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


spec:RegisterPack( "Arms", 20261027.1113, [[Hekili:TZvBZTTns4FlUDgDsjoYsYNsBsT8mjx71EzMMM5uM5(MiHiHmXykswsqR6B8WF73UaeKGKauu2on3h6mT2Yea7UyX(Yd2LkBMV5ZBw7t40nFCXSfVE(SfF305ZNF5M187tOBwNq8ULCd8HiYE4NVlDFg(W7dJj(4sZIZt9Gbc48KS3EXf3W4b5BN6fV)IaAk5wwiR6dBwVnNfY)xrB2AHNzjuVnFComknZtYTc3)djnLfNw4MG)IXVVWDh(N)JqswgZRW9NsjGmLgVJfcsY3(TfUTw4y9Pw4oF68Ltk(aoX1cXp7TnPw1sxZ2dR(NZVFBAEwWpZ4xupWKcxF6osEip7CXc8sj74fUFMChnnsJG)4Nwx4Eqjl3KZ8PtLC)9eopKcsbNe5b)Mbcnpa(qq8E4NzLpE8VgNYjH48sz3sbU9BalsIpqtHpVoKSh)1bknHfDJAwzt(bGGGC8EAAgn9wAAnFqEieGAnkX3h1ybS0WdSiF4b4p(3uVBdPzzrW)x(ipcqtFjD2cghLhgvseS1k(aXJZIJYMMKsblHTe(lxDXwXM1rUPoNTB128D7Mk)ZP(XhI6FzbX58QvP)WPP09ewu2vxotJ1Wk9iHHoY)0jKLXphnHxXIyC9zLKVFpnu)jP5rDxgiM3ISh)TtLA7yRskNDeB5Eop54RxD2vtc1tobQaMP0Om2D1cs1tmtfZAoP0RF8I6sy63rszKTW(umn6Fq9Y5uNKasg987iH5O2l9gkFAaLeYdMM4XVAXSJqgWoZ53ZP5ksCMA4PnyWdzuohm7ZQESyrOJq)0pt4L4ed2ToLlTKtDO4wUdj56zJaDfFkOeaREhHT(1wM7Xyny2g67KLh5dNSTyQpfpHkh0HgHlZFuPcKZ2tD4Xo(m61JhV8vYjpTCYK09XPOhL3TtEX8PlN8YlLU5)wcns4)lMheqPKBfUFdoe43drTRh(DiD(MjqqXDS0miKMCpx4gVRm(0o2nbCiOtEeNbXLi1RfotG4cuKOEKm(0JOkIfswtvrJN5CGeXrfaSZVA(SrsQ1Chl0kzmWo(A8JJodIFCNZnE(tN3yINIS4efFOuEQm8AmHrPqAXPE5PP0i(1RmjxEXz8JzkabVDWSI(vEkHa9MY2d5ZUJcgjWeMMcbDUE1s01RBAdnvS0dfDGdq7fz8kHHdeNmdY789gMRUiJRW821WcpHiZMwDyCSpQdpppdCdbtE4aB1CKqcnleII5Xan7IzId)RNzGiaYIyMNJ0xUlHW5dX4GTXEgnB18wNzv(Cbzo4io8Guki5H(JQucvHHmPLdPqU(JX2RTYw56FuSoRmBF5wpZeBnSmFkHh4CGLfOzBOhuzXShmhN12jOZU807TqS5lpbIjZRbBjBe7eKm8eHXPagWtWCVru5rJTgA9QLpyASkB9jgyQkbdWV68ygYazyP7fy)kpNnmESc4LD2AyeaKUq29cjjgSDwmQClQpVQT4cJwwGGscz)xHrPkKW42P1WPjgvLz7H2CEII1DPyVXtaFlFKLvCeFqv(ZMC5QlvmbNKa8PPmSVXK5dI2UHztve8rNTp(oG1J8Ib)yGMtBC2PKEJoMbK94SKw)1XLup15agPWA4RQP1musv(I23aqpLHAmqiyqMw42qj8(tCOTIto3H2AFCPp0jWtjdIoDQGuliMyV3mjCZzmvzu1KlZ7NlFDsvPjaFfYwPX9NLmpTp8FQjF6Ae80Y)OrVuTBo3WZO5Tx6YORM)AZu0usTH4k(LiVMgFFeP20w9bvbhmLeY8sSLq0gvTCXXrJpsy6vlEOPNWYL9Rc6pmNSShD8(ek8QC4oPuI)9WTXB4eE1k5QL(EPuoiFq4Nk5VA5vhwZMU8OzH0NsLctFyl2zpdja7LX2IFycFXrHxCIGj0Jx)LiJ8r1md4qrMt)hvvWrLthUToejrvtoES4w5(K9a)vvsulTFvbGABHAzkTQ6Ksk(mCXurDegJFQW9xJ9rUjvdNx4IvguuWGpLgZPccxx0XjtlCll3kwvnSaJPWuHtqE49GSNtcF1bgfWX4(pH48xOtdwKf1WpaSpqUiYwwiJdrskjCCeswrPf3dW(OWuoiQ7bPEn0FpNLKq91uvOSH29Iz4SLKf0zSEUUnkKFkpmuOL2LgVxD99l6Gk7T1vrPSUlmv9wYoqsaPfdKd7d4rPqMurHCtJpa7jXHm5a5(ZfliYGIXWoQvgJZSvAWbwQJMtZuiRoIqBM1m(yNPZj5rn97fLJv84sWxJoJCZnPXDwAijJlyIF31xpMtIhhOHwDk7BM2SroqcdF(4YlMPhkUKtNa2xRwYHXE32D5nff95osOzBzmSy5iPDJ(mfLtgT8)fbOxvlj0AWrgWIq6RKUlkdy)89jVf9BJVRSjfU13LXD8TQgCqJIZVjOSXde0LgsAc(vOoHhGUotkJ9Ca8fO3H3arCpO6jiffmsIkCBz7niTkdQCIzCwiwNZDal9Xel4NHllDGKITnzmiY5yDsHpVp3lqk3e4jjiHkDpZ6ifNxY0iiA9nHXBXE8OKNjDDyp1Rqm2s2jXjB5fjgn(SYB7STwUu3W5HQCr6dQYgHfyDp5pEWy0HgYQi8WllhrNu4ZN8GDby0qeaZHNSlaDcCnPBa9N4DLeAyTlm11)9XC53Y1Mcw0rgOzPhiIhZC8Ist)2J1cqTiVoy(sLUqWOu0LtSJFRwXNrP8VLvBQl8tsGmUGrTxAm2Wq017E5IVx2mszB9a7(mWKNvUEGAVl(N0Jc012VTcR1jXQlF0hfTtd(yVGu3G0hbZQqYQqSEAivni7fFyZAqFNbJ3PV6qCQiKNBwVzn2qVmS19svk8PpkEjakD528(nRLCzZAjUg43aCnka3FZ6w4B2WbwzzX6YMojmxJiKsxAHs6N96uYQttH7vfUxIK8V3IK1lwpnzH71RkCHuLUJa7rg279RlCNPjbQ0TBwRftavCapwALhnnslCbMmxWdDBvjZTxGhXc6wMLAHRrKotc4RhSaE9aeqJ1b6OcPCvMKUVZM9tRwCCm5gP13BHw1vFYGXSwXxeucTdE4bTTtJ6gGS5n2muRkk1ayZ8LhJnZNzJpvfRAi85OBN528)Rk5KywpAh9gvGsyPmgF3zSeMv48wQB6jER0hVWDIq2Sf6OCVQlwNPPkmuNkb5Ah2qrUgPkfZSTZVAMv1KrmR2EGTfpCo28d0BbZr8bwiuU906gHsBHGD2DvAN)rNPJ1ceyRMlYJoZI3eDj0EQU6a4ZT5RHDUrxYm23hb3Aljs7MAXOQhqYW)M9IEJivNnhseZLzt)QIJji(ziEQ7exIzunuFZfdQoQ2cB(NvLzYOIOvTQowCDB1ScKaoAwiEv36fTqR3Aijudh5loi(2p0hAb5RHLjua6b40E3R0SeA(op1GT4s6hhGXxmRHr8sau9cbW2lT1a5GAH9Ng3wHBggtQwyFzJ79WTsrWX3dZY3DV(mvAOV7St0ENa7ZK5rclCMuoRvT9iNvDe9VWaFAyGRwuJoN2uloKESwh0QHyoVJyEsWC)kHdVTV1)FHd)VWo)SIDwVbWgD9B2ezbBmjfGxmaFSp83nrPBlaYrdf9NakDBWQFKO0Tf0PQXzhdU8M(WM3fRVTCJg53z2SAuQ2JI(BLaXmQG7gfy5sLo1MBRUIQTpxR0hDB)SHypxTs1gXw90Pbs2oTIwyaGDWyOaEBp1oDbvnnROj6gA7RaU9bTj20h4((Vi2aUf2PDrRf2cV8NYLmgSED4MhcuEc8)9aWtRRU9HJBqfc9uJ8cgv2aUBrnkPOHxYCdt3S3Qj8G1gCnLJtbNNOfSgnq4vDOTfKnLJLORIMWVPODD7qTZGwnMTMb1nzvyQ33QmbrRLDc2z3VScrH7leXlnHiRFG7dePU9Cb278RSmkI(QB2WCXs1PPPEb31DdhWKW1b12aWWpU3aoCTEDQM(zislBTCuMXTV(okoyl79OT8ZLEQDBczH7lRgTDNqfLhtId0U0n6ueU(II0VSzigZKt4QoDGf)0URt7M4nK7ZyfV8t4Q0wrxx2t2Er5Q1F2EHVQDQ(mbq12oUZrXkvPrpLZI(qHAl33ZY9kwAeC7jIFQzxypzutwrwQVXvvqTSmBdUWy9GiPDjfL8quLvdKporSJRxUcOR4tLvXR5DBxl((Ovb0PvkSfZmjCdInAfLOKf9Cvj0mO6OsnM6B4PjqxdsemDHsLW0HBYVrN1jZZA)TaTL)rJ1zcV1Wer9BJ3v4m(TevcWYCLmgl(pWX6v9EP(jc8hcu2tePdU0eQVbTdAwAt1oW0xUtnGHxvvBpt5HQ)IEk2tYLiXDy5R8PjCLNU0JFzqR2bMRD7jIy3ewZbjx1xmvZd1Yxz0YsficnGKnNhGrH)f1)CmGpDZ)7d]] )

spec:RegisterPack( "Fury", 20261027.1113, [[Hekili:TV1EVnUns8plPfW1E3SowoN32DVKa0xx7Ta32I6f4(plrltBjezjxjQ4Mdb6Z(ndFjkjsz5SpU)5W(iosKZmC4843mKEL3QpSA5gcJU69ZNn)1EZM)Tt988UE1s2JhORwEGeEpzh8HuYE4))hL5pIp8XKmYgCQfzL5HWlIySdfV9QR2fZIkxpnmB)vr0CY9XjX6pSA56Y4e2)mD1Ah8S4anC179G3slcfCRk4FtYZJZYRcoG)iMbpAl(R)ycPOioSk4NZjGmLNTnobKKV(RRcAnXXMdTkWBQ3IjvVdh4sU4x82Mutp1LX7Hz)lLpUoVSi6xIzxv)IjvbBOBjLjSIl5timNSLvf8bYd080QGRQcoMDKToC6UDgKxiA7kJHL4uHq8hGcgiw5(diLwwMUHMdF4NO7ZYjjX)N4uGalJYkzWt)dA6g4h)kzFblN)MJuYd8pqs3ufWIaA9BGiCi7ifw7BiPHWti5W)fMLYYZssOW4ItLJvRLkOmgqhuQQEhjKfNLwm9qof2lxtyV82RwtZlO53tZ9lyivVmE7TRl3UDQ4xNUj7yQJzsySeQFbFnOML5dNMt3tItlU56zgChMzijjXx8R(jXfSlr7WBJtJzMJ6q5(90eZNKxM2DAGyEpYE8N(ARPtnl9YUwYBPiMwE40uHVA7S4h88bBnAAr8d1Kq)e7uXUMtWxZDyuxcd)bsEmzniH8Hr)lAyjJ6FiIuqV8bssjQ9Y3rztJOKew00dHSBMp7eKjKK6)NL0sfjUq96PnyWtAtp1J5tcnQ7N(OlW9u)mWC3xovjN6qX1mFYH7Mnc0vSPGsaIR5ZDrUZXypfRbZ2Kn(fcV1wmDdf3HKV0NMItBZiPcKfVN6ZY83etVB84fVsm4PYbtYbVE0Jk8(jVWB6IjV8AruIF7anfDOfXhGWssUvf8v4Rahzi0B9R)EKoF1eiY2248ciUKynxfKTv64VnExegrPmLfNaVVEUWEsvWAks0qsbB6jufzCjRPQOXZ8psszOcaw534nBKGAnxXCTsrmyhFh(XrxaXpEWFx4MPEng45il(PzhLYJ2WRXagLdHENgwMNttz3DRn5kmduEVtSf8dk)EqvXD5ERuvMMLVNKOcUNNb2yiHQLvDedqGJbDbK05atekIBtaHalGmcFN9zykq4KSVySp3Zi0RdcKKLTb1txwwaUAGznSPCRhslU2dcdfhgdAV5Z4BW3nZbD0bn5eJV2ta1(049qU7hOB8BoIPk3MMCXRFUaynYId9fbg6kX4uGaMGwBFmT4wVwgaAh4OcUm4ZIYPGwkzZiToxhtZUaeMaPJpjNVZjNfZ)5Y9nuclY)yCrKHXLzaN5ZEYEm4E2893cM1oON3IZJEIpdRux078KpaJX9j0IIu4Fn8mAMFPlJUX712PiUXfZO7lotxXg5dgn2zq9Bw8KT3PDcNyNVQSBalRtIAj9N9zFmkop5ymGCSRL48E25zr8ChNMMosSpACygy(c4cNAqp1Ifcz8utVGfl6F53FiobO0oEEAxRmfQyFoO4r8DH6hMtjBEear1WZ8MBfKv4qMtzGGdXK0ll9017GZMUyuVRApZbO1IMV2LVDD9a1XZBJ5ahf)LAyhsZTUt)ur(Ju1y0Gp6N6JfEqDgbvpSwHY(O1nYCXcGS1jIf5cXkO0v)CPSMOe6d0eouP1uO0rQLm5aEk(OQcUE2eZe3C2GX1JWyiwtzJIZ3VLHe7h5J6TgqPOi7IfyU4FeGwLZl4JxeluhdGKde9n6NZruuCeqGcfqcXua5pRGobwmzinGG763ZH2ztAhgIbeFKSoyb7IqiFPzkjzn9Xmu)9bK(HiaN)fahKIyCKs2Akx6eWiXaXGQ1iWbaFeiiF5jwQcDGtXUtfMDCMf5(hDHlF3lCVshn(0o2pDHeuIPXP0r6PETCrKQ7j)vJaA3ibuAoEep5eBl9Nfon9S)yaPPiY)BWoPDW(YdCsXATD054j95iHVIPDt31yJUtAz1BzrcweMqoylvVkxG540sYCle0EoNXNmPZtT58KZmnKsaYPcagAoIpqNARjxU5AftWbXBhLTAUFJnt)phP6uPQ(jvJAmYwbcfe9KxqolJx89gYEEqxzZCQfsDFESeG0XOmbePKIpqsVNNdCm(jiuE2gQUPFyYLCzQNFhQFLYPADlxHuIbYwJInpRq2qryxNL8i27ssYRogtXucynWxzsJ4uhQH)oW(iXKiRJtIzWEOKWzPiz5DqCpSxInS8iV9gK65q)ZY4dhOBmuvOSH(S8r4VMue15DNip(VxMiqkSnpBVcLXv2k8xLHx2EL4T2YCBKXgmlGSTYmRKJKhVKpHulkglROwrHUWvhahyhnAomBzc7icTzwZi1DgoJuM2eGkVRR8hpsLfNSBxEwNPMaGm4mzt35x)o)dHmGggTJSVr6Yg5ijj5thxEXmtW7soDg5MDAjNKfEFpv2WffZXoIRzBzmmFHe3K5i5DngT8)vE2F0eet)laQkmObwKqFLWDrzaJNwXBr)2ShuqwRJ7fm(Ek9a3nIMMvUlsc2LGU0aqTgGeNiJ9GGpbe45s49MOirrbJKOaGjH1tA1TtXalyXjy7m3cSCdMMa)maA9ijhXypge5sSDOWN3xggjKBc8KdiHKUNfDKcvTei64DjzRr0Wk5zsxh2Zfl1yh5w47SsevJg)jfDQo6qdzLhE4LY30b46tUfG(lStka2dp5wa6e4As3a6FK4g5AydWJD9FFoiZLZnhSOtTqtPhyrczV94fTH4jFhOgGDaPMsMxhmFPcxO98ABLR43AuJmkLFtrTPo3p5qcwrgjmpdlBdD9Eum5hfNoO407a7(ImS4TVrfp47Z(zZOaDT9BRWATtC71p7TI2PbFUGU7gK(enxHlzAuUNhwwlYE17wTe03fW77Cg4qCQuKNRwUAjEUDf4XSluPWNEp)a7LUCR(HvlfCz1sbUg4NaCnkuIYQLTW3SIbSYXKnLnts4UyAKAx3IAgSgYVxfCxvWSQGrvbxaqDTxVU6190FcCeJfgCktMQGBUvbuUfQLGNEItq3XPedPVGvCjxgWsm6wmh9ASgFSkysTsTnw9vlnIrHBKGk8V5ydX0fYuX6m2dxQUgj5cN7kMOnG1iOcNl2FQ3UmKafQfBI9RDYJM(6vbat848OPkezU7ggWNq3k3RfUgjmSjGF7GfW7gGaAT1cNuifZYM09Do211(h4GEZZ1xTrJjuUpoJuYnCwimZ7jKPW(cTVbrZBMdzt23c(yCfOYWNHpoxXKm7rXj2aNZxL90BdU0pNZU2bTuSRBSCtMo2WAWvppe6q7I3etj0DAJAVypxrgWwBykzwBmcNBTLeXgyTyOBsIigqNgLWL93WfM2Xu0(HQoFyvIA1(Kt5L5QnkRq7KLY7AvVPaBDJxe5p9f3Cn82c0xkqXvi6eP1ig3BiJTKM3xNgSfNITa9TdPt7CJIgg91tS)q)nYBCMCqa9O3O(U6gXW4GEI2ICpOnxTmYWlcO8EN1NPs3CZTwmgxPT(SAEM5PNje16nVEev91f5lc2oBoaFKl2(n))0bkXvqQMxRKMAXHCbuQJB1qm96iM)FGrdtipFGr1xRflobTtzH2pyMy7xjH(GwvFBxgaB8wCk24eMu9TGzi85KlhNqTmVDmwD9BEdB4SXMuaEXEVUxWA6BntVySozOOVaqxDHRsbD1qSmRl1YvTPxKr67UWPGUYPs7WgnminWk7k5OvUDHlBgLI9e1aFlh5A3YFXxSyHsF6YL1uj12FZcwXw3nhUi2xpdgA7agzSm7CxD4wgyl7BmmxDeWR9a7C)uudRBktNnayURye9xpYakg58Q3yURyiFrG4)jFdGdVIJ9UhKvghtyFaOguN1o3qEQwIz7s8BxjkOOLlNSLHB3BWgqSAZTMYX5aWIFMEwnpy6J8Rfwj(Vc6a(Xuzd4KI21NVMBg06K(Qzq9P2Xn07Bw2Wg1YobpQWpVcrvWl4XJSbfQFeZdeI8aceZAFuIIEjWpOw7gMZxO2nTD4IDD3Wxyt46axAaGN70y4gHByghEMA4FM7nSHNA3t1Qk4L916yfam3s3qIsQfU(II0VSzjgZKZOgJo4r)4kYO9PcnKcjCcu9JOgwNWALhYxVWlnoWVEXn2gXNR4InoiWEXg6Af3zR4wv)bpN9I(Ga6k33Nea9lSIS8mrp18y9oBmtUWU1yHR6EPSfxNttP6bustGLCEW7WPfYNDGVIRNRQQa(NKDqRzrLl5FPP0aDALcB(mBs2GyJr3aKSONQuqZa9wv7VzG2aDnirWwLCkHPd3eFtaRtMx0(Bpyl)JgZZgERHjIMLb3v4S(TluaWYElegZ)l4y9QERMEch)bhL9eE6aRNN4Gwbn7POAfy7lfObWWB0nvZwEO6VGG81KykcCho(QcAdx55l98t7wTcS300ZeX(kXFwskzryKXFv99JhF6Q)l]] )

spec:RegisterPack( "Protection", 20261027.1113, [[Hekili:1MvBVnoUr4Fl5oax7nzvSsQV7AAIb2T9oCDb62dWhq)MKOLOTiISOosQ4lfb63ENHKsMsIYz30EyxeRioKZdNxEMzIJcJ(1Onzefn6Z3S8MVlC5nFFqyy4TrBupxrJ2ursFKShEOKCa(5Vi4kAQIXlXLEUGtYWdqYRfPWY5kvL8URVEptLxVniLF46CQG8iRG19q0MT1Sc1)OmA7eAwwrtJ(CiSkvM6QZMK)nriyCrtsf(bt9CtYo8x)BfePKL2K8JccGmbFhRaWZ3(TnjE3(C3n0KegeUArZNqX)jC50CIGKQOcztYr4U0KCGlvGw5Ssf8owP75g0K0K8HIJKNHLuKYhL)v4ZCAtIemAMx1KuWWtGbIulPznjBF2k0pvlGhjLW7(G4G0ad79JrTA7Vt3rlLSNa53aNxk858FvFU)tEgDXvaoZzP5gfKZp2Iy91tJjydz1KI3FKrlYmA96t3HfGkliph08PMpr0VrgujOGhClrD5dxd)uvqJL58A1vSDpSTE3Ua3xgiOhiSs593U05mGDMskkIn)AmAdUcJKEGvYuUsjQlhlK2W5aiCtGSpremY2cQri6VttRv04QCIKE1tKIACJI9uvqoLuOYdQsv3FZYx5ysjLX)wnTU9iUOD5GEk4fjvPyL7LDVwVj4nVY5lvc2J0y(turSDRwnn6e3QIjvRxotQiQaWedPGXv8JuX6jK91un4FkYIL1LzuXqLMrrxPDXyAjUTSzwdOIDGgR4Xzm665Zx9EJWbwHjIdCrGeX3I3fgSAXL3AcE)xv0skKgTrlhe4z1wtY3Glb5H6CQ2L)aEoFZI7GCzMadAn35Me(oBkYo2(CfeJxxQyfW6N2l4tGujkEOPePk4vmfCnY6Bk69U4JKsfAaGB(9HlNzoT(3yTvrYGKW14JZUasuEkEFAwqypb)AWsCj)OfpDbE9eyMaOHdsRfcAPA9d(WvkMX)jJla5g0wChwcGpY4haljYYPnTU0JTKQl0mAUuheb1WOuauvNHgrtwPbWiclGtuMB2ezluhWWTPpyEjESA2Mdu4cL1Y6soTh6VvZQQOzoEyeBGv1ir8wImF0Air(EksyzJObMkjlJ(dgq(l1ffAR0ob)qtYh18zx)rG3NkEuhbRH(DNI3SrOS2it5ri9l5iMGb3d4vIJmjY5Nlqsy0PbxdO0Wv6n4Jj3ZnYXRIy)cDwxw7gJLM9vx9fgu0xmZUJX3flOkG0gm4dHWqLDfu0kMdefqy(dHJexrGuteQD8k4cX6xRZLa6Sli73l4J2kuiwPvs249FATyGehodhg9Zj5uXihHAr))tlVBzWQrAABbNNH22(wmuRAVayyzPmWz5wrAqKCbp9XXBVpuCLDM2Yoiy4MvZmXnUscXmMi)FMk4y7pB0LLmTnycObvuqFVjDPnaoR(q1DyEl)jQvoiaNcfwWW(5psPv60iAjVEFUTNmcMstYGm7pI2evoM6SWY9CeYfOqTqdACeWafKjjLdNo)yPT3iYGcggbLqbbSIWoqLziRj(m042rIidB5bGCnwrbE(qn2FeIBc2khEq20t5iuCLvPL8MK9f8TKIt4zX4e2CT1m2uJFSNdLgYKGB8bG07HWzZ77Q67zZL6CZzZVqrkG1d2Ecxb2c0V0cMElABbBnwk6a53FXl7qpSQPhU0UI7rHVFXltdGzFjaWp900ayeX1IXe6fuYtVQjED4SZzHnhI2kpo)9lVr3r7fAdGw65mTzGYcYb)8f2q)HRbMbWdyTu266q4l1KcbRsXuo9n(U2QxqwcIY)K8uOUopPcQ4cb1PcUe(vm17zZMF2mGHPtFiUxcH8m7(Ht7d8F0LfyCS)qd2apXd3(MDfdldoz3N3V6fFR16OgtsNrH1jfS)daKtiVpYqz0lnZE2J30zcf63hy0gWElH1hnRlWtvI6mAt0gCWhjoon2Ui85N1dNBt4I(y0gEfmCmvfTXOm4uTTkQFk2mIEVXvWfGEkHP5horutY9nj3Smsbq6TOMU5L6uXfnj(NzQj5Lx669C8GtieU9TabpJu1bMjgukzDtYYMKzyHJbdxbR9GhuQ3hcX)8BcIUJEngCEh(sdVXdGPX(C9)x1K8EiDCQ0HMeyA(3H)vnwPF8YMKBXBWQ3YnO3qiD3aFZmzWnd)lEaHwHgZSpM9tZpPVtMTaYEbobI3jPq0)D)pJECgRUBG)PS04WLVYevmv9Pi8Fyx8p6lDTfyodO4lDRvmZSkWNWiyuaCDjTTZS4lrPthUwlNJaSPtn8Wx5D1N460Ordt4lBPfNdXr0gNs5Oj0tCA7E1tt4E58mSHtqyxQoyd0ni7lkQ9Sp1z)0kyWmgNuWaw1ZTledF)5JtWHu(JfeA2by4fem)WaWCsVUJRycnGYfDGTBohFEW)YKh60dXyOl0Ji6pW8MvTEtFJ1moDdxWh4cxoj6637stcO1qTsN7dqEBBVv8lqo8P6E2ur8CTqRDS22OnspzM64(P1u(2vh2uVUIaEENdDZ(Aa35yrop28WXS4KFS3E96ihs4oTJCDRJ818Io9J6WmRFPximfzUBxXUaBYXj0jT6Y0HtXXBhVqlZu8RoJAOLBkUuhVQwUP4f7ncIwYPyVM6gpYva28B)Q9fOMhsv9A1(otds3RBIctdoZGdgX0QEiH2PYzdNjyAYUUbk0x(xDOItbe3mKWY7fx3kcqxtQl8o8qxW8GVpgZCh2(L0tECMEug8100BV62G0OO7lo6C44nMHSmY21fPwLJ(7FU97veFB0)9p]] )

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
