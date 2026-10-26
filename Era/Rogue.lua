-- Era/Rogue.lua
-- Classic Era (1.15.x) Rogue.  Spell, rank, talent and aura IDs from the Classic Era client tables (1.15.9).

if UnitClassBase( 'player' ) ~= 'ROGUE' then return end

local addon, ns = ...
local Hekili = _G[ addon ]
local class, state = Hekili.Class, Hekili.State

local floor, min = math.floor, math.min

local GetItemInfoInstant = ( C_Item and C_Item.GetItemInfoInstant ) or _G.GetItemInfoInstant

local spec = Hekili:NewSpecialization( 4 )

-- Energy costs: the live client's cost for the rank you know (GetSpellPowerCost, talent reductions included), cached
-- for 10 seconds; the Era SpellPower table value with talent reductions applied is the fallback and the upper bound.
local GetSpellPowerCost = _G.GetSpellPowerCost or ( C_Spell and C_Spell.GetSpellPowerCost )
local cost_cache = {}

local function energy_cost( key, fallback )
    local ability = class.abilities[ key ]
    local id = ability and ability.id
    if not id or not GetSpellPowerCost then return fallback end

    local now = GetTime()
    local c = cost_cache[ id ]

    if not c or now - c.t > 10 then
        local value
        local ok, costs = pcall( GetSpellPowerCost, id )
        if ok and type( costs ) == "table" then
            for _, p in ipairs( costs ) do
                if type( p ) == "table" and p.type == Enum.PowerType.Energy and type( p.cost ) == "number" then
                    value = p.cost
                    break
                end
            end
        end
        c = { t = now, v = value }
        cost_cache[ id ] = c
    end

    -- min(): talent reductions apply whether or not the client's number already includes them.
    return c.v and min( c.v, fallback ) or fallback
end



-- Energy: Classic Era regenerates energy in ticks of 20 every 2 seconds (40 with Adrenaline Rush), not smoothly.
-- The tick phase is learned from the client: an energy gain of exactly one tick marks a tick.
local ENERGY_TICK = 2
local energy_tick = 0       -- GetTime() of the last tick seen.
local last_energy = -1

local function energy_tick_value( now )
    return state.buff.adrenaline_rush.expires >= now and 40 or 20
end

spec:RegisterResource( Enum.PowerType.ComboPoints )

spec:RegisterResource( Enum.PowerType.Energy, {
    energy_tick = {
        last = function ()
            local t = state.query_time
            -- Without an observed tick the phase is unknown; assume the next tick is half an interval away.
            local base = energy_tick > 0 and energy_tick or ( state.now - ENERGY_TICK / 2 )

            return base + floor( ( t - base ) / ENERGY_TICK ) * ENERGY_TICK
        end,

        interval = ENERGY_TICK,
        value = energy_tick_value,
    },
}, nil, {
    -- No smooth regeneration: all passive energy comes from the tick model above.
    regen = function () return 0 end,
} )

spec:RegisterUnitEvent( "UNIT_POWER_FREQUENT", "player", nil, function( event, unit, powerType )
    if powerType ~= "ENERGY" then return end

    local energy = UnitPower( "player", Enum.PowerType.Energy )
    local diff = energy - last_energy
    last_energy = energy

    if diff == 20 or diff == 40 then energy_tick = GetTime() end
end )


-- Talents: { talentID, maxRank, rank1SpellID, ... rankNSpellID }, from the Classic Era client's Talent table.
spec:RegisterTalents( {
    -- Assassination
    improved_eviscerate        = {   276, 3, 14162, 14163, 14164 },
    remorseless_attacks        = {   272, 2, 14144, 14148 },
    malice                     = {   270, 5, 14138, 14139, 14140, 14141, 14142 },
    ruthlessness               = {   273, 3, 14156, 14160, 14161 },
    murder                     = {   274, 2, 14158, 14159 },
    improved_slice_and_dice    = {   277, 3, 14165, 14166, 14167 },
    relentless_strikes         = {   281, 1, 14179 },
    improved_expose_armor      = {   278, 2, 14168, 14169 },
    lethality                  = {   269, 5, 14128, 14132, 14135, 14136, 14137 },
    vile_poisons               = {   682, 5, 16513, 16514, 16515, 16719, 16720 },
    improved_poisons           = {   268, 5, 14113, 14114, 14115, 14116, 14117 },
    cold_blood                 = {   280, 1, 14177 },
    improved_kidney_shot       = {   279, 3, 14174, 14175, 14176 },
    seal_fate                  = {   283, 5, 14186, 14190, 14193, 14194, 14195 },
    vigor                      = {   382, 1, 14983 },

    -- Combat
    improved_gouge             = {   203, 3, 13741, 13793, 13792 },
    improved_sinister_strike   = {   201, 2, 13732, 13863 },
    lightning_reflexes         = {   186, 5, 13712, 13788, 13789, 13790, 13791 },
    improved_backstab          = {   202, 3, 13733, 13865, 13866 },
    deflection                 = {   187, 5, 13713, 13853, 13854, 13855, 13856 },
    precision                  = {   181, 5, 13705, 13832, 13843, 13844, 13845 },
    endurance                  = {   204, 2, 13742, 13872 },
    riposte                    = {   301, 1, 14251 },
    improved_sprint            = {   222, 2, 13743, 13875 },
    improved_kick              = {   206, 2, 13754, 13867 },
    dagger_specialization      = {   182, 5, 13706, 13804, 13805, 13806, 13807 },
    dual_wield_specialization  = {   221, 5, 13715, 13848, 13849, 13851, 13852 },
    mace_specialization        = {   184, 5, 13709, 13800, 13801, 13802, 13803 },
    blade_flurry               = {   223, 1, 13877 },
    sword_specialization       = {   242, 5, 13960, 13961, 13962, 13963, 13964 },
    fist_weapon_specialization = {   183, 5, 13707, 13966, 13967, 13968, 13969 },
    weapon_expertise           = {  1703, 2, 30919, 30920 },
    aggression                 = {  1122, 3, 18427, 18428, 18429 },
    adrenaline_rush            = {   205, 1, 13750 },

    -- Subtlety
    master_of_deception        = {   241, 5, 13958, 13970, 13971, 13972, 13973 },
    opportunity                = {   261, 5, 14057, 14072, 14073, 14074, 14075 },
    sleight_of_hand            = {  1700, 2, 30892, 30893 },
    elusiveness                = {   247, 2, 13981, 14066 },
    camouflage                 = {   244, 5, 13975, 14062, 14063, 14064, 14065 },
    initiative                 = {   245, 3, 13976, 13979, 13980 },
    ghostly_strike             = {   303, 1, 14278 },
    improved_ambush            = {   263, 3, 14079, 14080, 14081 },
    setup                      = {   246, 3, 13983, 14070, 14071 },
    improved_sap               = {   262, 3, 14076, 14094, 14095 },
    serrated_blades            = {  1123, 3, 14171, 14172, 14173 },
    heightened_senses          = {  1701, 2, 30894, 30895 },
    preparation                = {   284, 1, 14185 },
    dirty_deeds                = {   265, 2, 14082, 14083 },
    hemorrhage                 = {   681, 1, 16511 },
    deadliness                 = {  1702, 5, 30902, 30903, 30904, 30905, 30906 },
    premeditation              = {   381, 1, 14183 },
} )


-- Auras
spec:RegisterAuras( {
    -- Energy regeneration increased by 100%.
    adrenaline_rush = {
        id = 13750,
        duration = 15,
        max_stack = 1,
    },
    -- Attack speed increased by 20%; attacks strike an additional nearby opponent.
    blade_flurry = {
        id = 13877,
        duration = 15,
        max_stack = 1,
    },
    blind = {
        id = 2094,
        duration = 10,
        max_stack = 1,
    },
    cheap_shot = {
        id = 1833,
        duration = 4,
        max_stack = 1,
    },
    -- Critical strike chance of your next Sinister Strike, Backstab, Ambush or Eviscerate increased by 100%.
    cold_blood = {
        id = 14177,
        duration = 3600,
        max_stack = 1,
    },
    evasion = {
        id = 5277,
        duration = 15,
        max_stack = 1,
    },
    expose_armor = {
        id = 11198,
        duration = 30,
        max_stack = 1,
        shared = "target",
        copy = { 8647, 8649, 8650, 11197, 11198 },
    },
    garrote = {
        id = 11290,
        duration = 18,
        tick_time = 3,
        max_stack = 1,
        copy = { 703, 8631, 8632, 8633, 11289, 11290 },
    },
    ghostly_strike = {
        id = 14278,
        duration = 7,
        max_stack = 1,
    },
    gouge = {
        id = 11286,
        duration = function() return 4 + 0.5 * talent.improved_gouge.rank end,
        max_stack = 1,
        copy = { 1776, 1777, 8629, 11285, 11286 },
    },
    -- Increases Physical damage taken; 30 charges.
    hemorrhage = {
        id = 17348,
        duration = 15,
        max_stack = 30,
        shared = "target",
        copy = { 16511, 17347, 17348 },
    },
    kidney_shot = {
        id = 8643,
        duration = 6,
        max_stack = 1,
        copy = { 408, 8643 },
    },
    -- Disarmed.
    riposte = {
        id = 14251,
        duration = 6,
        max_stack = 1,
    },
    -- Pseudo-aura: you parried, so Riposte is usable for 5 seconds.
    riposte_ready = {
        duration = 5,
        max_stack = 1,
    },
    rupture = {
        id = 11275,
        duration = function() return 6 + 2 * combo_points.current end,
        tick_time = 2,
        max_stack = 1,
        copy = { 1943, 8639, 8640, 11273, 11274, 11275 },
    },
    sap = {
        id = 11297,
        duration = 45,
        max_stack = 1,
        copy = { 6770, 2070, 11297 },
    },
    -- Melee attack speed increased by 20%.
    slice_and_dice = {
        id = 6774,
        duration = function() return ( 6 + 3 * max( 1, combo_points.current ) ) * ( 1 + 0.15 * talent.improved_slice_and_dice.rank ) end,
        max_stack = 1,
        copy = { 5171, 6774 },
    },
    sprint = {
        id = 11305,
        duration = 15,
        max_stack = 1,
        copy = { 2983, 8696, 11305 },
    },
    stealth = {
        id = 1787,
        duration = 3600,
        max_stack = 1,
        copy = { 1784, 1785, 1786, 1787 },
    },
    -- Armor reduced (warriors' Sunder Armor; Expose Armor does not stack with it).
    sunder_armor = {
        id = 11597,
        duration = 30,
        max_stack = 5,
        shared = "target",
        copy = { 7386, 7405, 8380, 11596, 11597 },
    },
    vanish = {
        id = 11329,
        duration = 10,
        max_stack = 1,
        copy = { 11327, 11329 },
    },
} )


spec:RegisterStateTable( "stealthed", setmetatable( {}, {
    __index = function( t, k )
        if k == "rogue" or k == "mantle" then
            return buff.stealth.up or buff.vanish.up
        elseif k == "rogue_remains" or k == "mantle_remains" then
            return max( buff.stealth.remains, buff.vanish.remains )
        elseif k == "all" then
            return buff.stealth.up or buff.vanish.up or buff.shadowmeld.up
        elseif k == "remains" or k == "all_remains" then
            return max( buff.stealth.remains, buff.vanish.remains, buff.shadowmeld.remains )
        end

        return false
    end
} ) )


-- Main-hand weapon: Backstab and Ambush need a dagger (item subclass 15).
local mainhand_dagger = false

local function UpdateWeapon()
    mainhand_dagger = false

    local item = GetInventoryItemID( "player", 16 )
    if item and GetItemInfoInstant then
        local _, _, _, _, _, classID, subclassID = GetItemInfoInstant( item )
        mainhand_dagger = classID == 2 and subclassID == 15
    end
end

spec:RegisterStateExpr( "mainhand_dagger", function() return mainhand_dagger end )

-- Positional abilities (Backstab, Ambush, Garrote) can't be checked by the client; the setting says where you stand.
spec:RegisterStateExpr( "behind_target", function() return settings.behind_target ~= false end )

-- Stealth openers (setting "Stealth Opener").
spec:RegisterStateExpr( "opener_enabled", function() return settings.opener ~= "none" end )

spec:RegisterStateExpr( "opener_ambush", function()
    local o = settings.opener
    return o == "auto" or o == "ambush"
end )

spec:RegisterStateExpr( "opener_cheap_shot", function()
    local o = settings.opener
    return o == "cheap_shot" or o == "auto" and not target.is_boss
end )

spec:RegisterStateExpr( "opener_garrote", function()
    local o = settings.opener
    return o == "auto" or o == "garrote"
end )

-- Rupture (setting "Use Rupture").
spec:RegisterStateExpr( "rupture_wanted", function()
    local mode = settings.rupture_mode
    if mode == "always" then return true end
    if mode == "noraid" then return not raid end
    return false
end )

-- Expose Armor (setting "Maintain Expose Armor").
spec:RegisterStateExpr( "expose_wanted", function()
    local mode = settings.expose_mode
    if mode == "always" then return true end
    if mode == "no_sunder" then return not debuff.sunder_armor.up end
    return false
end )

spec:RegisterStateExpr( "finish_cp", function()
    return min( combo_points.max, settings.finish_cp or 5 )
end )


-- Slice and Dice: 6 s + 3 s per combo point, Improved Slice and Dice +15% per rank.
spec:RegisterStateFunction( "snd_duration", function( cp )
    return ( 6 + 3 * cp ) * ( 1 + 0.15 * talent.improved_slice_and_dice.rank )
end )


-- Relentless Strikes: 20% chance per combo point to restore 25 energy; guaranteed with 5 points.
spec:RegisterHook( "spend", function( amt, resource )
    if resource == "combo_points" and amt >= 5 and talent.relentless_strikes.enabled then
        gain( 25, "energy" )
    end
end )


-- Cold Blood is consumed by the next Sinister Strike, Backstab, Ambush or Eviscerate.
local cold_blood_consumers = {
    sinister_strike = true,
    backstab = true,
    ambush = true,
    eviscerate = true,
}

-- Attacking breaks stealth.
spec:RegisterHook( "runHandler", function( action )
    local a = class.abilities[ action ]

    if a and a.startsCombat and stealthed.all then
        removeBuff( "stealth" )
        removeBuff( "vanish" )
        removeBuff( "shadowmeld" )
        setCooldown( "stealth", 10 )
    end

    if cold_blood_consumers[ action ] and buff.cold_blood.up then removeBuff( "cold_blood" ) end
end )


-- Combat log: we parried (Riposte).
local parried = 0

spec:RegisterCombatLogEvent( function( _, subtype, _, sourceGUID, _, _, _, destGUID, _, _, _, ... )
    if destGUID ~= state.GUID then return end
    if subtype ~= "SWING_MISSED" and subtype ~= "SPELL_MISSED" then return end

    local missType
    if subtype == "SWING_MISSED" then missType = ...
    else missType = select( 4, ... ) end

    if missType == "PARRY" then parried = GetTime() end
end )


spec:RegisterHook( "reset_precast", function()
    UpdateWeapon()

    -- Stealth is the rogue's only shapeshift form.
    if GetShapeshiftForm() > 0 and not buff.stealth.up then applyBuff( "stealth" ) end

    if now == query_time and parried > 0 and now - parried < 5 then
        applyBuff( "riposte_ready", parried + 5 - now )
    end
end )


-- Abilities
spec:RegisterAbilities( {
    -- Increases your Energy regeneration rate by 100% for 15 sec.
    adrenaline_rush = {
        id = 13750,
        cast = 0,
        cooldown = 300,
        gcd = "totem",

        talent = "adrenaline_rush",
        startsCombat = false,
        texture = 136206,

        toggle = "cooldowns",

        handler = function()
            applyBuff( "adrenaline_rush" )
        end,
    },


    -- Ambush the target.  Must be stealthed and behind the target.  Requires a dagger in the main hand.  Awards 1 combo point.
    ambush = {
        id = 11269,
        cast = 0,
        cooldown = 0,
        gcd = "totem",

        spend = function() return energy_cost( "ambush", 60 ) end,
        spendType = "energy",

        startsCombat = true,
        texture = 132282,

        usable = function()
            if not stealthed.all then return false, "must be stealthed" end
            if not mainhand_dagger then return false, "requires a dagger in the main hand" end
            return behind_target, "must be behind the target"
        end,

        handler = function()
            gain( 1, "combo_points" )
        end,

        copy = { 8676, 8724, 8725, 11267, 11268 },
    },


    -- Backstab the target.  Must be behind the target.  Requires a dagger in the main hand.  Awards 1 combo point.
    backstab = {
        id = 25300,
        cast = 0,
        cooldown = 0,
        gcd = "totem",

        spend = function() return energy_cost( "backstab", 60 ) end,
        spendType = "energy",

        startsCombat = true,
        texture = 132090,

        usable = function()
            if not mainhand_dagger then return false, "requires a dagger in the main hand" end
            return behind_target, "must be behind the target"
        end,

        handler = function()
            gain( 1, "combo_points" )
        end,

        copy = { 53, 2589, 2590, 2591, 8721, 11279, 11280, 11281 },
    },


    -- Increases your attack speed by 20%.  In addition, attacks strike an additional nearby opponent.  Lasts 15 sec.
    blade_flurry = {
        id = 13877,
        cast = 0,
        cooldown = 120,
        gcd = "totem",

        spend = function() return energy_cost( "blade_flurry", 25 ) end,
        spendType = "energy",

        talent = "blade_flurry",
        startsCombat = false,
        texture = 132350,

        toggle = "cooldowns",

        handler = function()
            applyBuff( "blade_flurry" )
        end,
    },


    blind = {
        id = 2094,
        cast = 0,
        cooldown = 300,
        gcd = "totem",

        spend = function() return energy_cost( "blind", 30 ) end,
        spendType = "energy",

        startsCombat = true,
        texture = 136175,

        toggle = "interrupts",

        handler = function()
            applyDebuff( "target", "blind" )
        end,
    },


    -- Stuns the target for 4 sec.  Must be stealthed.  Awards 2 combo points.
    cheap_shot = {
        id = 1833,
        cast = 0,
        cooldown = 0,
        gcd = "totem",

        spend = function() return energy_cost( "cheap_shot", 60 - 10 * talent.dirty_deeds.rank ) end,
        spendType = "energy",

        startsCombat = true,
        texture = 132092,

        usable = function() return stealthed.all, "must be stealthed" end,

        handler = function()
            applyDebuff( "target", "cheap_shot" )
            gain( 2, "combo_points" )
        end,
    },


    -- Your next Sinister Strike, Backstab, Ambush or Eviscerate is a critical strike.
    cold_blood = {
        id = 14177,
        cast = 0,
        cooldown = 180,
        gcd = "off",

        talent = "cold_blood",
        startsCombat = false,
        texture = 135988,

        toggle = "cooldowns",

        nobuff = "cold_blood",

        handler = function()
            applyBuff( "cold_blood" )
        end,
    },


    evasion = {
        id = 5277,
        cast = 0,
        cooldown = function() return 300 - 45 * talent.endurance.rank end,
        gcd = "off",

        startsCombat = false,
        texture = 136205,

        toggle = "defensives",

        handler = function()
            applyBuff( "evasion" )
        end,
    },


    -- Finishing move that causes damage per combo point.
    eviscerate = {
        id = 31016,
        cast = 0,
        cooldown = 0,
        gcd = "totem",

        spend = function() return energy_cost( "eviscerate", 35 ) end,
        spendType = "energy",

        startsCombat = true,
        texture = 132292,

        usable = function() return combo_points.current > 0, "requires combo points" end,

        handler = function()
            spend( combo_points.current, "combo_points" )
        end,

        copy = { 2098, 6760, 6761, 6762, 8623, 8624, 11299, 11300 },
    },


    -- Finishing move that reduces the target's armor for 30 sec.
    expose_armor = {
        id = 11198,
        cast = 0,
        cooldown = 0,
        gcd = "totem",

        spend = function() return energy_cost( "expose_armor", 25 ) end,
        spendType = "energy",

        startsCombat = true,
        texture = 132354,

        usable = function() return combo_points.current > 0, "requires combo points" end,

        handler = function()
            applyDebuff( "target", "expose_armor" )
            spend( combo_points.current, "combo_points" )
        end,

        copy = { 8647, 8649, 8650, 11197 },
    },


    feint = {
        id = 25302,
        cast = 0,
        cooldown = 10,
        gcd = "totem",

        spend = function() return energy_cost( "feint", 20 ) end,
        spendType = "energy",

        startsCombat = false,
        texture = 132294,

        toggle = "defensives",

        handler = function() end,

        copy = { 1966, 6768, 8637, 11303 },
    },


    -- Garrote the enemy.  Must be stealthed and behind the target.  Awards 1 combo point.
    garrote = {
        id = 11290,
        cast = 0,
        cooldown = 0,
        gcd = "totem",

        spend = function() return energy_cost( "garrote", 50 - 10 * talent.dirty_deeds.rank ) end,
        spendType = "energy",

        startsCombat = true,
        texture = 132297,

        usable = function()
            if not stealthed.all then return false, "must be stealthed" end
            return behind_target, "must be behind the target"
        end,

        handler = function()
            applyDebuff( "target", "garrote" )
            gain( 1, "combo_points" )
        end,

        copy = { 703, 8631, 8632, 8633, 11289 },
    },


    -- 125% weapon damage and 15% dodge for 7 sec.  Awards 1 combo point.
    ghostly_strike = {
        id = 14278,
        cast = 0,
        cooldown = 20,
        gcd = "totem",

        spend = function() return energy_cost( "ghostly_strike", 40 ) end,
        spendType = "energy",

        talent = "ghostly_strike",
        startsCombat = true,
        texture = 136136,

        handler = function()
            applyBuff( "ghostly_strike" )
            gain( 1, "combo_points" )
        end,
    },


    gouge = {
        id = 11286,
        cast = 0,
        cooldown = 10,
        gcd = "totem",

        spend = function() return energy_cost( "gouge", 45 ) end,
        spendType = "energy",

        startsCombat = true,
        texture = 132155,

        handler = function()
            applyDebuff( "target", "gouge" )
            gain( 1, "combo_points" )
        end,

        copy = { 1776, 1777, 8629, 11285 },
    },


    -- An instant strike that makes the target take more Physical damage (30 charges).  Awards 1 combo point.
    hemorrhage = {
        id = 17348,
        cast = 0,
        cooldown = 0,
        gcd = "totem",

        spend = function() return energy_cost( "hemorrhage", 35 ) end,
        spendType = "energy",

        talent = "hemorrhage",
        startsCombat = true,
        texture = 136168,

        handler = function()
            applyDebuff( "target", "hemorrhage", nil, 30 )
            gain( 1, "combo_points" )
        end,

        copy = { 16511, 17347 },
    },


    -- Interrupts spellcasting and locks that school for 5 sec.
    kick = {
        id = 1769,
        cast = 0,
        cooldown = 10,
        gcd = "totem",

        spend = function() return energy_cost( "kick", 25 ) end,
        spendType = "energy",

        startsCombat = true,
        texture = 132219,

        toggle = "interrupts",

        debuff = "casting",
        readyTime = state.timeToInterrupt,

        handler = function()
            interrupt()
        end,

        copy = { 1766, 1767, 1768 },
    },


    -- Finishing move that stuns the target.
    kidney_shot = {
        id = 8643,
        cast = 0,
        cooldown = 20,
        gcd = "totem",

        spend = function() return energy_cost( "kidney_shot", 25 ) end,
        spendType = "energy",

        startsCombat = true,
        texture = 132298,

        toggle = "interrupts",

        usable = function() return combo_points.current > 0, "requires combo points" end,

        handler = function()
            applyDebuff( "target", "kidney_shot", combo_points.current + ( known_id_kidney() == 8643 and 1 or 0 ) )
            spend( combo_points.current, "combo_points" )
        end,

        copy = { 408 },
    },


    -- Adds 2 combo points to your target.  Must be stealthed.
    premeditation = {
        id = 14183,
        cast = 0,
        cooldown = 120,
        gcd = "off",

        talent = "premeditation",
        startsCombat = false,
        texture = 136183,

        usable = function() return stealthed.all and combo_points.current <= 3, "must be stealthed, with 3 or fewer combo points" end,

        handler = function()
            gain( 2, "combo_points" )
        end,
    },


    -- Finishes the cooldown on your other Rogue abilities.
    preparation = {
        id = 14185,
        cast = 0,
        cooldown = 600,
        gcd = "totem",

        talent = "preparation",
        startsCombat = false,
        texture = 136121,

        toggle = "cooldowns",

        handler = function()
            setCooldown( "vanish", 0 )
            setCooldown( "evasion", 0 )
            setCooldown( "sprint", 0 )
            setCooldown( "blind", 0 )
            setCooldown( "cold_blood", 0 )
            setCooldown( "premeditation", 0 )
            setCooldown( "ghostly_strike", 0 )
            setCooldown( "kidney_shot", 0 )
            setCooldown( "gouge", 0 )
        end,
    },


    -- A strike that becomes active after parrying.  Disarms the target.
    riposte = {
        id = 14251,
        cast = 0,
        cooldown = 6,
        gcd = "off",

        spend = function() return energy_cost( "riposte", 10 ) end,
        spendType = "energy",

        talent = "riposte",
        startsCombat = true,
        texture = 132336,

        buff = "riposte_ready",

        handler = function()
            removeBuff( "riposte_ready" )
            applyDebuff( "target", "riposte" )
        end,
    },


    -- Finishing move that causes damage over time.  Lasts longer per combo point.
    rupture = {
        id = 11275,
        cast = 0,
        cooldown = 0,
        gcd = "totem",

        spend = function() return energy_cost( "rupture", 25 ) end,
        spendType = "energy",

        startsCombat = true,
        texture = 132302,

        usable = function() return combo_points.current > 0, "requires combo points" end,

        handler = function()
            applyDebuff( "target", "rupture", 6 + 2 * combo_points.current )
            spend( combo_points.current, "combo_points" )
        end,

        copy = { 1943, 8639, 8640, 11273, 11274 },
    },


    sap = {
        id = 11297,
        cast = 0,
        cooldown = 0,
        gcd = "totem",

        spend = function() return energy_cost( "sap", 65 ) end,
        spendType = "energy",

        startsCombat = false,
        texture = 132310,

        usable = function() return stealthed.all and combat == 0, "must be stealthed and out of combat" end,

        handler = function()
            applyDebuff( "target", "sap" )
        end,

        copy = { 6770, 2070 },
    },


    -- An instant strike that causes damage in addition to your normal weapon damage.  Awards 1 combo point.
    sinister_strike = {
        id = 11294,
        cast = 0,
        cooldown = 0,
        gcd = "totem",

        spend = function() return energy_cost( "sinister_strike", 45 - ( talent.improved_sinister_strike.rank == 2 and 5 or 3 * talent.improved_sinister_strike.rank ) ) end,
        spendType = "energy",

        startsCombat = true,
        texture = 136189,

        handler = function()
            gain( 1, "combo_points" )
        end,

        copy = { 1752, 1757, 1758, 1759, 1760, 8621, 11293 },
    },


    -- Finishing move that increases melee attack speed by 20%.  Lasts longer per combo point.
    slice_and_dice = {
        id = 6774,
        cast = 0,
        cooldown = 0,
        gcd = "totem",

        spend = function() return energy_cost( "slice_and_dice", 25 ) end,
        spendType = "energy",

        startsCombat = false,
        texture = 132306,

        usable = function() return combo_points.current > 0, "requires combo points" end,

        handler = function()
            applyBuff( "slice_and_dice", snd_duration( combo_points.current ) )
            spend( combo_points.current, "combo_points" )
        end,

        copy = { 5171 },
    },


    sprint = {
        id = 11305,
        cast = 0,
        cooldown = function() return 300 - 45 * talent.endurance.rank end,
        gcd = "off",

        startsCombat = false,
        texture = 132307,

        toggle = "defensives",

        handler = function()
            applyBuff( "sprint" )
        end,

        copy = { 2983, 8696 },
    },


    stealth = {
        id = 1787,
        cast = 0,
        cooldown = 0,
        gcd = "off",

        startsCombat = false,
        texture = 132320,

        usable = function() return combat == 0 and not stealthed.all, "must be out of combat and not stealthed" end,

        handler = function()
            applyBuff( "stealth" )
        end,

        copy = { 1784, 1785, 1786 },
    },


    -- Restores 100 energy.
    thistle_tea = {
        cast = 0,
        cooldown = 300,
        gcd = "off",

        item = 7676,
        startsCombat = false,

        usable = function() return settings.thistle_tea, "disabled in the Rogue settings" end,

        handler = function()
            gain( 100, "energy" )
        end,
    },


    vanish = {
        id = 1857,
        cast = 0,
        cooldown = function() return 300 - 45 * talent.elusiveness.rank end,
        gcd = "off",

        startsCombat = false,
        texture = 132331,

        toggle = "defensives",

        handler = function()
            applyBuff( "vanish" )
            applyBuff( "stealth" )
        end,

        copy = { 1856 },
    },
} )


spec:RegisterStateFunction( "known_id_kidney", function()
    local a = class.abilities.kidney_shot
    return a and a.id
end )


-- Settings
spec:RegisterSetting( "rogue_description", nil, {
    type = "description",
    name = "Adjust the settings below to match your gear, your position and your raid.  The defaults follow the common Classic Era " ..
        "rogue guides; a simulator for your own character is the best way to fine-tune them."
} )

spec:RegisterSetting( "rotation_header", nil, {
    type = "header",
    name = "Rotation"
} )

spec:RegisterSetting( "finish_cp", 5, {
    type = "range",
    name = "Eviscerate Combo Points",
    desc = "Eviscerate is recommended once you have at least this many combo points.  5 gets the most from every finisher and " ..
        "makes Relentless Strikes always refund 25 energy; Seal Fate builds still usually go to 5.",
    width = "full",
    min = 1,
    max = 5,
    step = 1,
} )

spec:RegisterSetting( "snd_refresh", 3, {
    type = "range",
    name = "Slice and Dice Refresh Window",
    desc = "Slice and Dice is refreshed with whatever combo points you have once it has less than this many seconds left.  " ..
        "Energy is pooled for it, so a builder doesn't leave you short when it falls off.",
    width = "full",
    min = 0,
    max = 10,
    step = 0.5,
} )

spec:RegisterSetting( "rupture_mode", "noraid", {
    type = "select",
    name = "Use Rupture",
    desc = "Rupture is recommended at 5 combo points (instead of Eviscerate) when it isn't on the target and the target lives long " ..
        "enough for all of it.  In raids, Eviscerate usually does more damage, so Rupture is off there by default.",
    width = "full",
    values = {
        never = "Never",
        noraid = "Outside raids",
        always = "Always",
    },
} )

spec:RegisterSetting( "expose_mode", "never", {
    type = "select",
    name = "Maintain Expose Armor",
    desc = "Expose Armor at 5 combo points, kept up on the target.  It doesn't stack with Sunder Armor, so leave it off in raids " ..
        "where a warrior sunders; \"Without Sunder Armor\" only uses it when the target has no Sunder Armor.",
    width = "full",
    values = {
        never = "Never",
        no_sunder = "Without Sunder Armor",
        always = "Always",
    },
} )

spec:RegisterSetting( "blade_flurry_single", true, {
    type = "toggle",
    name = "Blade Flurry on a Single Target",
    desc = "When enabled, Blade Flurry is used on cooldown for its attack speed even against one target (with the Cooldowns toggle).  " ..
        "When disabled, it's only recommended with 2 or more enemies nearby.  Mind crowd-controlled enemies next to your target.",
    width = "full",
} )

spec:RegisterSetting( "position_header", nil, {
    type = "header",
    name = "Position and Openers"
} )

spec:RegisterSetting( "behind_target", true, {
    type = "toggle",
    name = "Attacking From Behind",
    desc = "The game doesn't tell addons where you stand.  When enabled, Backstab, Ambush and Garrote are recommended (you're behind " ..
        "the target, as in raids).  Disable it when you tank or face the target, so Sinister Strike is used instead.",
    width = "full",
} )

spec:RegisterSetting( "opener", "auto", {
    type = "select",
    name = "Stealth Opener",
    desc = "The first attack from stealth.\n\n" ..
        "Automatic: Ambush with a dagger from behind; otherwise Cheap Shot (not on bosses, which are immune to stuns), then Garrote " ..
        "from behind; otherwise your normal builder.  Premeditation is used first when talented.",
    width = "full",
    values = {
        auto = "Automatic",
        ambush = "Ambush",
        cheap_shot = "Cheap Shot",
        garrote = "Garrote",
        none = "Normal builder",
    },
} )

spec:RegisterSetting( "consumables_header", nil, {
    type = "header",
    name = "Consumables"
} )

spec:RegisterSetting( "thistle_tea", true, {
    type = "toggle",
    name = "Thistle Tea",
    desc = "When enabled and you carry Thistle Tea, it is recommended (with the Cooldowns toggle) when you are low on energy.",
    width = "full",
} )


spec:RegisterOptions( {
    enabled = true,

    aoe = 2,

    -- Sinister Strike (rank 1): known from level 1, on the 1-second rogue GCD, no cooldown of its own.
    gcd = 1752,

    nameplates = true,
    nameplateRange = 8,

    damage = true,
    damageExpiration = 6,

    package = "Combat",
    usePackSelector = true
} )


spec:RegisterPack( "Combat", 20261026.2307, [[Hekili:DIvBVTnom4FlzdOxdwNBs7AhWUMaSU1d3TpS7W8a23STITCSqCSmKKxwbk8V9JusXVKi7K7(qBTLejFi5dPOBW8GVh4Nqu0GVEZSBUFo8J3n3o79b(QNlPb(LK4nK1WdfKTWV)eF7kIcx(5CojbfwYReXWwzkvP8dxF9AMkRALxmF71)jDdlNDDM5pb(RQy5Q)Qiy1aMuwsJd(67GDPYyWy5ePKfxh9KGuhzmDD034RRqGj4PSC4Hx)6d2Ro6Y(so3B(DtR)cEqFnyLFaeP3regbxxXatdk4herSGKcQ87KFsff1rxxhTJVtTk2B96os3ZYxvh9d(UmkjPZjSy6Z)J)0RmGqLr7SV10s226OeAkPkxHiWpNfdltkaD9z9JvLk2w4VPmHubM6U3wYzfGTF6Nmzmvaruy1hZjjWH(J8kH4znS)yIGwqYzfWYFRsMvhXb)jMZZt47kM6za1tfuXAqaflEdyFk41WB3aadaZnZGv0hy6VBXpTyTwJ7imeVPCHDdub4JyubOj92RG(lyvYkGoOE2A4Vb(vLaH(t)QKlHt9rXwU4kRi8s0W7FR1vXfeuzg4f2OeimtX4fScibreu0hlucEEof2LvyvHnFiPkfCsjGI6VqIrbLELcASoH(MfxlvusUkRZ2WIBqNRZ7IQIqZBH5miRGvjlSsstUIL2(INjr3vygaziPvjPH800W1XjlM39aXK88JvFCI80hkLvWKziaqhIhQPksVyGvqlulNDAnGfRjO3RRBSbdB6a5e2ayD0RA28V1B(kKsTpI24(GDGO7wActrWT671iqnQoe4QRGm2fUW9dlU1TQjBxvzCxRwml4(WXqfAziqDuDeODr3cTMieCiz1kHDLbSXPJPFYwbIbtfjhCV3Ugi2jtHUt7yy80vpaV6ixL0qxhGGRlfHAmSLg1wqVJx8Bqr3kSEGuwceXwedujaRRWwgHP6ogO)TQkn1tI2oemDyc8Gxv5fxIs9tkKGOBzu5Y5V0ud1vdHsyPC60dTcPbZHcBUAadzqEBo)(zxOiI1uLh2amuXHtsxoF2X(bNNeMwnMxCKmazMk2aq(8LbzUmfDR88frLbCGCa7uYXe)d935G)cokwKAyk)HUygqQo5FmRqFJWhmfN75omSrl(tXZyJqOwc7qIftqVubnf7DAo1LLaruxjBBXJKfONn1SDIGxk7WzmDwWgK9CA0rMmqc1r27EhkeXriGl9D0xbiieVVOtlXXSTltd9BiSc5dn8ujSJ13DbQr0XBENduq1xyfs03xHjsZ77ifQbAGTCXDxKq12PRWni92tX0BSTWETjyw7JNYUtSg2E8bsmZDLzIHovH6YRJzVUnNr0W4dRMxUWOCpAZn5WOIsLROB7ynN2mVCSR8WT7RFEeB7cLpqjYJW8Ssfz1(YeOrzcz9AkmHsQGVfP(zmSY6sCWg7Sl4daoYO65yiqnMpAxf(UVsW2qpsDWSErCuIDmCKMdpFN6j9DcyNilYgYzF4UJLrAvBOuR1Hf9IlNGeSmnTwdWxMy80qtG7Lj28YEy4TPaNoS(lb(WOGsyRJgxFhrGdBjd8d8X74K6phy)LGWlFv)1f2l0dEmWpwa9nfmsGF)l7RJUW2K6aKxh9WI6OBd8nOdh7VZmeb(DyJO1uagpWK7f0mqGdiy3ae92beTD0ahI3ztf(TlUvHDwbhYVFhq47gY(hmlHjAhA(ImnvianUV9RhCf43RkC(vxrPwyDW8QTIEWOU9arBsFKWODCxxjTHcBJ65WnRUIATUIBc1Y6OzNPfmDxqJC))ha2j108HfJLCSrrJeO3nYz7oXvxFEGXrW6RlH2tXDNGthlMxh9YlD(CihJYvhnD0kR(d2DMOP)1cM687NP364w5gKoBm2v7WFNgaJr5Ahi880ZqfTndjEEQ5qcwRmUcuZTbk9)pG(e6otA6OstTNvog1YEdWPlLEOo6UXyghC905PW9C1j1rhCLLHPoz)D02BUAw15fygURQPwESYVE5LUGfn5Wm5bOR3pwKP3OUa4SZ6ABhoehFyeoYKR6OQRjGhd8JQV3uh9UXkH6ozBpMC3XJh5k)Ll2tdgzuzTBD7P7xmu9PDk4U4R)C0NfaN0GX2PQhft3pEX(W2RzsxNDpXty5)hmyDN7QAgI31vWVFOKzJ6(pJtSU0vCatC6IseCvQmKLy(Fe)wWq61d(3d]] )

spec:RegisterPack( "Assassination", 20261026.2307, [[Hekili:DIvBVnnsq4FlbK61kkPjn0IuPPsuOO74dCNWiX3S9g71oRIJxRDxtOsv(3(nZURFlzTtU7daXE3zMNzMN5fJ)C)F47ftuu)VD9SRVDo8NPxVy2799upxq99kirBiPWpYjBH)(Jsjrkz5efJNJN(CgNeJ6qYlfrWnwRufY7U6QuMAD5QPr8Tx9N0nSm2vRn)JV3QswM6VY9xnGLLf0i)V9o4uQmY37tzOjJQcFsqQc7HGQWVZtlryk4jSm4hV(1UVsv4591Z8PZV5IQVI33tdD5DvH9VIWiyAjdacOGFsercsIQk8hKFrfGQVQkChFNAv0000os)j(2veL1Yxwf(t(U1usCNByX0N)hVlU0ac1AANZTMwY2wfgttiLzkebEzSi41KCqxFw)ZYcfBl8VjmHubM6M3wWz5GTF6xmzevaXxaJqUarvgi2JzCE8haNMsYQc)I(8ysAkvagGlaBUJlILxm1aRNYPI0Nb4XI2axGc(n801W1a4C9m4n6lCXhSEanpLLJMKWqeNGAuFaQa8NyCbOn9olN(B4TKva9q9S1WFh8Ssbg9E63fCjCRpk2YfxAfHxGgU(PUoRATGkxR9vDCceMHebwoKIic4gr8CLGNLrHtz5wvyZisQsb3ucOO6RKiuq50cbnsNsFZYRKkiWbHZ2JHxUbDUoplkZdmpfKXG8cw8S0kjn(sws7dtnP6UcZaiROxwkPb8KKG0O4LZ7EHisw2HQpkwE8lLWYzY1iaqhIhOjlYPrLcbnx9WSJRbS4ng9EDLJnyythiNWgaRcFvZH)T(WxHuQ6iAJ7d2bIUBPXmLUCTVxJa1O6aAozfKXoZfUVF5c3QMSDvPXDTAX8c3xocQrlcaQJQJaTV0TqPeHGdjRwjSVzaBC8y6N4a3LVlhdMksg4EVnfi2XxCxDHSRUatRcHkKyiAqY0fGFh9ZqOVdqW1LIqng2uJAlO3XZ)dOOBfwpqkkaIylIbQeG1vzKyAqsgeJFg9VvLjjtLOTdathed)yAzXzNJs9lkKGOBzu5dZFPPgQRgcGgYPz0l23kKgmhiS5QbmKb5T58BNDMIisPQPylWafhUj9H5Zo0pGoEbjLJ5fhidqMPInaKpDzqMltr3kpDruRboqgGDk5qI)((7CWFbhflsnmLVOlMbKQt(hYk0ZeUZuCwZDyyJw8p5pJncHAjSdjwmb9sf0eS3P5wNxaerDLSTfpswGE2uZXXcEHSdNX0zbBq2ZPrhzYajuhzVBDOqehbaU0tPVeqqaoVOtlXXSTltd9BiSC59n8ujCI13DbQr0XBENduq1dSci65vyI088osUAGgypS8MZIPA70v4gKU4ym9gBlSJnbZA)5XS7eRHTxFGeZCxzMiOtvGU86q2RBZzeniA)Q5hwAu(uAZKCy1rPYv0T5gNGzE5qx5(f11ppITDHYhOe5rynxPISQUmHuVueufj4BrQ)AgwzDoUyJD3f8haowt17XqGAmp0Uk8zpLGTHEG6GT9c5Oe7y4kn7F)o1t6zcyNilYgYzV)MdLrAvBGuR1Hf9SZNGeS1AATgGVmX4PbMa3ltS5LAymDtomBc6I77bRckHJoy99DebUSL03Z3dNXj1FEq9qq4HVP)Od7aD)h99IeqFtbJ471FyFv4z2Mu7H8QW7xwfUW3ZGoC))o7q471HnIwtbyCptwlOzHahqWEai6IbeTD1ahI35qf(TmUvHDxbhYxFci8ndz)92LWeTdmFOMMk4Jg3Z(9dUc81Qc3F1vuQfw7TVARO7TQBpq0M0hjmAx31vsBOW2OEomz1vuR1vCtOEOkC2jAbt3f0i3()bGDsnnFyXyjhBu0ib6DJC3UBC11NhyDeS(6CO9uu3n40XI5vHV8sNphYXQCvHxmALv)f7or00FSGPo)2z6JoSvUbPZgJD1U83XbWyuU2fcpn9murBZsINMA2NG1kJRa1CBGs))iqFcDNnnDuPPQzLJrTStaoEP09vH3mgZyVXtNMcR5QtQc3BKLHPoPEgTDYvZBDoaZWDvn1YJv(1lV0fSOjhMjpaD92XIm9w1faNDxxB7WH44dJWr2CvhvDTb8yGFu99MQW3nwju3nB7XK7UE8iJ8FyznnyKvL1U1IJ3VyO6t7wWDXx)9OpjaoPbJTBvpkMUD8I9HTxZMUo7EI3WY)3BX6oZQAwI31i43puYSrD)NXjwx6koGjoDrjcUs1AKLy()m(TGH0V3)Fd]] )

spec:RegisterPack( "Subtlety", 20261026.2307, [[Hekili:DI1BVTjoy8pl5MuVwTU0K21oPTMkDBRN2TxSBAmP9oahWeScbJSnlRsv8z)EESnGtIHKDVOTySF8ZVN))Jgop87HbPefn8lxp767Md)m96BM9MWa1tv0WGksYAYk4HsYg43b1lvfu1t4gpvWjPO4sETib2mxPQKV9QRwXu51lNMW3C1NORzfSRYn)jmyznRq9pLHlhqPYkAs4xEnSlvMeg8HcIuYsAIFuqAIBvEt834RQrWj4zSc4Hx8Id2Tj(8DLE(053ErZN1hvdy5BBI39icJGRQzG6Hl4herIGKPAI)o5Nurzt8vnXB5BvltMUALJ0FGVzjrz18LnX)GVnNssDoHftF8RbxCPbeQCQZ(wvlzBAItPzK6cfIGpr3WfICic0eJ(UujC7bfSeynPeuWh1pwxPyBG)MXesfCIBFvfNvca6XFYKjub4QFxt8xf0n0uMIOyCWw4v0sQqEXudEEewSc8EkwYAq1uWGHvxdycWX1ZG3OpWfVZcDA5kwj83Tegc1mUWUbEb4JOdbYs2zVs6VG3swczdQNSk(Ba6RfOB7XFvXLWP(lby1xAfXaZ2v9ge(cbvMZlsT(cqygAASsi2qeWjs4LkbVOGc7YkTxHnuiPkfCsjGIMptsqbLtRe0eDS8LlUsQOKcvUZ2WlxJgNZArDzKzvubd89yzYcRK00lzz9lMAIXUcZaiROxwlPr8SSOvjPlM7EGesrXHxFsQ84hkJvYK5iaqdIhPtiKttQfcAP6Hzh)g05BO1RlzSoJ2SgiNW6aBI)JUn)x9M)bMs16r7mFqpvUjG7A1iqnxDeTKSeIyN5d33V4g)xnzZYAJ5AVfZl8F4eO4SkcsDuoc0)s)cTIieCiy1lH9ndOJJ7t)ahYD5BlrNPIuaM3Rwbj2PxanM2Yq)PVk9PnXqfsk4nif6cWVH2zm0WbsW1LIqng2nJAlO3Yl)tOOBjwpqQQGeXEedPsawxwqsPrzfGp(j0(wwNLnvI6ocuDuk8W06QZohL6Nuiar3WOYhM)CxnK7nejHxvqVyFTq6WCKWgRgqrgK3hZVB2zkIyfvnfBZfP4WjPpmF2H2bNNgLvpMvCGmqYmvSgG8PldM5Yu0nYtxevoKduayNsomXFF7DoyVGHIfPMmL)wxmdivh8pmRq33)TMIZ2Chg2Of)P8jSriulHDiXIjOxQGMH9onN68kiruxjBBXJjlqpBQz7ubVs6KZy6SGni3XOrdzYabuprV78CHioIaCPhpFjGGiCEHtlXX0Tpvd9BiSs59D5PsyhRT7duJChV81EqbvpWkIONxHbsZ6TKs1anWEyXTNLs16Xv4oKEZXY070TWo2euR9XJP3jwfBp(abM5(ImjqNQiD51HzV(vNr0OK9RMFyH5YNs7MKdmfLkFE3UtCcQ55dnL7VPT(59yBxO8bkrCzuz76cmYI5qBBXwgY(49aLxPISSTqcALMswTIcCyYe8nyXrodR9ohP(yz3GpainNQz6qGQWaezkCDGsWwt3tl7VTtbMEiby)5DqDi7)(BpuQLw4)7iJ0cMiPgldl6zNpbZtZ1vhANYZtmUJiJ))5j2WBlmMUUegXbddcdagLsyRdi9VLiqoBYWGWaCuPu)rfTZsHfFr)vkwEbHVpmiraTFfmsyWUCgAIpZ2RBpK3eF)IM4BcdmOd)0bhQiHboj1O2uag3tLTcA4v4bc2narVzar7zy4rCNnv4xa5)kSuo8iF7oGW3oK(3JsIXBhz(YoDQqiQ8a73F4ZX3EvinyFEPEyThT3Er3JX8oGOpOpIB0YA2xqBi32OwomG2NxR3u8Nq9qt8StudMMuOsU7)daDcnDFFYybhRx0ibADJCwxIBU28aSAW6RZHwIjUeb1(I5nXp)SZxv5Hryt8fJwzTl)Wten7oDXuNF3m9whorWG0zJLD1ZH84aySuUEELN29murBhxZt7A2pbRxgFoQ5whL(FEWUj0oew9uPPAZkhj1QF81XlMUVj(2XYnANMC630qX39g1DAxyBE)KM49g)zY6N0skWofS7TEhgAQduD9fgRuENySlyrvoCvXaP(3nMpEh23a4S0VTTwh0FoichHmT2R6Ju(yGF077LnXVESYrxY27uv4YyFe6dpSOnnye27AZ6MJ37zOADlXCx8Tl1(tcGt6Wypr)rX0DJ34yy91r(2BNy8e28)9467m3R77k8no)ndfm7UUFBCI1L(8dyGtxuIGRwLJzjM)R1VcuK(9H)h]] )

spec:RegisterPackSelector( "assassination", "Assassination", "|T132292:0|t Assassination",
    "If you have spent more points in |T132292:0|t Assassination than in any other tree, this priority will be automatically selected for you.",
    function( tab1, tab2, tab3 )
        return tab1 > max( tab2, tab3 )
    end )

spec:RegisterPackSelector( "combat", "Combat", "|T132090:0|t Combat",
    "If you have spent more points in |T132090:0|t Combat than in any other tree, this priority will be automatically selected for you.",
    function( tab1, tab2, tab3 )
        return tab2 > max( tab1, tab3 )
    end )

spec:RegisterPackSelector( "subtlety", "Subtlety", "|T132320:0|t Subtlety",
    "If you have spent more points in |T132320:0|t Subtlety than in any other tree, this priority will be automatically selected for you.",
    function( tab1, tab2, tab3 )
        return tab3 > max( tab1, tab2 )
    end )
