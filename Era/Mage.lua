-- Era/Mage.lua
-- Classic Era (1.15.x) Mage.  Spell, rank, talent and aura IDs, mana costs, cast times and durations come from the
-- Classic Era client tables (build 1.15.9.70003).

if UnitClassBase( 'player' ) ~= 'MAGE' then return end

local addon, ns = ...
local Hekili = _G[ addon ]
local class, state = Hekili.Class, Hekili.State

local GetSpellPowerCost = _G.GetSpellPowerCost or ( C_Spell and C_Spell.GetSpellPowerCost )
local GetItemCount = ( C_Item and C_Item.GetItemCount ) or _G.GetItemCount
local GetItemCooldown = ( C_Container and C_Container.GetItemCooldown ) or _G.GetItemCooldown
local IsAutoRepeatSpell = _G.IsAutoRepeatSpell
local HasWandEquipped = _G.HasWandEquipped

local spec = Hekili:NewSpecialization( 8 )


local function known_id( key )
    local ability = class.abilities[ key ]
    return ability and ability.id
end


-- Base mana cost per rank (Era SpellPower table).  The live cost (talents, Arcane Power) comes from
-- GetSpellPowerCost when the client provides it; this table is the fallback.
local mana_cost = {
    -- Fireball
    [133] = 30, [143] = 45, [145] = 65, [3140] = 95, [8400] = 140, [8401] = 185, [8402] = 220, [10148] = 260, [10149] = 305, [10150] = 350, [10151] = 395, [25306] = 410,
    -- Frostbolt
    [116] = 25, [205] = 35, [837] = 50, [7322] = 65, [8406] = 100, [8407] = 130, [8408] = 160, [10179] = 195, [10180] = 225, [10181] = 260, [25304] = 290,
    -- Fire Blast
    [2136] = 40, [2137] = 75, [2138] = 115, [8412] = 165, [8413] = 220, [10197] = 280, [10199] = 340,
    -- Scorch
    [2948] = 50, [8444] = 65, [8445] = 80, [8446] = 100, [10205] = 115, [10206] = 135, [10207] = 150,
    -- Pyroblast
    [11366] = 125, [12505] = 150, [12522] = 195, [12523] = 240, [12524] = 285, [12525] = 335, [12526] = 385, [18809] = 440,
    -- Arcane Missiles
    [5143] = 85, [5144] = 140, [5145] = 235, [8416] = 320, [8417] = 410, [10211] = 500, [10212] = 595, [25345] = 655,
    -- Arcane Explosion
    [1449] = 75, [8437] = 120, [8438] = 185, [8439] = 250, [10201] = 315, [10202] = 390,
    -- Blizzard
    [10] = 320, [6141] = 520, [8427] = 720, [10185] = 935, [10186] = 1160, [10187] = 1400,
    -- Cone of Cold
    [120] = 210, [8492] = 290, [10159] = 380, [10160] = 465, [10161] = 555,
    -- Frost Nova
    [122] = 55, [865] = 85, [6131] = 115, [10230] = 145,
    -- Flamestrike
    [2120] = 195, [2121] = 330, [8422] = 490, [8423] = 650, [10215] = 815, [10216] = 990,
    -- Blast Wave
    [11113] = 215, [13018] = 270, [13019] = 355, [13020] = 450, [13021] = 545,
    -- Ice Barrier
    [11426] = 305, [13031] = 360, [13032] = 420, [13033] = 480,
    -- Mage Armor, Frost Armor, Ice Armor
    [6117] = 270, [22782] = 380, [22783] = 490,
    [168] = 60, [7300] = 110, [7301] = 170,
    [7302] = 240, [7320] = 320, [10219] = 410, [10220] = 500,
    -- Arcane Intellect, Arcane Brilliance
    [1459] = 60, [1460] = 185, [1461] = 520, [10156] = 945, [10157] = 1510,
    [23028] = 3400,
    -- Counterspell, Ice Block
    [2139] = 100, [11958] = 15,
}

-- Base cast time per rank (Era SpellCastTimes), before Improved Frostbolt / Improved Fireball.
local cast_time = {
    [133] = 1.5, [143] = 2, [145] = 2.5, [3140] = 3, [8400] = 3.5, [8401] = 3.5, [8402] = 3.5, [10148] = 3.5, [10149] = 3.5, [10150] = 3.5, [10151] = 3.5, [25306] = 3.5,
    [116] = 1.5, [205] = 1.8, [837] = 2.2, [7322] = 2.6, [8406] = 3, [8407] = 3, [8408] = 3, [10179] = 3, [10180] = 3, [10181] = 3, [25304] = 3,
}

-- Arcane Missiles channel length per rank (3, 4, then 5 missiles).
local missiles_duration = { [5143] = 3, [5144] = 4 }

-- Frostbolt's chill per rank.
local frostbolt_duration = { [116] = 5, [205] = 6, [837] = 6, [7322] = 7, [8406] = 7, [8407] = 8, [8408] = 8, [10179] = 9, [10180] = 9, [10181] = 9, [25304] = 9 }

-- Fireball's burn per rank.
local fireball_duration = { [133] = 4, [143] = 6, [145] = 6 }


local function mana_spend( key )
    if state.buff.clearcasting.up then return 0 end

    local id = known_id( key )
    local c

    if GetSpellPowerCost and id and id > 0 then
        local ok, costs = pcall( GetSpellPowerCost, id )
        if ok and type( costs ) == "table" then
            for _, p in ipairs( costs ) do
                if type( p ) == "table" and p.type == 0 and type( p.cost ) == "number" then c = p.cost; break end
            end
        end
    end

    return c or mana_cost[ id ] or 0
end


spec:RegisterResource( Enum.PowerType.Mana )


-- Talents: { talentID, maxRank, rank1SpellID, ... rankNSpellID }, from the Classic Era client's Talent table.
spec:RegisterTalents( {
    -- Arcane
    arcane_subtlety           = {    74, 2, 11210, 12592 },
    arcane_focus              = {    76, 5, 11222, 12839, 12840, 12841, 12842 },
    improved_arcane_missiles  = {    80, 5, 11237, 12463, 12464, 16769, 16770 },
    wand_specialization       = {    78, 2, 6057, 6085 },
    magic_absorption          = {  1650, 5, 29441, 29444, 29445, 29446, 29447 },
    arcane_concentration      = {    75, 5, 11213, 12574, 12575, 12576, 12577 },
    magic_attunement          = {    82, 2, 11247, 12606 },
    improved_arcane_explosion = {    81, 3, 11242, 12467, 12469 },
    arcane_resilience         = {    85, 1, 28574 },
    improved_mana_shield      = {    83, 2, 11252, 12605 },
    improved_counterspell     = {    88, 2, 11255, 12598 },
    arcane_meditation         = {  1142, 3, 18462, 18463, 18464 },
    presence_of_mind          = {    86, 1, 12043 },
    arcane_mind               = {    77, 5, 11232, 12500, 12501, 12502, 12503 },
    arcane_instability        = {   421, 3, 15058, 15059, 15060 },
    arcane_power              = {    87, 1, 12042 },

    -- Fire
    improved_fireball         = {    26, 5, 11069, 12338, 12339, 12340, 12341 },
    impact                    = {    30, 5, 11103, 12357, 12358, 12359, 12360 },
    ignite                    = {    34, 5, 11119, 11120, 12846, 12847, 12848 },
    flame_throwing            = {    28, 2, 11100, 12353 },
    improved_fire_blast       = {    27, 3, 11078, 11080, 12342 },
    incinerate                = {  1141, 2, 18459, 18460 },
    improved_flamestrike      = {    31, 3, 11108, 12349, 12350 },
    pyroblast                 = {    29, 1, 11366 },
    burning_soul              = {    23, 2, 11083, 12351 },
    improved_scorch           = {    25, 3, 11095, 12872, 12873 },
    improved_fire_ward        = {    24, 2, 11094, 13043 },
    master_of_elements        = {  1639, 3, 29074, 29075, 29076 },
    critical_mass             = {    33, 3, 11115, 11367, 11368 },
    blast_wave                = {    32, 1, 11113 },
    fire_power                = {    35, 5, 11124, 12378, 12398, 12399, 12400 },
    combustion                = {    36, 1, 11129 },

    -- Frost
    frost_warding             = {    70, 2, 11189, 28332 },
    improved_frostbolt        = {    37, 5, 11070, 12473, 16763, 16765, 16766 },
    elemental_precision       = {  1649, 3, 29438, 29439, 29440 },
    ice_shards                = {    73, 5, 11207, 12672, 15047, 15052, 15053 },
    frostbite                 = {    38, 3, 11071, 12496, 12497 },
    improved_frost_nova       = {    62, 2, 11165, 12475 },
    permafrost                = {    65, 3, 11175, 12569, 12571 },
    piercing_ice              = {    61, 3, 11151, 12952, 12953 },
    cold_snap                 = {    69, 1, 12472 },
    improved_blizzard         = {    63, 3, 11185, 12487, 12488 },
    arctic_reach              = {   741, 2, 16757, 16758 },
    frost_channeling          = {    66, 3, 11160, 12518, 12519 },
    shatter                   = {    67, 5, 11170, 12982, 12983, 12984, 12985 },
    ice_block                 = {    72, 1, 11958 },
    improved_cone_of_cold     = {    64, 3, 11190, 12489, 12490 },
    winter_s_chill            = {    68, 5, 11180, 28592, 28593, 28594, 28595 },
    ice_barrier               = {    71, 1, 11426 },
} )


-- Auras
spec:RegisterAuras( {
    arcane_brilliance = {
        id = 23028,
        duration = 3600,
        max_stack = 1,
        shared = "player",
    },
    arcane_intellect = {
        id = 10157,
        duration = 1800,
        max_stack = 1,
        shared = "player",
        copy = { 1459, 1460, 1461, 10156, 10157 },
    },
    -- Spells deal 30% more damage and cost 30% more mana.
    arcane_power = {
        id = 12042,
        duration = 15,
        max_stack = 1,
    },
    blast_wave = {
        id = 13021,
        duration = 6,
        max_stack = 1,
        copy = { 11113, 13018, 13019, 13020, 13021 },
    },
    -- Your next damage spell costs no mana (Arcane Concentration).
    clearcasting = {
        id = 12536,
        duration = 15,
        max_stack = 1,
    },
    -- Fire spell critical strike chance increased until 3 critical strikes.
    combustion = {
        id = 11129,
        duration = 3600,
        max_stack = 20,
        copy = { 28682 },
    },
    cone_of_cold = {
        id = 10161,
        duration = 8,
        max_stack = 1,
        copy = { 120, 8492, 10159, 10160, 10161 },
    },
    evocation = {
        id = 12051,
        duration = 8,
        max_stack = 1,
    },
    fireball = {
        id = 25306,
        duration = function() return fireball_duration[ known_id( "fireball" ) ] or 8 end,
        tick_time = 2,
        max_stack = 1,
        copy = { 133, 143, 145, 3140, 8400, 8401, 8402, 10148, 10149, 10150, 10151, 25306 },
    },
    -- Improved Scorch: fire damage taken increased by 3% per stack.
    fire_vulnerability = {
        id = 22959,
        duration = 30,
        max_stack = 5,
        shared = "target",
    },
    frost_armor = {
        id = 7301,
        duration = 1800,
        max_stack = 1,
        copy = { 168, 7300, 7301 },
    },
    frost_nova = {
        id = 10230,
        duration = 8,
        max_stack = 1,
        copy = { 122, 865, 6131, 10230 },
    },
    frostbite = {
        id = 12494,
        duration = 5,
        max_stack = 1,
    },
    frostbolt = {
        id = 25304,
        duration = function() return frostbolt_duration[ known_id( "frostbolt" ) ] or 9 end,
        max_stack = 1,
        copy = { 116, 205, 837, 7322, 8406, 8407, 8408, 10179, 10180, 10181, 25304 },
    },
    ice_armor = {
        id = 10220,
        duration = 1800,
        max_stack = 1,
        copy = { 7302, 7320, 10219, 10220 },
    },
    ice_barrier = {
        id = 13033,
        duration = 60,
        max_stack = 1,
        copy = { 11426, 13031, 13032, 13033 },
    },
    ice_block = {
        id = 11958,
        duration = 10,
        max_stack = 1,
    },
    mage_armor = {
        id = 22783,
        duration = 1800,
        max_stack = 1,
        copy = { 6117, 22782, 22783 },
    },
    -- Your next Mage spell with a casting time less than 10 sec is instant.
    presence_of_mind = {
        id = 12043,
        duration = 3600,
        max_stack = 1,
    },
    pyroblast = {
        id = 18809,
        duration = 12,
        tick_time = 3,
        max_stack = 1,
        copy = { 11366, 12505, 12522, 12523, 12524, 12525, 12526, 18809 },
    },
    -- Pseudo-aura: Shoot (wand) is auto-repeating.
    wand = {
        duration = 3600,
        max_stack = 1,
    },
    winters_chill = {
        id = 12579,
        duration = 15,
        max_stack = 5,
        shared = "target",
    },

    -- Aliases.
    frozen = {
        alias = { "frost_nova", "frostbite" },
        aliasMode = "first",
        aliasType = "debuff",
    },
} )


-- Mana gems: one of each can be carried; they share a cooldown.  Restored mana is the average of the Era ranges.
local mana_gems = {
    { item = 8008, value = 1100, conjure = "conjure_mana_ruby" },    -- Mana Ruby: 1000-1200
    { item = 8007, value = 850,  conjure = "conjure_mana_citrine" }, -- Mana Citrine: 775-925
    { item = 5513, value = 600,  conjure = "conjure_mana_jade" },    -- Mana Jade: 550-650
    { item = 5514, value = 400,  conjure = "conjure_mana_agate" },   -- Mana Agate: 375-425
}

local gem_count = {}

local function count_item( item )
    if not GetItemCount then return 0 end
    local ok, n = pcall( GetItemCount, item )
    return ok and type( n ) == "number" and n or 0
end

spec:RegisterStateExpr( "mana_gem_id", function() return 0 end )
spec:RegisterStateExpr( "mana_gem_value", function() return 0 end )

spec:RegisterStateFunction( "has_gem", function( item )
    return ( gem_count[ item ] or 0 ) > 0
end )

-- Armor choice from the "Armor" setting, falling back to what you know.
spec:RegisterStateExpr( "armor_choice", function()
    local want = settings.armor
    if want == "mage" and state:IsKnown( "mage_armor" ) then return 1 end
    if want ~= "frost" and state:IsKnown( "ice_armor" ) then return 2 end
    return 3
end )

-- The Arcane priority's main nuke (setting "Arcane: Main Nuke").
spec:RegisterStateExpr( "nuke_frostbolt", function()
    return settings.arcane_nuke ~= "fireball"
end )

-- Out of mana for spells: wand time.
spec:RegisterStateExpr( "wand_mana", function()
    return settings.wand_mana_pct > 0 and mana.pct <= settings.wand_mana_pct
end )

-- Already wanding for mana: keep at it (spirit regeneration resumes 5 sec after the last spell) until mana is back to
-- twice the wand threshold, instead of casting again as soon as one spell is affordable.
spec:RegisterStateExpr( "wanding", function()
    return buff.wand.up and settings.wand_mana_pct > 0 and mana.pct < min( 100, 2 * settings.wand_mana_pct )
end )

spec:RegisterStateExpr( "scorch_wanted", function()
    return settings.scorch_stacks and talent.improved_scorch.enabled
end )


spec:RegisterHook( "reset_precast", function()
    mana_gem_id = 0
    mana_gem_value = 0

    for _, gem in ipairs( mana_gems ) do
        local n = count_item( gem.item )
        gem_count[ gem.item ] = n
        if n > 0 and mana_gem_id == 0 then
            mana_gem_id = gem.item
            mana_gem_value = gem.value
        end
    end

    if IsAutoRepeatSpell and IsAutoRepeatSpell( class.abilities.shoot.name or "Shoot" ) then
        applyBuff( "wand" )
    else
        removeBuff( "wand" )
    end
end )


-- Cast-time spells become instant with Presence of Mind.
local function consume_pom()
    if state.buff.presence_of_mind.up then state.removeBuff( "presence_of_mind" ) end
end

local function consume_clearcasting()
    if state.buff.clearcasting.up then state.removeBuff( "clearcasting" ) end
end


-- Abilities
spec:RegisterAbilities( {
    arcane_brilliance = {
        id = 23028,
        cast = 0,
        cooldown = 0,
        gcd = "spell",

        spend = function() return mana_spend( "arcane_brilliance" ) end,
        spendType = "mana",

        startsCombat = false,
        texture = 135869,

        handler = function()
            applyBuff( "arcane_brilliance" )
        end,
    },


    arcane_explosion = {
        id = 10202,
        cast = 0,
        cooldown = 0,
        gcd = "spell",

        spend = function() return mana_spend( "arcane_explosion" ) end,
        spendType = "mana",

        startsCombat = true,
        texture = 136116,

        handler = function()
            consume_clearcasting()
        end,

        copy = { 1449, 8437, 8438, 8439, 10201 }
    },


    arcane_intellect = {
        id = 10157,
        cast = 0,
        cooldown = 0,
        gcd = "spell",

        spend = function() return mana_spend( "arcane_intellect" ) end,
        spendType = "mana",

        startsCombat = false,
        texture = 135932,

        handler = function()
            applyBuff( "arcane_intellect" )
        end,

        copy = { 1459, 1460, 1461, 10156 }
    },


    arcane_missiles = {
        id = 25345,
        cast = function() return ( missiles_duration[ known_id( "arcane_missiles" ) ] or 5 ) * haste end,
        channeled = true,
        cooldown = 0,
        gcd = "spell",

        spend = function() return mana_spend( "arcane_missiles" ) end,
        spendType = "mana",

        startsCombat = true,
        texture = 136096,

        start = function()
            consume_clearcasting()
        end,

        copy = { 5143, 5144, 5145, 8416, 8417, 10211, 10212 }
    },


    -- Spells deal 30% more damage and cost 30% more mana for 15 sec.
    arcane_power = {
        id = 12042,
        cast = 0,
        cooldown = 180,
        gcd = "off",

        talent = "arcane_power",
        startsCombat = false,
        texture = 136048,

        toggle = "cooldowns",

        handler = function()
            applyBuff( "arcane_power" )
        end,
    },


    blast_wave = {
        id = 13021,
        cast = 0,
        cooldown = 45,
        gcd = "spell",

        spend = function() return mana_spend( "blast_wave" ) end,
        spendType = "mana",

        talent = "blast_wave",
        startsCombat = true,
        texture = 135903,

        handler = function()
            consume_clearcasting()
            applyDebuff( "target", "blast_wave" )
        end,

        copy = { 11113, 13018, 13019, 13020 }
    },


    blizzard = {
        id = 10187,
        cast = function() return 8 * haste end,
        channeled = true,
        cooldown = 0,
        gcd = "spell",

        spend = function() return mana_spend( "blizzard" ) end,
        spendType = "mana",

        startsCombat = true,
        texture = 135857,

        start = function()
            consume_clearcasting()
        end,

        copy = { 10, 6141, 8427, 10185, 10186 }
    },


    -- Resets the cooldown of your Frost spells.
    cold_snap = {
        id = 12472,
        cast = 0,
        cooldown = 600,
        gcd = "off",

        talent = "cold_snap",
        startsCombat = false,
        texture = 135865,

        toggle = "cooldowns",

        handler = function()
            setCooldown( "ice_barrier", 0 )
            setCooldown( "frost_nova", 0 )
            setCooldown( "cone_of_cold", 0 )
            setCooldown( "ice_block", 0 )
        end,
    },


    combustion = {
        id = 11129,
        cast = 0,
        cooldown = 180,
        gcd = "off",

        talent = "combustion",
        startsCombat = false,
        texture = 135824,

        toggle = "cooldowns",

        handler = function()
            applyBuff( "combustion" )
        end,
    },


    cone_of_cold = {
        id = 10161,
        cast = 0,
        cooldown = 10,
        gcd = "spell",

        spend = function() return mana_spend( "cone_of_cold" ) end,
        spendType = "mana",

        startsCombat = true,
        texture = 135852,

        usable = function() return target.distance <= 10, "target must be within 10 yards" end,

        handler = function()
            consume_clearcasting()
            removeDebuff( "target", "frost_nova" )
            applyDebuff( "target", "cone_of_cold" )
        end,

        copy = { 120, 8492, 10159, 10160 }
    },


    conjure_mana_agate = {
        id = 759,
        cast = function() return 3 * haste end,
        cooldown = 0,
        gcd = "spell",

        spend = 0.05,
        spendType = "mana",

        startsCombat = false,
        texture = 134104,

        usable = function() return combat == 0 and not has_gem( 5514 ), "out of combat, without a Mana Agate" end,

        handler = function()
            gem_count[ 5514 ] = 1
        end,
    },


    conjure_mana_jade = {
        id = 3552,
        cast = function() return 3 * haste end,
        cooldown = 0,
        gcd = "spell",

        spend = 0.05,
        spendType = "mana",

        startsCombat = false,
        texture = 134104,

        usable = function() return combat == 0 and not has_gem( 5513 ), "out of combat, without a Mana Jade" end,

        handler = function()
            gem_count[ 5513 ] = 1
        end,
    },


    conjure_mana_citrine = {
        id = 10053,
        cast = function() return 3 * haste end,
        cooldown = 0,
        gcd = "spell",

        spend = 0.05,
        spendType = "mana",

        startsCombat = false,
        texture = 134104,

        usable = function() return combat == 0 and not has_gem( 8007 ), "out of combat, without a Mana Citrine" end,

        handler = function()
            gem_count[ 8007 ] = 1
        end,
    },


    conjure_mana_ruby = {
        id = 10054,
        cast = function() return 3 * haste end,
        cooldown = 0,
        gcd = "spell",

        spend = 0.05,
        spendType = "mana",

        startsCombat = false,
        texture = 134104,

        usable = function() return combat == 0 and not has_gem( 8008 ), "out of combat, without a Mana Ruby" end,

        handler = function()
            gem_count[ 8008 ] = 1
        end,
    },


    -- Interrupts the target's spellcasting and locks that school for 10 sec.
    counterspell = {
        id = 2139,
        cast = 0,
        cooldown = 30,
        gcd = "off",

        spend = function() return mana_spend( "counterspell" ) end,
        spendType = "mana",

        startsCombat = true,
        texture = 135856,

        toggle = "interrupts",

        debuff = "casting",
        readyTime = state.timeToInterrupt,

        handler = function()
            interrupt()
        end,
    },


    -- Mana regeneration increased by 1500% while channeling for 8 sec.
    evocation = {
        id = 12051,
        cast = function() return 8 * haste end,
        channeled = true,
        cooldown = 480,
        gcd = "spell",

        startsCombat = false,
        texture = 136075,

        start = function()
            applyBuff( "evocation" )
        end,

        finish = function()
            removeBuff( "evocation" )
            -- Roughly what 8 sec of spirit regeneration at +1500% returns for a typical level-60 mage.
            gain( 0.6 * mana.max, "mana" )
        end,
    },


    fire_blast = {
        id = 10199,
        cast = 0,
        cooldown = function() return 8 - 0.5 * talent.improved_fire_blast.rank end,
        gcd = "spell",

        spend = function() return mana_spend( "fire_blast" ) end,
        spendType = "mana",

        startsCombat = true,
        texture = 135807,

        handler = function()
            consume_clearcasting()
        end,

        copy = { 2136, 2137, 2138, 8412, 8413, 10197 }
    },


    fireball = {
        id = 25306,
        cast = function()
            if buff.presence_of_mind.up then return 0 end
            return max( 1.5, ( cast_time[ known_id( "fireball" ) ] or 3.5 ) - 0.1 * talent.improved_fireball.rank ) * haste
        end,
        cooldown = 0,
        gcd = "spell",

        spend = function() return mana_spend( "fireball" ) end,
        spendType = "mana",

        startsCombat = true,
        texture = 135812,

        handler = function()
            consume_pom()
            consume_clearcasting()
            applyDebuff( "target", "fireball" )
        end,

        copy = { 133, 143, 145, 3140, 8400, 8401, 8402, 10148, 10149, 10150, 10151 }
    },


    flamestrike = {
        id = 10216,
        cast = function() return buff.presence_of_mind.up and 0 or 3 * haste end,
        cooldown = 0,
        gcd = "spell",

        spend = function() return mana_spend( "flamestrike" ) end,
        spendType = "mana",

        startsCombat = true,
        texture = 135826,

        handler = function()
            consume_pom()
            consume_clearcasting()
        end,

        copy = { 2120, 2121, 8422, 8423, 10215 }
    },


    frost_armor = {
        id = 7301,
        cast = 0,
        cooldown = 0,
        gcd = "spell",

        spend = function() return mana_spend( "frost_armor" ) end,
        spendType = "mana",

        startsCombat = false,
        texture = 135843,

        handler = function()
            removeBuff( "mage_armor" )
            removeBuff( "ice_armor" )
            applyBuff( "frost_armor" )
        end,

        copy = { 168, 7300 }
    },


    frost_nova = {
        id = 10230,
        cast = 0,
        cooldown = function() return 25 - 2 * talent.improved_frost_nova.rank end,
        gcd = "spell",

        spend = function() return mana_spend( "frost_nova" ) end,
        spendType = "mana",

        startsCombat = true,
        texture = 135848,

        usable = function() return target.distance <= 10, "target must be within 10 yards" end,

        handler = function()
            consume_clearcasting()
            applyDebuff( "target", "frost_nova" )
        end,

        copy = { 122, 865, 6131 }
    },


    frostbolt = {
        id = 25304,
        cast = function()
            if buff.presence_of_mind.up then return 0 end
            return max( 1.5, ( cast_time[ known_id( "frostbolt" ) ] or 3 ) - 0.1 * talent.improved_frostbolt.rank ) * haste
        end,
        cooldown = 0,
        gcd = "spell",

        spend = function() return mana_spend( "frostbolt" ) end,
        spendType = "mana",

        startsCombat = true,
        texture = 135846,

        handler = function()
            consume_pom()
            consume_clearcasting()
            applyDebuff( "target", "frostbolt" )
        end,

        copy = { 116, 205, 837, 7322, 8406, 8407, 8408, 10179, 10180, 10181 }
    },


    ice_armor = {
        id = 10220,
        cast = 0,
        cooldown = 0,
        gcd = "spell",

        spend = function() return mana_spend( "ice_armor" ) end,
        spendType = "mana",

        startsCombat = false,
        texture = 135843,

        handler = function()
            removeBuff( "mage_armor" )
            removeBuff( "frost_armor" )
            applyBuff( "ice_armor" )
        end,

        copy = { 7302, 7320, 10219 }
    },


    -- Absorbs damage for 1 min; spells are not interrupted while the shield holds.
    ice_barrier = {
        id = 13033,
        cast = 0,
        cooldown = 30,
        gcd = "spell",

        spend = function() return mana_spend( "ice_barrier" ) end,
        spendType = "mana",

        talent = "ice_barrier",
        startsCombat = false,
        texture = 135988,

        toggle = "defensives",

        handler = function()
            applyBuff( "ice_barrier" )
        end,

        copy = { 11426, 13031, 13032 }
    },


    ice_block = {
        id = 11958,
        cast = 0,
        cooldown = 300,
        gcd = "spell",

        spend = function() return mana_spend( "ice_block" ) end,
        spendType = "mana",

        talent = "ice_block",
        startsCombat = false,
        texture = 135841,

        toggle = "defensives",

        handler = function()
            applyBuff( "ice_block" )
        end,
    },


    mage_armor = {
        id = 22783,
        cast = 0,
        cooldown = 0,
        gcd = "spell",

        spend = function() return mana_spend( "mage_armor" ) end,
        spendType = "mana",

        startsCombat = false,
        texture = 135991,

        handler = function()
            removeBuff( "ice_armor" )
            removeBuff( "frost_armor" )
            applyBuff( "mage_armor" )
        end,

        copy = { 6117, 22782 }
    },


    -- Use the best mana gem in your bags (Mana Ruby, Citrine, Jade or Agate).
    mana_gem = {
        id = 10058,
        name = "|cff00ccff[Mana Gem]|r",
        link = "|cff00ccff[Mana Gem]|r",
        known = function() return mana_gem_id > 0 end,
        cast = 0,
        cooldown = 120,
        gcd = "off",

        startsCombat = false,

        item = function() return mana_gem_id > 0 and mana_gem_id or 8008 end,
        bagItem = true,
        texture = 134104,

        usable = function() return mana_gem_id > 0, "requires a mana gem in your bags" end,

        readyTime = function()
            if mana_gem_id == 0 or not GetItemCooldown then return 0 end
            local ok, start, duration = pcall( GetItemCooldown, mana_gem_id )
            if not ok or not start or start == 0 then return 0 end
            return max( 0, start + duration - query_time )
        end,

        handler = function()
            gain( mana_gem_value, "mana" )
            gem_count[ mana_gem_id ] = max( 0, ( gem_count[ mana_gem_id ] or 1 ) - 1 )
            mana_gem_id = 0
            mana_gem_value = 0
        end,

        copy = { 5405, 10052, 10057, "use_mana_gem" }
    },


    -- Your next Mage spell with a casting time under 10 sec is instant.
    presence_of_mind = {
        id = 12043,
        cast = 0,
        cooldown = 180,
        gcd = "off",

        talent = "presence_of_mind",
        startsCombat = false,
        texture = 136031,

        toggle = "cooldowns",

        handler = function()
            applyBuff( "presence_of_mind" )
        end,
    },


    pyroblast = {
        id = 18809,
        cast = function() return buff.presence_of_mind.up and 0 or 6 * haste end,
        cooldown = 0,
        gcd = "spell",

        spend = function() return mana_spend( "pyroblast" ) end,
        spendType = "mana",

        talent = "pyroblast",
        startsCombat = true,
        texture = 135808,

        handler = function()
            consume_pom()
            consume_clearcasting()
            applyDebuff( "target", "pyroblast" )
        end,

        copy = { 11366, 12505, 12522, 12523, 12524, 12525, 12526 }
    },


    scorch = {
        id = 10207,
        cast = function() return buff.presence_of_mind.up and 0 or 1.5 * haste end,
        cooldown = 0,
        gcd = "spell",

        spend = function() return mana_spend( "scorch" ) end,
        spendType = "mana",

        startsCombat = true,
        texture = 135827,

        handler = function()
            consume_pom()
            consume_clearcasting()
            -- Improved Scorch applies Fire Vulnerability (33/66/100% chance); predicted as a hit.
            if talent.improved_scorch.enabled then
                applyDebuff( "target", "fire_vulnerability", nil, min( 5, debuff.fire_vulnerability.stack + 1 ) )
            end
        end,

        copy = { 2948, 8444, 8445, 8446, 10205, 10206 }
    },


    -- Wand (auto-repeat).
    shoot = {
        id = 5019,
        cast = 0,
        cooldown = 0,
        gcd = "spell",

        startsCombat = true,
        texture = 132317,

        usable = function()
            if HasWandEquipped and not HasWandEquipped() then return false, "requires a wand" end
            return buff.wand.down, "already shooting"
        end,

        handler = function()
            applyBuff( "wand" )
        end,
    },
} )


-- Settings
spec:RegisterSetting( "mage_description", nil, {
    type = "description",
    name = "Adjust the settings below to match your group and playstyle.  The priorities follow the Classic Era mage " ..
        "guides; Frostbolt / Fireball rank choice (downranking) is up to you."
} )

spec:RegisterSetting( "mana_header", nil, {
    type = "header",
    name = "Mana"
} )

spec:RegisterSetting( "mana_gem_pct", 75, {
    type = "range",
    name = "Mana Gem Below Mana %",
    desc = "Use your best mana gem in combat once your mana is below this percentage and the gem would not overfill you.",
    width = "full",
    min = 0,
    max = 100,
    step = 1,
} )

spec:RegisterSetting( "evocation_pct", 15, {
    type = "range",
    name = "Evocation Below Mana %",
    desc = "Channel Evocation in combat once your mana is below this percentage (while standing still).",
    width = "full",
    min = 0,
    max = 100,
    step = 1,
} )

spec:RegisterSetting( "wand_mana_pct", 10, {
    type = "range",
    name = "Wand Below Mana %",
    desc = "Start your wand (Shoot) once your mana is below this percentage and Evocation / mana gems are not available.  " ..
        "Set to 0 to never recommend the wand.",
    width = "full",
    min = 0,
    max = 100,
    step = 1,
} )

spec:RegisterSetting( "conjure_gems", true, {
    type = "toggle",
    name = "Conjure Mana Gems Out of Combat",
    desc = "When enabled, missing mana gems (Ruby, Citrine, Jade, Agate) are conjured out of combat.",
    width = "full",
} )

spec:RegisterSetting( "buffs_header", nil, {
    type = "header",
    name = "Buffs and Defensives"
} )

spec:RegisterSetting( "armor", "mage", {
    type = "select",
    name = "Armor",
    desc = "Which armor to keep up.  If you have not learned it yet, the next one down is used (Mage Armor > Ice Armor > Frost Armor).",
    width = "full",
    values = {
        mage = "Mage Armor (mana regeneration)",
        ice = "Ice Armor / Frost Armor (melee mitigation, leveling)",
        frost = "Frost Armor",
    },
} )

spec:RegisterSetting( "cold_snap", true, {
    type = "toggle",
    name = "Cold Snap",
    desc = "When enabled (and the Cooldowns toggle is on), Cold Snap is recommended to reset Ice Barrier when it is down, " ..
        "or Frost Nova and Cone of Cold when enemies are on you.",
    width = "full",
} )

spec:RegisterSetting( "aoe_header", nil, {
    type = "header",
    name = "Area of Effect"
} )

spec:RegisterSetting( "aoe_frost_nova", true, {
    type = "toggle",
    name = "Frost Nova When Enemies Are On You",
    desc = "When enabled, Frost Nova is recommended when several enemies are within 10 yards (AoE grinding: Nova, step back, " ..
        "Blizzard / Cone of Cold).",
    width = "full",
} )

spec:RegisterSetting( "fire_header", nil, {
    type = "header",
    name = "Fire"
} )

spec:RegisterSetting( "scorch_stacks", true, {
    type = "toggle",
    name = "Maintain Scorch Stacks (Improved Scorch)",
    desc = "When enabled and you have Improved Scorch, Scorch is recommended to build and keep 5 stacks of Fire Vulnerability on " ..
        "your target.  Disable it when another mage maintains the stacks.",
    width = "full",
} )

spec:RegisterSetting( "pyroblast_opener", true, {
    type = "toggle",
    name = "Pyroblast Opener",
    desc = "When enabled and you have Pyroblast, it is recommended as the first spell of a fight (and with Presence of Mind).  " ..
        "Otherwise Pyroblast is not used.",
    width = "full",
} )

spec:RegisterSetting( "fire_blast_mana_pct", 40, {
    type = "range",
    name = "Fire: Fire Blast Above Mana %",
    desc = "The Fire priority weaves Fire Blast on cooldown while your mana is at or above this percentage.  " ..
        "Fire Blast is always used while moving.  Set to 100 to only use it while moving.",
    width = "full",
    min = 0,
    max = 100,
    step = 1,
} )

spec:RegisterSetting( "arcane_header", nil, {
    type = "header",
    name = "Arcane"
} )

spec:RegisterSetting( "arcane_nuke", "frostbolt", {
    type = "select",
    name = "Arcane: Main Nuke",
    desc = "The spell the Arcane priority casts between cooldowns (Frostbolt for AP/Frost builds, Fireball for AP/Fire builds).",
    width = "full",
    values = {
        frostbolt = "Frostbolt",
        fireball = "Fireball",
    },
} )

spec:RegisterSetting( "clearcasting_missiles", true, {
    type = "toggle",
    name = "Arcane: Arcane Missiles on Clearcasting",
    desc = "When enabled, the Arcane priority spends Clearcasting on Arcane Missiles (the most expensive spell, so the most mana saved).  " ..
        "Otherwise Clearcasting is spent on your main nuke.",
    width = "full",
} )


spec:RegisterOptions( {
    enabled = true,

    aoe = 3,

    -- Frost Armor: known from level 1, on the GCD, no cooldown of its own.
    gcd = 168,

    nameplates = true,
    nameplateRange = 10,

    -- Count enemies hit by Blizzard / Flamestrike / Arcane Explosion as well.
    damage = true,
    damageExpiration = 6,

    package = "Frost",
    usePackSelector = true
} )


spec:RegisterPack( "Frost", 20261027.1552, [[Hekili:LMv)VTnop4)wkgqUwCBPnTVTBxVMcSpX7nCR4aYa2VzBzhLeTOifijNCDOW)TFKs2YF7KU9ldowKpKMI8HKDbtc(AWS5edn4HlV4YBMCXLVE8KRV(YGzMh3sdMTLKSMSeEqq2a)7NusTbF7JCjzoQRwMQsGtwzmB13E(5lzMvPXJtKBoFfvrwZ4m)dbZItzCZFjcI7XO6T0KGhEdCkvNem79CIwZsYI(OIKfznEw0xS(ZwLCbJdp8Ixu7KSOtRR1ea6ZY(mk2mRVQVnlQUiBS6TmLbwf0)BY9ROK5vKQg(F4FMLfDEweNUJYzILfA(YSOVrujkYcq0Vs2rvcRC7L7nXjJxUSeqR3u1QGUMv0kw0D4hy6ePA(VbE1BLF8vlvmXCRffsdvF24SOCFlwYbJY05Wisxt)ZSifrSolkzLKLqDNMUfKqMf9OmDSZl(crarGL0nOp8XDYeIHjff(ZEIyo8mrTrQkqc(97LCi8a5eaCGe(a0dYDeRRIQaQNifgLKZPGimroMUOOMAmWNIgCJSptsqJQhVvrHeNyI53NEoekjcAityOaajMxYwmnoDXIXnpy8C5EXOQhfRyCoJisO2Z6gFmchA)WqKTpe6(aNoXHwPedadiFpOCPdfVadaYcm81dmx5GPIidaeeW)EQIgUbUvdvPXpIW5d1fNI32hH(jmdKWr)vG47K5)s6twcSeptaWaEmrPyuLpNPY7YJEEDTMmfsMua5dNx79eop09ZqotBEjsco16yBwUXuvuRb4YK1Ojb2dUz14TjM7MC9idBd9(lAj8b8WoulbQ6c1qrxJas(BZ1y0PgcNkm1qKkiXqv4OUnvIeWaEO2jk6gctOVFYfJmYLl5qTeDbvOz7O6NqNAhnKkOByu99qsQHOwsHArimHfE3nf0ZJRl5vaSdvH1FmCNsdLlcXpfVaxLtA)nsoN3cKccd(a)9AkfOE0RKsJ9StLc(JnOHqIDzms6qG3POKKvi9oq9beNvcRQur7l59oRIr68hpCIrX3Jg1Q91xN2HiTP3TINvvCbtHjxeTLdCJCxtVPs4RBjw47rydP)n25c6m(QRGq5Na0JHVhO5GWW4TAOWPeLGoFCtpc1bT2jUxp2BJXRf5vyf9xU12GPD)frLUmL4p2xGzzPHNrL9H0r4RS1wL1afsfcV2DoKRYa(R7N6pAhHNs72iuVBvALtCrXUSMxC0CDJOnZScAEDXpvh1gOlwS6FXtwlLKQuqX7DTcQjWdJ6ou3TM5xrof75s6SQnF9PVLnF3k3tvDlbW4QPqHoM4TbglPBPIbwvQAD10XANNQHg5glvUlDbMD42g1X7ltuWPrDzLsHTs2olIaorUOyQeyIR3A9EiD7F3YLAgklo9rc8dC6L3Xz)4hefiReqvTNPPvY(GksFhzKXQgzlCyy5rDs6nNw0V(hurJw1oSBwV(ZHs(veT4B84rAut2MBA91peJtpFfDlvCrSUR4RJrQTPpcQLcLYjNBDJDCrISphmdMthdFTwfzpq7H35bZcMH81A7Ms0fKuUbE8b7Mt59vdExWmNhfmR6Webga2(KRrpeNvcD7z55sqeUQhe8ZCaGPGQifJa7H5N9il6oGJ)6SOrq1dqdLfDFw0fiG)VHa01(VkKDpbvByVU3is(ekvbT98lnq0(ZtH3070mwj635gAQgRjM4SrRPBYIE6jy8HAfjGctZIUYPq9Cliop1d2aJ8u1Mdo6JvqWuNHb1BAeulJG5P(LX5gdyulHQqyaXx3lIvUopU0upvoI7B6f3odLhNFdKci2)rpPwLevvTNJkc1BYf9Mtwg37r1(kW9SrwP6R8UGhRk4N4YQAZOfGynZVeZq0ln3(TvHANRhxwQ09kYdruvUgCT70k7OMfHfaL2OXIZhId7WyFz9s96q3hBwLnMhe8RkbV5s2dZQ1yv7Ey3kxxTRY5orlFX7JcWMvZDciUg(rHwZA4orZUu(rbxFLTpNgnUAJsMMdxByNADOm6MZUoucA5eSdLR5NJ15TfSTd4RL9hQXapqRL2JV4mgsr(Snupt0EW(BD6e9pJtpSSpFl031tZPG)5TI91D1P6MbjzoqdObypoq)N(ykkMOEOI)ATO6RM(NOdv5yPdKWvSXD3twydZflv7Us6Cn(s5YxL3DzuFD(HY98BPpGFCc(NiYU2YaEvT19hkx0U0)awR7)ia1N21FKBi0QB2BNNV1TtIDt5r9DVDayQ(hjOiI0hqNzZbqcNuZkSN6)V4)wh8Tb)3p]] )

spec:RegisterPack( "Fire", 20261027.1552, [[Hekili:LM1AVTnUs0FlzlGxBKaf7K1P5geBG(eBxGMTaUa5BsIsM2M1YIguu23ueOF77mKIsupTl6hsGI4W5jNZCeJ7e3V7UyjrsDF6MX3C3KX38wNjtNEJ7c5l7PUl2tc3swdpet2b)(ZmH6LVeXjlXTMWtfHWR2iL7tE46RxZKBsdCc57UEdvq2YIyfp4UiiLfj)sSBqh2mzpn09P7HvPjHUl(qejjHfM5)jbjZhTDM)xvEZEbFflcE4nVXEHm)Hv3ZeqXJY(huQfkpn5Hm)QIStTV1PmWMW(FMFCdLS0skB1)XVTix2RY8FMicfKvYm)VtoqfXz(xN5FKFuge6SETLgSnXvAVrUH2qGpYsc5IL)j4gccdCHyUKMmc8ymVb)njg(1wkDFM)0m)VSdYchOWRwaBlCtMFIeQwGfuUCajk6kJ3)EWsGFcHwmATyiUHL5hnUZh47cstKmoSm(tiNhTKFmguW3ErWd0BNhh9cSXe0tG)ApnMkCYZU1DbvaAVxL0vDims1oJCJGMSbS5vM3SMUdvZNoWdjA)sf9k1Eu9iPSSKqLsw86eWzY(hsikFIZEbfoggqKxo7AOsrIPESyjnkIgkVITAwq6Qvo1xWbJ6b2lfiyrrmsCivTw76hlGEeXoUa1S6bVWnCwiD2eT2kLOh1aY3HwUrRLcb6rjRe8ezhQ5wTASePhffYJ)rQG6HfeprAWlO6ks1MvXc1zS)qMuWIP)oQ4hKL)w7NSgWC(fvaMWdicbJkkoZy9U8Sh2b8VQd4pu5qpKN3bh9tXZ)RWUkuRaitUdK5)hwcRvWFmYPDpzVrYkrqXB90nywnaQWpfoylay1OOkVhA(90)PxedujIUptLK2TEN0wuvWgXd3IMfqgJKBC2hkFCY0bs2o68Xne(ezRITHjTNHozvIyfxO78FWGWbWbCDsAOg35Z4H2m)N4hq0lqAEaIhGjubLeUbHVFHNAL)apsKg3mqpQTk6I5pE6KJbrmb3vZi)8QodgI7C24xvzgO6MqbCfp(kVDS4LoP7hDsFNWvhHX3FG6bkDhJMmF2T68z9zcLZoKC1qJc8zbDfc5cRtHCpvLrnJnWPyP4MIOqYLb)SuW3xjVMOuVkyvp5bjsjD5Gl2XpaH(ajrSMkDWW1tY9wYOZNmEWWLun(dyiVdPrqkHeamdKV4OCShN(A3siO7iS4Kh1oHsc0zDcX8lAOlZxr7rwVFSZ0kjwLYlQwAp(v8WhEYEEz5RuonacSAD1OsxTMxUOUFUnwHvOluFvFuhaEShYPNBgBnMZcmOO9unVbEg3CXHXbg))Xs)3if6461xsxXaK45Zkw6ajkL2UrOfUvPvm13wSwH4vYtv0OQN2sBf7fd1ICmSWWIxORlHPcbnw2S2dqcJSh6x0MQq)ki10665d43ZpI4MTjr9o02LkaqyPIT2WivwpnbiyivJy0f)3X)0dfCYEg4oMtU5Dkhcop8)3hXtq)2)iWNo)4asfxZodq5qIuraEqcmvDlY79UlHxHGO3EPzxLGbwIok3wVpI9ZFseipkeaLeVMADwdqzWatD0)i4GQAMULEjafHSHEC2KX13GMxrmGqxbgew0RCPbTOObM2Eb)N0y9Cctk0P0nmyaZBy58Aj1K56WHBXonIHwahAitz(u1QN3uyoDwUQgamHbMF(9dgwh1(UxLKi4CTdlVu5zVxOOSD2TJAwvYRCNLt1w4PbTkxjFiyJc45MaDxaF(dM1B8bDhjIy8iG7c3f4mSe1NBsxrsJKWJpP(8tAmjiIU099Ul0EK7cBIlUsqTDjxTz1AR4P)y1cKhud32Hgk43aktaDPcgb(A2cEoz(pcFfjm4Ca0fc1Ym)5z(Jrf(x9PqnFhBv2oZXMQDAn1wQH8QuPLQXpOsSBeg04DDQrllFEz0cunuVVTJeqbPhBt1nHvmfm0KfMb(sM)RVI0wANHuM)i0433zqvThdcpqN3EEjnOdb19)RJatpBVsuzZ9rfjxG8sv9DQsBdwqQ0naCMh1NGpK603uDc5KeJuc3yaPHeuM)LfRwNGKAnGKuEUDY4osaLqJ2jbt8IoPHwGoT3hrkLH6Q934(kH6Q3Vz54IMXVI0LlATffFmvFap1VpGgTWTEHbQYzpxAqFqyLxmqLtXwF1UQTysPnQDvcNcD706(MsDx9cg6dNZ6oe6v53wQ86x7qB4DLtaQD5dTIMy)b8TH11Q2YVkIZsHDbY14IjolTvh1QvTPUMIZsDDbu9RmcQ3g(FnOCDBw5mIENVBOM3xRHnb9(oLxFmrFhBljR33PVck76yYmnTNiQK5uLjSvzqbq0ZkG)BYKsBmCkupgQKn8zyO(YUT7XDqA3EC2zgnQx3dj(sopDvxRtQ)mc4UZSDdK1ZuT(oJyX3U2qilgaM5rT(jbQmW9gUaTrC5o9y1t9vcgG2r9HbA(UH(G1ovm1hiM1qBPn57EolBUfI2jLQsmLmkE0MrH9vBukx(1BOZDvVIJ(6ekU5IE8JQL1o8QkxbsFNSvxespwR9lgXsGH6RhsTKf1R87jPDQGQRpDKQ8GWmPYn4O7)28FNdFR7)b]] )

spec:RegisterPack( "Arcane", 20261027.1552, [[Hekili:9MvBRnooq4FllleA5kUjnx72R0u4276XDlSLczH9B2w2rorBvScYYjxlf)B)MrYww2X2j9kSFP4in6zgnV8OrQ(t8)M)8fef1)HlgFXvtgFXN8MC5Lx4px98gQ)8nK4NilHpsjRH)(7YysQE4N5cYcCXzICzmm0kLAt2nNF(sMAvEKxSy95ROsYtmoZ(H)8OCgx9pP(r9O1Sn0y)hUgMLMf7p)p4KSmwCr49ssrOr7fHFvBrBKIegh(4JFS5ufHN0CDtaWpT4lOCZ1wB2nfHnfzTEDlZzGEH1)DXUvuYchPmc8NpoVi88IqfHttv1liribB4XZ)lPidgMKUW8tMeweUNxKDwr43jYyjjrzmLVr2sLPA42j2PII9wUCpfAuWP3uVdFuSJklvXJsAgnnggvKa7Dgo2oW)dg4kkcbdWpn)j6ziWuq9KmflfuJi1IO2y(kd0kNIwzLIU)F3WfzmusWzKwIjMqueYYmq8Si3RC30uHGpu7lIeCLElIUIicNF6EMsEgAERjPqyyjDnAc3VvetuAvR3NAnVt)jrAJYzufIqgybfFHeJYN5TrsHuViI6xMDorVtcyPkkNtJvNXsMfLNK41EcVfIDPJCNksY4Cgb8T656gFmefqKRfsez9hbXReSy6Sjg0QLyaya57bLlmOyfyaqsqVDpWm1aJJidauSi9h5sAagqcK5rpJWzD1vZIbQJy9XmLKLsFpq8dYI316jlbEM3iaOdpIiLmQ0MZ4mwP3ZUwTkZHKjjqFX5nghs5dm)mGZYuNH8OZ0g26LRvUIQvaxe)eQsG9HRw5TjwD7KlhPyRP3nEpHpGfAxgwF(DO6rxUPPQqda4uEIs3a1rRectP4jIu(ZqTQHf7bXwOKejhfrynibgtsjXRqgpOY)upxlsMNU)gDNrROjw(5HDoXcbhn)mCv7VZ7upeHoeJJVLgqtPRz0S7Mn1DHLv2RRy6AKs4WizLWu14oLx(MrFyTyBR9rcWTbHoqge0oMVIjeNgzhdSJ0ggKISZLIPBAIAtKdYDD5jptZrM6WuwhB8SzBAkl4BCXwF7iCiDIwT7OsQayyZ8lOjmOy(Uz2P2s450Uvc1Aw1AP0T1L2SIRvNll8g8SUwCvUksN56OelKOhWu(dqctCIDGx1gqCUuchGFRbupRxg4gYk3XTfPm4OL40QOXXDOmeV4mumi6SgoWdQ5oPRJUxKl1LHnqfcTyflHlWHmNe3sT4PXjejcvItrPNTsQo7x7r7wInLwuGibkbsx0(0stWiFZRFW09tZXPPKioDXRvi2CwjfBni7UPJ7w3ra1jv(ujvXplTcDEeWu6tbkdNI7VP7gGQBQY0auzZpvT5urwczj4pyqiT00W(D(mN9Yle5ctJqCGWkdoweBsstPssxsDIAaxM988ua1gevWKb1tnsrKlPq7lari2RYTZMmE0cA1P9Vqtnhe0Mx8Q2AR0TrR2X6AQJc72ibhUQZGIb38)FugKrTsMAhjkufbZE71rvvW1Y7H8fbzmWGU7624gvfT6kICawChZ3WKxpt55F7fApwhK)C46cySzV7mTJitXKd)5(ZXJeZ03PJMqY5k4Zh03XRmD0)Z(ZnwK)C3Ew8vaS9jxRJPnAjWCJqlDmIW0EqW2AdaMeQ4KmcCHrBlofH3cxs7YIWrqngezkcVRiCmc4VoeGMwDCHS7g12h2lBbBncLrPAn1QDJg79kHbeVQxeD08X5rTmuiUFQxCBMNdAywr40JZUHKue7R7X52QrjxLoCdtApDxnnPN4dyJKBl9x)wp6UUW3vT1RBY4(wyvTO76AwLQxFFfdvLSAH6RsWfkf(ceLxzyOQS231CV81oVmATRS7lKou9A9LoBKV4CJWIqizzsToADn1dvkFySVOg7MxEDOIAN7Noi4tRbV9vA7Q4UMUR1fB7oX25YHDvy3jALxZ9OaSDfDNaIx69OqRVA49Vc8rbxFLLVf(wtTrnl2HRn0DRnugD7wt7RgQQzXIWxFvt4mqpJgzgSXrnT90Xdvou346pFBQV6iBBTMir1PudehQ7iPXjxn7mboLgzngRR(2VdfJYWJwEZkQNUBnhC)Mmc9WDDY4vdLE1U733LtO3uf3oJFFAOxc0dC4zFmJoDg7Uq7b297vTZ0B)1681RhIjTQF7HihpYt37Jn05WDLBlRdKPw9ohD3kNEFx9ugMiwNpEsTCLpGIXV18rugk10(2idyhnJt9yvnEKL96UO(Hwgkdw)CldyiD)8locCI5TP0tz46CFQf91aQsMA8Im1BSUe19Lzkcp1VS7msUAf2jXFx9pFch1))(]] )

spec:RegisterPackSelector( "arcane", "Arcane", "|T135932:0|t Arcane",
    "If you have spent more points in |T135932:0|t Arcane than in any other tree, this priority will be automatically selected for you.",
    function( tab1, tab2, tab3 )
        return tab1 > max( tab2, tab3 )
    end )

spec:RegisterPackSelector( "fire", "Fire", "|T135810:0|t Fire",
    "If you have spent more points in |T135810:0|t Fire than in any other tree, this priority will be automatically selected for you.",
    function( tab1, tab2, tab3 )
        return tab2 > max( tab1, tab3 )
    end )

spec:RegisterPackSelector( "frost", "Frost", "|T135846:0|t Frost",
    "If you have spent more points in |T135846:0|t Frost than in any other tree, this priority will be automatically selected for you.",
    function( tab1, tab2, tab3 )
        return tab3 > max( tab1, tab2 )
    end )
