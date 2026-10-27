-- Era/Paladin.lua
-- Classic Era (1.15.x) Paladin.  Spell, rank, aura and talent IDs from the Classic Era client tables (see PORTING.md).

if UnitClassBase( 'player' ) ~= 'PALADIN' then return end

local addon, ns = ...
local Hekili = _G[ addon ]
local class, state = Hekili.Class, Hekili.State

local floor = math.floor
local GetSpellPowerCost = _G.GetSpellPowerCost or ( C_Spell and C_Spell.GetSpellPowerCost )

local spec = Hekili:NewSpecialization( 2 )

spec:RegisterResource( Enum.PowerType.Mana )


local function known_id( key )
    local ability = class.abilities[ key ]
    return ability and ability.id
end

-- Mana costs: the live client's cost for the rank you know (talents such as Benediction included), refreshed every
-- 10 seconds; the per-rank table is only a fallback in case the client gives no cost.
local cost_cache = {}

local function mana_cost( key, fallback )
    local id = known_id( key )
    if not id then return 0 end

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

    if c.v then return c.v end
    local v = fallback and fallback[ id ] or 0
    -- Percent-of-base-mana cost; base mana isn't exposed, so estimate it from maximum mana.
    if v < 0 then v = floor( -v / 100 * UnitPowerMax( "player", 0 ) * 0.5 ) end
    return v
end

-- Per-rank mana costs from the Era client's SpellPower table (fallback only; the live cost is used when the client
-- reports one).  Negative values are a percentage of base mana.
local COST = {
    seal_of_righteousness = { [20154] = 20, [21084] = 20, [20287] = 40, [20288] = 60, [20289] = 90, [20290] = 120, [20291] = 140, [20292] = 170, [20293] = 200 },
    seal_of_command = { [20375] = 65, [20915] = 110, [20918] = 140, [20919] = 180, [20920] = 210 },
    seal_of_the_crusader = { [21082] = 25, [20162] = 40, [20305] = 65, [20306] = 90, [20307] = 125, [20308] = 160 },
    seal_of_wisdom = { [20166] = 135, [20356] = 170, [20357] = 200 },
    seal_of_light = { [20165] = 110, [20347] = 140, [20348] = 180, [20349] = 210 },
    seal_of_justice = { [20164] = -13 },
    judgement = { [20271] = -6 },
    hammer_of_wrath = { [24275] = 295, [24274] = 360, [24239] = 425 },
    exorcism = { [879] = 85, [5614] = 135, [5615] = 180, [10312] = 235, [10313] = 285, [10314] = 345 },
    consecration = { [26573] = 135, [20116] = 235, [20922] = 320, [20923] = 435, [20924] = 565 },
    holy_shield = { [20925] = 150, [20927] = 195, [20928] = 240 },
    holy_shock = { [20473] = 225, [20929] = 275, [20930] = 325 },
    righteous_fury = { [25780] = -30 },
    repentance = { [20066] = 60 },
    hammer_of_justice = { [853] = 30, [5588] = 50, [5589] = 75, [10308] = 100 },
    blessing_of_might = { [19740] = 20, [19834] = 30, [19835] = 45, [19836] = 60, [19837] = 85, [19838] = 110, [25291] = 130 },
    blessing_of_wisdom = { [19742] = 30, [19850] = 45, [19852] = 65, [19853] = 90, [19854] = 115, [25290] = 125 },
    blessing_of_kings = { [20217] = -8 },
    blessing_of_sanctuary = { [20911] = 60, [20912] = 85, [20913] = 110, [20914] = 135 },
}

local function cost_fn( key )
    local fb = COST[ key ]
    return function() return mana_cost( key, fb ) end
end


-- Talents: { talentID, maxRank, rank1SpellID, ... rankNSpellID }, from the Classic Era client's Talent table.
-- In-game tab order: 1 Holy (TabID 382), 2 Protection (383), 3 Retribution (381).
spec:RegisterTalents( {
    -- Holy
    divine_strength                  = {  1450, 5, 20262, 20263, 20264, 20265, 20266 },
    divine_intellect                 = {  1449, 5, 20257, 20258, 20259, 20260, 20261 },
    spiritual_focus                  = {  1432, 5, 20205, 20206, 20207, 20209, 20208 },
    improved_seal_of_righteousness   = {  1463, 5, 20224, 20225, 20330, 20331, 20332 },
    healing_light                    = {  1444, 3, 20237, 20238, 20239 },
    consecration                     = {  1435, 1, 26573 },
    improved_lay_on_hands            = {  1443, 2, 20234, 20235 },
    unyielding_faith                 = {  1628, 2, 9453, 25836 },
    illumination                     = {  1461, 5, 20210, 20212, 20213, 20214, 20215 },
    improved_blessing_of_wisdom      = {  1446, 2, 20244, 20245 },
    divine_favor                     = {  1433, 1, 20216 },
    lasting_judgement                = {  1465, 3, 20359, 20360, 20361 },
    holy_power                       = {  1627, 5, 5923, 5924, 5925, 5926, 25829 },
    holy_shock                       = {  1502, 1, 20473 },

    -- Protection
    improved_devotion_aura           = {  1422, 5, 20138, 20139, 20140, 20141, 20142 },
    redoubt                          = {  1421, 5, 20127, 20130, 20135, 20136, 20137 },
    precision                        = {  1630, 3, 20189, 20192, 20193 },
    guardian_s_favor                 = {  1425, 2, 20174, 20175 },
    toughness                        = {  1423, 5, 20143, 20144, 20145, 20146, 20147 },
    blessing_of_kings                = {  1442, 1, 20217 },
    improved_righteous_fury          = {  1501, 3, 20468, 20469, 20470 },
    shield_specialization            = {  1424, 3, 20148, 20149, 20150 },
    anticipation                     = {  1629, 5, 20096, 20097, 20098, 20099, 20100 },
    improved_hammer_of_justice       = {  1521, 3, 20487, 20488, 20489 },
    improved_concentration_aura      = {  1626, 3, 20254, 20255, 20256 },
    blessing_of_sanctuary            = {  1431, 1, 20911 },
    reckoning                        = {  1426, 5, 20177, 20179, 20181, 20180, 20182 },
    one_handed_weapon_specialization = {  1429, 5, 20196, 20197, 20198, 20199, 20200 },
    holy_shield                      = {  1430, 1, 20925 },

    -- Retribution
    improved_blessing_of_might       = {  1401, 5, 20042, 20045, 20046, 20047, 20048 },
    benediction                      = {  1407, 5, 20101, 20102, 20103, 20104, 20105 },
    improved_judgement               = {  1631, 2, 25956, 25957 },
    improved_seal_of_the_crusader    = {  1464, 3, 20335, 20336, 20337 },
    deflection                       = {  1403, 5, 20060, 20061, 20062, 20063, 20064 },
    vindication                      = {  1633, 3, 9452, 26016, 26021 },
    conviction                       = {  1411, 5, 20117, 20118, 20119, 20120, 20121 },
    seal_of_command                  = {  1481, 1, 20375 },
    pursuit_of_justice               = {  1634, 2, 26022, 26023 },
    eye_for_an_eye                   = {  1632, 2, 9799, 25988 },
    improved_retribution_aura        = {  1405, 2, 20091, 20092 },
    two_handed_weapon_specialization = {  1410, 3, 20111, 20112, 20113 },
    sanctity_aura                    = {  1409, 1, 20218 },
    vengeance                        = {  1402, 5, 20049, 20056, 20057, 20058, 20059 },
    repentance                       = {  1441, 1, 20066 },
} )


-- Auras
spec:RegisterAuras( {
    -- Seals (player buffs; only one can be active, and Judgement consumes it).
    seal_of_righteousness = {
        id = 20293,
        duration = 30,
        max_stack = 1,
        copy = { 20154, 21084, 20287, 20288, 20289, 20290, 20291, 20292, 20293 },
    },
    seal_of_command = {
        id = 20920,
        duration = 30,
        max_stack = 1,
        copy = { 20375, 20915, 20918, 20919, 20920 },
    },
    seal_of_the_crusader = {
        id = 20308,
        duration = 30,
        max_stack = 1,
        copy = { 21082, 20162, 20305, 20306, 20307, 20308 },
    },
    seal_of_wisdom = {
        id = 20357,
        duration = 30,
        max_stack = 1,
        copy = { 20166, 20356, 20357 },
    },
    seal_of_light = {
        id = 20349,
        duration = 30,
        max_stack = 1,
        copy = { 20165, 20347, 20348, 20349 },
    },
    seal_of_justice = {
        id = 20164,
        duration = 30,
        max_stack = 1,
    },
    seal = {
        alias = { "seal_of_righteousness", "seal_of_command", "seal_of_the_crusader", "seal_of_wisdom", "seal_of_light", "seal_of_justice" },
        aliasMode = "first",
        aliasType = "buff",
    },

    -- Judgement debuffs on the target.
    judgement_of_the_crusader = {
        id = 20303,
        duration = 10,
        max_stack = 1,
        shared = "target",
        copy = { 21183, 20188, 20300, 20301, 20302, 20303 },
    },
    judgement_of_wisdom = {
        id = 20355,
        duration = function() return 10 + 10 * talent.lasting_judgement.rank end,
        max_stack = 1,
        shared = "target",
        copy = { 20186, 20354, 20355 },
    },
    judgement_of_light = {
        id = 20346,
        duration = function() return 10 + 10 * talent.lasting_judgement.rank end,
        max_stack = 1,
        shared = "target",
        copy = { 20185, 20344, 20345, 20346 },
    },
    judgement_of_justice = {
        id = 20184,
        duration = 10,
        max_stack = 1,
        shared = "target",
    },

    -- Blessings (any paladin's counts; Greater Blessings included).
    blessing_of_might = {
        id = 25291,
        duration = 300,
        max_stack = 1,
        shared = "player",
        copy = { 19740, 19834, 19835, 19836, 19837, 19838, 25291, 25782, 25916 },
    },
    blessing_of_wisdom = {
        id = 25290,
        duration = 300,
        max_stack = 1,
        shared = "player",
        copy = { 19742, 19850, 19852, 19853, 19854, 25290, 25894, 25918 },
    },
    blessing_of_kings = {
        id = 20217,
        duration = 300,
        max_stack = 1,
        shared = "player",
        copy = { 20217, 25898 },
    },
    blessing_of_sanctuary = {
        id = 20914,
        duration = 300,
        max_stack = 1,
        shared = "player",
        copy = { 20911, 20912, 20913, 20914, 25899 },
    },

    -- Threat from holy spells increased.
    righteous_fury = {
        id = 25780,
        duration = 1800,
        max_stack = 1,
    },
    -- Block chance increased; blocked attacks deal holy damage.  4 charges.
    holy_shield = {
        id = 20928,
        duration = 10,
        max_stack = 4,
        copy = { 20925, 20927, 20928 },
    },
    -- Pseudo-aura: your Consecration is on the ground (8 sec).
    active_consecration = {
        duration = 8,
        max_stack = 1,
        generate = function( t )
            local applied = action.consecration.lastCast

            if applied and applied > 0 and query_time - applied < 8 then
                t.count = 1
                t.expires = applied + 8
                t.applied = applied
                t.caster = "player"
                return
            end

            t.count = 0
            t.expires = 0
            t.applied = 0
            t.caster = "nobody"
        end,
    },
    hammer_of_justice = {
        id = 10308,
        duration = 6,
        max_stack = 1,
        copy = { 853, 5588, 5589, 10308 },
    },
    repentance = {
        id = 20066,
        duration = 6,
        max_stack = 1,
    },
    divine_shield = {
        id = 1020,
        duration = 12,
        max_stack = 1,
        copy = { 642, 1020 },
    },
    divine_protection = {
        id = 5573,
        duration = 8,
        max_stack = 1,
        copy = { 498, 5573 },
    },
    forbearance = {
        id = 25771,
        duration = 60,
        max_stack = 1,
    },
    vengeance = {
        id = 20059,
        duration = 8,
        max_stack = 1,
        copy = { 20050, 20052, 20053, 20054, 20055 },
    },

    -- Auras (paladin auras).
    devotion_aura = {
        id = 10293,
        duration = 3600,
        max_stack = 1,
        copy = { 465, 10290, 643, 10291, 1032, 10292, 10293 },
    },
    retribution_aura = {
        id = 10301,
        duration = 3600,
        max_stack = 1,
        copy = { 7294, 10298, 10299, 10300, 10301 },
    },
    sanctity_aura = {
        id = 20218,
        duration = 3600,
        max_stack = 1,
    },
} )


-- Settings-derived state.
local function judgement_debuff_wanted( which )
    if state.settings.judgement_debuff ~= which then return false end
    local d = state.debuff[ "judgement_of_" .. ( which == "crusader" and "the_crusader" or which ) ]
    -- Refresh it if it will drop before Judgement could be used again.
    return d.remains < state.gcd.max and state.target.time_to_die > 6
end

-- The judgement debuff the settings ask for is missing (or about to drop) on the target.
spec:RegisterStateExpr( "jd_crusader", function() return judgement_debuff_wanted( "crusader" ) end )
spec:RegisterStateExpr( "jd_wisdom", function() return judgement_debuff_wanted( "wisdom" ) end )
spec:RegisterStateExpr( "jd_light", function() return judgement_debuff_wanted( "light" ) end )

-- A debuff seal is up and waiting for Judgement: don't overwrite it with the main seal.
spec:RegisterStateExpr( "debuff_seal_pending", function()
    return ( jd_crusader and buff.seal_of_the_crusader.up ) or ( jd_wisdom and buff.seal_of_wisdom.up ) or
        ( jd_light and buff.seal_of_light.up )
end )

-- More points in Protection than in any other tree (the Protection priority's pack selector).
spec:RegisterStateExpr( "prot_tree", function()
    local get = ns.GetTabPoints
    if not get then return false end
    local t1, t2, t3 = get( 1 ), get( 2 ), get( 3 )
    return t2 > max( t1, t3 )
end )

-- Main seal: Seal of Wisdom when mana is below the "Seal of Wisdom" threshold, otherwise Seal of Command
-- (Retribution, talented, per setting) or Seal of Righteousness.
spec:RegisterStateExpr( "use_sow", function()
    return settings.wisdom_mana_pct > 0 and mana.pct < settings.wisdom_mana_pct and action.seal_of_wisdom.known
end )

spec:RegisterStateExpr( "use_soc", function()
    if use_sow or not talent.seal_of_command.enabled then return false end
    if prot_tree and settings.ret_seal == "auto" then return false end
    return settings.ret_seal ~= "righteousness"
end )

spec:RegisterStateExpr( "use_sor", function()
    return not use_sow and not use_soc
end )

spec:RegisterStateExpr( "main_seal_up", function()
    if use_sow then return buff.seal_of_wisdom.up end
    if use_soc then return buff.seal_of_command.up end
    return buff.seal_of_righteousness.up
end )

spec:RegisterStateExpr( "need_main_seal", function()
    return not main_seal_up and not debuff_seal_pending
end )

-- Judge the main seal (setting) while mana allows.  Never judge Seal of Wisdom used for mana.
spec:RegisterStateExpr( "judge_main", function()
    return settings.judge_main_seal and main_seal_up and not use_sow and mana.pct >= settings.judge_mana_pct
end )

spec:RegisterStateExpr( "self_blessing_might", function() return settings.self_blessing == "might" end )
spec:RegisterStateExpr( "self_blessing_wisdom", function() return settings.self_blessing == "wisdom" end )
spec:RegisterStateExpr( "self_blessing_kings", function()
    return settings.self_blessing == "kings" or settings.self_blessing == "auto" and prot_tree and
        talent.blessing_of_kings.enabled and not talent.blessing_of_sanctuary.enabled
end )
spec:RegisterStateExpr( "self_blessing_sanctuary", function()
    return settings.self_blessing == "sanctuary" or settings.self_blessing == "auto" and prot_tree and
        talent.blessing_of_sanctuary.enabled
end )
-- "Automatic": Protection uses Sanctuary (or Kings), everyone else Might.
spec:RegisterStateExpr( "self_blessing_auto_might", function()
    return settings.self_blessing == "auto" and not self_blessing_sanctuary and not self_blessing_kings
end )

-- Any blessing at all is on you (another paladin's counts).
spec:RegisterStateExpr( "any_blessing", function()
    return buff.blessing_of_might.up or buff.blessing_of_wisdom.up or buff.blessing_of_kings.up or buff.blessing_of_sanctuary.up
end )


spec:RegisterStateFunction( "remove_seals", function()
    removeBuff( "seal_of_righteousness" )
    removeBuff( "seal_of_command" )
    removeBuff( "seal_of_the_crusader" )
    removeBuff( "seal_of_wisdom" )
    removeBuff( "seal_of_light" )
    removeBuff( "seal_of_justice" )
end )

spec:RegisterStateFunction( "apply_seal", function( seal )
    remove_seals()
    applyBuff( seal )
end )


-- Abilities
spec:RegisterAbilities( {
    -- Melee attacks deal additional Holy damage.  Lasts 30 sec.
    seal_of_righteousness = {
        id = 20293,
        cast = 0,
        cooldown = 0,
        gcd = "spell",
        spend = cost_fn( "seal_of_righteousness" ),
        spendType = "mana",
        startsCombat = false,
        texture = 132325,
        handler = function()
            apply_seal( "seal_of_righteousness" )
        end,
        copy = { 20154, 21084, 20287, 20288, 20289, 20290, 20291, 20292 }
    },
    -- Melee attacks have a chance to deal 70% weapon damage as Holy damage.  Lasts 30 sec.
    seal_of_command = {
        id = 20920,
        cast = 0,
        cooldown = 0,
        gcd = "spell",
        spend = cost_fn( "seal_of_command" ),
        spendType = "mana",
        talent = "seal_of_command",
        startsCombat = false,
        texture = 132347,
        handler = function()
            apply_seal( "seal_of_command" )
        end,
        copy = { 20375, 20915, 20918, 20919 }
    },
    -- Increases melee attack power, attack speed; Judgement makes the target take more Holy damage.
    seal_of_the_crusader = {
        id = 20308,
        cast = 0,
        cooldown = 0,
        gcd = "spell",
        spend = cost_fn( "seal_of_the_crusader" ),
        spendType = "mana",
        startsCombat = false,
        texture = 135924,
        handler = function()
            apply_seal( "seal_of_the_crusader" )
        end,
        copy = { 21082, 20162, 20305, 20306, 20307 }
    },
    -- Melee attacks can restore mana.  Judgement: attacks against the target can restore the attacker's mana.
    seal_of_wisdom = {
        id = 20357,
        cast = 0,
        cooldown = 0,
        gcd = "spell",
        spend = cost_fn( "seal_of_wisdom" ),
        spendType = "mana",
        startsCombat = false,
        texture = 135960,
        handler = function()
            apply_seal( "seal_of_wisdom" )
        end,
        copy = { 20166, 20356 }
    },
    -- Melee attacks can heal you.  Judgement: attacks against the target can heal the attacker.
    seal_of_light = {
        id = 20349,
        cast = 0,
        cooldown = 0,
        gcd = "spell",
        spend = cost_fn( "seal_of_light" ),
        spendType = "mana",
        startsCombat = false,
        texture = 135917,
        handler = function()
            apply_seal( "seal_of_light" )
        end,
        copy = { 20165, 20347, 20348 }
    },
    seal_of_justice = {
        id = 20164,
        cast = 0,
        cooldown = 0,
        gcd = "spell",
        spend = cost_fn( "seal_of_justice" ),
        spendType = "mana",
        startsCombat = false,
        texture = 135971,
        handler = function()
            apply_seal( "seal_of_justice" )
        end,
    },
    -- Unleashes the active seal on the target, consuming it.
    judgement = {
        id = 20271,
        cast = 0,
        cooldown = function() return 10 - talent.improved_judgement.rank end,
        gcd = "spell",
        spend = cost_fn( "judgement" ),
        spendType = "mana",
        startsCombat = true,
        texture = 135959,
        usable = function() return buff.seal.up, "requires an active seal" end,
        handler = function()
            if buff.seal_of_the_crusader.up then applyDebuff( "target", "judgement_of_the_crusader" )
            elseif buff.seal_of_wisdom.up then applyDebuff( "target", "judgement_of_wisdom" )
            elseif buff.seal_of_light.up then applyDebuff( "target", "judgement_of_light" )
            elseif buff.seal_of_justice.up then applyDebuff( "target", "judgement_of_justice" ) end
            remove_seals()
        end,
    },
    -- Hurls a hammer at an enemy below 20% health.
    hammer_of_wrath = {
        id = 24239,
        cast = 1,
        cooldown = 6,
        gcd = "spell",
        spend = cost_fn( "hammer_of_wrath" ),
        spendType = "mana",
        startsCombat = true,
        texture = 132326,
        usable = function() return target.health.pct < 20, "requires target health under 20 percent" end,
        handler = function()
        end,
        copy = { 24275, 24274 }
    },
    -- Holy damage to an undead or demon target.
    exorcism = {
        id = 10314,
        cast = 0,
        cooldown = 15,
        gcd = "spell",
        spend = cost_fn( "exorcism" ),
        spendType = "mana",
        startsCombat = true,
        texture = 135903,
        usable = function() return target.is_undead or target.is_demon, "requires an undead or demon target" end,
        handler = function()
        end,
        copy = { 879, 5614, 5615, 10312, 10313 }
    },
    -- Holy damage to all enemies standing in it over 8 sec.
    consecration = {
        id = 20924,
        cast = 0,
        cooldown = 8,
        gcd = "spell",
        spend = cost_fn( "consecration" ),
        spendType = "mana",
        talent = "consecration",
        startsCombat = true,
        texture = 135926,
        handler = function()
            applyBuff( "active_consecration" )
        end,
        copy = { 26573, 20116, 20922, 20923 }
    },
    holy_shock = {
        id = 20930,
        cast = 0,
        cooldown = 30,
        gcd = "spell",
        spend = cost_fn( "holy_shock" ),
        spendType = "mana",
        talent = "holy_shock",
        startsCombat = true,
        texture = 135972,
        handler = function()
        end,
        copy = { 20473, 20929 }
    },
    -- Block chance increased by 30%; blocked attacks deal Holy damage.  4 charges, 10 sec.
    holy_shield = {
        id = 20928,
        cast = 0,
        cooldown = 10,
        gcd = "spell",
        spend = cost_fn( "holy_shield" ),
        spendType = "mana",
        talent = "holy_shield",
        startsCombat = false,
        texture = 135880,
        equipped = "shield",
        handler = function()
            applyBuff( "holy_shield", nil, 4 )
        end,
        copy = { 20925, 20927 }
    },
    -- Increases threat from Holy spells.  Lasts 30 min.
    righteous_fury = {
        id = 25780,
        cast = 0,
        cooldown = 0,
        gcd = "spell",
        spend = cost_fn( "righteous_fury" ),
        spendType = "mana",
        startsCombat = false,
        texture = 135962,
        nobuff = "righteous_fury",
        handler = function()
            applyBuff( "righteous_fury" )
        end,
    },
    -- Stuns the target for 6 sec (interrupts casting).
    hammer_of_justice = {
        id = 10308,
        cast = 0,
        cooldown = function() return 60 - 5 * talent.improved_hammer_of_justice.rank end,
        gcd = "spell",
        spend = cost_fn( "hammer_of_justice" ),
        spendType = "mana",
        startsCombat = true,
        texture = 135963,
        toggle = "interrupts",
        debuff = "casting",
        readyTime = state.timeToInterrupt,
        handler = function()
            interrupt()
            applyDebuff( "target", "hammer_of_justice" )
        end,
        copy = { 853, 5588, 5589 }
    },
    repentance = {
        id = 20066,
        cast = 0,
        cooldown = 60,
        gcd = "spell",
        spend = cost_fn( "repentance" ),
        spendType = "mana",
        talent = "repentance",
        startsCombat = true,
        texture = 135942,
        toggle = "interrupts",
        debuff = "casting",
        readyTime = state.timeToInterrupt,
        handler = function()
            interrupt()
            applyDebuff( "target", "repentance" )
        end,
    },

    -- Blessings (self-buffs only; group blessings are not the priority's job).
    blessing_of_might = {
        id = 25291,
        cast = 0,
        cooldown = 0,
        gcd = "spell",
        spend = cost_fn( "blessing_of_might" ),
        spendType = "mana",
        startsCombat = false,
        texture = 135906,
        handler = function()
            removeBuff( "blessing_of_wisdom" ); removeBuff( "blessing_of_kings" ); removeBuff( "blessing_of_sanctuary" )
            applyBuff( "blessing_of_might" )
        end,
        copy = { 19740, 19834, 19835, 19836, 19837, 19838 }
    },
    blessing_of_wisdom = {
        id = 25290,
        cast = 0,
        cooldown = 0,
        gcd = "spell",
        spend = cost_fn( "blessing_of_wisdom" ),
        spendType = "mana",
        startsCombat = false,
        texture = 135970,
        handler = function()
            removeBuff( "blessing_of_might" ); removeBuff( "blessing_of_kings" ); removeBuff( "blessing_of_sanctuary" )
            applyBuff( "blessing_of_wisdom" )
        end,
        copy = { 19742, 19850, 19852, 19853, 19854 }
    },
    blessing_of_kings = {
        id = 20217,
        cast = 0,
        cooldown = 0,
        gcd = "spell",
        spend = cost_fn( "blessing_of_kings" ),
        spendType = "mana",
        talent = "blessing_of_kings",
        startsCombat = false,
        texture = 135995,
        handler = function()
            removeBuff( "blessing_of_might" ); removeBuff( "blessing_of_wisdom" ); removeBuff( "blessing_of_sanctuary" )
            applyBuff( "blessing_of_kings" )
        end,
    },
    blessing_of_sanctuary = {
        id = 20914,
        cast = 0,
        cooldown = 0,
        gcd = "spell",
        spend = cost_fn( "blessing_of_sanctuary" ),
        spendType = "mana",
        talent = "blessing_of_sanctuary",
        startsCombat = false,
        texture = 136051,
        handler = function()
            removeBuff( "blessing_of_might" ); removeBuff( "blessing_of_wisdom" ); removeBuff( "blessing_of_kings" )
            applyBuff( "blessing_of_sanctuary" )
        end,
        copy = { 20911, 20912, 20913 }
    },

    -- Paladin auras.
    devotion_aura = {
        id = 10293,
        cast = 0,
        cooldown = 0,
        gcd = "spell",
        startsCombat = false,
        texture = 135893,
        nobuff = "devotion_aura",
        handler = function()
            removeBuff( "retribution_aura" ); removeBuff( "sanctity_aura" )
            applyBuff( "devotion_aura" )
        end,
        copy = { 465, 10290, 643, 10291, 1032, 10292 }
    },
    retribution_aura = {
        id = 10301,
        cast = 0,
        cooldown = 0,
        gcd = "spell",
        startsCombat = false,
        texture = 135873,
        nobuff = "retribution_aura",
        handler = function()
            removeBuff( "devotion_aura" ); removeBuff( "sanctity_aura" )
            applyBuff( "retribution_aura" )
        end,
        copy = { 7294, 10298, 10299, 10300 }
    },
    sanctity_aura = {
        id = 20218,
        cast = 0,
        cooldown = 0,
        gcd = "spell",
        talent = "sanctity_aura",
        startsCombat = false,
        texture = 135934,
        nobuff = "sanctity_aura",
        handler = function()
            removeBuff( "devotion_aura" ); removeBuff( "retribution_aura" )
            applyBuff( "sanctity_aura" )
        end,
    },

    -- Defensives.
    divine_shield = {
        id = 1020,
        cast = 0,
        cooldown = 300,
        gcd = "spell",
        startsCombat = false,
        texture = 135896,
        toggle = "defensives",
        nodebuff = "forbearance",
        handler = function()
            applyBuff( "divine_shield" )
            applyDebuff( "player", "forbearance" )
        end,
        copy = { 642 }
    },
    divine_protection = {
        id = 5573,
        cast = 0,
        cooldown = 300,
        gcd = "spell",
        startsCombat = false,
        texture = 135954,
        toggle = "defensives",
        nodebuff = "forbearance",
        handler = function()
            applyBuff( "divine_protection" )
            applyDebuff( "player", "forbearance" )
        end,
        copy = { 498 }
    },
    lay_on_hands = {
        id = 10310,
        cast = 0,
        cooldown = function() return 3600 - 600 * talent.improved_lay_on_hands.rank end,
        gcd = "spell",
        startsCombat = false,
        texture = 135928,
        toggle = "defensives",
        usable = function() return health.pct < 20, "use below 20 percent health" end,
        handler = function()
            spend( mana.current, "mana" )
            gain( health.max, "health" )
        end,
        copy = { 633, 2800 }
    },
    divine_favor = {
        id = 20216,
        cast = 0,
        cooldown = 120,
        gcd = "off",
        talent = "divine_favor",
        startsCombat = false,
        texture = 135915,
        handler = function()
        end,
    },
} )


-- Settings
spec:RegisterSetting( "paladin_description", nil, {
    type = "description",
    name = "Adjust the settings below to match your role and mana.  Holy (healing) is not covered; Holy-talented characters " ..
        "get the Retribution priority."
} )

spec:RegisterSetting( "seals_header", nil, {
    type = "header",
    name = "Seals and Judgement"
} )

spec:RegisterSetting( "ret_seal", "auto", {
    type = "select",
    name = "Retribution Seal",
    desc = "Which seal Retribution keeps up and judges.\n\n" ..
        "|cFFFFD100Automatic|r: Seal of Command once you have the talent (slow two-handers), otherwise Seal of Righteousness.\n" ..
        "Protection always uses Seal of Righteousness unless you pick Seal of Command explicitly.",
    width = "full",
    values = {
        auto = "Automatic",
        command = "Seal of Command",
        righteousness = "Seal of Righteousness",
    },
} )

spec:RegisterSetting( "judgement_debuff", "none", {
    type = "select",
    name = "Keep Judgement Debuff on Target",
    desc = "Keep this Judgement on your target (raid utility): cast the matching seal, judge it, then go back to your main seal.\n\n" ..
        "|cFFFFD100Crusader|r: Judgement of the Crusader (more Holy damage taken).  |cFFFFD100Wisdom|r / |cFFFFD100Light|r: " ..
        "Judgement of Wisdom / Light.  Leave it on |cFFFFD100None|r if another paladin is assigned to it.",
    width = "full",
    values = {
        none = "None",
        crusader = "Judgement of the Crusader",
        wisdom = "Judgement of Wisdom",
        light = "Judgement of Light",
    },
} )

spec:RegisterSetting( "judge_main_seal", true, {
    type = "toggle",
    name = "Judge Your Main Seal",
    desc = "When enabled, Judgement is used on cooldown to unleash your Seal of Righteousness / Command, and the seal is recast " ..
        "right after.  Disable it to only keep the seal up (saves mana).",
    width = "full",
} )

spec:RegisterSetting( "judge_mana_pct", 30, {
    type = "range",
    name = "Judge Main Seal Above Mana %",
    desc = "Judging (and recasting) your main seal is only recommended at or above this mana percentage.  " ..
        "Holy Shock (if talented) uses the same limit.",
    width = "full",
    min = 0,
    max = 100,
    step = 1,
} )

spec:RegisterSetting( "wisdom_mana_pct", 0, {
    type = "range",
    name = "Seal of Wisdom Below Mana %",
    desc = "Below this mana percentage, Seal of Wisdom replaces your main seal (and is not judged) to regain mana.  " ..
        "Useful while leveling.  0 disables it.",
    width = "full",
    min = 0,
    max = 100,
    step = 1,
} )

spec:RegisterSetting( "abilities_header", nil, {
    type = "header",
    name = "Abilities"
} )

spec:RegisterSetting( "hammer_of_wrath", true, {
    type = "toggle",
    name = "Hammer of Wrath",
    desc = "When enabled, Hammer of Wrath is recommended against targets below 20% health (if mana is at or above the " ..
        "Consecration mana limit, or the target is about to die).",
    width = "full",
} )

spec:RegisterSetting( "exorcism", true, {
    type = "toggle",
    name = "Exorcism",
    desc = "When enabled, Exorcism is recommended on cooldown against undead and demons.",
    width = "full",
} )

spec:RegisterSetting( "consecration_targets", 3, {
    type = "range",
    name = "Retribution: Consecration Targets",
    desc = "Retribution recommends Consecration with at least this many enemies in melee range (and mana above the limit below).  " ..
        "0 disables it.  Protection always uses Consecration with 2+ enemies.",
    width = "full",
    min = 0,
    max = 10,
    step = 1,
} )

spec:RegisterSetting( "consecration_mana_pct", 40, {
    type = "range",
    name = "Consecration Above Mana %",
    desc = "Retribution AoE Consecration, Protection single-target Consecration and Hammer of Wrath are only recommended at or " ..
        "above this mana percentage.  Protection AoE Consecration ignores it.",
    width = "full",
    min = 0,
    max = 100,
    step = 1,
} )

spec:RegisterSetting( "prot_consecration_single", true, {
    type = "toggle",
    name = "Protection: Consecration on a Single Target",
    desc = "When enabled, Protection uses Consecration on cooldown against a single target too (threat), while mana allows.",
    width = "full",
} )

spec:RegisterSetting( "buffs_header", nil, {
    type = "header",
    name = "Self-Buffs"
} )

spec:RegisterSetting( "self_blessing", "auto", {
    type = "select",
    name = "Blessing on Yourself",
    desc = "Recommend this Blessing on yourself when you have no Blessing at all (another paladin's Blessing counts).\n\n" ..
        "|cFFFFD100Automatic|r: Blessing of Sanctuary (or Kings) for Protection if talented, otherwise Blessing of Might.",
    width = "full",
    values = {
        none = "None",
        auto = "Automatic",
        might = "Blessing of Might",
        wisdom = "Blessing of Wisdom",
        kings = "Blessing of Kings",
        sanctuary = "Blessing of Sanctuary",
    },
} )


spec:RegisterOptions( {
    enabled = true,
    aoe = 3,
    gcd = 635, -- Holy Light (Rank 1): every paladin knows it from level 1, it has no cooldown of its own.
    nameplates = true,
    nameplateRange = 8,
    damage = true,
    damageExpiration = 6,
    package = "Retribution",
    usePackSelector = true
} )


spec:RegisterPack( "Retribution", 20261027.1552, [[Hekili:TIvyVTTnq0FlTfWigltjolPDlijaRPbOnaROyQa5BsIw6SntKeniPQJbc4V9DKusMYsY2kzOafYK39Uh5X7DKjysWpd8tisi47ND6zFCYPN9jVjxCXzb(Y1lHa)LK4NiZXpYjz4))VGKtNwiPSC9CRtzKenccwbpgNFHuUuC5jNmNkxum1lMLDYcGtEIMsR)iWFAbnv(T8GP9eAXsigheNfeXncQk6hKuscf)ygJRIUnLie0yv0DCYLQibqsvrflFcGLhRIUVizoKb5s87VsYYa0d2mv0dCICbo2DpZ4Xurg(5TSCbeJJBcIb7)MDNhUi5Sz0uCP9HpOI6Mjh5Ycv0eCvmwDV2EFZ2I4YMevfTSY15fuCnIq8aB1cGK4yyJy9LF4RI4mPHFiDFGWrYotQI(j5xapFlZnWESLd1awh0VqfXmogR3JoH890jVFmsr9MMkAns5nBKyOEuVjQIOOLAOJzS0e2k8lsocbh0M6UxB3ILlqFULxiij6DDCXLBPJMmZZHKUsjyuqCHNH4cj4KFSrUipb3HojbYWCvRuglpD9MehUJMrYjJ9kZdMLt8cgngQwswUMatlMndhtBUkkLMrLTb3Sufq6SF)ZPaUaYNJJXblFnl16ddcqkX5fyKv3tI1(l8wYbSuykr(BxFY0seczZcZOZxipMo763rYxhwnZOJ0HQ(NwREP5yKcjZoX49hMvurclRDCAcP1Q9J2t6L3(aZy0(XsqYJLfe(69HxTHDJP(qOgpmxegxEQtd5Jj1)CKor71LHEMZZ7e3n7GiI2F0ep7yhasPvPCeiZ3nXXm0badoaEInrduHacfS4r5aKeMrO5HMQ3D6oxhgGviYX93nGWheiB2uSEVQL31(JETWuTR97XcHeleTLM3VDTiw6wwdPfLIjcPw8ruPjPDwfnfWkDOH3uHwnIKS2vZ6yt5PwrKHoH9YWFZklz180IQNlpF7hLgvPr6vl04XbD4exnpoXlJ8CxbCiNXELH4Gp8nq8RnsJTnnAobeUeYt0QLMu9)uVHFzLKSw6)w7rzv0jyxm3ZLoNeo21HhScv2MkLc36SFkBLJlDMup8YM3qXYGkr6QazL5(jOt1nt2AUrMUBElJL3SXMyNwwH65dX5Frs4ZbPNKMbHylJekC15J7n3z(HHEUMav3tYLsvd6AOlfAyCdUzPK4MthP98xqiKdzuq03AP0(rh6AUXMklDDOybl(jnF6aHQvCLRb(49PeO3TUv6kcpx7sGFGFkvifMRodZifPs8ZVBUknKtWEwjbFoW3sc8oXBl8fi1xUTBJ7sujWpMtLaNsc8DuHurJqnTD3utBs)LYQORqLrB5SMu)XEiL908w0P8AdTiJBhXHrJZ3dnmYuBXcZyTjHt70HXHl6Hd1o6g)ou80y8X9SokfJCrQuuYq2MkfAa)0EaSHqvBy59a7Fo40EPywp49x7TqWiI5cyFcDMiCKvKxx4QIU5AN7y3D5F0lVGT4BP7zsXNRIgR54KthscEJSOX3(Q0RKe7CLvpPgH(k)DxqDIsxcJ4MIk6uZwvtb1DTBv77OHT7AOFFcfBuBDjFpW3u5nq)p)6RzUlb1wVGYnyVt)ATnpJO6auhVOYEoPVNvvEoPVev7NxTps01JT2LOBRNCnSayDzhQPD(mSHfJnUTdfZ)F7ODi6QV22uhIe7RQ3ZHiYo4Mb9PY(gBg0RW4RSBGPSglRwWWS(xR(taQhn4)(]] )

spec:RegisterPack( "Protection", 20261027.1552, [[Hekili:LJ13VTTnq4)wkkGrcsMsC2s7wqtaw76qxEOOyQa9njstrzXejrdsQ6AGa(3(UJY6NwYk2PVTxcSeV77(UJ8(oQemp4Rb(rudp4ZxD5vVz(Lx9wV5xF9vb(MnR4b(ROShPlHFKtZG)(fL0WzgHmhxAtQKgHaOLfkgSCIXSsFZfxSuyskw4XKzxKWv0hfPI6Fe4VOqKA(N8GfJez9kodEjSkxZAhtl5l0uAKa(rSuzjFiLQ1cML8rf9gl5FfltmCzH2s(7c1MZTKpjt3yj(jcEAe8OpNMAjY4wMMZ1G5Nzj3xeTKNXZnGDFqMR5mfTmMMefNA8GewjJfPqA(6xdmziwDsBgzjZHe6u79O5(UkK(MUK2swv5QHM)OiFPLSSqa5nG13KRt40OwEmymrh36fq9VrvaXJnwYxPFNRY74KJj1ow5sn81C5VeAMufD6U1ulHMUMUr3R2cfvWnMuMgjxNVVk9dyzoQKjT9baohGrX1GN8OD2eOACJGBjzuxH(pLF80QTglzDcSVGRLdLuiDmibFFkerxjf5HpnNzkOykG4Tb2p080yVTBpo(YsKcgwsEO6WGLeXxuehFEn4ImHd9E0djpI3V0evQcOKBhc5DDzxZngyDnez79u3gJ2BLIdnllOMZU9cvvflmgpflIVfzGx3x75kAd6)ITmiughQRYAeMxrZ3ewT6mKT1p1y40yIht1tHNZOPXkdtQDX6KUG5S6PUVJwyKLlC60HzTqhjZMIZLwnmA4XsejyVmKPk00iUcX7HO6hN52MgYW9SzvzEddbelFOlELV7zGuAvjfaY97U44E1Zagv7(weUcnpulvZY58OqSlmenD)GaVaABIACNDqU3uuk9E9oEx7p4vcnlJRq)EOqBGg52lEinvOGaOVCt)MCrxnOkXhCjCmj2r3eqwlxXWHR8DEipNNj467M3H5GuAOUuj1f977R)akEB1nqrzgOWb0XOr1eu4ctylzbhMkY74nszGLrBQe1q3o3Lg4eaj4eWC4zzNudrTt28Yp(pRsP3RwC1tXXWPF3swKxg9hdfWdPV4idXZUH5aXV2ie7YTr3P2Wv88iCcXaC5q76oQETdQdBK8X9GZU9DOVEwhC1jty7vdrf3u(mCQQ3kM5UgB7ygUEiSE7OW)HuXe6SorO6LdRiSgGlPJ99w7OiYlDsBGpCfnna2oxbEnvLJCiWpWpva3NXDnDEmTi1a)8ZURTZZPaQrbVpWVKtWfW7RbgyWBspSXDf)c8zkHHReu8g6dRnIO9RJGw7QvBS6k8zj3b3lgX53glfAedrZUEeZgsOPDyBPmzjZaDU9pCgnz82Bl5DGAzzlosQ3mbPkBR6rNTxVyhY0EY(HrJ3obnCsx9yH7D7sIwxl4W4WVpchQDSD8hqfeX4pMip6Ok2gVTQJok3v4cHD(LtG7wjZDrKngIJ13n(g)wD1XaCSEZblFnIUoFp0oXjvJDKSsie6uVT1xRmOyOJgJ1ixPipifQxerySE8EA0dcupBoUuyS(5bf4BtJxHF6xJuVl6Ji3hGHYV(AU7tf)4eMh7O0p5Ky0bal6)nIhwmkDzpdgw0)7gNc)t6hISsTVNEQ)cnFmPLC6(M6SyNpQCksm0Ny(CgH8ZzU2ZzkXXoSAFQ)VOjq)VEKGtLaopMiHT9pv9)mfFBW)9d]] )

spec:RegisterPackSelector( "protection", "Protection", "|T135880:0|t Protection",
    "If you have spent more points in |T135880:0|t Protection than in any other tree, this priority will be automatically selected for you.",
    function( tab1, tab2, tab3 )
        return tab2 > max( tab1, tab3 )
    end )

spec:RegisterPackSelector( "retribution", "Retribution", "|T135873:0|t Retribution",
    "Otherwise (Retribution, Holy or no talents), this priority will be automatically selected for you.",
    function( tab1, tab2, tab3 )
        return tab2 <= max( tab1, tab3 )
    end )
