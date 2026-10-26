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


-- Talents: { talentID, maxRank, rank1SpellID, ... rankNSpellID }
spec:RegisterTalents( {
    -- Arms
    improved_heroic_strike          = {   124, 3, 12282, 12663, 12664 },
    deflection                      = {   130, 5, 16462, 16463, 16464, 16465, 16466 },
    improved_rend                   = {   127, 3, 12286, 12658, 12659 },
    improved_charge                 = {   126, 2, 12285, 12697 },
    tactical_mastery                = {   128, 5, 12295, 12676, 12677, 12678, 12679 },
    improved_thunder_clap           = {   141, 3, 12287, 12665, 12666 },
    improved_overpower              = {   131, 2, 12290, 12963 },
    anger_management                = {   137, 1, 12296 },
    deep_wounds                     = {   121, 3, 12834, 12849, 12867 },
    two_handed_weapon_specialization = {  136, 5, 12163, 12711, 12712, 12713, 12714 },
    impale                          = {   662, 2, 16493, 16494 },
    axe_specialization              = {   132, 5, 12700, 12781, 12783, 12784, 12785 },
    sweeping_strikes                = {   133, 1, 12292 },
    mace_specialization             = {   125, 5, 12284, 12701, 12702, 12703, 12704 },
    sword_specialization            = {   123, 5, 12281, 12812, 12813, 12814, 12815 },
    polearm_specialization          = {   134, 5, 12165, 12830, 12831, 12832, 12833 },
    improved_hamstring              = {   129, 3, 12289, 12668, 23695 },
    mortal_strike                   = {   135, 1, 12294 },

    -- Fury
    booming_voice                   = {   158, 5, 12321, 12835, 12836, 12837, 12838 },
    cruelty                         = {   157, 5, 12320, 12852, 12853, 12855, 12856 },
    improved_demoralizing_shout     = {   161, 5, 12324, 12876, 12877, 12878, 12879 },
    unbridled_wrath                 = {   159, 5, 12322, 12999, 13000, 13001, 13002 },
    improved_cleave                 = {   166, 3, 12329, 12950, 20496 },
    piercing_howl                   = {   160, 1, 12323 },
    blood_craze                     = {   661, 3, 16487, 16489, 16492 },
    improved_battle_shout           = {   154, 5, 12318, 12857, 12858, 12860, 12861 },
    dual_wield_specialization       = {  1581, 5, 23584, 23585, 23586, 23587, 23588 },
    improved_execute                = {  1542, 2, 20502, 20503 },
    enrage                          = {   155, 5, 12317, 13045, 13046, 13047, 13048 },
    improved_slam                   = {  2233, 5, 12862, 12330, 20497, 20498, 20499 },
    death_wish                      = {   165, 1, 12328 },
    improved_intercept              = {  1543, 2, 20504, 20505 },
    improved_berserker_rage         = {  1541, 2, 20500, 20501 },
    flurry                          = {   156, 5, 12319, 12971, 12972, 12973, 12974 },
    bloodthirst                     = {   167, 1, 23881 },

    -- Protection
    shield_specialization           = {  1601, 5, 12298, 12724, 12725, 12726, 12727 },
    anticipation                    = {   138, 5, 12297, 12750, 12751, 12752, 12753 },
    toughness                       = {   140, 5, 12299, 12761, 12762, 12763, 12764 },
    improved_shield_block           = {   151, 3, 12945 },
    improved_revenge                = {   147, 3, 12797, 12799, 12800 },
    last_stand                      = {   153, 1, 12975 },
    improved_shield_bash            = {   149, 2, 12958 },
    improved_sunder_armor           = {   146, 3, 12308, 12810, 12811 },
    concussion_blow                 = {   152, 1, 12809 },
    one_handed_weapon_specialization = {  702, 5, 16538, 16539, 16540, 16541, 16542 },
    shield_slam                     = {  1666, 1, 23922 },
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
            return not combat and target.minR > 7, "cannot be in combat; target must be outside 8 yards"
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


spec:RegisterPack( "Arms", 20261026, [[Hekili:LRvBpUnUr4FlbhGH9LnAT9wNMKABGMEfPnaxAr1b0VjjAjURiw9Ilj16BpSq)2VHKsuusKYEZ9YEafizTSeNzE4WzMNH0kyvWpe4NG44GVSE563Uc(FGp)XJ4a)JO47r3bxuGYH)(xP5mXnFmReLiKIvwrJHhKY5hzF46RVJWtRo4fxMF9)aFpjJCDQ6Ja)dvKm()Si4WyBXoIJd(Yk4bywSYk1r)xeLskP1rhfFq4pwhDR4R)TmeJrIRJ(7ueGfA5TKmabFZ3uhnqW5MdToAL3QnlQ)SyG(syZ(qFTPf1NKds)PQhpqRyPFIWVU7blQJsW3IQY4SRKcetr3YRJ(b0dyAHHc)U)TFD0PwSCxfjb7PS(hrCEggqbhvedFsaqZtHlslZH)YAU98VVKYrzIXrj3JbR9VatCS8eMcx7NHYfFCcJpskURDuSf)fqHao(iMYW07X0o7iSHeaDEuusIWJLsOzNifjWne)5)GJVpdZyfW)BUvmc0zIsphGGIMfdnIGPw9NrXCszbZ7ifdrahq8xV76dYjBOAsDf52DhQU9wp1x9skpvmTyPLvCTuM30JIZrKc22BwAyAqYyuwwO6RHzeg)krO7osbHBoQJv554mZ7qRkglMYIJaGc9vhpV8TRcDQO9opdTabC4cg5HoGOVJDTy3hOqV5cLWRad)beLGoaZt5WW)ioUIJdpMIy4REaLvH3Xr07WCVumkJN6DmMVD9YZOgiIj8)vHRAvXRAFSxpd8edZ5qamtFBPqIq6P1ptgVhwcrGHnI2yPrA8apeDC)YzGVI7bobi(nug1U3XypNPHaWSKqwvrcSYoWOjyXkuZddXfcXsM14a5KCCiVmmHG3pF(M3OgSxZGr08sQi3i((fF7kVnlE9nNdjqvGqrL1e9cvgUG7rYHcJpGbmcdWJIkUF)UnIv(X1F86mHkare)KkGRiARb3qchdkG9olJ9zKPAt6SYYekqXCvfdwmbh3DXj7wjuK4UIaDsmHVF36LZeoV9lTOKumTKehQIigRiX4HmfCboNGz7wntQ54kkfCvgHaPSqXtc5PumG8SKz6qwDWSnNvggQ9FoZU3PzvY)vzAwt1)MPoZMzTiwcgXtdpryPglXMHMRx(K9SvlktmVjCmW8AbFgX1ctPvAVmOzZDMgSDZt2EMoIAHfJ2wmaSxxnhlvlSiAUKXTXBA55LT0DUnRLNaTejXECg6OLvO1ZAMIMJtpfxBD9dakkJ8tYL(2eV5dlbjgM8PTvHEAOLx0A6XACYSwicorysTff3qxRRVv2EtRredss5BRA47Tf(i6XPxyJUC3SxLx(ay6zXLq2cOtVERDTO3A4FkkxmQI76nf03n8KiF0zrc9W6NWQlUoSVlZ6RTpdabPGJHEqpYNUkRHeFDfAnvWVKATM6r3cJuzs83N1P)i8Adm6BLvtBLxMI6ga4fOUUH1)vPgTH(Og903lNQF3yJn02vV1UgTv434X)Uw73WUFfL)nK(u7wHSvO2UiUinCPvhncpB(zkLTB9t9J02SzAxW0LruBiBu0T0HR55cPyuYJWUl6fKVDNsAvSnfZb8bP3A8RfxVyT0BZzRuBoeTdZ8XoIZ(vGKysd7k)0gh8zPGFMeUM1d)TG16SEMlyrrX79DT7iTL37d1rqLK2tlGxwhHeNGqoy)2Z4WGAuVH2HrOogYGDrx)5aFiOJbd08GLoHOfI5FGFGVyFWmXzwPupC1xKh8vZctWhd8vwkWxT9h4tkuFdIQc8hqqhWbR4qytgztv4KUUoABD0ncvEZav2jSjZzD0(D1rW(VJMb(vI4iJ2xhT0abT88b(gP3IPlyJ)KtB0VAxDeyKvsBygtPmUB2vPaJ546axpADBaCZfdW9xaaTscFwqQKYg6ERJv9H7e7C4wOR)SdD1r9Bje0GzwQjrCWtpzmD6rQimZ7Cygn)TyqV318YG61en2zZLo25Iti1bNUmwFJcXtqURsjQJwiG2QLoWwZm1ewVYWryHZxQoxz99QakhPRuCn)MCudZAhcpXygM11ogZT8DMqM1sN7eBvu60wln3WCOUiRHSoMgDUrEJl(l1sND4TWeHUj46Q3TYv2KyNIMiZ6(mLwBisuXnDWqVNtv1s75qVxcgxPJI(jSh6RB0qQCi2t1UH8BttS2veyLR0tnLTvhXaE)Zvg0f)pGaUiSq(dAmjL4GtuwXNgQ(zHehn5uuIQdBFAgoRNVUrer)ZfVN5Bi0NKCZ1zVFHwOvWPjOCD08xMr0cofpZKRdAhbx8dJ18JPm1QAp)9OzIXpsZVbn8SuHZox7e4uFyj))rpzAH6Dmk9N7xYbU0vvOhmxncMpR2UEH6lCygXFS6l8fUxoZt3Xkxv)tisAfBGaI6bs5j6hSxtJo7m7pcDn6QwYxzxJUkTO3u85AFBYEfh37PRAcwT3RCfZ06ApB3i7KDWjCWJtA2SP1N6QVsthL78uhhTKLu1T7ApIG(hXu)oRgDmtYaGLEBU4gWgo0rNWr7WCszoUsWlqFKx0KyYMnNEJbxWUcEMn(7Q8YVln9EX(1lp8OTn6Mg4U4wUMQNLbnRQSHSvBlQV8O0p1jEB0L8QM(d7tN4lFJb0KrDVBhQnsU0g4UiZyqC2yIjQpjk548vaXwdyxeeSvfVfmoELpKDcjxVh9AImiUQNC26F7YGOjf4yWz91izQnXox(piI9ntYKcBs)BBcTHlFDtc5Wc7x2mqx3YiwYXRFsdtImiwO2kEQO1a1Bh4BWuK8(b)8p]] )

spec:RegisterPack( "Fury", 20261026, [[Hekili:TR1xVnoUr8plbhGH9TzvSCQ3E7Iy)W2T9UUpSf40b03KeTeterKLuPOIBkc0N9oKuKIsIu2z3RB7dfytSJ08NFKCMFZOrBOF4VfgKIy4WVSz9M35d)egWEUchguHsEe9a8Lc0r43)Lg6Z8l(CEjkLRvDzdnbUrgJvv)HBU5bclR5Gxs5XB(f8JKCYnzYpcdo0qYz)1IWdt9vDfoj8l(WnW1jsV0g)3rukPK2gxX)GWGlDp)p)t5O6AssB8FMIaSqlVNKdi4h(H24rkU0u02yFp)TRA)mxWabSR)WqRPvnGCe0(NBE(aTPo7NjSB6VXQ24u89OMCw91cfsOO7zTX)g6jmTOn(M24tLNyhs8E4bdZlH2dneyj6jbXVcBSGXAowXTuqtrkMcF5t4JLuuo5FrkadeKv2WGR(R4Iu4JFbDSMrf35eg9K4lOI02ywgyR)gaHQYtyyTNIksGRGOWVskly0Y8CmihPOtw9UunMXa7Wrv7NrjmszrTxffdNHhqS3S7MdyAnM(iMgvZ4w9AY97o0C)9EY)0lT8uHdnrmwooQwSguAzErpk(iIuuF3TRn8oOzckpps(Nr5KA2184VDKccZuQQMJhX5MxH2umvn9cOhdJwsEnvN3kcCpzzCX6drn4IAYt9MqFf7wX(EG0VMNv8Dfq8Nquc6aGqHy4)joPHHJQYq14RFcL3G3Xq0hWmVmmkNL5vLWUBZ6ZyMeur0)Ob3OmXvQB7nWbVOdIuxwOep8CE7ZdMFehvcbUrDQ25Pjw8alcvTF9cyVI5bBcaZuKiyFVdzpNRHaW80OAzE3iNMI5NqD3mcxWvlDr3giJCehXkJsj49lxU9TsH96egrH8xEUrYJR(rFVTREZT8tlEg)hvHDqET4e)dDjJfL0JOCflbTewIaW96xb6awyzqkyyG9QsKs1bjixQgOw(j7A8kYdDyG8YYukWxDDtnCAb7mpKKUZNBl(v5rYKecB)UnRxW3D2V2HD05DcJjWFoUG5roce5pHtJgkHNANFOx8N3lzyAjjjsgBnfXCvGCoCb(ibxVZxA8KgkfqIrWuwTadrSmkg2LYtxOd(1Pf2bqsoWnFwpV3PNL6)169umILfDIuNzeGygZUz9l2tJTBpGq)XCCDDb8d3IoOaM6O78FNDlY3yim8XA732mrAGdhKYUyPZ8U72(IT7PdYxz3VkciWL98CwyOSR9Pmcn)ebktp9KEZmPvmqVA2fythCVlwMucHhqrypd7PwSqk5ldJY2UD(L)8uiYoaMezRdDlvTGej6azH4uO)Iumk9zOo3Gi)72jnRmGNIzaWHCE9YsRU(eCT32fZUQ9nfqVlAEBx5o9nF1ZxoUSaxkXn1vg6c3MQ(5ywZun0nWp6RgX7Yd7KHsl2iQIV59MU6vYEn6lwvwbr0uE7Q6wnVURb0C8t4Cr)OhWqF6ylv7GEQfs1gF76vMf3eUHZBMX5qMVSMs2jDLojMuwIyXvocbTzZVQ6KAT)wksQmY)DQDPpa((x4s5A9bKL79DTGGYPtPdhCqpH2wDx4bGfUijhvzRuGIRWuons2yXG25KwEwsPxg75vVsAkfaOyzbiTh5xqt9n0l3DRYjCHepBOT2MFVTq))tqfQOY(K6zTmyZaqbSvq4b0fEjqJXFQ5JIhkV75X6bP(r1SW84qkZcMTFomaIVRbPmN7XjeTGJ(WGWa(t4vZhPIur4BFrmxMUT5WpggiDtyGKMe(KcnrbzcHbJOldzGxgPSHWW5qB8(241TXlAJVc2dSZq27XXl5WadkcoqbhERd0AYFAcdNKRTX3bvi4M8p4CnysOcRLDTXBKRM(fNbcueZ2G9wN(yyGDBm4eFHpmdbLo3nVRqHPeG9GBaHVna(UlgG7VaaALH(SGuQLn09hDCQRJM4c9toeYKm2CHzNFxGYL8XV5GLxe4STn(LxSl0G4R24vCO9EhqRJ9NlI)Axr291beY5kF1KP)mNFBelYzQqia)gH7gNHRC3u2DtNU0iyWvLd5wOD4TYeHUlK0Ne77IyGxGWezwlVi82yKip)6HHUuJKcys5gb2FVamJPu0PHQ6hwr0OIqNljZvXOqECsq34JNLHF0O)KLhIKdHNpnlBm8kLLtf1gL8yY3Ptb140z4mmhGaTIZtsBDoPxOhKfbNLF21muVmpOv0gh7fDoOXiJ)Ai6M69CNQtRIoAXymq95oG)kROUwc1(dVzGQEgJVYUm(gH48bT)(v03flWWPpoCTFjZPSNyyam9NaZ)FJhxgiF9nE0p9tlHUJRjWJF4L6SpzT5ADXCOOwBDz4GvfEXgiGOE)3nxJi6zLoBRi)pqNuoB)r1kLbSUYyl3YawNT9g9eRoxRuZ28X4E3CXiy1Bx5kIrTXo3836yUKBUtty2UvTFoMGy8(jxg35OUMiRaIUgj20C472PEA4HtNviQ7j0kImw7TDOy23n4Vz(rcozQKkXMwHX5ZJ67MHyU(JVGMJFL9)6Ic57slN)UFaOAHTR5Pxt7oxq)ckbzDT5AX8LvIDPEDvPIIV11B2qE8aXB3vxfO)fGlFAQ12q2f5gJkwDUygQbE(UZ3tUToFUiiyJ(ubghVx8(z)m5DPpkQAGE2AC6YGOzTNPGZ67AFUNKBP4Fqe7BNTeg8KQ)yxOn813ithfHwOgwgVoP8)BsVftrIRh(V)]] )

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
