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


spec:RegisterPack( "Affliction", 20261026.2307, [[Hekili:9Q1FVTTnq0plfdWlgRZXoDolTloaDTDyTBRyaQd7)KeTeLnHLefKOsAac0N9DhPOeLeLSJh2qrsS5pEVJh594De1DL7xCDcjcQ7NVA5vxVc(zXvVA5p66iEmJ66Krcoq2bFiLKa)(TrrXSabJNID9ymNeIauWlZdGU3lezfV5Yl3Xe7l3UiGNC5VspWIzxUx9hxNTLSyXhtD3ocTfz0a3p)AOxArGRZ7IjffSGk)pKtQ8BPVY)Vj5X8GdGDKZJyXa7FZ3yDev(x0fLvlwTEE1NWH7in8I3ihCqojsu5)fY90Cy6xcnYFypLew53aWdAmF)F6u5VRKbM5lR8f7P2gublby)3YzfcEenF)(gJYHLugte886jnVYpKgrkJffluM27kZlOa0)olIIgvgYsoTyppoeP8JjjCabCiVpNWsLlM4kF6xPbLMnJa8s0OsdH)8w(hQ8HpI8LGEPG9CwaWajh(foE5APX3vqfcw6oTv9E(xkQhBoLKLfZOau8uebyIpw5hrIbRGhfbR8uELFgqgnr6wyPH8hWrl3iMdqw9jICZQyrwofoUSLi(UnxkTmpsEcp)LSOnBlJIwi)2ICAcSMkU96LtnZIdS0N5edaR2t1HxmSD9s88(MmQW(WJbFQNGKHSKqsjlYce324Q096HD5bDndoffl2JJ6UHJs1joodhcqsen2lKNWsjylivG94LsPH0Wzcwc9ULMd)4lHrheC0JMwWUNE8Hs4u0sW2VN6rtHTwAXDBAwvq)WIkFhvuycwXEcS37TLhlA2zQBtKtGJplkZMzPv9(2RoULfGbmD4KLTxoIiPjhsv4326cGO0zkRDb6q9eCVqg9UvDDS888Ym9EqnmTnokk3yccthUcq04S0noRgu93prd7uCQMJVSG6Xe0KcC0dpafI6fEGwEChJSTzVATfTL1EQ(2RwF8nOC6oA6qc17pVyxohoeahyxCpNf(aj(anhpwyqZnlNPd3moZHsBnXAh3bX540K(4NEEObZedrLcHOsdCVrrzIugLNgdIF8sbQ9bQQsLcqcKNdYLrck8NFHgJcO6a65Q7nsRXcviDib5SiPC8LA98FNLEyHHkef1FuS6XsY6jlGFeAD2f427MLpjxYDfsax68rWR1VBb22opt0lkdck3wwybBDxNjYWa3xMkSA2n99CXouTR4vO3u6gv0V3zVqqIPPIfYiLyCxJMs2gRmJfKyqVSwHtpLq5zWbRj98RxmDMAd2Qz2o3gjCPLtG7tc4mzGSr4tVyA5nqQUhbOobONiqTqb3faGSNghhXY76(WRj0DOLtcbLcu162vlnVWC9Y(ik5Kh5zfvZo1bRYCPEdgKcrwzySytkAYVvBav(v()LaYtvaHYYRtAZ1jct9cZ1bubYfyS(wAepVjTh6xZacncuLZhmwscKKu0JEYVJwR8dEKD80h16(QMaJw26PO(3aFZud58Kw4XVnaDSXrb)61taU0Uq0VWW6FYGQHaE7MRxpFQf4ZY6MCPRK5Bx8QVpGavZnPum16f2t9OX0eiEUOfxDldq2C4Ne(qQKhIPffPWpT4B26aom78K44bk5qx81TmaBDhNeUcE6UsQbS1nm0ROA3mhov44FaxUcrJVNKdbG)jqeCpPup9BH4n8M35TrxnL)8tQsyGFlVZS5MwC81v0i4q9gX6smQ1JGwXa8mJqtzIiO8gyaEqfUItmn(Hi8FwDa9jsM7HDw6LVIRdu(Abm5bLwdAEP4mCDCDWSYkWs3LeaF4ZYxcO(gl3F21rzbyv61ojxh4Al4EugX1rBfv(3AuI4G1RRamIrWvp4Za2k)z6Tx1OVZ2OBDNOz8QrmdPJ942qhNSl(pN661NY31njdtwAtsrUyqPo5Yy5uUS(PvR2g9upndG4uRZjNBZD(ic)qpeAnAC6Tf9b27gdpKrHFNiRWmq(wp6ottY7MgH9QCqN44Lpk3lFfs21NJ7rQOHZ(hhZuBRP00uhPIt1o(G74K7)RKhaUzmRSPOtl00RI0Py5gKKxpcj6IqnPyqfRs0Tv16XxCWV)3VHlbASWUM6CnHPBi2QXIXAR2166FyXWMlytnj4e3vRLuDwHKkDzC69Jh7AP9pZ9IkFzD0sZAqT0duobR8MLYwB196ew3x47ZRoV4vJIUR8F6PNbFJfYQuULsXnpn3KxK1(QIdSVopsO0RC9KkXTVZ4jd1zDkOwuFSJa))EhQqjzpHlwxrN1qhZs(mdA0L9jn4vlTzyRNCZWSIVrzUZGKRfLQ(eRMovUzcSrnqM6GwkY54QHJExVzzrdjhB1k3nvrnf1xVEYtKDwhMCFrDzX61ogh3ZESX4TBqkR8NFkERZAbP8LJfM0RcWHEtv7wPVBrJYZORNkRfR1eoKrDpw50w5KTmpAkm2QuCiZM9ALDBfA2Y(yPanOwYHmR7XkR9lbTLXrtgQxDMdjSUd7(4UfN2KHOqj6oHSq7BV6oEc91VdR8ZxOZVhcdwQcAS)eKqeYuscdEK2JWF7aplZy0kM6(AUhXi0d7SmHXcO7)SVhXgAg3zzeJfPp4fGTE3ZGrjTHxGkz2FT4Me3Kp7R8BQuO6(QXtPe0Gzp)Yai78AYU6QARlfCYuP0pWSjd9YRC83iEYmRSMv7ZbAvIkLI9yEEQ)Fh890CISD3)5p]] )

spec:RegisterPack( "Demonology", 20261026.2307, [[Hekili:9QvBVrkos4FlJwP(s0LRt3jBNjt2KiD7M90TZE7OvI50(na3GPBuamY2mzJue)2VQSXGbm0D6t3PrHa(LN6Pk7QCvoJ)A)V67ftKu)VC1QRUzn8ZYRUE1h99KVws99kjrpt2bVuqYHNprZzfSm2UxXUEnJrIraeSkEe09EPSuC3LxUlvUVA7Yiw(L)t6ZPzPxUx)lFVTvPzYFPWF7eIvusJ8)YNGEPIiFVFkJiePr1H)mNuh2j(6W)GWZyrpd8GZssZaP)DFNZruhEwFuwVC9MZVRo0JvLvh(VslGHCzD4Vresk3cIuHeMBm(zD4Z0s4lwL8C4PzuiKEKiEAsAeToe1TyXY6pJmXtzte3P4reNKat)RKVr5fkP9hSx2tjX1HTC7fdDF639Qd3vLcwGlQdL7PUgKinhi3VYbsYsO897B1xV08QmIKXBMeq4yAcPktAO2pvXf0lqvpHIKQeLcNk2Za6dT)l55mabCipXjPfgtf9pPrv2nJaCbsQIy4x)D2pxhcVIYtzZI2Zu2fchEGJxPlTllcQuMwSZWQNyFv0mwoLuwMLsbOyficWeHf0esgWcwscO5fS6Wsqy0CLzjTiM9coA1A85lRdbsVNOA8hzzGTpv0iFyZsgL)dnF1qvS32LynFo7i2Fa22QImQq4EdHsMKmAHevLxaVceDRnEGQx)zsKmLviwwYPGhZwI8V(WLkAfq45m(fPjpSTkjzP6RLCAoy7f3FZQ5MP450I35eJaRBGUJGmq3UaD5FOKkDp8myTpqskrPKtkillJK33UKA6na7ka6AbSBptUhh1JJhLUtCCwgeqij0SGywEAbbBbffWNGcknMgVqMMtFCL9WpSkm5GaxeAHi9B0dpucJImbB)B0aAbSfKkE8HwTc6huk(oQuydMqTDmylSBSDLPPnjNaBZxwvUWrRM1TRpmZIqh7EYmTCVAejkkht14316sqqfl0SDjAqdKSG4u6JR7ByzCEvPznObMUgNeLBTbj1ewbGO1yzACrdOMVpsIDmgv7XxjObPsAUah94nqXyCTa44SSEKSR5GMyGgM1TR((R2C4fioDhTySanRpFyhNbBcGnSl)gln(fs2ZuoUTWsm3UAHXDZAphgcU1x7WgigdNMYg)27dnyMOlA7zTW5BIQCvmuwr2R64NqmAi6VksbehfpUeo(dJD(pOzyGEJd956Z3kCh98YbrkBJcrX4pAPgKMxoiSa(k06IZWL3hw9MsL7hibmPNpbED2DhW215jIUOkkQABLWb2MUorKHbUVcoNXfTB779IDSEvjqywu67vmS3fFqFy3sLNsgUQrliBZ00yjjdIx2eHZmLy1EWr6Kz(nktVP2ITEMDZTneUI5e48KiwQYr2Y9zGpT6eiD3tauph0JeOoOGZcaq2tZYss59nF4XeMomHtIHifyuR7xVY(aZnRgIOsMSKaNOA3PXzvLZ3DOtk4zvI(ITPsQ(QHayEt)BjKQUeCLvhN0LtwcMIiMidefGlrF9T0egVn9m6Fwcc0YrvnFGSKCizUKxduFJSv9sazhR4vtCFDtaPvTEmr)BHVDQXmwEh84xJqhBCsWVzZmGR4fI(zwS)nlrngW7F4MnNpNc(Uy3SQUomFNYR)EKa0n3MsXC6lSMgqZO5G)SOdxtlJq2E4hf(qQKpJzoxa)0HVDRJKHDNhLmEHsEUp(MwgHTPJJcxjRyxf1c2MggBv0TBNdN2D83GdxbVXNiCWb83bbzQ08Va(B4jVN35D1wM2pOl1cEQoZS9KwC8nvEjzqDrzMsHAIhbTIo4LwUMQerWWBabcGI8LhzA8Jr4)z1bmuqQCpClLb5R47bLzlGjp62fGyEf4m8989WSYe4TxOea8YxuxgsZjw()OVNMb4fv0yK89GJTGZrtj(EgwuhEVvPSJ0xFjqIjW1m4ta26WfMLx9OF01O7mNinUEcAOmShMd9mY(4)8AUxH5SD9tYWwkDjPOugmuNsnwnNjByA16LXa9TtbioNEo7CBpZhr47hGqhPXP3v0hW3hSSqwf(DKsfMbkVntUY0M8UnjCxLdAeNU8r1A51OWU5umpQiA4S)4uuTRMsBQorfN6v8rNXPw)xR2aC7uSSTOthIzqfPZjLBrH8PjeIPiuBrmQIvf6UQA9Wkh88)(fCfqt521wNRnm9DXwpLpwx1Uo1)XfdBRW2XKGDCxTrjQtYLuhxgN(q)X(mD4EUpuhQQJwrRr1spkYjWYBxPATlUxp36Hb((Y6tZF1QO76W3E7DiVPCz1rUvHIBVAUzpiR7wfhXVExsOYQCZSrI7UNXJgQtAxqtq9P2c8)3ZqL6q2ZyInv0501XUKpBNgtzFkcVELlITz2fd7k(MuY9gKsx0r1NrB6v5MnWw1azhh0rrohoA4KN1Bxw0yHJT6u2TvrnNOVzZS7i7Ph2Y(SMYIn6o6hpGpUK49pGISo88JXADskK2woLBYGkahBnfn)XsCi((fnQ2JUzUSwCwt4yjA6XPmDvozNKNmfgxvkowY296u6Uk0St6tLc0OAjhlztpoL6Wsq7K4KjdnOoZXcSPd324(fN2MHOuh0DMWcD39Q)0j03CpSQ3pZKFp4gSs704(kibpK5cjm6sApG87g4jrJjRyQ)T5Easyg2jrHPCOhETVhGdTJ7KiXuE6JUbyNN9mAuko8bZFA0X3wCBIBQR9v9LofQ(3A8CrcAXCGDzeK9UnzFtvTnLcoBQuMly2wcdYRC67iE2mRCMv77bADIkvY9yEE6)Rx83OCIQD))d]] )

spec:RegisterPack( "Destruction", 20261026.2307, [[Hekili:9QvBVnUns4FllkGVyC75yNDD629IdW1MwCTx7IIt7H(njrlrzlejrbkQKgGa9B)MHuKIsIs2Xa3HIDxB(Y88md58chx)n(F13lMiO(F5M13C7g4pRU5dR)wFpXlLuFVss0JKdWhki5WF)aTsWRJePScCUxYyKyucvSAEem)rHOS6ZxF9HuXX69RIy5x)pPpMMLE9r1)47TVont8Zf(7Na3QsAK)x(oywAvKV3pKrQQsJAc)roPj0c)MW)GWZyrpceHZssZa4)MVX9sAcVQVC2SAZ2LFUj07ijM9Ct43ZYeWIEW76)DDAX7Hj(n5Nw2eskIBc)PuoffcRijJCGd8Uj8AyvucpT4qt4VtKRf1T4Qvn)csepPnP6ZsweXjjacFL8eLxi37FWE(iLaY2WSN1K9HF3Rj8qDkybaQiosDTOQ0CGr)lEALGLq5hpA0wV086mIGXB3eqSyAcPotOP2puZROGO)10eksQsefoT6idOpm(pNNZajGl5boOAsLjRjK(N0OA7Hrb8EKufXW)8py)yR9kMMJM)OJS0iabcA9W1l1fZHsfviaZNMvpW(Av7A5uszzwkfefRaLaSXxActizalyjjGMxWAclbWO5sZsAH8GerfoHxcIS5xiYBbvRk5u4M4EI4VU7AjZci8Cg)9Pj72xNKSs(TvCAoOtv3D7652z1JW9J32gJawhOMiidoUEp6lTRKkCV8mWMgiiLik5KcYQYiXDgtLE2aCQayQfWTOmXrCv3pEvQjX1zzqaqsOzbXS80ccoccfWNGcknMgVqKMtVFT9YpTkm5IGRE0IQ0NONEPegfzco(t0aAbC0sRUFNrRG5bLIFGkQSfwL0joyp4dBozAhtWjW1Nv1LlCmQ(C7dNMzrOdtpmtlpkxrIKYXuL87gDfauXcfBxHg0ablioLE)M(gwgNxxQpdAft3GtkLpn2aSVMlfc8nECqeRUqC)6fx1U5UBj3T7M1VMZEcmPlTLsQ2PhLH2KRhCrl10FFw1tgIXouzeGqDoTQlYIXtfcpMbxJSMqKIXgss5GXVjSUiJwv1g5qHhekbJtSNvdFuaHbaCx13OAW2YQAOU5C)1X8)Up2ZWcr9caM03MygDrFt95Dmn)9u71xxrdsf08kC1J9jJXqWbiz6XUUHdAdxVy8vGB2E678C6bAXya1x5F3bod8RGyaREILg)mj7rkh90SG5tRxOJGz5gJzlmHV6zGuPtdkjQySDwCRjwCvRHJXWjLxeF9uOS80NdVfX1xAWoXGRQIpGCeWvA42UmbiRidsBjVOYsq)amgpK8IXHlWjck8p)endt9PdfVuLXVOvwyUnpsepnrMi9ADM4FnT4Xvw5pOyMdfQbP5LdcOJFegfcga3I2T(vPk3pfaCYTCc51D86qSDtEHsVQokQEFDLdzRN6cLmSWJGNPtABM7Tk7y1PsqL(qPVZ3Wzx8objJwiubnYWtnAbzFMIgRizqMU2Ct6TelVdosN07Vvz6TvJSv7SBVMKVsMtGkbIyPY4fwEPdcDiRDqn9ecQxCGZuqDIcYIdc5inlBuKvmbVEcDuRyiGegC8UnRTl1z76HsuIjlzC8AuQ2tQDwLvb)z0jf8SkrFrtX1YV1sGMWMW)JaE8IaCLLfc0vLAcw0mwLkefGlqF990eg3uWk9plbaTCuL7hiljhkVn5La53r2k)qa5aR4fDUw1qaPLJEofuyeVzRXmwEN4XVns64Gtk8B3oJWL8cL(vwS)vlOCKFD3TBxoNc(My3SQUkmFNYR((iaudBkkyo9fotdOz0CWFUQtU6rgjz7LFwYhEeWJy1ofWF6KV9OJWWEYZcJNPKh7lF9iJKTEIZsUcwXHAQLyBhySvrnUD13k3XFdsUcEJpq4pIpOocZtkJN(xa)nmZ7YoVlZdx)7QhFc)TmNPjtlU(23IkyqjIz6hh2gpsw3i8ajlxtz9oy4nGaqLgrYIdoJhGnwc)p7fCdbsw7HBuguVIV3tuEfS5r9BbI5vG7W3Z3dl(Rc7NJea4dFr2FO2mw(FVVNIbyRBAns(EqAlipAkX3tZIMW7SEC)i91xaKyc5Qx8fi2MWf6Jx1QV31Q7mNin(We0qAypnh6zK9X)ZRTtlZz76xKHnkDfPivgmuNunwpNjBy17QJXavd7ajoNEo7En58rj8XbsOJ0427EUoW3DwwiRNSFMOc7aXB7KNmMI3TjH7htHgXPF4V8S8diy3EjMhzenC3F7uuTRBa2uDIEfOoXhLJtE(VrEb4ttXst7cCaZGEjmhkFcb57M1UJ9yWgeRhaRUOkL)vgiSDhVdUxCdSGxFfcplB)qt4sesq7CJP(f79qCyNjKi6Q7eN2GUzkpuRgi4WKoSrcQ7rkfZfEWSFuc3uEWMgk4urnZkvi3w85or3mDqUZ3vskOHXa0cY0OcBX0p41MP8N7AxHtLFC3mS13ExVGBxBLqDrEZQmE42NYDU7rn2m9DnHYgHiP1OMHmkNeWYpPoY6YO0lG5WukFzZuU92nfX9fhRfO9lh3SJwhYZGnA315drm19PlcszEVPcpOsslZ6A6F(S1S016)r8RxN8Lht3oBs3UFmGZwuxuo4283t559)3YLeQSZZyI1pE359r7x3B7fRFHVKWBw7IyBN9WW(X9tICVfj1fvc8z0MEps3wWwp31o9JJ3ZE6KqtwwN9lGhdooQtSnpyEoOVD7S3i7Ph2yFvBhq06o6hpGpoZaUdHeIFCowRlsHu2YPCtg8y)XwZQ2FhyhW3V)aY7OBNRavNp)FmI6zCIPRoh0H8K53C1uGXiBpRt0D1tHo0Nk94O2gmgz9morDy3g6qCY6Eh0sHXa2oHBBC)(qyEmGqf0DMWcDTz3F63U12YDt9WYQH2jRxdDAC3T52mStwN4W(XFc87w4frJjRBSFJ7pbj0l7IOWuo0d7W)j4GzDxejMS01Hn73zUNrRsYH3HrYC)ddyQKu2HF53uLq1)hiyUibgzoWUmsK9(Hd81nWO9v)ZwkL(3sWgHbf6o9phWSvw5Sm73IOvfQuloI15P()7O)gLtKJ7)Fd]] )

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
