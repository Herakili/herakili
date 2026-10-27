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


spec:RegisterPack( "Feral", 20261027.1113, [[Hekili:TM1wVTTos4FlPhaFAqtDSsA6n4Khs7Py3cSDlQlqFts0su2ews0GKkU(Ga9B)mdPUqjrP6MDFOTYKCM5JZLpoK13Z)7(RIjkQ)xUAXvV2BXvVzUNN31(Ruh3t9xTNeTJSb(iNKb)9NOcsko6XuojgLvYlerWmBvQ9Y3F5LByQTfRNhXZUClS4DSuwZh(RwxWsv)7C)1Jyu5EAK)x88GPPYOk7vg(8pquLHF8RRkdj5XLH3tjIYqfjFxz46JLHjCr25xug(HuIuYIkd)lbbqPGNWsbS9h)rzyLM(OOGfJk0ALLHEZ9U583dYJM5tGYkdJjzW(UJ9mtGwLLVbSw0wUKMBqWrWnaJuie0CLbqZl)mA4vAhK89DrhSedG2a4Hkbe9d(HTusS1YQHmUTVS5NFxVRnIbG4herKGKOWjEGkY7VtBCAAWO6kSAl1YEviccDzf5m1X)eG1ZwTvqJHLEptHEdWo3a)Ap)avi3YsupRmuqqdj4kIIXZpVYNP1T9ovYYKv(K7PBz5XVewYlveXgQcu53y7V8BKDu4ZVk4hab47P5ub87VZ2qfiA(uH4yhRBce)hsr6LRoW2trZkOYT80yPnoIPRlssWHeudeI45kbpnLclHLxTSkFMKQqnJOT8ZKiCxjNVxqbpZAI6f3EzgrSlGNeacfCGLgFbl52ZqlmV)mZl2pZmZgaU9MXTY5z0CCHrPebefA1DVjgvbrevaMaIscJdU)ayOkyOZmhtYyMGgSgs2BK)ee63D97XORbBWhbhi5kA8mTC1iFuzvyMGmibZdanOscAMDGgMHzpBooVQO8UBR(Dg5Nv(clTPTyJnbljkYdm)kiLjvxG8F3cAhn7OyDm5qxuJGn(RtrYiIurBLnJZr2hxI7oQBVIUrx7zCoyTcprmIUpSWQHdTQw))QRIHsVebpRQ2gid)g5bn)Qz01AcbOuMdLhIdmjmZx5f5r05LH18fvfPggdGyfzMGIxSQo9a5OevJcrcSosUMy7aOsjVcyWpnlNNNcu2fsuCG0nxtFB4gcZ5QA4aKYm4hh4fPXDq2A4p7zr7QLN(aAuCTAWKaETyY6ukABoS5pFEB2CKopwO39yOY8vGHRR)Y2RDb9hDyrqvfGRS6bvbVDrF9LqOcgnibtp0C1OwB4aTMD2zgEu7XqtyIiGHZObkEqmJEN3cJt)Rnu1G3SsN4jTvdXluv00RHgnmmXG3tZ0J)dCS3p4PjsZjJMTsDmR(xOppLFyGpUtbrdmcY5hmq7g9rDR545jSCfEcnCguT2HWhnU6aJqdhL9bk1jHPShOA7NVbreVyZ2UzXWPX8igVqAocDyMaBpcqnscmaPnwDZmdmQjjR9)GqJ43BJBWAcuQ4bb7A8eSgGZeM(Pk41oG1YxnSayNwhJS)GzBp5mkfONqsgyFHJ6YUlVXL34D9nRu3ndAxDfEqvySFMdsCOpmZEvpEMzvZ1kz(oirk3Kj9jbfzYyq3ecm)HLQZzyiGRYNRQcF6LEoQ8e0mclxUeR1Q7RQTp1Nx1OQn5dYZBcLK0GOT426cGgeAQijytu8TEA(eJFeknLqBIVP2VEaASNLF1nd02AIC7qtabL)MrJde0n4Ex3AiQDOsovTD((i1Y29zNfhaZntaKIw5ulgyaAoUKHO3wWLxnuUn6Upgiwdw0Zdr8IC1m4BmjKSb(ygMxD3q9ftZ4G3K93G0bcU5C(N3OoCA9WpIY9anaCgzmQ8URoVoKoqdnb2RBki6SgO92cvNwKQWIeBbgTFpB5nyLzqhZdDcDf7wVErHMnfkDaoxqt32pjlCxFluxGH7d4kKs1lQgb1MEGHjANCfK7dVg3joYMxp)GDpw99nySxMO5cWzW(GCYfOv8tFJ02OLUTl9DnVaBkb(G2JdifAnbUjL3I6BLzDd36jVAr3(tqTIbqO1f0CAIWkxx9yJC4ZRDOMdqPpqp4Vc6rsctn4k)hiICCl6VYFf2tPu)Ie0eiIRGp)I(fkO5y)uX(37VkcU7d4li4Jj0TnC)vgR7VQxBQgfhyEcdqaFfGIPvRDt6NMErjqfF90kUxh8NMUnEtu7VQN2RLU2nyBV2BbGsEZis29wb4kF9iRSZIEZVciWAE7iR5K2Qk9gW0zRR8GAL1)g32EGZGYIrUvEz4SYW65DC3Cx5i1MS3fXDzXH3v3vUXPf96a168MjYf6frDGolLmwAXPk)yjl6l33D)0EBF9oAq57ezvw3PXwN23)3Po1d29gqLH3DBZyzKF2X729UtMSWQmYPsbROf75QgsAQT1qItasLHVEQmonlQboAEMj5f71aNTrRBIRvZ29c6VY6aB0ctGiSRVPsPD2aOnkBBeSmCP1BUnSzq9gW(0yti86fUkcAnqxjwIh01cpt7JU2W9liAvOREe1yt3NyDEKUBrJphIW6qRLD3yklgA2XQJg0DOnIEULFRPtZYWhFeGrKDNwAyCvz45AG9RA8u7TUUEdnvlOtvZQBuYgToGKNRJjgxciQ7ns2WunNAFyrHtV)7oziC34qWyeRUxldFrZOnDW(RbJ3IXQP63IOZSt7wf7gc725R2uJrPni4nHh3vhXALpg3XV9(OMiEYgbmVKwxmB92AtrMzENTPOZg)aiRtFCFkYONb9wNeypzN0Kb7Po5XBXunc4S3KopN2u0xc2EBbD90ngNXnMZVTFoOEBiZJEn(gXoLS6XVMIEQ77zDIG0fD1)lk86r3oad8RCXm1MTVRJnM0ZzEoTo5O9Eun9CUX5Y6GZiPpVBsol9JL1bO2VP2KCq4ZW1V7ZopBN(GUZAjEBFxU))s)yFOPJhGt7I0frAAksHAlhoM(Fv))6noQ))a]] )

spec:RegisterPack( "Balance", 20261027.1113, [[Hekili:TMvyVrnot4FlvivarVTBAzHJtTv6aErash60fKUVLeVjoBS2K4v2oDfOQ8B)MXjoXjXjDv59da7A7zMNz8mpE2HaVGVh4Nqu0GVD16REJ36RE7kppVRd8v)4anW)ajEpzh8Hssb83VNKtkJ1R)JCojbLwYRe4szk1b5FC5L7yQSQTRI5fxMrfK9SCw3hc83wXYvFPmy7mMvEGgh8nppyBQmUZI1rVGKl51rPCrD0)qLkUGOy8YxErD0hYjsjlUo6)jia0e8uwoaON9S6OoX)OOILaAX(S1rER828Yv1r1r)Pw7vsAYuBaI9zkc)6Oeovw(Cf(H6OmkjNvUduWxrB5RdeY)yiGQJ2AWWoacujOT)LFeKnX6G948V9Bpi4y)lreliPG5(o5EQaaYFX5L7zL9hrLr7vJggfMJa3afvLm1pEoytFfrKYe0FtEGuuhj4kTRbG9teQGbk5tWU1rS06OsW34GIHOqcg2UOXUP6dCzD0xkL0yau(hjcqxyakNxUdadrSJQKx0gpAn5aXpMb3niiVhICWoFUsiyXKsAByht4KMi6Frq)OSApQJpY)oO5bWf(AbPKGUkajX9T3wKYKbkUfwWgicGZQe88C8MgvVoc2MEiPkfGljy)6VsIr1jxDqqHq5wI6v3EzbrSpKNgccfEKLNCbl92Z2wLMUA8oRQoCEZo7yPQr74w58cAjEW4CIaU2619OnMvbTx9HqKSOxA8BArAcQFrhHW)Wki56WEXf4)KNZpIHdIQzrmTXKNSQZGGzevLHnFlmNjvxGCd3gtuOj1we(CyNvFe52sjIobXV4ssBhZE9uDYqOold0r31N16NFwBYbneZvo)SeAtuP)i4vvtoYkfRGgQ4Hjm6DEBSnvMjFcneUmOqAjTGrL31B4Utf2M0nY8JDkdYBQh6aNzRrHbMUWluI1Dd83eUk0EZXoDRATpYkbTakVK34503xphshytZgZyVo34jARMOI9UsdNcSlYleAwWLIBeBL5iqAPufIhWwJhbo(mtTXhWC)pH5F9fyX6slb5E4Dq0SnFkKFaU9fJp2bEfsJpAvRCTWu4PW85twp9SZ1JTIPQdv(b(rQqMHmpLqv9yNHDapeYBWdpWzLkyhiZLwQU72nNVnNstKHhjLkAshKaHMbk9UcCMqLkzI)tf8ygVsgULPOly6NQGx7aw386P3H716yg)d2TN0oohOIWegWVWvDz3B24kA8UXMvMjO6hk2sZyLjTmdtU9YjhB4STp1dNzsIrLSApCzwAswFpGWjzRidAtGJKhgNHk5cORg41J0WDXj36H2Of18kLe6I4TgV4i05gR8Qnt02wImBQjGqWpz0KqbDhwkOFNa1o2wKkB1Hy1n954doCiS35cOkY6gC9edqlXJmf92cEZvtLlHwanULZ(jy5qbV55Lx0ZBbBRx(HrS4x9sdV1en0rGDDx6YGZiZGy5GNLBXI8i7GRxm8MCYcsv(uFDOy36nkQ15uO0H4EqxgckaN8KNKfUBSfmPFOFa90lvVQDfuB6fMMy8lY2nFqCgNxV)eVpWhAzwc6zYVXaE(RefmWpWhBerI)mg0wW)(n9ViIwsasIKG3h4hdDCbOd(HfJQAQJo30AzxLtGFd0d8Tlad8TI6OfuaKgzgJCyPgU)1ZSVZQoBu2x9vhDJvhTtRa1oGDiTo6UBRJUEnA)xpByyOeGjUADp8AQzD5WBMXHMuRzBRxy5aD1T1rp8a0(6G8wa6aqQJEP2PESYynSVwF0ZCFAtbnI83mdY1PD2O1bK0U(BNnwowci87nZ1YsL69yc30v0)3pziC38qycxqD0R6wTJp4XbZ7Ml3EmXHnoDrGm6gCincAjV1N6D3cbCx0lGYbhfE52fLHXinDko0kw9oUenqtFKlse8)1GLnzMvZmnPdojem4W01PT5h295sv)qdJ2c6QlRMBJnAeoOZTrout)PZ7i2xPT9PUu19Wwpprq6QA)xrHxpR7aeyV2vHDFU3(b2yXixtNVMvD1)REp348gZLZmPpVBPsEDBTdWPD3VlwcJnmBljI8bnyRFM4SEAR(oOBQEtOPabLZkyl8mAEgwr4HtZOPvIWM5KIedoQUhPw7PDCA6v3KYcKc2ZjzPIwRI)tL2y4ymEYCjBwInOB6jl(aLDH8K5T4eUlvNBM3GTjBN7WqN0AMmlvMBpJfNX2XZQz(a8ctTrx2594S2Zrp4YRDozNhfDJNXZPIS5yeM)(y5h0BhYJTydgq0siYWqmzqrAto3Z76jh1qL0ne2LAhy8eIhtEnZuKhql7ywYl1gXObh7YItNT8jtW4qBg2mvtCHuPY4qh9F28))dUAW)b]] )

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
