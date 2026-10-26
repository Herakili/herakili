-- Warrior builds and combat scenarios for tools/harness.lua.

local BUILDS = {
    [ "17/34/0" ] = { -- Fury (dual wield)
        12663, 12659, 12679, 12963, 12867, 16494,                       -- Arms: Imp. HS 2, Imp. Rend 3, TM 5, Imp. OP 2, DW 3, Impale 2
        12838, 12856, 12861, 23588, 20503, 13048, 12328, 12974, 23881,  -- Fury: BV 5, Cruelty 5, IBS 5, DWS 5, Imp. Exec 2, Enrage 5, DW, Flurry 5, BT
    },
    [ "31/20/0" ] = { -- Arms (two-hander)
        12664, 12659, 12679, 12963, 12296, 12867, 12714, 16494, 12292, 12785, 12294, -- Arms: ... Anger Mgmt, 2H Spec 5, Impale 2, SS, Axe 5, MS
        12838, 12856, 13002, 12861,                                     -- Fury: BV 5, Cruelty 5, UW 5, IBS 5
    },
    [ "8/48/3" ] = { -- Fury/Prot dual-wield tank: Fury tree plus Defiance-free utility (common Era DW tank spec)
        12663, 12679,                                                    -- Arms: Imp. HS 2 (TM 5 takes 5 more)
        12838, 12856, 13002, 12861, 23588, 20503, 13048, 12328, 12974, 23881, 20501, 20505, -- Fury: ..., BT, Imp. BR 2, Imp. Intercept 2
        12299,                                                           -- Prot: Toughness 1
    },
    [ "14/5/32" ] = { -- Protection (shield) tank
        12663, 12679,                                                    -- Arms: Imp. HS 2, TM 5
        12838,                                                           -- Fury: BV 5
        12727, 12753, 12818, 12764, 12975, 12944, 12800, 12792, 12811, 12765, 12809, 16542, 23922, -- Prot: ... Defiance 5, Imp. Sunder 3, Shield Slam
    },
    [ "0/0/0" ] = {},
}

local DW = { [ 16 ] = 19019, [ 17 ] = 19351, [ 18 ] = 19361 }         -- Thunderfury + Maladath, crossbow
local TWO_HANDER = { [ 16 ] = 17076, [ 18 ] = 19361 }                  -- Bonereaver's Edge
local SWORD_AND_BOARD = { [ 16 ] = 19019, [ 17 ] = 19349, [ 18 ] = 19361 } -- Thunderfury + Elementium Reinforced Bulwark

return {
    builds = BUILDS,
    defaultBuild = "17/34/0",

    reset = function( H )
        local W = H.W
        W.powerType, W.rage = 1, 0
        W.forms = { 2457, 71, 2458 }                         -- Battle, Defensive, Berserker Stance
        W.stance = ( H.LEVEL >= 30 ) and 3 or 1
        W.equip = ( H.BUILD == "31/20/0" ) and TWO_HANDER or ( H.BUILD == "14/5/32" and SWORD_AND_BOARD or DW )
    end,

    scenarios = function( H )
        local W, Target, Aura, Fire, CLEU, GUIDS = H.W, H.Target, H.Aura, H.Fire, H.CLEU, H.GUIDS
        local function Shout() return Aura( 25289, 100, 0, 120 ) end

        return {
            { "Out of combat, target in range, no Battle Shout", function()
                W.rage, W.target = 20, Target()
            end },
            { "Combat, 60 rage, single target", function()
                W.inCombat, W.rage, W.target, W.buffs = true, 60, Target(), { Shout() }
            end },
            { "Combat, 10 rage, single target", function()
                W.inCombat, W.rage, W.target, W.buffs = true, 10, Target(), { Shout() }
            end },
            { "Combat, 60 rage, target at 15% (execute)", function()
                W.inCombat, W.rage, W.target, W.buffs = true, 60, Target( 15000 ), { Shout() }
            end },
            { "Combat, 60 rage, 3 enemies in melee", function()
                W.inCombat, W.rage, W.target, W.buffs = true, 60, Target(), { Shout() }
                H.Plates( 2 )
            end },
            { "Combat, 60 rage, 3 enemies hit, nameplates OFF", function()
                W.inCombat, W.rage, W.target, W.buffs = true, 60, Target(), { Shout() }
                W.cvars.nameplateShowEnemies = "0"
                -- Damage-based detection counts ability hits (white swings go through the swing timer), e.g. Whirlwind.
                for i = 1, 3 do
                    W.cleu = { n = 23, W.time, "SPELL_DAMAGE", false, GUIDS.player, "Tester", 0x511, 0,
                        "Creature-0-1-1-1-1234-000000000" .. i, "Mob", 0xa48, 0, 1680, "Whirlwind", 1, 600, -1, 1, 0, 0, 0, false, false }
                    Fire( "COMBAT_LOG_EVENT_UNFILTERED" )
                    W.cleu = nil
                end
            end },
            { "Out of combat, Battle Stance, target 20 yd away", function()
                W.rage, W.target, W.buffs, W.stance = 0, Target(), { Shout() }, 1
                W.target.distance = 20
            end },
            { "Combat, Berserker Stance, 20 rage, target 15 yd away", function()
                W.inCombat, W.rage, W.target, W.buffs, W.stance = true, 20, Target(), { Shout() }, 3
                W.target.distance = 15
            end },
            { "Combat, 60 rage, GCD just triggered", function()
                W.inCombat, W.rage, W.target, W.buffs = true, 60, Target(), { Shout() }
                W.gcdStart = W.time + 3.9 -- the scenario ticks 4 s; this leaves ~1.4 s of GCD at the end
            end },

            -- Raid opener (setting "Open With Sunder Armor" = In raids, the default).
            { "Raid pull: Battle Stance, 0 rage, target 20 yd", function()
                W.groupSize, W.rage, W.target, W.buffs, W.stance = 25, 0, Target(), { Shout() }, 1
                W.target.distance = 20
            end },
            { "Raid: just charged, Battle Stance, 15 rage", function()
                W.groupSize, W.inCombat, W.rage, W.target, W.buffs, W.stance = 25, true, 15, Target(), { Shout() }, 1
            end },
            { "Raid: Battle Stance, 5 rage (no rage for Sunder)", function()
                W.groupSize, W.inCombat, W.rage, W.target, W.buffs, W.stance = 25, true, 5, Target(), { Shout() }, 1
            end },
            { "Raid: Berserker Stance, 30 rage, no Sunder yet", function()
                W.groupSize, W.inCombat, W.rage, W.target, W.buffs, W.stance = 25, true, 30, Target(), { Shout() }, 3
            end },
            { "Raid: Berserker Stance, 30 rage, Sunder already cast", function()
                W.groupSize, W.inCombat, W.rage, W.target, W.buffs, W.stance = 25, true, 30, Target(), { Shout() }, 3
                W.debuffs = { Aura( 11597, 29, 1, 30 ) }
                H.Cast( 11597 )
            end },
            { "Party (5): Berserker Stance, 30 rage", function()
                W.groupSize, W.inCombat, W.rage, W.target, W.buffs, W.stance = 5, true, 30, Target(), { Shout() }, 3
            end },
            { "Battle Stance, 30 rage, target just dodged", function()
                W.inCombat, W.rage, W.target, W.buffs, W.stance = true, 30, Target(), { Shout() }, 1
                CLEU( "SWING_MISSED", GUIDS.player, W.target.guid, "DODGE", false, 0 )
            end },

            -- Tanking.  Tank Mode "auto" (default): Defensive Stance means tanking.
            { "Tank: Defensive, 35 rage, aggro", function()
                W.inCombat, W.rage, W.target, W.buffs, W.stance, W.aggro = true, 35, Target(), { Shout() }, 2, true
                W.debuffs = { Aura( 11597, 25, 5, 30 ), Aura( 11556, 20, 0, 30 ) }
            end },
            { "Tank: Defensive, 60 rage, just parried (Revenge)", function()
                W.inCombat, W.rage, W.target, W.buffs, W.stance, W.aggro = true, 60, Target(), { Shout() }, 2, true
                W.debuffs = { Aura( 11597, 25, 5, 30 ), Aura( 11556, 20, 0, 30 ) }
                CLEU( "SWING_MISSED", W.target.guid, GUIDS.player, "PARRY", false, 0 )
            end },
            { "Tank: Defensive, 30 rage, fresh target (no Sunder/Demo)", function()
                W.inCombat, W.rage, W.target, W.buffs, W.stance, W.aggro = true, 30, Target(), { Shout() }, 2, true
            end },
            { "Tank: Defensive, 55 rage, 3 enemies", function()
                W.inCombat, W.rage, W.target, W.buffs, W.stance, W.aggro = true, 55, Target(), { Shout() }, 2, true
                W.debuffs = { Aura( 11597, 25, 5, 30 ), Aura( 11556, 20, 0, 30 ) }
                H.Plates( 2 )
            end },
            { "Tank: Defensive, 40 rage, lost aggro, taunt setting on", function()
                W.inCombat, W.rage, W.target, W.buffs, W.stance, W.aggro = true, 40, Target(), { Shout() }, 2, false
                W.debuffs = { Aura( 11597, 25, 5, 30 ), Aura( 11556, 20, 0, 30 ) }
                H.Setting( "tank_taunt", true )
            end },
            { "Tank: Defensive, 40 rage, 15% health", function()
                W.inCombat, W.rage, W.target, W.buffs, W.stance, W.aggro = true, 40, Target(), { Shout() }, 2, true
                W.health = W.healthMax * 0.15
                W.debuffs = { Aura( 11597, 25, 5, 30 ), Aura( 11556, 20, 0, 30 ) }
            end },
            { "Tank Mode Always: pull, Battle Stance, 20 yd", function()
                W.rage, W.target, W.buffs, W.stance = 0, Target(), { Shout() }, 1
                W.target.distance = 20
                H.Setting( "tank_mode", "always" )
            end },
            { "Tank Mode Always: charged, Battle Stance, 40 rage", function()
                W.inCombat, W.rage, W.target, W.buffs, W.stance, W.aggro = true, 40, Target(), { Shout() }, 1, true
                H.Setting( "tank_mode", "always" )
            end },
            { "Tank Mode Never: in Defensive Stance", function()
                W.inCombat, W.rage, W.target, W.buffs, W.stance = true, 30, Target(), { Shout() }, 2
                H.Setting( "tank_mode", "never" )
            end },
        }
    end,
}
