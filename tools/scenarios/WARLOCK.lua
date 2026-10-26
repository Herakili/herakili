-- Warlock builds and combat scenarios for tools/harness.lua.

local BUILDS = {
    [ "30/0/21" ] = { -- Affliction (SM/Ruin-style: Nightfall, Siphon Life, Shadow Mastery, Dark Pact)
        18175, 17814, 18183, 18372, 18830, 17787, 18288, 18095, 18265, 18275, 18220, 18218, -- Aff: Suppr. 2, Imp. Corr 5, Imp. LT 2, Imp. DS 2, Imp. CoA 3, Fel Conc 5, Amplify, Nightfall 2, SL, SM 5, Dark Pact, Grim Reach 1
        17803, 17782, 17792, 18134, 17959,                                                   -- Destro: ISB 5, Cataclysm 5, Bane 5, Devastation 5, Ruin
    },
    [ "0/31/20" ] = { -- Demonology (Soul Link / Master Demonologist, demon kept out)
        18695, 18701, 18746, 18708, 18752, 18710, 18773, 23825, 19028,                       -- Demo: Imp. Imp 2, Embrace 5, Fel Int 5, Fel Dom, Fel Stam 5, Master Summ. 2, Unholy Power 5, MD 5, Soul Link
        17803, 17782, 17792, 18134,                                                          -- Destro: ISB 5, Cataclysm 5, Bane 5, Devastation 5
    },
    [ "7/21/23" ] = { -- Destruction (DS/Ruin: Succubus sacrificed, Shadow Bolt)
        17814, 18175,                                                                        -- Aff: Imp. Corruption 5, Suppression 2
        18701, 18696, 18746, 18708, 18707, 18710, 18754, 18788,                              -- Demo: Embrace 5, Imp. Imp 3, Fel Int 5, Fel Dom, Imp. VW 3, Master Summ. 2, Imp. Sayaad 1, Demonic Sacrifice
        17803, 17782, 17792, 18134, 17877, 18119, 17959,                                     -- Destro: ISB 5, Cata 5, Bane 5, Devastation 5, Shadowburn, Aftermath 1, Ruin
    },
    [ "0/21/30" ] = { -- Destruction, Fire (Imp sacrificed, Conflagrate, Improved Searing Pain, Emberstorm)
        18701, 18696, 18746, 18708, 18707, 18710, 18754, 18788,                              -- Demo: as DS/Ruin
        17782, 17792, 18134, 17877, 17932, 17959, 17958, 18136, 17962,                       -- Destro: Cata 5, Bane 5, Dev 5, Shadowburn, Imp. SP 5, Ruin, Emberstorm 5, Intensity 2, Conflagrate
    },
    [ "0/0/0" ] = {},
}

-- Hekili derives base mana from max mana minus intellect (the harness reports 300 intellect = 4220 mana).
local function BaseMana( level ) return 4220 + math.floor( 1400 * level / 60 ) end

local PET_NPC = { Imp = 416, Voidwalker = 1860, Succubus = 1863, Felhunter = 417 }

return {
    builds = BUILDS,
    defaultBuild = "30/0/21",

    reset = function( H )
        local W = H.W
        W.powerType = 0
        W.manaMax = BaseMana( H.LEVEL ) + 3000
        W.mana = W.manaMax
        W.baseMana = math.floor( 1100 * H.LEVEL / 60 )                     -- percent costs (summons, Soul Link)
        W.pet = nil
        W.itemCounts = { [ 6265 ] = 5 }                                  -- Soul Shards
        W.equip = { [ 18 ] = H.LEVEL >= 60 and 19861 or 11287 }          -- Touch of Chaos / Lesser Magic Wand
        if H.Hekili and H.Hekili.DB then H.Hekili.DB.profile.toggles.cooldowns.value = false end
    end,

    scenarios = function( H )
        local W, Target, Aura, Setting = H.W, H.Target, H.Aura, H.Setting
        -- Scenarios tick 4 seconds before the display is read: add 4 to remaining times.
        local T = 4
        local DS = H.BUILD == "7/21/23" or H.BUILD == "0/21/30"

        local function Pet( family, mana )
            H.Pet( family, family )
            W.pet.guid = "Pet-0-1-1-1-" .. PET_NPC[ family ] .. "-0000000099"
            W.pet.mana, W.pet.manaMax = mana or 1000, 1000
            H.Fire( "UNIT_PET", "player" )
        end
        local function Armor() return Aura( 11735, 1500, 0, 1800 ) end
        -- The build's usual setup: Demon Armor plus the demon out, or its Demonic Sacrifice buff.
        local function Setup()
            W.buffs = { Armor() }
            if H.BUILD == "7/21/23" then table.insert( W.buffs, Aura( 18791, 1500, 0, 1800 ) )      -- Touch of Shadow
            elseif H.BUILD == "0/21/30" then table.insert( W.buffs, Aura( 18789, 1500, 0, 1800 ) )  -- Burning Wish
            elseif H.BUILD == "0/31/20" then
                Pet( "Imp" ); table.insert( W.buffs, Aura( 25228, 3000, 0, 3600 ) )                 -- Soul Link
            elseif H.LEVEL >= 10 and H.LEVEL < 40 then Pet( "Voidwalker" )
            else Pet( "Imp" ) end
        end
        local function Combat( manaPct, healthPct )
            Setup()
            W.inCombat, W.target = true, Target()
            if manaPct then W.mana = math.floor( W.manaMax * manaPct / 100 ) end
            if healthPct then W.health = math.floor( W.healthMax * healthPct / 100 ) end
        end
        -- All of the build's DoTs and the default curse (Agony) on the target.
        local function DotsUp()
            W.debuffs = { Aura( 11713, 20 + T, 0, 24 ), Aura( 25311, 15 + T, 0, 18 ), Aura( 25309, 12 + T, 0, 15 ) }
            if H.BUILD == "30/0/21" then table.insert( W.debuffs, Aura( 18881, 25 + T, 0, 30 ) ) end
        end

        return {
            -- Out of combat / pet management.
            { "OOC, target, no demon", function()
                W.target, W.buffs = Target(), { Armor() }
            end },
            { "OOC, no target, no Demon Armor", function()
                Setup()
                W.buffs = {}
                if DS then W.buffs = { Aura( H.BUILD == "7/21/23" and 18791 or 18789, 1500, 0, 1800 ) } end
            end },
            { "OOC, demon out, fresh target (pull)", function()
                Setup()
                W.target = Target()
            end },
            { "OOC, demon out, no sacrifice / Soul Link yet", function()
                W.target, W.buffs = Target(), { Armor() }
                Pet( H.BUILD == "0/21/30" and "Imp" or ( DS and "Succubus" or "Imp" ) )
            end },
            { "OOC, no demon, setting Demon=Felhunter", function()
                W.target, W.buffs = Target(), { Armor() }
                Setting( "pet", "felhunter" )
                Setting( "demonic_sacrifice", false )
            end },
            { "OOC, no demon, setting Demon=Succubus, 0 shards", function()
                W.target, W.buffs = Target(), { Armor() }
                W.itemCounts = {}
                Setting( "pet", "succubus" )
                Setting( "demonic_sacrifice", false )
            end },
            { "OOC, no demon, setting Demon=None", function()
                W.target, W.buffs = Target(), { Armor() }
                Setting( "pet", "none" )
            end },
            { "OOC, demon out, setting Demonic Sacrifice off", function()
                W.target, W.buffs = Target(), { Armor() }
                Pet( "Succubus" )
                Setting( "demonic_sacrifice", false )
            end },
            { "Combat, demon died (no sacrifice buff)", function()
                Combat()
                W.pet = nil
                W.buffs = { Armor() }
                W.cooldowns = {}
            end },

            { "Combat, demon died, Cooldowns on (Fel Domination)", function()
                Combat()
                W.pet = nil
                W.buffs = { Armor() }
                H.Hekili.DB.profile.toggles.cooldowns.value = true
            end },

            -- Single target.
            { "Combat, fresh target", function()
                Combat()
            end },
            { "Combat, fresh target, Amplify Curse on cd", function()
                Combat()
                W.cooldowns[ 18288 ] = { start = W.time, duration = 100 }
            end },
            { "Combat, DoTs + curse up", function()
                Combat()
                DotsUp()
            end },
            { "Combat, DoTs up, Shadow Trance proc", function()
                Combat()
                DotsUp()
                table.insert( W.buffs, Aura( 17941, 6 + T, 0, 10 ) )
            end },
            { "Combat, fresh target, Shadow Trance about to expire", function()
                Combat()
                table.insert( W.buffs, Aura( 17941, 2 + T, 0, 10 ) )
            end },
            { "Combat, DoTs up, 20% mana, 90% health (Life Tap)", function()
                Combat( 20, 90 )
                DotsUp()
                if W.pet then W.pet.mana = 0 end
            end },
            { "Combat, DoTs up, 20% mana, demon has mana (Dark Pact)", function()
                Combat( 20, 90 )
                DotsUp()
                if not W.pet then Pet( "Imp" ) end
                W.pet.mana = 1000
            end },
            { "Combat, DoTs up, 20% mana, 45% health (no tap)", function()
                Combat( 20, 45 )
                DotsUp()
                if W.pet then W.pet.mana = 0 end
            end },
            { "Combat, DoTs up, 5% mana, 40% health (wand)", function()
                Combat( 5, 40 )
                DotsUp()
                if W.pet then W.pet.mana = 0 end
            end },
            { "Combat, DoTs up, 5% mana, 40% health, wanding", function()
                Combat( 5, 40 )
                DotsUp()
                if W.pet then W.pet.mana = 0 end
                W.autoRepeat = true
            end },
            { "Combat, DoTs up, 25% health (low health)", function()
                Combat( 80, 25 )
                DotsUp()
            end },
            { "Combat, DoTs up, target at 20% (execute)", function()
                Combat()
                DotsUp()
                W.target = Target( 20000 )
            end },
            { "Combat, DoTs up, target 20%, Drain Soul Execute on", function()
                Combat()
                DotsUp()
                W.target = Target( 20000 )
                Setting( "drain_soul_execute", true )
            end },
            { "Combat, solo, Voidwalker, DoTs up, 60% health", function()
                Combat( 80, 60 )
                DotsUp()
                Pet( "Voidwalker" )
            end },

            -- AoE.
            { "Combat, 4 enemies (Rain of Fire)", function()
                Combat()
                H.Plates( 3 )
            end },
            { "Combat, 4 enemies, Hellfire on, RoF off", function()
                Combat()
                H.Plates( 3 )
                Setting( "aoe_hellfire", true )
                Setting( "aoe_rain_of_fire", false )
            end },
            { "Combat, 4 enemies, AoE spells off", function()
                Combat()
                H.Plates( 3 )
                Setting( "aoe_rain_of_fire", false )
            end },

            -- Curse settings.
            { "Raid, fresh target, curse Elements", function()
                Combat(); W.groupSize = 25
                Setting( "curse_raid", "elements" )
            end },
            { "Raid, fresh target, curse Shadow", function()
                Combat(); W.groupSize = 25
                Setting( "curse_raid", "shadow" )
            end },
            { "Raid, fresh target, curse Recklessness", function()
                Combat(); W.groupSize = 25
                Setting( "curse_raid", "recklessness" )
            end },
            { "Raid, fresh boss, curse Doom", function()
                Combat(); W.groupSize = 25
                W.target = Target( nil, true )
                Setting( "curse_raid", "doom" )
            end },
            { "Raid, Elements already up (other lock)", function()
                Combat(); W.groupSize = 25
                Setting( "curse_raid", "elements" )
                W.debuffs = { Aura( 11722, 200 + T, 0, 300 ) }
            end },
            { "Party, fresh target, solo curse Weakness", function()
                Combat(); W.groupSize = 5
                Setting( "curse_solo", "weakness" )
            end },
            { "Combat, fresh target, curse None", function()
                Combat()
                Setting( "curse_solo", "none" )
            end },

            -- Spell settings.
            { "Combat, curse+Corruption up, Immolate off", function()
                Combat()
                W.debuffs = { Aura( 11713, 20 + T, 0, 24 ), Aura( 25311, 15 + T, 0, 18 ), Aura( 18881, 25 + T, 0, 30 ) }
                Setting( "immolate", false )
            end },
            { "Combat, Immolate 2s left (Conflagrate)", function()
                Combat()
                DotsUp()
                W.debuffs[ 3 ] = Aura( 25309, 2 + T, 0, 15 )
            end },
            { "Combat, DoTs up, Soul Fire on", function()
                Combat()
                DotsUp()
                Setting( "soul_fire", true )
            end },
            { "Combat, DoTs up, Searing Pain on", function()
                Combat()
                DotsUp()
                Setting( "searing_pain", true )
            end },
        }
    end,
}
