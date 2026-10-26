-- Druid builds and combat scenarios for tools/harness.lua.
-- Build strings are Balance/Feral Combat/Restoration (the in-game tab order).

local BUILDS = {
    [ "0/31/20" ] = { -- Feral (raid cat / bear): Leader of the Pack, Furor 5/5
        16938, 16951, 16941, 24866, 16979, 16944, 16968, 16975, 16954, 16961, 16999, 16857, 24894, 17007, -- Feral: Ferocity 5, Feral Instinct 5, BI 2, FS 2, Feral Charge, SC 3, Imp. Shred 2, PS 3, BF 2, PF 2, SF 2, FF (Feral), HotW 5, LotP
        17055, 17061, 17068, 17082,                                      -- Resto: Imp. MotW 5, Furor 5, Nature's Focus 5, Imp. Enrage 2
    },
    [ "31/0/20" ] = { -- Balance (Moonkin)
        16818, 16825, 16835, 16864, 16820, 16913, 16926, 16880, 16847, 16901, 24858, -- Balance: Imp. Wrath 5, Imp. MF 5, NS 3, OoC, NR 2, Vengeance 5, Imp. SF 5, NG, Moonglow 3, Moonfury 5, Moonkin
        17055, 17061, 17068, 5570,                                       -- Resto: Imp. MotW 5, Furor 5, Nature's Focus 5, Insect Swarm
    },
    [ "0/0/31" ] = { -- Restoration (gets the Balance priority)
        17055, 17061, 17068, 5570, 24972, 17116, 24946, 17078, 18562,  -- Resto: ..., Insect Swarm, TS 5, NSw, GoN 5, Imp. Regrowth 5, Swiftmend
    },
    [ "0/0/0" ] = {},
}

local STAFF = { [ 16 ] = 943 }               -- Warden Staff
local WOLFSHEAD = { [ 1 ] = 8345, [ 16 ] = 943 }

local MOTW = 9885

return {
    builds = BUILDS,
    defaultBuild = "0/31/20",

    reset = function( H )
        local W = H.W
        W.powerType, W.energy, W.rage, W.combo = 0, 100, 0, 0
        W.baseMana, W.manaMax = 1244, 5000 -- level-60 druid base mana (Cat/Bear Form cost 55% of it)
        W.mana = W.manaMax
        W.forms = {}
        local L = H.LEVEL
        if L >= 10 then W.forms[ #W.forms + 1 ] = L >= 40 and 9634 or 5487 end
        if L >= 16 then W.forms[ #W.forms + 1 ] = 1066 end
        if L >= 20 then W.forms[ #W.forms + 1 ] = 768 end
        if L >= 30 then W.forms[ #W.forms + 1 ] = 783 end
        if L >= 40 and H.BUILD == "31/0/20" then W.forms[ #W.forms + 1 ] = 24858 end
        W.stance, W.formID = 0, nil
        W.equip = STAFF

        local db = H.Hekili and H.Hekili.DB
        if db then
            db.profile.toggles.defensives.value = false
            db.profile.toggles.interrupts.value = false
        end
    end,

    scenarios = function( H )
        local W, Target, Aura, Setting = H.W, H.Target, H.Aura, H.Setting
        local L = H.LEVEL

        local function Index( id )
            for i, f in ipairs( W.forms ) do if f == id then return i end end
            return 0
        end
        -- Shapeshift into a form (power type, shapeshift bar, form ID, form aura).
        local function Cat( energy, combo )
            W.powerType, W.energy, W.combo = 3, energy or 100, combo or 0
            W.stance, W.formID = Index( 768 ), 1
            W.buffs = { Aura( 768 ), Aura( MOTW, 1500, 0, 1800 ) }
        end
        local function Bear( rage )
            local id = L >= 40 and 9634 or 5487
            W.powerType, W.rage = 1, rage or 0
            W.stance, W.formID = Index( id ), L >= 40 and 8 or 5
            W.buffs = { Aura( id ), Aura( MOTW, 1500, 0, 1800 ) }
        end
        local function Moonkin()
            W.powerType = 0
            W.stance, W.formID = Index( 24858 ), 31
            W.buffs = { Aura( 24858 ), Aura( MOTW, 1500, 0, 1800 ), Aura( 16864, 500, 0, 600 ) }
        end
        local function Caster()
            W.powerType, W.stance, W.formID = 0, 0, nil
            W.buffs = { Aura( MOTW, 1500, 0, 1800 ), Aura( 16864, 500, 0, 600 ) }
        end
        local function FF() return Aura( 9907, 30, 0, 40 ) end
        local function Prowl() W.buffs[ #W.buffs + 1 ] = Aura( 9913 ) end

        local cat = {
            { "Cat: out of combat, solo, fresh target", function()
                Cat( 100 ); W.target = Target()
            end },
            { "Cat: prowling, solo (not behind) -> Pounce", function()
                Cat( 100 ); Prowl(); W.target = Target()
            end },
            { "Cat: prowling, party (behind) -> Ravage", function()
                Cat( 100 ); Prowl(); W.groupSize = 5; W.target = Target()
            end },
            { "Cat: out of combat, raid, full energy", function()
                Cat( 100 ); W.groupSize = 25; W.target = Target()
            end },
            { "Cat: out of combat, raid, Tiger's Fury never", function()
                Setting( "tigers_fury", "never" )
                Cat( 100 ); W.groupSize = 25; W.target = Target(); W.debuffs = { FF() }
            end },
            { "Cat: combat, solo, 0 CP, 100 energy, fresh target", function()
                Cat( 100 ); W.inCombat, W.target = true, Target(); W.debuffs = { FF() }
            end },
            { "Cat: combat, solo, Rake up, 60 energy", function()
                Cat( 60, 1 ); W.inCombat, W.target = true, Target(); W.debuffs = { FF(), Aura( 9904, 6, 0, 9 ) }
            end },
            { "Cat: combat, party (behind), Rake up, 60 energy", function()
                Cat( 60, 1 ); W.groupSize = 5; W.inCombat, W.target = true, Target(); W.debuffs = { FF(), Aura( 9904, 6, 0, 9 ) }
            end },
            { "Cat: combat, party, behind = never", function()
                Setting( "behind", "never" )
                Cat( 60, 1 ); W.groupSize = 5; W.inCombat, W.target = true, Target(); W.debuffs = { FF(), Aura( 9904, 6, 0, 9 ) }
            end },
            { "Cat: combat, raid, 2 CP, 70 energy", function()
                Cat( 70, 2 ); W.groupSize = 25; W.inCombat, W.target = true, Target( 100000, true ); W.debuffs = { FF() }
            end },
            { "Cat: combat, raid, no Faerie Fire on target", function()
                Cat( 70, 2 ); W.groupSize = 25; W.inCombat, W.target = true, Target( 100000, true )
            end },
            { "Cat: combat, raid, no FF, Faerie Fire setting off", function()
                Setting( "faerie_fire", false )
                Cat( 70, 2 ); W.groupSize = 25; W.inCombat, W.target = true, Target( 100000, true )
            end },
            { "Cat: combat, solo, 5 CP, 60 energy, no Rip", function()
                Cat( 60, 5 ); W.inCombat, W.target = true, Target(); W.debuffs = { FF(), Aura( 9904, 6, 0, 9 ) }
            end },
            { "Cat: combat, solo, 5 CP, Rip up", function()
                Cat( 60, 5 ); W.inCombat, W.target = true, Target(); W.debuffs = { FF(), Aura( 9904, 6, 0, 9 ), Aura( 9896, 8, 0, 12 ) }
            end },
            { "Cat: combat, raid, 5 CP, 60 energy", function()
                Cat( 60, 5 ); W.groupSize = 25; W.inCombat, W.target = true, Target( 100000, true ); W.debuffs = { FF() }
            end },
            { "Cat: combat, raid, 5 CP, bleeds = always", function()
                Setting( "bleeds", "always" )
                Cat( 60, 5 ); W.groupSize = 25; W.inCombat, W.target = true, Target( 100000, true ); W.debuffs = { FF() }
            end },
            { "Cat: combat, raid, 10 energy, 2 CP (starved)", function()
                Cat( 10, 2 ); W.groupSize = 25; W.inCombat, W.target = true, Target( 100000, true ); W.debuffs = { FF() }
            end },
            { "Cat: raid, 10 energy, powershift on, Wolfshead", function()
                Setting( "powershift", true )
                W.equip = WOLFSHEAD
                Cat( 10, 2 ); W.groupSize = 25; W.inCombat, W.target = true, Target( 100000, true ); W.debuffs = { FF() }
            end },
            { "Cat: raid, 10 energy, powershift on, no mana", function()
                Setting( "powershift", true )
                W.equip, W.mana = WOLFSHEAD, 300
                Cat( 10, 2 ); W.groupSize = 25; W.inCombat, W.target = true, Target( 100000, true ); W.debuffs = { FF() }
            end },
            { "Cat: raid, 50 energy, powershift on (enough energy)", function()
                Setting( "powershift", true )
                W.equip = WOLFSHEAD
                Cat( 50, 2 ); W.groupSize = 25; W.inCombat, W.target = true, Target( 100000, true ); W.debuffs = { FF() }
            end },
            { "Cat: raid, 90 energy, Tiger's Fury = always", function()
                Setting( "tigers_fury", "always" )
                Cat( 90, 2 ); W.groupSize = 25; W.inCombat, W.target = true, Target( 100000, true ); W.debuffs = { FF() }
            end },
            { "Cat: raid, Clearcasting, 20 energy", function()
                Cat( 20, 2 ); W.buffs[ #W.buffs + 1 ] = Aura( 16870, 10, 0, 15 )
                W.groupSize = 25; W.inCombat, W.target = true, Target( 100000, true ); W.debuffs = { FF() }
            end },
        }

        local bear = {
            { "Bear: combat, 40 rage, debuffs up", function()
                Bear( 40 ); W.groupSize = 5; W.aggro = true; W.inCombat, W.target = true, Target()
                W.debuffs = { FF(), Aura( 9898, 20, 0, 30 ) }
            end },
            { "Bear: combat, fresh target, 30 rage", function()
                Bear( 30 ); W.groupSize = 5; W.aggro = true; W.inCombat, W.target = true, Target()
            end },
            { "Bear: combat, 40 rage, Demoralizing Roar off, no debuffs", function()
                Setting( "demo_roar", false ); Setting( "faerie_fire", false )
                Bear( 40 ); W.groupSize = 5; W.aggro = true; W.inCombat, W.target = true, Target()
            end },
            { "Bear: combat, 70 rage, single target", function()
                Bear( 70 ); W.groupSize = 5; W.aggro = true; W.inCombat, W.target = true, Target()
                W.debuffs = { FF(), Aura( 9898, 20, 0, 30 ) }
            end },
            { "Bear: combat, 3 enemies, 40 rage", function()
                Bear( 40 ); W.groupSize = 5; W.aggro = true; W.inCombat, W.target = true, Target()
                W.debuffs = { FF(), Aura( 9898, 20, 0, 30 ) }
                H.Plates( 2 )
            end },
            { "Bear: combat, 5 rage (starved)", function()
                Bear( 5 ); W.groupSize = 5; W.aggro = true; W.inCombat, W.target = true, Target()
                W.debuffs = { FF(), Aura( 9898, 20, 0, 30 ) }
            end },
            { "Bear: target 15 yd away, 10 rage", function()
                Bear( 10 ); W.target = Target(); W.target.distance = 15
            end },
            { "Bear: 20% health, 40 rage, defensives on", function()
                H.Hekili.DB.profile.toggles.defensives.value = true
                Bear( 40 ); W.health = W.healthMax * 0.2; W.aggro = true; W.inCombat, W.target = true, Target()
                W.debuffs = { FF(), Aura( 9898, 20, 0, 30 ) }
            end },
            { "Bear: party, not tanking, Growl setting on", function()
                Setting( "growl_taunt", true )
                Bear( 30 ); W.groupSize = 5; W.aggro = false; W.inCombat, W.target = true, Target()
                W.debuffs = { FF(), Aura( 9898, 20, 0, 30 ) }
            end },
        }

        local caster = {
            { "Caster form: out of combat, no Mark of the Wild", function()
                Caster(); W.buffs = {}; W.target = Target()
            end },
            { "Caster form: combat, fresh target", function()
                Caster(); W.inCombat, W.target = true, Target()
            end },
            { "Caster form: combat, Moonfire up", function()
                Caster(); W.inCombat, W.target = true, Target(); W.debuffs = { Aura( 9835, 9, 0, 12 ), FF() }
            end },
            { "Caster form: combat, preferred form = bear", function()
                Setting( "feral_form", "bear" )
                Caster(); W.inCombat, W.target = true, Target()
            end },
        }

        local balance = {
            { "Balance: caster form, out of combat", function()
                Caster(); W.target = Target()
            end },
            { "Balance: Moonkin, combat, fresh target", function()
                Moonkin(); W.groupSize = 25; W.inCombat, W.target = true, Target( 100000, true )
            end },
            { "Balance: Moonkin, combat, FF up", function()
                Moonkin(); W.groupSize = 25; W.inCombat, W.target = true, Target( 100000, true ); W.debuffs = { FF() }
            end },
            { "Balance: Moonkin, combat, DoTs up", function()
                Moonkin(); W.groupSize = 25; W.inCombat, W.target = true, Target( 100000, true )
                W.debuffs = { FF(), Aura( 9835, 9, 0, 12 ), Aura( 24977, 9, 0, 12 ) }
            end },
            { "Balance: Moonkin, DoTs off, Wrath nuke", function()
                Setting( "dot_moonfire", false ); Setting( "dot_insect_swarm", false ); Setting( "balance_nuke", "wrath" )
                Moonkin(); W.groupSize = 25; W.inCombat, W.target = true, Target( 100000, true ); W.debuffs = { FF() }
            end },
            { "Balance: Moonkin, Nature's Grace up", function()
                Moonkin(); W.buffs[ #W.buffs + 1 ] = Aura( 16886, 10, 0, 15 )
                W.groupSize = 25; W.inCombat, W.target = true, Target( 100000, true )
                W.debuffs = { FF(), Aura( 9835, 9, 0, 12 ), Aura( 24977, 9, 0, 12 ) }
            end },
            { "Balance: Moonkin, 3 enemies", function()
                Moonkin(); W.inCombat, W.target = true, Target(); W.debuffs = { FF() }
                H.Plates( 2 )
            end },
            { "Balance: Moonkin, 8% mana, fresh target", function()
                Moonkin(); W.mana = W.manaMax * 0.08; W.inCombat, W.target = true, Target()
            end },
            { "Balance: Moonkin, moving", function()
                Moonkin(); W.speed = 7; W.inCombat, W.target = true, Target(); W.debuffs = { FF() }
            end },
            { "Balance: in Bear Form, 40 rage", function()
                Bear( 40 ); W.aggro = true; W.inCombat, W.target = true, Target(); W.debuffs = { FF(), Aura( 9898, 20, 0, 30 ) }
            end },
        }

        local list = {}
        local function add( t ) for _, s in ipairs( t ) do list[ #list + 1 ] = s end end
        if H.BUILD == "31/0/20" or H.BUILD == "0/0/31" then
            add( balance )
        else
            add( caster )
            if L >= 10 then add( bear ) end
            if L >= 20 then add( cat ) end
        end
        return list
    end,
}
