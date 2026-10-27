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


spec:RegisterPack( "Affliction", 20261027.1552, [[Hekili:9QvBVTTnq4FlbdWlglWXoDonTloaDTDyTRlOaUd7BsIwIYMWsIcIujnab63(UJuuI6v74HnuuxB(YZZdpY74De1zHZ3CwhqKuN7VA(vxVy(vVE2ILlVYzT8PuQZ6uI)EYw4ljKy4Z3fggX8LmEc21trCsacGGNN5dDVtktfV9Yl3YK7Y3mZNhF5oAgzplIv9fN1BYzrYpL4SzaMfPuFN7Fd0lv47S(9reHG5x49XmsHxTck8(Bswe3FpiLmEilceWp8d9oIcVZBIYcGQPfFgh(AL2fVvny)msOSW7BKhOzW0VeAK)4okjOWRcGhny(HVUUWBBodK5ffEYD0(gKGfdS)hzmHKhsZ2TRsuRzX5rejpRCstl8cOHK8iPyMwAVpptqbO)clKIIkfzjJk2XJcqk)uCmhqahYhYiSe1IjQWJ(DQFUDZiaxGIkja(N3X)yHh8vKVy0k5VJZ8bgizWh44vRLkBNGkLSKTgv9b(3eLJnJsstJyuakEcIamXNk8cjrGk4HHWkpHx4LcKrJvMfwsa)rC0QnIPaKfFMO2SeZsZOWjMne5pT6sLYCjzX8SlyHR2Khgot9Rzz0yynjU965JntXEwYlCI(GQD1D4gbBxxGh5xLsL9p8iWM6kjPilXKeYSuF5TvMktVUyxUqxtGtrrYD4OUR7O0DIJZYGaKesJCd4XSec2csfOh3eknGgmrYIP3n3E4hEjm4GGJE0eb7b6HhkHtrLGT)a1LMaBTuXDRQwvq)WIkBlvkSbtSJa79UB4rYQDMY2Kze44ZS80j90QzF7vhwz(OdtdozP7uJiuj5aQg)6wNbeLmrR2zOb1vYDdy07w00WYZYYtn7bLWu34GOCJnimJ7karLXY04Ksqn)(if2XyuThFUG6YK0ybo6UhGcW4fUq48OgISUz3YylgLvFQ(2RwE4nOm6wAsxcn7pNTnJdhcGdSZEGZcEKeTNMHhlSO5M5tmUBwN5WqBv(Ah2aX540u24NFzObZeDrvbcXinW9gI8yvyuEsee8JNlXyFquvvKcieipdcxgkPW)8B0imaQXHEQ(EJKsSWiKRj(zSqv44lnXZ)clz)mROqum(JMvxwCARWc4xHwNCoU9UA(ZQLCZajGjD6a4vB37b26opr0f5((5BYf9GTPRtezyG7YtK9k7Q(EPyhO3vCfMnLMEfT7DYzssenrot5PeH7A0eYMiTmMrIG4LLr4mtjqDgSZAYm)YftJPwHTEM1ZTkeUs5e4(eFot5iB5(0YNwDdKU7baQHd6rcunuWDbai7OrrHSSMMp8ActhMWjbqKcmQ1TlMBFH5Y5TruXjp0TxuT704SQYL6TOtk4zLI(IvPOP(vPak8k8(ljKMQeCLvxNuNRtiM6fMRdefitI(6BOH8SQ0EOFpfi0YrvnFqSKyijPWNCv)gvR6lUKT8KNmX91nbIw16Xe9Vc(QPgW5X1WJ)Qd6yJdc(1lhbCLUq0p3s9pBrvxaVD11lNo2c8fPUrx66W81lE9V7qGU5QukgB9c7PU0iAm4plQX10shKTh(rHpKk5(iQqKa)TgF7w7WHDNhfhpsj7BIVPLoyB64OWvYt2MtTGTSHUwfD725WPDh)t4YvWB8dKmWb8RarW9KQ4P)i4VH38oT27QQ8NFrxcd8P6oZQBAXXxwrJKd1BezkXOmEe0k6GNA5AQsebdVbcWfkYvEKPX3fH)ZQdOnrQCp6NLw5R4SgkFvatUtP1qmVeCgoRDwJzLjWQ3veaF5E1JbuEJLZV6SwRaSk9sJKZA4Al4EugXzTrffE3AvIyN1RJeeXa4Ag8jaBH3eZ2RE0313ORnNOmE1aYqzypSgAyKDW)SUSE9XSDntYWML6KuulgmuNAzmFmtw70Q1BJU6xNbqCS15OZT6oFeHFUfc1IgNEDrFGExzzHSk87izfMbY3Yb3zQsE3we9xLdAehU8r1E5RqYU(umpQiA4SF9qsTUMsBPoqfN6D8o3XP2)xOoaCZqQSQOZEOPvfPJXYnijVzasmfHAtrNkwvO3xvRhEXbF(VFdxb0qUDv15AdttxSfd5JvxTBVR)UfdBVGTJjbN4UAPIQtYLuhxgNEB)XMkT9zUZk8u1rRKvNAP7e5eu5nZvTwh3RHBD7aF3V408xTk6UW75NFb8nKlRoYTkuC1tZn6fz1VQyh914rcvwLRhnsC97mE0qDsNckdQp0rG)FVdvQdzpIj2urxVUo2L8z70yk7tj4fZ7tylhDZWUIVbzUXGuRfDu9rwnnQCZgyRAGSJd2trohoA4G31BxwuxYXw7L7QQOgJ6Rxo6jYgRdBUpVSSyZAh9JBPN(y82viLfEtpgR1jTG02YHCtAvbyxRPU9EPVzrJQZOlhlRLERjSlJME6LZ(kNSM5btHPVkf7YSDV9YEFfAwZ(qPa1PwYUmB6PxwBxcAnJdMmuR6m7syzh9BJBwCAvgIsDq3rclu)2RodNqF57WQ((5M87b3G5ANM(FcsWdzSqcDEK2dWF9apjzmyftnFn3dicZWojjmKdD7N99aAOACNKigYtVZla37DpDgLsdNHrY6)1IRsCt9SVQFPtHQ5RgpwKGkmBzx6azJxt2XuvBzPGJMkL5bMTzOvELd)gXJMzvVz1(sGwNOsUChMN3VB(pEa2QZ)8d]] )

spec:RegisterPack( "Demonology", 20261027.1552, [[Hekili:9Qv4UnUns4NLffWxcUah7SNtt3MeGRn9W12RlkG3d9FsIwIYMisIcKuBAac0Z(ndPOeLeLSJpChwSU2Kd)MVziNHZWTbRd(sW2eIIg85BwDZTRxDZ3UC9Mn3eSv9AjnyBjj(zYE4lfKC4ZNO58cEgF)R4uVMXjjiasELigM(Gsvk)01xVNPouTBzmp)6dub5zwgR9lbB3vXYu)CrWUj0SSKgh85VdMLkJd2(JzePKfxh9tcsDuhdQJ(dIiJh)mqfbpLLbe4B(gVsuhDrFuwdQ6YpvhTLxLvh9VyfGixxh9BePIkCGGjvWAtWFwh9mTe(fVsDj8PvkeYTKyblLftRJqBlrUS(xqMSv7wKFsZJybjfw(xiFLkk0A7p4VCGssQJA52lw6(0VVToAFfd8axvhPoq9jKKLdK7xfaj5PuXHdT27wwEvgrXfnlciCcnLuLPSu7hRes6vOPNsrsvIArqLh4a9HX)58CoGakYtccRW6QO)jnUYDyeGRqsvKa)N)o)NQJGVI6t7ZIpW1(fIa(aLxBlTBlsQsXk2Bz1t8ViBKvqjLLzmkafVarawiSHMsYawWttblVGxhvckJMRDlSIe(lO0694lxwhbK(arp4pWZaFpt2OF4Wsgv89n)QHQ4STBXg(CXjC(a8TvfzuP0)bcTojz0cfAkVabgi6oh8atV(xiXkgVqUSuqHGMDe1F9HR10kKiY5IRyPpSRknDP(xlf0CW3lV)2vZTs5ZSI35cJbVBOzIWmW2UcJ6FOKQ8lEgS3hQiLOwYjfKLLXQ7B3sTZgItfctTaoTNPoGs94yPmtIY54qaLKsZct45SccocQkGpHfuAcnzHILtFCLR4h3eMuiieHwizFLECrjCkYeC8VsdPfWrqQ8XhATkyEWOe7PkPlys9XXWDWPX2DMMXuccCmFzv5cpJA33(4Xzwmgy3tNSYdAjs1uoHAWVB0LGIkwyy7s0HgQ4Hjm6JR77y5crvPDpObMUbNeL7CbHztRaq06SSdUObu7VprIDkovx5RK0qMIMlrPhFakbZRfc3OL1JKDdh2Kd0YSUt13FZMJVbjO7PfJvOD)5d7fC4qaCGD5x5SKxizptf4Xch1C3Qf2WnNZCyk42yTJ7G4CCzAF8BVp0GvIHOT31c3VjRY15q5fzVAYFc5OHS)6mfqEu86s46pm35)GMHj6Tb0xAUFRWF2ZRhKPSnlefZ)y0AilVCqAb8RWOlUa3EFy1BAtUFIeWLE5e41539aB3KNj6YQ44QDvspyBN6mrge8qfCpJpA3o37f7eZUsO0UP0pQy4Sl(G5YUL6iLmCxJwq2LzOXssgKVSjdNDjj6ZGJSj76BmMElTfBZk7wBBkCnZjW9jXCMoq2j8zqmT(giZ0tauVa0teOoOG7caqoqZYszI(Up8Ac7e20jjqMcmR19Rx5EH5MvdruRtEAOxuDN0gSQR57tyqkezvIXITLsQ)vdbW6M(3kOsDfekRVoPRMSuSerSqgilGqHX67OPCrB5z0)SeuOtGQE9azj5qXCPVgQ)nYw9xcj75fVAZ7BgciTE0tj7Fl8TlnHZZ7Gh)1i0XbNe8B3md4AEHOFHd7FZrvJb8(hUDZLZzGVl2nRPBsZ3z8MFpsbMHBlPyo7f2tdPz0CiEw2HRDKri7k(jHpuk5ZyLZfWF7W3D0r6WDYtshVqjp3hF7iJW2oXjHRIxSVI6aBZaJ9kMXDRHZeo(BWLRq04tebea(7GISDA(xG4n8M3l7IUABt77nTAbFQVZS9Mwu(MoVuCOVOmBRqn5JGrXa8sNqtDHiy6nGaHqF(QtSm(Xi8)S(agQiDTh(1YG6vc2cTzlHfp61fGCEf4kc2gSfRktIpGHwbWx(S(9qAUXk4hc2Aya(qfnoPGTW1wW9OmsWwllQJU3Pv2r2BGciXe4Af(mGToAHD71i9J(KUZDI04JtqdTJ94CONtoa)Z2M3vyoFx)ImC1sxrkAJbt1PnJvZ5YgwwTzBm08avaIZzNZU2278re(BdqOJ04Y7A6d47doEiNg)orTcRa13Mj3zAlE3Le(7YbDIt3(OEV8JOYU9CCp6mA4Q)2POAxpLUuDIoon74JUJtV)VwFa4UPyzBtNEuZGosNtl3Hk57Mqj2MqDvXOow1O7RR1JBCWN)3VHRbAQWU2(CDHPFi26PIX6621R9pUzyxd2nNeCI7MnAvDwHKM8Y4Yhgp2NPdpZ9H6iDF0AAnQx6rzobwE3k9OD596fwpmX3NxFEXRonDxh92BVd9nviRjZTovC7tZn7fzDVQ4i(17rc1ELBNntC37mEYqDwNcAsQp1rG))EhQYKYEgxSTJoVHoUT85g0yB7tt41R8rSnZUz42X3KAUNqABXKvFgRPxNBUa70dKBEqpn5C8SHtExVBBrJvooQxD32f1CQ(2nZEISND4Q7lAAl2A7yC8a(4tJ3)aQY6OlpfV1zzqgF5uHjd6aCS3u28pwIh13VPr9z0nZv1I3EchRr7mE1PV2j708KLW4RtXXA2DwVA3xJMDAFQsGg1l5ynBNXRwh2cANgNSyOb9zowHnt43h3V502kevMKUZKwO7TxdMUG(M3Hv)9lS13dHbRmbn(FcsiczUucJEK2JO)obplAmzht9Fn3JqcRyNffMkGE4Z(Eeo0k3zrIPI0h9cWEV7zKuAo8b7)0OJFT42c30p7R(xMsO6)QXZLjOfZb(Lrq271KdSD120k4SLszFGzxnmOUYPFJ4zRSYBvTVhOnfQuPoG159pT))EboAW)j]] )

spec:RegisterPack( "Destruction", 20261027.1552, [[Hekili:9QvBVnUns4FllkGVyClCSZUonDV4aCTPfx71UOOAp0VjjAjkBHijkqrLTbiq)2VzifPOKOKDmWDOO7AZxMNNziNx441FJ)x89IjcQ)NVz9n3Uz9nF7QnB3EJVN4LsQVxjj6jYb4dfKC4pFKwj41rIuwbo3lzmsmkHkwnpcM)Oquw9PRV(qQ4y9(vrS8Rps5KNsZsnFW3BFDAM4Nl83pb0vL0i)p)DWS0QiFVFiJuvLg1e(JCstOffAc)tcpJf9eWfoljndyW38nUxst4v9LZgaSLFQj07ijM91MWVNLjGf9O31)rDAX7Hj(n5Nw2eskIBc)PuoffcRijJCGd8Uj8AyvucpT4qt4VtKRf1T4Qvn)csepPzP6tsweXjjacFH8mLxi37FY(6rkbKTHzFvt2h)DVMWd1PGfaOI4i11IQsZbg9V5PvcwcLF8OrB9sZRZicgVDtaXIPjK6mHMA)qnVIcI(xttOiPkru40QJmG(W4)CEodKaUKh5GQjvMSMq6FrJQThgfW7rsved)1)K9JT2RyAoA(JoYsJaeiO1dxVuxmhkvuHamFAw9i7lvTRLtjLLzPuquScucWgFPjmHKbSGLKaAEbRjSeaJMlnlPfYdsev4eEjiYMFHiVfuTQKtHlJ7jI)(URLmlGWZz83NMSBFDsYk53wXP5GovD)TRNBNvpb3pEBBmcyDGAIGm4469O70UsQW9YZaBAGGuIOKtkiRkJe3Bmv6zdWPcGPwa3IYehXv9W4vPMexNLbbajHMfeZYtli4iiuaFckO0yA8crAo9H12l)0QWKlcU6rlQsFME6LsyuKj44ptdOfWrlT6HDgTcMhuk(bQOYwyvsN4G9GpS5KPDmbNaxFwvxUWXO6ZTpCAMfHom9WmT8OCfjskhtvYVB0vaqfluSDfAqdeSG4u6dB6ByzCEDP(mOvmDdoPuUBSbyFnxke4B84GiwDH4H1lUQDZD3sUF3nRFnN9mysxAlLuTtpkdTjxp4IwQP)(SQNmeJDOYiaH6CAvxKfJNkeEmdUgznHifJnKKYbJFtyDrgTQQnYHcpiucgNypRg(Oacda4UQVr1GTLv1qDZ5(RJ5)9FSNHfI6famPVnXm6I(M6Z7yA(7P2RVUIgKkO5v4Qh7tgJHGdqY0JDDdh0gUEX4Ra3S903550d0IXaQVY)UdCg4xbXaw9mln(RKSNOC0tZcM7wVqhbZYngZwycF1ZaPsNgusuXy7S4wtS4QwdhJHtkVi(6Pqz5PphElIRV0GDIbxvfFa5iGR0WTDzcqwrgK2sErLLG(bymEi5fJdxGteu4V(jAgM6thkEPkJFrRSWCBEKiEAImr616mX)AAXtRSYFqXmhkudsZlheqh)imkemaUfTB9RsvUFka4KB5eYR741Hy7M8cLEvDuu9(6khYwp1fkzyHhbptN02m3Bv2XQtLGk9HsFNVHZU4DcsgTqOcAKHNA0cY(mfnwrYGmDT5M0BjwEhCKoP3FRY0BRgzR2z3EnjFLmNavceXsLXlS8she6qw7GA6jeuV4aNPG6efKfheYrAw2OiRycE9e6OwXqajm449BwBxQZ21dLOetwY441OuTNu7SkRc(tOtk4zvI(IMIRLFRLanHnH)hb82fb4klleORk1eSOzSkvikaxG(67PjmUPGv6FvcaA5Ok3pqwsouEBYlbYVJSv(HaYbwXl6CTQHaslh9CkOWiEZwJzS8oXJFBK0XbNu43UDgHl5fk9RSy)Rwq5i)6UB3UCof8nXUzvDvy(oLx99raOg2uuWC6lCMgqZO5G)CvNC1JmsY2l)SKp8iGNWQDkG)Vt(2Jocd7jplm(kL8uF5RhzKS1tCwYvWkoutTeB7aJTkQXTR(w5o(BqYvWB8rc)j8b1ryEsz80)g4VHzEx25DzE46)q94t4pL5mnzAX13(wubdkrmt)4W24rY6gHhiz5AkR3bdVbeaQ0iswCWz8aSXs4)zVGBiqYApCJYG6v89EMYRGnpQFlqmVcCh(E(EyXFvylDKaaF4ZYwe1MXY)799umaBDtRrY3dsBb5rtj(EAw0eEV1J7hPV(cGetix9IVaX2eUqF8Qw9dUwDN5ePXhMGgsd7P5qpJSp(FETDAzoBx)ImSrPRifPYGH6KQX65mzdRExDmgO6zhiX50Zz3RjNpkHpoqcDKg3E3Z1b(UZYcz9K9ZevyhiEBN8KXu8UnjC)yk0io9d)LNLFab72lX8iJOH7(BNIQDDdWMQt0Ra1j(OCCYZ)nYla3nflnTlWbmd6LWCOChcY3nRDh7XGniwpawDrvk)Rmqy7oEpCV4gybV(keEw2(HMWLiKG25gt9l27H4Wotir0v3joTbDZuEOwnqWHjDyJeu3JukMl8Gz)OeUP8GnnuWPIAMvQqUT4ZDIUz6GCNVRKuqdJbOfKPrf2IPFWRnt5p31UcNk)4UzyRV9UEb3U2kH6I8Mvz8WTpL7C3JASz67AcLncrsRrndzuojGL3PoY6YO0lG5WukFEZuU92nfX9fhRfO9lh3SJwhYZGnA315drm19PlcszEVPcpOsslZ6A6F(S1S016)r8RxN8Lht3oBs3UFmGZwuxuo4283t559)3YLeQSZZyI1pE359r7x3B7fRFHVKWBw7IyBN9WW(X9tICVfj1fvc8z0MEps3wWwp31o9JJ3ZE6KqtwwN9lGhdooQtSnpyEoOVD7S3i7Ph2yFvBhq06o6hpGpoZaUdHeIFCowRlsHu2YPCtg8y)XwZQ2FhyhW3V)aY7OBNRavNp)FmI6zCIPRoh0H8K53C1uGXiBpRt0D1tHo0Nk94O2gmgz9morDy3g6qCY6Eh0sHXa2oHBBC)(qyEmGqf0DMWcDTz3F63U12YDt9WYQH2jRxdDAC3T52mStwN4W(XFc87w4frJjRBSFJ7pbj0l7IOWuo0d7W)j4GzDxejMS01Hn73zUNrRsYH3HrYC)ddyQKu2HF53uLq1)hiyUibgzoWUmsK9(Hd81nWO9v)ZwkL(3sWgHbf6o9phWSvw5Sm73IOvfQuloI159V0)dpch1))(d]] )

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
