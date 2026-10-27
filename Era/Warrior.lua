-- Era/Warrior.lua
-- Classic Era (1.15.x) Warrior.  Spell, rank and talent IDs verified against Wowhead Classic.

if UnitClassBase( 'player' ) ~= 'WARRIOR' then return end

local addon, ns = ...
local Hekili = _G[ addon ]
local class, state = Hekili.Class, Hekili.State

local floor = math.floor

local IsCurrentSpell = _G.IsCurrentSpell or ( C_Spell and C_Spell.IsCurrentSpell )

local spec = Hekili:NewSpecialization( 1 )


-- Rank-dependent values, keyed by the spell ID of the highest rank you know.
local rend_duration = { [772] = 9, [6546] = 12, [6547] = 15, [6548] = 18, [11572] = 21, [11573] = 21, [11574] = 21 }
local thunder_clap_duration = { [6343] = 10, [8198] = 14, [8204] = 18, [8205] = 22, [11580] = 26, [11581] = 30 }
local charge_rage = { [100] = 9, [6178] = 12, [11578] = 15 }
local GetWeaponEnchantInfo, GetTime, min = _G.GetWeaponEnchantInfo, _G.GetTime, math.min
local WINDFURY_TOTEM_ENCHANTS = { [1783] = true, [563] = true, [564] = true }

local function known_id( key )
    local ability = class.abilities[ key ]
    return ability and ability.id
end


-- Rage from white hits in 1.x: 7.5 * damage / c, where c depends on level (no TBC speed factor).
-- Expected damage is discounted for misses, dodges and glancing blows.
local SWING_EFFICIENCY = 0.8

local function rage_conversion()
    local level = state.level or UnitLevel( "player" )
    return 0.0091107836 * ( level ^ 2 ) + 3.225598133 * level + 4.2652911
end

local function rage_amount( isOffhand )
    local minMH, maxMH, minOH, maxOH = UnitDamage( "player" )
    local d

    if isOffhand then d = ( ( minOH or 0 ) + ( maxOH or 0 ) ) / 2
    else d = ( ( minMH or 0 ) + ( maxMH or 0 ) ) / 2 end

    return 7.5 * d * SWING_EFFICIENCY / rage_conversion()
end


spec:RegisterResource( Enum.PowerType.Rage, {
    -- Anger Management: 1 rage every 3 seconds while in combat.
    anger_management = {
        talent = "anger_management",

        last = function ()
            local start = state.combat
            local t = state.query_time

            if start == 0 then return t end
            return start + floor( ( t - start ) / 3 ) * 3
        end,

        interval = 3,

        stop = function () return state.combat == 0 end,
        value = 1
    },

    bloodrage = {
        aura = "bloodrage",

        last = function ()
            local app = state.buff.bloodrage.applied
            local t = state.query_time

            return app + floor( t - app )
        end,

        interval = 1,
        value = 1
    },

    mainhand = {
        swing = "mainhand",

        last = function ()
            local swing = state.combat == 0 and state.now or state.swings.mainhand
            local t = state.query_time

            return swing + ( floor( ( t - swing ) / state.swings.mainhand_speed ) * state.swings.mainhand_speed )
        end,

        interval = "mainhand_speed",

        stop = function () return state.swings.mainhand == 0 end,
        value = function( now )
            -- A queued Heroic Strike or Cleave replaces the white swing, so it generates no rage.
            return state.buff.heroic_strike.expires < now and state.buff.cleave.expires < now and rage_amount() or 0
        end,
    },

    offhand = {
        swing = "offhand",

        last = function ()
            local swing = state.combat == 0 and state.now or state.swings.offhand
            local t = state.query_time

            return swing + ( floor( ( t - swing ) / state.swings.offhand_speed ) * state.swings.offhand_speed )
        end,

        interval = "offhand_speed",

        stop = function () return state.swings.offhand == 0 end,
        value = function()
            return rage_amount( true ) or 0
        end,
    },
} )


-- Talents: { talentID, maxRank, rank1SpellID, ... rankNSpellID }, from the Classic Era client's Talent table.
spec:RegisterTalents( {
    -- Arms
    improved_heroic_strike           = {   124, 3, 12282, 12663, 12664 },
    deflection                       = {   130, 5, 16462, 16463, 16464, 16465, 16466 },
    improved_rend                    = {   127, 3, 12286, 12658, 12659 },
    improved_charge                  = {   126, 2, 12285, 12697 },
    tactical_mastery                 = {   641, 5, 12295, 12676, 12677, 12678, 12679 },
    improved_thunder_clap            = {   128, 3, 12287, 12665, 12666 },
    improved_overpower               = {   131, 2, 12290, 12963 },
    anger_management                 = {   137, 1, 12296 },
    deep_wounds                      = {   121, 3, 12834, 12849, 12867 },
    two_handed_weapon_specialization = {   136, 5, 12163, 12711, 12712, 12713, 12714 },
    impale                           = {   662, 2, 16493, 16494 },
    axe_specialization               = {   132, 5, 12700, 12781, 12783, 12784, 12785 },
    sweeping_strikes                 = {   133, 1, 12292 },
    mace_specialization              = {   125, 5, 12284, 12701, 12702, 12703, 12704 },
    sword_specialization             = {   123, 5, 12281, 12812, 12813, 12814, 12815 },
    polearm_specialization           = {   134, 5, 12165, 12830, 12831, 12832, 12833 },
    improved_hamstring               = {   129, 3, 12289, 12668, 23695 },
    mortal_strike                    = {   135, 1, 12294 },

    -- Fury
    booming_voice                    = {   158, 5, 12321, 12835, 12836, 12837, 12838 },
    cruelty                          = {   157, 5, 12320, 12852, 12853, 12855, 12856 },
    improved_demoralizing_shout      = {   161, 5, 12324, 12876, 12877, 12878, 12879 },
    unbridled_wrath                  = {   159, 5, 12322, 12999, 13000, 13001, 13002 },
    improved_cleave                  = {   166, 3, 12329, 12950, 20496 },
    piercing_howl                    = {   160, 1, 12323 },
    blood_craze                      = {   661, 3, 16487, 16489, 16492 },
    improved_battle_shout            = {   154, 5, 12318, 12857, 12858, 12860, 12861 },
    dual_wield_specialization        = {  1581, 5, 23584, 23585, 23586, 23587, 23588 },
    improved_execute                 = {  1542, 2, 20502, 20503 },
    enrage                           = {   155, 5, 12317, 13045, 13046, 13047, 13048 },
    improved_slam                    = {   168, 5, 12862, 12330, 20497, 20498, 20499 },
    death_wish                       = {   165, 1, 12328 },
    improved_intercept               = {  1543, 2, 20504, 20505 },
    improved_berserker_rage          = {  1541, 2, 20500, 20501 },
    flurry                           = {   156, 5, 12319, 12971, 12972, 12973, 12974 },
    bloodthirst                      = {   167, 1, 23881 },

    -- Protection
    shield_specialization            = {  1601, 5, 12298, 12724, 12725, 12726, 12727 },
    anticipation                     = {   138, 5, 12297, 12750, 12751, 12752, 12753 },
    improved_bloodrage               = {   142, 2, 12301, 12818 },
    toughness                        = {   140, 5, 12299, 12761, 12762, 12763, 12764 },
    iron_will                        = {   141, 5, 12300, 12959, 12960, 12961, 12962 },
    last_stand                       = {   153, 1, 12975 },
    improved_shield_block            = {   145, 3, 12945, 12307, 12944 },
    improved_revenge                 = {   147, 3, 12797, 12799, 12800 },
    defiance                         = {   144, 5, 12303, 12788, 12789, 12791, 12792 },
    improved_sunder_armor            = {   146, 3, 12308, 12810, 12811 },
    improved_disarm                  = {   151, 3, 12313, 12804, 12807 },
    improved_taunt                   = {   143, 2, 12302, 12765 },
    improved_shield_wall             = {   150, 2, 12312, 12803 },
    concussion_blow                  = {   152, 1, 12809 },
    improved_shield_bash             = {   149, 2, 12311, 12958 },
    one_handed_weapon_specialization = {   702, 5, 16538, 16539, 16540, 16541, 16542 },
    shield_slam                      = {   148, 1, 23922 },
} )


-- Auras
spec:RegisterAuras( {
    battle_shout = {
        id = 25289,
        duration = function() return 120 * ( 1 + 0.1 * talent.booming_voice.rank ) end,
        max_stack = 1,
        shared = "player",
        copy = { 6673, 5242, 6192, 11549, 11550, 11551, 25289 },
    },
    battle_stance = {
        id = 2457,
        duration = 3600,
        max_stack = 1,
    },
    berserker_stance = {
        id = 2458,
        duration = 3600,
        max_stack = 1,
    },
    defensive_stance = {
        id = 71,
        duration = 3600,
        max_stack = 1,
    },
    -- Immune to Fear, Sap and Incapacitate effects.  Generates extra rage when taking damage.
    berserker_rage = {
        id = 18499,
        duration = 10,
        max_stack = 1,
    },
    -- Generating 1 rage per second.
    bloodrage = {
        id = 29131,
        duration = 10,
        tick_time = 1,
        max_stack = 1,
    },
    -- Next 5 successful melee attacks restore health.
    bloodthirst = {
        id = 23888,
        duration = 8,
        max_stack = 5,
        copy = { 23885, 23886, 23887, 23888 },
    },
    blood_craze = {
        id = 16492,
        duration = 6,
        tick_time = 1,
        max_stack = 1,
        copy = { 16488, 16490, 16491, 16492 },
    },
    challenging_shout = {
        id = 1161,
        duration = 6,
        max_stack = 1,
    },
    charge_stun = {
        id = 7922,
        duration = 1,
        max_stack = 1,
    },
    -- Pseudo-aura: Cleave is queued on the next main-hand swing.
    cleave = {
        duration = function () return swings.mainhand_speed end,
        max_stack = 1,
    },
    concussion_blow = {
        id = 12809,
        duration = 5,
        max_stack = 1,
    },
    -- Physical damage increased by 20%.
    death_wish = {
        id = 12328,
        duration = 30,
        max_stack = 1,
    },
    deep_wound = {
        id = 12721,
        duration = 12,
        tick_time = 3,
        max_stack = 1,
    },
    demoralizing_shout = {
        id = 11556,
        duration = function() return 30 * ( 1 + 0.1 * talent.booming_voice.rank ) end,
        max_stack = 1,
        shared = "target",
        copy = { 1160, 6190, 11554, 11555, 11556 },
    },
    disarm = {
        id = 676,
        duration = 10,
        max_stack = 1,
    },
    -- Melee damage increased after being critically hit.
    enrage = {
        id = 14204,
        duration = 12,
        max_stack = 1,
        copy = { 12880, 14201, 14202, 14203, 14204 },
    },
    -- Attack speed increased for the next 3 swings.
    flurry = {
        id = 12970,
        duration = 15,
        max_stack = 3,
        copy = { 12966, 12967, 12968, 12969, 12970 },
    },
    hamstring = {
        id = 7373,
        duration = 15,
        max_stack = 1,
        shared = "target",
        copy = { 1715, 7372, 7373 },
    },
    -- Pseudo-aura: Heroic Strike is queued on the next main-hand swing.
    heroic_strike = {
        duration = function () return swings.mainhand_speed end,
        max_stack = 1,
    },
    intercept_stun = {
        id = 20615,
        duration = 3,
        max_stack = 1,
        copy = { 20253, 20614, 20615 },
    },
    intimidating_shout = {
        id = 20511,
        duration = 8,
        max_stack = 1,
        copy = { 20511, 5246 },
    },
    last_stand = {
        id = 12976,
        duration = 20,
        max_stack = 1,
    },
    mocking_blow = {
        id = 20560,
        duration = 6,
        max_stack = 1,
        copy = { 694, 7400, 7402, 20559, 20560 },
    },
    -- Healing effects reduced by 50%.
    mortal_strike = {
        id = 21553,
        duration = 10,
        max_stack = 1,
        shared = "target",
        copy = { 12294, 21551, 21552, 21553 },
    },
    -- Pseudo-aura: the target dodged, so Overpower is usable for 5 seconds.
    overpower_ready = {
        duration = 5,
        max_stack = 1,
    },
    piercing_howl = {
        id = 12323,
        duration = 6,
        max_stack = 1,
    },
    -- Special attacks are guaranteed to critically hit.
    recklessness = {
        id = 1719,
        duration = 15,
        max_stack = 1,
    },
    rend = {
        id = 11574,
        duration = function() return rend_duration[ known_id( "rend" ) ] or 21 end,
        tick_time = 3,
        max_stack = 1,
        copy = { 772, 6546, 6547, 6548, 11572, 11573, 11574 },
    },
    retaliation = {
        id = 20230,
        duration = 15,
        max_stack = 30,
    },
    revenge_stun = {
        id = 12798,
        duration = 3,
        max_stack = 1,
    },
    -- Pseudo-aura: you blocked, dodged or parried, so Revenge is usable for 5 seconds.
    revenge_usable = {
        duration = 5,
        max_stack = 1,
    },
    -- Pseudo-aura: a Windfury Totem weapon enchant is on your main hand (Horde shaman in your group).  Enchant IDs of
    -- Windfury Totem Effect ranks 1-3 (spells 8514, 10607, 10611) from the client's SpellEffect table.
    windfury_totem_weapon = {
        duration = 10,
        max_stack = 1,
        generate = function( t )
            local hasMH, mhExpires, _, mhEnchant = GetWeaponEnchantInfo()
            if hasMH and mhExpires and WINDFURY_TOTEM_ENCHANTS[ mhEnchant ] then
                local now = GetTime()
                t.count = 1
                t.expires = now + mhExpires / 1000
                t.applied = min( now, t.expires - 10 )
                t.caster = "player"
                return
            end
            t.count = 0
            t.applied = 0
            t.expires = 0
            t.caster = "nobody"
        end,
    },
    shield_bash_silenced = {
        id = 18498,
        duration = 3,
        max_stack = 1,
    },
    shield_block = {
        id = 2565,
        duration = function() return talent.improved_shield_block.enabled and 6 or 5 end,
        max_stack = 1,
    },
    shield_wall = {
        id = 871,
        duration = 10,
        max_stack = 1,
    },
    sunder_armor = {
        id = 11597,
        duration = 30,
        max_stack = 5,
        shared = "target",
        copy = { 7386, 7405, 8380, 11596, 11597 },
    },
    -- Your next 5 melee attacks strike an additional nearby opponent.
    sweeping_strikes = {
        id = 12292,
        duration = 20,
        max_stack = 5,
    },
    taunt = {
        id = 355,
        duration = 3,
        max_stack = 1,
    },
    thunder_clap = {
        id = 11581,
        duration = function() return thunder_clap_duration[ known_id( "thunder_clap" ) ] or 30 end,
        max_stack = 1,
        shared = "target",
        copy = { 6343, 8198, 8204, 8205, 11580, 11581 },
    },

    -- Aliases.
    stance = {
        alias = { "battle_stance", "defensive_stance", "berserker_stance" },
        aliasMode = "first",
        aliasType = "buff",
    },
    major_armor_reduction = {
        alias = { "sunder_armor", "expose_armor" },
        aliasType = "debuff",
        aliasMode = "first"
    },
} )


-- Combat log: Overpower (target dodged us) and Revenge (we blocked, dodged or parried).
local enemy_dodged = 0
local revenge_trigger = 0

local revenge_misses = {
    BLOCK = true,
    DODGE = true,
    PARRY = true,
}

spec:RegisterCombatLogEvent( function( _, subtype, _, sourceGUID, _, _, _, destGUID, _, _, _, ... )
    if subtype ~= "SWING_MISSED" and subtype ~= "SPELL_MISSED" then return end

    -- SWING_MISSED: missType is the first suffix argument; SPELL_MISSED has spellId, spellName, spellSchool first.
    local missType
    if subtype == "SWING_MISSED" then missType = ...
    else missType = select( 4, ... ) end

    if sourceGUID == state.GUID and missType == "DODGE" then
        enemy_dodged = GetTime()
    elseif destGUID == state.GUID and revenge_misses[ missType ] then
        revenge_trigger = GetTime()
    end
end )


-- Rage retained on a stance change (Tactical Mastery: 5 per rank).
spec:RegisterStateExpr( "stance_rage_retained", function()
    return 5 * talent.tactical_mastery.rank
end )

-- Whether to use the tank priority ("Tank Mode" setting): Auto = while in Defensive Stance, Always, or Never.
spec:RegisterStateExpr( "tank_priority", function()
    local mode = settings.tank_mode
    if mode == "always" then return true end
    if mode == "never" then return false end
    return buff.defensive_stance.up
end )

-- Whether the "Open With Sunder Armor" setting applies to the current group.
spec:RegisterStateExpr( "opener_sunder_wanted", function()
    local mode = settings.opener_sunder
    if mode == "always" then return true end
    if mode == "group" then return group end
    if mode == "raid" then return raid end
    return false
end )

spec:RegisterStateExpr( "hamstring_weave_now", function()
    local mode = settings.hamstring_weave
    if mode == "always" or mode == true then return true end           -- true: the old on/off setting
    if mode == "windfury" then return buff.windfury_totem_weapon.up end
    return false
end )

spec:RegisterStateFunction( "swap_stance", function( stance )
    removeBuff( "battle_stance" )
    removeBuff( "defensive_stance" )
    removeBuff( "berserker_stance" )

    local lost = rage.current - 5 * talent.tactical_mastery.rank
    if lost > 0 then
        spend( lost, "rage" )
    end

    if stance then applyBuff( stance )
    else applyBuff( "stance" ) end
end )


local function heroic_strike_cost()
    return 15 - state.talent.improved_heroic_strike.rank
end

local finish_heroic_strike = setfenv( function()
    spend( heroic_strike_cost(), "rage" )
end, state )

spec:RegisterStateFunction( "start_heroic_strike", function()
    applyBuff( "heroic_strike", swings.time_to_next_mainhand )
    state:QueueAuraExpiration( "heroic_strike", finish_heroic_strike, buff.heroic_strike.expires )
end )


local finish_cleave = setfenv( function()
    spend( 20, "rage" )
end, state )

spec:RegisterStateFunction( "start_cleave", function()
    applyBuff( "cleave", swings.time_to_next_mainhand )
    state:QueueAuraExpiration( "cleave", finish_cleave, buff.cleave.expires )
end )


spec:RegisterHook( "reset_precast", function()
    local form = GetShapeshiftForm()
    if form == 1 then applyBuff( "battle_stance" )
    elseif form == 2 then applyBuff( "defensive_stance" )
    elseif form == 3 then applyBuff( "berserker_stance" )
    else removeBuff( "stance" ) end

    if IsCurrentSpell and IsCurrentSpell( class.abilities.heroic_strike.id ) then
        start_heroic_strike()
        Hekili:Debug( "Starting Heroic Strike, next swing in %.2f...", buff.heroic_strike.remains )
    end

    if IsCurrentSpell and IsCurrentSpell( class.abilities.cleave.id ) then
        start_cleave()
        Hekili:Debug( "Starting Cleave, next swing in %.2f...", buff.cleave.remains )
    end

    if now == query_time then
        if enemy_dodged > 0 and now - enemy_dodged < 5 then
            applyBuff( "overpower_ready", enemy_dodged + 5 - now )
        end
        if revenge_trigger > 0 and now - revenge_trigger < 5 then
            applyBuff( "revenge_usable", revenge_trigger + 5 - now )
        end
    end
end )


-- Abilities
spec:RegisterAbilities( {
    -- Increases the melee attack power of party members within 20 yards.  Lasts 2 min.
    battle_shout = {
        id = 25289,
        cast = 0,
        cooldown = 0,
        gcd = "spell",

        spend = 10,
        spendType = "rage",

        startsCombat = false,
        texture = 132333,

        handler = function()
            applyBuff( "battle_shout" )
        end,

        copy = { 6673, 5242, 6192, 11549, 11550, 11551 }
    },


    battle_stance = {
        id = 2457,
        cast = 0,
        cooldown = 1,
        gcd = "off",

        startsCombat = false,
        texture = 132349,

        nobuff = "battle_stance",

        timeToReady = function () return max( cooldown.berserker_stance.remains, cooldown.battle_stance.remains, cooldown.defensive_stance.remains ) end,

        handler = function()
            swap_stance( "battle_stance" )
        end
    },


    berserker_stance = {
        id = 2458,
        cast = 0,
        cooldown = 1,
        gcd = "off",

        startsCombat = false,
        texture = 132275,

        nobuff = "berserker_stance",

        timeToReady = function () return max( cooldown.berserker_stance.remains, cooldown.battle_stance.remains, cooldown.defensive_stance.remains ) end,

        handler = function()
            swap_stance( "berserker_stance" )
        end
    },


    defensive_stance = {
        id = 71,
        cast = 0,
        cooldown = 1,
        gcd = "off",

        startsCombat = false,
        texture = 132341,

        nobuff = "defensive_stance",

        timeToReady = function () return max( cooldown.berserker_stance.remains, cooldown.battle_stance.remains, cooldown.defensive_stance.remains ) end,

        handler = function()
            swap_stance( "defensive_stance" )
        end
    },


    -- Removes and grants immunity to Fear, Sap and Incapacitate effects; extra rage when taking damage.  Lasts 10 sec.
    berserker_rage = {
        id = 18499,
        cast = 0,
        cooldown = 30,
        gcd = "spell",

        startsCombat = false,
        texture = 136009,

        buff = "berserker_stance",

        handler = function()
            applyBuff( "berserker_rage" )
            if talent.improved_berserker_rage.enabled then
                gain( 5 * talent.improved_berserker_rage.rank, "rage" )
            end
        end
    },


    -- Generates 10 rage at the cost of health, and then generates an additional 10 rage over 10 sec.
    bloodrage = {
        id = 2687,
        cast = 0,
        cooldown = 60,
        gcd = "off",

        startsCombat = false,
        texture = 132277,

        usable = function() return health.pct > 30, "health must be above 30%" end,

        handler = function()
            gain( 10, "rage" )
            applyBuff( "bloodrage" )
        end
    },


    -- Instantly attack the target causing damage equal to 45% of your attack power.
    bloodthirst = {
        id = 23894,
        cast = 0,
        cooldown = 6,
        gcd = "spell",

        spend = 30,
        spendType = "rage",

        talent = "bloodthirst",
        startsCombat = true,
        texture = 136012,

        handler = function()
            applyBuff( "bloodthirst", nil, 5 )
        end,

        copy = { 23881, 23892, 23893 }
    },


    -- Forces all nearby enemies to focus attacks on you for 6 sec.
    challenging_shout = {
        id = 1161,
        cast = 0,
        cooldown = 600,
        gcd = "spell",

        spend = 5,
        spendType = "rage",

        startsCombat = true,
        texture = 132091,

        toggle = "defensives",

        handler = function()
            applyDebuff( "target", "challenging_shout" )
        end
    },


    -- Charge an enemy, generate rage, and stun it for 1 sec.  Cannot be used in combat.
    charge = {
        id = 11578,
        cast = 0,
        cooldown = 15,
        gcd = "off",

        spend = function()
            return -( charge_rage[ known_id( "charge" ) ] or 15 ) - 3 * talent.improved_charge.rank
        end,
        spendType = "rage",

        startsCombat = true,
        texture = 132337,

        buff = "battle_stance",

        usable = function()
            return combat == 0 and target.minR > 7, "cannot be in combat; target must be outside 8 yards"
        end,

        handler = function()
            setDistance( 5 )
            applyDebuff( "target", "charge_stun" )
        end,

        copy = { 100, 6178 }
    },


    -- On next attack, hits the target and its nearest ally.
    cleave = {
        id = 20569,
        cast = 0,
        cooldown = 0,
        gcd = "off",

        spend = 20,
        spendType = "rage",

        startsCombat = true,
        texture = 132338,

        nobuff = "cleave",

        usable = function()
            return not buff.heroic_strike.up and not buff.cleave.up, "heroic strike or cleave already queued"
        end,

        handler = function()
            -- The rage is spent when the swing lands; see start_cleave.
            gain( 20, "rage" )
            start_cleave()
        end,

        copy = { 845, 7369, 11608, 11609 }
    },


    -- Stuns the opponent for 5 sec.
    concussion_blow = {
        id = 12809,
        cast = 0,
        cooldown = 45,
        gcd = "spell",

        spend = 15,
        spendType = "rage",

        talent = "concussion_blow",
        startsCombat = true,
        texture = 132325,

        toggle = "interrupts",

        handler = function()
            applyDebuff( "target", "concussion_blow" )
        end
    },


    -- Increases physical damage by 20% and grants immunity to Fear for 30 sec, but increases damage taken.
    death_wish = {
        id = 12328,
        cast = 0,
        cooldown = 180,
        gcd = "spell",

        spend = 10,
        spendType = "rage",

        talent = "death_wish",
        startsCombat = false,
        texture = 136146,

        toggle = "cooldowns",

        handler = function()
            applyBuff( "death_wish" )
        end
    },


    -- Reduces the melee attack power of all nearby enemies.
    demoralizing_shout = {
        id = 11556,
        cast = 0,
        cooldown = 0,
        gcd = "spell",

        spend = 10,
        spendType = "rage",

        startsCombat = true,
        texture = 132366,

        handler = function()
            applyDebuff( "target", "demoralizing_shout" )
            active_dot.demoralizing_shout = max( active_dot.demoralizing_shout, active_enemies )
        end,

        copy = { 1160, 6190, 11554, 11555 }
    },


    disarm = {
        id = 676,
        cast = 0,
        cooldown = 60,
        gcd = "spell",

        spend = 20,
        spendType = "rage",

        startsCombat = true,
        texture = 132343,

        buff = "defensive_stance",

        handler = function()
            applyDebuff( "target", "disarm" )
        end
    },


    -- Finish off a wounded foe, converting all remaining rage into additional damage.  Only usable below 20% health.
    execute = {
        id = 20662,
        cast = 0,
        cooldown = 0,
        gcd = "spell",

        spend = function()
            return talent.improved_execute.rank == 2 and 10 or talent.improved_execute.rank == 1 and 13 or 15
        end,
        spendType = "rage",

        startsCombat = true,
        texture = 135358,

        usable = function()
            if buff.defensive_stance.up then return false, "requires battle or berserker stance" end
            return target.health.pct < 20, "requires target health under 20 percent"
        end,

        handler = function()
            -- Every point of rage left after the base cost is converted into damage.
            if rage.current > 0 then spend( rage.current, "rage" ) end
        end,

        copy = { 5308, 20658, 20660, 20661 }
    },


    -- Maims the enemy, reducing movement speed for 15 sec.
    hamstring = {
        id = 7373,
        cast = 0,
        cooldown = 0,
        gcd = "spell",

        spend = 10,
        spendType = "rage",

        startsCombat = true,
        texture = 132316,

        usable = function() return not buff.defensive_stance.up, "requires battle or berserker stance" end,

        handler = function()
            applyDebuff( "target", "hamstring" )
        end,

        copy = { 1715, 7372 }
    },


    -- A strong attack that increases melee damage on your next swing.
    heroic_strike = {
        id = 25286,
        cast = 0,
        cooldown = 0,
        gcd = "off",

        spend = function() return 15 - talent.improved_heroic_strike.rank end,
        spendType = "rage",

        startsCombat = true,
        texture = 132282,

        nobuff = "heroic_strike",

        usable = function()
            return not buff.heroic_strike.up and not buff.cleave.up, "heroic strike or cleave already queued"
        end,

        handler = function()
            -- The rage is spent when the swing lands; see start_heroic_strike.
            gain( 15 - talent.improved_heroic_strike.rank, "rage" )
            start_heroic_strike()
        end,

        copy = { 78, 284, 285, 1608, 11564, 11565, 11566, 11567 }
    },


    -- Charge an enemy, causing damage and stunning it for 3 sec.
    intercept = {
        id = 20617,
        cast = 0,
        cooldown = function() return 30 - 5 * talent.improved_intercept.rank end,
        gcd = "spell",

        spend = 10,
        spendType = "rage",

        startsCombat = true,
        texture = 132307,

        buff = "berserker_stance",

        usable = function() return target.minR > 7, "target must be outside 8 yards" end,

        handler = function()
            setDistance( 5 )
            applyDebuff( "target", "intercept_stun" )
        end,

        copy = { 20252, 20616 }
    },


    intimidating_shout = {
        id = 5246,
        cast = 0,
        cooldown = 180,
        gcd = "spell",

        spend = 25,
        spendType = "rage",

        startsCombat = true,
        texture = 132154,

        toggle = "defensives",

        handler = function()
            applyDebuff( "target", "intimidating_shout" )
        end
    },


    last_stand = {
        id = 12975,
        cast = 0,
        cooldown = 600,
        gcd = "off",

        talent = "last_stand",
        startsCombat = false,
        texture = 135871,

        toggle = "defensives",

        handler = function()
            applyBuff( "last_stand" )
        end
    },


    mocking_blow = {
        id = 20560,
        cast = 0,
        cooldown = 120,
        gcd = "spell",

        spend = 10,
        spendType = "rage",

        startsCombat = true,
        texture = 132350,

        buff = "battle_stance",

        handler = function()
            applyDebuff( "target", "mocking_blow" )
        end,

        copy = { 694, 7400, 7402, 20559 }
    },


    -- A vicious strike that deals weapon damage plus a bonus and wounds the target, reducing healing by 50%.
    mortal_strike = {
        id = 21553,
        cast = 0,
        cooldown = 6,
        gcd = "spell",

        spend = 30,
        spendType = "rage",

        talent = "mortal_strike",
        startsCombat = true,
        texture = 132355,

        handler = function()
            applyDebuff( "target", "mortal_strike" )
        end,

        copy = { 12294, 21551, 21552 }
    },


    -- Instantly overpower the enemy after it dodges.  Cannot be blocked, dodged or parried.
    overpower = {
        id = 11585,
        cast = 0,
        cooldown = 5,
        gcd = "spell",

        spend = 5,
        spendType = "rage",

        startsCombat = true,
        texture = 132223,

        buff = "battle_stance",

        usable = function()
            return buff.overpower_ready.up, "only usable after the target dodges"
        end,

        handler = function()
            removeBuff( "overpower_ready" )
        end,

        copy = { 7384, 7887, 11584 }
    },


    piercing_howl = {
        id = 12323,
        cast = 0,
        cooldown = 0,
        gcd = "spell",

        spend = 10,
        spendType = "rage",

        talent = "piercing_howl",
        startsCombat = true,
        texture = 136147,

        handler = function()
            applyDebuff( "target", "piercing_howl" )
        end
    },


    -- Interrupts a spell and prevents casting from that school for 4 sec.
    pummel = {
        id = 6554,
        cast = 0,
        cooldown = 10,
        gcd = "spell",

        spend = 10,
        spendType = "rage",

        startsCombat = true,
        texture = 132938,

        buff = "berserker_stance",

        toggle = "interrupts",

        debuff = "casting",
        readyTime = state.timeToInterrupt,

        handler = function()
            interrupt()
        end,

        copy = { 6552 }
    },


    -- All special attacks critically hit for 15 sec.  30 min cooldown.
    recklessness = {
        id = 1719,
        cast = 0,
        cooldown = 1800,
        gcd = "spell",

        startsCombat = false,
        texture = 132109,

        buff = "berserker_stance",

        toggle = "cooldowns",

        handler = function()
            applyBuff( "recklessness" )
        end
    },


    -- Wounds the target, causing it to bleed over time.
    rend = {
        id = 11574,
        cast = 0,
        cooldown = 0,
        gcd = "spell",

        spend = 10,
        spendType = "rage",

        startsCombat = true,
        texture = 132155,

        usable = function() return not buff.berserker_stance.up, "requires battle or defensive stance" end,

        handler = function()
            applyDebuff( "target", "rend" )
        end,

        copy = { 772, 6546, 6547, 6548, 11572, 11573 }
    },


    retaliation = {
        id = 20230,
        cast = 0,
        cooldown = 1800,
        gcd = "spell",

        startsCombat = false,
        texture = 132336,

        buff = "battle_stance",

        toggle = "defensives",

        handler = function()
            applyBuff( "retaliation" )
        end
    },


    -- Instantly counterattack after blocking, dodging or parrying.
    revenge = {
        id = 25288,
        cast = 0,
        cooldown = 5,
        gcd = "spell",

        spend = 5,
        spendType = "rage",

        startsCombat = true,
        texture = 132353,

        buff = "defensive_stance",

        usable = function() return buff.revenge_usable.up, "only usable after blocking, dodging or parrying" end,

        handler = function()
            removeBuff( "revenge_usable" )
        end,

        copy = { 6572, 6574, 7379, 11600, 11601 }
    },


    shield_bash = {
        id = 1672,
        cast = 0,
        cooldown = 12,
        gcd = "spell",

        spend = 10,
        spendType = "rage",

        startsCombat = true,
        texture = 132357,

        equipped = "shield",
        usable = function() return not buff.berserker_stance.up, "requires battle or defensive stance" end,

        toggle = "interrupts",

        debuff = "casting",
        readyTime = state.timeToInterrupt,

        handler = function()
            interrupt()
        end,

        copy = { 72, 1671 }
    },


    shield_block = {
        id = 2565,
        cast = 0,
        cooldown = 5,
        gcd = "off",

        spend = 10,
        spendType = "rage",

        startsCombat = false,
        texture = 132110,

        equipped = "shield",
        buff = "defensive_stance",

        handler = function()
            applyBuff( "shield_block" )
        end
    },


    shield_slam = {
        id = 23925,
        cast = 0,
        cooldown = 6,
        gcd = "spell",

        spend = 20,
        spendType = "rage",

        talent = "shield_slam",
        startsCombat = true,
        texture = 134951,

        equipped = "shield",

        handler = function()
        end,

        copy = { 23922, 23923, 23924 }
    },


    shield_wall = {
        id = 871,
        cast = 0,
        cooldown = 1800,
        gcd = "spell",

        startsCombat = false,
        texture = 132362,

        equipped = "shield",
        buff = "defensive_stance",

        toggle = "defensives",

        handler = function()
            applyBuff( "shield_wall" )
        end
    },


    -- Slams the opponent, causing weapon damage plus a bonus.  Resets your swing timer.
    slam = {
        id = 11605,
        cast = function() return 1.5 - 0.1 * talent.improved_slam.rank end,
        cooldown = 0,
        gcd = "spell",

        spend = 15,
        spendType = "rage",

        startsCombat = true,
        texture = 132340,

        handler = function()
        end,

        copy = { 1464, 8820, 11604 }
    },


    -- Sunders the target's armor; stacks up to 5 times.
    sunder_armor = {
        id = 11597,
        cast = 0,
        cooldown = 0,
        gcd = "spell",

        spend = function() return 15 - talent.improved_sunder_armor.rank end,
        spendType = "rage",

        startsCombat = true,
        texture = 132363,

        handler = function()
            applyDebuff( "target", "sunder_armor", nil, min( 5, debuff.sunder_armor.stack + 1 ) )
        end,

        copy = { 7386, 7405, 8380, 11596 }
    },


    -- Your next 5 melee attacks strike an additional nearby opponent.
    sweeping_strikes = {
        id = 12292,
        cast = 0,
        cooldown = 30,
        gcd = "spell",

        spend = 30,
        spendType = "rage",

        talent = "sweeping_strikes",
        startsCombat = false,
        texture = 132306,

        buff = "battle_stance",

        handler = function()
            applyBuff( "sweeping_strikes", nil, 5 )
        end
    },


    taunt = {
        id = 355,
        cast = 0,
        cooldown = 10,
        gcd = "off",

        startsCombat = true,
        texture = 136080,

        buff = "defensive_stance",

        handler = function()
            applyDebuff( "target", "taunt" )
        end
    },


    -- Blasts nearby enemies, damaging them and slowing their attack speed.
    thunder_clap = {
        id = 11581,
        cast = 0,
        cooldown = 4,
        gcd = "spell",

        spend = function() return 20 - ( talent.improved_thunder_clap.rank == 3 and 4 or talent.improved_thunder_clap.rank ) end,
        spendType = "rage",

        startsCombat = true,
        texture = 136105,

        buff = "battle_stance",

        handler = function()
            applyDebuff( "target", "thunder_clap" )
            active_dot.thunder_clap = max( active_dot.thunder_clap, min( 4, active_enemies ) )
        end,

        copy = { 6343, 8198, 8204, 8205, 11580 }
    },


    -- Attacks up to 4 nearby enemies.
    whirlwind = {
        id = 1680,
        cast = 0,
        cooldown = 10,
        gcd = "spell",

        spend = 25,
        spendType = "rage",

        startsCombat = true,
        texture = 132369,

        buff = "berserker_stance",

        handler = function()
        end
    },
} )


-- Settings
spec:RegisterSetting( "warrior_description", nil, {
    type = "description",
    name = "Adjust the settings below to match your gear and playstyle.  The defaults follow the Classic Era warrior sim " ..
        "and community guides; a simulator for your own character is the best way to fine-tune them."
} )

spec:RegisterSetting( "general_header", nil, {
    type = "header",
    name = "Rage Dumps"
} )

spec:RegisterSetting( "hs_rage_threshold", 40, {
    type = "range",
    name = "Heroic Strike Rage Threshold",
    desc = "Heroic Strike is recommended (single target) once you have at least this much rage.  Lower it as your gear improves.",
    width = "full",
    min = 0,
    softMax = 100,
    step = 1,
} )

spec:RegisterSetting( "cleave_rage_threshold", 40, {
    type = "range",
    name = "Cleave Rage Threshold",
    desc = "Cleave is recommended (2+ targets) once you have at least this much rage.",
    width = "full",
    min = 0,
    softMax = 100,
    step = 1,
} )

spec:RegisterSetting( "execute_queueing", false, {
    type = "toggle",
    name = "Heroic Strike During Execute Phase",
    desc = "When enabled, Heroic Strike / Cleave can still be recommended while the target is below 20% health.  " ..
        "Usually Execute is the better use of your rage.",
    width = "full",
} )

spec:RegisterSetting( "hamstring_weave", "windfury", {
    type = "select",
    name = "Hamstring Weaving",
    desc = "Hamstring as a cheap extra attack when you have spare rage and nothing else is ready.  Each Hamstring is another " ..
        "chance at a Windfury Totem proc, which is why most top Fury warriors weave it when they have Windfury (Horde).  " ..
        "Without Windfury it's rarely worth the rage.",
    width = "full",
    values = {
        never = "Never",
        windfury = "With Windfury Totem",
        always = "Always",
    },
} )

spec:RegisterSetting( "hamstring_rage_threshold", 50, {
    type = "range",
    name = "Hamstring Weaving Rage Threshold",
    desc = "Minimum rage before Hamstring is used for weaving.",
    width = "full",
    min = 10,
    softMax = 100,
    step = 1,
} )

spec:RegisterSetting( "debuffs_header", nil, {
    type = "header",
    name = "Debuffs"
} )

spec:RegisterSetting( "opener_sunder", "raid", {
    type = "select",
    name = "Open With Sunder Armor",
    desc = "Make Sunder Armor your first attack of each fight (after Charge, if you charged in).\n\n" ..
        "The stance swap is timed for rage: right after Charge you Sunder in Battle Stance first, so the Charge rage " ..
        "is spent instead of lost on the swap; with too little rage for Sunder you swap to Berserker Stance first " ..
        "(nothing to lose) and Sunder there.",
    width = "full",
    values = {
        none = "Never",
        raid = "In raids",
        group = "In a party or raid",
        always = "Always",
    },
} )

spec:RegisterSetting( "debuff_sunder_enabled", false, {
    type = "toggle",
    name = "Maintain Sunder Armor",
    desc = "When enabled, Sunder Armor is recommended up to 5 stacks and kept up.  Leave it off in raids where the tank sunders.",
    width = "full",
} )

spec:RegisterSetting( "debuff_demoshout_enabled", false, {
    type = "toggle",
    name = "Maintain Demoralizing Shout",
    desc = "When enabled, Demoralizing Shout is recommended when the target does not have it.",
    width = "full",
} )

spec:RegisterSetting( "rend_enabled", true, {
    type = "toggle",
    name = "Use Rend (Battle Stance)",
    desc = "When enabled, Rend is recommended in Battle Stance if the target will live long enough.  " ..
        "Useful while leveling; disable it against bleed-immune enemies and in raids.",
    width = "full",
} )

spec:RegisterSetting( "execute_header", nil, {
    type = "header",
    name = "Execute Phase"
} )

spec:RegisterSetting( "execute_bt_ap", 2000, {
    type = "range",
    name = "Bloodthirst / Mortal Strike Over Execute Above Attack Power",
    desc = "At or above this attack power, Bloodthirst / Mortal Strike stay ahead of Execute during the execute phase.  " ..
        "Set to 0 to always prefer Execute.",
    width = "full",
    min = 0,
    softMax = 4000,
    step = 50,
} )

spec:RegisterSetting( "weaving_header", nil, {
    type = "header",
    name = "Stance Dancing"
} )

spec:RegisterSetting( "overpower_dance", true, {
    type = "toggle",
    name = "Fury: Overpower Stance Dance",
    desc = "When enabled, Fury may swap to Battle Stance for Overpower after a dodge, if no rage beyond Tactical Mastery is lost " ..
        "and Bloodthirst / Whirlwind are on cooldown.  Under those conditions each Overpower (weapon damage + 35, extra crit " ..
        "with Improved Overpower, 5 rage) is worth far more than the few seconds without Berserker Stance's crit.  About half " ..
        "of the top Era Fury warriors dance on Patchwerk; on bosses you can't hit from behind (e.g. Ragnaros) it rarely comes up.",
    width = "full",
} )


spec:RegisterSetting( "tank_header", nil, {
    type = "header",
    name = "Tanking"
} )

spec:RegisterSetting( "tank_mode", "auto", {
    type = "select",
    name = "Tank Mode",
    desc = "When to use the tank priority.  The Era norm is dual-wield Fury/Protection tanking in Defensive Stance, so this " ..
        "works with any talent build and with or without a shield.\n\n" ..
        "Auto: whenever you are in Defensive Stance.\n" ..
        "Always: also pull into Defensive Stance (Charge, then Sunder if you have the rage, then Defensive Stance).\n" ..
        "Never: Defensive Stance is treated as a mistake and you are sent back to your damage stance.\n\n" ..
        "Characters with most points in Protection use the Protection priority, which always tanks.",
    width = "full",
    values = { auto = "Auto (in Defensive Stance)", always = "Always", never = "Never" },
} )

spec:RegisterSetting( "tank_hs_rage", 40, {
    type = "range",
    name = "Tank: Heroic Strike Rage Threshold",
    desc = "While tanking, Heroic Strike is queued (single target) at or above this much rage.  With Bloodthirst, it is also queued " ..
        "below this while Bloodthirst is on cooldown, as long as a Sunder Armor is still affordable afterwards.  Dual-wield tanks " ..
        "queue it often, which also removes the off-hand dual-wield miss penalty.",
    width = "full",
    min = 0,
    softMax = 100,
    step = 1,
} )

spec:RegisterSetting( "tank_cleave_rage", 40, {
    type = "range",
    name = "Tank: Cleave Rage Threshold",
    desc = "While tanking two or more enemies, Cleave is queued at or above this much rage.",
    width = "full",
    min = 0,
    softMax = 100,
    step = 1,
} )

spec:RegisterSetting( "tank_bt_first_rage", 50, {
    type = "range",
    name = "Tank: Bloodthirst Before Revenge Above",
    desc = "When Bloodthirst and Revenge are both ready, Bloodthirst goes first at or above this much rage (if Revenge's window " ..
        "outlasts the next global cooldown); below it, Revenge goes first.  Revenge is the best threat per rage, Bloodthirst " ..
        "the best per global cooldown, and the tanks in the fastest Classic Era kills switch the same way.",
    width = "full",
    min = 0,
    softMax = 100,
    step = 1,
} )

spec:RegisterSetting( "tank_demoshout", true, {
    type = "toggle",
    name = "Tank: Maintain Demoralizing Shout",
    desc = "While tanking, keep Demoralizing Shout on the target.",
    width = "full",
} )

spec:RegisterSetting( "tank_shield_block", true, {
    type = "toggle",
    name = "Tank: Shield Block",
    desc = "With a shield equipped, use Shield Block while you have aggro (more blocks also mean more Revenge).",
    width = "full",
} )

spec:RegisterSetting( "tank_taunt", false, {
    type = "toggle",
    name = "Tank: Taunt When You Lose Aggro",
    desc = "Recommend Taunt when the target is not attacking you.  Off by default: in raids an off-tank often shouldn't.",
    width = "full",
} )

spec:RegisterSetting( "tank_last_stand_pct", 20, {
    type = "range",
    name = "Tank: Last Stand Below Health %",
    desc = "Recommend Last Stand (talent) below this health percentage while tanking; Shield Wall (with a shield) at half of it.  " ..
        "Both are on the Defensives toggle.  0 disables.",
    width = "full",
    min = 0,
    max = 100,
    step = 1,
} )


spec:RegisterOptions( {
    enabled = true,

    aoe = 2,

    gcd = 6673,

    nameplates = true,
    nameplateRange = 8,

    -- Count enemies we've recently hit or been hit by, in case nameplates miss stacked mobs.
    damage = true,
    damageExpiration = 6,

    package = "Fury",
    usePackSelector = true
} )

-- Changed defaults, applied once to profiles still at the old default (Era/Classes.lua, ns.MigrateSettings).  Append only.
spec.settingMigrations = {
    { name = "overpower_dance", from = false, to = true },           -- era-beta-5: on by default
    { name = "hamstring_weave", from = false, to = "windfury" },     -- era-beta-5: on/off became Never / With Windfury / Always
    { name = "tank_hs_rage", from = 45, to = 40 },                   -- era-beta-3: threat research
}


spec:RegisterPack( "Arms", 20261027.1552, [[Hekili:TZ1EVnUns8plPfW1UBwhBNZ9X24a0E91vG(a1lW9FwIwI2siYsQsuXnhc8N9BMHIsusKYYz3E79hfOBIJeNhC484hhs3nZ382nR9zc(MFzXSfF28zl(8PZxUCXM1INs5BwNY8EGTh(qm7a8ZVo7qo(WNIsy(iP5jfzEWlceI083CZn7dfbfBN6LC4MaEg7HWOWQpSz92IWiX)kEZwlYmpL7T5xMdVLN7jL2j3)nlllmj7KBk(RqXtNC3H)5)mILNh6DY97YyGoLLSlmc0Kp(Jp52IWX6d9K7CqAto9t4axtQF(BAYTksxhEaO(hkEABwrEWpekUP(fto56Z3XkIe5xte4LX2jo5(w2J8Syng(T)26tUhv6Y(IqF(uP0)gMqeXbTqWI9GFhckTia(qqYb4N5LpE8pNKjyr44YcFGds7xbrKMCKNbFEDe7a(RJCEAy8E1OYN8vadb94B4z58Sh4z1YbLbPa1wuMVpAXccZIogg7dpa)XVZ9EiINNhd)R8rEmGN(s(SfCokxmQ0iyQD6NyEIWK48PPzCWtylt8Qv3SLMSoYj11H7wTTy3UPY)CQFYX4(jliPqurL(dNMXpWcJZV72zAIgO0Jff5i)tNOWCX1Ol8QW4qH(OsloCGhP)KSI4UKbQ5dO4XF7uz2ohvs9SJAlNZfPNNE1Axnlup5c4c4MYJZdFSwrQEIzUy2Yj1E9Lx0wcd)rwwiBlmpPHX)tUxHG7KgWY5x)ilQaTEz75IPbCwKiyAQN4UfZodBa)mN)OGxOyXvQxpTHaEoNleGBFE1JjIWaH(5FofL4Ka(ToLKwkPoCCRWHLE)SrGTsmfmcGxVd5RFVLXEordUTr(o5fX(WkBlH6ZXvOYx6WJrY8hvAafHh4oIeh)q(9JhV81YbpTCWSSdjzyeL3dt(05txo5v3kdZ)1uEmf)tJdsOukTtUFe(kiUhYAx)6Vg5ZhnbskUlmlhsPjNZNCt2vMFAx4(abK0Piwec5Ly10cRjqEboYupwUy6zmfjKM10u04zohzXc0aaZ87MpBKKBnNXKvjpe8JVh)4ORG8hp6S3ZF68gd8s0fN4KJL6tLJxJbmkdklo1RilJhlUFLj9YljxCoxbi5Tdwv0Vksjc430Wdq9Sh5GtcmGPzqsN7xTed96w2qZelJqXa4a0FrMVICCG8K5qDNVWWy1vzKcZtxdeEbzMnrDusIpAdVUihcdbxEybB1CKrKLfsrf6fcw2fZOf)7NzGjaYIKqphzSCxgHJhYXbtJdH88vZBTMvfZfK7GVXreKXbnpYFuLrOknKjRCehQ1FoXEVvXkP)fj68YQ9Lt9CtI1az(CMiW5yyEGMVHEsLfZE2CEwBRGo7kYEYcZMV8cyMSUgmLSXSlqZWvKqbhWaEbU7nYkpAS1uR3T8ztVRYxFIbHQkWaYRUoMHkqgi9aH9RCD2W7tuaVSlwdVbaPt6Uxel1GVZIrLtr9Xvnfxy0Zcuuwu4)HCkvPeg3USgom6TQkBp3wYtuIUlh7nFceB5JISsI4dQQF2uk3DRsi4GiWNMQW(LMCFq02nCBQYGp6QdjpcIEKxcehd8CAJ1oL2BmWmGDahL07V6pCosjiGsrwZCvn0MzrQkv0g8VE1c17a5hcfzHncLk6VMHgfxCzdnAFzvo0zW7sXdD(uHMMygn3Bw)T5iMQ8NAkL59lLpmvP0uGpafQ0K(7LIoTx8FxR701j4DR0Jg)Y020CJiJMBCPRGUB(NzMJMQNnKqX)kkPPj3xqvnnQpQ61GP6pMjXwTqBC1YEghn(mzOxT45Mrclx2VjO)0CYoE0j6Jm4vLVDY4m)NGnI3ii8UvsQLXEzCbOFq6Nk9VI8QfRztxE2cq6dPYGP)Al(zVhQ91RGTL)We0IZIS4cXrONV(9CX4ZAugW6HSC(3Q6BJQCoShDijIQtCIeAV4(SdG8v9puRIFvBFA7CAziT61KslElSDuQ7bJXpDY9Nt8rPjndxFYf7hi1MGFllrWjgx3QXjtp5w2KvSxAyBfZGHclEIONaDVGf96JHCacJ73dP4VrNhHXwmdFfi(ajrSTHrHcijsjJtIr2snu8aa2Jdd5i1Tdwnn8)OimnL7RzQqDdD5Pr4SLLh05D9SjBuj)TIOiYkTll5GAt730bq2BQ7Dsz3wcvDzj)ilf0wmhompGhLbfrP23MLCeMt0Im7i7PRjcInyymmJAvS4kBneCGn4O5WmLTQJk0wyntn2z4cwrCZqEQjS0JlXDn6k2(9zjDinILliH43L(635K6jaEO1DY(gPnFKJSOO3Fs5tNPNfUusxaSxREYrjEp0L8MQI(yhrw2wodlwos63OpsQjYON)ps4DvheH2XAKdIiI)Az4IYb2V4q6BW42KhlpAc36TX4o(b1XAWJtk2huECdmmKgQxcXvOnreGHotkZ9CeIf4pIB(G2cu9aKQcMjrLUT8qnyTA(PCG5IWiS7M7ar6J1uWpd7t6ildpSKXGkxGDhf(8HcVaPEZGNKImQm8mVJwCDPqJHS17Js2INSJsFM0nG9s39WylvNOv2Y9qmA8vLB0zBTEP2CZZv1I0FPQAe2w1dS)8zJzhAORu6Hxv(gDwHpFYZ2vGrdrbmNEYUc0jX1KUj0Fh3MezH12Ru343lzFVD8Dr3YFh8RJ3Jhb4rkH)2eQugwOtIFelUwoiTaVTCKbgCphVu(jm0PHW0ilvfj12zToeyX0B)Zk5IhCGSeBkUc)K8CdKYJyBx(uPOrHhcXaK8Kw6Z(eSIU68iGWhsJQMP7sIIsoMJqeWsWWVfWFatUCuxIbPqqea4xY4FkjQg9ASNmHVnavj8FhdykZrjEf8qvLNccKXMSqiAgsFEasyaJWh0(Xcy2LFZrVihIUPPpzi4wZbVklUfhRTchs)KbWLDVIuFNICcoERiKocRC42knGO57tb78UwBhJGgcUyCPRk8woM1McAEJ2PwGo6FsET7iLQnfaTblSEzj4jnJzVFss8tsdU88Gl9mclPh42xN8D6fsmyHBfZ1kyE1TV4O52iPEPBVUBD(ZSJhsZQ2VZW2NdU489G3P(XawwQtfellrZoWTviRvHDyXylshUWjypqiUnur7nkm4WoBIOitP24XI)ebTjLmSWVw0(aaT2t1lJ1fAx(XAvHt)0M1GZxo8Yo3ofOUFmUaSz9M14XINJxagP)f8PFHUknLAXMVzZAPi2SwUpb43W2F4WoN3SU1(f2iarzHyDfuNfMB3kYPBTWj9abDozTi0j37o5ElYY)rlwwtSoSZtU3Vckfm7K7iWHie9JU)K7mnnqbFDZATASOHdKXsRYOze7jxqiZjzOVslfU9ELse0TJL1kxdKdMuWpBWk49dqbn2s1ZQKsQmPDFUn)Nwhu450BKxFHfEv3ixdoZA9XK4e6h88ZAtNgTGdfZxAZrTQ)UdqmZxEoXmFMn5u133HiNZoDMBl(VQ7T0OEXb6nAMl5PmgVbAwQ5qbVL2MEk(iJXp5oH0nBPokNR6Q1vAMcdT8Lyx70gk21a3anY2b)Qrw1EtAuTJaBRE4ySfhOFqMNjgybzC75aqjJ2csC2dvAxmwxOJ1seyR9LYLoZQ3eDn0ED)6e4ZTfRHN)PUMz80tjP1wtK(n1Qr1jPkt)Bok6lPsD2ciraOMD9R6ZmX8RqWLpsnfyunqdZnxToR2cBXNvTTvx2gA775sPBR9VGWfOhbDxr7fOqRRDNeLHJ8M3IxFO(akiVhJMaaONBt7YlQ5e08sd2qSij9dbW4nBCymVe7uVv)TDRhhOeue2FfCB9aDycPIW(ke37IBLHqGxK5Yl)AFUknS3DMjAxQ2(CzEHicNj1ZAtBp6z19k4VH)EzWFRiQX9pOPvCi3uH6KwnuZ5DuZlcH7hii4TJT()li4)nS53RWM1Vgfgd9BEvmiXyslGOya5yFqVBcq3wcKZMk6)ba0THO(fcq3wsNQZG(CiL30hS8UW8TvB0O8UYMxJY0EwGFRiWYObUBwGLlv2uBHT6gQ2XCTkF09sCyi3ZDRuNiFRJhTbi2oxOdYbapmWHI1T9q7CHcudZkAIUP2(aazFqtIn9HRV)9GnGnGDz7XAHT0l)vV)IbBshUNbbWJG(3d2oT7grFq4gu7pV0KUxH9E2mMDlMrjhn0Wxdd3CGQjOG1(An1JlbIhDrgm6AkQUNdTqRPIPOZM3e0nfVRVub2fqRR3qTaQVQcKxEFuzcDwl)e8(r8xRsCY9tPuLMaJ1pM9bcs3Eza73FczZtOBNIzhZflvRMMUrfDd3Wxys56ayBaW3h3BchH2ngqn8Rqqw2o7fzX2(o9EAHvD(KwknxgP29O8p5(QQ32(aDOMIjHaAx7gDjkxFzr6x3mKJzYfSlNoiIF32Mt7ZXCiBLXku53HDrBfyT2krN40EMsnopCYi0ZzIRV02ls6sY7fES25L3lay9jwFWF7cu2gMuBM)o(fRuDN9CwrDhdtiDpxH43l7VzzVymhioUMNk(fJEZkkh7iqoxIqRPp6M8QNKhBuTpUShJdURG9GjRD)uLYGAXSb2NKsM5AYvO8Ppv2cZMBSFn9TzTcQxRI4lMzs5gKy06itPi6zFI4IqL)H6DQVF4MGDoivW0UPvkthPj)(GxdNjV93H8wbLnOZeIZHPI6TIORYz87yUeIP524mM(piA(192rJjecmAFgtiF6BnH7DqZGM91vndm9vdxdA8Dvn20uWu9xtCAojjrI8YYxyCtiRVCTh3Bx1mWCJRVW9SycT9G0R6DLRfHA5lCEzFs2uMaIvicWmG)O6)zUGpDZ)9d]] )

spec:RegisterPack( "Fury", 20261027.1552, [[Hekili:TZvBVnUns4FlPfW1UBwhBNZBB3lja9TR9wGRTOEbUVzzAz6iHil5krf3CiW)2Vzg(IOKiLL3nBVVCa7UXrICMHdNxEMH07YPlF)YfByc(YFz2KzVz6KzF14PZNpB5cXt75lxSNf(a7E4dPSDW)(pkZFcF4tjzSn4ulYkZdHxeje7lE7vxDFSiQC94WSDxfXZzpeNeB(WYfRlJte)Z0LR9WZI98WL)Yu4T8Iqj3oU6FZYZJZYpUAp(Jyb8OT4V(9jSII4WJR(XCgit5zBJtaj5Z)8JRAmXH2d94QPa3gD8D4axqIFXBRtnZuxeVdM9pv(068YIOFkwCv1lgDC1g(wwzIO4sAcH5STIJREp7rEE6XvxDC1HSdI1HJV)ElYlfT7lJHL4yPq87Gcgiw5U9iLwuMUHNdF4h47YYzjX)N4uGalIYkfWt)DE6g4h)mBxHiNEZbo7r6dS0nhxjIaA9RGiSp7ahw7ByPHWty5W)eMLkYZss4W4ItvJ1OLk4cbqhuQo(owOiolTy8(CoSxUMjE1TxTMNxWZFGNhuiqQEz82BxxUD7y5VoEt2HupZKjej8GcAnONL9dhNZ3XItlU56jwChMziljjq(RbjXfIlr7WBJtJf2JAF5UD8e7NKxM2EAGy(aYE8NbgRPtnlZYUsYBOigxU)0uHwTTw89E(GTgpTi(XksyEIBQ4wZj5R9omQlHH)ilpMTgKqAy8)Khwk4b7Jyf8lFKLuIAV875IXrCwIiA8(qXnZMCcYeYsd(JsEPMexOF94Am4zJPN(X0KqJ6UPp6c8apidm3dutvXPwuCTiGT)UjdaDLymOeG4AbKlYDEg7Pyny2MSjOq6T2GPB44oK6Lb8uCABgOuGI4D8arwWMy(Ddho)1Ybpwnywo41JEuHpm6lNoE(OxDTmkXVUNNIo0Y4dqyjf3oU6ZWxboYqO3Qx)TiD(SrqKTTX5fqCj5A(4QSTkh)TX3hHruktfXjW7RMlSNCC1Aos0qwHy8jufzKKvxvu7zbhyPcubaR8BMozGKA1xXKwPigSJVd)4GlG4hpgCF4MXtRnWZrwcsZoOKhJHxTbmihc9ooSmpNNkU7wxYvygO8ENCl470(9GQIC5ERsvMMLVJLOdUNNb2yiHQKvtedqGJbDbK0zVqgkISjGqGfqgHV29mSfiCsUxmUN7ze61dbsYY2G6PlllaxnWSg2uUDksls7bHHIdJbT3Sj0g8Dt8qhtqtIy0Apbu7JJ3b5UFKVjO(igRDBQZLPDZfaRrwCyGmWqBjgNceWe0A7I5f3oTHbGXboQGKHaruoh0sjBgy05MyAUfGWeiD8j58DE5SC(FOCFdNjIcoexezzCzhWz2KNDhdUJn)GTGzTh6nD(5rp5NHvQp6DEYhGX4HeErrk83AEg1ZV0Mr3m9nUPiUXfl47kotxXA5dgm0Bq9BM)SR3zCch5MV6SBalRsI6i9N7zFikop5qmGCSTL4So25fruUJtttpj2hmmmdmFbCHJTONEXcHmEUUxW85DV87oeNeuAlppJRvMgvCabkEaTlu9WCoBZtaiQAEM3CRKSshYCUaeCiMKzzzMUzhCY45d6Cvp1EagTO9R95Bxvpqv88MyoWrrV0a7qzU1E6NkYFKUgdKpMFj4afGcsT6n4PzOnII9rRwuPHLyyRYbltdIfpzk85sv5qj8h5jekP1COQrUJK4aukAuhxD9Kr25Sj2GH0JWWhoZwJIZ3UvGe77Pr9wluuCKDXs4w0hbuv5uTEu9Rqjmaioq03yEobMO4aa(eQDecNaYFwbFeSyYqAaX1nVNq15sA7hybC)tvcSKDriAV0mTKSM)ugQ)Eps)qeBZ)cqcYr4nkjBnNKojcsmgmOATIzaihbcslp5svQd8k2TkUSLFSmT)Gl852EH)v6GHN2N(5lu4rSnov(qp3PLlcsDh7pRfl7gfws7XJqjh5AP)bbrZm7pg8zAI8)gytghS)6XmPzTXo6C8K(uKRxZ02z6QTr3kJS(TIijlcty7DLLxNgWECgjzMdc6oDZWtMV55MCE0zMbsla5Cj2cdhXhyYQvNl3CTMj4GOor5QC7VXLP)lCwoDwQFq3EgRevG8aboPYWfzuj3By7O4TQw4ujFMU74i2ONrzddslfVNL(aL(Bi(jikE2gUPvFyELCvwNFdQALtuTQrRq2WvQgIITmRq1grydxK8e2XswYRpeZXSbyLVxztJ4upQH)oW(i5KyRJtIfW2NIWzPizP(gUd2gX2uEGAQbRAo8)OmE)E(glvfkBO7knIG1SIOwV7ePW)TYejiHT5z70amUYv5(6K7QMQeV1vsBRK1GzbKOvLuLDG90L0esDOyCSIAea6cF99RN9XO(WCLeSLi0Kz1ds3A4cwzADyPuVwPhpqNaND)95zTMAcGVGyYM2ZV6Db7dfanSAczxJ0NnYbwsYlhx(Yj2q2vC6msl71sojl8HoQNHef7XoG0SnmgMnxbzYEKuVIrl)FMs8JMGyMFjgvPbnWIe(RLUlAdy8mkEl63M9OgTAvCVvdFGZ3tUr80SY7Ju4CzOlnGrRg(WrQypiUta8DUczVnasuuWijASxke9Sg94uoWcrCc2eZTal3GziWpd4vpWYr41dbrUeBck85DLHrs5MbpzpsiL7zrlPqxgbcm((KS1iqyT8mQTd75cJAONCl0oRcm1GHVOatnrhQjRu4HxPEtlmRp7xa6UMoLa4o8KFbOvGRrTdO)rczK0Ww4gB7)EoGYBz7IML)oyxNc()6IRwNrPYWeDYAwWKRQbz54TMJeWH55W5YpHUo1yM102R9KAASw5cmB81)PHV45ditXUh3HFsE8awfJ2MogbnjExm6GuK1qEUpdZORp2bW9rEkN6v62SKKSdfiebmfmwDi8lWIRaLLuGleeHSCH0)NcIAnFlYtQW3hHIe(3drmT6qHxXCkNBXQxr5brZqYZdqadyeBaPFOawDfxDimjGM349p5W52Ya3ef3JH1ArajFshyfUus8dklOsiA4H0IzQH7l1qrcBxxcyR3bEsGtSYztbnemX4st1DuNruonV1QdlOH(xuuzosHA3NG1ZZcZZWI(XO3pjN8tsfU8yFvwgXQ5du7BZ(r7ejo0Wn85A4mF71FWEZnrs9HwYw788NORCKKzQrQFvcr3GbW60(0(uP60oXYu0SDCFjYAKyh2mwJZd34eShie3oYO9wng8drXjKNPuAGkO)cbvKsoM43YBVhGw7i7LZ8cnt)4nRWX3TCby8vaVS1njbY7NIBalxSCbE63f4LvrAFbF6xOR9Iskw(DlxizXYfY6eGFcL)WHQ9xUOr9clfaR8mzBb0Me(7lfsTRBqnlwhJ7V3DC1KJRgCC1f4EOZwFPFDhT6dhXqP9HwHFC1n3Ql8SrvaRE(zIG(36KdPRK)KKRdVrJUbZXqio3WpUAuLsTzTVlxyLZh3ibv4FZZgID8eBfR3C5KuDnsY5E3vSrVdRrqfotU)uTDzjb6QaCj2VXlpQh474kGjtjEuxfIm3FV3Oj0UjyvcxnayUeWVQ3c4D9qaD2LUtkKYz5s6(Ap76g)dCqFZhQVATE8PDF8M2GmCMlnZ7i)H0(cTVbrB6epYMQfG0y8fOYYNHgNVys2T77eBGZOvzhTjKK(ze7Ag0sZU2j2Sz6qlRbFTpuQdDlEJSLq)5qR8IN6lYa2LqBjZzpgjU1usKBGvIHPFJYyaT65ij7FdjmnJPy8d1Ds0wIC0jYt5G5RJKlrtKfQlRyNz)ACLXKPodKx9t8620v2p5DW7ez0ywx8oRDJ6x4TASfNIRy8nJMZBDL86h9ntS7O(1szCMCqI6OZa((ASx)4GzIUcA3RnxJmkWBsR6IB2LPs70Ynwmw3j0USA(atrprkQvBEDiQM7B1FjW6C5a8rUy728)LdpIV4t1Vxw11I95gCvf3QMyoTLy()Xe1pH88XevDVWC4e0mBfA)GjHDFNE6cvv11fRhSz68tXgViKQUgz9HpNC54fLL91lZPRF9ROgXgxsb4fp9nDItZCTZ6eE1jdf9xaQvFqQ0OwTel7ssDCx16euK5gaDkuRevAg2OMbPfmzFjhDYTl8zZOvSNO83BjqRTR8fFX85A9PpxwBLut)nhaxBC52irSR2f03obmWAz26YUrwg4PFvBy(AgW0MdS1T8spS2Pm9w7)mFXi6UuKEuhY5vQXmFXq(uJU)fx3tiRiy3DaQY6W27c7uV6N25gTt3imxFbyCReLu0rheDmC3ocUWGvzPvxoohSv0jJ70Wuyo48gWKOFf0b0H96cZKM2vNsTFg048YRyq1zFt24DnlxWIAyNGh4(NwH44QVKcf5cfu3GL7j64Eedw08a5LDqGUUdUnmNnxVB66i6B7UHVWLW1cPupWn3QDW1c3iSocA9W)e3rylp12Nn8XvVQRggRXE5x66tusJW1vuKULnhXygDgLx0ck6hx9fnpyS(udHxmQFeLV6frRnaTM(PDSKQDaRvyDCFiR2BTDcHvn9oXLADaSViipRDWSDci0N6VLDXT6wuEkTOTHHlyMNkr8lsHfZFjqXv)ywFXWU1bcKtfi0B4J2bV6i4XsDRBv937C6ixhWYQJQM4b1ExhKpBpPMRMRUKi6tQ2hwVI6f0x5sduVgjXNnXLK1l2y1kefl6OenCtWyF087vSlyN9seCvgRwyAXn53J4k4mfn)Uh3WPS28CH4SFIODpaAlCo)UjlHy6U)jdP)aEZVUZwjmIqGr1zmISPDEoQ9AfuVHQ6vGRVsXwqJVX0rrxotvF9IP1KCksKxE(Ig7cz95l90P8RxbU7y8zwZYsvqbwPicJk9Z6)31aF6Y)7]] )

spec:RegisterPack( "Protection", 20261027.1552, [[Hekili:1Qv4YTnUr4NfF3m6KsCOLSRU7QRTNjP9YC1Z00BQYm9FKeIeseJPi0baAf3XdF27UliPajbLtC7njXIMyb2pSy3VDxOeUi8ZHRszgE4NUC(L)4I5x(tblwU8YWvMN2ZdxTNL8aBl8qbBh8ZFtjn8eJqwGd9uUKLIlGwwQsGHZmM96RV4ITctw56Ge5UlY4k2dICr7dHRwxkYn)9IW1JOz9EEs4NwaJY1jU6Sk(FZukHuvfVh)qyEQkEd(R)1CMwlsQI)ffdqMsUrKd457)(QyVtFQ7eQIxaAEw19O4FehojJPyjgUsxfFa2lvX7KAdOvPOWaVtu4UUbvXvXVp)a7jyidR4b9Fb(mJxfRbJM9vvX5cCfeGiLAEAv86NQf6JLk4rwb8U3R2PTWOE)j41A7VX3Wl0Ihb5xbRxc850ptR7)qMYNDoGZmrsMvbzYdniM2EeMGjKwYYF3bbpp1Q1loUhMbQmN9uq19v3ZO3Od2R4Wj4AM5T3Eb8ttopsNjlnNl2C76YnBcCFzGIVJjk03C1CN1aMzclppY(RrOn4C0t6wrHW4kLQSyOqKHZbq4KazFKPeS15CRq8VWtkn8O9zmn)8hz5L4evB5MGmol3KfSpXCZLZFHLjHve97L8YML4SMHd6OGN1CJruSv3(AAsWBEH1xBuIh4rYh5QO6PwRPbR4AteB)DZNOnmtayIHqWO9YdC1DJi7lPA48jpnsxwKYv9vAkhpkRhmIxGtlDsTb0i2XJmYOub)UPtx(oRWb1cZu7KQanIVzVzrWYzV9kRZ7)CpVGdHrRi5ahVATvf)D4qqCift1m87X157MDnelluOtRDpxfl3uhISrSnZa(4Lfgrom(X5cNjqOehx0eM2e8cMcjHSUMIoVl6aRWGgayNFZI5tSRw3Dmzv0cii8o8XjNbbkpgTnjnyrhb)wWsuH8qnEAD86iWefqdhKuQu8cZD36dxjye)92JaKBGS4oSeaFK9CaSKilhzADPhBivNrmAUuhmf3YOKduvNGgHiRiamGWc4e1z2jXwd5bSCB0cllWLLyB2XHnuAdRl74C4)EPy)EEQZjmInWQALiAntNnymKiFlhjSQ9ObMkTiL)Zwq(BL55KvAJsURk(deF2fFa495Qhipyc6xF0FR2dv04zQpaHFXhWamyFaVsDqOro)mfscJhAW2asnConbFm5E2roNQi2pJI6sBMyK2oVY9FLofDfZo7i8DrkUbiTbdEFi0xzNdjTIKarb4MF7IbIByqOjc1wEfCGi61uSeqNDgB7wLCWuHeXgsjPdN)XXIasCynCy0pLKJ5JCaYf9)pT8M5blhOP15szkAB7AXqTsNcGHvKiGdl3ms98KZLjpmC6DHIRStilBpNHlxoX634kj4Zy98)vUsIL)SIslzlBW6qdQiN)oB4sJdCA5U9xJXTYh51Ybo4CiXc62p9boFpfgXlKLBZQRjJHH0SuiY(dOnXKHHoZQ5EoaXcCixOfnocyHcYKKiHvxEOOU2iwVegwb1qcbmJWgqLPiRj(mu42bMkfl5bGCjMrbEExjwFeIBgwkhUq1HN6bO48ALwiRI3MlxZYpINzddyZiRzKnh)WtouAisc2X7asVBxmzA3JQUNSzAk2CY0ZmSCy8G1hXvqDc6NBatNbRlb7omv0o2xE2l7qhSs0dVTEe3LcF)SNhhat(AaGF6PXbWaIRzdj0Z5ShFrt8DlMCklSDriR8W43V(cD947IUL)lWVUaI)To5q1jskvgMOJIhOKR1c5e4TMJlGh3ZPlTpHHoDuMZ023ej13z9yiWLbx9Lw9IfBztXUhpHFYwRLvF0YoCDAbAUyNadq0YE4zReZO3udhe(qiQDNUrMNlpq9ZGPGHpXwPGnh1KvbOfQebPYyJ)jsuN57S8Kj8ZziKW)DiJ1yoQRxbBzYw5iWyZBAeIWd0dAoirkG(Pgy3PV4qsEenVG9p5j42XbVLfFehlOACcF2ayY1rzHFuPMQPRxeYaLvl(yPg05SDNcGdgdIKGG46GT6sdbxmU1vfgLJS2uqZ1nfabeTOJ(pOp6osuT7HI2Gd2eLud)kYE)KDYpzn42MfR9me1ZhwT3l)f3ejESW9I56fmF7vV6O5(vsnAdm3S8zFJ1eRpmpFkhgNLl(paqoI8UidLHgAs9ApCs9zt(i4D626uDQUMGy3BvWBISEj2HdJ148Wdod7bQIBpz0UUPg8dzICkY0IgOP4FWGjzzkmXVt0(xrrRNi7L38c9t)mAwHQ7dxboFAyWb3DeK3VapacxfUcVibnE9uy7xWNFIUSRAme(HWvY9HRGtSWvwnbRADRx0tr2R8Qt7)4aqpAHRgCddvX3aCSZdnaKEnQP9(hAvXzvX(VdIQ4NFUTxUHxebcHREnqWZvu0cMrU4H47QINxfpH8r6EzfWy36bL08qi(NEvq09QmgcoVxMbbVHxObH9P0FHCqVd4MgJBOkEwv8BWBjCj94BRIVc3blFn7Gon13Ud8DhewClWyDW1AH1m7lM449rq7j7uazpd7O37ntGO)h)Fg94Dw0Ud8FRfeoCJ2TEfJfzhI)b7k(bFHRnaZPHFFHBnIz79h(ujGgceS2G2M7aWxGsRoCTwolXziHQ)MX)g3R(eNcJg0CUVOLgC2hhHRCkngnHE8tBMl1DU7MZtZ7ooHTH6GnGA40NxuZAFSt5XvqVE2pQGESQNAwig(Pt7NGn9)hlii2H5blrW8Z9aZr962(V11asx0c227nW3j4FE0fD8lfWsxqx5IFhZlx2CA67AcggUHd4dClMpk66wixvmO1fKsN6dqEBdUr8Zqo8XkOWMr8uTKshSnfDtspAK6W(tjk)rQsHYiGR3Pq3KVfWDkwKtJnpCmZoEo2zUEpi7t4o(b5DnhKV0POtX5omZ0l9cHXiZDBrWfyJ2Eof0sPPxmghVZjXG40tSL60KhzeorJEUhTeygJiVE6KmJry70eij3yKVUBmuUXii70CijzF2RxY8pWVaSwx9n7yGAUpf3lLi(evRDdvrhgtEIw6SIr1p0N)6yU1(DRnoZBBRE0M)fB37O35LJwLZ4vG8seHJsFmK86eKh2IXGewSYCVTp1go37B4125vDfJuVxNOkTEFXVDMlviiHI2Vk6tHJxjhX8W6TkR0KH26FT5)Pc4Bd)V]] )

spec:RegisterPackSelector( "arms", "Arms", "|T132292:0|t Arms",
    "If you have spent more points in |T132292:0|t Arms than in any other tree, this priority will be automatically selected for you.",
    function( tab1, tab2, tab3 )
        return tab1 > max( tab2, tab3 )
    end )

spec:RegisterPackSelector( "fury", "Fury", "|T132347:0|t Fury",
    "If you have spent more points in |T132347:0|t Fury than in any other tree, this priority will be automatically selected for you.",
    function( tab1, tab2, tab3 )
        return tab2 > max( tab1, tab3 )
    end )

spec:RegisterPackSelector( "protection", "Protection", "|T134952:0|t Protection",
    "If you have spent more points in |T134952:0|t Protection than in any other tree, this priority will be automatically selected for you.  " ..
    "Dual-wield tanks with a Fury build keep the Fury priority, which switches to tanking in Defensive Stance (see Tank Mode).",
    function( tab1, tab2, tab3 )
        return tab3 > max( tab1, tab2 )
    end )
