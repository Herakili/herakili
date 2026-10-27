-- Era/Warlock.lua
-- Classic Era (1.15.x) Warlock.  Spell, rank, aura and talent IDs from the Classic Era client tables.

if UnitClassBase( 'player' ) ~= 'WARLOCK' then return end

local addon, ns = ...
local Hekili = _G[ addon ]
local class, state = Hekili.Class, Hekili.State

local GetSpellPowerCost = _G.GetSpellPowerCost or ( C_Spell and C_Spell.GetSpellPowerCost )
local IsAutoRepeatSpell = _G.IsAutoRepeatSpell
local GetSpellInfo = _G.GetSpellInfo
local IsPlayerSpell = _G.IsPlayerSpell
local GetItemCount = _G.GetItemCount or ( C_Item and C_Item.GetItemCount )
local GetInventoryItemID = _G.GetInventoryItemID
local wipe = table.wipe or wipe

local spec = Hekili:NewSpecialization( 9 )

spec:RegisterResource( Enum.PowerType.Mana )


local function known_id( key )
    local ability = class.abilities[ key ]
    return ability and ability.id
end


-- Mana costs: the client's own cost for the rank you know (talents such as Cataclysm and Suppression included, and
-- percent-of-base-mana costs such as the summons resolved), refreshed every 5 seconds.
local cost_cache, cost_cache_time = {}, 0

local function mana_cost( key )
    local id = known_id( key )
    if not id then return 0 end

    local c = cost_cache[ id ]
    if c == nil then
        c = false
        if GetSpellPowerCost then
            local ok, costs = pcall( GetSpellPowerCost, id )
            if ok and type( costs ) == "table" then
                for _, p in ipairs( costs ) do
                    if type( p ) == "table" and p.type == 0 and ( p.cost or 0 ) > 0 then c = p.cost; break end
                end
            end
        end
        cost_cache[ id ] = c
    end

    return c or 0
end


-- Rank-dependent values, keyed by the spell ID of the highest rank you know.
local corruption_duration = { [172] = 12, [6222] = 15 }
local shadow_bolt_cast = { [686] = 1.7, [695] = 2.2, [705] = 2.8 }
local life_tap_amount = { [1454] = 30, [1455] = 75, [1456] = 140, [11687] = 220, [11688] = 310, [11689] = 424 }
local dark_pact_amount = { [18220] = 150, [18937] = 200, [18938] = 250 }


-- Talents: { talentID, maxRank, rank1SpellID, ... rankNSpellID }, from the Classic Era client's Talent table.
spec:RegisterTalents( {
    -- Affliction
    suppression                  = {  1005, 5, 18174, 18175, 18176, 18177, 18178 },
    improved_corruption          = {  1003, 5, 17810, 17811, 17812, 17813, 17814 },
    improved_curse_of_weakness   = {  1006, 3, 18179, 18180, 18181 },
    improved_drain_soul          = {  1101, 2, 18213, 18372 },
    improved_life_tap            = {  1007, 2, 18182, 18183 },
    improved_drain_life          = {  1004, 5, 17804, 17805, 17806, 17807, 17808 },
    improved_curse_of_agony      = {  1284, 3, 18827, 18829, 18830 },
    fel_concentration            = {  1001, 5, 17783, 17784, 17785, 17786, 17787 },
    amplify_curse                = {  1061, 1, 18288 },
    grim_reach                   = {  1021, 2, 18218, 18219 },
    nightfall                    = {  1002, 2, 18094, 18095 },
    improved_drain_mana          = {  1121, 2, 17864, 18393 },
    siphon_life                  = {  1041, 1, 18265 },
    curse_of_exhaustion          = {  1081, 1, 18223 },
    improved_curse_of_exhaustion = {  1082, 4, 18310, 18311, 18312, 18313 },
    shadow_mastery               = {  1042, 5, 18271, 18272, 18273, 18274, 18275 },
    dark_pact                    = {  1022, 1, 18220 },

    -- Demonology
    improved_healthstone         = {  1221, 2, 18692, 18693 },
    improved_imp                 = {  1222, 3, 18694, 18695, 18696 },
    demonic_embrace              = {  1223, 5, 18697, 18698, 18699, 18700, 18701 },
    improved_health_funnel       = {  1224, 2, 18703, 18704 },
    improved_voidwalker          = {  1225, 3, 18705, 18706, 18707 },
    fel_intellect                = {  1242, 5, 18731, 18743, 18744, 18745, 18746 },
    improved_sayaad              = {  1243, 3, 18754, 18755, 18756 },
    fel_domination               = {  1226, 1, 18708 },
    fel_stamina                  = {  1241, 5, 18748, 18749, 18750, 18751, 18752 },
    master_summoner              = {  1227, 2, 18709, 18710 },
    unholy_power                 = {  1262, 5, 18769, 18770, 18771, 18772, 18773 },
    improved_subjugate_demon     = {  1283, 5, 18821, 18822, 18823, 18824, 18825 },
    demonic_sacrifice            = {  1281, 1, 18788 },
    improved_firestone           = {  1261, 2, 18767, 18768 },
    master_demonologist          = {  1244, 5, 23785, 23822, 23823, 23824, 23825 },
    soul_link                    = {  1282, 1, 19028 },
    improved_spellstone          = {  1263, 2, 18774, 18775 },

    -- Destruction
    improved_shadow_bolt         = {   944, 5, 17793, 17796, 17801, 17802, 17803 },
    cataclysm                    = {   941, 5, 17778, 17779, 17780, 17781, 17782 },
    bane                         = {   943, 5, 17788, 17789, 17790, 17791, 17792 },
    aftermath                    = {   982, 5, 18119, 18120, 18121, 18122, 18123 },
    improved_firebolt            = {   983, 2, 18126, 18127 },
    improved_lash_of_pain        = {   984, 2, 18128, 18129 },
    devastation                  = {   981, 5, 18130, 18131, 18132, 18133, 18134 },
    shadowburn                   = {   963, 1, 17877 },
    intensity                    = {   985, 2, 18135, 18136 },
    destructive_reach            = {   964, 2, 17917, 17918 },
    improved_searing_pain        = {   965, 5, 17927, 17929, 17930, 17931, 17932 },
    pyroclasm                    = {   986, 2, 18096, 18073 },
    improved_immolate            = {   961, 5, 17815, 17833, 17834, 17835, 17836 },
    ruin                         = {   967, 1, 17959 },
    emberstorm                   = {   966, 5, 17954, 17955, 17956, 17957, 17958 },
    conflagrate                  = {   968, 1, 17962 },
} )


-- Auras
spec:RegisterAuras( {
    -- Increases the effect of your next Curse of Weakness or Curse of Agony by 50%, or Curse of Exhaustion by 20%.
    amplify_curse = {
        id = 18288,
        duration = 30,
        max_stack = 1,
    },
    -- Demonic Sacrifice (Imp): Fire damage increased by 15%.
    burning_wish = {
        id = 18789,
        duration = 1800,
        max_stack = 1,
    },
    corruption = {
        id = 25311,
        duration = function() return corruption_duration[ known_id( "corruption" ) ] or 18 end,
        tick_time = 3,
        max_stack = 1,
        copy = { 172, 6222, 6223, 7648, 11671, 11672, 25311 },
    },
    curse_of_agony = {
        id = 11713,
        duration = 24,
        tick_time = 2,
        max_stack = 1,
        copy = { 980, 1014, 6217, 11711, 11712, 11713 },
    },
    curse_of_doom = {
        id = 603,
        duration = 60,
        max_stack = 1,
    },
    curse_of_exhaustion = {
        id = 18223,
        duration = 12,
        max_stack = 1,
    },
    curse_of_recklessness = {
        id = 11717,
        duration = 120,
        max_stack = 1,
        shared = "target",
        copy = { 704, 7658, 7659, 11717 },
    },
    curse_of_shadow = {
        id = 17937,
        duration = 300,
        max_stack = 1,
        shared = "target",
        copy = { 17862, 17937 },
    },
    curse_of_the_elements = {
        id = 11722,
        duration = 300,
        max_stack = 1,
        shared = "target",
        copy = { 1490, 11721, 11722 },
    },
    curse_of_tongues = {
        id = 11719,
        duration = 30,
        max_stack = 1,
        shared = "target",
        copy = { 1714, 11719 },
    },
    curse_of_weakness = {
        id = 11708,
        duration = 120,
        max_stack = 1,
        shared = "target",
        copy = { 702, 1108, 6205, 7646, 11707, 11708 },
    },
    death_coil = {
        id = 17926,
        duration = 3,
        max_stack = 1,
        copy = { 6789, 17925, 17926 },
    },
    demon_armor = {
        id = 11735,
        duration = 1800,
        max_stack = 1,
        copy = { 706, 1086, 11733, 11734, 11735 },
    },
    demon_skin = {
        id = 696,
        duration = 1800,
        max_stack = 1,
        copy = { 687, 696 },
    },
    drain_life = {
        id = 11700,
        duration = 5,
        tick_time = 1,
        max_stack = 1,
        copy = { 689, 699, 709, 7651, 11699, 11700 },
    },
    drain_soul = {
        id = 11675,
        duration = 15,
        tick_time = 3,
        max_stack = 1,
        copy = { 1120, 8288, 8289, 11675 },
    },
    -- Demonic Sacrifice (Felhunter): restores 2% of total mana every 4 sec.
    fel_energy = {
        id = 18792,
        duration = 1800,
        max_stack = 1,
    },
    fel_domination = {
        id = 18708,
        duration = 15,
        max_stack = 1,
    },
    -- Demonic Sacrifice (Voidwalker): restores 2% of total health every 4 sec.
    fel_stamina = {
        id = 18790,
        duration = 1800,
        max_stack = 1,
    },
    hellfire = {
        id = 11684,
        duration = 15,
        tick_time = 1,
        max_stack = 1,
        copy = { 1949, 11683, 11684 },
    },
    immolate = {
        id = 25309,
        duration = 15,
        tick_time = 3,
        max_stack = 1,
        copy = { 348, 707, 1094, 2941, 11665, 11667, 11668, 25309 },
    },
    rain_of_fire = {
        id = 11678,
        duration = 8,
        tick_time = 2,
        max_stack = 1,
        copy = { 5740, 6219, 11677, 11678 },
    },
    -- Improved Shadow Bolt: Shadow damage taken increased by 20%.
    shadow_vulnerability = {
        id = 17800,
        duration = 12,
        max_stack = 4,
        shared = "target",
        copy = { 17794, 17797, 17798, 17799, 17800 },
    },
    -- Nightfall: your next Shadow Bolt is instant.
    shadow_trance = {
        id = 17941,
        duration = 10,
        max_stack = 1,
    },
    -- Pseudo-aura: wand auto-repeat (Shoot) is active.
    shooting = {
        duration = 3600,
        max_stack = 1,
    },
    siphon_life = {
        id = 18881,
        duration = 30,
        tick_time = 3,
        max_stack = 1,
        copy = { 18265, 18879, 18880, 18881 },
    },
    soul_link = {
        id = 25228,
        duration = 3600,
        max_stack = 1,
        copy = { 25228, 19028 },
    },
    -- Demonic Sacrifice (Succubus): Shadow damage increased by 15%.
    touch_of_shadow = {
        id = 18791,
        duration = 1800,
        max_stack = 1,
    },

    -- Aliases.
    armor = {
        alias = { "demon_armor", "demon_skin" },
        aliasMode = "first",
        aliasType = "buff",
    },
    sacrificed = {
        alias = { "touch_of_shadow", "burning_wish", "fel_energy", "fel_stamina" },
        aliasMode = "first",
        aliasType = "buff",
    },
} )


spec:RegisterPet( "imp", 416, "summon_imp", 3600 )
spec:RegisterPet( "voidwalker", 1860, "summon_voidwalker", 3600 )
spec:RegisterPet( "succubus", 1863, "summon_succubus", 3600 )
spec:RegisterPet( "felhunter", 417, "summon_felhunter", 3600 )


-- Soul Shards in your bags (item 6265); spent by Shadowburn, Soul Fire and the Voidwalker/Succubus/Felhunter summons.
spec:RegisterStateExpr( "shard_count", function()
    return GetItemCount and GetItemCount( 6265 ) or 0
end )

spec:RegisterStateFunction( "spend_shard", function()
    shard_count = max( 0, shard_count - 1 )
end )


-- Curse choice (settings "Curse (solo / party)" and "Curse (raid)").
-- A curse you have not learned yet falls back to Curse of Agony (rank 1 IDs; lower ranks stay in the spellbook).
local curse_spells = { agony = 980, doom = 603, shadow = 17862, elements = 1490, recklessness = 704, weakness = 702, tongues = 1714 }

local function chosen_curse()
    local s = state.settings
    local c
    if state.raid then c = s.curse_raid or "agony"
    else c = s.curse_solo or "agony" end

    local id = curse_spells[ c ]
    if id and not IsPlayerSpell( id ) then return "agony" end
    return c
end

spec:RegisterStateExpr( "curse_agony", function() return chosen_curse() == "agony" end )
spec:RegisterStateExpr( "curse_doom", function() return chosen_curse() == "doom" end )
spec:RegisterStateExpr( "curse_shadow", function() return chosen_curse() == "shadow" end )
spec:RegisterStateExpr( "curse_elements", function() return chosen_curse() == "elements" end )
spec:RegisterStateExpr( "curse_recklessness", function() return chosen_curse() == "recklessness" end )
spec:RegisterStateExpr( "curse_weakness", function() return chosen_curse() == "weakness" end )
spec:RegisterStateExpr( "curse_tongues", function() return chosen_curse() == "tongues" end )


-- Pet choice (setting "Demon").  Falls back to a demon you can summon (the Voidwalker, Succubus and Felhunter
-- need a Soul Shard; the Imp is free).
local pet_spells = { imp = 688, voidwalker = 697, succubus = 712, felhunter = 691 }

local function can_summon( p )
    if not IsPlayerSpell( pet_spells[ p ] ) then return false end
    return p == "imp" or state.shard_count > 0
end

local function chosen_pet()
    local s = state.settings
    local want = s.pet or "auto"
    if want == "none" then return "none" end

    if want == "auto" then
        if state.talent.demonic_sacrifice.enabled and s.demonic_sacrifice and not state.talent.soul_link.enabled then
            -- Sacrifice the Succubus for Shadow damage, or the Imp for a Fire build.
            want = state.talent.emberstorm.rank >= 3 and "imp" or "succubus"
        elseif not state.group then
            want = "voidwalker"
        else
            want = "imp"
        end
    end

    if can_summon( want ) then return want end
    if want ~= "voidwalker" and not state.group and can_summon( "voidwalker" ) then return "voidwalker" end
    if can_summon( "imp" ) then return "imp" end
    return "none"
end

spec:RegisterStateExpr( "pet_imp", function() return chosen_pet() == "imp" end )
spec:RegisterStateExpr( "pet_voidwalker", function() return chosen_pet() == "voidwalker" end )
spec:RegisterStateExpr( "pet_succubus", function() return chosen_pet() == "succubus" end )
spec:RegisterStateExpr( "pet_felhunter", function() return chosen_pet() == "felhunter" end )

-- No demon out and none expected to be sacrificed: a summon is due.
spec:RegisterStateExpr( "pet_needed", function()
    if ( settings.pet or "auto" ) == "none" then return false end
    if pet.alive then return false end
    if buff.sacrificed.up then return false end
    return true
end )

spec:RegisterStateExpr( "dark_pact_mana", function()
    return dark_pact_amount[ known_id( "dark_pact" ) or 0 ] or 250
end )

spec:RegisterStateExpr( "life_tap_mana", function()
    return ( life_tap_amount[ known_id( "life_tap" ) or 0 ] or 424 ) * ( 1 + 0.1 * talent.improved_life_tap.rank )
end )

spec:RegisterStateExpr( "has_wand", function()
    return GetInventoryItemID( "player", 18 ) ~= nil
end )


spec:RegisterStateFunction( "sacrifice_pet", function()
    if pet.imp.up then applyBuff( "burning_wish" )
    elseif pet.voidwalker.up then applyBuff( "fel_stamina" )
    elseif pet.succubus.up then applyBuff( "touch_of_shadow" )
    elseif pet.felhunter.up then applyBuff( "fel_energy" ) end

    dismissPet( "imp" )
    dismissPet( "voidwalker" )
    dismissPet( "succubus" )
    dismissPet( "felhunter" )
end )

spec:RegisterStateFunction( "summon_demon", function( p )
    for k in pairs( pet_spells ) do
        if k ~= p then dismissPet( k ) end
    end
    summonPet( p )
    removeBuff( "sacrificed" )
    removeBuff( "soul_link" )
    removeBuff( "fel_domination" )
    if p ~= "imp" then spend_shard() end
end )


spec:RegisterHook( "reset_precast", function()
    if now - cost_cache_time > 5 then
        wipe( cost_cache )
        cost_cache_time = now
    end

    shard_count = nil

    local shoot = GetSpellInfo and GetSpellInfo( 5019 )
    if shoot and IsAutoRepeatSpell and IsAutoRepeatSpell( shoot ) then applyBuff( "shooting" ) end
end )


-- Summons: Fel Domination halves the cost; the client already includes it once the buff is really up.
local function summon_cost( key )
    local c = mana_cost( key )
    if state.buff.fel_domination.up and state.buff.fel_domination.applied >= state.now then return c * 0.5 end
    return c
end

local function cast_time( base )
    -- Module-level helper (not run in Hekili's state environment), so state values need the state. prefix.
    return base * state.haste
end


-- Abilities
spec:RegisterAbilities( {
    -- Increases the effect of your next Curse of Agony / Weakness by 50%.
    amplify_curse = {
        id = 18288,
        cast = 0,
        cooldown = 180,
        gcd = "off",

        talent = "amplify_curse",
        startsCombat = false,
        texture = 136132,

        handler = function()
            applyBuff( "amplify_curse" )
        end,
    },


    conflagrate = {
        id = 18932,
        cast = 0,
        cooldown = 10,
        gcd = "spell",

        spend = function() return mana_cost( "conflagrate" ) end,
        spendType = "mana",

        talent = "conflagrate",
        startsCombat = true,
        texture = 135807,

        debuff = "immolate",

        handler = function()
            removeDebuff( "target", "immolate" )
        end,

        copy = { 17962, 18930, 18931 }
    },


    corruption = {
        id = 25311,
        cast = function() return cast_time( max( 0, 2 - 0.4 * talent.improved_corruption.rank ) ) end,
        cooldown = 0,
        gcd = "spell",

        spend = function() return mana_cost( "corruption" ) end,
        spendType = "mana",

        startsCombat = true,
        texture = 136118,

        handler = function()
            applyDebuff( "target", "corruption" )
        end,

        copy = { 172, 6222, 6223, 7648, 11671, 11672 }
    },


    curse_of_agony = {
        id = 11713,
        cast = 0,
        cooldown = 0,
        gcd = "spell",

        spend = function() return mana_cost( "curse_of_agony" ) end,
        spendType = "mana",

        startsCombat = true,
        texture = 136139,

        handler = function()
            removeBuff( "amplify_curse" )
            removeDebuff( "target", "curse_of_doom" )
            applyDebuff( "target", "curse_of_agony" )
        end,

        copy = { 980, 1014, 6217, 11711, 11712 }
    },


    -- Deals heavy Shadow damage after 1 min.  Cannot be cast on players.
    curse_of_doom = {
        id = 603,
        cast = 0,
        cooldown = 60,
        gcd = "spell",

        spend = function() return mana_cost( "curse_of_doom" ) end,
        spendType = "mana",

        startsCombat = true,
        texture = 136122,

        handler = function()
            removeDebuff( "target", "curse_of_agony" )
            applyDebuff( "target", "curse_of_doom" )
        end,
    },


    curse_of_recklessness = {
        id = 11717,
        cast = 0,
        cooldown = 0,
        gcd = "spell",

        spend = function() return mana_cost( "curse_of_recklessness" ) end,
        spendType = "mana",

        startsCombat = true,
        texture = 136225,

        handler = function()
            applyDebuff( "target", "curse_of_recklessness" )
        end,

        copy = { 704, 7658, 7659 }
    },


    curse_of_shadow = {
        id = 17937,
        cast = 0,
        cooldown = 0,
        gcd = "spell",

        spend = function() return mana_cost( "curse_of_shadow" ) end,
        spendType = "mana",

        startsCombat = true,
        texture = 136137,

        handler = function()
            applyDebuff( "target", "curse_of_shadow" )
        end,

        copy = { 17862 }
    },


    curse_of_the_elements = {
        id = 11722,
        cast = 0,
        cooldown = 0,
        gcd = "spell",

        spend = function() return mana_cost( "curse_of_the_elements" ) end,
        spendType = "mana",

        startsCombat = true,
        texture = 136130,

        handler = function()
            applyDebuff( "target", "curse_of_the_elements" )
        end,

        copy = { 1490, 11721 }
    },


    curse_of_tongues = {
        id = 11719,
        cast = 0,
        cooldown = 0,
        gcd = "spell",

        spend = function() return mana_cost( "curse_of_tongues" ) end,
        spendType = "mana",

        startsCombat = true,
        texture = 136140,

        handler = function()
            applyDebuff( "target", "curse_of_tongues" )
        end,

        copy = { 1714 }
    },


    curse_of_weakness = {
        id = 11708,
        cast = 0,
        cooldown = 0,
        gcd = "spell",

        spend = function() return mana_cost( "curse_of_weakness" ) end,
        spendType = "mana",

        startsCombat = true,
        texture = 136138,

        handler = function()
            removeBuff( "amplify_curse" )
            applyDebuff( "target", "curse_of_weakness" )
        end,

        copy = { 702, 1108, 6205, 7646, 11707 }
    },


    -- Drains your pet's mana and gives it to you.
    dark_pact = {
        id = 18938,
        cast = 0,
        cooldown = 0,
        gcd = "spell",

        talent = "dark_pact",
        startsCombat = false,
        texture = 136141,

        usable = function() return pet.alive and pet.mana_current >= dark_pact_mana, "requires pet mana" end,

        handler = function()
            gain( dark_pact_mana, "mana" )
        end,

        copy = { 18220, 18937 }
    },


    -- Horrifies the target for 3 sec and heals you for 100% of the damage dealt.
    death_coil = {
        id = 17926,
        cast = 0,
        cooldown = 120,
        gcd = "spell",

        spend = function() return mana_cost( "death_coil" ) end,
        spendType = "mana",

        startsCombat = true,
        texture = 136145,

        toggle = "defensives",

        handler = function()
            applyDebuff( "target", "death_coil" )
        end,

        copy = { 6789, 17925 }
    },


    demon_armor = {
        id = 11735,
        cast = 0,
        cooldown = 0,
        gcd = "spell",

        spend = function() return mana_cost( "demon_armor" ) end,
        spendType = "mana",

        startsCombat = false,
        texture = 136185,

        handler = function()
            removeBuff( "demon_skin" )
            applyBuff( "demon_armor" )
        end,

        copy = { 706, 1086, 11733, 11734 }
    },


    demon_skin = {
        id = 696,
        cast = 0,
        cooldown = 0,
        gcd = "spell",

        spend = function() return mana_cost( "demon_skin" ) end,
        spendType = "mana",

        startsCombat = false,
        texture = 136185,

        handler = function()
            removeBuff( "demon_armor" )
            applyBuff( "demon_skin" )
        end,

        copy = { 687 }
    },


    -- Sacrifices your demon for a 30 min buff that depends on the demon.
    demonic_sacrifice = {
        id = 18788,
        cast = 0,
        cooldown = 0,
        gcd = "spell",

        talent = "demonic_sacrifice",
        startsCombat = false,
        texture = 136184,

        usable = function() return pet.alive, "requires a demon" end,

        handler = function()
            sacrifice_pet()
        end,
    },


    drain_life = {
        id = 11700,
        cast = function() return 5 * haste end,
        cooldown = 0,
        gcd = "spell",

        channeled = true,
        breakable = true,

        spend = function() return mana_cost( "drain_life" ) end,
        spendType = "mana",

        startsCombat = true,
        texture = 136169,

        aura = "drain_life",
        tick_time = function() return class.auras.drain_life.tick_time end,

        start = function()
            applyDebuff( "target", "drain_life" )
        end,

        tick = function() end,

        breakchannel = function()
            removeDebuff( "target", "drain_life" )
        end,

        handler = function() end,

        copy = { 689, 699, 709, 7651, 11699 }
    },


    drain_soul = {
        id = 11675,
        cast = function() return 15 * haste end,
        cooldown = 0,
        gcd = "spell",

        channeled = true,
        breakable = true,

        spend = function() return mana_cost( "drain_soul" ) end,
        spendType = "mana",

        startsCombat = true,
        texture = 136163,

        aura = "drain_soul",
        tick_time = function() return class.auras.drain_soul.tick_time end,

        start = function()
            applyDebuff( "target", "drain_soul" )
        end,

        tick = function() end,

        breakchannel = function()
            removeDebuff( "target", "drain_soul" )
        end,

        handler = function() end,

        copy = { 1120, 8288, 8289 }
    },


    -- Your next demon summon is 5.5 sec faster and costs 50% less mana.
    fel_domination = {
        id = 18708,
        cast = 0,
        cooldown = 900,
        gcd = "off",

        talent = "fel_domination",
        startsCombat = false,
        texture = 136082,

        toggle = "cooldowns",

        handler = function()
            applyBuff( "fel_domination" )
        end,
    },


    hellfire = {
        id = 11684,
        cast = function() return 15 * haste end,
        cooldown = 0,
        gcd = "spell",

        channeled = true,
        breakable = true,

        spend = function() return mana_cost( "hellfire" ) end,
        spendType = "mana",

        startsCombat = true,
        texture = 135818,

        aura = "hellfire",

        start = function()
            applyBuff( "hellfire" )
        end,

        breakchannel = function()
            removeBuff( "hellfire" )
        end,

        copy = { 1949, 11683 }
    },


    immolate = {
        id = 25309,
        cast = function() return cast_time( 2 - 0.1 * talent.bane.rank ) end,
        cooldown = 0,
        gcd = "spell",

        spend = function() return mana_cost( "immolate" ) end,
        spendType = "mana",

        startsCombat = true,
        texture = 135817,

        handler = function()
            applyDebuff( "target", "immolate" )
        end,

        copy = { 348, 707, 1094, 2941, 11665, 11667, 11668 }
    },


    -- Converts health into mana.
    life_tap = {
        id = 11689,
        cast = 0,
        cooldown = 0,
        gcd = "spell",

        startsCombat = false,
        texture = 136126,

        -- The health cost is applied in the handler (no health forecasting in the resource model).
        usable = function() return health.current > ( life_tap_amount[ known_id( "life_tap" ) or 0 ] or 424 ), "not enough health" end,

        handler = function()
            spend( life_tap_amount[ known_id( "life_tap" ) or 0 ] or 424, "health" )
            gain( life_tap_mana, "mana" )
        end,

        copy = { 1454, 1455, 1456, 11687, 11688 }
    },


    rain_of_fire = {
        id = 11678,
        cast = function() return 8 * haste end,
        cooldown = 0,
        gcd = "spell",

        channeled = true,
        breakable = true,

        spend = function() return mana_cost( "rain_of_fire" ) end,
        spendType = "mana",

        startsCombat = true,
        texture = 136186,

        aura = "rain_of_fire",

        start = function()
            applyDebuff( "target", "rain_of_fire" )
        end,

        breakchannel = function()
            removeDebuff( "target", "rain_of_fire" )
        end,

        copy = { 5740, 6219, 11677 }
    },


    -- Fire damage; causes a high amount of threat.
    searing_pain = {
        id = 17923,
        cast = function() return cast_time( 1.5 ) end,
        cooldown = 0,
        gcd = "spell",

        spend = function() return mana_cost( "searing_pain" ) end,
        spendType = "mana",

        startsCombat = true,
        texture = 135827,

        handler = function() end,

        copy = { 5676, 17919, 17920, 17921, 17922 }
    },


    shadow_bolt = {
        id = 25307,
        cast = function()
            if buff.shadow_trance.up then return 0 end
            return cast_time( ( shadow_bolt_cast[ known_id( "shadow_bolt" ) ] or 3 ) - 0.1 * talent.bane.rank )
        end,
        cooldown = 0,
        gcd = "spell",

        spend = function() return mana_cost( "shadow_bolt" ) end,
        spendType = "mana",

        startsCombat = true,
        texture = 136197,

        velocity = 20,

        handler = function()
            removeBuff( "shadow_trance" )
        end,

        copy = { 686, 695, 705, 1088, 1106, 7641, 11659, 11660, 11661 }
    },


    -- Instant Shadow damage; costs a Soul Shard.
    shadowburn = {
        id = 18871,
        cast = 0,
        cooldown = 15,
        gcd = "spell",

        spend = function() return mana_cost( "shadowburn" ) end,
        spendType = "mana",

        talent = "shadowburn",
        startsCombat = true,
        texture = 136191,

        usable = function() return shard_count > 0, "requires a soul shard" end,

        handler = function()
            spend_shard()
        end,

        copy = { 17877, 18867, 18868, 18869, 18870 }
    },


    -- Wand.
    shoot = {
        id = 5019,
        cast = 0,
        cooldown = 0,
        gcd = "spell",

        startsCombat = true,
        texture = 132317,

        nobuff = "shooting",
        usable = function() return has_wand, "requires a wand" end,

        handler = function()
            applyBuff( "shooting" )
        end,
    },


    siphon_life = {
        id = 18881,
        cast = 0,
        cooldown = 0,
        gcd = "spell",

        spend = function() return mana_cost( "siphon_life" ) end,
        spendType = "mana",

        talent = "siphon_life",
        startsCombat = true,
        texture = 136188,

        handler = function()
            applyDebuff( "target", "siphon_life" )
        end,

        copy = { 18265, 18879, 18880 }
    },


    -- Long Fire nuke; costs a Soul Shard.
    soul_fire = {
        id = 17924,
        cast = function() return cast_time( 6 - 0.4 * talent.bane.rank ) end,
        cooldown = 60,
        gcd = "spell",

        spend = function() return mana_cost( "soul_fire" ) end,
        spendType = "mana",

        startsCombat = true,
        texture = 135808,

        usable = function() return shard_count > 0, "requires a soul shard" end,

        handler = function()
            spend_shard()
        end,

        copy = { 6353 }
    },


    -- Links you and your demon: 20% of your damage taken goes to the demon, both deal 3% more damage.
    soul_link = {
        id = 19028,
        cast = 0,
        cooldown = 0,
        gcd = "spell",

        spend = function() return mana_cost( "soul_link" ) end,
        spendType = "mana",

        talent = "soul_link",
        startsCombat = false,
        texture = 136160,

        usable = function() return pet.alive, "requires a demon" end,

        handler = function()
            applyBuff( "soul_link" )
        end,
    },


    summon_felhunter = {
        id = 691,
        cast = function() return buff.fel_domination.up and 4.5 or ( 10 - 2 * talent.master_summoner.rank ) end,
        cooldown = 0,
        gcd = "spell",

        spend = function() return summon_cost( "summon_felhunter" ) end,
        spendType = "mana",

        startsCombat = false,
        texture = 136217,
        essential = true,

        usable = function() return shard_count > 0, "requires a soul shard" end,

        handler = function()
            summon_demon( "felhunter" )
        end,
    },


    summon_imp = {
        id = 688,
        cast = function() return buff.fel_domination.up and 4.5 or ( 10 - 2 * talent.master_summoner.rank ) end,
        cooldown = 0,
        gcd = "spell",

        spend = function() return summon_cost( "summon_imp" ) end,
        spendType = "mana",

        startsCombat = false,
        texture = 136218,
        essential = true,

        handler = function()
            summon_demon( "imp" )
        end,
    },


    summon_succubus = {
        id = 712,
        cast = function() return buff.fel_domination.up and 4.5 or ( 10 - 2 * talent.master_summoner.rank ) end,
        cooldown = 0,
        gcd = "spell",

        spend = function() return summon_cost( "summon_succubus" ) end,
        spendType = "mana",

        startsCombat = false,
        texture = 136220,
        essential = true,

        usable = function() return shard_count > 0, "requires a soul shard" end,

        handler = function()
            summon_demon( "succubus" )
        end,
    },


    summon_voidwalker = {
        id = 697,
        cast = function() return buff.fel_domination.up and 4.5 or ( 10 - 2 * talent.master_summoner.rank ) end,
        cooldown = 0,
        gcd = "spell",

        spend = function() return summon_cost( "summon_voidwalker" ) end,
        spendType = "mana",

        startsCombat = false,
        texture = 136221,
        essential = true,

        usable = function() return shard_count > 0, "requires a soul shard" end,

        handler = function()
            summon_demon( "voidwalker" )
        end,
    },
} )


-- Settings
local curse_values = {
    agony = "Curse of Agony",
    doom = "Curse of Doom (Agony on short fights)",
    shadow = "Curse of Shadow",
    elements = "Curse of the Elements",
    recklessness = "Curse of Recklessness",
    weakness = "Curse of Weakness",
    tongues = "Curse of Tongues",
    none = "None",
}

spec:RegisterSetting( "warlock_description", nil, {
    type = "description",
    name = "Adjust the settings below to match your raid assignment and playstyle.  The defaults follow Classic Era " ..
        "warlock guides and sims; Fear and Banish are never part of the priority."
} )

spec:RegisterSetting( "curses_header", nil, {
    type = "header",
    name = "Curses"
} )

spec:RegisterSetting( "curse_solo", "agony", {
    type = "select",
    name = "Curse (solo and party)",
    desc = "The curse to keep on your target when you are not in a raid.  Curse of Doom falls back to Curse of Agony " ..
        "when the target dies within ~65 seconds.  Only one curse per warlock can be on a target.",
    width = "full",
    values = curse_values,
} )

spec:RegisterSetting( "curse_raid", "agony", {
    type = "select",
    name = "Curse (raid)",
    desc = "The curse to keep on your target in a raid (your raid assignment: Recklessness, Elements, Shadow; or " ..
        "Agony / Doom if unassigned).  Shadow, Elements, Recklessness, Weakness and Tongues are not reapplied while " ..
        "another warlock's copy is up.",
    width = "full",
    values = curse_values,
} )

spec:RegisterSetting( "mana_header", nil, {
    type = "header",
    name = "Mana"
} )

spec:RegisterSetting( "life_tap_mana_pct", 35, {
    type = "range",
    name = "Life Tap / Dark Pact Below Mana %",
    desc = "Life Tap (or Dark Pact, if talented and your demon has the mana) is recommended when your mana is below this percentage.",
    width = "full",
    min = 0,
    max = 100,
    step = 1,
} )

spec:RegisterSetting( "life_tap_health_pct", 50, {
    type = "range",
    name = "Life Tap Only Above Health %",
    desc = "Life Tap is only recommended while your health is above this percentage.",
    width = "full",
    min = 0,
    max = 100,
    step = 1,
} )

spec:RegisterSetting( "wand_mana_pct", 10, {
    type = "range",
    name = "Wand Below Mana %",
    desc = "When your mana is below this percentage (and Life Tap is not an option), Shoot (wand) is recommended.  " ..
        "Requires a wand.",
    width = "full",
    min = 0,
    max = 100,
    step = 1,
} )

spec:RegisterSetting( "spells_header", nil, {
    type = "header",
    name = "Spells"
} )

spec:RegisterSetting( "immolate", true, {
    type = "toggle",
    name = "Use Immolate",
    desc = "When enabled, Immolate is kept on your target (when it will live long enough).  Disable it when debuff " ..
        "slots or mana are tight.",
    width = "full",
} )

spec:RegisterSetting( "drain_soul_execute", false, {
    type = "toggle",
    name = "Drain Soul Execute",
    desc = "When enabled, Drain Soul is recommended once your target is below 25% health, for Soul Shards and, with " ..
        "Improved Drain Soul, the mana regeneration on kill.  On Era it does not deal extra damage at low health, so " ..
        "Shadow Bolt is more damage.",
    width = "full",
} )

spec:RegisterSetting( "soul_fire", false, {
    type = "toggle",
    name = "Use Soul Fire",
    desc = "When enabled, Soul Fire (6 sec cast, 1 min cooldown, costs a Soul Shard) is recommended when you have a " ..
        "Soul Shard and the target will live long enough.",
    width = "full",
} )

spec:RegisterSetting( "searing_pain", false, {
    type = "toggle",
    name = "Searing Pain Filler",
    desc = "When enabled, Searing Pain replaces Shadow Bolt as the filler (Fire builds with Improved Searing Pain).  " ..
        "Searing Pain causes a high amount of threat.",
    width = "full",
} )

spec:RegisterSetting( "drain_life_health", 35, {
    type = "range",
    name = "Drain Life Below Health %",
    desc = "Drain Life (and Death Coil, on the Defensives toggle) is recommended when your health is below this percentage.  " ..
        "Set to 0 to disable.  While solo with a Voidwalker, Drain Life is also used to keep your health topped up.",
    width = "full",
    min = 0,
    max = 100,
    step = 1,
} )

spec:RegisterSetting( "aoe_header", nil, {
    type = "header",
    name = "Area of Effect"
} )

spec:RegisterSetting( "aoe_targets", 3, {
    type = "range",
    name = "AoE Spells At Enemies",
    desc = "Rain of Fire / Hellfire are recommended with at least this many enemies.",
    width = "full",
    min = 2,
    max = 10,
    step = 1,
} )

spec:RegisterSetting( "aoe_rain_of_fire", true, {
    type = "toggle",
    name = "Use Rain of Fire",
    desc = "When enabled, Rain of Fire is recommended against groups of enemies.",
    width = "full",
} )

spec:RegisterSetting( "aoe_hellfire", false, {
    type = "toggle",
    name = "Use Hellfire",
    desc = "When enabled, Hellfire is recommended against groups of enemies within 10 yards (it damages you as well; " ..
        "only while your health is above 50%).",
    width = "full",
} )

spec:RegisterSetting( "pet_header", nil, {
    type = "header",
    name = "Demon"
} )

spec:RegisterSetting( "pet", "auto", {
    type = "select",
    name = "Demon",
    desc = "The demon to summon when none is out (only recommended out of combat, or after Fel Domination).\n\n" ..
        "Automatic: Voidwalker when solo, Imp in a group; with Demonic Sacrifice the Succubus (Imp for Fire builds).  " ..
        "Demons you cannot summon yet (or without a Soul Shard) fall back to one you can.",
    width = "full",
    values = {
        auto = "Automatic",
        imp = "Imp",
        voidwalker = "Voidwalker",
        succubus = "Succubus",
        felhunter = "Felhunter",
        none = "None (no summons)",
    },
} )

spec:RegisterSetting( "demonic_sacrifice", true, {
    type = "toggle",
    name = "Demonic Sacrifice",
    desc = "With the Demonic Sacrifice talent (and not Soul Link), recommend sacrificing your demon for its buff.  " ..
        "While the buff is up, no demon is expected.",
    width = "full",
} )


spec:RegisterOptions( {
    enabled = true,

    aoe = 3,

    gcd = 687, -- Demon Skin (level 1, on the GCD, no cooldown).

    nameplates = true,
    nameplateRange = 30,

    damage = true,
    damageExpiration = 6,

    package = "Affliction",
    usePackSelector = true
} )


spec:RegisterPack( "Affliction", 20261027.1212, [[Hekili:9Q1FVTnos0plflGVeCfo2PNtt7fhGET7HB3RxqbCxS)NKOLOSjSKOafvsdqG(SVZqkkrjrj74f3II6AZF8EpoKZWziQ3sVV7TjIiPEpC9IRVz5IRF)8LxV8AVnYNZPEBYjHhi7GVKrsHp)uCCcluY4zyxpNWjriaf8sri09EPmV4JxD1oMCF525H80R2tfKdSewZx82STKLi)LmVTJWCron07Hpa9slc9285esrblSk4NfKQGwfuf87ercp8aifbpMLac4N(jNJOk4IUOSC(Yvxw9R4W3O0EXhvdouqILvbFN8ivat)kOr(t7PKOQGgaEYG5x(2MQGDLmqMVTkqUN6AqfSuG9)RGvi5XuX(9nIAdlTmHi5I6jDzvqenMuMilMRL2Nlffua6VYIPOOYrwe0I98KiKYFjnLdiGd5lccltTysQcO)GgwA3mcWBrrLfb)ZN4)Cva8vKVu0kfUNZcbgic4dC8Q1sJTRGkLSSDgv9f(3lQhRGsYZtyuakEgIamXNRcIjjGk4XXWkpJxfKdKrtvMfwwe)jC0QnIlbiR(vIAZQyEUGcNy2sK)91xPuMprKYfVLfVEBzC8C1VMlOPWAQ4UBwm1mloWYELtmeuTVUd)ey76T4r(15uP7HNa2uFjjhzjLKrMNhkVRXuz61h7Yh6AgCkkrUhh19dhLUtCCwgeGKyAIFepLLrWwqQa94NrPr0Ozswk9(f2d)4lHrheC0JMvWEKE8Hs4uujy7ps9PzWwlT4(1nRkOFyrj2rLf2GvSNa79(B5jYMDM62KccC8zEz(mhTA23E3Xvwi6W0Htw(E1iIvsoIQXVT15arzZ0QDoAq9LC)ig9(LDnSCHOm3ShudtBJJIYT2GWmURaengltJZQb187tuyNIr1E8LfuFMKMwGJE4bOimEHpeopPJiBB2Vo2IrzTNQV76vhFdsq3rZgsOz)5n7eC4qaCGD(JCw0tKKdubESWIMBxmZ4UzDMddT14RDCdeNJttzJF51Hgmt0fvfieJ0a3BuuMQcJYZsGGF8sjg7dIQQIuaHa5ciCzSKc)Z)MMGbqno0xQV3iRglmc5gsOGfRchFLjE(xzzhMBffIIXF0S6ZsZ7fwa)k06SlWT31lErTK7gibmPxocET2DhW225zIErzyy52YchyB66mrgg4(YmPtz303Rf7i9UIFHztPRxr)EN9gjjHMjNR8usWDnAgzBIwgZjjq8Y6iCMPePodoynzMF9IPZuBWwpZ252ecxPCcCFsiNPCKTCF65tRUbs39ia1Xb9ebQfk4UaaK90KKyMOR5dVMW0HjCseePaJAD3Yf2xyUArFevCYJ9DIQDNgNvvUuFeDsbpRC0xSjfn1VQfqvqvWVjH0uLGRS66K2CDIXuVWCDGOacj6RVLgZfnP9q)roqOLJQA(GyjPqssXp7R(nQw1x8j74zpBI7RBceTQ1tj6Fd8ntnIZtBHh)1a0Xghf8Bwnb4kDHOFHL6FXIQHaE36BwD5ulWxL6MCPRdZ3U41)Eab6MBsPyQ1lSN6ttOPG)CrlUMwgGS9Wpj8HujpKqlkYG)2IVDRd4WUZtIJNOKdDX30YaSnDCs4k5z7kPwWw3WqRIUD7C40UJ)p4YvWB8leb4a(nGi4Esv80)g4VH38EzR3vt5p)tDjmWNQ7mBUPfhFDfnsouVrIPeJ64rqROdEULRPkrem8giaFOix5jMg)qe()wDa9jsL7HBw6LVI3gO81cyYdkTgI5LHZWBJ3gmRScS6DfbWxEq9ya13y59V82OvawLETrYBdCTfCpkJ4TXOIQG7SkrCW61tcIyeCnd(mGTkyMz7vp67Dn6wZjkJ3nImug2JRHogzp8pBQRxFkBx3KmSzPnjf1Ibd1PwglMYK1pTA92OV(1zaeNADo5CBUZhr4F0dHwrJtVTOpqVRTSqwf(DIScZa5B1O7mnjVBlc3v5GgXXlFuTx(oKSBohZJkIgo73pMuBRP0wQJuXPEhFWDCQ9)LQda3oMkBk60bn9QiDkwUfj5dJqIPiuBkguXQcDxvTE8fh85F(nCfqJ521uNRnmDDXwoMpwB1Uox)dlg2EbBhtcoXD9kfvNLlPoUmo9((JDvA)ZCVPkqvhTswdQLEqKtqL3Uq1ABCVoU19d89WYZZF1QO7QGxE5vW3yUS6i3QqXnpn3KxK1(QId0xNhjuzvUzYiXTVZ4jd1zDkOoO(yhb(R9ouPoK9eMytfDoDDSl5Z2PXu2NsWlx4syRMCZWUIVrzUZGuRfDu9jwnDQCZgyRAGSJd6OiNJhnC076TllAi5yRo5UPkQPO(MvtEISZ6WM7lQll2S2r)4E6XfJ3TgPSk4YtXADwliTTCm3KEvao0AQB3j9DlAuDgD1uzT4SMWHmA6XjNUkNSL5rtHXvLIdz2UxNS7QqZw2hlfOb1soKztpozTFjOTmoAYq9QZCiH1D42g3T40MmeL6GUtewO9Tx9gpH(63Hv99lm53dUbl0onUFcsWdzQqcdEK2JWF7aplzmAftDFn3JicZWoljmMdD)N99iAOzCNLigZtFWla78UNbJsPH3GrYC)AXnjUPE2x1V0Pq19vJNksqdM9SldGSZRj7zQQTUuWjtLY8aZ2m0lVYXFJ4jZSYzwTVgO1jQuk3J559Fm)hpaB17po]] )

spec:RegisterPack( "Demonology", 20261027.1212, [[Hekili:9QvBVTnos4FlblG3eSbo2PNZMTBsaUDtpCD3Rffq9q)MKOLOSjIKOajvZgGa9B)MHuuI6v74d3HI61MC4Z8md5mCg21FT)x99IjkQ)NVE113SE11)8Y1xV(AFp1lfuFVcs0tKDWxYjzWNpsZ458u(UxWPEjLtIraK8srem9ELQq((RUAhtTVC7YiE2v7PcYtSuwZx892wYsvFm3F7eAwwqJ8)8VaZsLr(E)EkrkzrvHFqqQcBzqv43iIuE0tave8ewkqGF4hgvIQWZ7IY6LR3CX7Rc94LPvH)lwoiYvvHFIivuHdemPcwBm(ZQWNOfWV4LQlGpTsHq6rIeSeweTkeTTy5YQ)azIN2TiFVMhrcscS8Vs(ovKR1234pVNsIRcB42Zw6(4x8Qc3vYapWLvHQ90XesYYaY9NcGK8eQy)(g71JLvMsuCr9IachttiLPkl1(9sHKEjA6juKufOweu5EoqFy8pMLXbeqrEuqy5wxf9VOrLUdJaCjsQ8y4)835FOke(kQpTplApx7xic4duETT0STiPkflFNLvpY)QSwwbLuuKYOau8CebyHWgAcjfybpjbS8CEvybOmAM2TWYJ5pJsR3JVyzviq69e9G)gpf89mzT(HdlPuXVw)RAQIZ2SfB4Z5hX5dW3wMNsLYXpqO1jjLMRqt5ziWar35Ghy6v)bjsX45YLfcke0SLO(P7VstRaIiJlUKLC)2YKKL6FTuqZaFV8UBwn3kLpXYFJlmc8UbMjcsbB7smQ)(cQACXtH9(afPa1sgjNSSisDxZwQD2aCQayQfWP9u1EuQhgkLzsuohhcOKeAAqmpJLtWrqvb8jiNsJPXluSm6dRCf)WMWKcbHi0Cj770dlkHtrMGJ)DAanhocsLpCFJvbZdgLyhvjDbtQpogSfon2SZupMsqGJ5lllwmYO29T3DyMfHb2D0jRyVwIenLJPg8BhDjOO8fg2UeDObkEqmJ(W6UowUquwy3dQHPDWjr5wxqy20kaenol7GlQb1(7JKyhJt1v(sjnGPOzsu6HhGIX8AbWnAPDiz7Wb15aTmR9u9DxV5WBqc6oA(qfA3FoBNGdhcGdSl)oNf)mj9jQapw4OMBxTWgU5CMdtb3eRDyheNJlt7JF9THgSsmeT5Uw4(nzzMohkpp9ft(tihnK9xNPaYJIxxcx)H5o)h0umrVnG(cZ9B5JN98QEzkBYcrX8pgTgWYk6Lwa)km6IZXT37x9Q2K7MibCPxmbET(9rGTDYteDzzuu52s5iyBN6ergeCFjCpZy0UzU3k2XMDLaPDtPBur)zxCM5YUL6iLuCxJMt2MAOXsskKVSodNDjX6ZGdSj76RnMolTbBZkBxBtkCnZjW9jrCMoq2j8PxmT(giZ0tauNa0JeOwOG7caq2ttttyIUUp8Ac7e20jXqMcmR1DRx5EH5Mv9ruRtEsWOO6oPnyvxZ37XGuiYQaJfBkLu)RAcG1n9VvqL6kiuwFDsBnzjyjIyHmqwaHcJ13st4IMYZO)vbOqNav96bYsYGI5sEjq)BKT6Veq2XZFXM33meqA9Oht2)g4BwAmNN1cp(RbOJdoj43SzgW18cr)Ch2)QJQgc4D3FZMlMZaFtSBwt3KMV14n)EGcmd3usXC2lSNgqtPzq8SSfx7idq2v8JcFOuYNWkNZH)2IV7Od0H7KhLoEMsEQl(2rgGTDIJcxfpFxj1b26bg6vmJ7wdNjC8tWLRq04Jebea(fqr2on)riEdV59I2ORM20(vtRwWN67mBUPfLVUZlfh6lk12kuD(iyumaVWj0uxicMEdiqa0NV6ilJFic)pRpG(ksx7X4APx9k(EqB2syXdEDbiNxoUcFpFpSQmj(agAfaF5Z63dP(gl)FZ3ZWa8HkQDs(EW1wW9OmIVNLfvH350k7a71xbKycCTcFcWwfUWU9AK(HXKU1DI04DtqdTJ9WCOJt2h)Jx97kmNVRBrgUAPTifTXGP60MXQ5Cz9lR2SngyEGkaX5SZzxBZD(ic)TEi0sAC5Tn9b89EhpKtJFhPwHvG6BZK7mnfV7sIX7YbDIt3(OEV8DOYU5uCp6mA4Q)5POABpLUuDIoon74dUJtV)VwFa42PyzttNJOMEDKoNwUfvYVmHsSnH6QIbDSQrFSUwpSXbF(F)gUgOPc7A6Z1fMUHyRNkgRTB3rT)Hnd7AWU5KGtCxVrRQtkK0KxgxE)4XUmT)zUZQc19rRP1GEPhK5ey5TR0J2M3RtyD)eFFE9PfV600Dv4RV(g03uHSMm36uXnpn3SxK1(QId4xNhju7vUz2mXTVZ4rd1jDkOoP(uhb()7DOktk7zCX2o6gn0XTLp3GgBBFAcVE1yeBZSBgUD8nPM7iK2wmz1NXA605MlWo9a5MhCKMCoC2WjVR3TTOHkhhDuD30f1CQ(MnZEISJD4Q7ZRBl2A7yCCp(mMgV7EuLvHxCmERtYGm(YPct61b4qVPS(FSKruF3Mg1Nr3mxvlJ2t4qnANzuDow7KTAEYsygRtXHA2D2r1(ynA2Q9PkbAqVKd1SDMr1A)wqB14Kfd1RpZHkSEIX9XDBoTPcrLjP7mPfAF7v)PlOV(Dy1F)CB99qyWktqZ4pbjeHmxkHbps7b0FRGNenMSJPUVM7biHvStIctfq3)zFpahAK7KiXur6dEb4rV7zGuAoCM9FA0HVwCtHB6N9v)ltjuDF145Ye0Gzp)Yai78AY(2UARBfC2sPSpWSRg6vx50Vr8SvwnAvTVfOnfQuQ2J159pT))EboQ))5]] )

spec:RegisterPack( "Destruction", 20261027.1212, [[Hekili:9QvBVnUns4FllkGVyClCSZUonDV4aCTPfx71UOOAp0VjjAjkBHijkqrLTbiq)2VzifPOKOKDmWDOO7AZxMNNziNx441FJ)x89IjcQ)NVz9n3Uz9nF7Qn3S5gFpXlLuFVss0tKdWhki5WF(iTsWRJePScCUxYyKyucvSAEem)rHOS6txF9HuXX69RIy5xFKYjpLMLA(GV3(60mXpx4VFcORkPr(F(7GzPvr(E)qgPQknQj8h5KMqlk0e(NeEgl6jGlCwsAgWGV5BCVKMWR6lNnR2SD5NAc9osIzFTj87zzcyrp6D9FuNw8EyIFt(PLnHKI4MWFkLtrHWksYih4aVBcVgwfLWtlo0e(7e5ArDlUAvZVGeXtAwQ(KKfrCscGWxipt5fY9(NSVEKsazBy2x1K9XF3Rj8qDkybaQiosDTOQ0CGr)BEALGLq5hpA0wV086mIGXB3eqSyAcPotOP2puZROGO)10eksQsefoT6idOpm(pNNZajGl5roOAsLjRjK(x0OA7Hrb8EKufXWF9pz)yR9kMMJM)OJS0iabcA9W1l1fZHsfviaZNMvpY(sv7A5uszzwkfefRaLaSXxActizalyjjGMxWAclbWO5sZsAH8GerfoHxcIS5xiYBbvRk5u4Y4EI4VV7AjZci8Cg)9Pj72xNKSs(TvCAoOtv3F7652z1tW9J32gJawhOMiidoUEp6oTRKkCV8mWMgiiLik5KcYQYiX9gtLE2aCQayQfWTOmXrCvpmEvQjX1zzqaqsOzbXS80ccoccfWNGcknMgVqKMtFyT9YpTkm5IGRE0IQ0NPNEPegfzco(Z0aAbC0sREyNrRG5bLIFGkQSfwL0joyp4dBozAhtWjW1Nv1LlCmQ(C7dNMzrOdtpmtlpkxrIKYXuL87gDfauXcfBxHg0ablioL(WM(gwgNxxQpdAft3GtkL7gBa2xZLcb(gpoiIvxiEy9IRA3C3TK73DZ6xZzpdM0L2sjv70JYqBY1dUOLA6VpR6jdXyhQmcqOoNw1fzX4PcHhZGRrwtisXydjPCW43ewxKrRQAJCOWdcLGXj2ZQHpkGWaaUR6BunyBzvnu3CU)6y(F)h7zyHOEbat6BtmJUOVP(8oMM)EQ96RRObPcAEfU6X(KXyi4aKm9yx3WbTHRxm(kWnBp9DEo9aTymG6R8V7aNb(vqmGvpZsJ)kj7jkh90SG5U1l0rWSCJXSfMWx9mqQ0PbLevm2olU1elUQ1WXy4KYlIVEkuwE6ZH3I46lnyNyWvvXhqoc4knCBxMaKvKbPTKxuzjOFagJhsEX4Wf4ebf(RFIMHP(0HIxQY4x0klm3MhjINMitKETot8VMw80kR8humZHc1G08Ybb0XpcJcbdGBr7w)QuL7Ncao5woH86oEDi2UjVqPxvhfvVVUYHS1tDHsgw4rWZ0jTnZ9wLDS6ujOsFO035B4SlENGKrleQGgz4PgTGSptrJvKmitxBUj9wIL3bhPt693Qm92Qr2QD2TxtYxjZjqLarSuz8clV0bHoK1oOMEcb1loWzkOorbzXbHCKMLnkYkMGxpHoQvmeqcdoE)M12L6SD9qjkXKLmoEnkv7j1oRYQG)e6KcEwLOVOP4A53Ajqtyt4)raVDraUYYcb6QsnblAgRsfIcWfOV(EAcJBkyL(xLaGwoQY9dKLKdL3M8sG87iBLFiGCGv8IoxRAiG0YrpNckmI3S1yglVt843gjDCWjf(TBNr4sEHs)kl2)QfuoYVU72TlNtbFtSBwvxfMVt5vFFeaQHnffmN(cNPb0mAo4px1jx9iJKS9Ypl5dpc4jSANc4)7KV9OJWWEYZcJVsjp1x(6rgjB9eNLCfSId1ulX2oWyRIAC7QVvUJ)gKCf8gFKWFcFqDeMNugp9Vb(ByM3LDExMhU(pup(e(tzottMwC9TVfvWGseZ0poSnEKSUr4bswUMY6DWWBabGknIKfhCgpaBSe(F2l4gcKS2d3OmOEfFVNP8kyZJ63ceZRa3HVNVhw8xf2shjaWh(SSfrTzS8)EFpfdWw30AK89G0wqE0uIVNMfnH3B94(r6RVaiXeYvV4lqSnHl0hVQv)GRv3zorA8HjOH0WEAo0Zi7J)NxBNwMZ21VidBu6ksrQmyOoPASEot2WQ3vhJbQE2bsCo9C29AY5Js4JdKqhPXT39CDGV7SSqwpz)mrf2bI32jpzmfVBtc3pMcnIt)WF5z5hqWU9smpYiA4U)2POAx3aSP6e9kqDIpkhN88FJ8cWDtXst7cCaZGEjmhk3HG8DZA3XEmydI1dGvxuLY)kde2UJ3d3lUbwWRVcHNLTFOjCjcjODUXu)I9EioSZeseD1DItBq3mLhQvdeCysh2ib19iLI5cpy2pkHBkpytdfCQOMzLkKBl(CNOBMoi357kjf0WyaAbzAuHTy6h8AZu(ZDTRWPYpUBg26BVRxWTRTsOUiVzvgpC7t5o39OgBM(UMqzJqK0AuZqgLtcy5DQJSUmk9cyomLYN3mLBVDtrCFXXAbA)YXn7O1H8myJ2DD(qetDF6IGuM3BQWdQK0YSUM(NpBnlDT(Fe)61jF5X0TZM0T7hd4Sf1fLdUn)9uEE))TCjHk78mMy9J3DEF0(192EX6x4lj8M1Ui22zpmSFC)Ki3BrsDrLaFgTP3J0TfS1ZDTt)449SNoj0KL1z)c4XGJJ6eBZdMNd6B3o7nYE6Hn2x12beTUJ(Xd4JZmG7qiH4hNJ16IuiLTCk3Kbp2FS1SQ93b2b897pG8o625kq15Z)hJOEgNy6QZbDipz(nxnfymY2Z6eDx9uOd9PspoQTbJrwpJtuh2THoeNSU3bTuymGTt42g3VpeMhdiubDNjSqxB29N(TBTTC3upSSAODY61qNg3DBUnd7K1joSF8Na)UfEr0yY6g734(tqc9YUikmLd9Wo8Fcoyw3frIjlDDyZ(DM7z0QKC4DyKm3)WaMkjLD4x(nvju9)bcMlsGrMdSlJezVF4aFDdmAF1)SLsP)TeSryqHUt)ZbmBLvolZ(TiAvHk1IJyDE)l9)WJWr9)Vp]] )

spec:RegisterPackSelector( "affliction", "Affliction", "|T136145:0|t Affliction",
    "If you have spent more points in |T136145:0|t Affliction than in any other tree, this priority will be automatically selected for you.",
    function( tab1, tab2, tab3 )
        return tab1 > max( tab2, tab3 )
    end )

spec:RegisterPackSelector( "demonology", "Demonology", "|T136172:0|t Demonology",
    "If you have spent more points in |T136172:0|t Demonology than in any other tree, this priority will be automatically selected for you.",
    function( tab1, tab2, tab3 )
        return tab2 > max( tab1, tab3 )
    end )

spec:RegisterPackSelector( "destruction", "Destruction", "|T136186:0|t Destruction",
    "If you have spent more points in |T136186:0|t Destruction than in any other tree, this priority will be automatically selected for you.",
    function( tab1, tab2, tab3 )
        return tab3 > max( tab1, tab2 )
    end )
