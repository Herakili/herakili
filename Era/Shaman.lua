-- Era/Shaman.lua
-- Classic Era (1.15.x) Shaman.  Spell, rank, talent, enchant and cost data from the Classic Era client tables (1.15.9).

if UnitClassBase( 'player' ) ~= 'SHAMAN' then return end

local addon, ns = ...
local Hekili = _G[ addon ]
local class, state = Hekili.Class, Hekili.State

local GetTotemInfo = _G.GetTotemInfo
local GetWeaponEnchantInfo = _G.GetWeaponEnchantInfo
local GetSpellPowerCost = _G.GetSpellPowerCost or ( C_Spell and C_Spell.GetSpellPowerCost )

local spec = Hekili:NewSpecialization( 7 )

spec:RegisterResource( Enum.PowerType.Mana )


-- Talents: { talentID, maxRank, rank1SpellID, ... rankNSpellID }, from the Classic Era client's Talent table.
-- Tree order (talent frame / GetTalentTabInfo): 1 Elemental, 2 Enhancement, 3 Restoration.
spec:RegisterTalents( {
    -- Elemental
    convection                = {   564, 5, 16039, 16109, 16110, 16111, 16112 },
    concussion                = {   563, 5, 16035, 16105, 16106, 16107, 16108 },
    earth_s_grasp             = {   572, 2, 16043, 16130 },
    elemental_warding         = {  1640, 3, 28996, 28997, 28998 },
    call_of_flame             = {   561, 3, 16038, 16160, 16161 },
    elemental_focus           = {   574, 1, 16164 },
    reverberation             = {   575, 5, 16040, 16113, 16114, 16115, 16116 },
    call_of_thunder           = {   562, 5, 16041, 16117, 16118, 16119, 16120 },
    improved_fire_totems      = {   567, 2, 16086, 16544 },
    eye_of_the_storm          = {  1642, 3, 29062, 29064, 29065 },
    elemental_devastation     = {  1645, 3, 30160, 29179, 29180 },
    storm_reach               = {  1641, 2, 28999, 29000 },
    elemental_fury            = {   565, 1, 16089 },
    lightning_mastery         = {   721, 5, 16578, 16579, 16580, 16581, 16582 },
    elemental_mastery         = {   573, 1, 16166 },

    -- Enhancement
    ancestral_knowledge       = {   614, 5, 17485, 17486, 17487, 17488, 17489 },
    shield_specialization     = {   612, 5, 16253, 16298, 16299, 16300, 16301 },
    guardian_totems           = {   609, 2, 16258, 16293 },
    thundering_strikes        = {   613, 5, 16255, 16302, 16303, 16304, 16305 },
    improved_ghost_wolf       = {   605, 2, 16262, 16287 },
    improved_lightning_shield = {   607, 3, 16261, 16290, 16291 },
    enhancing_totems          = {   610, 2, 16259, 16295 },
    two_handed_axes_and_maces = {   617, 1, 16269 },
    anticipation              = {   601, 5, 16254, 16271, 16272, 16273, 16274 },
    flurry                    = {   602, 5, 16256, 16281, 16282, 16283, 16284 },
    toughness                 = {   615, 5, 16252, 16306, 16307, 16308, 16309 },
    improved_weapon_totems    = {  1647, 2, 29192, 29193 },
    elemental_weapons         = {   611, 3, 16266, 29079, 29080 },
    parry                     = {   616, 1, 16268 },
    weapon_mastery            = {  1643, 5, 29082, 29084, 29086, 29087, 29088 },
    stormstrike               = {   901, 1, 17364 },

    -- Restoration
    improved_healing_wave     = {   586, 5, 16182, 16226, 16227, 16228, 16229 },
    tidal_focus               = {   593, 5, 16179, 16214, 16215, 16216, 16217 },
    improved_reincarnation    = {   589, 2, 16184, 16209 },
    ancestral_healing         = {   581, 3, 16176, 16235, 16240 },
    totemic_focus             = {   595, 5, 16173, 16222, 16223, 16224, 16225 },
    nature_s_guidance         = {   583, 3, 16180, 16196, 16198 },
    healing_focus             = {   587, 5, 16181, 16230, 16232, 16233, 16234 },
    totemic_mastery           = {   582, 1, 16189 },
    healing_grace             = {  1646, 3, 29187, 29189, 29191 },
    restorative_totems        = {   588, 5, 16187, 16205, 16206, 16207, 16208 },
    tidal_mastery             = {   594, 5, 16194, 16218, 16219, 16220, 16221 },
    healing_way               = {  1648, 3, 29206, 29205, 29202 },
    nature_s_swiftness        = {   591, 1, 16188 },
    purification              = {   592, 5, 16178, 16210, 16211, 16212, 16213 },
    mana_tide_totem           = {   590, 1, 16190 },
} )


-- Rank data, keyed by spell ID (Classic Era SpellPower / SpellCastTimes / SpellDuration tables).
-- Mana costs: fallback only when the client reports no cost (see mana_cost).
local MANA = {
    -- Lightning Bolt
    [403] = 15, [529] = 30, [548] = 45, [915] = 75, [943] = 105, [6041] = 135, [10391] = 165, [10392] = 195, [15207] = 230, [15208] = 265,
    -- Chain Lightning
    [421] = 280, [930] = 380, [2860] = 490, [10605] = 605,
    -- Earth Shock
    [8042] = 30, [8044] = 50, [8045] = 85, [8046] = 145, [10412] = 240, [10413] = 345, [10414] = 450,
    -- Flame Shock
    [8050] = 55, [8052] = 95, [8053] = 160, [10447] = 250, [10448] = 345, [29228] = 410,
    -- Frost Shock
    [8056] = 115, [8058] = 225, [10472] = 325, [10473] = 430,
    -- Lightning Shield
    [324] = 45, [325] = 80, [905] = 125, [945] = 180, [8134] = 240, [10431] = 305, [10432] = 370,
    -- Rockbiter / Flametongue / Frostbrand / Windfury Weapon
    [8017] = 15, [8018] = 25, [8019] = 50, [10399] = 75, [16314] = 100, [16315] = 125, [16316] = 150,
    [8024] = 30, [8027] = 55, [8030] = 80, [16339] = 105, [16341] = 130, [16342] = 155,
    [8033] = 60, [8038] = 85, [10456] = 110, [16355] = 135, [16356] = 160,
    [8232] = 90, [8235] = 115, [10486] = 140, [16362] = 165,
    -- Fire totems
    [3599] = 25, [6363] = 45, [6364] = 75, [6365] = 110, [10437] = 145, [10438] = 170,          -- Searing
    [1535] = 95, [8498] = 170, [8499] = 280, [11314] = 395, [11315] = 520,                       -- Fire Nova
    [8190] = 230, [10585] = 360, [10586] = 500, [10587] = 650,                                   -- Magma
    [8227] = 90, [8249] = 140, [10526] = 200, [16387] = 275,                                     -- Flametongue
    [8181] = 75, [10478] = 120, [10479] = 180,                                                   -- Frost Resistance
    -- Earth totems
    [8075] = 25, [8160] = 65, [8161] = 125, [10442] = 225, [25361] = 275,                        -- Strength of Earth
    [8071] = 30, [8154] = 60, [8155] = 90, [10406] = 115, [10407] = 160, [10408] = 210,          -- Stoneskin
    [8143] = 60,                                                                                 -- Tremor
    [5730] = 15, [6390] = 30, [6391] = 55, [6392] = 75, [10427] = 105, [10428] = 140,            -- Stoneclaw
    -- Water totems
    [5675] = 40, [10495] = 60, [10496] = 80, [10497] = 100,                                      -- Mana Spring
    [5394] = 40, [6375] = 50, [6377] = 60, [10462] = 70, [10463] = 80,                           -- Healing Stream
    [8184] = 75, [10537] = 120, [10538] = 180,                                                   -- Fire Resistance
    [16190] = 20, [17354] = 40, [17359] = 60,                                                    -- Mana Tide
    -- Air totems
    [8835] = 155, [10627] = 250, [25359] = 310,                                                  -- Grace of Air
    [8512] = 115, [10613] = 175, [10614] = 250,                                                  -- Windfury
    [10595] = 75, [10600] = 120, [10601] = 180,                                                  -- Nature Resistance
    [15107] = 115, [15111] = 170, [15112] = 225,                                                 -- Windwall
    [6495] = 65,                                                                                 -- Sentry
    -- Ghost Wolf
    [2645] = 100,
}

-- Costs given as a fraction of base mana.
local MANA_PCT = {
    [17364] = 0.21,                         -- Stormstrike
    [2484] = 0.06, [8177] = 0.06,           -- Earthbind, Grounding Totem
    [25908] = 0.08,                         -- Tranquil Air Totem
    [8166] = 0.10, [8170] = 0.10,           -- Poison / Disease Cleansing Totem
    [370] = 0.10, [8012] = 0.10,            -- Purge
}

-- Lightning Bolt cast time by rank (ranks 4+ are 3 sec).
local LB_CAST = { [403] = 1.5, [529] = 2, [548] = 2.5 }

-- Searing Totem duration by rank.
local SEARING_DURATION = { [3599] = 30, [6363] = 35, [6364] = 40, [6365] = 45, [10437] = 50, [10438] = 55 }

-- Temporary weapon enchant IDs (GetWeaponEnchantInfo) of each imbue rank, from the imbue spells' enchant effects.
local IMBUE_ENCHANTS = {
    [29] = "rockbiter", [6] = "rockbiter", [1] = "rockbiter", [503] = "rockbiter", [1663] = "rockbiter", [683] = "rockbiter", [1664] = "rockbiter",
    [5] = "flametongue", [4] = "flametongue", [3] = "flametongue", [523] = "flametongue", [1665] = "flametongue", [1666] = "flametongue",
    [2] = "frostbrand", [12] = "frostbrand", [524] = "frostbrand", [1667] = "frostbrand", [1668] = "frostbrand",
    [283] = "windfury", [284] = "windfury", [525] = "windfury", [1669] = "windfury",
}

local IMBUE_DURATION = 300


local function known_id( key )
    local ability = class.abilities[ key ]
    return ability and ability.id
end

-- Mana costs: the live client's cost for the rank you know (talents such as Convection and Totemic Focus included),
-- refreshed every 10 seconds.  The per-rank tables above (Era SpellPower table) are only a fallback.
local cost_cache = {}

local function live_cost( id )
    local now = GetTime()
    local c = cost_cache[ id ]

    if not c or now - c.t > 10 then
        local value
        if GetSpellPowerCost then
            local ok, costs = pcall( GetSpellPowerCost, id )
            if ok and type( costs ) == "table" then
                for _, p in ipairs( costs ) do
                    if type( p ) == "table" and p.type == 0 and type( p.cost ) == "number" then
                        value = p.cost
                        break
                    end
                end
            end
        end
        c = { t = now, v = value }
        cost_cache[ id ] = c
    end

    return c.v
end

-- reduction: talent multiplier applied to the fallback table only (the live cost already includes it).
local function mana_cost( key, reduction )
    local id = known_id( key )
    if not id then return 0 end

    local v = live_cost( id )
    if v then return v end

    if MANA[ id ] then return MANA[ id ] * ( reduction or 1 ) end
    return MANA_PCT[ id ] or 0
end

-- Shocks and Lightning Bolt / Chain Lightning: Convection; free with Clearcasting (Elemental Focus) or Elemental Mastery.
local function damage_spell_cost( key )
    if state.buff.clearcasting.up or state.buff.elemental_mastery.up then return 0 end
    return mana_cost( key, 1 - 0.02 * state.talent.convection.rank )
end

-- Totems: Totemic Focus reduces their cost by 5% per rank.
local function totem_cost( key )
    return mana_cost( key, 1 - 0.05 * state.talent.totemic_focus.rank )
end

local function plain_cost( key )
    return mana_cost( key )
end

-- Totems by element; GetTotemInfo slots: 1 fire, 2 earth, 3 water, 4 air.
local TOTEMS = {
    fire  = { slot = 1, "searing_totem", "fire_nova_totem", "magma_totem", "flametongue_totem", "frost_resistance_totem" },
    earth = { slot = 2, "strength_of_earth_totem", "stoneskin_totem", "tremor_totem", "earthbind_totem", "stoneclaw_totem" },
    water = { slot = 3, "mana_spring_totem", "healing_stream_totem", "fire_resistance_totem", "poison_cleansing_totem", "disease_cleansing_totem", "mana_tide_totem" },
    air   = { slot = 4, "windfury_totem", "grace_of_air_totem", "tranquil_air_totem", "nature_resistance_totem", "windwall_totem", "grounding_totem", "sentry_totem" },
}

-- Rank 1 spell of each totem: its (localized) name identifies the totem in GetTotemInfo, which reports e.g. "Searing Totem III".
local TOTEM_SPELL = {
    searing_totem = 3599, fire_nova_totem = 1535, magma_totem = 8190, flametongue_totem = 8227, frost_resistance_totem = 8181,
    strength_of_earth_totem = 8075, stoneskin_totem = 8071, tremor_totem = 8143, earthbind_totem = 2484, stoneclaw_totem = 5730,
    mana_spring_totem = 5675, healing_stream_totem = 5394, fire_resistance_totem = 8184, poison_cleansing_totem = 8166,
    disease_cleansing_totem = 8170, mana_tide_totem = 16190,
    windfury_totem = 8512, grace_of_air_totem = 8835, tranquil_air_totem = 25908, nature_resistance_totem = 10595,
    windwall_totem = 15107, grounding_totem = 8177, sentry_totem = 6495,
}

local TOTEM_DURATION = {
    searing_totem = function() return SEARING_DURATION[ known_id( "searing_totem" ) ] or 55 end,
    fire_nova_totem = function() return 5 - state.talent.improved_fire_totems.rank end,   -- fuse: it explodes and is gone
    magma_totem = 20, flametongue_totem = 120, frost_resistance_totem = 120,
    strength_of_earth_totem = 120, stoneskin_totem = 120, tremor_totem = 120, earthbind_totem = 45, stoneclaw_totem = 15,
    mana_spring_totem = 60, healing_stream_totem = 60, fire_resistance_totem = 120, poison_cleansing_totem = 120,
    disease_cleansing_totem = 120, mana_tide_totem = 12,   -- 12 sec (4 ticks)
    windfury_totem = 120, grace_of_air_totem = 120, tranquil_air_totem = 120, nature_resistance_totem = 120,
    windwall_totem = 120, grounding_totem = 45, sentry_totem = 300,
}

local TOTEM_ELEMENT = {}
for element, list in pairs( TOTEMS ) do
    for _, key in ipairs( list ) do TOTEM_ELEMENT[ key ] = element end
end

local function totem_generator( key )
    local slot = TOTEMS[ TOTEM_ELEMENT[ key ] ].slot
    local spellID = TOTEM_SPELL[ key ]
    local name

    return function( t )
        name = name or ( GetSpellInfo( spellID ) )
        local up, totemName, start, duration = GetTotemInfo( slot )

        if up and name and totemName and start and duration and duration > 0 and totemName:sub( 1, #name ) == name then
            t.count = 1
            t.applied = start
            t.expires = start + duration
            t.caster = "player"
            return
        end

        t.count = 0
        t.applied = 0
        t.expires = 0
        t.caster = "nobody"
    end
end


-- Main-hand weapon imbue (pseudo-auras from GetWeaponEnchantInfo).
local function imbue_generator( kind )
    return function( t )
        local hasMH, mhExpires, _, mhEnchant = GetWeaponEnchantInfo()

        if hasMH and mhExpires and ( kind == "any" or IMBUE_ENCHANTS[ mhEnchant ] == kind ) then
            local now = GetTime()
            t.count = 1
            t.expires = now + mhExpires / 1000
            t.applied = min( now, t.expires - IMBUE_DURATION )
            t.caster = "player"
            return
        end

        t.count = 0
        t.applied = 0
        t.expires = 0
        t.caster = "nobody"
    end
end


local function totem_aura( key )
    return { duration = TOTEM_DURATION[ key ], max_stack = 1, generate = totem_generator( key ) }
end


-- Auras
spec:RegisterAuras( {
    -- Next damage spell costs no mana (Elemental Focus).
    clearcasting = {
        id = 16246,
        duration = 15,
        max_stack = 1,
    },
    earth_shock = {
        id = 10414,
        duration = 2,
        max_stack = 1,
        copy = { 8042, 8044, 8045, 8046, 10412, 10413 },
    },
    elemental_devastation = {
        id = 30165,
        duration = 10,
        max_stack = 1,
        copy = { 29177, 29178 },
    },
    -- Next Fire, Frost or Nature damage spell is a critical strike and costs no mana.
    elemental_mastery = {
        id = 16166,
        duration = 3600,
        max_stack = 1,
    },
    flame_shock = {
        id = 29228,
        duration = 12,
        tick_time = 3,
        max_stack = 1,
        copy = { 8050, 8052, 8053, 10447, 10448 },
    },
    flurry = {
        id = 16280,
        duration = 15,
        max_stack = 3,
        copy = { 16257, 16277, 16278, 16279 },
    },
    frost_shock = {
        id = 10473,
        duration = 8,
        max_stack = 1,
        copy = { 8056, 8058, 10472 },
    },
    ghost_wolf = {
        id = 2645,
        duration = 3600,
        max_stack = 1,
    },
    lightning_shield = {
        id = 10432,
        duration = 600,
        max_stack = 3,
        copy = { 324, 325, 905, 945, 8134, 10431 },
    },
    -- Next Nature spell with a cast time under 10 sec is instant.
    natures_swiftness = {
        id = 16188,
        duration = 3600,
        max_stack = 1,
    },
    -- Next 2 sources of Nature damage on the target are increased by 20%.
    stormstrike = {
        id = 17364,
        duration = 12,
        max_stack = 2,
    },

    -- Main-hand imbues.
    mh_rockbiter = { duration = IMBUE_DURATION, max_stack = 1, generate = imbue_generator( "rockbiter" ) },
    mh_flametongue = { duration = IMBUE_DURATION, max_stack = 1, generate = imbue_generator( "flametongue" ) },
    mh_frostbrand = { duration = IMBUE_DURATION, max_stack = 1, generate = imbue_generator( "frostbrand" ) },
    mh_windfury = { duration = IMBUE_DURATION, max_stack = 1, generate = imbue_generator( "windfury" ) },
    -- Any temporary main-hand enchant (imbues, oils, sharpening stones).
    mh_temporary_enchant = { duration = IMBUE_DURATION, max_stack = 1, generate = imbue_generator( "any" ) },

    -- Totem element aliases.
    fire_totem = {
        alias = TOTEMS.fire,
        aliasMode = "first",
        aliasType = "buff",
    },
    earth_totem = {
        alias = TOTEMS.earth,
        aliasMode = "first",
        aliasType = "buff",
    },
    water_totem = {
        alias = TOTEMS.water,
        aliasMode = "first",
        aliasType = "buff",
    },
    air_totem = {
        alias = TOTEMS.air,
        aliasMode = "first",
        aliasType = "buff",
    },

    -- Totems (GetTotemInfo).
    searing_totem = totem_aura( "searing_totem" ),
    fire_nova_totem = totem_aura( "fire_nova_totem" ),
    magma_totem = totem_aura( "magma_totem" ),
    flametongue_totem = totem_aura( "flametongue_totem" ),
    frost_resistance_totem = totem_aura( "frost_resistance_totem" ),
    strength_of_earth_totem = totem_aura( "strength_of_earth_totem" ),
    stoneskin_totem = totem_aura( "stoneskin_totem" ),
    tremor_totem = totem_aura( "tremor_totem" ),
    earthbind_totem = totem_aura( "earthbind_totem" ),
    stoneclaw_totem = totem_aura( "stoneclaw_totem" ),
    mana_spring_totem = totem_aura( "mana_spring_totem" ),
    healing_stream_totem = totem_aura( "healing_stream_totem" ),
    fire_resistance_totem = totem_aura( "fire_resistance_totem" ),
    poison_cleansing_totem = totem_aura( "poison_cleansing_totem" ),
    disease_cleansing_totem = totem_aura( "disease_cleansing_totem" ),
    mana_tide_totem = totem_aura( "mana_tide_totem" ),
    windfury_totem = totem_aura( "windfury_totem" ),
    grace_of_air_totem = totem_aura( "grace_of_air_totem" ),
    tranquil_air_totem = totem_aura( "tranquil_air_totem" ),
    nature_resistance_totem = totem_aura( "nature_resistance_totem" ),
    windwall_totem = totem_aura( "windwall_totem" ),
    grounding_totem = totem_aura( "grounding_totem" ),
    sentry_totem = totem_aura( "sentry_totem" ),
} )


-- Totems and imbues the settings ask for.  Each setting holds an ability key (or "none"); the priorities read
-- e.g. enh_use_windfury_totem / ele_use_mana_spring_totem.
local TOTEM_SETTINGS = { "totem_fire", "totem_earth", "totem_water", "totem_air" }

for _, prefix in ipairs( { "enh", "ele" } ) do
    for key in pairs( TOTEM_DURATION ) do
        spec:RegisterStateExpr( prefix .. "_use_" .. key, function()
            for _, s in ipairs( TOTEM_SETTINGS ) do
                if settings[ prefix .. "_" .. s ] == key then return true end
            end
            return false
        end )
    end
end

-- Imbue choice: "auto" picks the best main-hand imbue you know (Windfury > Flametongue > Rockbiter).
local function imbue_choice( prefix )
    local choice = state.settings[ prefix .. "_imbue" ] or "none"
    if choice ~= "auto" then return choice end

    for _, key in ipairs( { "windfury_weapon", "flametongue_weapon", "rockbiter_weapon" } ) do
        local ability = class.abilities[ key ]
        if ability and state.action[ key ].known then return key end
    end
    return "none"
end

for _, prefix in ipairs( { "enh", "ele" } ) do
    for _, key in ipairs( { "rockbiter_weapon", "flametongue_weapon", "frostbrand_weapon", "windfury_weapon" } ) do
        spec:RegisterStateExpr( prefix .. "_use_" .. key, function()
            return imbue_choice( prefix ) == key
        end )
    end
end

-- Enhancement shock choice.
for _, key in ipairs( { "earth_shock", "frost_shock", "flame_shock" } ) do
    spec:RegisterStateExpr( "enh_use_" .. key, function()
        return settings.enh_shock == key
    end )
end

-- A main-hand weapon is equipped (imbues need one).
spec:RegisterStateExpr( "mainhand_equipped", function()
    return GetInventoryItemID( "player", 16 ) ~= nil
end )


spec:RegisterStateFunction( "place_totem", function( key )
    local element = TOTEM_ELEMENT[ key ]
    for _, k in ipairs( TOTEMS[ element ] ) do
        removeBuff( k )
    end
    applyBuff( key )
end )

spec:RegisterStateFunction( "apply_imbue", function( key )
    removeBuff( "mh_rockbiter" )
    removeBuff( "mh_flametongue" )
    removeBuff( "mh_frostbrand" )
    removeBuff( "mh_windfury" )
    applyBuff( key, IMBUE_DURATION )
    applyBuff( "mh_temporary_enchant", IMBUE_DURATION )
end )

spec:RegisterStateFunction( "consume_damage_spell", function()
    removeBuff( "clearcasting" )
    removeBuff( "elemental_mastery" )
end )


local function totem( key, id, copy, extra )
    local a = {
        id = id,
        cast = 0,
        cooldown = 0,
        gcd = "spell",

        spend = function() return totem_cost( key ) end,
        spendType = "mana",

        startsCombat = false,
        totem = TOTEM_ELEMENT[ key ],

        handler = function()
            place_totem( key )
        end,

        copy = copy,
    }
    if extra then
        for k, v in pairs( extra ) do a[ k ] = v end
    end
    return a
end

local function imbue( key, aura, id, copy )
    return {
        id = id,
        cast = 0,
        cooldown = 0,
        gcd = "spell",

        spend = function() return plain_cost( key ) end,
        spendType = "mana",

        startsCombat = false,

        usable = function() return mainhand_equipped, "requires a main-hand weapon" end,

        handler = function()
            apply_imbue( aura )
        end,

        copy = copy,
    }
end


-- Abilities
spec:RegisterAbilities( {
    -- Hurls a bolt of lightning at an enemy.
    lightning_bolt = {
        id = 15208,
        cast = function()
            if buff.natures_swiftness.up then return 0 end
            return ( ( LB_CAST[ known_id( "lightning_bolt" ) ] or 3 ) - 0.2 * talent.lightning_mastery.rank ) * haste
        end,
        cooldown = 0,
        gcd = "spell",

        spend = function() return damage_spell_cost( "lightning_bolt" ) end,
        spendType = "mana",

        startsCombat = true,
        texture = 136048,

        handler = function()
            consume_damage_spell()
            removeBuff( "natures_swiftness" )
            removeDebuffStack( "target", "stormstrike" )
        end,

        copy = { 403, 529, 548, 915, 943, 6041, 10391, 10392, 15207 }
    },

    -- Lightning that jumps to up to 2 additional targets.
    chain_lightning = {
        id = 10605,
        cast = function()
            if buff.natures_swiftness.up then return 0 end
            return ( 2.5 - 0.2 * talent.lightning_mastery.rank ) * haste
        end,
        cooldown = 6,
        gcd = "spell",

        spend = function() return damage_spell_cost( "chain_lightning" ) end,
        spendType = "mana",

        startsCombat = true,
        texture = 136015,

        handler = function()
            consume_damage_spell()
            removeBuff( "natures_swiftness" )
            removeDebuffStack( "target", "stormstrike" )
        end,

        copy = { 421, 930, 2860 }
    },

    -- Instantly shocks the target with concussive force, interrupting spellcasting.
    earth_shock = {
        id = 10414,
        cast = 0,
        cooldown = 6,
        gcd = "spell",

        spend = function() return damage_spell_cost( "earth_shock" ) end,
        spendType = "mana",

        startsCombat = true,
        texture = 136026,

        handler = function()
            consume_damage_spell()
            applyDebuff( "target", "earth_shock" )
            removeDebuffStack( "target", "stormstrike" )
            setCooldown( "flame_shock", 6 )
            setCooldown( "frost_shock", 6 )
        end,

        copy = { 8042, 8044, 8045, 8046, 10412, 10413 }
    },

    -- Instantly sears the target with fire, plus additional damage over 12 sec.
    flame_shock = {
        id = 29228,
        cast = 0,
        cooldown = 6,
        gcd = "spell",

        spend = function() return damage_spell_cost( "flame_shock" ) end,
        spendType = "mana",

        startsCombat = true,
        texture = 135813,

        handler = function()
            consume_damage_spell()
            applyDebuff( "target", "flame_shock" )
            setCooldown( "earth_shock", 6 )
            setCooldown( "frost_shock", 6 )
        end,

        copy = { 8050, 8052, 8053, 10447, 10448 }
    },

    -- Instantly shocks the target with frost, slowing its movement for 8 sec.
    frost_shock = {
        id = 10473,
        cast = 0,
        cooldown = 6,
        gcd = "spell",

        spend = function() return damage_spell_cost( "frost_shock" ) end,
        spendType = "mana",

        startsCombat = true,
        texture = 135849,

        handler = function()
            consume_damage_spell()
            applyDebuff( "target", "frost_shock" )
            setCooldown( "earth_shock", 6 )
            setCooldown( "flame_shock", 6 )
        end,

        copy = { 8056, 8058, 10472 }
    },

    -- Surrounds the caster with 3 balls of lightning that strike melee attackers.
    lightning_shield = {
        id = 10432,
        cast = 0,
        cooldown = 0,
        gcd = "spell",

        spend = function() return plain_cost( "lightning_shield" ) end,
        spendType = "mana",

        startsCombat = false,
        texture = 136051,

        handler = function()
            applyBuff( "lightning_shield", nil, 3 )
        end,

        copy = { 324, 325, 905, 945, 8134, 10431 }
    },

    -- Instantly attack with your weapon; the next 2 sources of Nature damage to the target are increased by 20%.
    stormstrike = {
        id = 17364,
        cast = 0,
        cooldown = 20,
        gcd = "spell",

        spend = function() return plain_cost( "stormstrike" ) end,
        spendType = "mana",

        talent = "stormstrike",
        startsCombat = true,
        texture = 135963,

        handler = function()
            applyDebuff( "target", "stormstrike", nil, 2 )
        end,
    },

    -- Next Fire, Frost or Nature damage spell is a critical strike and costs no mana.
    elemental_mastery = {
        id = 16166,
        cast = 0,
        cooldown = 180,
        gcd = "off",

        talent = "elemental_mastery",
        startsCombat = false,
        texture = 136115,

        toggle = "cooldowns",

        handler = function()
            applyBuff( "elemental_mastery" )
        end,
    },

    -- Next Nature spell with a casting time under 10 sec is instant.
    natures_swiftness = {
        id = 16188,
        cast = 0,
        cooldown = 180,
        gcd = "off",

        talent = "nature_s_swiftness",
        startsCombat = false,
        texture = 136076,

        toggle = "cooldowns",

        handler = function()
            applyBuff( "natures_swiftness" )
        end,
    },

    -- Purges the enemy target, removing magic effects.  Not part of the priorities.
    purge = {
        id = 8012,
        cast = 0,
        cooldown = 0,
        gcd = "spell",

        spend = function() return plain_cost( "purge" ) end,
        spendType = "mana",

        startsCombat = true,
        texture = 136075,

        handler = function()
        end,

        copy = { 370 }
    },

    ghost_wolf = {
        id = 2645,
        cast = 3,
        cooldown = 0,
        gcd = "spell",

        spend = function() return plain_cost( "ghost_wolf" ) end,
        spendType = "mana",

        startsCombat = false,
        texture = 136095,

        handler = function()
            applyBuff( "ghost_wolf" )
        end,
    },

    -- Orc racial: Classic Era Blood Fury (attack power) for every class.
    blood_fury = {
        id = 20572,
        cast = 0,
        cooldown = 120,
        gcd = "off",

        toggle = "cooldowns",
        startsCombat = false,
        texture = 135726,

        handler = function()
            applyBuff( "blood_fury" )
        end,
    },

    -- Weapon imbues.
    rockbiter_weapon = imbue( "rockbiter_weapon", "mh_rockbiter", 16316, { 8017, 8018, 8019, 10399, 16314, 16315 } ),
    flametongue_weapon = imbue( "flametongue_weapon", "mh_flametongue", 16342, { 8024, 8027, 8030, 16339, 16341 } ),
    frostbrand_weapon = imbue( "frostbrand_weapon", "mh_frostbrand", 16356, { 8033, 8038, 10456, 16355 } ),
    windfury_weapon = imbue( "windfury_weapon", "mh_windfury", 16362, { 8232, 8235, 10486 } ),

    -- Fire totems.
    searing_totem = totem( "searing_totem", 10438, { 3599, 6363, 6364, 6365, 10437 }, { startsCombat = true } ),
    fire_nova_totem = totem( "fire_nova_totem", 11315, { 1535, 8498, 8499, 11314 }, { cooldown = 15, startsCombat = true } ),
    magma_totem = totem( "magma_totem", 10587, { 8190, 10585, 10586 }, { startsCombat = true } ),
    flametongue_totem = totem( "flametongue_totem", 16387, { 8227, 8249, 10526 } ),
    frost_resistance_totem = totem( "frost_resistance_totem", 10479, { 8181, 10478 } ),

    -- Earth totems.
    strength_of_earth_totem = totem( "strength_of_earth_totem", 25361, { 8075, 8160, 8161, 10442 } ),
    stoneskin_totem = totem( "stoneskin_totem", 10408, { 8071, 8154, 8155, 10406, 10407 } ),
    tremor_totem = totem( "tremor_totem", 8143 ),
    earthbind_totem = totem( "earthbind_totem", 2484, nil, { cooldown = 15 } ),
    stoneclaw_totem = totem( "stoneclaw_totem", 10428, { 5730, 6390, 6391, 6392, 10427 }, { cooldown = 30 } ),

    -- Water totems.
    mana_spring_totem = totem( "mana_spring_totem", 10497, { 5675, 10495, 10496 } ),
    healing_stream_totem = totem( "healing_stream_totem", 10463, { 5394, 6375, 6377, 10462 } ),
    fire_resistance_totem = totem( "fire_resistance_totem", 10538, { 8184, 10537 } ),
    poison_cleansing_totem = totem( "poison_cleansing_totem", 8166 ),
    disease_cleansing_totem = totem( "disease_cleansing_totem", 8170 ),
    mana_tide_totem = totem( "mana_tide_totem", 17359, { 16190, 17354 }, { cooldown = 300, talent = "mana_tide_totem", toggle = "cooldowns" } ),

    -- Air totems.
    windfury_totem = totem( "windfury_totem", 10614, { 8512, 10613 } ),
    grace_of_air_totem = totem( "grace_of_air_totem", 25359, { 8835, 10627 } ),
    tranquil_air_totem = totem( "tranquil_air_totem", 25908 ),
    nature_resistance_totem = totem( "nature_resistance_totem", 10601, { 10595, 10600 } ),
    windwall_totem = totem( "windwall_totem", 15112, { 15107, 15111 } ),
    grounding_totem = totem( "grounding_totem", 8177, nil, { cooldown = 15 } ),
    sentry_totem = totem( "sentry_totem", 6495 ),
} )


-- Settings
spec:RegisterSetting( "shaman_description", nil, {
    type = "description",
    name = "Adjust the settings below to match your group and playstyle.  Totems and weapon imbues are set separately for " ..
        "the Elemental and Enhancement priorities; a totem you have not learned yet is simply skipped."
} )

spec:RegisterSetting( "general_header", nil, {
    type = "header",
    name = "General"
} )

spec:RegisterSetting( "lightning_shield", true, {
    type = "toggle",
    name = "Maintain Lightning Shield",
    desc = "When enabled, Lightning Shield is recommended whenever it is not active.",
    width = "full",
} )

spec:RegisterSetting( "imbue_refresh", 60, {
    type = "range",
    name = "Refresh Weapon Imbue Out of Combat (seconds)",
    desc = "Out of combat, your weapon imbue is recommended again once it has less than this many seconds left.  " ..
        "In combat it is only recommended when it is missing.",
    width = "full",
    min = 0,
    max = 300,
    step = 5,
} )

spec:RegisterSetting( "totems_precombat", false, {
    type = "toggle",
    name = "Place Totems Before Combat",
    desc = "When enabled, your chosen buff totems are also recommended out of combat (for example before a raid pull).  " ..
        "Otherwise they are only recommended once you are in combat.",
    width = "full",
} )

spec:RegisterSetting( "searing_ttd", 15, {
    type = "range",
    name = "Searing Totem Minimum Fight Length",
    desc = "Searing Totem is only recommended when the target is expected to live at least this many seconds.",
    width = "full",
    min = 0,
    softMax = 60,
    step = 1,
} )

spec:RegisterSetting( "aoe_totems", true, {
    type = "toggle",
    name = "Fire Nova / Magma Totem for AoE",
    desc = "When enabled, Fire Nova Totem and Magma Totem are recommended against 3 or more enemies (they replace your " ..
        "single-target fire totem).",
    width = "full",
} )


local FIRE_TOTEMS = { none = "None", searing_totem = "Searing Totem", flametongue_totem = "Flametongue Totem",
    frost_resistance_totem = "Frost Resistance Totem" }
local EARTH_TOTEMS = { none = "None", strength_of_earth_totem = "Strength of Earth Totem", stoneskin_totem = "Stoneskin Totem",
    tremor_totem = "Tremor Totem" }
local WATER_TOTEMS = { none = "None", mana_spring_totem = "Mana Spring Totem", healing_stream_totem = "Healing Stream Totem",
    fire_resistance_totem = "Fire Resistance Totem", poison_cleansing_totem = "Poison Cleansing Totem",
    disease_cleansing_totem = "Disease Cleansing Totem" }
local AIR_TOTEMS = { none = "None", windfury_totem = "Windfury Totem", grace_of_air_totem = "Grace of Air Totem",
    tranquil_air_totem = "Tranquil Air Totem", nature_resistance_totem = "Nature Resistance Totem", windwall_totem = "Windwall Totem" }
local IMBUES = { none = "None", auto = "Best known (Windfury > Flametongue > Rockbiter)", windfury_weapon = "Windfury Weapon",
    flametongue_weapon = "Flametongue Weapon", rockbiter_weapon = "Rockbiter Weapon", frostbrand_weapon = "Frostbrand Weapon" }


spec:RegisterSetting( "enh_header", nil, {
    type = "header",
    name = "Enhancement"
} )

spec:RegisterSetting( "enh_imbue", "auto", {
    type = "select",
    name = "Main-Hand Imbue",
    desc = "The weapon imbue the Enhancement priority keeps on your main hand.",
    width = "full",
    values = IMBUES,
} )

spec:RegisterSetting( "enh_shock", "earth_shock", {
    type = "select",
    name = "Shock",
    desc = "The shock the Enhancement priority weaves between melee swings.  Earth Shock benefits from Stormstrike; " ..
        "Flame Shock is kept up as a damage-over-time effect instead.",
    width = "full",
    values = { none = "None", earth_shock = "Earth Shock", frost_shock = "Frost Shock", flame_shock = "Flame Shock" },
} )

spec:RegisterSetting( "enh_shock_mana", 30, {
    type = "range",
    name = "Shock Minimum Mana %",
    desc = "Shocks are only recommended at or above this mana percentage.",
    width = "full",
    min = 0,
    max = 100,
    step = 1,
} )

spec:RegisterSetting( "enh_lb_pull", true, {
    type = "toggle",
    name = "Pull With Lightning Bolt",
    desc = "When enabled (and not in a raid), Lightning Bolt is recommended out of combat when your target is out of melee range.",
    width = "full",
} )

spec:RegisterSetting( "enh_totem_earth", "strength_of_earth_totem", {
    type = "select", name = "Earth Totem", desc = "Earth totem the Enhancement priority keeps up.", width = "full", values = EARTH_TOTEMS,
} )

spec:RegisterSetting( "enh_totem_fire", "searing_totem", {
    type = "select", name = "Fire Totem", desc = "Fire totem the Enhancement priority keeps up (Searing Totem only on targets " ..
        "that live long enough).", width = "full", values = FIRE_TOTEMS,
} )

spec:RegisterSetting( "enh_totem_water", "mana_spring_totem", {
    type = "select", name = "Water Totem", desc = "Water totem the Enhancement priority keeps up.", width = "full", values = WATER_TOTEMS,
} )

spec:RegisterSetting( "enh_totem_air", "windfury_totem", {
    type = "select", name = "Air Totem", desc = "Air totem the Enhancement priority keeps up.  Windfury Totem is for your party's " ..
        "melee; Grace of Air Totem when your party prefers agility.", width = "full", values = AIR_TOTEMS,
} )


spec:RegisterSetting( "ele_header", nil, {
    type = "header",
    name = "Elemental"
} )

spec:RegisterSetting( "ele_cl_mana", 50, {
    type = "range",
    name = "Single-Target Chain Lightning Minimum Mana %",
    desc = "On a single target, Chain Lightning is only recommended at or above this mana percentage (always with Clearcasting " ..
        "or Elemental Mastery).  Set to 100 to save Chain Lightning for multiple targets.",
    width = "full",
    min = 0,
    max = 100,
    step = 1,
} )

spec:RegisterSetting( "ele_flame_shock", true, {
    type = "toggle",
    name = "Use Flame Shock",
    desc = "When enabled, Flame Shock is kept on targets that live long enough for its full duration.",
    width = "full",
} )

spec:RegisterSetting( "ele_earth_shock", false, {
    type = "toggle",
    name = "Use Earth Shock",
    desc = "When enabled, Earth Shock is recommended whenever the shock cooldown is free (after Flame Shock).  " ..
        "Off by default: Lightning Bolt is more mana-efficient.",
    width = "full",
} )

spec:RegisterSetting( "ele_shock_mana", 40, {
    type = "range",
    name = "Shock Minimum Mana %",
    desc = "Flame Shock and Earth Shock are only recommended at or above this mana percentage.",
    width = "full",
    min = 0,
    max = 100,
    step = 1,
} )

spec:RegisterSetting( "ele_imbue", "none", {
    type = "select",
    name = "Main-Hand Imbue",
    desc = "The weapon imbue the Elemental priority keeps on your main hand.  Most Elemental shamans use a wizard oil instead.",
    width = "full",
    values = IMBUES,
} )

spec:RegisterSetting( "ele_totem_earth", "none", {
    type = "select", name = "Earth Totem", desc = "Earth totem the Elemental priority keeps up.", width = "full", values = EARTH_TOTEMS,
} )

spec:RegisterSetting( "ele_totem_fire", "searing_totem", {
    type = "select", name = "Fire Totem", desc = "Fire totem the Elemental priority keeps up (Searing Totem only on targets " ..
        "that live long enough).", width = "full", values = FIRE_TOTEMS,
} )

spec:RegisterSetting( "ele_totem_water", "mana_spring_totem", {
    type = "select", name = "Water Totem", desc = "Water totem the Elemental priority keeps up.", width = "full", values = WATER_TOTEMS,
} )

spec:RegisterSetting( "ele_totem_air", "none", {
    type = "select", name = "Air Totem", desc = "Air totem the Elemental priority keeps up.", width = "full", values = AIR_TOTEMS,
} )


spec:RegisterOptions( {
    enabled = true,

    aoe = 3,

    gcd = 8017,

    nameplates = true,
    nameplateRange = 8,

    damage = true,
    damageExpiration = 6,

    package = "Enhancement",
    usePackSelector = true
} )


spec:RegisterPack( "Elemental", 20261026.2306, [[Hekili:nRvBVXnUr4FlbhWEEX5BT96E(AtInqVR5qVG2GIUb4(MK4kXDxcRvuvKYBnGH(T3ziLwsrrs5GRb4(qsS5mIppZW5njMKBs(CYMcIKM8P1xV(UBG)SA9TxFxYg5Z10Kn1K8hj7HFOICe(7puspsRKKsuYZLCsb(8cEBtoi9GuwlE7vxTNjp0UDvo)4v)D6JSs2vh0)tYMTTSs5VwLSnaQIAAEYN(rqkvKNS5NljcblVl7dne4VgqVlBZbYrs1B7Y(hS9hKvSQ9Dz)eVuEzx2pFGWQgj4eWhy9skPjNiKQ1UA029pHLPnpdp9VucgkU)88hHFvYL0JIUmsvrx2FL)bZkxOPqxMGkXTuSCf4uA47yLGR4B(gp0fEOXg0nRU5haqQ4DznTvuXYUpIp4gL)u8wKZbS)9TmWdbB4Vb2udzNSl7ZKNOnvW29B8thOKc7NEkt(B)RnaOCjrY4vlrl9a1bpfxed6Ze58MIVfWSUDBjQtdHvmWKvDztol6YyI(9TQ9r678D0WHFnNZll4NGF60bW51LbacwlPSKFcnrs5jYZI(JrfPEfhLlFNVvbYtyn0IZXeoe6DJda08RKxT)7lzpHpMK0SNkbZvXJ)nvi5nkx4GNc4jOaA2OXx3W4nm5ZyydCiFHoDOlRGJhEvCqXgkKNa0e2C4uRecJ6(y3hj54MkwvReVLi)U7Vkh8iPAbPLmH8smN8E2XTT0lz7UxYGF7A)pA5GbMkoWOLfO(dXTRCfUyB7UDtwDL6i6lGy6eLriPxk98Zohz3IrrFu7R)vvKI6P0XukdxhJXRkFw5jHtzmkIw1RZjkPgpBoqe60ma)A4edJeOv5hivG(4ocwWQZSzEFTYdD8q65TlTF3g7L(A45Ff(Bms4HRFzE3oSx0HCK0J91aHnyiJCvoMFKEMqRAOhHfeVFFEXQJK)R9gTL2iOnpIzKZsvcx5fX1FIcUo6rgv8W6rp4yKp70NW3vT1VOKKBvuaxeRISQox(GXFdpCAo(Kq9flS2HP8GZgl5BF8GQBjBrbvbK1sUoKf66dRWtGujpTGrF4(BwViaxu7rpDuDminyvPZ1EWOAD0mdJR5vFl8pf0scSoXTuvdDxdvap(fQTvOQi1qvAEh2Mk3uQD5OGDkcBa73s28wXIlEtiN3lHDEpC3ltDBV)M1l9Nhzxuq1r(IB)omBwfeTeAA(lm0Q)e)jWW)mg67zOGlXwc7poOb6SZP9fn0pPQKXEEfSah4TPufe8IXmaiPvGMPQSRr(nqd9QcDcTJUQ8zTKJih6xDiuATluoPcUIT2J)pWcDTgdgQsEd5isOtylnvxvfbdpKBf9h0JKU4IHAKwYu7(l6gvl8jFWhC2iuWN2hAVCkTAG4OTmOoGhs5kZqPZs8siJ0Vy6SRHlKBBGPf95KCfA5JolYVlYi(lMsNyvf7AHoutjKJidDge4LmNfolv05OQemCywvUunTbsw1fXHKW8dCHQ(2qh7HndlJ9iRUgh6QTsYGz4W67v0cRAx9D2ujbvKubmUfuG4CQWGDor4qyVZYNTOB9GaoCMQNSSHsoofeFY144tsuOuzQGpe6xsGYstXYRcwz5UIIIwnNjGUZy7ZkHx)NFn045xwualyckrqJHyav0qgqyumphQpbQXs0imETOB8(gc4L57sH3Ry6MpvQgGPRhfejK6)FG3C2pitLQbz66rbPIiBNjUlGkA4ciC2JLt4iIEpwmsmhlM1IUXyUw1EyYfWhRhHzccburdvaHZGjuHdkAv5dRrIgWy0IZebqpY9E2BwF4u3Ss0T8jsdJSTKQhjxivvvU8jszl9(34zkIxgpUUFxa4R8MqpsWIbOx1J6c9BSyvbttF1ik(gP(m9oVVYcFfsTglzcLMiCkTmtSARNXR6F8PWJB5JIyR94f79QriY6v5FpmozZtWB2bKEY3Q7e0ogpes2KSbF3ob(Ta1gg8tFs9PfPvihls(PKnAtpzZK2UjBYBWXTyeq)qTS7Yw0LfVTDx277YUnrcena0(6e7dDF6ziqS(5goCBao4TbTps4vrdlI2O3qJ)uaA4VVTpE4xtdrIpbGHj)qaMeODUpQeqvdxMz0adzUlazg353hhgRHbA)Zmyq8hdG40rb8H6uTmihEycd6)5aOpDgbFOpvld6HNYWG(Fja6bgzWhfcOQHhZm(HHm3CDKZEZ4fHo7nAm(SF6GjwqgQwyGXm8HDavnKyMrwSytOYJodK4NfJuXgDVdZyHAOcI2dS4p4Zi3oSB6yowG5w2JxdMhvAqDO9P6Ns13UvFNuCjyiOKnVX86OwZb1L9YlDzJhgYc5qL5gnbKxxRTckd1TfVArCoOUSh6YU2PxG2vOViLfd3uH9ytWtDVLfzn6KI4Hkjoz(hVnRCvkSbeFOkTN0UBVZ3MASr7mUIYqcvP1)SrETgVAoNjfD0RF32LeVt0DK2sPVHRm2GE3dD1egVH7xMxpdxFMG6l5eBsk37OWMbbVEdJn69ko8n1KzxTJ7XeWG3UXR0e1pwSrKOUx1GnDM7ksuN393kqSPFmxBIVXsm45wVbCeRFLwku6k2aiogWKyPjUHvT16JaLyNRDrlz4McCk5G5x93)sSHsSUJaVXv42yPJkSk81lyFseTY4nRvIJWDZnDeBQgRRmji9T051dQsZl6YEJJgJ8fO7pMZ4b1TbHA5Zp8ETByz0bLgFxm6AtM0VOvN0zXGjE9Rm49pGvI(6x5XNdgZIJ8w1oDn8Yx7zyI1TXFxk70P1XorClOe5LHT2)Vcm205uhffZ9n5cSMBkNH)RfOtjh666Ezx9zANJ6TiQ3B(s5D9FHk9zLH86U32Lp(7QJl7hFVyr5(KljBEMh8lI4EVybhjZwPjE(XxHwCh)K7tBE2hkx15s0c9AJwQ4Y8r32wuE7E1BZYADLJw5bEd(1VW)Zh990gIA9K)3d]] )

spec:RegisterPack( "Enhancement", 20261026.2306, [[Hekili:nRvBVnUns4FlbfW3g0CoVDnT3IMaC96E42f9wCaEb63KeTmTnrKfvjPsWceOF7DiPKiL4qQSOyr7hwVoCgX5zEHdFePZUo7tzB2ru0SpEZv3C31W)wFZTxDx2g1NBOzBAiLpsoaFPMCc(8D1hj1L0t0ALw2NR4KD6zqYBfLG8JkvJ8TxE5bM6y721L8tx(FPpYQyxE0(FzB22YQuVVoBBe7kBOLzF87bPuzz2M)DfrkzLDfVtqGpC2VRyZrYjs9BHVO4ItsLG9i9IUc5rE5JDfptjpXQpCH5Bn86Uc2PTTAf(f2HJQAqMEky0QDDfKA4dfxrp1v028iL20v8g78dtivPaTLNVg8zbFpRc80V5Bqrd8ytr81RV(7aBwZ7keT1u55DFq)OBmbmja(eo4HwgeeGP8xjIsbzpm0Niprf1We(R8Npsj78FEm08Z))nGH5kIIXRphEo1r6mBAWJCqFMSKl293aR20UTsRJGW2nGL1Dftc3Df6aBjNxTJ)CTl4ZQv8EBnr7D0TT73d6zdXMmsxXLO5KlTiZKvK60IX4VVpjAm0fJjntce8aiewEKZk1HnIGQrYaoMLnx39HUpqk1Xf56gbfQv3suF79xwsQQYTcYRys1f6s)7TfpS93RyWFDf(Jwn4f5sJtO1F0EZfUshkcgDToq(LamB8zILSdLp(S2a5VqFIwbYFRo1wvbRlGfPtI8)eVckDG6QHyMIioqHHyq0K3cFHVhIY0kkvxwuFGUEP4WwykNGnA9X8QT5AeS6mDP1kRrwdZVekX(bDArd33BkSmW3cM(IfdwQR(mGaAjrofWdl1psK21CqGOHlicqDADjSab0xpJqO0H9Lt6Mu1PJ5JtxE)SnnD91Oe4vK41LKpC1ljY)U5ABfNVlFFler8hLkKuXJ6QaVrLElDTDT6BTAc4ElS1TlSlTT5N2gyLjxmj1m0wMPl92QlGG2xqAHCGOxJULUNlM3UGjNKKEIiyKTvuR)BMWC(Jx8ePQLEVEX)6Ms1dtR1SAPfU6nNPivq3X1E(fOJEg39If(te128YqNTjJlONailF4UZ9bhLiu9MtNt02UvsZ9gE1a(xpaD)NFVGlvHpV3Wl88vqqb55DdVA5quFuW7Hg82F86HfQ6QTCfpFhJ(WD(nrnRwaK8mRENUal3UA0hnZeT6ndlSgeyQ9FX2JDvGWbSmcFJjZf09cQ845HqX4ikE9bqRq0ek1bipzOyYx(xmSeqGDltrfiGAUmhKgLGciN0Vy4yQX2cn03HfKMl0lgnkcpe5eViKS9x(KPX1B1n4Hv)nuOdcSzJMrZfM91L6UjJ7Opmzabj5JSMgkqbOTwXG(lvWYUA6UZ92FY2u0V80mcA1PrI1pMo2OJClYeFqqkP5895eMiCYdLAnq44jnIcIN)gqHg3iHsTgjC8KgPMOAf60Je2TrtQm0sruXAUictAtDG(z9gDOPfNexAXnwYjg6AtRpanHHySTBCGfIOYQ(TeqfUGnHkyOOSgZwtenyJjdUqfa9ehn37gFiR7gj5uQ79NlBeAoibZBGW(f4ZhoPfG3vPYWWbWe5uOrWKBTdMKKMApBHsxufSgdvusR1WzsGwwj0XPwIg)W1WApCzjn4oMKsGPnHfJOI1Kre6BtDR4)f)DqF1B)wnVz6jg8IRqB5)dttr7J8Ni99QTVqj0q()roCAyqD77sAFtARYg(4hmD15agIL1QbLDUZ4MfeEFMqUs)CpbSQSy6HBwz5(6L9CZHztPHIvaEZC0BqximQ3xrem9v8gn(m6TktHAp72ZqGYltHcEJiOJfAnYebEmlTwn0P88heEGUi148Q2HLL9yCfUUCUWqy5yN6RNR2fpwhp3GbrdH7K9pq1igyrv(pcIZ28e82AaOdo6SNbsp6Kq2MSn63tuQpAoRJbF7JMZ6R)9DY(PSnwxhESjuCY2uk00izeTYyeJ6kwbVVwCYrDf)yxXTzkaFrSyiNhmRgQLZYXzn5S(TrSEizimRhQLZ6XPt5S()iI1JWncdcru1HJf4z5aZ3Li17Orfl170yAQpKaMZI3fXIrytHz6iQ6WWcmZCG57JcMj0UWbXev8nokLnNr)HOLFowz4fEo5(LCHC5C26FgXwbK0WmyGsoRgLKNZ0xFveBJrCdZ8y65qqk6FEGiwVnucDyOavrhmssm0dhX64Ht0ddi4A6qsAkJEqjw7VieaXWsevDGzbYKEOjw7Wz7X5JcekpglpL2txXdDf3yeOzKy(ZRML4MVhQx9DaVqdMVXG5yDn9EQ)eXRwIbMZB1YBmyXH3bMjMVLBVjVEsk6Ha(LzBoZ7Mr8X)lVe6aJj1O9v9jxI2v1xbJ7nN9u6a0SytiJu4PU3ZJ8yLAaESEZbulrBvmxP4oqA(Q2iz8SB6QcJJeRXpoTtuVbvZLCPKSA)d7xqTR5acFvSwTNkzsARdxley23mGPzN5STs3wWD)KcoKdG24G4NLzxX5Py(gEKZlvHHJ95hpDs4JCw1l7bX2(y(5tJH)56mh9tpj7Kyp4yTxg5r3Qz(jzhD5GVsbr(Ph6D6aFWjGVi6v6F4d7jTvkSIFhEhmHc9gjDo987o0(MH9BcyxKLOCD(vtIUD3CLCHa0B2eR4YnR(T81r2OxQ5R0fTpwQYc3nIM6nLC3qA63Uz8AcXEVJx3oZ9xU34wZdxB3S900vSURUBOm9m9UHXULtBif9QoTIsDFNMSYD9RXITbQ31DIT6Yt8SDygC6eVmJ3vHgFJSfM7OVTI3vEgTJS3K)6ZjXVsvtVGRJtGbI22gcUA(KTeCnHELRn(l4Y)V(l3N(Btb126Sy)VrfJZC2WpckxMA4xRIjbPbxR6ixOFPx9pZT)ovqmJN97d]] )

spec:RegisterPackSelector( "elemental", "Elemental", "|T136048:0|t Elemental",
    "If you have spent more points in |T136048:0|t Elemental than in any other tree, this priority will be automatically selected for you.",
    function( tab1, tab2, tab3 )
        return tab1 > max( tab2, tab3 )
    end )

spec:RegisterPackSelector( "enhancement", "Enhancement", "|T136051:0|t Enhancement",
    "If you have spent more points in |T136051:0|t Enhancement than in any other tree, this priority will be automatically selected for you.",
    function( tab1, tab2, tab3 )
        return tab2 > max( tab1, tab3 )
    end )

-- Hekili doesn't recommend healing: Restoration uses the Elemental (caster) priority.
spec:RegisterPackSelector( "restoration", "Elemental", "|T136052:0|t Restoration",
    "If you have spent more points in |T136052:0|t Restoration than in any other tree, the Elemental (caster damage) priority will be " ..
    "automatically selected for you.",
    function( tab1, tab2, tab3 )
        return tab3 > max( tab1, tab2 )
    end )
