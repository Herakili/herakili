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

spec:RegisterSetting( "tank_hs_rage", 45, {
    type = "range",
    name = "Tank: Heroic Strike Rage Threshold",
    desc = "While tanking, Heroic Strike is queued (single target) at or above this much rage.  Dual-wield tanks queue it often, " ..
        "which also removes the off-hand dual-wield miss penalty.",
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


spec:RegisterPack( "Arms", 20261026.2252, [[Hekili:TV1)VTnUv8)wYvad72ufB35UR9InW1DB3UcC9kMlW(nlrlrhrezjFuuXldb6V99iPifLePSCs619dhqBSTeFFHp((YNhP0MzB(YM1rigEZNMpD(BNb)3B(8fZ3SMD)b8M1hqH3IUb(skAp83FKUpNFX7tYqrCsZZkOHWnIzSd5V)QRUHWIl26fMT)Q)j(wsc5Qy5hBwVTGKW(L0nBDiW8d4WnFAgCxCEOuuLb)BeLsYOLbh4Fqy3xgSJ)Z)wckpNewg83PiqHOz7ijGA8Ixug0IWXMdTmyM3Sftk)iFGRf6E(7BYnnPRj7bQ)5I73slYJ)zc7Q6BmPmicVdvKWYVuqqifTJvg8f0DyAQbd)PpVUm4OsxUPGeH9Ks)diglbdAbdLgcFsaLMfdFjoBp838Qlp(xZOmucFCuYTyqA)giIdzhXu47Rtq75FCeJpqsVrnQ8j)aWqqp(aMMJP3IP1YHldHcuBrrrrClwmHMCKKgbxG)N)fo82eCEEk8)QlfIaEgj5ZwWZOAXqRrWuR8JOqgjln37afdUbBrSxT8QTIjRVCsDjz3YTf725j)Pxu2X0(jloRGPPY8IEu8Eejn)63m1q0aLHOKeF5p9ti5Sl5(VljPeM5OouSFpoX8k0I0UKbQ5TCXZ)0xB2ofvs9SJAlNZfhon9Q1UAwOUYzWfWnfNMtURwr0xXoxSB5KAV5Yl3wcd)oeLG2cZtXWW)hCybd7FigLJV8ousb36rVbZ8IXOewS3Hq21ZNEc2a(z()EbUqXIlu32RHaEihZyGBFU(YcI4bc9Z)CruIFg436xrALK6WXTmF0Hvthb2kMhyeaVEFHV(khJ9uIgCBtI8ZlsJGv2wcncZxHQUPpoLtw0OkdiJSh7ZY8Ji4vJhV41Yb7vnyeDFgLhrfE7KxoZBXKx9gzy(VDaNkI)fJdsOujTYGVJFliUhszxF7FKZNVBcKuChHMdP0KZ5YGSDv5N2rUjMbjDkszeiVeQMwynbYlG5mneLZ8oHPitOznnfnUM)rukJBaGz(1ZMosYTMZyHvjNa(XR4FD0fq(J78VjmYBwJbEo6IFA2Xk9r741yaJOqnrVWckfNYwT0MEfMLZoLRaK82NxvmshPKa8ZJShQNDhgCsGb4rHKoRwUGh61TSHHjwgHYdGJ5(lY8vchhipzou357TmwtvMtH9PRfcpJmZ2OojllIBdVSihcdbxEybB5moJewwiffjKaw25tfl(RMAHjXyAgj0xgl3Lr8Xd54GPXEcoF5SwRz6yU4CF(D8zXumO5jrJ0gbDAiBw5emuR)uIDLtXkP)rj68QQ9vt9CBI1czryel2)ijp2W3WmPY8PpyppRRvq)Df07DWSzlodMjRRbtjxm7m0m(kcHHbmGNH7EJSYJg7m161lEW290(6tSiuvbgqE11XSubYcP7fy)QwNTC)mfWl3I1YDae6cDpmbDWIVZ8rvtrZXPNIZT6zbkkkH8FfoLQucJBxwJpmXDvv2EOTKNOeDxo2B(ei2kIlsTe5xqx)SPuU(nkHWhKa8PTkSVZM7dhTDd3gDg8rxSp7oq0JcZG4yGNEnw7uAV1aZy0E(OKE)15Lux1)iptHZ0x6H1mvIUEr7oamlzOUhOeeOsl0n0bw)fomO4SRDyq7JR8HjdEkvqm5JgsTGzI5EZIWnhHNYPQPuM1Vu(2uQYqb(guTYq6plvEAV4)ul(01j4Pv)XGFuJoNBez0S7LUc66zV1ohTvuBiHIFnQRzi3hrPndQpQ2WbBfHStIRcIU4QJghhn(ePPxo)HMrclw0VjO)0CYT9Ot0NWGRRH7tXOO7HUXBeeE9sj1YypkMb6hK(rR)AY1lwt9wCYQqMdrBWmVTd)SNHcG9kyx5pSHV4KWlotWeM5R)Aur(KwMbSOiRP)tQDWrvth6whYKO2towMOR8i0Eq(QDs0OSVEdGA7H6yiT21jLw8fOXuX(imM)TYGFnlIlnPz4YYa(odk2WGptZyybJR30XjELbvB3kFx14BWifgkScYsUh09cuYRpsWaoMG)bKN)ktEqsDyg(bq8XsIqBjjegKjPIXzPC2k2AX9aSpmmKJI99avtd(3lihoGJmmvCDJ73lgH)wuECN71t72CL8ZfjjcR0oA2Ev77x1bv27R3fLQ9DHO2VL8JOdG2YtKdZd4suOsQyJCPzhH5KyrgDeD)LccsTyySmJAvX4cxBn4a3QJMdZwkRoQqBH1m)yNHZqfPnJ7fBhR4YvGVgDb6MBOzDinbLZecjQl913Z)qid4HX(u23iD5JCeLK88jLxo1mvCLKEkyFB5qNKfEBxU0uJmh7iHbULpX8fJKUpMJ0CxLvs9zcgSqRQWc3nC8jI0vWCd4UDT(pMwxQOLIVdNAHNvgoE1u7R2SyrsH23ZbCihX4pw0FD9aprbzHnuxo(8kdRwgZsdlYZHlXDNo27CR8JBwdOG4dUZHkEert560M1BwZpnJC(HwkxTGV9jXXFwbxyZh2SwkLnRLj1HpHAvyaRZM1TsUVHbIYbXM6MjlS3GmNtVXbNmDRm5KtFUYGRldEdNL)LwSSMyZCeLbRwwgmFAzWiO4bHFWJRkdMAObQCnBwBesXnCGmw4ugnJ2kdaHmtidZOoPWD3DRGGU9ywRCnYNytbF7GvWvdqbT2e8jvsjv20U)Ql)Nw7V7P0BoV(Eh8QU1BloZgDEk4e3p4HhmMonAAIlM35Yrv3r(aeZSfNsmZM6so6o1hICo50zMR4FD)2Ir9Od0B0(TWtzm)bhWrAyrWBLTPN8XYy8YGjcDZvQJQ5QPADHHPWst6c21oTHIDnQ0igz7GF1i1nKkgv7iW2QhFmUIdm3)5tedmxyC7zFRfgT5cX5ouPD9jtHo2irGRgoLlD2vVjMAO7sH1jWN5kwJVT1MAM1n9wiT2AI0VPwn0BaUm9V9OO3jk15kGKdzXURVENbem)cEVD3jAec(v)DcxNvBUR4tDp2wneTAu)u51D1WoObmUBH458Px0cTEKjKqn8LpYu8J(Tp0cYNbfBOamtWz8GNy4j08b(OHy5K0poaRpvkdJ5vaO6fcGRNyLbkbfH9xg3vxRdtiAc7RACVlUAdbJ)qOv9Gl1NRsd7DNzIXdevFUmpsyHtL6zTPTh9uFCq)jg4ZddSMOghButR4qoGP6KwnuZzDuZZcM73iC4TJT()lC4)j25NvSZMN(L1q)MNGMqm20cikgGp2h(7MO0DLa5KPI(daLUly1psu6Us6Op1GtbxEtFyZ7I13vTrRY7cxEnkt7jr)TuGyMBG7MfyXcLn1vyRPHQDmxRYhDp7nl5EUEP6muATH2nqY25C4eoa8TVDOaEBp0ohbKAyort0n123aC7dAsSPpW993i2a6c78A0AUR0l)H0KXGTRd39qGYtG)VhaEghPvF44g0gHEUzEbNkxa3DygLC0YtyRLHBpA1gEWAhUM6X5GZtC(twDqy6JNQfKnvGL4SuSHFtX76ZcYTaADQu1cO(eMeU69rLniAT8t4hR1xxLOm4LI8L2qK91a4U7sdUp(lHKKNXOD)05lulU2oqSUrF8Byt56aI7PbPNzCIzNbS9oq8EA42zToATHGn3j2VNqBHorkwD8C9IyZ4O66fkMXX29mb2Yv20NfKQl6fs1aRi38C)o36Wo3WZwNfy)4AmnsQ9VRAtEg82Y0t9W2BOLugI94Zc7ZoiSo1KRGzj(w1Ei1SZQ1IxfeDz2wjqNp1MYniXy0sCLi6bOo3LrVSQUN6LRYwj)bPc2ANrPmDKM8LPQUusE7xaRwzxAqNTQ9dtfn7fSRYz9f0sw)XEF0Jf)dccFDVTuoru9tGXd(6RQIiANBzqZGMBSMAgy79QYOU516DwYgsR63XkXCssISmNJ32kBOAoFTN)EyPNb235WZeVOnKodsVQBlYic1XBRvvJQIudC2wWI5zSLVi0VgtrIRV5)9]] )

spec:RegisterPack( "Fury", 20261026.2252, [[Hekili:TV1EVTnos8plzxaJ42ufBNZ922lja7J729kW1DX6cC)NLOLOJiISKxjQ4nhc0N9B4qrkkjsz5K2E)ZH(ioICEWHZJFdP865R)06vreoD9hxmBXBNd)ZBXILlwVI)4E66v7jH3tUd(qkzh8))JY8hfp8XKmsKG0ISY8qyGyoFFX7V8Y7y84YnEHz7U8xO3Zsyxgl)X6vBkzj8)z66noeyXEA46pohgLwekfvvW)MKNZYYRc2l(bJdpAR4x)XesrblSk4VNtafkpBllbuJV9BRc6q45MtTkyU38LtR(GyIRqDV49T5MM0vSDa1)C5JBYllI)zg)YMbMwfer3skt4fxGeeMt2YRc(e5bAEAvWLvbhYoW3e6D3DgSxQA3vYGLONuj(DW6cmRC3EbNwvMgrZHp8t0Dz5Ke2)HLcmyvCwjhE6VttJGF8lKDf8CCKduYd4hiPrvb8yGx)kOc7ZoqH1EejneEcjh(VWSuEEwscfMhlTEUARubLZb(i0QQpqc5SS0cV95uyJCdH)6BUCdnVGMFpn3VGl46fST3SPC7wp5V6fLDi1bLeopH6xGRbfvMp0lNUJWslU(QzgshOmKKK4l)v)ewb)cHt4nSug3Cw7l3TJMy(K8Y0(KbQ59cXl(PV2B6yuPx2nAEhdHx5(JZfC12BXpA6bFnAAb7HgwOFIDUy3YjLR5oSWwct)bsoJSb0qCA0)KgwYP(7Jjf0lEGKukSE53r5EXuscp2BFi)6fZocBcjP()rjTuXIZud71sapPD9upgjs4upm)fHa3t9Za3D)AsRLupoUH7t2F7SjGTI7bgbiPMpgICRJ5EmrdUTjr(fYO1ocnIk2HQh0NMkilAsTbKZ2r95z(rm6TNF(Y3iNSx9Kj5quViIk8(PVAU3YPV(kzwIFDpnveqlZpaPLQLwvW3igccKH8Und)9c(8ntHmBBz5fqEj5AUkiBBDG)w2DXImkLPCwcmEdTWEsvWgQGPHKcU3rmfzOM12u06z(hiPCHbaw5xpF2ej3AVIrRsbd8JVv8XjNb5pEW)UWiV5TM4POl(PzhQ1hTJxRjmjhs96fwMNtt53EJn9kmdmEFqUf8dQ4EWuHHCVV2uMMLVJKOsUNNb(ycg1OR6mgGcZaBbu0zpxMkc9jGuGfqfHVZofMkKGi7lg70EcPEDWGKSSiHD6IYciudCRHnLBMl4fA9G0qSqgy9wmd3GVDMd(OtAImdx7jGz3JTdQD)anYV9m8uHnTLY8HLsmnpJf6ltm0xJfKajmbR2ogT4M5DCa0bWXfOo4ZJZPGvkjAI2MRZPzxbctGYXhvY36uYs6FUspIs4X(hyfXgoxMjCwm7j75GhyZ3Fl4w7GFZxEA8t(zyL6IFNM(bymUpHwuKc)RvKr76l9f01ZFRDok24yC6UItmuSv9GjN7mP(1lFY2y6GWP2LRQ6giYMIOwk)zN6dXS8Kdma5yFpXfdSZZJXAhhNNokSp58WmW9fWf6zWp1Ifsz8u7OGLlhE5pCkojO0ErE6qRmfQyFeu8eCxO5H5us0JaiQwrMxFJKTYaYCkhuCiNKEzPjxVdoZB5Kbx1ZnNG2kAoSRy7M(bAYN3fZHyw4GAyh1UB9j)yz(Jv9y0so6N6lA8G6mdQEADsL9ITn11ILazBkelRfk6Gs39Zf19eLqFGMGqL2qHwhPwQKd4PWzvfC1SPMfUrXiYRhlYHyTKTqD((TCbZ(rCwV3akfvioMeZf(raAvo2Wh2el0hdGKdu9i9ZreffhaeOqdKqofq)ZkOtHftMGhqYD94i0oBA74qmiWhv3hSuCXciFPzknzd9XmH97tc(hka48Va4GubgNAnBdf1ojmsrIyW0AK4aGpcmexEYLQ0g4uT71HzVGzzT)jN5k29m3R0jNF8a7NoRguIPZzDG0td65kqQUJ8NTsODDnGsZ5lWto12s)zHttt9lbKMIj)Vb7Koa7RpWjLO1(rNsK0xIc(kH2VCxRn6ELLvJYJLIimHS3wPEvTaZ5P1KfwyO9AoNF0Iop1vYtpXYqkfiNkbyOLO4b6sBTLY1xPeIys4XrzRN73zZ1)lrPovPQFsDqngvRaLcYEInKZZWMVJi7WKU1hMtJsQpNhljiDmltarkT4tK07XAGNl(eKkplIQp0prXL86sp)g0)kf5AZrUcLedQpAuXHNvuFGIWUop5rXzxssEZbgvusq0d8LM8GL6Wm83aXhljISHLW4WEynJZsfSfpbXDWEP4alpGhVbPHg6FuY2VNgzyQe6MiMfNH)gsrCVXosD8FRmrIuyBE2ofkJlT14VQcF9XRW2ARYTrfBWTaQ2wxzLCG84fibPwmmwwrDYcDMRtaCKNOr7PzRsypvORWANPU305KY02auXtDfF8evvCYD3LN1J0eaKbkKO(03mM)(qoWdJJJCOz6Yh5ajj5ZNuE1mtW71s6LuBUJdDsw49d0GdQrMZDcAG74tSyzn8jZzAE4XkP(zcpaQv1Gc6ho(cR6Jm3O0FFR)ZbxvnT5qhbPw4zTHRiHSZ(UD3c01JbrFa8YAd6rJXFUik67bEKohrBOUe(PvOwTnMLgwwuaps4oDyW1w1hwVcaCjMCVla8ajpvOtRxTEL4slkexWOC3c(0hXRQSU4)6Fy9kPuwVsMuh(juRIc4ZwVQtY91Cquoi2u3mzH7ojeC7QoCZq0qmCvWTvbZQcMufCguN3EZkQHhO5mXmoxw0q58xfC9nkucDszh80tidD3dJCkd1idQ51nZiNDhHdfVKfv62vtvW0gJAxGkRxzeIl2ibt4FXXgIz0PPH1zOlQvxjy5sN7kMPAH1iycxi3FA2Um0avkBBQ9BDkJ2jTQcaHmhLrBtOq4U7wcjOFBlnkxR0Y2uW)6OvWBhHcATVQJQKsQSPDFNJDDD8HysV75gR2QRmv4JZmPOJZsPB(aPuL(xc)Bq1MpZHUv30gohxjQmIzW55kNKzdAhzdCbUkhOXou7xGIRBslL46NR3uONB4n4QHpPn0U6n1udDxwPjkEURmdI(6m1mRDfIsRRMi3aBudDhIYCa96se193Hkt3Ck64qvBFw1Oo9oESOmx9qUw4NSQ(fnzWsGDUUFz9tF57SJ4QshQeO89N4iL1igV0egBjTFzfAjwbj2s03nLoT3RtX44VMWHt93QUXjkbj0JbZ67QvSXjbnH2YCpQnxToYfVfu1V0nd5Q0V2CNfJX7ZZqEnpZ60ZKQAZM3aQQ(UY)QGTZwaWlCXoS7)NpqjUss1(o1BBfhZTV3K3QLAoVNA()bgnoL80bg1CN(wcc6wYs4)iQeB)(yhcAvZv9pcXmF5XeJtysnVcaJrohD54eQL5RgG1q)2VEbOySPfqu883oiyn9RmWGySoAQOVcqxDHRsbD1qTm7l1Y7zWGiJ0xC7XGUICPBAJwoKgyLDvC0Q0oZLpJYWEKEGVbrU2V9xXalxQSNUcznnsDJ3SGvSZlMaQIdDMbJ94aMySm79IkGEgIZRS10CDIaZ7oXExoVAA9lz68aaw4khXW9JmIMroT(nw4khYxfi(F23aq4vi27bqwzChjdbGAuNS2PMYtDKy2EdMTBeLC0YBMPLPBpAWgqSg3T26XPaWcVqdRUhC99D0bRe(RGnapCEBaNu8U5YfClGoxZrJaAUYc0rFiQSHnQJFI4Es(YQevbVcZhzdk0xceZJiVmV79PipAb8sRS7NUyPAZ12nS0p6tmGnLRh6PxgwAUXvWCc4L7HT6LbyM35UAgdOyNGUEb9J5eIw999miujJ7(zqmqDrV4kgV1Dcniohxzt)SarC5G4zgz942xK0PwfUhsjT3r7lxAqKdTmsQZoR(awoLJezGsITH1GYapFnlSpBpADAOvHjf)u9530ULMv43xbDz2ojqxmZMMnkXy0lATigaJSWLrVT29lLJTs(JsfS1hHsz6jn5xcNMsjfD)I70j7sl6SvTFCQOzty9voRFXEK1FS3a754FHGW3myVCtXQFigp4JV2XTznQvq7t0sTcS99XXOU516J0XgsRMVBo4AssISmNJVLo2q1C6ApExRQvG9JS7eXlUw(NvKsESilQ8BM6BO5e85R)V)]] )

spec:RegisterPack( "Protection", 20261026.2252, [[Hekili:1IvyVTTnq0FlPfWiPnvX2zURRlXaTBRylaRRaUa7BsIwI2IiYsQKuXldb63(U7OKmLeLtB2gAtKd5D8E84Dp(K9N5)z)vXmn3)JZNo)1ZGF8MpFXC)v67l4(Rkyr3Y2cFiJTd(9NK5AEKwKNHtDFAolgxavEPmcMorRluV9Il2k0jLR9IY3DXVYVvKkUiX8WF16srQ(3Y8xpsyvf8i)podMLRISdyv4FYKsrUSkSaFi03xfUb)ZFkLPuIOQWFrYayjZ3isbW88Nxf609tTDOkCM3SfNvDdA(hWPJsyswKMlvvH7Hnsv4UCLgIAUitdJjYSxxVQWQW3LUNDpmLMLDR6hHNj8QqfKXmdvfMkWvqaMuQ4XvHRVV2OpukHpYYGXENCNYaJ69NGxhTFMVHNPe3b2VcwVi45PFMw3FppMF25aoterjMaKKVVbX02JWe4qCjl9v7f80ytuV4WE4miKPS79QUP6ggnIYRqYHJV1m9lV(c436uEGkjVuFUyZ1Rl3SXZEqpjFhtKPU6YPwRb4zelnnW8Nbyo4CSm6ArMqBBLSmBOruIZcqOtGT3XKc26uUXi(FXJk18GIeMIF(DS0s0r5wU2lHZs1jEfr6RMp9rwMiwwWxk5LnlXjnt71japO4ATiBRQDyYjyKhz9vAP4wEq(DCzqTR1rAWkUwhWkwoDIsZ0Eqkg6)ckY3ZLlhX2hl0W5tACGQmlMl7h0yoEuwpzapdDlEsDcul2Xd05bXc(YtpDXRmg7vBmtUlx6Pq8D2lM5T4SxEPP49pk4zCOnAfzhu4vhTQWNHtb9HupvZ0VdxNND2BHEzHelAn75QW8n1TiBeBt0qnEzMwKcZFWx4mbAL44IgXuAVhjvKtiRBQOZyb7zzAmba78RMnDIz16UJPSIsanHlXpo5eOr5UGTrXEZ6y43cwcYY3xJN2cVogmrcCWErLsjptV8Ax4kc74VXCeGCdug3ILa4JmNdqMez5OuRn9ydP6zeJMn1btYnmkPav1rOriYkcadiSaorvIXj2A4Iad3gTW5z4YsSn74WgkUH1LDWh(xkfff8yRtyeBqw1yrWAMkzWCir(wosyvxrdmvkrm)ngq(PY0uklTrMVRk89eF2fVh495YBPkyc6V9q9wDfQOPYuThA)c3JnyW(agsUxOqo)ejscJhAW2aUA4CYbxm5o2rwNQi2pH66IBCmqz8RS4RSOORzgVdWXcKCnqAdj8(qOFWohU0kihikGY8RNnWCndAnrO2YRGteqdt9saD2jSTBL5dCfUiwtbjEO)hMlaiXH1WIr)ywownYE4UO)7IYlM6TyqKwNMNhJ52UzmmQ0PaKyfrc4WA(06eZOf0P5r3oCv6IiBBNqj4E1eZxmXu(yBju6miQqPBUikWCp1WWIwdvdaJ0oOX96z9ctxuLOOYRHTJPC2Dp6IV84lUzrChGVbzkd8fiX5zowZ6eNkLTZ9PToHif6ph09PzP1j0hThF0RwVAXdUMRzFmScmMdZZsf)nKYoKj6MdrBOPMuV2dD6izQO8SOsq(miwdsa7p6ER6g)vGMh04bc93ZKziM8x5Vcv9PWxKaVReE(r61sQ1J4)E)v5fWBgW1(Rmbdw167jPpfyE5KoA1WjGluH3JPVCWQWRQcNp1xdq6PeMwXITH4KQq3cgRcF4H2lEhQAeHWLpfi4qpzlygrLy4YQWPvHta40xzjm31oqj5hcXV7jbrBDNdbNtLNe8gQ(KW(P0)xuf(kqdYyTlvHWRY8c8v6wqF8LvHxI7GfpLDqhfyT7axcgn4wGVUhuAnZKMpU4rApzCbS9eu(LtzKi6F9)A0JcmB3bULys4WM51uvmMQcF8FOeMBD1U2aml1zUA3AmZiudEc6p5a4ABABeS5QrPng2zlRLaYPJPC6BCV6YCQnAGskxDln4Spo8xzDtiMcDuN24ljLYEZ5qPLvryBRoKdizbUQIAw7dYAgpa9eyDia9yvpMxig((JxNGk0()fee7aOCdbZB6bMdX1wRMP0y(0EP3dyVvZNRd0Fy0ymUsod7bjx2DD68fnhUU02nS7dNWf4MnDu01vtwvie1zJGgNI)oaIoklDII(KhJJILFTOWsLOfldnOtimgXKT4rBGnQYsQaKUYz2y8v1knjBgJRWs1jz3y8cwkqj7gRhVJAuYYr7ehHn9ix5EfDTmk05isvnMrHUFF3bcY(QqhVFPvclvo8OYyTow63r2wD0vwlDDv)(dNjj6IqGSGvM6u6ABa69vHAu9wFBnP79i3q27BiTJV0LWekA)oBpgoEI10t9RVZNvQtWAdZ3O)R4sgnU))m]] )

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
