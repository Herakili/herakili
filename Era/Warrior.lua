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

spec:RegisterSetting( "hamstring_weave", false, {
    type = "toggle",
    name = "Hamstring Weaving (Windfury)",
    desc = "When enabled, Hamstring is recommended as a cheap extra attack when you have spare rage and nothing else is ready.  " ..
        "Mainly useful with Windfury Totem.",
    width = "full",
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

spec:RegisterSetting( "overpower_dance", false, {
    type = "toggle",
    name = "Fury: Overpower Stance Dance",
    desc = "When enabled, Fury may swap to Battle Stance for Overpower after a dodge, if no rage beyond Tactical Mastery is lost " ..
        "and Bloodthirst / Whirlwind are on cooldown.",
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


spec:RegisterPack( "Arms", 20261027.1212, [[Hekili:TZ1EVnUns8pl5kGRD3So2oN7JTXbO96RRa9bQxG7)SeTeTLqKLuLOIBoe4p73mdfLOKiLLZUT79hfOBIJeNhC484hhs3nZ382nR9zc(MFEXSfF68zl(SPZxmFXM1INs5BwNY8EGTh(qm7a8ZVk7qo(WNIsy(iP5jfzEWlceI083CZn7dfbfBN6LC4MaEg7HWOWQpSz92IWiX)oEZwlYmpL7T5NNdVLN7jL2j3)dlllmj7KBk(RqXtNC3H)5)kILNh6DY9BZyGoLLSlmc0Kp6Jo52IWX6d9K78PZxo50pIdCnP(5VPj3QiDD4bG6VV4PTzf5bFFO4M6xm5KRpFhRisKFnrGxgBN4K7BzpYZI1y438RRp5EuPl7lc95tLs)Rzcreh0cbl2d(DiO0Ia4dbjhGFMx(4X)usMGfHJll8boiTFberAYrEg851rSd4VoY5PHX7vJkFYxcme0JVMNLZZEGNvlhugKcuBrz((Ofliml6yySp8a8h)g37HiEEEm8VYh5XaE6l5ZwW5OCXOsJGP2PFK5jctIZNMMXbpHTmXRwDZwAY6iNuxhUB12ID7Mk)ZP(jhJ7NSGKcrfv6pCAg)almo)UBNPjAGspwuKJ8pDIcZfxJUWRcJdf6JkT4WbEK(tYkI7sgOMpGIh)TtLz7Cuj1ZoQTCoxKEE6vRD1Sq9KlGlGBkpop8XAfP6jM5IzlNu71xErBjm8hzzHSTW8Kgg)p4EfcUtAalNF9JSOc06LTNlMgWzrIGPPEI7wm7mSb8ZC(9cEHIfxPE90gc45CUqaU95vpMicde6N)5uuItc436usAPK6WXTchw69Zgb2kXuWiaE9oKV(9wg75en42g57Kxe7dRSTeQphxHkFPdpgjZFuPbueEG7isC8d53pE8Yxlh80YbZYoKKHruEpm5tMpD5KxDRmm)xs5Xu8pnoiHsP0o5(pWxbX9qw76x)viF(htGKI7cZYHuAY58j3KDL5N2fUpqajDkIfHqEjwnTWAcKxGJm1JLlMEgtrcPznnfnEMZrwSanaWm)U5Zgj5wZzmzvYdb)47Xpo6ki)XJo798NoVXaVeDXjo5yP(u541yaJYGYIt9kYY4XI7xzsV8sYfNZvasE7Gvf9RIuIa(nn8aup7ro4KadyAgK05(vlXqVULn0mXYiumaoa9xK5Rihhipzou35ZnmwDvgPW801aHxqMztuhLK4J2WRlYHWqWLhwWwnhzezzHuuHEHGLDXmAX)(zgycGSij0Zrgl3Lr44HCCW04qipF18wRzvXCb5o4BCebzCqZJ8hvzeQsdzYkhXHA9NtS3BvSs6FrIoVSAF5up3KynqMpNjcCogMhO5BONuzXSNnNN12kOZUISNSWS5lVaMjRRbtjBm7c0mCfjuWbmGxG7EJSYJgBn16DlF207Q81NyqOQcmG8QRJzOcKbspqy)kxNn8(efWl7I1WBaq6KU7fXsn47Syu5uuFCvtXfg9SafLff(FjNsvkHXTlRHdJERQY2ZTL8eLO7YXEZNaXw(OiRKi(GQ6NnLYD3Qecoic8PPkSFHj3heTDd3MQm4JU6qYJGOh5LaXXapN2yTtP9gdmdyhWrj9(RZlPEQZrmtH10xvdRzQKQ6fT3bGEjd17aLieQ0c7gkv0FHdnkU4AhA0(YkFOZG3Lki68PcsnXmAU3SiCZrmv5u1ukZ7xkFykvPPaFaQwPj93lvEAV4)Uw8PRtW7w9hn(LPTZ5grgn39sxbD38p1mhnvuBiHI)zuxttUVGsBAuFu1WbtfHmtITcI24QLnooA8zstVAXZnJewUSFtq)P5KT9Ot0hzWRQH7KXz(pb7gVrq4DRKulJ9Y4cq)G0pv6Ff5vlwZMU8SvH0hsLbt)1w8ZEpuaSxbBl)Hj8fNfEXfcMqpF9FgvKpRLzalkYA6FJQdoQA6WU1HmjQEYjsODL7ZoaYx1jrTY(vnaQThQLH0QRtkT4TWgtP(img)0j3FkXhLM0mC9jxSZGudd(1SebNyCDthNm9KBz7wXUQHnymdgkSckIEc09cw0RpgYbCmUFhKN)gDEegBXm8LG4dKeX2ggfkGmjLmojgzl1AXdaSpomKJuFpy10W)9IW0uUVMPc1n0VNgHZwwEqN31Z2TrL8xlIIiR0USKdQTVFthuzVPUlkL9Dju1VL8JSuqBXe5W8aEugujLAKBwYryorlYSJSNUMii2GHXWmQvfJRS1AWb2QJMdZukRoQqBH1m)yNHlyfXnJ7P2XspUe81ORy73NL0H0iwUGeIFx6RFNtQNa4HwFk7BK28roYIIE)jLpzMEQ4sjDbyFT6jhL49qxYBQk6JDezzB5mSy5iPFJ(iP2jJE()ab6vDKeAhWroiIi(RLHlkhy)IdPVbJBtES8qkCR3lJ74huhWbpoPyFq5bpWWqAOOjexH2erag6mPm3ZriwG)iUdeAFq1dqQkyMev62YJ3G1QnOYbMlcJW(CUdePpwyb)mSzPJSm8ytgdQCb2Nu4Zhk8cK6ndEskYOYWZ8oAX1LcngYwVpkzlEgpk9zs3a2lDleJTuDIwzl3iXOXxvUBNT16LAhopxvls)LQQrydwpW(JNnMDOHUsPhEv5B0zf(8jpBxbgnefWC6j7kqNext6Mq)DCVsKfwBdtDJFVKn)2X3fDl)nWVoEpEyGhPe(BtOszyHojisS4A5G0c82YrgyW9C8s5NWqNgctJSuvKuBN16qGftV9pQKlEecYsSP4k8tYtqqkpITD5tLIgfEiedqYtAPp7tWk6QtMacFinQAMUljkk5yocralbd)wa)bm5YrDjgKcbraGFjJ)PKOA0RXEYe(2auLW)DmGPmhL4vWJxvEEiqgBYcHOzi95biHbmcFq7hlGzx(nh9ICi6MM(KHGBnh8QS4wCS2kCi9tgax2hls9DkYjm5TIq6iSYHBR0acPVpfSZ7ATNmcAi4IXLUQWB5ywBkO5nANFb6O)X51UJuQ2ua0gSW6LLGN5mM9(jjXpjn4YtgU0ZiSKEGBFvY3QxiXGfUvmxRG5v3(IJMBJK6LUh7U15pZ2EinRAtpdBZo4IZ3bEN6hiyzPovqSSen7a3wHSwf2HfJTiD4cNG9aH42qfT3OWGd7SjIImLAJhl(Jf0MuYWc)Ar7da0ApvVmwxOD5hRvfo9JBwdoF5Wl7CpvG6(X4cWM1BwJhqEoEvyK(xWN(z6s1uQfB(6nRLIyZA5(eGFdB)HdBFEZ6w7xyJaeLfI1vqDwyUNRiNU1cN0de05K1IqNCV7K7Til)NTyznX6Wop5E)kOuWStUJahIq0p6(tUZ00af81nR1QXIgoqglTkJMrSNCbHmNKH(kTu42Bykrq32wwRCnqoysb)0bRG3paf0yFvpRskPYK29z28FADKHNtVrE95w4vD3Cn4mR1mtItOFWZpRnDA0houmFHnh1QM8oaXmF55eZ8z2KtvZFhICo70zUT4)Qw4sJ6fhO3OJUKNYy8UOzPMdf8wAB6P4Jmg)K7es3SL6OCUQRwxPzkm03xIDTtBOyxdCd0iBh8RgzvpoPr1ocST6HJXwCG(rAEMyGfKXTNJcLmAliXzpuPDXyDHowlrGTEykx6mREt01q719RtGp3wSgEsO6AMXZrLKwBnr63uRgvNPQm9V5OOVGk1zlGebGA21VQzZeZVcbx(i1uGr1anm3C16SAlSfFw12wJgIw9(9C51T1dyqdeOBbD1r7fTqRBHNeQHJ8I4I3MO(qliVwJMqbONGt7UmQ5j08oe2qSij9JdW4fDCymVeavVqaSDjihOeue2FzCBncDycPIW(Qg37IBLHqG3R5Y7cBFUknS3DMjA3X2(CzEHWcNj1ZAtBp6z1nm4VXaFzyGRiQXnrOPvCi3zH6KwnuZ5DuZlcM7hiC4TJT()lC4)n253RyN1Vqfgd9BEPmiXyslGOya(yF4VBIs3wcKZMk6Vau62Gv)crPBlPt1brFo4YB6dBExS(2QnAuExzZRrzApl6VveIz0a3nlWYLkBQTWwDdv7yUwLp6EDomK75UvQJLV1zK2ajBNR2b5aGNi4qb82EODUvbQHzfnr3uBFaWTpOjXM(a33)gXgWUWUSnATWw6L)s2KXGTRd39Gq5r4)7bGN2TKOpCCdQrOxAM3RWUqBg4UfZOKJgA9RHHBoA1eEWAhUM6XLGZJUsdgDqev34Hwq2ubw0P0Bc)MI31xVa7cO1fDOwa1xAbYvVpQmbrRLFcEtj(Zvjo5(ju(stiY6h4(arQBVwG9BsHSnk09uXSJ5ILQvtt3TIUHB4lmPCDqTnam8J7nHJq7UdOg(vislBNcJSIBFNJpTWQoPsl1NlJu7EO(NCFv1BBF0ou7XK4aTRDJUeLRVSi9RBgYXm5c2QthyXVB71P9jAoK9ZyfV87WwPTIUwBLOtCAptPgNmoze650X1xA7foDj59Irw7KZ7ffS(eRpmWDrlBdyQnZFh)IvQ(0EoROUJHj4UNRq87Ln5SSxGMdemxZZh)IHWzfLJDeiNlrO10hDtE1tYJnQEix2OXb3AWEWK1UPQszq9z2a7tsjZCn5kO(0Nk7JzZD3VM(gUwb1Rvr8fZmPCdsmATLPue9SzrCrOY)q9o13zCtWohKkyAl1kLPJ0KFhXRHZK3(7vERGYg0zcX5Wur9(r0v5m(9oxcX0CVCgt)hen)6EBRXecbgTpJjKp9TMW9oOzqZM7QMbM(6IRbn(UQUBAkyQ(RoonNKKirEz5lrUjK1xU2JF9YRMbM7E9fUNftOThKEvV1CTiulFj0lBwYMYeqScraMb8hu)p4f8PB(F]] )

spec:RegisterPack( "Fury", 20261027.1212, [[Hekili:TZvBVTTrs4FlUfqvQXrws(uARpBd03U2laxBrvaUVjQvuRejmfPk5sR4dg63(nZSVWLK7sjL4K7lhqsSm5UZm7SZlpZSRY8XZF38zRyc(8FBYOjVz8OjFZWXtgpz(mXt74ZNTJf(aBd8Hu2w4F)hL5pHp8PKm2kCQfzL5HWlIeIDf3C1vBIfrLlhgMT9QiEo7H4KyZhMpBzzCI4FMoFPhEwSJho)3gdVLxek52Hf)BwEECw(Hf7WFelGhTg)1FmHvuehEyXpNZazkpBDCcijF5xEyrJj23EOhwmE44Pdo8wCGZiXV4M6uZm1zXBHz)lLpTmVSi6xIfxv9IbhwSIVMvMikUKMqyoBT4WI3XEKNNEyXvhwSpBVyz4WnBSiVu02ugdlXHsH4pbfmqSYT7qknRmDfph(WpX3MLZsI)pXPabMfLvkGN(N80vWp(v22cro9M9C2J0hyPRoSqeb063bryx2EoS2xXsdHNWYH)jmlvKNLKWHXfNQgRrlvWfcGoOuD4TSqrCwAXWD5CyVCjt8Q7UAjpVGN)appOqGu9Y413TSC96HYFD4QS9PEMjtis4bf0Aqpl7homNVLfNwC71JS4omZqwssG8xdsIlexI2H3fNglSh1UYTB5j2pjVmT90aX8bK94pdmwthBwMLDLK3qrmSC3XPcTABT4p55d2A80I4hRiH5jUPIBnNKV27WOUeg(JS8y2sqcPHXFppSuWd2fXk4x(ilPe1E5B4IHrCwIiA4UqXTtgDeYeYsd(RsEPMexOF9WAm4zJPN(X0KqJ6UPp6c8apidm3dutvXPwuCPiGT7(r9aDLyiOeG4AbKlY9Eg7Xyny2MSkOq6T2GPR44oK6Lb8uCAR6PuGI4T8arwWQy(997p91Ybpunywo41JEuHpm4RhpC6GxDTmkXVVJNIo0Y4dqyjf3oS4lWxboYqO3Qx)9iD(IbqKT1X5fqCj5A(WIS1kh)1XBIWikLPI4e49vZf2toSyjhjAiRqm8iQImsYQRkQ9SG9SubQaGv(TJh1tsT6RysRued2X3JFS3fq8Jhd2eUA44Ad8CKLG0S9k5Xy4vBa9YHqVddlZZ5PI7VZLCfMbkV3k3c(bTFpOQixUBuQY0S8TSeDW98mWgdjuLSAIyacCmOlGKo7eYqrKnbecSaYi8TUNHTaHtY9IX9CpJqVEiqsw2kupDzzb4QbM1WMYDJrArApimuCymO9MmI2GVFKh6ycAseJw7jGAFy8wi39J8vb1hXqTBtDUmUBUaynYIddKbgAlX4uGaMGwBBmV4UXnmamoWrfKmeiIY5GwkzvpJo3etZTaeMaPJpkNV3lNLZ)dL7R4mruW(4IilJl7aotg9S7yWDS5hSgmR9qVXtpp6j)mSs9rVZt(amgpKWlksH)wZZOE(L2m62XVXnfXnUybFBXz6kwlFqV(EdQF70ND9oJt4a38vNDdyzvsuhP)Cp79rX5j7JbKJTTeN0XoViIYDCCA6jXEV(HzG5lGlCOf90lwiKXZ19cMoT7LF3H4KGsB55zCTY0OIdiqX9ODHQhMZzREcarvZZ827KKv6qMZfGGdXKmllZ0n7GJgoTxNR6X2dWOfTFTpF7Q6bQIN3eZbok6LgyhkZT2t)yr(J01yuJpMNgGfEW9gb1mSgHY(O1nQCXsGSvjIL5cXkOmv)CPQMOe(J8ecQ0sou6i3rMCapfnQdlUE0a7e3eBW46rymeNPSrX57xlqI9J0OUXckfhzxSeZf9raAvovWhveluhdGKde9vMNtikk2diqHciHykG8NvWhalMmKgqWDZ7jODUK2tdXaIpsvhSKDriKV0mTKSK)ugQ)Ehs)qeGZ)cGdYrmokjBjNKojmsmqmOATcCaWhbcslp5svQd8k2TQWSLZSm3FVl857EH)vAV(h3X(5luGsSnovosp3PLlIuDl791cODRcqP94r8KdCT0)GWPzM9hdinnr(Fd2jJd2NFGtAwBSJohpPpfj81mTD6UAB0TslRFRisYIWe2oxP615cShNrsM4GGUZ50)OjDEUjNhCMPH0cqoxcWWWr8bMuB15YTxRzcoiQDuUQ5(7Cz6)PivNov1pPBuJv2kqOGONub5ImQ47vSTuqxvZCQestFECeG0ZOSbePLI3XsFGYb2h)eekpBf300pm5sUk1ZFa1VYjQw1YviL4cvRrXMNvOAOiSRlsEc7Djl517J5ykbSg4RSPrCQh1WFhyFKCsSLXjXcypur4SuKSuhe3c7Lydl3tT3Gvnh(FvgVBhFLLQcLn0NLgrWswruR3DK84)rzIePW68STAugx5QWFDgEv7vIx7kZTvgBWSaY2QYSY2ZE6sAcPoumowrnIcDHVoaEID0O(WCLjSLi0Kz1Ju3A4cwzADaQuxxPh3tNfNTztEwRPMaGmiMSQ98RExWUqbqdR2r21i9zJSNLK8YXLVEKn4DfNoJCZETKtYcFOJkBirXES9inBdJHjtv4MShj11y0Y)xPS)OjiM(xcuvAqdSiH)AP7I2agpTIBq)2Sh1qwRI7TO)dC(oYnINMvUjsb2LHU0aqTAGehOI9GGpbe45k492OirrbJKObGPG1ZA0Tt5aleXjy7mxdSCfMMa)maADplhXy3he5sSDOWN3wggjLBg8KDiHuUNfTKcDTei64njzlr0WA5zqBh2ZflvFp5wODwfIQE9FrrNAIoutwPWdVs9MwaxF2Va0DHDkbWD4j)cqRaxdAhq)Je3iPHTap22)9CqM3Y2fnl)tWUof8)1vyTmJsLHj6KfUGjxvdYYXBjhjGdZZ(tLFcDDQXmRPTt7j10yTYfyYWRFVHV4jfitXUd3HFsEqbwvK2MogbnjEBm6GuK1qE2KHz01hab4(ipVt9kDDwss2(ceIaMcglre(fyXvGYskWfcIqwUq6)tbrTMVf5jv47Iqrc)7(iMwDOWRyoVZ1yjSO8GOzi55biGbmIvG03xaRUIR2hMeqZB4UNC4CBzGBII7XWAPiGKpPdScCkj(bLfuDen8qAXm1W9LAOiHTTlbS17apjWjw5SPGgcMyCPP6wQ9ikNMBSAZcAO)vfvMJuO2Djyr9SW8mSYFm69tYj)KuHlpayLLrSA(a1((SF2orIdnCdFUgoZ3D9hS3CtKuFO1T1op)r6phjzMcLoTYHO7YayDAFUFQuDANyzkA2wUVeznsSdBglX5HBCc2deIBhz0UrJbFFuCc5zkLgOm6VsqfPKJj(T82pbqRDK9YzEHMPF8Mv4WBNpdm(kGx26oLa59tXnG5ZMpdph8c8ARiTVGp9B0fGrjfZ)H5ZKSy(mzDcWpHYF4qj)ZN1OEH5cGvEMSTaAtc)nNcP21nOMfRJX937pSy0Hf9oS4cCp0z)V0VUJ(9HJOV0(qRWpS4270fE2OkGfp)mrq)BDYH0vYFsY1H3Or3G5yieNB4hwmOsP2S235ZSY5JBKGk8V5zdXoEITI1BUCsQUgj5uV7k2O3H1iOcNi3FQ2USKaDvaUe734Lh1d8DybWKXepQRcrM7VbC0eA3jSkHRgamxc43CYc49NGa6SvDhviLZYL09TE21n(h4G(UpuF1An6t7(4nTbz4mvAM3r(dP9fAFdI24rEKnvFaPX4lqLLpdnoFXKS753r2aNqRYo6vij9ti21mOLMDTtSzZ0(wwd(6HOuh6w8gylH(ZHw5fp2xKbSvH2sMZgnsCRPKi3aRedtthLXaA14rs2)osyAgtX4hQ7KOtjQr7ipMxMV2sohTtMPU7IDMcSXnitM)mqEtqXBFtxPaLxjVJKwJzDp8S2sQF)3QXwCkUc03mKoV1n070OVzIDh6VwEJZKdsOhDg13x39onoyMORi3N0MRrgf4fRvDpo7YuPDU5glgRRiAxwnFG5Phjf1QnVoevZ1V6Zc2oxoaFKl2Un)F5aL4liv9RPvDT4PCHUQIBvtmh3sm))aJonH88bgvDnXC4e0mLfA)GzIDFfF6cAv1Th7eyZ4PhJnEHjvDRYof(C0LJxOw232mNU(1VXAeBCjfGx8430jynZTqRtmwhnu0NbOR(WvPHUAjw21L64QR1jYiZDb6yqxjQ0mSrndslSY(so6KBx4ZMrRypsnW3rixBx(l(IPt16tFUS2kPM(BoWk24UUrIyx9m4uBhqpRLzR7(gzzGhbwTH5RJaJBoWw33l9WANY0BdaM4lgr31JCcfJCE1BmXxmKplq8FX3ai4ve27oqwzDS7DbG6K6S25gYt3smxFPyCReLu0rVeDmC3EdUaIvzUvxoohaw0zK708qyoc9gyLOFf0b0X(6c4KM2vNxTFg04KZRyq1PGtg6DnlxyJAyNGh9(NwH4WIVMIh5cku3iMpriYNqGyrZJMx2lb6Ip42WCYu9UPRdRVT7g(cxcxl4sNa45wngUw4gH1HrRh(N4EdB5P2(uIpS4vD16ynam)s3PeL0iCDffPBzZrmMbNrngTWJ(XvKrZJi7ukKWlq1pIAy9cR1gLwt)0ows1oQ1kapUpUv7T2oXXQMENGtTok2xe4N1oI2orf6t93YU4oDZkpMw02WWfwZJLi(fP6IPVeq5QFGRVya46abYXce6n8r7GxDe8yUU)TQM8DoTLRdyz1Hwt8G6XRdYNTJuZvZvxxe9jvpeRxw9m6RHPbQxJK4tg5sYoj2y1pefl6OonCtWyF087ASlyNNKi4QwwTW0IBYVBXvWzkA(9rUHtzT55cX5PjI2ncOTW587RSeIP7MO0N(d4n)6o7NWacbgvNXaYM25jQEsRG6DvvVcC91m2cA8TM2k6YzQ6RCmTMKtrI8YZx(yxiRpFPNoVF9kWDBJpZAwMRckWkfryuPFv))4g4tN)F)]] )

spec:RegisterPack( "Protection", 20261027.1212, [[Hekili:1Qv4YTnUr4NfF3m6KsCOLSRU7QRTNjP9YC1Z00BQYm9FKeIeseJPi0baAf3XdF27UliPajbLtC7njXIMyb2pSy3VDxOeUi8ZHRszgE4NUC(L)4I5x(tblUCXLHRmpTNhUApl5b2w4Hc2o4N)MsA4jgHSah6PCjlfxaTSuLadNzm71xFXfBfMSY1bjYDxKXvShe5I2hcxTUuKB(7fHRhrZ698KWpTagLRtC1zv8)MPucPQkEp(HW8uv8g8x)R5mTwKuf)lkgGmLCJihWZ3)9vXEN(u3jufViyXYzv3JI)rC4KmMILy4kDv8byVufVtQnGwLIcd8orH76gufxf)(8dSNGHmSIh0)f4ZmEvSgmA2xvfNlWvqaIuQ5PvXRFQwOpwQGhzfW7EVAN2cJ69NGxRT)gFdVqlEeKFfSEjWNt)mTU)dzkF25aoZejzwfKjp0GyA7rycMqAjl)Dhe88uRwV44EygOYC2tbv3xDpJEJoyVIdNGRzM3E7fWpn58iDMS0CUyZTRl3SjW9Lbk(oMOqFZvZDwdyMjS88i7VgH2GZrpPBffcJRuQYIHcrgohaHtcK9rMsWwNZTcX)cpP0WJ2NX08ZFKLxItuTLBcY4SCtwW(eZnxo)fwMewr0VxYlBwIZAgoOJcEwZngrXwD7RPjbV5fwFTrjEGhjFKRIQNATMgSIRnrS93nFI2WmbGjgcbJ2lpWv3nISVKQHZN80iDzrkx1xPPC8OSEWiEboT0j1gqJyhpYiJsf87MoD57SchulmtTtQc0i(M9MfblN92RSoV)Z98coegTIKdC8Q1wv83HdbXHumvZWVhxNVB21qSSqHoT29CvSCtDiYgX2md4Jxwye5W4hNlCMaHsCCrtyAtWlykKeY6Ak68UOdScdAaGD(nlMpXUAD3XKvrlGGW7WhNCgeO8y02K0GfDe8BblrfYd14P1XRJatuanCqsPsXlm3DRpCLGr83BpcqUbYI7Wsa8r2ZbWsISCKP1LESHuDgXO5sDWuClJsoqvDcAeISIaWaclGtuNzNeBnKhWYTrlSSaxwITzhh2qPnSUSJZH)7LI975PoNWi2aRQvIO1mD2GXqI8TCKWQ2JgyQ0Iu(pBb5VvMNtwPnk5UQ4pq8zx8bG3NREG8GjOF9r)TApurJNP(ae(fFadWG9b8k1bHg58ZuijmEObBdi1W50e8XK7zh5CQIy)mkQlTzIrA78k3)v6u0vm7SJW3fP4gG0gm49HqFLDoK0kscefGB(TlgiUHbHMiuB5vWbIOxtXsaD2zSTBvYbtfseBiLKoC(hhlciXH1WHr)usoMpYbix0))0YBMhSCGMwNlLPOTTRfd1kDkagwrIaoSCZi1ZtoxM8WWP3fkUYoHSS9CgUC5eRFJRKGpJ1Z)x5kjw(ZkkTKTSbRdnOIC(7SHlnoWPL72Fng3kFKxlh4GZHelOB)0h489uyeVqwUnRUMmggsZsHi7pG2etgg6mRM75aelWHCHw04iGfkitsIewD5HI6AJy9syyfudjeWmcBavMISM4ZqHBhyQuSKhaYLygf45DLy9riUzyPC4cvhEQhGIZRvAHSkEBUCnl)iEMnmGnJSMr2C8dp5qPHijyhVdi9UDXKPDpQ6EYMPPyZjtpZWYHXdwFexb1jOFUbmDgSUeS7Wur7yF5zVSdDWkrp826rCxk89ZEECam5Rba(PNghadiUMnKqpNZE8fnX3TyYPSW2fHSYdJF)6l01JVl6w(Va)6ci(36KdvNiPuzyIokEGsUwlKtG3AoUaECpNU0(eg60rzotBFtKuFN1JHaxgC1xA1lwSLnf7E8e(jBTww9rl7W1PfO5IDcmarl7HNTsmJEtnCq4dHO2D6gzEU8a1pdMcg(eBLc2CutwfGwOseKkJn(NirDMVZYtMWpNHqc)3HmwJ5OUEfSLjBLJaJnVPricpqpO5GePa6NAGDN(Idj5r08c2)KNGBhh8ww8rCSGQXj8zdGjxhLf(rLAQMUEriduwT4JLAqNZ2DkaoymisccIRd2QlneCX4wxvyuoYAtbnx3uaeq0Io6)G(O7ir1UhkAdoytusn8Ri79t2j)K1GBBwS2ZqupFy1EV8xCtK4Xc3lMRxW8Tx9QJM7xj1OnWCZYN9nwtS(W88PCyCwU4)aa5iY7ImugAOj1R9Wj1Nn5JG3PBRt1P6AcIDVvbVjY6LyhomwJZdp4mShOkU9Kr76MAWpKjYPitlAGMI)bdMKLPWe)or7FffTEISxEZl0p9ZOzfQUpCf48PHbhC3rqE)c8aiCv4k8Ie041tHTFbF(j6YUQXq4hcxj3hUcoXcxz1eSQ1TErpfzVYRoT)Jda9OfUAWnmufFdWXop0aq61OM27FOvfNvf7)oiQIF(52E5gEreieU61abpxrrlyg5IhIVRkEEv8eYhP7LvaJDRhusZdH4F6vbr3RYyi48Ezge8gEHge2Ns)fYb9oGBAmUHQ4zvXVbVLWL0JVTk(kChS81Sd60uF7oW3DqyXTaJ1bxRfwZSVyIJ3hbTNStbK9mSJEV3mbI(F8)z0J3zr7oW)Twq4WnA36vmwKDi(hSR4h8fU2amNg(9fU1iMT3F4tLaAiqWAdABUdaFbkT6W1A5SeNHeQ(Bg)BCV6tCkmAqZ5(IwAWzFCeUYP0y0e6XpTzUu35UBopnV74e2gQd2aQHtFErnR9XoLhxb96z)Oc6XQEQzHy4NoTFc20)FSGGyhMhSebZp3dmh1RB7)wxdiDrlyBV3aFNG)5rx0XVualDbDLl(DmVCzZPPVRjyy4goGpWTy(OORBHCvXGwxqkDQpa5Tn4gXpd5WhRGcBgXt1skDW2u0nj9OrQd7pLO8hPkfkJaUENcDt(wa3Pyron28WXm745yN569GSpH74hK31Cq(sNIofN7WmtV0legJm3TfbxGnA75uqlLMEXyC8oNedItpXwQttEKr4en65E0sGzmI86PtYmgHTttGKCJr(6UXq5gJGStZHKK9zVEjZ)a)cWAD13SJbQ5(uCVuI4tuT2nufDym5jAPZkgv)qF(RJ5w73T24mVTT6rB(xSDVJENxoAvoJxbYlreok9XqYRtqEylgdsyXkZ92(uB4CVVHxBNx1vms9EDIQ069f)2zUuHGekA)QOpfoELCeZdR3QSstgAR)1M)NkGVn8)c]] )

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
