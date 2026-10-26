-- Rogue builds and combat scenarios for tools/harness.lua.

local BUILDS = {
    [ "19/32/0" ] = { -- Combat swords (raid): Assassination utility, Blade Flurry, Adrenaline Rush
        14142, 14161, 14159, 14167, 14179, 14137,                        -- Assa: Malice 5, Ruthlessness 3, Murder 2, Imp. SnD 3, Relentless, Lethality 5
        13863, 13845, 13791, 13872, 14251, 13852, 13964, 13877, 30920, 18429, 13750, -- Combat: Imp. SS 2, Precision 5, LR 5, Endurance 2, Riposte, DW 5, Swords 5, BF, WE 2, Aggression 3, AR
    },
    [ "31/8/12" ] = { -- Assassination Seal Fate daggers
        14164, 14142, 14161, 14159, 14167, 14179, 14137, 16514, 14177, 14195, 14983, -- Assa: Imp. Evis 3, ..., Vile Poisons 2, Cold Blood, Seal Fate 5, Vigor
        13866, 13845,                                                    -- Combat: Imp. Backstab 3, Precision 5
        14075, 30893, 14066, 13980,                                      -- Sub: Opportunity 5, Sleight 2, Elusiveness 2, Initiative 3
    },
    [ "21/0/30" ] = { -- Subtlety Hemorrhage
        14163, 14142, 14161, 14159, 14167, 14179, 14137,                 -- Assa: Imp. Evis 2, Malice 5, Ruth 3, Murder 2, Imp. SnD 3, Relentless, Lethality 5
        14075, 30893, 14066, 13980, 14278, 14081, 14173, 14185, 14083, 16511, 30906, 14183, 30894, -- Sub: ..., Ghostly, Imp. Ambush 3, Serrated 3, Prep, DD 2, Hemo, Deadliness 5, Premed, HS 1
    },
    [ "0/0/0" ] = {},
}

local SWORDS = { [ 16 ] = 19351, [ 17 ] = 18832, [ 18 ] = 19361 }    -- Maladath + Brutality Blade, crossbow
local DAGGERS = { [ 16 ] = 18816, [ 17 ] = 18805, [ 18 ] = 19361 }   -- Perdition's Blade + Core Hound Tooth, crossbow

-- Setting defaults (Era/Rogue.lua), restored before every scenario.
local DEFAULTS = {
    finish_cp = 5, snd_refresh = 3, rupture_mode = "noraid", expose_mode = "never", blade_flurry_single = true,
    behind_target = true, opener = "auto", thistle_tea = true,
}

local function Settings( H )
    local Hekili = rawget( _G, "Hekili" )
    return Hekili and Hekili.DB and Hekili.DB.profile.specs[ 4 ].settings
end

local function StealthID( level )
    return level >= 60 and 1787 or level >= 40 and 1786 or level >= 20 and 1785 or 1784
end

return {
    builds = BUILDS,
    defaultBuild = "19/32/0",

    reset = function( H )
        local W = H.W
        W.powerType, W.energy, W.combo = 3, 100, 0
        W.forms = { StealthID( H.LEVEL ) }
        W.stance = 0
        W.equip = ( H.BUILD == "19/32/0" or H.BUILD == "0/0/0" ) and SWORDS or DAGGERS

        local s = Settings( H )
        if s then for k, v in pairs( DEFAULTS ) do s[ k ] = v end end

        -- Cooldowns and Interrupts toggles off (the profile default) unless a scenario turns them on.
        local Hekili = rawget( _G, "Hekili" )
        local toggles = Hekili and Hekili.DB and Hekili.DB.profile.toggles
        if toggles then
            if toggles.cooldowns then toggles.cooldowns.value = false end
            if toggles.interrupts then toggles.interrupts.value = false end
        end
    end,

    scenarios = function( H )
        local W, Target, Aura, CLEU, GUIDS = H.W, H.Target, H.Aura, H.CLEU, H.GUIDS
        local function SnD( remains ) return Aura( 6774, remains, 0, 30 ) end
        local function Set( k, v ) Settings( H )[ k ] = v end
        local function Toggle( name ) H.Hekili.DB.profile.toggles[ name ].value = true end
        local function Stealthed()
            W.stance = 1
            W.buffs = { Aura( StealthID( H.LEVEL ) ) }
        end

        return {
            { "Out of combat, target in range, not stealthed", function()
                W.target = Target()
            end },
            { "Stealthed, target in range (opener)", function()
                W.target = Target(); Stealthed()
            end },
            { "Stealthed, boss target (opener)", function()
                W.target = Target( 1000000, true ); Stealthed()
            end },
            { "Stealthed, opener Garrote (setting)", function()
                Set( "opener", "garrote" )
                W.target = Target(); Stealthed()
            end },
            { "Stealthed, opener Cheap Shot (setting)", function()
                Set( "opener", "cheap_shot" )
                W.target = Target(); Stealthed()
            end },
            { "Stealthed, opener: normal builder (setting)", function()
                Set( "opener", "none" )
                W.target = Target(); Stealthed()
            end },
            { "Combat, 100 energy, 0 CP, no SnD", function()
                W.inCombat, W.target = true, Target()
            end },
            { "Combat, 60 energy, 2 CP, no SnD", function()
                W.inCombat, W.target, W.energy, W.combo = true, Target(), 60, 2
            end },
            { "Combat, 60 energy, 3 CP, SnD 15 s", function()
                W.inCombat, W.target, W.energy, W.combo, W.buffs = true, Target(), 60, 3, { SnD( 15 ) }
            end },
            { "Combat, 60 energy, 5 CP, SnD 15 s", function()
                W.inCombat, W.target, W.energy, W.combo, W.buffs = true, Target(), 60, 5, { SnD( 15 ) }
            end },
            { "Combat, 60 energy, 5 CP, SnD 2 s", function()
                W.inCombat, W.target, W.energy, W.combo, W.buffs = true, Target(), 60, 5, { SnD( 2 ) }
            end },
            { "Combat, 10 energy, 2 CP, SnD 2.5 s (pool for SnD)", function()
                W.inCombat, W.target, W.energy, W.combo, W.buffs = true, Target(), 10, 2, { SnD( 2.5 ) }
            end },
            { "Combat, 5 energy, 3 CP, SnD 15 s (energy-starved)", function()
                W.inCombat, W.target, W.energy, W.combo, W.buffs = true, Target(), 5, 3, { SnD( 15 ) }
            end },
            { "Combat, 60 energy, 4 CP, SnD 15 s, Eviscerate at 4 (setting)", function()
                Set( "finish_cp", 4 )
                W.inCombat, W.target, W.energy, W.combo, W.buffs = true, Target(), 60, 4, { SnD( 15 ) }
            end },
            { "Combat, 3 enemies, 60 energy, 2 CP, SnD 15 s, cooldowns on", function()
                Toggle( "cooldowns" )
                W.inCombat, W.target, W.energy, W.combo, W.buffs = true, Target(), 60, 2, { SnD( 15 ) }
                H.Plates( 2 )
            end },
            { "Combat, 1 enemy, 60 energy, 2 CP, SnD 15 s, cooldowns on", function()
                Toggle( "cooldowns" )
                W.inCombat, W.target, W.energy, W.combo, W.buffs = true, Target(), 60, 2, { SnD( 15 ) }
            end },
            { "Combat, 1 enemy, 20 energy, BF on cd, cooldowns on (AR)", function()
                Toggle( "cooldowns" )
                W.inCombat, W.target, W.energy, W.combo, W.buffs = true, Target(), 20, 2, { SnD( 15 ) }
                W.cooldowns[ 13877 ] = { start = W.time, duration = 120 }
            end },
            { "Combat, 60 energy, 5 CP, SnD 15 s, raid, cooldowns on", function()
                Toggle( "cooldowns" )
                W.groupSize, W.inCombat, W.target, W.energy, W.combo, W.buffs = 25, true, Target( 1000000, true ), 60, 5, { SnD( 15 ) }
                W.cooldowns[ 13877 ] = { start = W.time, duration = 120 }
                W.cooldowns[ 13750 ] = { start = W.time, duration = 300 }
            end },
            { "Combat, 1 enemy, SnD 15 s, cooldowns on, BF single target off (setting)", function()
                Toggle( "cooldowns" ); Set( "blade_flurry_single", false )
                W.inCombat, W.target, W.energy, W.combo, W.buffs = true, Target(), 60, 2, { SnD( 15 ) }
            end },
            { "Combat, 30 energy, 2 CP, SnD 15 s, just parried", function()
                W.inCombat, W.target, W.energy, W.combo, W.buffs = true, Target(), 30, 2, { SnD( 15 ) }
                W.cooldowns[ 13877 ] = { start = W.time, duration = 120 }
                W.cooldowns[ 13750 ] = { start = W.time, duration = 300 }
                CLEU( "SWING_MISSED", W.target.guid, GUIDS.player, "PARRY", false, 0 )
            end },
            { "Combat, 60 energy, target casting, interrupts on", function()
                Toggle( "interrupts" )
                W.inCombat, W.target, W.energy, W.combo, W.buffs = true, Target(), 60, 1, { SnD( 15 ) }
                W.target.casting = { spellID = 133, start = W.time, finish = W.time + 8 } -- still casting when the 4 s scenario ends
            end },
            { "Combat, 60 energy, 2 CP, SnD 15 s, not behind (setting)", function()
                Set( "behind_target", false )
                W.inCombat, W.target, W.energy, W.combo, W.buffs = true, Target(), 60, 2, { SnD( 15 ) }
            end },
            { "Solo, 5 CP, SnD 15 s (Rupture outside raids)", function()
                W.inCombat, W.target, W.energy, W.combo, W.buffs = true, Target(), 60, 5, { SnD( 15 ) }
            end },
            { "Raid, 5 CP, SnD 15 s (no Rupture in raids)", function()
                W.groupSize, W.inCombat, W.target, W.energy, W.combo, W.buffs = 25, true, Target( 1000000, true ), 60, 5, { SnD( 15 ) }
            end },
            { "Raid, 5 CP, SnD 15 s, Rupture always (setting)", function()
                Set( "rupture_mode", "always" )
                W.groupSize, W.inCombat, W.target, W.energy, W.combo, W.buffs = 25, true, Target( 1000000, true ), 60, 5, { SnD( 15 ) }
            end },
            { "Raid, 5 CP, Expose Armor w/o Sunder, target sundered", function()
                Set( "expose_mode", "no_sunder" ); Set( "rupture_mode", "never" )
                W.groupSize, W.inCombat, W.target, W.energy, W.combo, W.buffs = 25, true, Target( 1000000, true ), 60, 5, { SnD( 15 ) }
                W.debuffs = { Aura( 11597, 25, 5, 30 ) }
            end },
            { "Raid, 5 CP, Expose Armor w/o Sunder, no Sunder", function()
                Set( "expose_mode", "no_sunder" ); Set( "rupture_mode", "never" )
                W.groupSize, W.inCombat, W.target, W.energy, W.combo, W.buffs = 25, true, Target( 1000000, true ), 60, 5, { SnD( 15 ) }
            end },
            { "Raid, 5 CP, Expose Armor always, EA up 20 s", function()
                Set( "expose_mode", "always" ); Set( "rupture_mode", "never" )
                W.groupSize, W.inCombat, W.target, W.energy, W.combo, W.buffs = 25, true, Target( 1000000, true ), 60, 5, { SnD( 15 ) }
                W.debuffs = { Aura( 11198, 20, 0, 30 ) }
            end },
            { "Combat, 60 energy, 2 CP, SnD 15 s, GCD just triggered", function()
                W.inCombat, W.target, W.energy, W.combo, W.buffs = true, Target(), 60, 2, { SnD( 15 ) }
                W.gcdStart = W.time + 3.1 -- the scenario ticks 4 s; the harness GCD is 1.5 s, so ~0.6 s is left at the end
            end },
        }
    end,
}
