-- Era/Druid.lua
-- Classic Era (1.15.x) Druid.  Spell, rank, talent and aura IDs from the Classic Era client tables (build 1.15.9).

if UnitClassBase( 'player' ) ~= 'DRUID' then return end

local addon, ns = ...
local Hekili = _G[ addon ]
local class, state = Hekili.Class, Hekili.State

local floor = math.floor
local GetShapeshiftFormID = _G.GetShapeshiftFormID

local IsCurrentSpell = _G.IsCurrentSpell or ( C_Spell and C_Spell.IsCurrentSpell )
local GetSpellPowerCost = _G.GetSpellPowerCost or ( C_Spell and C_Spell.GetSpellPowerCost )

local spec = Hekili:NewSpecialization( 11 )

spec:RegisterGear( "wolfshead_helm", 8345 ) -- +20 energy on shifting into Cat Form, +5 rage into Bear Form.


local bash_duration = { [5211] = 2, [6798] = 3, [8983] = 4 }

local function known_id( key )
    local ability = class.abilities[ key ]
    return ability and ability.id
end


-- Mana costs: the live client's cost for the rank you know (GetSpellPowerCost, talent reductions such as Moonglow
-- and Natural Shapeshifter included), refreshed every 10 seconds.  No hard-coded per-rank costs; if the client gives
-- nothing, shapeshifts fall back to their percent of base mana from the client's SpellPower table.
local cost_cache = {}

local function client_mana_cost( id )
    if not id or not GetSpellPowerCost then return nil end

    local now = GetTime()
    local c = cost_cache[ id ]

    if not c or now - c.t > 10 then
        local value
        local ok, costs = pcall( GetSpellPowerCost, id )
        if ok and type( costs ) == "table" then
            for _, p in ipairs( costs ) do
                if type( p ) == "table" and p.type == 0 and type( p.cost ) == "number" then
                    value = p.cost
                    break
                end
            end
        end
        c = { t = now, v = value }
        cost_cache[ id ] = c
    end

    return c.v
end

local function mana_cost( key )
    return client_mana_cost( known_id( key ) ) or 0
end

-- Percent of base mana (SpellPower table): Cat / Bear / Dire Bear Form 55%, Moonkin Form 35%, Travel Form 20%.
local form_pct = { cat_form = 0.55, bear_form = 0.55, dire_bear_form = 0.55, moonkin_form = 0.35, travel_form = 0.20 }

local function form_cost( key )
    local c = client_mana_cost( known_id( key ) )
    if c then return c end
    return form_pct[ key ] or 0
end


-- Rage from white hits in 1.x: 7.5 * damage / c, discounted for misses, dodges and glancing blows.
local SWING_EFFICIENCY = 0.8

local function rage_amount()
    local level = state.level or UnitLevel( "player" )
    local c = 0.0091107836 * ( level ^ 2 ) + 3.225598133 * level + 4.2652911
    local minMH, maxMH = UnitDamage( "player" )
    return 7.5 * ( ( ( minMH or 0 ) + ( maxMH or 0 ) ) / 2 ) * SWING_EFFICIENCY / c
end


-- Energy: Era energy comes in ticks of 20 every 2 seconds on a server timer, not continuously.
-- The tick phase is learned from observed ticks (+20 energy that isn't a shapeshift); until one is seen,
-- the first guess is "next tick in 1 second".
local ENERGY_TICK = 2
local last_energy_tick = 0
local last_energy = 0
local last_shift = 0

local function energy_tick_phase()
    if last_energy_tick == 0 then last_energy_tick = GetTime() - 1 end
    return last_energy_tick
end

spec:RegisterUnitEvent( "UNIT_POWER_FREQUENT", "player", nil, function( event, unit, powerType )
    if powerType ~= "ENERGY" then return end
    local e = UnitPower( "player", Enum.PowerType.Energy )
    local now = GetTime()
    local delta = e - last_energy
    if delta > 0 and now - last_shift > 0.3 then
        local maxE = UnitPowerMax( "player", Enum.PowerType.Energy )
        if ( delta >= 19 and delta <= 21 ) or ( e == maxE and delta < 20 ) then
            last_energy_tick = now
        end
    end
    last_energy = e
end )

spec:RegisterEvent( "UPDATE_SHAPESHIFT_FORM", function()
    last_shift = GetTime()
    last_energy = UnitPower( "player", Enum.PowerType.Energy )
end )


-- Resources.  Mana first: it is the druid's primary resource outside of animal forms.
spec:RegisterResource( Enum.PowerType.Mana )

spec:RegisterResource( Enum.PowerType.Energy, {
    tick = {
        last = function()
            local phase = energy_tick_phase()
            local t = state.query_time
            return phase + floor( ( t - phase ) / ENERGY_TICK ) * ENERGY_TICK
        end,

        interval = ENERGY_TICK,
        value = 20,
    },
} )

-- The ticks above are the whole energy model: no continuous regeneration on top of them.
do
    local res = rawget( spec, "resources" )
    local energy = type( res ) == "table" and res.energy and res.energy.state
    if type( energy ) == "table" then
        energy.reset = function() energy.regen = 0 end
    end
end

spec:RegisterResource( Enum.PowerType.Rage, {
    -- Enrage: 20 rage over 10 seconds.
    enrage = {
        aura = "enrage",

        last = function()
            local app = state.buff.enrage.applied
            local t = state.query_time

            return app + floor( t - app )
        end,

        interval = 1,
        value = 2,
    },

    mainhand = {
        swing = "mainhand",
        aura = "bear_form",

        last = function()
            local swing = state.combat == 0 and state.now or state.swings.mainhand
            local t = state.query_time

            return swing + ( floor( ( t - swing ) / state.swings.mainhand_speed ) * state.swings.mainhand_speed )
        end,

        interval = "mainhand_speed",

        stop = function() return state.swings.mainhand == 0 end,
        value = function( now )
            -- A queued Maul replaces the white swing, so it generates no rage.
            return state.buff.maul.expires < now and rage_amount() or 0
        end,
    },
} )

spec:RegisterResource( Enum.PowerType.ComboPoints )


-- Talents: { talentID, maxRank, rank1SpellID, ... rankNSpellID }, from the Classic Era client's Talent table.
-- Tree order in the talent frame: 1 Balance, 2 Feral Combat, 3 Restoration.
spec:RegisterTalents( {
    -- Balance
    improved_wrath            = {   762, 5, 16814, 16815, 16816, 16817, 16818 },
    nature_s_grasp            = {   761, 1, 16689 },
    improved_nature_s_grasp   = {   921, 4, 17245, 17247, 17248, 17249 },
    improved_entangling_roots = {   787, 3, 16918, 16919, 16920 },
    improved_moonfire         = {   763, 5, 16821, 16822, 16823, 16824, 16825 },
    natural_weapons           = {   791, 5, 16902, 16903, 16904, 16905, 16906 },
    natural_shapeshifter      = {   781, 3, 16833, 16834, 16835 },
    improved_thorns           = {   782, 3, 16836, 16839, 16840 },
    omen_of_clarity           = {   788, 1, 16864 },
    nature_s_reach            = {   764, 2, 16819, 16820 },
    vengeance                 = {   792, 5, 16909, 16910, 16911, 16912, 16913 },
    improved_starfire         = {   784, 5, 16850, 16923, 16924, 16925, 16926 },
    nature_s_grace            = {   789, 1, 16880 },
    moonglow                  = {   783, 3, 16845, 16846, 16847 },
    moonfury                  = {   790, 5, 16896, 16897, 16899, 16900, 16901 },
    moonkin_form              = {   793, 1, 24858 },

    -- Feral Combat
    ferocity                  = {   796, 5, 16934, 16935, 16936, 16937, 16938 },
    feral_aggression          = {   795, 5, 16858, 16859, 16860, 16861, 16862 },
    feral_instinct            = {   799, 5, 16947, 16948, 16949, 16950, 16951 },
    brutal_impact             = {   797, 2, 16940, 16941 },
    thick_hide                = {   794, 5, 16929, 16930, 16931, 16932, 16933 },
    feline_swiftness          = {   807, 2, 17002, 24866 },
    feral_charge              = {   804, 1, 16979 },
    sharpened_claws           = {   798, 3, 16942, 16943, 16944 },
    improved_shred            = {   802, 2, 16966, 16968 },
    predatory_strikes         = {   803, 3, 16972, 16974, 16975 },
    blood_frenzy              = {   800, 2, 16952, 16954 },
    primal_fury               = {   801, 2, 16958, 16961 },
    savage_fury               = {   805, 2, 16998, 16999 },
    faerie_fire_feral         = {  1162, 1, 16857 },
    heart_of_the_wild         = {   808, 5, 17003, 17004, 17005, 17006, 24894 },
    leader_of_the_pack        = {   809, 1, 17007 },

    -- Restoration
    improved_mark_of_the_wild = {   821, 5, 17050, 17051, 17053, 17054, 17055 },
    furor                     = {   822, 5, 17056, 17058, 17059, 17060, 17061 },
    improved_healing_touch    = {   824, 5, 17069, 17070, 17071, 17072, 17073 },
    nature_s_focus            = {   823, 5, 17063, 17065, 17066, 17067, 17068 },
    improved_enrage           = {   826, 2, 17079, 17082 },
    reflection                = {   829, 3, 17106, 17107, 17108 },
    insect_swarm              = {   827, 1, 5570 },
    subtlety                  = {   841, 5, 17118, 17119, 17120, 17121, 17122 },
    tranquil_spirit           = {   843, 5, 24968, 24969, 24970, 24971, 24972 },
    improved_rejuvenation     = {   830, 3, 17111, 17112, 17113 },
    nature_s_swiftness        = {   831, 1, 17116 },
    gift_of_nature            = {   828, 5, 17104, 24943, 24944, 24945, 24946 },
    improved_tranquility      = {   842, 2, 17123, 17124 },
    improved_regrowth         = {   825, 5, 17074, 17075, 17076, 17077, 17078 },
    swiftmend                 = {   844, 1, 18562 },
} )


-- Auras
spec:RegisterAuras( {
    -- Forms.  Bear Form and Dire Bear Form are one aura: the priorities only care about "a bear form".
    aquatic_form = {
        id = 1066,
        duration = 3600,
        max_stack = 1,
    },
    bear_form = {
        id = 5487,
        duration = 3600,
        max_stack = 1,
        copy = { 5487, 9634 },
    },
    cat_form = {
        id = 768,
        duration = 3600,
        max_stack = 1,
    },
    moonkin_form = {
        id = 24858,
        duration = 3600,
        max_stack = 1,
    },
    travel_form = {
        id = 783,
        duration = 3600,
        max_stack = 1,
    },

    barkskin = {
        id = 22812,
        duration = 15,
        max_stack = 1,
    },
    bash = {
        id = 8983,
        duration = function() return ( bash_duration[ known_id( "bash" ) ] or 4 ) + 0.5 * talent.brutal_impact.rank end,
        max_stack = 1,
        copy = { 5211, 6798, 8983 },
    },
    -- Your next damage or healing spell or offensive ability costs no mana, rage or energy.
    clearcasting = {
        id = 16870,
        duration = 15,
        max_stack = 1,
    },
    dash = {
        id = 9821,
        duration = 15,
        max_stack = 1,
        copy = { 1850, 9821 },
    },
    demoralizing_roar = {
        id = 9898,
        duration = 30,
        max_stack = 1,
        shared = "target",
        copy = { 99, 1735, 9490, 9747, 9898 },
    },
    -- A warrior's Demoralizing Shout doesn't stack with Demoralizing Roar.
    demoralizing_shout = {
        id = 11556,
        duration = 30,
        max_stack = 1,
        shared = "target",
        copy = { 1160, 6190, 11554, 11555, 11556 },
    },
    -- Generating rage over time; armor reduced.
    enrage = {
        id = 5229,
        duration = 10,
        tick_time = 1,
        max_stack = 1,
    },
    -- Faerie Fire and Faerie Fire (Feral) are the same armor debuff (they don't stack); any druid's counts.
    faerie_fire = {
        id = 9907,
        duration = 40,
        max_stack = 1,
        shared = "target",
        copy = { 770, 778, 9749, 9907, 16857, 17390, 17391, 17392 },
    },
    feral_charge_effect = {
        id = 19675,
        duration = 4,
        max_stack = 1,
    },
    -- Converting rage into health.
    frenzied_regeneration = {
        id = 22896,
        duration = 10,
        tick_time = 1,
        max_stack = 1,
        copy = { 22842, 22895, 22896 },
    },
    gift_of_the_wild = {
        id = 21850,
        duration = 3600,
        max_stack = 1,
        shared = "player",
        copy = { 21849, 21850 },
    },
    hurricane = {
        id = 17402,
        duration = 10,
        tick_time = 1,
        max_stack = 1,
        copy = { 16914, 17401, 17402 },
    },
    innervate = {
        id = 29166,
        duration = 20,
        max_stack = 1,
    },
    insect_swarm = {
        id = 24977,
        duration = 12,
        tick_time = 2,
        max_stack = 1,
        copy = { 5570, 24974, 24975, 24976, 24977 },
    },
    mark_of_the_wild = {
        id = 9885,
        duration = 1800,
        max_stack = 1,
        shared = "player",
        copy = { 1126, 5232, 6756, 5234, 8907, 9884, 9885 },
    },
    -- Pseudo-aura: Maul is queued on the next main-hand swing.
    maul = {
        duration = function() return swings.mainhand_speed end,
        max_stack = 1,
    },
    moonfire = {
        id = 9835,
        duration = function() return known_id( "moonfire" ) == 8921 and 9 or 12 end,
        tick_time = 3,
        max_stack = 1,
        copy = { 8921, 8924, 8925, 8926, 8927, 8928, 8929, 9833, 9834, 9835 },
    },
    -- Next Nature or Arcane spell's casting time reduced by 0.5 sec.
    natures_grace = {
        id = 16886,
        duration = 15,
        max_stack = 1,
    },
    omen_of_clarity = {
        id = 16864,
        duration = 600,
        max_stack = 1,
    },
    pounce = {
        id = 9827,
        duration = function() return 2 + 0.5 * talent.brutal_impact.rank end,
        max_stack = 1,
        copy = { 9005, 9823, 9827 },
    },
    pounce_bleed = {
        id = 9826,
        duration = 18,
        tick_time = 3,
        max_stack = 1,
        copy = { 9007, 9824, 9826 },
    },
    prowl = {
        id = 9913,
        duration = 3600,
        max_stack = 1,
        copy = { 5215, 6783, 9913 },
    },
    rake = {
        id = 9904,
        duration = 9,
        tick_time = 3,
        max_stack = 1,
        copy = { 1822, 1823, 1824, 9904 },
    },
    rip = {
        id = 9896,
        duration = 12,
        tick_time = 2,
        max_stack = 1,
        copy = { 1079, 9492, 9493, 9752, 9894, 9896 },
    },
    thorns = {
        id = 9910,
        duration = 600,
        max_stack = 1,
        shared = "player",
        copy = { 467, 782, 1075, 8914, 9756, 9910 },
    },
    tigers_fury = {
        id = 9846,
        duration = 6,
        max_stack = 1,
        copy = { 5217, 6793, 9845, 9846 },
    },

    -- Aliases.
    form = {
        alias = { "cat_form", "bear_form", "moonkin_form", "travel_form", "aquatic_form" },
        aliasMode = "first",
        aliasType = "buff",
    },
} )


local form_by_id = { [ 1 ] = "cat_form", [ 3 ] = "travel_form", [ 4 ] = "aquatic_form", [ 5 ] = "bear_form", [ 8 ] = "bear_form", [ 31 ] = "moonkin_form" }
local all_forms = { "cat_form", "bear_form", "moonkin_form", "travel_form", "aquatic_form" }


-- Shapeshifting: energy and rage are reset; Furor (20% per rank) and Wolfshead Helm add some back.
spec:RegisterStateExpr( "powershift_gain", function()
    return 8 * talent.furor.rank + ( equipped.wolfshead_helm and 20 or 0 )
end )

spec:RegisterStateFunction( "swap_form", function( form )
    for _, f in ipairs( all_forms ) do removeBuff( f ) end
    removeBuff( "maul" )
    removeBuff( "prowl" )

    if form == "cat_form" then
        if energy.current > 0 then spend( energy.current, "energy" ) end
        gain( powershift_gain, "energy" )
    elseif form == "bear_form" then
        if rage.current > 0 then spend( rage.current, "rage" ) end
        gain( 2 * talent.furor.rank + ( equipped.wolfshead_helm and 5 or 0 ), "rage" )
    end

    if form then applyBuff( form ) end
end )

-- Caster form or Moonkin Form: casting is possible.
spec:RegisterStateExpr( "caster_form", function()
    return not ( buff.cat_form.up or buff.bear_form.up or buff.travel_form.up or buff.aquatic_form.up )
end )

-- Settings as expressions.
spec:RegisterStateExpr( "behind_target", function()
    local mode = settings.behind
    if mode == "always" then return true end
    if mode == "group" then return group end
    return false
end )

spec:RegisterStateExpr( "bleeds_wanted", function()
    local mode = settings.bleeds
    if mode == "always" then return true end
    if mode == "noraid" then return not raid end
    return false
end )

spec:RegisterStateExpr( "prowl_wanted", function()
    local mode = settings.prowl_opener
    if mode == "always" then return true end
    if mode == "solo" then return not group end
    return false
end )

spec:RegisterStateExpr( "ravage_opener", function()
    return settings.opener == "ravage" and behind_target
end )

spec:RegisterStateExpr( "prefer_cat", function()
    return settings.feral_form ~= "bear"
end )

spec:RegisterStateExpr( "tf_precombat", function()
    return settings.tigers_fury ~= "never"
end )

spec:RegisterStateExpr( "tf_combat", function()
    return settings.tigers_fury == "always"
end )

spec:RegisterStateExpr( "nuke_starfire", function()
    return settings.balance_nuke ~= "wrath"
end )

spec:RegisterStateExpr( "conserve_mana", function()
    return mana.pct < settings.conserve_mana_pct
end )

-- Time until the next energy tick.
spec:RegisterStateExpr( "energy_tick_remains", function()
    local phase = energy_tick_phase()
    local t = query_time
    return ENERGY_TICK - ( ( t - phase ) % ENERGY_TICK )
end )

-- Powershift: shift out and back into Cat Form for Furor / Wolfshead energy.
spec:RegisterStateExpr( "powershift_now", function()
    if not settings.powershift or not buff.cat_form.up or buff.clearcasting.up then return false end
    local gain = powershift_gain
    if gain < 40 then return false end
    local threshold = min( settings.powershift_energy, gain - 20 )
    if energy.current >= threshold then return false end
    -- A tick about to land would give the energy anyway.
    if energy_tick_remains < 0.5 and energy.current + 20 >= threshold then return false end
    return mana.current >= action.cat_form.cost + settings.powershift_mana
end )


local finish_maul = setfenv( function()
    spend( buff.clearcasting.up and 0 or ( 15 - talent.ferocity.rank ), "rage" )
end, state )

spec:RegisterStateFunction( "start_maul", function()
    applyBuff( "maul", swings.time_to_next_mainhand )
    state:QueueAuraExpiration( "maul", finish_maul, buff.maul.expires )
end )


spec:RegisterHook( "reset_precast", function()
    -- The shapeshift form ID is authoritative for the current form (auras can lag a frame).
    if GetShapeshiftFormID then
        local f = GetShapeshiftFormID()
        local key = f and form_by_id[ f ]
        if key then
            for _, other in ipairs( all_forms ) do
                if other ~= key and buff[ other ].up then removeBuff( other ) end
            end
            if not buff[ key ].up then applyBuff( key ) end
        elseif not f then
            for _, other in ipairs( all_forms ) do
                if buff[ other ].up then removeBuff( other ) end
            end
        end
    end

    if IsCurrentSpell and class.abilities.maul.id and IsCurrentSpell( class.abilities.maul.id ) then
        start_maul()
        Hekili:Debug( "Starting Maul, next swing in %.2f...", buff.maul.remains )
    end
end )


-- Abilities
spec:RegisterAbilities( {
    -- Forms ------------------------------------------------------------------------------------------------
    bear_form = {
        id = 5487,
        cast = 0,
        cooldown = 0,
        gcd = "spell",

        spend = function() return form_cost( "bear_form" ) end,
        spendType = "mana",

        startsCombat = false,
        texture = 132276,

        nobuff = "bear_form",

        handler = function()
            swap_form( "bear_form" )
        end,
    },

    dire_bear_form = {
        id = 9634,
        cast = 0,
        cooldown = 0,
        gcd = "spell",

        spend = function() return form_cost( "dire_bear_form" ) end,
        spendType = "mana",

        startsCombat = false,
        texture = 132276,

        nobuff = "bear_form",

        handler = function()
            swap_form( "bear_form" )
        end,
    },

    -- In Cat Form, this is a powershift (use a "/cancelform" + "/cast Cat Form" macro).
    cat_form = {
        id = 768,
        cast = 0,
        cooldown = 0,
        gcd = "spell",

        spend = function() return form_cost( "cat_form" ) end,
        spendType = "mana",

        startsCombat = false,
        texture = 132115,

        usable = function()
            return not buff.cat_form.up or settings.powershift, "already in cat form"
        end,

        handler = function()
            swap_form( "cat_form" )
        end,
    },

    moonkin_form = {
        id = 24858,
        cast = 0,
        cooldown = 0,
        gcd = "spell",

        spend = function() return form_cost( "moonkin_form" ) end,
        spendType = "mana",

        talent = "moonkin_form",
        startsCombat = false,
        texture = 136036,

        nobuff = "moonkin_form",

        handler = function()
            swap_form( "moonkin_form" )
        end,
    },

    travel_form = {
        id = 783,
        cast = 0,
        cooldown = 0,
        gcd = "spell",

        spend = function() return form_cost( "travel_form" ) end,
        spendType = "mana",

        startsCombat = false,
        texture = 132144,

        nobuff = "travel_form",

        handler = function()
            swap_form( "travel_form" )
        end,
    },


    -- Caster ------------------------------------------------------------------------------------------------
    faerie_fire = {
        id = 9907,
        cast = 0,
        cooldown = 0,
        gcd = "spell",

        spend = function() return buff.clearcasting.up and 0 or mana_cost( "faerie_fire" ) end,
        spendType = "mana",

        startsCombat = true,
        texture = 136033,

        usable = function() return caster_form, "requires caster or moonkin form" end,

        handler = function()
            removeBuff( "clearcasting" )
            applyDebuff( "target", "faerie_fire" )
        end,

        copy = { 770, 778, 9749 }
    },

    -- Channeled: 10 sec, 1 min cooldown.
    hurricane = {
        id = 17402,
        cast = 10,
        channeled = true,
        breakable = true,
        cooldown = 60,
        gcd = "spell",

        spend = function() return buff.clearcasting.up and 0 or mana_cost( "hurricane" ) end,
        spendType = "mana",

        startsCombat = true,
        texture = 136018,

        usable = function() return caster_form, "requires caster or moonkin form" end,

        start = function()
            removeBuff( "clearcasting" )
            applyDebuff( "target", "hurricane" )
        end,

        breakchannel = function()
            removeDebuff( "target", "hurricane" )
        end,

        copy = { 16914, 17401 }
    },

    insect_swarm = {
        id = 24977,
        cast = 0,
        cooldown = 0,
        gcd = "spell",

        spend = function() return buff.clearcasting.up and 0 or mana_cost( "insect_swarm" ) end,
        spendType = "mana",

        talent = "insect_swarm",
        startsCombat = true,
        texture = 136045,

        usable = function() return caster_form, "requires caster or moonkin form" end,

        handler = function()
            removeBuff( "clearcasting" )
            applyDebuff( "target", "insect_swarm" )
        end,

        copy = { 5570, 24974, 24975, 24976 }
    },

    mark_of_the_wild = {
        id = 9885,
        cast = 0,
        cooldown = 0,
        gcd = "spell",

        spend = function() return mana_cost( "mark_of_the_wild" ) end,
        spendType = "mana",

        startsCombat = false,
        texture = 136078,

        usable = function() return caster_form, "requires caster or moonkin form" end,

        handler = function()
            applyBuff( "mark_of_the_wild" )
        end,

        copy = { 1126, 5232, 6756, 5234, 8907, 9884 }
    },

    moonfire = {
        id = 9835,
        cast = 0,
        cooldown = 0,
        gcd = "spell",

        spend = function() return buff.clearcasting.up and 0 or mana_cost( "moonfire" ) end,
        spendType = "mana",

        startsCombat = true,
        texture = 136096,

        usable = function() return caster_form, "requires caster or moonkin form" end,

        handler = function()
            removeBuff( "clearcasting" )
            applyDebuff( "target", "moonfire" )
        end,

        copy = { 8921, 8924, 8925, 8926, 8927, 8928, 8929, 9833, 9834 }
    },

    -- Self-buff (10 min) that lets your attacks and spells proc Clearcasting.
    omen_of_clarity = {
        id = 16864,
        cast = 0,
        cooldown = 0,
        gcd = "spell",

        spend = function() return mana_cost( "omen_of_clarity" ) end,
        spendType = "mana",

        talent = "omen_of_clarity",
        startsCombat = false,
        texture = 136017,

        usable = function() return caster_form, "requires caster or moonkin form" end,

        handler = function()
            applyBuff( "omen_of_clarity" )
        end,
    },

    starfire = {
        id = 25298,
        cast = function()
            return max( 1, 3.5 - 0.1 * talent.improved_starfire.rank - ( buff.natures_grace.up and 0.5 or 0 ) ) * haste
        end,
        cooldown = 0,
        gcd = "spell",

        spend = function() return buff.clearcasting.up and 0 or mana_cost( "starfire" ) end,
        spendType = "mana",

        startsCombat = true,
        texture = 135753,

        usable = function() return caster_form, "requires caster or moonkin form" end,

        handler = function()
            removeBuff( "clearcasting" )
            removeBuff( "natures_grace" )
        end,

        copy = { 2912, 8949, 8950, 8951, 9875, 9876 }
    },

    thorns = {
        id = 9910,
        cast = 0,
        cooldown = 0,
        gcd = "spell",

        spend = function() return mana_cost( "thorns" ) end,
        spendType = "mana",

        startsCombat = false,
        texture = 136104,

        usable = function() return caster_form, "requires caster or moonkin form" end,

        handler = function()
            applyBuff( "thorns" )
        end,

        copy = { 467, 782, 1075, 8914, 9756 }
    },

    wrath = {
        id = 9912,
        cast = function()
            return max( 1, 2 - 0.1 * talent.improved_wrath.rank - ( buff.natures_grace.up and 0.5 or 0 ) ) * haste
        end,
        cooldown = 0,
        gcd = "spell",

        spend = function() return buff.clearcasting.up and 0 or mana_cost( "wrath" ) end,
        spendType = "mana",

        startsCombat = true,
        texture = 136006,

        usable = function() return caster_form, "requires caster or moonkin form" end,

        handler = function()
            removeBuff( "clearcasting" )
            removeBuff( "natures_grace" )
        end,

        copy = { 5176, 5177, 5178, 5179, 5180, 6780, 8905 }
    },


    -- Cat -------------------------------------------------------------------------------------------------
    claw = {
        id = 9850,
        cast = 0,
        cooldown = 0,
        gcd = "totem",

        spend = function() return buff.clearcasting.up and 0 or ( 45 - talent.ferocity.rank ) end,
        spendType = "energy",

        startsCombat = true,
        texture = 132140,

        buff = "cat_form",

        handler = function()
            removeBuff( "clearcasting" )
            removeBuff( "prowl" )
            gain( 1, "combo_points" )
        end,

        copy = { 1082, 3029, 5201, 9849 }
    },

    -- Finishing move; extra energy is converted into damage.
    ferocious_bite = {
        id = 31018,
        cast = 0,
        cooldown = 0,
        gcd = "totem",

        spend = function() return buff.clearcasting.up and 0 or 35 end,
        spendType = "energy",

        startsCombat = true,
        texture = 132127,

        buff = "cat_form",

        usable = function() return combo_points.current > 0, "requires combo points" end,

        handler = function()
            removeBuff( "clearcasting" )
            removeBuff( "prowl" )
            if energy.current > 0 then spend( energy.current, "energy" ) end
            spend( combo_points.current, "combo_points" )
        end,

        copy = { 22568, 22827, 22828, 22829 }
    },

    -- Talent; no cost, 6 sec cooldown; usable in Cat and Bear Form.
    faerie_fire_feral = {
        id = 17392,
        cast = 0,
        cooldown = 6,
        gcd = "spell",

        talent = "faerie_fire_feral",
        startsCombat = true,
        texture = 136033,

        usable = function() return buff.cat_form.up or buff.bear_form.up, "requires cat or bear form" end,

        handler = function()
            removeBuff( "prowl" )
            applyDebuff( "target", "faerie_fire" )
        end,

        copy = { 16857, 17390, 17391 }
    },

    -- Stun and bleed from Prowl.
    pounce = {
        id = 9827,
        cast = 0,
        cooldown = 0,
        gcd = "totem",

        spend = function() return buff.clearcasting.up and 0 or 50 end,
        spendType = "energy",

        startsCombat = true,
        texture = 132142,

        buff = "prowl",

        handler = function()
            removeBuff( "clearcasting" )
            removeBuff( "prowl" )
            applyDebuff( "target", "pounce" )
            applyDebuff( "target", "pounce_bleed" )
            gain( 1, "combo_points" )
        end,

        copy = { 9005, 9823 }
    },

    prowl = {
        id = 9913,
        cast = 0,
        cooldown = 10,
        gcd = "off",

        startsCombat = false,
        texture = 132089,

        nobuff = "prowl",

        usable = function() return buff.cat_form.up and combat == 0, "requires cat form, out of combat" end,

        handler = function()
            applyBuff( "prowl" )
        end,

        copy = { 5215, 6783 }
    },

    rake = {
        id = 9904,
        cast = 0,
        cooldown = 0,
        gcd = "totem",

        spend = function() return buff.clearcasting.up and 0 or ( 40 - talent.ferocity.rank ) end,
        spendType = "energy",

        startsCombat = true,
        texture = 132122,

        buff = "cat_form",

        handler = function()
            removeBuff( "clearcasting" )
            removeBuff( "prowl" )
            applyDebuff( "target", "rake" )
            gain( 1, "combo_points" )
        end,

        copy = { 1822, 1823, 1824 }
    },

    -- From Prowl, behind the target.
    ravage = {
        id = 9867,
        cast = 0,
        cooldown = 0,
        gcd = "totem",

        spend = function() return buff.clearcasting.up and 0 or 60 end,
        spendType = "energy",

        startsCombat = true,
        texture = 132141,

        buff = "prowl",

        usable = function() return behind_target, "must be behind the target (see the Behind the Target setting)" end,

        handler = function()
            removeBuff( "clearcasting" )
            removeBuff( "prowl" )
            gain( 1, "combo_points" )
        end,

        copy = { 6785, 6787, 9866 }
    },

    rip = {
        id = 9896,
        cast = 0,
        cooldown = 0,
        gcd = "totem",

        spend = function() return buff.clearcasting.up and 0 or 30 end,
        spendType = "energy",

        startsCombat = true,
        texture = 132152,

        buff = "cat_form",

        usable = function() return combo_points.current > 0, "requires combo points" end,

        handler = function()
            removeBuff( "clearcasting" )
            removeBuff( "prowl" )
            applyDebuff( "target", "rip" )
            spend( combo_points.current, "combo_points" )
        end,

        copy = { 1079, 9492, 9493, 9752, 9894 }
    },

    -- Behind the target.
    shred = {
        id = 9830,
        cast = 0,
        cooldown = 0,
        gcd = "totem",

        spend = function() return buff.clearcasting.up and 0 or ( 60 - 6 * talent.improved_shred.rank ) end,
        spendType = "energy",

        startsCombat = true,
        texture = 136231,

        buff = "cat_form",

        usable = function() return behind_target, "must be behind the target (see the Behind the Target setting)" end,

        handler = function()
            removeBuff( "clearcasting" )
            removeBuff( "prowl" )
            gain( 1, "combo_points" )
        end,

        copy = { 5221, 6800, 8992, 9829 }
    },

    -- Increases damage done for 6 sec.
    tigers_fury = {
        id = 9846,
        cast = 0,
        cooldown = 1,
        gcd = "off",

        spend = 30,
        spendType = "energy",

        startsCombat = false,
        texture = 132242,

        buff = "cat_form",

        handler = function()
            applyBuff( "tigers_fury" )
        end,

        copy = { 5217, 6793, 9845 }
    },


    -- Bear ------------------------------------------------------------------------------------------------
    bash = {
        id = 8983,
        cast = 0,
        cooldown = 60,
        gcd = "spell",

        spend = 10,
        spendType = "rage",

        startsCombat = true,
        texture = 132114,

        buff = "bear_form",

        toggle = "interrupts",

        debuff = "casting",
        readyTime = state.timeToInterrupt,

        handler = function()
            interrupt()
            applyDebuff( "target", "bash" )
        end,

        copy = { 5211, 6798 }
    },

    demoralizing_roar = {
        id = 9898,
        cast = 0,
        cooldown = 0,
        gcd = "spell",

        spend = 10,
        spendType = "rage",

        startsCombat = true,
        texture = 132121,

        buff = "bear_form",

        handler = function()
            applyDebuff( "target", "demoralizing_roar" )
            active_dot.demoralizing_roar = max( active_dot.demoralizing_roar, active_enemies )
        end,

        copy = { 99, 1735, 9490, 9747 }
    },

    -- 20 rage over 10 sec; Improved Enrage adds 5 per rank instantly.  Reduces armor.
    enrage = {
        id = 5229,
        cast = 0,
        cooldown = 60,
        gcd = "off",

        startsCombat = false,
        texture = 132126,

        buff = "bear_form",

        handler = function()
            applyBuff( "enrage" )
            if talent.improved_enrage.rank > 0 then gain( 5 * talent.improved_enrage.rank, "rage" ) end
        end,
    },

    -- Charge an enemy (8-25 yards), immobilizing it and interrupting spellcasting for 4 sec.
    feral_charge = {
        id = 16979,
        cast = 0,
        cooldown = 15,
        gcd = "off",

        spend = 5,
        spendType = "rage",

        talent = "feral_charge",
        startsCombat = true,
        texture = 132183,

        buff = "bear_form",

        usable = function() return target.minR > 7, "target must be outside 8 yards" end,

        handler = function()
            setDistance( 5 )
            applyDebuff( "target", "feral_charge_effect" )
        end,
    },

    -- Converts up to 10 rage per second into health for 10 sec.
    frenzied_regeneration = {
        id = 22896,
        cast = 0,
        cooldown = 180,
        gcd = "spell",

        startsCombat = false,
        texture = 132091,

        buff = "bear_form",

        toggle = "defensives",

        handler = function()
            applyBuff( "frenzied_regeneration" )
        end,

        copy = { 22842, 22895 }
    },

    growl = {
        id = 6795,
        cast = 0,
        cooldown = 10,
        gcd = "off",

        startsCombat = true,
        texture = 132270,

        buff = "bear_form",

        handler = function()
        end,
    },

    -- On next swing, like a warrior's Heroic Strike.
    maul = {
        id = 9881,
        cast = 0,
        cooldown = 0,
        gcd = "off",

        spend = function() return buff.clearcasting.up and 0 or ( 15 - talent.ferocity.rank ) end,
        spendType = "rage",

        startsCombat = true,
        texture = 132136,

        buff = "bear_form",
        nobuff = "maul",

        usable = function() return not buff.maul.up, "maul already queued" end,

        handler = function()
            -- The rage is spent when the swing lands; see start_maul.
            gain( buff.clearcasting.up and 0 or ( 15 - talent.ferocity.rank ), "rage" )
            start_maul()
        end,

        copy = { 6807, 6808, 6809, 8972, 9745, 9880 }
    },

    swipe = {
        id = 9908,
        cast = 0,
        cooldown = 0,
        gcd = "spell",

        spend = function() return buff.clearcasting.up and 0 or ( 20 - talent.ferocity.rank ) end,
        spendType = "rage",

        startsCombat = true,
        texture = 134296,

        buff = "bear_form",

        handler = function()
            removeBuff( "clearcasting" )
        end,

        copy = { 779, 780, 769, 9754 }
    },
} )


-- Settings
spec:RegisterSetting( "druid_description", nil, {
    type = "description",
    name = "The Feral priority follows your current form: Cat Form gets the cat rotation, Bear Form the bear (tank) rotation, " ..
        "caster form shifts into your preferred form (or casts Wrath / Moonfire before you have one).  The Balance priority is " ..
        "also used for Restoration, which Herakili doesn't cover (it doesn't do healing).\n\n"
} )

spec:RegisterSetting( "feral_form", "cat", {
    type = "select",
    name = "Feral: Preferred Form",
    desc = "The form the Feral priority shifts into from caster form.",
    width = "full",
    values = {
        cat = "Cat Form (damage)",
        bear = "Bear Form (tank)",
    },
} )

spec:RegisterSetting( "faerie_fire", true, {
    type = "toggle",
    name = "Maintain Faerie Fire",
    desc = "When enabled, Faerie Fire (or Faerie Fire (Feral) in Cat and Bear Form) is recommended when the target doesn't have it " ..
        "from any druid.  Disable it when another druid keeps it up.",
    width = "full",
} )

spec:RegisterSetting( "cat_header", nil, {
    type = "header",
    name = "Cat Form"
} )

spec:RegisterSetting( "behind", "group", {
    type = "select",
    name = "Behind the Target (Shred, Ravage)",
    desc = "Herakili can't see whether you are behind your target.  Shred and Ravage are only recommended when this says you are; " ..
        "otherwise Claw (and Pounce from Prowl).",
    width = "full",
    values = {
        always = "Always (I position behind)",
        group = "In a party or raid (someone else tanks)",
        never = "Never (always Claw)",
    },
} )

spec:RegisterSetting( "bleeds", "noraid", {
    type = "select",
    name = "Rip and Rake",
    desc = "In raids the 16 debuff slots on a boss are usually full, so cats use Ferocious Bite only.  Choose when Rip (5 combo points, " ..
        "target living long enough) and Rake are recommended.  Never use them on bleed-immune targets (elementals, undead constructs).",
    width = "full",
    values = {
        always = "Always",
        noraid = "Solo and in parties (not in raids)",
        never = "Never (Ferocious Bite only)",
    },
} )

spec:RegisterSetting( "rip_ttd", 10, {
    type = "range",
    name = "Rip Minimum Time to Die",
    desc = "Rip is only recommended over Ferocious Bite when the target is expected to live at least this many seconds.",
    width = "full",
    min = 0,
    softMax = 30,
    step = 1,
} )

spec:RegisterSetting( "prowl_opener", "solo", {
    type = "select",
    name = "Prowl Before Combat",
    desc = "Recommend Prowl out of combat in Cat Form, to open with Ravage or Pounce.",
    width = "full",
    values = {
        always = "Always",
        solo = "Solo only",
        never = "Never",
    },
} )

spec:RegisterSetting( "opener", "ravage", {
    type = "select",
    name = "Prowl Opener",
    desc = "The attack used from Prowl.  Ravage needs you to be behind the target (Behind the Target setting); otherwise Pounce is used.",
    width = "full",
    values = {
        ravage = "Ravage when behind, otherwise Pounce",
        pounce = "Pounce",
    },
} )

spec:RegisterSetting( "tigers_fury", "precombat", {
    type = "select",
    name = "Tiger's Fury",
    desc = "Tiger's Fury costs 30 energy for 6 seconds of bonus damage, which is usually a loss in combat.  Out of combat with full energy " ..
        "it is free.",
    width = "full",
    values = {
        never = "Never",
        precombat = "Before the pull, with full energy",
        always = "Also in combat, when energy would cap",
    },
} )

spec:RegisterSetting( "powershift", false, {
    type = "toggle",
    name = "Powershifting",
    desc = "When enabled, Cat Form is recommended while already in Cat Form when energy is low: shift out and back in for the energy " ..
        "from Furor (40 at 5/5) and Wolfshead Helm (20).  Needs 5/5 Furor or Wolfshead Helm, and mana.  Use a macro:\n\n" ..
        "/cancelform\n/cast Cat Form",
    width = "full",
} )

spec:RegisterSetting( "powershift_energy", 30, {
    type = "range",
    name = "Powershift Below Energy",
    desc = "Powershift when energy is below this (and at least 20 below what the shift gives you).",
    width = "full",
    min = 0,
    max = 60,
    step = 1,
} )

spec:RegisterSetting( "powershift_mana", 0, {
    type = "range",
    name = "Powershift Mana Reserve",
    desc = "Mana to keep in reserve (for example for an emergency heal) beyond the cost of the shift.",
    width = "full",
    min = 0,
    softMax = 2000,
    step = 50,
} )

spec:RegisterSetting( "bear_header", nil, {
    type = "header",
    name = "Bear Form"
} )

spec:RegisterSetting( "maul_rage_threshold", 15, {
    type = "range",
    name = "Maul Rage Threshold",
    desc = "Maul is queued on your next swing once you have at least this much rage (single target).  Raise it to keep rage for Swipe " ..
        "or Demoralizing Roar.",
    width = "full",
    min = 0,
    softMax = 100,
    step = 1,
} )

spec:RegisterSetting( "swipe_rage_threshold", 50, {
    type = "range",
    name = "Single-Target Swipe Rage Threshold",
    desc = "With one target, Swipe is used as an extra rage dump at or above this much rage.  With 2+ enemies Swipe is used whenever possible.",
    width = "full",
    min = 0,
    softMax = 100,
    step = 1,
} )

spec:RegisterSetting( "demo_roar", true, {
    type = "toggle",
    name = "Maintain Demoralizing Roar",
    desc = "When enabled, Demoralizing Roar is kept on the target (unless a warrior's Demoralizing Shout is there).  With 3+ enemies it is " ..
        "always used.",
    width = "full",
} )

spec:RegisterSetting( "frenzied_regen_pct", 30, {
    type = "range",
    name = "Frenzied Regeneration Below Health %",
    desc = "Frenzied Regeneration (defensives toggle) is recommended below this health percentage, with at least 30 rage.",
    width = "full",
    min = 0,
    max = 100,
    step = 1,
} )

spec:RegisterSetting( "growl_taunt", false, {
    type = "toggle",
    name = "Growl When Not Tanking",
    desc = "When enabled, Growl is recommended in a group when your target is not attacking you.",
    width = "full",
} )

spec:RegisterSetting( "balance_header", nil, {
    type = "header",
    name = "Balance"
} )

spec:RegisterSetting( "balance_nuke", "starfire", {
    type = "select",
    name = "Main Nuke",
    desc = "Starfire is the stronger and more mana-efficient nuke; Wrath for Arcane-immune targets or when you prefer shorter casts.  " ..
        "Wrath is still used when the target dies before a Starfire would land.",
    width = "full",
    values = {
        starfire = "Starfire",
        wrath = "Wrath",
    },
} )

spec:RegisterSetting( "dot_moonfire", true, {
    type = "toggle",
    name = "Maintain Moonfire",
    desc = "When enabled, Moonfire is kept on targets that live long enough.  It's always used while moving.",
    width = "full",
} )

spec:RegisterSetting( "dot_insect_swarm", true, {
    type = "toggle",
    name = "Maintain Insect Swarm",
    desc = "When enabled (and talented), Insect Swarm is kept on targets that live long enough.",
    width = "full",
} )

spec:RegisterSetting( "conserve_mana_pct", 15, {
    type = "range",
    name = "Conserve Mana Below %",
    desc = "Below this mana percentage, Faerie Fire, damage-over-time spells and Hurricane are skipped and only the main nuke is cast.  " ..
        "Druids can't use wands: once out of mana there is nothing left to recommend.",
    width = "full",
    min = 0,
    max = 100,
    step = 1,
} )

spec:RegisterSetting( "hurricane_targets", 3, {
    type = "range",
    name = "Hurricane Minimum Targets",
    desc = "Hurricane is recommended with at least this many enemies.",
    width = "full",
    min = 2,
    max = 10,
    step = 1,
} )


spec:RegisterOptions( {
    enabled = true,

    aoe = 3,

    gcd = 1126, -- Mark of the Wild: known from level 1, on the GCD, no cooldown of its own.

    nameplates = true,
    nameplateRange = 8,

    damage = true,
    damageExpiration = 6,

    package = "Feral",
    usePackSelector = true
} )


spec:RegisterPack( "Feral", 20261027.1212, [[Hekili:TM1wVTnUs4FlPlG3e0uhlNM0lWjpKUBX5SaNEkQlqFts0su2ews0GKkUzrH(TVZqQlusuQU5CEOTYKCM5JZLpoK13Z)R(RJjkQ)NwUy5TElw(M5El9w6Vw90bQ)6dKO9KTWh5Km4V)ivqsXrFkLtIrzL8cremZoL6G89xD1wMAxXM5r8SR2blEplL18H)6nfSu1)o3FZigvEGg5)jppyAQmQYELHN)bIQm8p(86YqsECz4duIOmurY3xgU5PYWeUi7Illd)qkrkzrLH)PGaOuWtyPa2(TFRmSst)HOGfJk0ALLHEZ9U5I3dYJM5JGYkdJjzW(UJ9mtGwLLVfSw0oUKMBqWtGBagPqiO5kdGMx(xOHxRDqY33fDWsmaAlGhQeq034h3rjXwlRgY42(QMF(v9U2igaIVrercsIcN4rQiV)oTXPPbJQRWQDul7vHii0LvKZup97aSEX6DcAmS0hyk0Ba25g4xh4hPc5owI6fLHccAibxrumE(fv(mTUT3PswMSYN8aDhlp(vWsELIi2svGk)c7WvFHSNcF(zb)iia)anNkGF)v2wQarZhlep1X6MaX)HuKE16JSdu0ScQChpnwAJJy6MIKeCib1aHiEUsWttPWsy5vlRYNjPkuZiAl)lseURKZpiOGNzdr9Y7UkJi2hWtcaHcoYsJVKLC3zOfM3FM5fhMzMzla3EZ4w58mAoUWOuIaIcT6U3eJQGiIkatarjHXb3Famufm0zMJjzmtqd2aj7nYFcc9RU(dy01Gn4JGJKCfnEMwUAKpQSkmtqgKG5bGgujbnZoqdZWSNTpnVQO8(7Q(Dg57v(clTPTyJnbljkYdm)kiLjvxI8F3bAhn7OyDm5qxuJGn(RtrYiIurBLnJZr2hxI7oQBVIUrx7zCoyTcprmIUpSWQHdTQw))QRIHsVebpRQ2gid)c5rn)Qz0nAcbOuMdLhIJmjmZN5f5r05LH18fvfPggdGyfzMGIxSQo9i5jjQgfIeyDKCnX2rqLsEfWGFAwoppfOSlKO4aPBUM(2WneMZv1WbiLzWpoYlsJ7GSnWFoWI2xlp9r0O4A1Gjb8AXKnPu02CyZFX82S5iDESqV7XqL5Radxx)LDq7c6p6WIGQkaxz1dQcE7I(6lHqfmAqcMEO5QrT2WbAn7SZm8O2JHMWeradNrdu8Gyg9EVfgN(NBOQbVzLoXtARgIxOQOP3anAyyIbVNMPh)h4yVVXttKMtgnBL6yw9VqFEk)4aFCNcIgyeKZpAG2n6J62WXZty5k8eA4mOATdHpAC1bgHgok7duQtctzps12pFlIiEX2DDZIHtJ5rmEH0Ce6Wmb2beGAKeyasBS6Mzgyutsw7)bHgXV3g3G1eOuXdc214jydaNjm9ZvWRDaRvVEybWETogz)bZ2EYzukqpHKmW(ch1LDxDJlVX76BwPUBg0U6k8GQWy)mhK4qFyM9Q(XzMvnxRK57HePCtM0hfuKjJbDtiW8hwQoNHHaUkFUQk85x65OYtqZiSC5kSwRUVQ2(upVQrvBYhKN3ekjPbr7WT1Lani0ursW2O47808jg)iuAkH2eFtTF9i0yplF5nd02gIC3qtabL)MrJde0T4Ex3AiQDOsovTB(Hi1Q29zNfhaZntaKIw5ulgyaAoUKHO3wWvlhk3wD3hdeRbl65HiErUAg8nMes2cFmdZRUFO(IPzCWBY(Bq6ab3Co)5nQdNwp8pq5EKgaoJmgvE)YlQdPd0qtG96McIoRbAVTq1PfPkSiXwGr73ZwEdwzg0X8qNqxXUZRxuOztHshGZf00T9ZYc333c1fy4(aUcPu9YQrqTPhyyI2jxb5(WRXDIJS51Zpy3JvFFbg7vjAUaCgSpiNCbAf)83iTnAPB7sFxZlXMsGpO94asHwtGBs5TO(wzw3WTEYLl62FcQvmacTUGMttew56QhBKdFU1HAocL(a9G)AOhjjm1GR8FKiYXTO)A)1ypLs9lsqtGiUc(8t6xOGMJ9tf7)G)6i4UpGVGGpMq32W9xBSU)6ETPAuCG5jmab8vakMwT2nPFA6fLav81tR4EDWFA624nrT)6EAVw6A3GT9AVfak5nJiz3BfGR82rwzNf9MFgqG182rwZjTvv6nGPZwx5b1kR)nUT9aNbLfJCR8YWzLH1Z74U5UYrQnzVlI7YIdVRURCJtl61bQ15ntKl0lI6aDwkzS0Itv(Xsw0xUV7(P92(6D0GY3jYQSUtJToTV)VtDQhS7nGkdV)UMXYiFVJ3T7DNmzHvzKtLcwrl2ZvnK0uBRHeNaKkdVDQmonlQboAEMj5f71aNTrRBIRvZ29c6V26aB0ctGiSRVPsPD2aOnkBBeSmCL1BUnSzq9gW(0yti86fUkcAnqxjwHh01cpt7JU2W9liAvOREe1yt3NyDEKUBrJphIW6qRLD3AklgA2XQJg0DOnIo3YV10Pzz4p(baJi7oT0Wyzz4fAG9ZA8u7TUUEdnvlOtvZQBuYgToGKNRJjgxciQ7ns2WunNAFyrHtV)7oziC)4qWyeRUxldFzZOnDW(ZbJ3IXQP63IOZSt7wf7gc725R2uJrPni4nHh3vhXALpg3XV8(OMiEYgbmVKwxmB92AtrMzENTPOZg)aiRtFCFkYONb9wNeypBN0Kb7Po5XBXunc4S3KopN2u0xc2bBbD90ngNXnMZVTFoOEBiZJEn(gXoLS6XVMIEQ77zDIG0fD1)lk86r3oad8RDXm1MTVVJnM0ZzEoTo5O9Eun9CUX5Q6GZiPpVBsol9JL1bO2VP2KCq4ZW1V7ZopBN(GUZAjEBFxU))s)yFOPJhGt7I0frAAksHAhhoM(Fv))6noQ))m]] )

spec:RegisterPack( "Balance", 20261027.1212, [[Hekili:TMv4oonoq4NLviTaI9620LchODxPd4qasGoDfj(xsCtCASAsCLTZwbAvE2VzCItCsCYwTC)aO12ZmFZ4z(80bFp)V7VjMOO(FB1YvVYB5QxVWBL3k)nQFEG6V5ajApzh8Hcso83VJKrkI0R)ZmojgLwYlf4sPk1b5BV8YDmvA52fr88ltPcYEwgR9d(B2wYYuFUWF7eMvEGg5)nppyBQmQ1IvHpJKj5vHjCrv4)sLkUGOy8INFrv47ZisjlQk8VfeaAcEclda0tEsvyR4FquYIbTyF2QqVfERF(IQWQW)sR9sjnESnaX(efHFvymNklEQc)qvykLKXk2bk4lOT2OdeY32hqvHBnyyhabQe02p4hbzJToyho)NnnheCSFqercscyUVtUJkaG8voVypRO7iQuANA0Wi3Ce4giVSGP(5tbBUrrejmb9pKhi5vHcUs7Aay)iHkyGs(iSBvilPkSa8noOyikeJHTlQTBI(axwf(5cjnca1MJebOlmaLXl2bGHi2rvYlAIhnMSN4htH7geK3broyNpvkeSisbTjSJjCste9Re0pkk3J64d8VdAUhCHVMtkiORcqsCxZTfPiUNIBGfSbIa4SkbpldVPr1RJGnPhsQsb4sc2V6lKiuDYfheuiuULOEXnxMte7d4jbGqbhzzXxWsU5STLjjlgUZIYdNxVZowIAWoUvopNwGhmkJiGRToDpyJjvqZvFaejZ7Kg)MwK6G6N1ri8pSCsMoSNFb(pzz8Jy4GOQxetBm5jlAniygrzrq93cYys1fi3WnrefAsTfHph0A1hqUTuIOvq8lUK02XSxprNmeOZYaD0E9zT(5N1KCqdWCLZplMwhv6ocEvvNJSqXYPbkEqmJER3ABtLAYNqdHldkKwqZzu5TDgU9ubnjDdm)qNYG866HwWz2AqyGPl8cKyDxp)nMRcS3COt3Ow7JSqqZHYl51Eo99LtH0E20SXe2R1nEK2QoQyVR0WPa7I8cbMfCP4AXwyocKwkvb4bS14rGJp1uB8Em3)Jy(xxbwKU0sqUdEhenB9Nc4hGBFXWJDGxI04dw1kxlibEkmB6K1tp7C5qRyQ6qLFGFKkKPiZtbuvp0zyhWdH8g8GdCwHc2bYCPfQBVz95BZO0yzWrsHIg3cjqOjGsNRaNjqPIh5)ubpIXlLbBzk6mM(Xk4voG11VC8D4EToMW)GD7iTJYaQimHb8lCvx2961UIgVzOzLPcQ(HIT0uwrCdZWOBVmYXAoB7tD)zMKyujl2dxMfMK13biCu2kYGwh4izbrPOsUa6QbE9ijyxu8nEOnAqnVujHUiETXlocDUXkwTEK22sKPJnbec(fJghiO7Wsb97eO2X2IuPloePUUlhV3HdG9oxavrw3GlhzaAbEKXO3wWRxnwUyAo04wg7xGLde86NxEwhVfSTE57hWIV65gERrAOLa7Q20LENrMcXYEpl3Gf5r2bxVy4n6K5KYSX(AFXUXBquR1PqPdW9GUmeuaozXpklC7qlys)q)a6PxQErZkO20lmoX43KTB6G4eoVE)rEV)gOLzjONr)gd45Vcuq)n(BWgrK4pJbTf8VFt)lIOfeGKi2)D(BIGoUa0b)WIbvnvHNBATSTYXFtn093yxa6VXkQJwqbqAGzmYHLA4(xnX(oR6Srzx1xv41wD0oUcu7a2H0QWBVPk8QLO9F5KHH(saMy1Yo4vxZ6YHxpHdnQwZ2wpZYbARBRcV)EO91E5Ta0bGuf(CTt9qLXAyFL(ON5(0McAe5VAcKRt7SrRdiPD9xpzSCOeq43BIRL5k17WeUPRO)FEYq42PHWiUGQWx0UAlFWddM3mvU9qIdBC6IazWnyFAe0sElp17Uzc4UOxaLdok8YTlkdJrQ7uSVvS6DCoAG6(iNLi4)1GLnzMvZm1Pdojem4W01PT57395Cv)qdJ2c6QlR6BJ1Ae2RZTbouD)Pt7i2xPn9Pox1D)wpprq6QA)3rHxnP7aeyV0vHDxU3(E2y2ixDNVMvD1)REp348AZLZePpVzUsEDBT9WPD3VZwcJnmBljI8EnyRFM4SoARUoORREJPjabLZkyl8myEgwr4(tZOUvIG65KIedoQUhOw7PDCA6v3KYmKc2ZjzUIwRI)tL2O)ymE0CjRNJnOD6jZ(aLDH8O5T4eUZvNBM3GTjBM7qFN0AMmZvMBpJfNX2HZQz6a8mtTrx259WS2trp4YRDozNheDdNXZPISPyeM((y(h0BgYJTy9gq0CiYWqmAqrAto1Z76jhvtL0oe25Ahy4eIhsEnXuK7rl7ywYZ1gXGbh7YIJNT8jtW4qBg2mvDCHuQs5qh9FY8))dUQ))9]] )

spec:RegisterPackSelector( "balance", "Balance", "|T136096:0|t Balance",
    "If you have spent more points in |T136096:0|t Balance than in any other tree, this priority will be automatically selected for you.",
    function( tab1, tab2, tab3 )
        return tab1 > max( tab2, tab3 )
    end )

spec:RegisterPackSelector( "feral", "Feral", "|T132115:0|t Feral",
    "If you have spent more points in |T132115:0|t Feral Combat than in any other tree, this priority will be automatically selected for you.",
    function( tab1, tab2, tab3 )
        return tab2 > max( tab1, tab3 )
    end )

spec:RegisterPackSelector( "restoration", "Balance", "|T136041:0|t Restoration",
    "Herakili doesn't do healing: with most points in |T136041:0|t Restoration, the Balance (damage) priority is selected.",
    function( tab1, tab2, tab3 )
        return tab3 > max( tab1, tab2 )
    end )
