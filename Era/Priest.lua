-- Era/Priest.lua
-- Classic Era (1.15.x) Priest.  Spell, rank, talent and aura IDs, mana costs, cooldowns, durations and tick
-- intervals come from the Classic Era client tables (build 1.15.9).

if UnitClassBase( 'player' ) ~= 'PRIEST' then return end

local addon, ns = ...
local Hekili = _G[ addon ]
local class, state = Hekili.Class, Hekili.State

local GetSpellPowerCost = _G.GetSpellPowerCost or ( C_Spell and C_Spell.GetSpellPowerCost )

local spec = Hekili:NewSpecialization( 5 )


-- Fallback per-rank mana costs, copied from the Era client's SpellPower table (build 1.15.9); the live client's
-- GetSpellPowerCost is used first (it includes talents such as Mental Agility).
local mana_cost = {
    -- Shadow Word: Pain
    [589] = 25, [594] = 50, [970] = 95, [992] = 155, [2767] = 230, [10892] = 305, [10893] = 385, [10894] = 470,
    -- Mind Blast
    [8092] = 50, [8102] = 80, [8103] = 110, [8104] = 150, [8105] = 185, [8106] = 225, [10945] = 265, [10946] = 310, [10947] = 350,
    -- Mind Flay
    [15407] = 45, [17311] = 70, [17312] = 100, [17313] = 135, [17314] = 165, [18807] = 205,
    -- Smite
    [585] = 20, [591] = 30, [598] = 60, [984] = 95, [1004] = 140, [6060] = 185, [10933] = 230, [10934] = 280,
    -- Holy Fire
    [14914] = 85, [15262] = 95, [15263] = 125, [15264] = 145, [15265] = 170, [15266] = 200, [15267] = 230, [15261] = 255,
    -- Holy Nova
    [15237] = 185, [15430] = 290, [15431] = 400, [27799] = 520, [27800] = 635, [27801] = 750,
    -- Inner Fire
    [588] = 30, [7128] = 65, [602] = 105, [1006] = 165, [10951] = 235, [10952] = 315,
    -- Devouring Plague (Undead)
    [2944] = 215, [19276] = 350, [19277] = 495, [19278] = 645, [19279] = 810, [19280] = 985,
    -- Starshards (Night Elf)
    [10797] = 50, [19296] = 85, [19299] = 140, [19302] = 190, [19303] = 245, [19304] = 300, [19305] = 350,
    -- Touch of Weakness (Undead)
    [2652] = 25, [19261] = 45, [19262] = 75, [19264] = 105, [19265] = 145, [19266] = 195,
    -- Shadowguard (Troll)
    [18137] = 50, [19308] = 85, [19309] = 120, [19310] = 160, [19311] = 200, [19312] = 250,
    -- Hex of Weakness (Troll)
    [9035] = 35, [19281] = 55, [19282] = 90, [19283] = 130, [19284] = 180, [19285] = 240,
}

-- Smite's cast time rises with rank: 1.5 sec (rank 1), 2 sec (rank 2), 2.5 sec (rank 3+).
local smite_cast = { [585] = 1.5, [591] = 2 }

local function known_id( key )
    local ability = class.abilities[ key ]
    return ability and ability.id
end

-- Mana cost of the known rank of an ability: the client's cost (refreshed every 10 seconds), otherwise the table
-- above with Mental Agility (-2% per rank on instant spells).  Inner Focus makes the next spell free.
local cost_cache = {}

local function client_cost( id )
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

local function cost( key, instant, pct )
    if state.buff.inner_focus.up then return 0 end
    local id = known_id( key )
    if not id then return 0 end
    local c = client_cost( id )
    if c then return c end
    -- Fallback: a percentage of base mana (spend < 1) or the per-rank table.
    c = pct or mana_cost[ id ] or 0
    if instant then c = c * ( 1 - 0.02 * state.talent.mental_agility.rank ) end
    return c
end


spec:RegisterResource( Enum.PowerType.Mana )


-- Talents: { talentID, maxRank, rank1SpellID, ... rankNSpellID }, from the Classic Era client's Talent table.
spec:RegisterTalents( {
    -- Discipline
    unbreakable_will              = {   342, 5, 14522, 14788, 14789, 14790, 14791 },
    wand_specialization           = {   345, 5, 14524, 14525, 14526, 14527, 14528 },
    silent_resolve                = {   352, 5, 14523, 14784, 14785, 14786, 14787 },
    improved_power_word_fortitude = {   344, 2, 14749, 14767 },
    improved_power_word_shield    = {   343, 3, 14748, 14768, 14769 },
    martyrdom                     = {   321, 2, 14531, 14774 },
    inner_focus                   = {   348, 1, 14751 },
    meditation                    = {   347, 3, 14521, 14776, 14777 },
    improved_inner_fire           = {   346, 3, 14747, 14770, 14771 },
    mental_agility                = {   341, 5, 14520, 14780, 14781, 14782, 14783 },
    improved_mana_burn            = {   350, 2, 14750, 14772 },
    mental_strength               = {  1201, 5, 18551, 18552, 18553, 18554, 18555 },
    divine_spirit                 = {   351, 1, 14752 },
    force_of_will                 = {  1202, 5, 18544, 18547, 18548, 18549, 18550 },
    power_infusion                = {   322, 1, 10060 },

    -- Holy
    healing_focus                 = {   410, 2, 14913, 15012 },
    improved_renew                = {   406, 3, 14908, 15020, 17191 },
    holy_specialization           = {   401, 5, 14889, 15008, 15009, 15010, 15011 },
    spell_warding                 = {   411, 5, 27900, 27901, 27902, 27903, 27904 },
    divine_fury                   = {  1181, 5, 18530, 18531, 18533, 18534, 18535 },
    holy_nova                     = {   442, 1, 15237 },
    blessed_recovery              = {  1636, 3, 27811, 27815, 27816 },
    inspiration                   = {   361, 3, 14892, 15362, 15363 },
    holy_reach                    = {  1635, 2, 27789, 27790 },
    improved_healing              = {   408, 3, 14912, 15013, 15014 },
    searing_light                 = {   403, 2, 14909, 15017 },
    improved_prayer_of_healing    = {   413, 2, 14911, 15018 },
    spirit_of_redemption          = {  1561, 1, 20711 },
    spiritual_guidance            = {   402, 5, 14901, 15028, 15029, 15030, 15031 },
    spiritual_healing             = {   404, 5, 14898, 15349, 15354, 15355, 15356 },
    lightwell                     = {  1637, 1, 724 },

    -- Shadow
    spirit_tap                    = {   465, 5, 15270, 15335, 15336, 15337, 15338 },
    blackout                      = {   464, 5, 15268, 15323, 15324, 15325, 15326 },
    shadow_affinity               = {   466, 3, 15318, 15272, 15320 },
    improved_shadow_word_pain     = {   482, 2, 15275, 15317 },
    shadow_focus                  = {   463, 5, 15260, 15327, 15328, 15329, 15330 },
    improved_psychic_scream       = {   542, 2, 15392, 15448 },
    improved_mind_blast           = {   481, 5, 15273, 15312, 15313, 15314, 15316 },
    mind_flay                     = {   501, 1, 15407 },
    improved_fade                 = {   483, 2, 15274, 15311 },
    shadow_reach                  = {   881, 3, 17322, 17323, 17325 },
    shadow_weaving                = {   461, 5, 15257, 15331, 15332, 15333, 15334 },
    silence                       = {   541, 1, 15487 },
    vampiric_embrace              = {   484, 1, 15286 },
    improved_vampiric_embrace     = {  1638, 2, 27839, 27840 },
    darkness                      = {   462, 5, 15259, 15307, 15308, 15309, 15310 },
    shadowform                    = {   521, 1, 15473 },
} )


-- Auras
spec:RegisterAuras( {
    -- Racial (Troll): casting speed increased.
    berserking = {
        id = 26635,
        duration = 10,
        max_stack = 1,
    },
    devouring_plague = {
        id = 19280,
        duration = 24,
        tick_time = 3,
        max_stack = 1,
        copy = { 2944, 19276, 19277, 19278, 19279, 19280 },
    },
    hex_of_weakness = {
        id = 19285,
        duration = 120,
        max_stack = 1,
        copy = { 9035, 19281, 19282, 19283, 19284, 19285 },
    },
    holy_fire = {
        id = 15261,
        duration = 10,
        tick_time = 2,
        max_stack = 1,
        copy = { 14914, 15262, 15263, 15264, 15265, 15266, 15267, 15261 },
    },
    inner_fire = {
        id = 10952,
        duration = 600,
        max_stack = 1,
        copy = { 588, 7128, 602, 1006, 10951, 10952 },
    },
    -- The mana cost of your next spell is reduced by 100%.
    inner_focus = {
        id = 14751,
        duration = 3600,
        max_stack = 1,
    },
    mind_flay = {
        id = 18807,
        duration = 3,
        tick_time = 1,
        max_stack = 1,
        copy = { 15407, 17311, 17312, 17313, 17314, 18807 },
    },
    power_infusion = {
        id = 10060,
        duration = 15,
        max_stack = 1,
    },
    power_word_fortitude = {
        id = 10938,
        duration = 1800,
        max_stack = 1,
        shared = "player",
        copy = { 1243, 1244, 1245, 2791, 10937, 10938 },
    },
    shadow_word_pain = {
        id = 10894,
        duration = function() return 18 + 3 * talent.improved_shadow_word_pain.rank end,
        tick_time = 3,
        max_stack = 1,
        copy = { 589, 594, 970, 992, 2767, 10892, 10893, 10894 },
    },
    -- Shadow Weaving: Shadow damage taken increased by 2% per stack (target debuff "Shadow Vulnerability").
    shadow_weaving = {
        id = 15258,
        duration = 15,
        max_stack = 5,
        shared = "target",
    },
    shadowform = {
        id = 15473,
        duration = 3600,
        max_stack = 1,
    },
    shadowguard = {
        id = 19312,
        duration = 600,
        max_stack = 3,
        copy = { 18137, 19308, 19309, 19310, 19311, 19312 },
    },
    -- Pseudo-aura: the wand (Shoot) is auto-repeating.
    shooting = {
        duration = 3600,
        max_stack = 1,
    },
    silence = {
        id = 15487,
        duration = 5,
        max_stack = 1,
    },
    starshards = {
        id = 19305,
        duration = 6,
        tick_time = 1,
        max_stack = 1,
        copy = { 10797, 19296, 19299, 19302, 19303, 19304, 19305 },
    },
    touch_of_weakness = {
        id = 19266,
        duration = 600,
        max_stack = 1,
        copy = { 2652, 19261, 19262, 19264, 19265, 19266 },
    },
    vampiric_embrace = {
        id = 15286,
        duration = 60,
        max_stack = 1,
        shared = "target",
    },
} )


-- Shadow Weaving at 5/5 applies a stack with every Shadow hit; lower ranks are a chance, so not predicted.
spec:RegisterStateFunction( "shadow_weave", function()
    if talent.shadow_weaving.rank == 5 then
        applyDebuff( "target", "shadow_weaving", nil, min( 5, debuff.shadow_weaving.stack + 1 ) )
    end
end )

-- Priests can only equip a wand in the ranged slot.
spec:RegisterStateExpr( "wand_equipped", function()
    return GetInventoryItemID( "player", 18 ) ~= nil
end )

-- Whether the Vampiric Embrace setting applies to the current group.
spec:RegisterStateExpr( "vampiric_embrace_wanted", function()
    local mode = settings.vampiric_embrace
    if mode == "always" then return true end
    if mode == "group" then return group end
    if mode == "raid" then return raid end
    return false
end )

-- Below the wand threshold: hold mana for Shadow Word: Pain and use the wand as the filler.
spec:RegisterStateExpr( "wand_phase", function()
    local pct = settings.wand_mana_pct or 0
    return pct > 0 and mana.pct < pct and wand_equipped
end )


local ShootName

spec:RegisterHook( "reset_precast", function()
    -- Shadowform is the priest's only shapeshift form.
    if buff.shadowform.down and ( GetShapeshiftForm() or 0 ) > 0 then applyBuff( "shadowform" ) end

    ShootName = ShootName or GetSpellInfo( 5019 )
    if ShootName and IsAutoRepeatSpell( ShootName ) then applyBuff( "shooting" ) end
end )


-- Abilities
spec:RegisterAbilities( {
    -- Racial (Troll): increases casting and attack speed by 10% to 30%, more at low health.
    berserking = {
        id = 20554,
        cast = 0,
        cooldown = 180,
        gcd = "off",

        spend = function() return cost( "berserking", false, 0.07 ) end,
        spendType = "mana",

        startsCombat = false,
        texture = 135727,

        toggle = "cooldowns",

        usable = function() return race.troll, "requires troll" end,

        handler = function()
            applyBuff( "berserking" )
        end,
    },


    -- Racial (Undead): a disease that deals Shadow damage over 24 sec and heals you for the damage.
    devouring_plague = {
        id = 19280,
        cast = 0,
        cooldown = 180,
        gcd = "spell",

        spend = function() return cost( "devouring_plague", true ) end,
        spendType = "mana",

        startsCombat = true,
        texture = 136123,

        usable = function() return race.undead, "requires undead" end,

        handler = function()
            removeBuff( "inner_focus" )
            applyDebuff( "target", "devouring_plague" )
            shadow_weave()
        end,

        copy = { 2944, 19276, 19277, 19278, 19279 }
    },


    -- Racial (Troll): weakens the target, reducing its damage and the healing it receives for 2 min.
    hex_of_weakness = {
        id = 19285,
        cast = 0,
        cooldown = 0,
        gcd = "spell",

        spend = function() return cost( "hex_of_weakness", true ) end,
        spendType = "mana",

        startsCombat = true,
        texture = 136157,

        usable = function() return race.troll, "requires troll" end,

        handler = function()
            removeBuff( "inner_focus" )
            applyDebuff( "target", "hex_of_weakness" )
        end,

        copy = { 9035, 19281, 19282, 19283, 19284 }
    },


    -- Holy damage to the target plus more over 10 sec.  Not usable in Shadowform.
    holy_fire = {
        id = 15261,
        cast = function() return 3.5 - 0.1 * talent.divine_fury.rank end,
        cooldown = 0,
        gcd = "spell",

        spend = function() return cost( "holy_fire" ) end,
        spendType = "mana",

        startsCombat = true,
        texture = 135972,

        usable = function() return buff.shadowform.down, "not usable in shadowform" end,

        handler = function()
            removeBuff( "inner_focus" )
            applyDebuff( "target", "holy_fire" )
        end,

        copy = { 14914, 15262, 15263, 15264, 15265, 15266, 15267 }
    },


    -- Holy damage to all enemies within 10 yards (and heals the party).  Not usable in Shadowform.
    holy_nova = {
        id = 27801,
        cast = 0,
        cooldown = 0,
        gcd = "spell",

        spend = function() return cost( "holy_nova", true ) end,
        spendType = "mana",

        talent = "holy_nova",
        startsCombat = true,
        texture = 135922,

        usable = function() return buff.shadowform.down, "not usable in shadowform" end,

        handler = function()
            removeBuff( "inner_focus" )
        end,

        copy = { 15237, 15430, 15431, 27799, 27800 }
    },


    inner_fire = {
        id = 10952,
        cast = 0,
        cooldown = 0,
        gcd = "spell",

        spend = function() return cost( "inner_fire", true ) end,
        spendType = "mana",

        startsCombat = false,
        texture = 135926,

        handler = function()
            removeBuff( "inner_focus" )
            applyBuff( "inner_fire" )
        end,

        copy = { 588, 7128, 602, 1006, 10951 }
    },


    -- Your next spell costs no mana and has 25% more critical strike chance.
    inner_focus = {
        id = 14751,
        cast = 0,
        cooldown = 180,
        gcd = "off",

        talent = "inner_focus",
        startsCombat = false,
        texture = 135863,

        nobuff = "inner_focus",

        handler = function()
            applyBuff( "inner_focus" )
        end,
    },


    mind_blast = {
        id = 10947,
        cast = 1.5,
        cooldown = function() return 8 - 0.5 * talent.improved_mind_blast.rank end,
        gcd = "spell",

        spend = function() return cost( "mind_blast" ) end,
        spendType = "mana",

        startsCombat = true,
        texture = 136224,

        handler = function()
            removeBuff( "inner_focus" )
            shadow_weave()
        end,

        copy = { 8092, 8102, 8103, 8104, 8105, 8106, 10945, 10946 }
    },


    -- Channelled for 3 sec, one Shadow damage tick per second.
    mind_flay = {
        id = 18807,
        cast = 3,
        channeled = true,
        breakable = true,
        cooldown = 0,
        gcd = "spell",

        spend = function() return cost( "mind_flay" ) end,
        spendType = "mana",

        talent = "mind_flay",
        startsCombat = true,
        texture = 136208,

        aura = "mind_flay",
        tick_time = 1,

        start = function()
            removeBuff( "inner_focus" )
            applyDebuff( "target", "mind_flay" )
        end,

        tick = function()
            shadow_weave()
        end,

        breakchannel = function()
            removeDebuff( "target", "mind_flay" )
        end,

        handler = function()
        end,

        copy = { 15407, 17311, 17312, 17313, 17314 }
    },


    power_infusion = {
        id = 10060,
        cast = 0,
        cooldown = 180,
        gcd = "off",

        spend = function() return cost( "power_infusion", true, 0.2 ) end,
        spendType = "mana",

        talent = "power_infusion",
        startsCombat = false,
        texture = 135939,

        toggle = "cooldowns",

        handler = function()
            applyBuff( "power_infusion" )
        end,
    },


    -- Shadow damage over 18 sec (21/24 with Improved Shadow Word: Pain).
    shadow_word_pain = {
        id = 10894,
        cast = 0,
        cooldown = 0,
        gcd = "spell",

        spend = function() return cost( "shadow_word_pain", true ) end,
        spendType = "mana",

        startsCombat = true,
        texture = 136207,

        cycle = "shadow_word_pain",

        handler = function()
            removeBuff( "inner_focus" )
            applyDebuff( "target", "shadow_word_pain" )
            shadow_weave()
        end,

        copy = { 589, 594, 970, 992, 2767, 10892, 10893 }
    },


    -- Shadow damage +15%, physical damage taken -15%; Holy spells can't be cast.
    shadowform = {
        id = 15473,
        cast = 0,
        cooldown = 1.5,
        gcd = "spell",

        spend = function() return cost( "shadowform", true, 0.4 ) end,
        spendType = "mana",

        talent = "shadowform",
        startsCombat = false,
        texture = 136200,

        nobuff = "shadowform",

        handler = function()
            removeBuff( "inner_focus" )
            applyBuff( "shadowform" )
        end,
    },


    -- Racial (Troll): shadows strike attackers that hit you.
    shadowguard = {
        id = 19312,
        cast = 0,
        cooldown = 0,
        gcd = "spell",

        spend = function() return cost( "shadowguard", true ) end,
        spendType = "mana",

        startsCombat = false,
        texture = 136051,

        usable = function() return race.troll, "requires troll" end,

        handler = function()
            removeBuff( "inner_focus" )
            applyBuff( "shadowguard", nil, 3 )
        end,

        copy = { 18137, 19308, 19309, 19310, 19311 }
    },


    -- Wand auto-attack.
    shoot = {
        id = 5019,
        cast = 0,
        cooldown = 0,
        gcd = "spell",

        startsCombat = true,
        texture = 132317,

        nobuff = "shooting",

        usable = function() return wand_equipped, "requires a wand" end,

        handler = function()
            applyBuff( "shooting" )
        end,
    },


    -- Silences the target for 5 sec.
    silence = {
        id = 15487,
        cast = 0,
        cooldown = 45,
        gcd = "spell",

        spend = function() return cost( "silence", false, 225 ) end,
        spendType = "mana",

        talent = "silence",
        startsCombat = true,
        texture = 136164,

        toggle = "interrupts",

        debuff = "casting",
        readyTime = state.timeToInterrupt,

        handler = function()
            removeBuff( "inner_focus" )
            interrupt()
            applyDebuff( "target", "silence" )
        end,
    },


    smite = {
        id = 10934,
        cast = function() return ( smite_cast[ known_id( "smite" ) ] or 2.5 ) - 0.1 * talent.divine_fury.rank end,
        cooldown = 0,
        gcd = "spell",

        spend = function() return cost( "smite" ) end,
        spendType = "mana",

        startsCombat = true,
        texture = 135924,

        usable = function() return buff.shadowform.down, "not usable in shadowform" end,

        handler = function()
            removeBuff( "inner_focus" )
        end,

        copy = { 585, 591, 598, 984, 1004, 6060, 10933 }
    },


    -- Racial (Night Elf): channelled Arcane damage over 6 sec.
    starshards = {
        id = 19305,
        cast = 6,
        channeled = true,
        breakable = true,
        cooldown = 0,
        gcd = "spell",

        spend = function() return cost( "starshards" ) end,
        spendType = "mana",

        startsCombat = true,
        texture = 135753,

        aura = "starshards",
        tick_time = 1,

        usable = function() return race.night_elf, "requires night elf" end,

        start = function()
            removeBuff( "inner_focus" )
            applyDebuff( "target", "starshards" )
        end,

        breakchannel = function()
            removeDebuff( "target", "starshards" )
        end,

        handler = function()
        end,

        copy = { 10797, 19296, 19299, 19302, 19303, 19304 }
    },


    -- Racial (Undead): the next melee attacker takes Shadow damage and deals less damage.
    touch_of_weakness = {
        id = 19266,
        cast = 0,
        cooldown = 0,
        gcd = "spell",

        spend = function() return cost( "touch_of_weakness", true ) end,
        spendType = "mana",

        startsCombat = false,
        texture = 136143,

        usable = function() return race.undead, "requires undead" end,

        handler = function()
            removeBuff( "inner_focus" )
            applyBuff( "touch_of_weakness" )
        end,

        copy = { 2652, 19261, 19262, 19264, 19265 }
    },


    -- Party members are healed for 20% of the Shadow damage you deal to the target for 1 min.
    vampiric_embrace = {
        id = 15286,
        cast = 0,
        cooldown = 10,
        gcd = "spell",

        spend = function() return cost( "vampiric_embrace", true, 40 ) end,
        spendType = "mana",

        talent = "vampiric_embrace",
        startsCombat = true,
        texture = 136230,

        handler = function()
            removeBuff( "inner_focus" )
            applyDebuff( "target", "vampiric_embrace" )
            shadow_weave()
        end,
    },
} )


-- Settings
spec:RegisterSetting( "priest_description", nil, {
    type = "description",
    name = "Herakili recommends damage spells only; healing and buffs for others are up to you.  Holy and Discipline " ..
        "priests get the same damage priority (Smite, Holy Fire and Shadow Word: Pain when out of Shadowform)."
} )

spec:RegisterSetting( "mana_header", nil, {
    type = "header",
    name = "Mana"
} )

spec:RegisterSetting( "wand_mana_pct", 20, {
    type = "range",
    name = "Wand Below Mana %",
    desc = "Below this mana percentage (with a wand equipped), the wand (Shoot) becomes your filler: Mind Blast and " ..
        "Mind Flay / Smite are held, Shadow Word: Pain is still kept up, and Inner Focus is used for a free Mind Blast.\n\n" ..
        "Set to 0 to never switch to the wand.  While leveling, a higher value (40-60) saves downtime.",
    width = "full",
    min = 0,
    max = 100,
    step = 1,
} )

spec:RegisterSetting( "inner_focus_mind_blast", true, {
    type = "toggle",
    name = "Inner Focus With Mind Blast",
    desc = "When enabled, Inner Focus is recommended right before Mind Blast whenever it is ready (a free, more likely " ..
        "critical Mind Blast).  Disable it to save Inner Focus for a heal.",
    width = "full",
} )

spec:RegisterSetting( "smite_filler", true, {
    type = "toggle",
    name = "Smite As Filler (without Mind Flay)",
    desc = "When enabled, Smite is the filler when Mind Flay is not available (Holy / Discipline, or below level 20).  " ..
        "Disable it to use the wand as the filler instead, which saves mana while leveling.",
    width = "full",
} )

spec:RegisterSetting( "shadow_header", nil, {
    type = "header",
    name = "Shadow"
} )

spec:RegisterSetting( "mind_blast_clip", true, {
    type = "toggle",
    name = "Clip Mind Flay For Mind Blast",
    desc = "When enabled, Mind Flay is cut short after a tick when Mind Blast comes off cooldown (or Shadow Word: Pain " ..
        "has fallen off).  When disabled, Mind Flay is always channelled in full.",
    width = "full",
} )

spec:RegisterSetting( "vampiric_embrace", "group", {
    type = "select",
    name = "Vampiric Embrace",
    desc = "When to keep Vampiric Embrace on your target (it heals your party for 20% of your Shadow damage).",
    width = "full",
    values = {
        none = "Never",
        raid = "In raids",
        group = "In a party or raid",
        always = "Always (also solo)",
    },
} )

spec:RegisterSetting( "aoe_header", nil, {
    type = "header",
    name = "Multiple Targets"
} )

spec:RegisterSetting( "swp_multidot", true, {
    type = "toggle",
    name = "Spread Shadow Word: Pain",
    desc = "When enabled and several enemies are detected, Shadow Word: Pain is recommended on up to 3 other targets " ..
        "that will live long enough.",
    width = "full",
} )

spec:RegisterSetting( "holy_nova_targets", 3, {
    type = "range",
    name = "Holy Nova Minimum Targets",
    desc = "With the Holy Nova talent and outside Shadowform, Holy Nova is recommended when at least this many enemies are " ..
        "within 10 yards.  Set to 0 to never recommend it.",
    width = "full",
    min = 0,
    max = 10,
    step = 1,
} )

spec:RegisterSetting( "cooldowns_header", nil, {
    type = "header",
    name = "Cooldowns"
} )

spec:RegisterSetting( "power_infusion_self", false, {
    type = "toggle",
    name = "Power Infusion On Yourself",
    desc = "When enabled, Power Infusion is recommended on yourself with your cooldowns.  Usually it is better given to a mage.",
    width = "full",
} )


spec:RegisterOptions( {
    enabled = true,

    aoe = 3,
    gcd = 585,

    -- Target swaps on by default: spreading Shadow Word: Pain is the priest's multi-target damage.
    cycle = true,

    nameplates = true,
    nameplateRange = 10,

    damage = true,
    damageExpiration = 6,

    package = "Shadow",
    usePackSelector = true
} )


spec:RegisterPack( "Shadow", 20261026.2303, [[Hekili:9MvBVXTns4FlTf3E7IZv2R95CxCZgGlxAqtXvJaOGlFtsCLO2LWsIcKuEpdeOF73mK6fkjkT2PffbXExsoZ8WHpZlKoyBWNd8tikAW9xF11VAl8FVRV5QBc8vpvsd8ljXpqoaFOGKd)0)ijHFch(PmojbfwYReXWuhvQs5DxE5bM6y1EVyE(L)c9bwg7YJMFf4VVILP(yrW(zmPSKghC)TWSuzCRXQJkfmUGPEQoAnjtYRJuhP1rjKCay2ZMYf1r)cpd(iPiPo69mzmRmJvq3aiwWtzzao)HFOoQvZFsWOsfO3)DgrkzX1r)SGuhT1B7TB(jqlFBwtVkqVsV6FvBnThsExD0x4NosjWI7S3yK8(p5xhj4kIIXlQJouXsOxacseXcskSGptEKkkwqdnIOT8WTvzRnaKYfakwBKDdmv1(mCDAHbChvhDpS19PejcdEAJuGTH9ROQG2U50AoNgFKuWIX9ybixj4rO5Ocx3cVVaweM9tegOpMe0zb66eusj40Oj4aXGRJba8ibMpLKLr12oDd4bEp)ZWrbl(bykIGI2rzqGSGukpYvkAIT9OKhzfhGPveJqGDadQa4rnBduBOQ)ngE(9HmYtDwWGLskCelPXCCE959n6V3S1)I(CxDuqbZNLaA6JffOiFGhxjhP44mwzjaiy4)ljVKj0hl57fKy8a2pNPalcu0mudAn)V4)CZEf9zAAy7HSKQuGYWdH6FLeJKfPxPaGA(EI6VT7sgIKWuMGEblD3(Q0uV(H8apuHB5u8Q4JH80WtuYdWPSSt8jZSGwK6dHdversN8wJDwjbFD(ibXHAKd99FQklRo6eKRbCrG3Liv31go(bg6ZW54vQHNcRnR4YHHRWx3tZqwtgqna9E9viVGdUCXjMK2QJ3bHtkp3ahyap15V)ofb4UkVCqSWuWYE0cY(mGG6uw9Y2JkFgNcsoq92DSRhjSHT0tbG1gdHnHMVgMXKQlWe37yfmL9QEoUzRvdjoXacRHGuatTYjG2I6d)DyjefpqKhBO9H0gwpSYXJfcIcXXRsOAmnEAnYwPiIduLNILtdv8Weg9TBV12s7Pcjv8agTb2W1YVYE5L8tqGbRiTscJmWppCQqjnlDLgzdN4zIRkjneo3YLN)aJW1(hC8hPH0ciBkv(2TNxqjG7mkYjSl01LnKxc6sC3agnM2raYdPv4wIyNWUjTyx8MoPkiNGN3KzcgryhBGmo9HUGHmFd4Y3hAaWfpsYQO7ActmupmXccY2yLwsWOz1U6eEVuaodlbuokRItaaYfQujnM)v2zpnoU(uN6C44jguak8qCYUTdygwRkSp(DvmhQea4WRFmpOgxYtRw3IeVoVWxDUnqFnyIVoLo9Mov0Sp24a(9g2eGnXO2fdq47vv6qnJHLjTMbAUy67gJnh6mH(i0ke8TWYmYHk6mrN7E9IBlht(8s(U6fIFmaQV4XDMA4a9pvPlrBIkABKr3EWGGkUzrM(y(rGfntS16go1gV5224M4cgKyuiQkvH20WE3siIUvRNLa6MSnxIRjUdxunmMh0Oir(ml61l5zQO5GoYX(9Aou4ybEf0Yj69HpI5hFQR()98hb)(AdCW64vkj0wBR7hlXTPPflNhiyhVqmHUvrOHVCJ10(iP1zeKIUL6vawCWUPB0Wg5E7vRgLlFHfp2gtIfJFkoJ2UAiXuo5)foCSBg6CpvgMxLPyWH5YrbBVU1j)Fq)soPG0ZqRJ(EtpVVZ0T0VPN9V89BUdlfqPJcamvlg1t8duA5m(9QYU5XskAuCqWRk)RshvYA7R3udkrWBBV2QTnSreRtm8RNlb)SXptuZWeTlMvTrIxCov80WLvnjes3P9oR(wQIcI5EcbnhqM8n34a96qWaF42tytptU((jIOaPBb(b(ydjs9ZdOJGHpDV(PgAqvW7c8JH7rtHKmWAwUOAD0ki37SNl4SRRJMwPRo6RFfygluJ1SIPE(6O3yPW2ccrBc8n(KaFlKg4BrIWTPc8mJ2RTI1dE79)Cq3bNcv(nZO8X7sBt8DMQv698k3B53UB6Egn3FFgZnUAUT5Mt)Vgv4TN35aR6vZSQUA9J3EZv9b3V)o2()JLqlAiKm0xA2In)NxTzeN)Z5yfDfPFMomuzVEoLHvPDg6Ax)g1W2RMLLcPrcW)bmOucuvYvYH2vp(soMmlHMxJeBXFPOT(R0Adzx32DXWkZTFDfk0R0(R82l4O7ipa646xkwy8nFhMUW5LM1m7LU488u)6OT3Uumx)fQpBqoOQRwkSz4fNDsLCCPBn0N7I3NFFnxSr3fYDX57r2Wo3m69zsrHg4wmAyrHBQDQJv6EpOLIw6FIVje(rV(3sHntEPVjkZ9BbE(At6x)BMyX(xgCPIoVSq65IUEP1qwk2yyvR5O9p7eNkdNzHd5URl4uDtVmbsxVshJmHhVZ6LKNi45ZSoOvd7RFGG3FYLsc8VXThW62jVKQ1BV24V0LbC4W4LAJyNu1u3u)PMySUwUWbZWUywSDA7KSoEykZ0Zvm3Lh9zbY22rAH4RmBCDrKf7SE2ooMKZ4pMoz)ZVJvnjy20fwnP1Rz9TMAu632rDJ4lEdk9DiUzPSq9DcHh)vQJCGeA(JL(JubrpEW))d]] )

spec:RegisterPackSelector( "discipline", "Shadow", "|T135987:0|t Discipline",
    "If you have spent more points in |T135987:0|t Discipline than in any other tree, this priority will be automatically selected for you.  " ..
    "Herakili has no healing priority; the Shadow priority's damage spells are used.",
    function( tab1, tab2, tab3 )
        return tab1 > max( tab2, tab3 )
    end )

spec:RegisterPackSelector( "holy", "Shadow", "|T237542:0|t Holy",
    "If you have spent more points in |T237542:0|t Holy than in any other tree, this priority will be automatically selected for you.  " ..
    "Herakili has no healing priority; the Shadow priority's damage spells are used.",
    function( tab1, tab2, tab3 )
        return tab2 > max( tab1, tab3 )
    end )

spec:RegisterPackSelector( "shadow", "Shadow", "|T136207:0|t Shadow",
    "If you have spent more points in |T136207:0|t Shadow than in any other tree, this priority will be automatically selected for you.",
    function( tab1, tab2, tab3 )
        return tab3 > max( tab1, tab2 )
    end )
