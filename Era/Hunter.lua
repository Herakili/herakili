-- Era/Hunter.lua
-- Classic Era (1.15.x) Hunter.  Spell, rank, talent and aura IDs from the Classic Era client tables (build 1.15.9).

if UnitClassBase( 'player' ) ~= 'HUNTER' then return end

local addon, ns = ...
local Hekili = _G[ addon ]
local class, state = Hekili.Class, Hekili.State

local FindUnitBuffByID = ns.FindUnitBuffByID

local ceil, max = math.ceil, math.max

local IsCurrentSpell = _G.IsCurrentSpell or ( C_Spell and C_Spell.IsCurrentSpell )

local spec = Hekili:NewSpecialization( 3, true )

spec:RegisterResource( Enum.PowerType.Mana )


-- Rank-dependent values, keyed by the spell ID of the highest rank you know.
local function known_id( key )
    local ability = class.abilities[ key ]
    return ability and ability.id
end

local GetSpellPowerCost = _G.GetSpellPowerCost or ( C_Spell and C_Spell.GetSpellPowerCost )

-- Mana costs: the live client's cost for the rank you know (talents such as Efficiency included), refreshed every
-- 10 seconds.  Percent-of-base-mana costs (Bestial Wrath, Revive Pet, ...) come back as absolute amounts.
local cost_cache = {}

local function mana_cost( key )
    local id = known_id( key )
    if not id then return 0 end

    local now = GetTime()
    local c = cost_cache[ id ]

    if not c or now - c.t > 10 then
        local value
        if GetSpellPowerCost then
            local ok, list = pcall( GetSpellPowerCost, id )
            if ok and type( list ) == "table" then
                for _, p in ipairs( list ) do
                    if type( p ) == "table" and p.type == 0 and type( p.cost ) == "number" then
                        value = p.cost
                        break
                    end
                end
            end
        end
        c = { t = now, v = value or 0 }
        cost_cache[ id ] = c
    end

    return c.v
end


-- Talents: { talentID, maxRank, rank1SpellID, ... rankNSpellID }, from the Classic Era client's Talent table.
-- Tree order in game (and in the talent-point string): Beast Mastery, Marksmanship, Survival.
spec:RegisterTalents( {
    -- Beast Mastery
    improved_aspect_of_the_hawk   = {  1382, 5, 19552, 19553, 19554, 19555, 19556 },
    endurance_training            = {  1389, 5, 19583, 19584, 19585, 19586, 19587 },
    improved_eyes_of_the_beast    = {  1624, 2, 19557, 19558 },
    improved_aspect_of_the_monkey = {  1381, 5, 19549, 19550, 19551, 24386, 24387 },
    thick_hide                    = {  1395, 3, 19609, 19610, 19612 },
    improved_revive_pet           = {  1625, 2, 24443, 19575 },
    pathfinding                   = {  1384, 2, 19559, 19560 },
    bestial_swiftness             = {  1391, 1, 19596 },
    unleashed_fury                = {  1396, 5, 19616, 19617, 19618, 19619, 19620 },
    improved_mend_pet             = {  1385, 2, 19572, 19573 },
    ferocity                      = {  1393, 5, 19598, 19599, 19600, 19601, 19602 },
    spirit_bond                   = {  1388, 2, 19578, 20895 },
    intimidation                  = {  1387, 1, 19577 },
    bestial_discipline            = {  1390, 2, 19590, 19592 },
    frenzy                        = {  1397, 5, 19621, 19622, 19623, 19624, 19625 },
    bestial_wrath                 = {  1386, 1, 19574 },

    -- Marksmanship
    improved_concussive_shot      = {  1341, 5, 19407, 19412, 19413, 19414, 19415 },
    efficiency                    = {  1342, 5, 19416, 19417, 19418, 19419, 19420 },
    improved_hunter_s_mark        = {  1343, 5, 19421, 19422, 19423, 19424, 19425 },
    lethal_shots                  = {  1344, 5, 19426, 19427, 19429, 19430, 19431 },
    aimed_shot                    = {  1345, 1, 19434 },
    improved_arcane_shot          = {  1346, 5, 19454, 19455, 19456, 19457, 19458 },
    hawk_eye                      = {  1352, 3, 19498, 19499, 19500 },
    improved_serpent_sting        = {  1348, 5, 19464, 19465, 19466, 19467, 19468 },
    mortal_shots                  = {  1349, 5, 19485, 19487, 19488, 19489, 19490 },
    scatter_shot                  = {  1353, 1, 19503 },
    barrage                       = {  1347, 3, 19461, 19462, 24691 },
    improved_scorpid_sting        = {  1351, 3, 19491, 19493, 19494 },
    ranged_weapon_specialization  = {  1362, 5, 19507, 19508, 19509, 19510, 19511 },
    trueshot_aura                 = {  1361, 1, 19506 },

    -- Survival
    monster_slaying               = {  1623, 3, 24293, 24294, 24295 },
    humanoid_slaying              = {  1301, 3, 19151, 19152, 19153 },
    deflection                    = {  1311, 5, 19295, 19297, 19298, 19301, 19300 },
    entrapment                    = {  1304, 5, 19184, 19387, 19388, 19389, 19390 },
    savage_strikes                = {  1621, 2, 19159, 19160 },
    improved_wing_clip            = {  1305, 5, 19228, 19232, 19233, 19234, 19235 },
    clever_traps                  = {  1306, 2, 19239, 19245 },
    survivalist                   = {  1622, 5, 19255, 19256, 19257, 19258, 19259 },
    deterrence                    = {  1308, 1, 19263 },
    trap_mastery                  = {  1322, 2, 19376, 19377 },
    surefooted                    = {  1310, 3, 19290, 19294, 24283 },
    improved_feign_death          = {  1309, 2, 19286, 19287 },
    killer_instinct               = {  1321, 3, 19370, 19371, 19373 },
    counterattack                 = {  1312, 1, 19306 },
    lightning_reflexes            = {  1303, 5, 19168, 19180, 19181, 24296, 24297 },
    wyvern_sting                  = {  1325, 1, 19386 },
} )


-- Mend Pet: the heal-over-time lives on the pet; any rank counts.
local mend_pet_ranks = { [136] = true, [3111] = true, [3661] = true, [3662] = true, [13542] = true, [13543] = true, [13544] = true }
local hunters_mark_ranks = { [1130] = true, [14323] = true, [14324] = true, [14325] = true }


-- Auras
spec:RegisterAuras( {
    aspect = {
        alias = { "aspect_of_the_hawk", "aspect_of_the_monkey", "aspect_of_the_cheetah", "aspect_of_the_pack", "aspect_of_the_beast", "aspect_of_the_wild" },
        aliasMode = "first",
        aliasType = "buff",
    },
    -- Untrackable.
    aspect_of_the_beast = {
        id = 13161,
        duration = 3600,
        max_stack = 1,
    },
    -- Movement speed increased by 30%.  Dazed if struck.
    aspect_of_the_cheetah = {
        id = 5118,
        duration = 3600,
        max_stack = 1,
    },
    -- Increases Ranged Attack Power.
    aspect_of_the_hawk = {
        id = 25296,
        duration = 3600,
        max_stack = 1,
        copy = { 13165, 14318, 14319, 14320, 14321, 14322, 25296 },
    },
    -- Increases chance to dodge.
    aspect_of_the_monkey = {
        id = 13163,
        duration = 3600,
        max_stack = 1,
    },
    -- Movement speed increased by 30%.  Dazed if struck.
    aspect_of_the_pack = {
        id = 13159,
        duration = 3600,
        max_stack = 1,
    },
    -- Nature resistance increased.
    aspect_of_the_wild = {
        id = 20190,
        duration = 3600,
        max_stack = 1,
        copy = { 20043, 20190 },
    },
    -- Pseudo-aura: Auto Shot is active (auto-repeating).
    auto_shot = {
        duration = 3600,
        max_stack = 1,
    },
    berserking = {
        id = 20554,
        duration = 10,
        max_stack = 1,
        copy = { 26296, 26297 },
    },
    -- Pet enraged (on the pet).
    bestial_wrath = {
        id = 19574,
        duration = 18,
        max_stack = 1,
        shared = "pet",
    },
    concussive_shot = {
        id = 5116,
        duration = 4,
        max_stack = 1,
    },
    -- Pseudo-aura: you parried, so Counterattack is usable for 5 seconds.
    counterattack_usable = {
        duration = 5,
        max_stack = 1,
    },
    counterattack = {
        id = 20910,
        duration = 5,
        max_stack = 1,
        copy = { 19306, 20909, 20910 },
    },
    deterrence = {
        id = 19263,
        duration = 10,
        max_stack = 1,
    },
    feign_death = {
        id = 5384,
        duration = 360,
        max_stack = 1,
    },
    -- Ranged Attack Power of all attackers against the target increased.  Any hunter's Mark counts.
    hunters_mark = {
        id = 14325,
        duration = 120,
        max_stack = 1,
        shared = "target",
        multi = hunters_mark_ranks,
        copy = { 1130, 14323, 14324, 14325 },
    },
    intimidation = {
        id = 19577,
        duration = 15,
        max_stack = 1,
    },
    -- Healing the pet every second (channeled).
    mend_pet = {
        id = 13544,
        duration = 5,
        tick_time = 1,
        max_stack = 1,
        generate = function( t )
            local name, _, count, _, duration, expires, caster = FindUnitBuffByID( "pet", mend_pet_ranks )

            if name then
                t.name = name
                t.count = 1
                t.expires = expires
                t.applied = expires - duration
                t.caster = "player"
                return
            end

            t.count = 0
            t.expires = 0
            t.applied = 0
            t.caster = "nobody"
        end,
        copy = { 136, 3111, 3661, 3662, 13542, 13543, 13544 },
    },
    -- Pseudo-aura: you dodged, so Mongoose Bite is usable for 5 seconds.
    mongoose_bite_usable = {
        duration = 5,
        max_stack = 1,
    },
    -- Ranged attack speed increased by 30% (Improved Aspect of the Hawk proc).
    quick_shots = {
        id = 6150,
        duration = 12,
        max_stack = 1,
    },
    -- Ranged attack speed increased by 40%.
    rapid_fire = {
        id = 3045,
        duration = 15,
        max_stack = 1,
    },
    -- Pseudo-aura: Raptor Strike is queued on the next melee swing.
    raptor_strike_queued = {
        duration = function () return swings.mainhand_speed end,
        max_stack = 1,
    },
    scatter_shot = {
        id = 19503,
        duration = 4,
        max_stack = 1,
    },
    scorpid_sting = {
        id = 14277,
        duration = 20,
        max_stack = 1,
        copy = { 3043, 14275, 14276, 14277 },
    },
    serpent_sting = {
        id = 25295,
        duration = 15,
        tick_time = 3,
        max_stack = 1,
        copy = { 1978, 13549, 13550, 13551, 13552, 13553, 13554, 13555, 25295 },
    },
    -- Attack power of party members increased.
    trueshot_aura = {
        id = 20906,
        duration = 1800,
        max_stack = 1,
        copy = { 19506, 20905, 20906 },
    },
    viper_sting = {
        id = 14280,
        duration = 8,
        max_stack = 1,
        copy = { 3034, 14279, 14280 },
    },
    volley = {
        id = 14295,
        duration = 6,
        tick_time = 1,
        max_stack = 1,
        copy = { 1510, 14294, 14295 },
    },
    wing_clip = {
        id = 14268,
        duration = 10,
        max_stack = 1,
        copy = { 2974, 14267, 14268 },
    },
    wyvern_sting = {
        id = 24133,
        duration = 12,
        max_stack = 1,
        copy = { 19386, 24132, 24133 },
    },
    -- Only one sting per hunter can be active on a target.
    sting = {
        alias = { "serpent_sting", "scorpid_sting", "viper_sting", "wyvern_sting" },
        aliasMode = "first",
        aliasType = "debuff",
    },
} )


-- Combat log: your dodges (Mongoose Bite), your parries (Counterattack), and your pet's death.
local last_dodge, last_parry = 0, 0
local pet_guid, pet_died = nil, false

spec:RegisterCombatLogEvent( function( _, subtype, _, sourceGUID, _, _, _, destGUID, _, _, _, ... )
    if subtype == "UNIT_DIED" then
        if pet_guid and destGUID == pet_guid then pet_died = true end
        return
    end

    if destGUID ~= state.GUID then return end
    if subtype ~= "SWING_MISSED" and subtype ~= "SPELL_MISSED" and subtype ~= "RANGE_MISSED" then return end

    -- SWING_MISSED: missType is the first suffix argument; SPELL_/RANGE_MISSED have spellId, spellName, spellSchool first.
    local missType
    if subtype == "SWING_MISSED" then missType = ...
    else missType = select( 4, ... ) end

    if missType == "DODGE" then last_dodge = GetTime()
    elseif missType == "PARRY" then last_parry = GetTime() end
end )


-- Auto Shot: the client reports every shot through UNIT_SPELLCAST_SUCCEEDED (spell 75).
local last_auto = 0
-- Virtual last-shot time set by predicted casts (Aimed Shot holds the next Auto Shot until it finishes).
local virtual_auto = 0

spec:RegisterEvent( "UNIT_SPELLCAST_SUCCEEDED", function( _, unit, _, spellID )
    if unit == "player" and spellID == 75 then last_auto = GetTime() end
end )

-- Ranged attack speed (already includes haste: quiver, Rapid Fire, Quick Shots, ...).
spec:RegisterStateExpr( "ranged_speed", function()
    local speed = UnitRangedDamage( "player" )
    return ( speed and speed > 0 ) and speed or 3
end )

-- Seconds until the next Auto Shot fires (0 if Auto Shot is off or the shot is due now).
spec:RegisterStateExpr( "time_to_auto", function()
    if buff.auto_shot.down then return 0 end

    local last = max( last_auto, virtual_auto )
    if last == 0 then return 0 end

    local speed = ranged_speed
    local nextShot = last + speed
    if nextShot < query_time then
        nextShot = nextShot + ceil( ( query_time - nextShot ) / speed ) * speed
    end
    return max( 0, nextShot - query_time )
end )

-- How a pending ability fits around Auto Shot.  ready = seconds until the ability is otherwise ready.
-- Returns the wait until the first moment at or after `ready` that lies within `window` seconds after a shot.
local function wait_after_shot( ready, window )
    if state.buff.auto_shot.down then return 0 end
    local speed = state.ranged_speed
    local tta = state.time_to_auto
    -- Shot times relative to now: tta - speed (the last one), tta, tta + speed, ...
    local shot = tta - speed
    while shot + window < ready do shot = shot + speed end
    return max( ready, shot )
end

-- Wait so that an ability that briefly holds Auto Shot (hold seconds) doesn't start just before a shot.
local function wait_no_clip( ready, hold )
    if state.buff.auto_shot.down then return 0 end
    local speed = state.ranged_speed
    local shot = state.time_to_auto
    while shot < ready do shot = shot + speed end
    if shot - ready < hold then return shot + 0.05 end
    return ready
end

-- Aimed Shot mode: "clipped", "full", "none" or "auto" (full with slow weapons, clipped with fast ones).
spec:RegisterStateExpr( "aimed_shot_mode", function()
    local mode = settings.aimed_shot_mode or "auto"
    if mode == "auto" then return ranged_speed >= 2.55 and "full" or "clipped" end
    return mode
end )

spec:RegisterStateExpr( "aimed_shot_wanted", function()
    return aimed_shot_mode ~= "none"
end )

-- Serpent Sting setting: "always", "solo" (not in a raid) or "never".
spec:RegisterStateExpr( "serpent_wanted", function()
    local mode = settings.serpent_sting or "solo"
    if mode == "always" then return true end
    if mode == "solo" then return not raid end
    return false
end )

spec:RegisterStateExpr( "pet_needs_revive", function()
    if not settings.pet_management then return false end
    return pet_died or ( UnitExists( "pet" ) and UnitIsDead( "pet" ) ) or false
end )

spec:RegisterStateExpr( "pet_missing", function()
    if not settings.pet_management then return false end
    return not UnitExists( "pet" ) and not pet_died
end )

local finish_raptor = setfenv( function()
    spend( mana_cost( "raptor_strike" ), "mana" )
end, state )

spec:RegisterStateFunction( "start_raptor", function()
    applyBuff( "raptor_strike_queued", swings.time_to_next_mainhand )
    state:QueueAuraExpiration( "raptor_strike_queued", finish_raptor, buff.raptor_strike_queued.expires )
end )


spec:RegisterHook( "reset_precast", function()
    virtual_auto = 0

    local autoName = class.abilities.auto_shot and class.abilities.auto_shot.name
    if autoName and IsAutoRepeatSpell( autoName ) then applyBuff( "auto_shot" )
    else removeBuff( "auto_shot" ) end

    if UnitExists( "pet" ) then
        pet_guid = UnitGUID( "pet" )
        if not UnitIsDead( "pet" ) then pet_died = false end
    end

    if IsCurrentSpell and class.abilities.raptor_strike.id and IsCurrentSpell( class.abilities.raptor_strike.id ) then
        start_raptor()
    end

    if now == query_time then
        if last_dodge > 0 and now - last_dodge < 5 then applyBuff( "mongoose_bite_usable", last_dodge + 5 - now ) end
        if last_parry > 0 and now - last_parry < 5 then applyBuff( "counterattack_usable", last_parry + 5 - now ) end
    end
end )


local function apply_aspect( aspect )
    removeBuff( "aspect" )
    applyBuff( aspect )
end
apply_aspect = setfenv( apply_aspect, state )


-- Abilities
spec:RegisterAbilities( {
    -- An aimed shot that increases ranged damage.  3 sec cast (shortened by ranged haste); holds Auto Shot.
    aimed_shot = {
        id = 20904,
        cast = function() return 3 / ( ( buff.rapid_fire.up and 1.4 or 1 ) * ( buff.quick_shots.up and 1.3 or 1 ) ) end,
        cooldown = 6,
        gcd = "spell",

        spend = function() return mana_cost( "aimed_shot" ) end,
        spendType = "mana",

        talent = "aimed_shot",
        startsCombat = true,
        texture = 135130,

        -- "full": cast right after an Auto Shot, so the cast doesn't swallow a shot.
        readyTime = function()
            if aimed_shot_mode ~= "full" then return 0 end
            return wait_after_shot( cooldown.aimed_shot.remains, 0.4 )
        end,

        handler = function()
            -- The shot that came due during the cast fires right after it (~0.5 s).
            virtual_auto = query_time + 0.5 - ranged_speed
        end,

        copy = { 19434, 20900, 20901, 20902, 20903 },
    },

    -- An instant shot that causes Arcane damage.
    arcane_shot = {
        id = 14287,
        cast = 0,
        cooldown = function() return 6 - 0.2 * talent.improved_arcane_shot.rank end,
        gcd = "spell",

        spend = function() return mana_cost( "arcane_shot" ) end,
        spendType = "mana",

        startsCombat = true,
        texture = 132218,

        copy = { 3044, 14281, 14282, 14283, 14284, 14285, 14286 },
    },

    aspect_of_the_beast = {
        id = 13161,
        cast = 0,
        cooldown = 1,
        gcd = "off",

        spend = function() return mana_cost( "aspect_of_the_beast" ) end,
        spendType = "mana",

        startsCombat = false,
        texture = 132252,

        nobuff = "aspect_of_the_beast",
        handler = function() apply_aspect( "aspect_of_the_beast" ) end,
    },

    aspect_of_the_cheetah = {
        id = 5118,
        cast = 0,
        cooldown = 1,
        gcd = "off",

        spend = function() return mana_cost( "aspect_of_the_cheetah" ) end,
        spendType = "mana",

        startsCombat = false,
        texture = 132242,

        nobuff = "aspect_of_the_cheetah",
        handler = function() apply_aspect( "aspect_of_the_cheetah" ) end,
    },

    aspect_of_the_hawk = {
        id = 25296,
        cast = 0,
        cooldown = 1,
        gcd = "off",

        spend = function() return mana_cost( "aspect_of_the_hawk" ) end,
        spendType = "mana",

        startsCombat = false,
        texture = 136076,

        nobuff = "aspect_of_the_hawk",
        handler = function() apply_aspect( "aspect_of_the_hawk" ) end,

        copy = { 13165, 14318, 14319, 14320, 14321, 14322 },
    },

    aspect_of_the_monkey = {
        id = 13163,
        cast = 0,
        cooldown = 1,
        gcd = "off",

        spend = function() return mana_cost( "aspect_of_the_monkey" ) end,
        spendType = "mana",

        startsCombat = false,
        texture = 132159,

        nobuff = "aspect_of_the_monkey",
        handler = function() apply_aspect( "aspect_of_the_monkey" ) end,
    },

    aspect_of_the_pack = {
        id = 13159,
        cast = 0,
        cooldown = 1,
        gcd = "off",

        spend = function() return mana_cost( "aspect_of_the_pack" ) end,
        spendType = "mana",

        startsCombat = false,
        texture = 132267,

        nobuff = "aspect_of_the_pack",
        handler = function() apply_aspect( "aspect_of_the_pack" ) end,
    },

    aspect_of_the_wild = {
        id = 20190,
        cast = 0,
        cooldown = 1,
        gcd = "off",

        spend = function() return mana_cost( "aspect_of_the_wild" ) end,
        spendType = "mana",

        startsCombat = false,
        texture = 136074,

        nobuff = "aspect_of_the_wild",
        handler = function() apply_aspect( "aspect_of_the_wild" ) end,

        copy = { 20043 },
    },

    -- Starts Auto Shot.
    auto_shot = {
        id = 75,
        cast = 0,
        cooldown = 0,
        gcd = "off",

        startsCombat = true,
        texture = 132369,

        nobuff = "auto_shot",
        usable = function() return not target.within8, "target is too close" end,

        handler = function()
            applyBuff( "auto_shot" )
        end,
    },

    -- Troll racial (hunter version): attack speed increased for 10 sec.
    berserking = {
        id = 20554,
        cast = 0,
        cooldown = 180,
        gcd = "off",

        toggle = "cooldowns",
        startsCombat = false,
        texture = 135727,

        handler = function()
            applyBuff( "berserking" )
        end,

        copy = { 26296, 26297 },
    },

    -- Send your pet into a rage for 18 sec.
    bestial_wrath = {
        id = 19574,
        cast = 0,
        cooldown = 120,
        gcd = "off",

        spend = function() return mana_cost( "bestial_wrath" ) end,
        spendType = "mana",

        talent = "bestial_wrath",
        toggle = "cooldowns",
        startsCombat = false,
        texture = 132127,

        usable = function() return pet.alive, "requires a living pet" end,

        handler = function()
            applyBuff( "bestial_wrath" )
        end,
    },

    call_pet = {
        id = 883,
        cast = 0,
        cooldown = 0,
        gcd = "spell",

        startsCombat = false,
        texture = 132161,

        usable = function() return not UnitExists( "pet" ), "you already have a pet" end,
        handler = function()
            summonPet( "pet" )
        end,
    },

    concussive_shot = {
        id = 5116,
        cast = 0,
        cooldown = 12,
        gcd = "spell",

        spend = function() return mana_cost( "concussive_shot" ) end,
        spendType = "mana",

        startsCombat = true,
        texture = 135860,

        handler = function()
            applyDebuff( "target", "concussive_shot" )
        end,
    },

    -- After you parry: damage and immobilize.
    counterattack = {
        id = 20910,
        cast = 0,
        cooldown = 5,
        gcd = "spell",

        spend = function() return mana_cost( "counterattack" ) end,
        spendType = "mana",

        talent = "counterattack",
        startsCombat = true,
        texture = 132336,

        buff = "counterattack_usable",

        handler = function()
            removeBuff( "counterattack_usable" )
            applyDebuff( "target", "counterattack" )
        end,

        copy = { 19306, 20909 },
    },

    deterrence = {
        id = 19263,
        cast = 0,
        cooldown = 300,
        gcd = "spell",

        talent = "deterrence",
        toggle = "defensives",
        startsCombat = false,
        texture = 132369,

        handler = function()
            applyBuff( "deterrence" )
        end,
    },

    dismiss_pet = {
        id = 2641,
        cast = 5,
        cooldown = 0,
        gcd = "spell",

        startsCombat = false,
        texture = 136095,

        usable = function() return pet.alive, "requires a pet" end,
    },

    disengage = {
        id = 14273,
        cast = 0,
        cooldown = 5,
        gcd = "spell",

        spend = function() return mana_cost( "disengage" ) end,
        spendType = "mana",

        startsCombat = true,
        texture = 132294,

        copy = { 781, 14272 },
    },

    feign_death = {
        id = 5384,
        cast = 0,
        cooldown = 30,
        gcd = "spell",

        spend = function() return mana_cost( "feign_death" ) end,
        spendType = "mana",

        toggle = "defensives",
        startsCombat = false,
        texture = 132293,

        handler = function()
            applyBuff( "feign_death" )
        end,
    },

    -- Places the Hunter's Mark on the target, increasing the Ranged Attack Power of all attackers against it.  2 min.
    hunters_mark = {
        id = 14325,
        cast = 0,
        cooldown = 0,
        gcd = "spell",

        spend = function() return mana_cost( "hunters_mark" ) end,
        spendType = "mana",

        startsCombat = false,
        texture = 132212,

        handler = function()
            applyDebuff( "target", "hunters_mark" )
        end,

        copy = { 1130, 14323, 14324 },
    },

    intimidation = {
        id = 19577,
        cast = 0,
        cooldown = 60,
        gcd = "spell",

        spend = function() return mana_cost( "intimidation" ) end,
        spendType = "mana",

        talent = "intimidation",
        startsCombat = true,
        texture = 132111,

        usable = function() return pet.alive, "requires a living pet" end,
        handler = function()
            applyBuff( "intimidation" )
        end,
    },

    -- Heals your pet every second while you focus (channeled, 5 sec).
    mend_pet = {
        id = 13544,
        cast = 5,
        channeled = true,
        cooldown = 0,
        gcd = "spell",

        spend = function() return mana_cost( "mend_pet" ) end,
        spendType = "mana",

        startsCombat = false,
        texture = 132179,

        usable = function() return pet.alive, "requires a living pet" end,
        start = function()
            applyBuff( "mend_pet" )
        end,

        copy = { 136, 3111, 3661, 3662, 13542, 13543 },
    },

    -- After you dodge: an attack that can't be blocked, dodged or parried.
    mongoose_bite = {
        id = 14271,
        cast = 0,
        cooldown = 5,
        gcd = "spell",

        spend = function() return mana_cost( "mongoose_bite" ) end,
        spendType = "mana",

        startsCombat = true,
        texture = 132215,

        buff = "mongoose_bite_usable",

        handler = function()
            removeBuff( "mongoose_bite_usable" )
        end,

        copy = { 1495, 14269, 14270 },
    },

    -- Fires several missiles, hitting 3 targets.  Briefly holds Auto Shot while aiming.
    multishot = {
        id = 25294,
        cast = 0,
        cooldown = 10,
        gcd = "spell",

        spend = function() return mana_cost( "multishot" ) end,
        spendType = "mana",

        startsCombat = true,
        texture = 132330,

        readyTime = function()
            if not settings.multishot_clip then return 0 end
            return wait_no_clip( cooldown.multishot.remains, 0.5 )
        end,

        copy = { 2643, 14288, 14289, 14290 },
    },

    -- Increases ranged attack speed by 40% for 15 sec.
    rapid_fire = {
        id = 3045,
        cast = 0,
        cooldown = 300,
        gcd = "off",

        spend = function() return mana_cost( "rapid_fire" ) end,
        spendType = "mana",

        toggle = "cooldowns",
        startsCombat = false,
        texture = 132208,

        handler = function()
            applyBuff( "rapid_fire" )
        end,
    },

    -- A strong attack on your next melee swing.
    raptor_strike = {
        id = 14266,
        cast = 0,
        cooldown = 6,
        gcd = "off",

        spend = function() return mana_cost( "raptor_strike" ) end,
        spendType = "mana",

        startsCombat = true,
        texture = 132223,

        nobuff = "raptor_strike_queued",
        usable = function() return target.within5, "requires melee range" end,

        handler = function()
            gain( mana_cost( "raptor_strike" ), "mana" ) -- paid when the swing lands
            start_raptor()
        end,

        copy = { 2973, 14260, 14261, 14262, 14263, 14264, 14265 },
    },

    revive_pet = {
        id = 982,
        cast = function() return 10 - 3 * talent.improved_revive_pet.rank end,
        cooldown = 0,
        gcd = "spell",

        spend = function() return mana_cost( "revive_pet" ) end,
        spendType = "mana",

        startsCombat = false,
        texture = 132163,

        handler = function()
            summonPet( "pet" )
        end,
    },

    scatter_shot = {
        id = 19503,
        cast = 0,
        cooldown = 30,
        gcd = "spell",

        spend = function() return mana_cost( "scatter_shot" ) end,
        spendType = "mana",

        talent = "scatter_shot",
        startsCombat = true,
        texture = 132153,

        handler = function()
            applyDebuff( "target", "scatter_shot" )
        end,
    },

    scorpid_sting = {
        id = 14277,
        cast = 0,
        cooldown = 0,
        gcd = "spell",

        spend = function() return mana_cost( "scorpid_sting" ) end,
        spendType = "mana",

        startsCombat = true,
        texture = 132169,

        handler = function()
            removeDebuff( "target", "sting" )
            applyDebuff( "target", "scorpid_sting" )
        end,

        copy = { 3043, 14275, 14276 },
    },

    -- Nature damage over 15 sec.  One sting per hunter per target.
    serpent_sting = {
        id = 25295,
        cast = 0,
        cooldown = 0,
        gcd = "spell",

        spend = function() return mana_cost( "serpent_sting" ) end,
        spendType = "mana",

        startsCombat = true,
        texture = 132204,

        handler = function()
            removeDebuff( "target", "sting" )
            applyDebuff( "target", "serpent_sting" )
        end,

        copy = { 1978, 13549, 13550, 13551, 13552, 13553, 13554, 13555 },
    },

    track_beasts = {
        id = 1494,
        cast = 0,
        cooldown = 0,
        gcd = "spell",

        startsCombat = false,
        texture = 132328,
    },

    tranquilizing_shot = {
        id = 19801,
        cast = 0,
        cooldown = 20,
        gcd = "spell",

        spend = function() return mana_cost( "tranquilizing_shot" ) end,
        spendType = "mana",

        startsCombat = true,
        texture = 136020,
    },

    trueshot_aura = {
        id = 20906,
        cast = 0,
        cooldown = 0,
        gcd = "spell",

        spend = function() return mana_cost( "trueshot_aura" ) end,
        spendType = "mana",

        talent = "trueshot_aura",
        startsCombat = false,
        texture = 132329,

        handler = function()
            applyBuff( "trueshot_aura" )
        end,

        copy = { 19506, 20905 },
    },

    viper_sting = {
        id = 14280,
        cast = 0,
        cooldown = 15,
        gcd = "spell",

        spend = function() return mana_cost( "viper_sting" ) end,
        spendType = "mana",

        startsCombat = true,
        texture = 132157,

        handler = function()
            removeDebuff( "target", "sting" )
            applyDebuff( "target", "viper_sting" )
        end,

        copy = { 3034, 14279 },
    },

    -- Arcane damage to enemies in the target area every second for 6 sec (channeled).
    volley = {
        id = 14295,
        cast = 6,
        channeled = true,
        cooldown = 60,
        gcd = "spell",

        spend = function() return mana_cost( "volley" ) end,
        spendType = "mana",

        startsCombat = true,
        texture = 132222,

        copy = { 1510, 14294 },
    },

    -- Melee attack that slows the target by 50% for 10 sec.
    wing_clip = {
        id = 14268,
        cast = 0,
        cooldown = 0,
        gcd = "spell",

        spend = function() return mana_cost( "wing_clip" ) end,
        spendType = "mana",

        startsCombat = true,
        texture = 132309,

        usable = function() return target.within5, "requires melee range" end,

        handler = function()
            applyDebuff( "target", "wing_clip" )
        end,

        copy = { 2974, 14267 },
    },

    wyvern_sting = {
        id = 24133,
        cast = 0,
        cooldown = 120,
        gcd = "spell",

        spend = function() return mana_cost( "wyvern_sting" ) end,
        spendType = "mana",

        talent = "wyvern_sting",
        startsCombat = true,
        texture = 135125,

        usable = function() return combat == 0, "only usable out of combat" end,

        handler = function()
            removeDebuff( "target", "sting" )
            applyDebuff( "target", "wyvern_sting" )
        end,

        copy = { 19386, 24132 },
    },
} )


-- Settings
spec:RegisterSetting( "hunter_description", nil, {
    type = "description",
    name = "Classic Era hunter priorities are built around Auto Shot: Aimed Shot and Multi-Shot are fit between shots, " ..
        "Arcane Shot is the mana-dependent filler, and the melee abilities are used only when the target is in melee range.  " ..
        "Use a swing timer addon (e.g. an Auto Shot bar) alongside Herakili for exact timing.\n\n",
    width = "full",
} )

spec:RegisterSetting( "rotation_header", nil, {
    type = "header",
    name = "Shot Rotation"
} )

spec:RegisterSetting( "aimed_shot_mode", "auto", {
    type = "select",
    name = "Aimed Shot",
    desc = "How Aimed Shot is fit around Auto Shot.\n\n" ..
        "|cFFFFD100Clipped|r: Aimed Shot whenever it is ready (best with fast weapons; the cast delays an Auto Shot).\n" ..
        "|cFFFFD100Full|r: Aimed Shot only right after an Auto Shot fires, so no shot is lost (best with slow weapons).\n" ..
        "|cFFFFD100Auto|r: Full when your ranged attack speed (as shown on the character sheet) is 2.55 sec or slower, otherwise Clipped.\n" ..
        "|cFFFFD100Never|r: Auto Shot + Multi-Shot only (e.g. to save mana).",
    values = { auto = "Auto (by weapon speed)", clipped = "Clipped (on cooldown)", full = "Full (after Auto Shot)", none = "Never (Auto Shot + Multi-Shot)" },
    sorting = { "auto", "clipped", "full", "none" },
    width = "full",
} )

spec:RegisterSetting( "multishot_clip", true, {
    type = "toggle",
    name = "Don't Clip Auto Shot With Multi-Shot",
    desc = "When enabled, Multi-Shot waits for the next Auto Shot if it would start in the last half second before the shot.",
    width = "full",
} )

spec:RegisterSetting( "multishot_st", true, {
    type = "toggle",
    name = "Multi-Shot on Single Target",
    desc = "When disabled, Multi-Shot is only recommended with 2 or more enemies (turn off near crowd-controlled targets).",
    width = "full",
} )

spec:RegisterSetting( "arcane_mana_pct", 40, {
    type = "range",
    name = "Arcane Shot Above Mana %",
    desc = "Arcane Shot is only recommended at or above this mana percentage (or while moving, when you can't cast Aimed Shot or Multi-Shot).  " ..
        "Set to 100 to keep it for movement only.",
    width = "full",
    min = 0,
    max = 100,
    step = 5,
} )

spec:RegisterSetting( "serpent_sting", "solo", {
    type = "select",
    name = "Serpent Sting",
    desc = "When to keep Serpent Sting on the target.  In raids it costs mana and debuff slots, so it is off by default there.",
    values = { always = "Always", solo = "Not in raids", never = "Never" },
    sorting = { "always", "solo", "never" },
    width = "full",
} )

spec:RegisterSetting( "hunters_mark", true, {
    type = "toggle",
    name = "Hunter's Mark",
    desc = "When enabled, Hunter's Mark is kept on targets that live long enough to benefit.",
    width = "full",
} )

spec:RegisterSetting( "volley_targets", 4, {
    type = "range",
    name = "Volley at Enemies",
    desc = "Volley is recommended with at least this many enemies.  Set to 0 to never recommend it.",
    width = "full",
    min = 0,
    max = 10,
    step = 1,
} )

spec:RegisterSetting( "melee_header", nil, {
    type = "header",
    name = "Melee and Pet"
} )

spec:RegisterSetting( "wing_clip", true, {
    type = "toggle",
    name = "Wing Clip in Melee",
    desc = "When enabled, Wing Clip is recommended when a non-boss target is in melee range and not slowed, so you can step back into range.",
    width = "full",
} )

spec:RegisterSetting( "pet_management", true, {
    type = "toggle",
    name = "Pet Management",
    desc = "When enabled, Call Pet and Revive Pet are recommended when you have no living pet.",
    width = "full",
} )

spec:RegisterSetting( "revive_in_combat", false, {
    type = "toggle",
    name = "Revive Pet in Combat",
    desc = "When enabled, Revive Pet (a long cast) may be recommended during combat; otherwise only out of combat.",
    width = "full",
} )

spec:RegisterSetting( "mend_pet_health", 40, {
    type = "range",
    name = "Mend Pet Below Pet Health %",
    desc = "Mend Pet is recommended when your pet's health is below this percentage.  Set to 0 to never recommend it.",
    width = "full",
    min = 0,
    max = 100,
    step = 5,
} )


spec:RegisterOptions( {
    enabled = true,

    aoe = 3,

    -- Track Beasts: known from level 1, on the GCD, no cooldown of its own.
    gcd = 1494,

    nameplates = false,
    nameplateRange = 8,

    -- Count enemies hit by your shots (Multi-Shot, Volley).
    damage = true,
    damageExpiration = 6,

    package = "Marksmanship",
    usePackSelector = true
} )


spec:RegisterPack( "Marksmanship", 20261027.1113, [[Hekili:nNv)VTTnt4)wslGxdwRJD6sBE7AcqB3ErBbs3W0q3VjjAPZwewsuGKkEgiq)TV7O(I6lhNMHT9lTYKhF4dpE3ZDS1DP7V76eY0G7xoFX5VA5IZF98Llx(sxh9(mW1jJfSLTb)iLLG)5nm5wvclvfXZOj3hlyHeekrUmanisRZuV5SZ2W1r5RMhisolcKST8yEZhUoRY5X6pL6UAI9wLbbUFb)ieubUoFiMPu8Gc)FwYk8T5qH)hZt1Ge5IuSMhJm4PpDCtk8FwxCwoF5fNw8zYEhd7vVPWFNyNEvW8nBk8BSEC02KZdbe0mjxi569pVWxfl2D2AMsJ4aSmrAH)74jqiUbrcCqnpHNU5u0YpfSVW)RapvzTpviByKuOzAoHWZcI5zzei3QMx4VopoUWpyFqmOiKIHnSG9Va5n5Sl8Fsn)czj4fxTPf(RKaBBOyx6tqm7qRirCiAW7Y1IYH(rCBKaUwLzE2AdGC9PZlj3ihkKj3KhR5VOCqdNlh(DYawkuBn6gz4GoGmdsXF7OlTQK1FNQ0BJd8vrCmGojwkUtzart8Zy0ACmj0EpOanHb6B(CXNzbKttnptcO3yft)9xDwalo2dr4581xH)LxchD3imJASeULFlyBEkaHkVYXhFnjqAO1kMZIrtNrFfbSyDKxwG(Tn0S2AVYjNTkF96MbNtxqJVlmkPq7jw7PJaVi2UT0(zw9WPoACsePBH99q6aRwlZbkQWJLlznlRZOZLqcdJSF7lxSyCqImxDkVe6QgXOX3ypXSqWGT9ygIn7entUb9v7qngE6LLXK)cgpbY30l4CTKYjKS0nagtjWtSChxHrpS(XGf(N1pwndt1MpHtK2ep6it8V9xE7yiBdhsXXarvsapLjhW4hkh4HacZq5gQCCRbZ0nRWkLPorP8NEXCL(5KMpfrBB0Jim8Bj47id56VgzE6WtscedabqhF0fD4xRNPDWhz4A1UH6KGhIEihUE5I73VhGAYwgDRrpSZ2xoKxj(QRxmJSgfVWeHeoOUEklNDsI4wBfqsdJeVBIN7IZYXwW9f8w5omtpPF4Yzu9G5O(41x11NCVjy3ZrOvUTEuKPJTQE5pT8PbHklOziL87QXOn3cVQOyowgp0BnxAhJ15w)87QgLR8wjuQ(iScdCa52kh6y(R7dGyHaPqUC)3kfYvGhxdjk68r6Q)kOrr1TaKrDaGcNuXT6YYsqzuqFwk25W)h4BW(v(jGPJqTwS08NsPMdcRAKb1EbSZcDKWiat1W3J9DHnlGX)NAl0chxzB4(lypR5wSYoEQxPmyFC(7ViEP)7gs0PQee6OUap0HNIE0BePBegpX7r)DttwyDPqrOPA1hegPeMwJ9GBBqgtkP2n)nwMMCZoAjFlcb5Krz1c)u4pXlf1UYwR(dt1TpetnVsD4P00DPixB5YnsJKxOIvERisny6GouAW0sdHWendFgmnXhpQZWojOnJwlz0mq3Q9nbSUo3I5jiYdE2WoMmLW01X1HesvMh3aRzOga(5xmp2bszRIHq3376usqxN(cWLR2R8jp4fQRg3Qjw7WIEiE47bajNrp0z66IeQV8OqTSo5e42G1pmbwDQuoaKH1rjSUOhwTlQBTZ2DPxf3oUqtaab7RM64wx2Lm61tyKDLvBgnA54c)zyM0eLKntouDSW)A8vHlioC53sKcQGsR9)nXAllcpkZ7wF2WJfgs2TsmoXvwp4P)Qq7pbFHLP8ere8OmotAQjAtMbBf6lgbZPYH60pq3dPDFb23lT9gCOlKlntwxxU0fuEjTCYCYM2f6Ca73eXiNUPYhh1JnApgJa6ujMwTEydB3J6uTHu4F3Dw7IM(xaPQd)7vQJK0S2qRQRhsPRTsB)fBxX9qQA1fi7T(5v9umZ8qFR6Tf(V1Yb0RMRX(H1DpKs4JtRUVM4JrREkHWhIwD1ZSnoj8P2)dkDEstYA1ZmpKK5dmzCiWtPN(quCgf4j1hNiXCCqMktZUMMUS4WbYlBF8WifBhuJ68YS)UDgDOC32xwCeWF5uOpvED7Zooc0NM8tL228MKkDo4Fxfota1KVR4)a6F66oUoGxQtJ(hYN0PL)dD4608)HUoB6VFuLOMzTLH6(KGEz0TrqMJoM3fjKUoFS()TbAu3)k]] )

spec:RegisterPack( "BeastMastery", 20261027.1113, [[Hekili:nNvBVTTnq4FlPfWlbR1XoDPnRRjaTDBOTaPByAO9BsIw6SfH1BGKkEgiq)23DuVr9QDAg22hARc5XN74X7EU7sTxA)N2w(mfy)5lwCXlxU4IxnF5YLVW2sTpfSTszEBzBWpIzr4F)oGjv3I)be7Pn3hMW8jiKjzcpuGaLkv(6ZpFdxfKTAUxs05bGGTLhYR)W2Avgpu9Xy7vJOBzk4z)z8dFq6zB9(qMuY9YD)fbl310gYD)qwm(bAlIK18q0cE6tlfj3TJq5UN2gPLZxE5z5FIoHL2(LVo3DxYo1kV5B2K7wlD153KXrl6z5UF0dr9lapwoGuIeftXtIr95fYttb)C37KZZDxNfgM76T3leKNHOecByE7FoQrYrvyipPcfFwe64Rep3DLayB9t2f)eej0GX3JCxzqIYuHmjDRfBLrSyzap9NiFHuXzOE)QGPcYD5OiH8yYOYsXRlNw8pyPCCHFLlG5f2XB5rKiwAfO4r84nOfFBwOI)8If13TILFRWJfdvsJ6MHlAbIuig)zlvHuf3SVR0eXf(ssyiGoswmQPuafna)eno03ZeqJhvckcd0h(P8pX8O7QCEQaqV2kM67V(CpwyOdIWZ4RVg)hNio(KGWmOWc4o(DGP4Xa4lDkwF4ZebX(gNyolefDg9vaWcvboPEQ3uBMvs7uS5SvzRxxV4C6rCyTWOaFLtYAhva4eW2TL0N(0936OXjkjElSVdstCALidOalhwMGvFSwRoxarmm6)nVyXIHbjq)0jDIONAeJAFJ5gZ8bn2MRPnSzNOyInOVIcp5Xxvet(By8eiEDNGZ1cm3XvWI3aymvcEJf74sm6H1ngm398UXQPyk58rCIKsCORmz)n)KZogAT(9nXHarwyaosDoG2puSWdbeM2KRnLJ7mzQe9jmszQsuk(rNqUu9mIxNIOnf6reg(Te8DKHCDpJilU)njccbGaOLp6Yw2xJNPzXhz4AP2qEsWbr3Nd3SCXH97E(stHUtZh2s9fl5uGV8MfZiPrYlmriIdYBgtYzNeLCNjdiXHrK31XZTXz5qh4qbVLUd92J6hUAgvpyoYpEZ1T9jhmb7axHg62QvrlDOt1j)PXEQrOucAhIj)(kmAYTWNkePvfftD2r1sBxl40bJbUVCvU0zvIuEwxafuHxN1yDxJG2wqCrhi6Bsc8zzB5l0qpahcGWKe0eYe7)wnHmj4WvqKKCyer9VdkKLElaydgCKLv7HQQZlaPMs(04eSJdGVb7B5NbDVjjyT(pgtDB4x2qdsMdytmQGenJo1uWESvnS7dmH6mtMB446daoChaZQdlkLJh7uWR2fN)57kOW)DlXIvwtdDuxIxA)Zqp6TjXBs0EI3H(B0FSw3EewOZpXxx(79jAUjMsHnUBkqktGpW6o9uKB2sj4BriiNmYtN7gd)f(Oi3v0R2x1LlFp2IhUn(oHnsJFLKPmC5AUwYluAvoRiJQ32ETmPEBl0geM5QTNEBt2Jd1QzRm(6vR4GQxOD7d1bS2w3H5jiY9M1yhtetyABzBrmZs9erWAgsQGF(z9esqmBvi4B)oBRcd02QlJEXPDkMtcFqTvOQg5S9RII4jqVNGZOPJgVqlH6lokulk8ocU1y9dJGvRsV9aPFHzcRl7GvZHAxmUrlDkH3YfQdaiyF5yx3Q64KqVAeHmlvBArdwFp3DgMjnsnE9M9zhZDVbhKCbzdx9TePGmO0z)XroBrv9bT82f812XcTr2U0oUX1gtq19uO8NGJSPR3rgcEvg2sQlYAAm9uf6lgaZXYHA1Gr7lPzJgMVlnnBm1dYv6nRk0x4ckEKwoAozD)hTUGD7kzGB3y5Jd6XgSPLbaDSetJEzmHT9vDS(AYDV)EdTOOFTjLJmCqQoIsZqHgvxNIPRPsB3dBwXDkwTQcKDo)8YEkMP)nhyuVn39ngoGo1C1Y3VU7umHpoU6UCIpgU6XicFiC1LZTRDs4S7)lsDEsDYA5CRtrz(atg7d8y8PpegNbbEu(XrsmhgKXY0mRPPkkomrEzRPrgp)40jQBvWi0PBj3ZMmLUEKLbkX3tdxmKgMkFVzEMJa(Rgd9XYMBg25iqFCJFS066jHkzxH)B5v1p)JonZ)dyDvv95nHxQ14ft5tAnOXuxUwJCmv0s9ufdY)vVRj5x7br6WJ0ebPV6y2EqIW26dv)hJqRA)3]] )

spec:RegisterPack( "Survival", 20261027.1113, [[Hekili:nNv)VTTnt4)wslGxdwRJD6sBEZAcqB3ErBbA3W0q3VjjAjAlcljkqsfpdeO)23DK6dQpOJtZW2(LwzY7E4DhV75o26V0)399IjkQ)xoFX5VA5IZF98Llx(sFp1(cQVxbjAlzd8rojd(tVsXTSBjP4g7t5KyuDjVuebBMOufYRo7Snmvs5Q5r8SZsOcYwwkR9dFVvLSu1hZ9x54CLf0i)VaFetLr(EVpLiLSOQWFwqQcBo)QWpuMROcWoe81Su40F6thVDv4Z6R)Y5lV40QpPLvB1YRQc3X3PwfnFZMQWwPB0FtjdSJNxf(XO9vHFLYYLtiLGRikgphoVOuwrbnUk8w58QW1LPGXeTpkLkpfqjLUHeT)fWjIHhJH8KguIjzqOUr8QWvckzBmFx(taKadgUbQcLjCv3b(JD(83bAKrtPGmkopvI(oxJmrPGBr40)mpFdNlbjEhtrpfKh2cp5mUawKLxJWCJH9wwg6iE6tuXYy5BqqktvSxywu7SMLFRiIKtBKoJKtGf9OIcAo8BpLrkJRIM6Njc0K(kpnLcrwsoCsfuq0e4ZuqAyn0OAcosQcXacQFQ6tKi05LZleuimUIO((RplIKMgai8C26RH)kiJb3ramtkSGcXmQT45uASmWS(06KrZJT0yojfeDg(vcLKQsckIuVP1mBKoWS5SvLRx3U4C8wD6tHG5)Qa(6avcniHSBlEEAThV1rJtgpFlD)aKoG2krjfZ0ciLcsRA9wDUGMrGYH38YflMgKe9vNmidVQbmAJn2BmlMQX2EnTHn7efrSbIv7a6ew(LMCYFbYNOIRgKCUwaftHcs(gkKtXbpwSJH55KH5GvHNnmxTaQrN7iiIhsa6YO939RGDeWAJhBItbI0yabsDnGooyw4HacrBYTMYXPtPIR1WQKPPqX8ZGuMu9CKAhZOTf6rKg(TK8DKPCd1ruMp2t0uyia9Irx0Z(6ImDl(itxRpnGNKgaOhZO3SCX9h3JIL2cDRMpS3XBwkWGV8MfZqPbYlOqiJrL34sYzNKXV1Mbe5WqY7285(4SCkfUVK36WHEBNXHlNH9dMd8J3CD)yY9wGDpUqhDBZQGLoLwdQF6SNweQLa3bzYVRbJUAl4QcZ5ifS4G1mHDowVB9ZVREvMmyfxkhIWkiXHk2whqNkEDFaKY5Gjuk2)TAcLsAamcqMe9pKx9xPkGuDlLwaZbaKI6MBnTLfuPMb9z58QW)pLTbgu4NOevcW1cTM)yooCqC9eqa3lfglrLOh0q3dFpmQfmSaK)FQnrl94ABtV)g2ZAVfRLJLhyObhIZF)nXnXVpBM8s3cccuxaoD8PxnCKliESwpnd0xkMhR7w1BinBbkic4cUk83ifkmm7PeSTaeyqgOvRcZP)jCPi3zgT6p0D3EpmrgoaiSUcVl5LkRqUMAeJc1wvWk0OgTDuptA02cTbbfAA7z02O9eGtg2RaTD1gkJ2f63TVnH137wOobqE0le2re5iM(E(EirQu)gg6AcWbaF(f9BAO5KvP0y)357zmqFVHeWgTdmVSbUq9vWr5q3Xn9a8eq0tWi4BAC3xer9LhfQM(KoWTfRFWbw96uocKX9rrSUyawDk1V3z3PmOJBVqOobaH9vUC3M2UOqV2Hq2DwTTOjBhxfodQKC0swV5y2XQWBGhcUaTHl)wYuaguu3)NdDnnHN0Y73FwBhl0gz)oXWgxB9GNHAbYFc(KnS9eAiGRmTL02t02ygDuqSycmDvd1BEG(oP9Cb23lDZgCOlKl1B20x2ecmxslDwt2oUqphC4qet4DUQhNmIn5mgtaQRctRrpSHTVR6AmKQW7UZ6uu4)Gh1t4FVuDiLM1bA1D9qmDDDAhQSDh3dXQ10GCG(ZRNPyM(H(w9BRcFJvayqpxT8J77EiMWhhx9qoXhdxTlIWhcxD9ZS1bj4P2)dsDEsBXA9ZmpeL5dSyCmWU4tFimotcSt(rhfMtdIRkn7EAktZHdux294HjA2oQh15MQ)(tgDOA3UxwCeWFPl0Dvx39SJJaD3gVRY223KuZZr)3LHtNq58Df)hG)t1mX1bIs9g0)qXKEJ8FiNR3W)h66SD((jzIA31MgQ)tcgur3LbPDDOUlHl89(qZ)Xc4Q()1p]] )

spec:RegisterPackSelector( "beast_mastery", "BeastMastery", "|T132164:0|t Beast Mastery",
    "If you have spent more points in |T132164:0|t Beast Mastery than in any other tree, this priority will be automatically selected for you.",
    function( tab1, tab2, tab3 )
        return tab1 > max( tab2, tab3 )
    end )

spec:RegisterPackSelector( "marksmanship", "Marksmanship", "|T132222:0|t Marksmanship",
    "If you have spent more points in |T132222:0|t Marksmanship than in any other tree, this priority will be automatically selected for you.",
    function( tab1, tab2, tab3 )
        return tab2 > max( tab1, tab3 )
    end )

spec:RegisterPackSelector( "survival", "Survival", "|T132215:0|t Survival",
    "If you have spent more points in |T132215:0|t Survival than in any other tree, this priority will be automatically selected for you.",
    function( tab1, tab2, tab3 )
        return tab3 > max( tab1, tab2 )
    end )
