-- Paladin builds and combat scenarios for tools/harness.lua.
-- Build strings are Holy/Protection/Retribution (the in-game tab order).

local BUILDS = {
    [ "11/5/35" ] = { -- Retribution (two-hander, Seal of Command)
        20266, 20261, 26573,                                             -- Holy: Divine Strength 5, Divine Intellect 5, Consecration
        20142,                                                           -- Prot: Imp. Devotion Aura 5
        20048, 20105, 25957, 20337, 20121, 20375, 26022, 20113, 20218, 20059, 20066, 26021, -- Ret: ... SoC, 2H Spec 3, Sanctity, Vengeance 5, Repentance
    },
    [ "14/32/5" ] = { -- Protection (Holy Shield, sword and board)
        20266, 20261, 26573, 20330,                                      -- Holy: DS 5, DI 5, Consecration, Imp. SoR 3
        20137, 20193, 20147, 20217, 20470, 20150, 20100, 20911, 20200, 20925, -- Prot: Redoubt 5, Precision 3, ..., BoSanc, 1H Spec 5, Holy Shield
        20105,                                                           -- Ret: Benediction 5
    },
    [ "31/0/20" ] = { -- Holy/Ret hybrid (Holy Shock); gets the Retribution priority
        20266, 20261, 20208, 26573, 20215, 20216, 25829, 20473, 20361,   -- Holy: ..., Consecration, Illumination 5, Divine Favor, Holy Power 5, Holy Shock, Lasting Judgement 3
        20048, 20105, 25957, 20121, 20375, 26023,                        -- Ret: Imp. BoM 5, Benediction 5, Imp. Judgement 2, Conviction 5, SoC, Pursuit 2
    },
    [ "0/0/0" ] = {},
}

local TWO_HANDER = { [ 16 ] = 19364 }                       -- Ashkandi, Greatsword of the Brotherhood
local SWORD_AND_BOARD = { [ 16 ] = 19019, [ 17 ] = 19349 }  -- Thunderfury + Elementium Reinforced Bulwark

local DEFAULTS = {
    ret_seal = "auto",
    judgement_debuff = "none",
    judge_main_seal = true,
    judge_mana_pct = 30,
    wisdom_mana_pct = 0,
    hammer_of_wrath = true,
    exorcism = true,
    consecration_targets = 3,
    consecration_mana_pct = 40,
    prot_consecration_single = true,
    self_blessing = "auto",
}

return {
    builds = BUILDS,
    defaultBuild = "11/5/35",

    reset = function( H )
        local W = H.W
        W.powerType, W.manaMax = 0, 6000
        W.mana = W.manaMax
        W.forms = {}
        W.equip = ( H.BUILD == "14/32/5" ) and SWORD_AND_BOARD or TWO_HANDER

        -- Settings back to their defaults for each scenario (not before login: the profile doesn't exist yet).
        local db = H.Hekili and H.Hekili.DB
        if db then
            local s = db.profile.specs[ 2 ].settings
            for k, v in pairs( DEFAULTS ) do s[ k ] = v end
            db.profile.toggles.interrupts.value = false
        end
    end,

    scenarios = function( H )
        local W, Target, Aura, CLEU, GUIDS = H.W, H.Target, H.Aura, H.CLEU, H.GUIDS
        local function Set( k, v ) H.Hekili.DB.profile.specs[ 2 ].settings[ k ] = v end

        local prot = H.BUILD == "14/32/5"
        local RF = 25780
        local SOR, SOC, SOTC, SOW = 20293, 20920, 20308, 20357
        local mainSeal = ( H.BUILD == "11/5/35" or H.BUILD == "31/0/20" ) and SOC or SOR

        -- Buffs a paladin has mid-fight: a blessing, the main seal, Righteous Fury (Protection), Holy Shield up.
        local function Buffs( seal )
            local b = { Aura( 25291, 250, 0, 300 ) }
            if seal ~= false then b[ #b + 1 ] = Aura( seal or mainSeal, 25, 0, 30 ) end
            if prot then
                b[ #b + 1 ] = Aura( RF, 1500, 0, 1800 )
                b[ #b + 1 ] = Aura( 20928, 8, 4, 10 )
            end
            return b
        end
        -- Holy Shield and Consecration on cooldown (Protection), so the rest of the priority shows.
        local function ProtBusy()
            W.cooldowns[ 20928 ] = { start = W.time, duration = 10 }
            W.cooldowns[ 20924 ] = { start = W.time, duration = 8 }
        end

        return {
            { "Out of combat, nothing up, target in range", function()
                W.target = Target()
            end },
            { "Out of combat, blessing up, no seal", function()
                W.target, W.buffs = Target(), { Aura( 25291, 250, 0, 300 ) }
                if prot then W.buffs[ 2 ] = Aura( RF, 1500, 0, 1800 ) end
            end },
            { "Out of combat, seal + blessing up (opener)", function()
                W.target, W.buffs = Target(), Buffs()
            end },
            { "Combat, single target, full mana, seal up", function()
                W.inCombat, W.target, W.buffs = true, Target(), Buffs()
            end },
            { "Combat, single target, seal just judged", function()
                W.inCombat, W.target, W.buffs = true, Target(), Buffs( false )
                W.cooldowns[ 20271 ] = { start = W.time, duration = 10 }
            end },
            { "Combat, Judgement on CD, seal up", function()
                W.inCombat, W.target, W.buffs = true, Target(), Buffs()
                W.cooldowns[ 20271 ] = { start = W.time, duration = 10 }
                if prot then ProtBusy() end
            end },
            { "Combat, target at 15% (execute)", function()
                W.inCombat, W.target, W.buffs = true, Target( 15000 ), Buffs()
                W.cooldowns[ 20271 ] = { start = W.time, duration = 10 }
                if prot then ProtBusy() end
            end },
            { "Combat, 4 enemies in melee", function()
                W.inCombat, W.target, W.buffs = true, Target(), Buffs()
                W.cooldowns[ 20271 ] = { start = W.time, duration = 10 }
                H.Plates( 3 )
            end },
            { "Combat, 2 enemies in melee", function()
                W.inCombat, W.target, W.buffs = true, Target(), Buffs()
                W.cooldowns[ 20271 ] = { start = W.time, duration = 10 }
                H.Plates( 1 )
            end },
            { "Combat, 15% mana, seal up, Judgement ready", function()
                W.inCombat, W.target, W.buffs, W.mana = true, Target(), Buffs(), 900
                if prot then ProtBusy() end
            end },
            { "Combat, 15% mana, no seal", function()
                W.inCombat, W.target, W.buffs, W.mana = true, Target(), Buffs( false ), 900
                W.cooldowns[ 20271 ] = { start = W.time, duration = 10 }
                if prot then ProtBusy() end
            end },
            { "Combat, undead target, Judgement on CD", function()
                W.inCombat, W.target, W.buffs = true, Target(), Buffs()
                W.target.creatureType = "Undead"
                W.cooldowns[ 20271 ] = { start = W.time, duration = 10 }
                if prot then ProtBusy() end
            end },
            { "Combat, target casting, interrupts toggle on", function()
                H.Hekili.DB.profile.toggles.interrupts.value = true
                W.inCombat, W.target, W.buffs = true, Target(), Buffs()
                W.target.casting = { spellID = 10, start = W.time, finish = W.time + 8, channel = true } -- Blizzard (channel): interrupt ASAP
            end },

            -- Settings.
            { "Set JotC: debuff missing, main seal up", function()
                Set( "judgement_debuff", "crusader" )
                W.inCombat, W.target, W.buffs = true, Target(), Buffs()
                if prot then ProtBusy() end
            end },
            { "Set JotC: Seal of the Crusader up", function()
                Set( "judgement_debuff", "crusader" )
                W.inCombat, W.target, W.buffs = true, Target(), Buffs( SOTC )
                if prot then ProtBusy() end
            end },
            { "Set JotC: debuff on target, no seal", function()
                Set( "judgement_debuff", "crusader" )
                W.inCombat, W.target, W.buffs = true, Target(), Buffs( false )
                W.debuffs = { Aura( 20303, 8, 0, 10 ) }
                W.cooldowns[ 20271 ] = { start = W.time, duration = 10 }
                if prot then ProtBusy() end
            end },
            { "Set JotC: out of combat, no seal", function()
                Set( "judgement_debuff", "crusader" )
                W.target, W.buffs = Target(), { Aura( 25291, 250, 0, 300 ) }
                if prot then W.buffs[ 2 ] = Aura( RF, 1500, 0, 1800 ) end
            end },
            { "Set JoW: debuff missing, main seal up", function()
                Set( "judgement_debuff", "wisdom" )
                W.inCombat, W.target, W.buffs = true, Target(), Buffs()
                if prot then ProtBusy() end
            end },
            { "Set seal Righteousness: no seal", function()
                Set( "ret_seal", "righteousness" )
                W.inCombat, W.target, W.buffs = true, Target(), Buffs( false )
                W.cooldowns[ 20271 ] = { start = W.time, duration = 10 }
                if prot then ProtBusy() end
            end },
            { "Set seal Command: no seal", function()
                Set( "ret_seal", "command" )
                W.inCombat, W.target, W.buffs = true, Target(), Buffs( false )
                W.cooldowns[ 20271 ] = { start = W.time, duration = 10 }
                if prot then ProtBusy() end
            end },
            { "Set SoW below 30%: 20% mana, no seal", function()
                Set( "wisdom_mana_pct", 30 )
                W.inCombat, W.target, W.buffs, W.mana = true, Target(), Buffs( false ), 1200
                W.cooldowns[ 20271 ] = { start = W.time, duration = 10 }
                if prot then ProtBusy() end
            end },
            { "Set SoW below 30%: 20% mana, SoW up", function()
                Set( "wisdom_mana_pct", 30 )
                W.inCombat, W.target, W.buffs, W.mana = true, Target(), Buffs( SOW ), 1200
                if prot then ProtBusy() end
            end },
            { "Set no main-seal Judgement: seal up", function()
                Set( "judge_main_seal", false )
                W.inCombat, W.target, W.buffs = true, Target(), Buffs()
                if prot then ProtBusy() end
            end },
            { "Set no Hammer of Wrath: target at 15%", function()
                Set( "hammer_of_wrath", false )
                W.inCombat, W.target, W.buffs = true, Target( 15000 ), Buffs()
                W.cooldowns[ 20271 ] = { start = W.time, duration = 10 }
                if prot then ProtBusy() end
            end },
            { "Set no Exorcism: undead target", function()
                Set( "exorcism", false )
                W.inCombat, W.target, W.buffs = true, Target(), Buffs()
                W.target.creatureType = "Undead"
                W.cooldowns[ 20271 ] = { start = W.time, duration = 10 }
                if prot then ProtBusy() end
            end },
            { "Set Consecration at 2 targets: 2 enemies", function()
                Set( "consecration_targets", 2 )
                W.inCombat, W.target, W.buffs = true, Target(), Buffs()
                W.cooldowns[ 20271 ] = { start = W.time, duration = 10 }
                H.Plates( 1 )
            end },
            { "Set Consecration 0 (off): 4 enemies", function()
                Set( "consecration_targets", 0 )
                W.inCombat, W.target, W.buffs = true, Target(), Buffs()
                W.cooldowns[ 20271 ] = { start = W.time, duration = 10 }
                H.Plates( 3 )
            end },
            { "Set Consecration mana 80%: 4 enemies, 60% mana", function()
                Set( "consecration_mana_pct", 80 )
                W.inCombat, W.target, W.buffs, W.mana = true, Target(), Buffs(), 3600
                W.cooldowns[ 20271 ] = { start = W.time, duration = 10 }
                H.Plates( 3 )
            end },
            { "Set no single-target Consecration (prot)", function()
                Set( "prot_consecration_single", false )
                W.inCombat, W.target, W.buffs = true, Target(), Buffs()
                W.cooldowns[ 20271 ] = { start = W.time, duration = 10 }
                W.cooldowns[ 20928 ] = { start = W.time, duration = 10 }
            end },
            { "Set blessing Kings: out of combat, none up", function()
                Set( "self_blessing", "kings" )
                W.target = Target()
                if prot then W.buffs = { Aura( RF, 1500, 0, 1800 ) } end
            end },
            { "Set blessing Wisdom: out of combat, none up", function()
                Set( "self_blessing", "wisdom" )
                W.target = Target()
                if prot then W.buffs = { Aura( RF, 1500, 0, 1800 ) } end
            end },
            { "Set blessing None: out of combat, none up", function()
                Set( "self_blessing", "none" )
                W.target = Target()
                if prot then W.buffs = { Aura( RF, 1500, 0, 1800 ) } end
            end },
            { "Prot: Righteous Fury missing in combat", function()
                W.inCombat, W.target, W.buffs = true, Target(), { Aura( 25291, 250, 0, 300 ), Aura( mainSeal, 25, 0, 30 ) }
            end },
        }
    end,
}
