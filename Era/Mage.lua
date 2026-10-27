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


spec:RegisterPack( "Frost", 20261027.1113, [[Hekili:LMv)VTnop4)wkgqUwCBUnTVTBxVMcSpX7nCR4aYa2V5yzhLeTOifijNCDOW)TFKs2YF7KU9ldowKpKMI8HKDHJd)A405edn8HlV4YBgFXLVoy84Xxfo184wA40TKK1KLWdcYg4F)KsQn4BFKljZrD1YuvcCYkJzR(2ZpFjZSknoirU58vufznJZ8peonoLXn)LimUhJQ3stcF4nWPuDs403ZjAnljl6JkswK14zrFX6pBvYfmo8WlErTtYIoTUwJdgF9zzFgfBQ1x13MfvxKnw9wMYaRc6)n5(vuY8ksvd)p8ptZIoplIt3r5mXYcnFzw03iQefzbi6xj7OkHvU9Y9M4KGLllb06nvTkORzfTIfDh(bMorQM)BGx9w5hF1sftm3ArH0q1NfKfL7BXsoyuMohgr6A6FMfPiI1zrjRKSeQ700TGeYSOhLPboV4lebebws3G(Wh3jtigMuu4p7jI5WZe1gPQaj43VxYHWdKtaWbs4dqpi3rSUkQcOEIuyusoNcIWe5y6IIAQXaFkAWnY(mjbnQoyRIcjoXeZVp5Ciuse0zmHHcaKyEjBXK40flcAEqWC5EXOQhfRyCoJisO2Z6gFmcpZ(HHiBFyM7dCYyhALsmamG89GYLou8cmailWWxpWCLdMkImaqqa)7Pk6SnWT6mvA8JiC(qDXP4T9rOFcZajC0Ffi(oz(VK(KLalXZeamGhtukgv5ZzQ8U8ONxxRjtHKjfq(W51EpHZN5(5motBEjscoX6yBwUXuvuRb4YK1Ojb2dUzvW2eZDJVEKHTHE)fTe(aEyhQLavDZ0qrxJas(BZ1y0PgcNkm1qKkiXqv4OUnvIeWaEO2jk6gctOVF8fJmYLl5qTeDbvOz7O6NqNAhDgvq3WO67HKudrTKc1Iqycl8UBcONhxxYRayhQcR)y4oLotUyg(P4f4QCs7VrY58wGuqyWh4VxtPa1JELuASNDQuWFSbnesSlJrshc8ofLKScP3bQpG4SsyvLkAFjV3zvmsN)4Htmk(E0OwTV(60oePn9Uv8SQIlykm5IOTCGBK7A6nvcFDlXcFpcBi9VXoxqNXxDfek)eGEm89anheggVvdfoLOe05bn9iuh0AN4EDG3gbRf5vyf9xU12GPD)frLUmL4h4lWSS0WZOY(q6i8v2ARYAGcPMbV2DoKRYa(R7N4pAhHNs72iuVBvALtCrXUSMxC0CDJOnZScAEDXpvh1gOlwS6FXtwlLKQuqX7DTcQjWdJ6ou3TM5xrof75s6SQnF9PVLnF3k3tvDlbW4QPqHoM4TbglPBPIbwvQAD10XANNQHg5glvUlDbMD42g1X7ltuWPrDzLsHTs2olIaorUOyQeyIR3A9EiD7F3YLAgklo9rc8dC6L3Xz)4hefiReqvTNPPvY(GksFhzKXQgzlC4SYJ6K0BoTOF9pOIgTQDy3SE9NdL8RiAX34XJ0OMSn306RFigNE(k6wQ4IyDxXxhJuBtFeulfkLto36g74IezFoCkmNog(ATkYEG2dVZdNgof5R12nLOliPCd84d2nNY7Rg(UWPopkCA1HjcnaS9jxJEioRmZTNLNlbr4QEqWpZbaMcQIumcShMF2JSO7ao(RZIgbvpanuw09zrxGa()gcqx7)Qq29euTH96EJi5tOuf02ZV0ar7ppfEtVtZyLOFNBOPASMySZgTMUjl6PNGXhQvKakmjl6kNc1ZTG48epydmYtvBo4OpwbbtDgguVPrqTmcMN6xgNBmGrTeQcHbeFDViw5684st9u5iUVPxC7muEC(nqkGy)h9KAvsuv1EoQiuVXx0BozzCVhv7Ra3ZgzLQVY7cESQGFIlRQnJwiI1u)smdrV0C73wfQDUECzPs3Riperv5AW1UtRSJAwewauAJgloFioSdJ9L1l1RdDFSzv2yEqWVQe8MlzpmRwJvT7HDRCD1UkN7eT8fVpkaBwn3jG4A4hfAnRH7en7s5hfC9v2(CA04QnkzAoCTHDQ1HYOBo76qjOLtWouUMFowN3wW2oGVw2FOgd8aTwAp(IZyif5Z2q9mr7b7V1Pt0)mo9WY(8TqFxpnNc(N3k2x3vNQBgKK5anGgG94a9F6JPOyI6Hk(R1IQVA6FIouLJLoqcxXg3DpzHnmxSuT7kPZ14lLlFvE3Lr915hk3ZVL(a(Xj4FIi7Ald4v1w3FOCr7s)dyTU)JauFAx)rUHqRUzVDE(w3oj2nLh1392bGP6FKGIisFaDMnhajCsnRWEQ))I)BDW3g(F)]] )

spec:RegisterPack( "Fire", 20261027.1113, [[Hekili:LM1AVTnUs0FlzlGxBKaf74nP5geBG(eBxGMTaUa5BsIsM2M1YIguu23ueOF77mKIsupTl6hsGI4W5jNZCeJ7e3V7UyjrsDF6MX3C3KX38wNjtMm1DH8L9u3f7jHBjRHhIj7GF)zMq9YxI4KL4wt4PIq4vBKY9jpC91RzYnPboH8DxVHkiBzrSIhCxeKYIKFj2nOdBMSNg6(09WQ0Kq3fFiIKKWcZ8)KGK5J2oZ)RkVzVGVIfbp8M3yVqM)WQ7zIZKBhL9pOuluEAYdz(vfzNAFRtzGnH9)m)4gkzPLu2Q)JFBrUSxL5)mrekiRKz(FNCGkIZ8VoZ)i)Omi0z9AlnyBIR0EJCdTHaFKLeYfl)tWneeg4cXCjnze4XyEd(Bsm8RTu6(m)BZ8)YoilCGcVAbSTWnz(jsOAbwq5YbKOORmE)7blb(jeAXO1IH4gwMF04oFGVlinrY4WY4pHCE0s(XyqbF7fbpqVDEC0lWgtqpb(R90yQWjp7w3fubO9Evsx1HWiv7mYncAYgWMxzEZA6ounF6apKO9lv0Ru7r1JKYYscvkzXRtaNj7FiHO8jo7fu4yyarE5SRHkfjM6XIL0OiAO8k2QzbPRw5uFbhmQhyVuGGffXiXHu1ATRFSa6re74cuZQh8c3WzH0zt0ARuIEudiFhA5gTwkeOhLSsWtKDOMPA1yjspkkKh)Jub1dliEI0Gxq1vKQnRIfQZy)HmPGft)DuXpil)T2pznG58lQamHhqecgvuCMX6D5zpSd4FvhWFOYHEipVdo6NIN)xHDvOwbqMChiZ)pSewRG)yKt7EYEJKvIGI36PBWSAauHFkCWwaWQrrvEp087P)tVigOseDFMkjTB9oPTOQGnIhUfnlGmgj34Spu(4KBhiz7OZh3q4tKTk2gM0Eg6KvjIvCHUZ)bdchahW1jPHACNpJhAZ8FIFarVaP5biEaMqfus4ge((fEQv(d8irACZa9O2QOlM)4PtogeXeCxnJ8ZR6myiUZzJFvLzGQBcfWv84R82XIx6KUF0j9DcxDegF)bQhO0DmAY8zt15Z6ZekNDi5QHgf4Zc6keYfwNc5EQkJAgBGtXsXnfrHKld(zPGVVsEnrPEvWQEYdsKs6YbxSJFac9bsIynv6GHRNK7TKrNpz8GHlPA8hWqEhsJGucjaygiFXr5ypE7RDlHGUJWItEu7ekjqN1jeZVOHUmFfThz9(Xo3wjXQuEr1s7XVIh(Wt2ZllFLYPbqGvRRgv6Q18Yf19ZTXkScDH6R6J6aWJ9qo9CZyRXCwGbfTNQ5nWZ4MlomoW4)pw6)gPqhxV(s6kgGepFwXshirP02ncTWTkTIP(2I1keVsEQIgv90wARyVyOwKJHfgw8cDDjmviOXYM1EasyK9q)I2uf6xbPMwxpFa)E(re3SnjQ3H2UubaclvS1ggPY6PjabdPAeJU4)o(NEOGt2Za3XCYnVt5qW5H))(iEc63(hb(05hhqQ4A2zakhsKkcWdsGPQBrEV3Dj8keeD6LMDvcgyj6OCB9(i2p)jrG8Oqaus8AQ1znaLbdm1r)JGdQQz6w6LaueYg6XztgxFdAEfXacDfyqyrVYLg0IIgyA7f8FsJ1ZjmPqNs3WGbmVHLZRLutMRdhUf70igAbCOHmL5tvREEtH50z5QAaWegy(53pyyDu77EvsIGZ1oS8sLN9EHIY2zth1SQKx5olNQTWtdAvUs(qWgfWZnb6Ua(8hmR34d6oseX4ra3fUlWzyjQp3KUIKgjHhFs95N0ysqeDP77DxO9i3f2exCLGA7sUAZQ1wXt)XQfipOgM2Hgk43aktaDPcgb(A2cEoz(pcFfjm4Ca0fc1Ym)5z(Jrf(x9PqnFhBv2oZXMQ92AQTud5vPslvJFqLy3imOX76uJww(8YOfOAOEFBhjGcsp2MQBcRykyOjlmd8Lm)xFfPT0odPm)rOXVVZGQApgeEGoNEEjnOdb19)RJatpBVsuzZ9rfjxG8sv9DQsBdwqQ0naCMh1NGpK603T6eYjjgPeUXasdjOm)llwTobj1AajP8C7KXDKakHgTtcM4fDsdTaDAVpIukd1v7VX9vc1vVFZYXfnJFfPlx0Alk(yQ(aEQFFanAHB9cduLZEU0G(GWkVyGkNIT(QDvBXKsBu7Qeof62P19nL6U6fm0hoN1Di0RYNwQ86x7qB4DLtaQD5dTIMy)b8TH11Q2YVkIZsHDbY14IjolTvh1QvTPUMIZsDDbu9RmcQ3g(FnOCDBw5mIENVBOM3xRHnb9(oLxFmrFhBljR33PVck76yYmnTNiQK5uLjSvzqbq0ZkG)BYKsBmCkupgQKn8zyO(YUT7XDqA3EC2zgnQx3dj(sopDvxRtQ)mc4UZSDdK1ZuT(oJyX3U2qilgaM5rT(jbQmW9gUaTrC5o9y1t9vcgG2r9HbA(UH(G1ovm1hiM1qBPn57EolBUfI2jLQsmLmkE0MrH9vBukx(1BOZDvVIJ(6ekU5IE8JQL1o8QkxbsFNSvxespwR9lgXsGH6RhsTKf1R87jPDQGQRpDKQ8GWmPYn4O7)28FNdFR7)n]] )

spec:RegisterPack( "Arcane", 20261027.1113, [[Hekili:9MvBpnooq4FlRwPkqhk0spy5quKU9ooD3kTiK6kTFljoPUTEXnUYXHEGq53(nJDITtAsOCiTFbLAp(zgpV84XMWjHFlC(cIIgE3zJp7IjJp7tbtMmzA4C1tBPHZ3ssFGSc(iJSb(7Vltjz6HFIlilWfNlkKPWqRvQT5xD6PRyQ1fjbPInNUMkjpW4m7hHZtkyC1)KfM0JwZ3stdV7sywAEA48)GtYZzPLX3kjLXgTxg)vTfTvkwY4WhF8JnNQm(OMRBsWKZpU8lOCZ1wB(vLXnfzJEDRkyGEH1)DXU1uYcpPmc8N3pVm(0YyfHtZuUfSuibB4(t)lPihgMKTW8tMeweUNxKFsz83jYujzPYykFJ8ivMPHBNyNkjny1Q9uOrbhFLBhEVyhvwPI7L0CAwkmQyjS3z4y7a)pyGRPiema)SIhONGatb1tYvSmqnImlIAJ5RmqRCkAL1k62)DlxKZqjbNrwfMycrzml3aXtIIGQDttfc(qTVirWv6Ti6ksiC(X7zkf5O5THKbHHv0nOjC7JIuIsRA9(uR5D6pjsBuoNQqeYblO8lKuu(8GTskK6Lqu)YStj6Dseltr5CAQ6e2Yzjflxg0EIGfIDzJ8NkrY4Cgb8T656gFmefrKBesez9hrPRfSu6Sjg0CsmamG89GYzguScmailrVDpWm1aJNidauQi7hfsAegqIKfjpHWzD11ZIbQdy9PmLKLrFpq8dYI316jRaEM3iaOdpHiLmQ0MZ4nwL3ZUwTklGKjjqFX5nghs5Jm)mIZYvNG8OZ0g2MvBu(IQvaxK(aQsG9HRwhSnvD9KZhPyBO3mEpHFfl0UmS(87q1JUCttvHgaWP8aLUfQJwleMsXJez8NGAvdl2DIhHssKCuKG1GeymjLKUgz8Gk)Jd8Tizr2(B0DgTIMy1NVUZjvi4O5NJRA)DEN6Hi0HyC8hPr0m6ggn)Mzt9xyvL9MAMUgPeEmswjmvn(tfuSD0h2iES1(yjWTbHoqge0oMVMjeNgzhJSJ0ggKISZLIPBAIAtKdYD95jprZrM5Xu6Inb2SnnLf8nUyRVDeoKorZ5oQLkcg2m)c6sgumFZm7ups4f0Uvc1AwoTu526sBwX1QZNfElEwxlUkFfPZC9uIfs0dyk)biHjoYoWlAdiTqkHdWV2aAG1ldCd5v742IufC0sCCD04WougIxCgkgeD2ah4b1Ch11r3lkK6YWgOcHwSILWf4qMtIBPw804Lejc1sVIYaBLKl7x7r7wITvwuKyjucKTO9PLMGrX2x(GP7NMJtZijC6IxQrS5Ssk2Aq(nth3TUtaQtQ8HkQIFwAf68iIP0Ncufof3Ev3na5AQY0auvZp1T5utwczj4pyqiTY0W(D(mN98Ze5ctJqCGWkhoweBsstPsYwr9IAaxM988ma1gevWKrUPgPiYvuO9fGie7v56ztgpAbT(0(NPzMdcAZlErBTv52O17yDn1bHDBKGdx1zqPGB()pkdYOwlJZrIcvtWS3EDuDfSt(aKVikNbg0nx2g3K6OvxrKxHf3Z8nm5UzQo)BVq7H6GcNdxxaJn7DNPDezgMCeopCoEKyU(oD0LKcUc(8o9D8Qshd)C4CJffo3VNLqfaBFY16yAJwIm3i0shJimTheST2aGjHkojJaxy02Itz81WL0oVmEeuJbrMY4BkJhJa(RdbOPvhFi7UrT9H98wW6qOkk50uR2nAS3Rfgq8IEr0tZhMh1YqH4(PEXTzEoOHzLXtpm7gssrSVShNBRgL8v6WnmP90D10KEIpGns(yL)636r3UcFF16w3KX9TW6Ar)11SkvV((kgQlz1c1xLGpuk8fiQUYWqvzTVR5E5RDEzuNRS7lKou9Q7sNnYx8UryzmKSmXPJwxt91kLFDSpZHDZlVourT39the8PoWBFL2UkUD0DTUyB3j2ExoSRc7orR6AUheGTRO7eq8sVheA9vdV)vGpi46RS8TW3AQnCSyVETHUBTHYOB3AAF1q1nlwg)YlAcNb6z0iZGnoQPTNoEOYbxJR)8TP(QJST1AIe1NsnqCW1rsJtUA2zcCknYAmwx9TFhkgLHhT8MvupD3Ao4(nze6H76KXlgk9QD3VVlNqVPk(Dg)(0qVeOVYHN9Xm61zS)cThy3Vx1otV9xRZxVCiM06(ThIC8apDVp2qVd3v(TSoqMA97C0DRC69D9tzyIyD(4jo5QEafJFR5JOmuQP9TrgWoAgN6XQA8il71DH7Hwgkdw)CldyiD)8lEcCK5TP0tz468FQf91aQtMA8ImUnwxI6)YmLXhhw1DgPqTg7K4VR)NpHJg(F]] )

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
