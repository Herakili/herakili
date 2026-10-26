-- Priest builds and combat scenarios for tools/harness.lua.
-- Racials: run with HARNESS_RACE=Undead (Devouring Plague, Touch of Weakness), NightElf (Starshards) or Troll
-- (Berserking, Shadowguard); the default is Human.

local BUILDS = {
    [ "13/0/38" ] = { -- Shadow (raid / leveling end game)
        14528, 14769, 14767, 14751, 14776,                               -- Disc: Wand Spec 5, Imp. PW:S 3, Imp. PW:F 2, Inner Focus, Meditation 2
        15338, 15320, 15317, 15330, 15316, 15407, 15274, 17325, 15334,   -- Shadow: Spirit Tap 5, Affinity 3, Imp. SW:P 2, Focus 5, Imp. MB 5, MF, Imp. Fade 1, Reach 3, Weaving 5
        15487, 15286, 15310, 15473,                                      -- Silence, Vampiric Embrace, Darkness 5, Shadowform
    },
    [ "20/31/0" ] = { -- Holy (raid healer; damage priority without Shadowform)
        14528, 14769, 14767, 14751, 14777, 14783, 14747,                 -- Disc: Wand Spec 5, Imp. PW:S 3, Imp. PW:F 2, IF, Meditation 3, Mental Agility 5, Imp. IF 1
        15011, 18535, 15237, 15363, 15014, 15017, 15031, 20711, 15356, 724, -- Holy: Spec 5, Divine Fury 5, Holy Nova, Inspiration 3, Imp. Healing 3, Searing Light 2, SG 5, SoR, SH 5, Lightwell
    },
    [ "31/20/0" ] = { -- Discipline (Power Infusion)
        14528, 14769, 14767, 14751, 14777, 14783, 14771, 18555, 14752, 18547, 10060, -- Disc: ..., Imp. Inner Fire 3, Mental Strength 5, Divine Spirit, Force of Will 2, PI
        15011, 18535, 15237, 15363, 15014, 15017, 14913,                 -- Holy: Spec 5, Divine Fury 5, Holy Nova, Inspiration 3, Imp. Healing 3, Searing Light 2, Healing Focus 1
    },
    [ "0/0/0" ] = {},
}

-- Hekili derives base mana from max mana minus intellect (the harness reports 300 intellect = 4220 mana).
local function BaseMana( level ) return 4220 + math.floor( 1400 * level / 60 ) end

return {
    builds = BUILDS,
    defaultBuild = "13/0/38",

    reset = function( H )
        local W = H.W
        W.powerType = 0
        W.baseMana = math.floor( 1436 * H.LEVEL / 60 )                    -- Shadowform costs 40% of base mana
        W.manaMax = BaseMana( H.LEVEL ) + 3000
        W.mana = W.manaMax
        -- Shadowform (talent) is the priest's only shapeshift form; start in it when the build has it.
        if H.BUILD == "13/0/38" and H.LEVEL >= 40 then
            W.forms, W.stance = { 15473 }, 1
        else
            W.forms, W.stance = {}, 0
        end
        W.equip = { [ 18 ] = H.LEVEL >= 60 and 19861 or 5240 }           -- Touch of Chaos / Torchlight Wand
        -- Cooldowns toggle off (the default); some scenarios turn it on.
        if H.Hekili and H.Hekili.DB then H.Hekili.DB.profile.toggles.cooldowns.value = false end
    end,

    scenarios = function( H )
        local W, Target, Aura = H.W, H.Target, H.Aura
        -- Scenarios tick 4 seconds before the display is read: add 4 to remaining times.
        local T = 4
        local function InnerFire() return Aura( 10952, 500, 0, 600 ) end
        local function SWP( remaining ) return Aura( 10894, ( remaining or 15 ) + T, 0, 24 ) end
        local function Weaving( remaining, stacks ) return Aura( 15258, ( remaining or 12 ) + T, stacks or 5, 15 ) end
        -- Mind Blast's cooldown is set on every rank (the harness answers GetSpellCooldown per rank ID).
        local MB_RANKS = { 8092, 8102, 8103, 8104, 8105, 8106, 10945, 10946, 10947 }
        local function CD( id, remaining )
            for _, r in ipairs( id == 10947 and MB_RANKS or { id } ) do W.cooldowns[ r ] = { start = W.time, duration = remaining + T } end
        end
        local function Combat( mana )
            W.inCombat, W.target, W.buffs = true, Target(), { InnerFire() }
            if mana then W.mana = math.floor( W.manaMax * mana / 100 ) end
        end
        -- A Mind Flay channel that is 1 second (one tick) in when the display is read.
        local function Flaying()
            W.casting = { spellID = 18807, start = W.time + T - 1, finish = W.time + T + 2, channel = true }
            table.insert( W.debuffs, Aura( 18807, T + 2, 0, 3 ) )
        end

        return {
            { "Out of combat, target, no Inner Fire", function()
                W.target = Target()
            end },
            { "Out of combat, target, buffed (pull)", function()
                W.target, W.buffs = Target(), { InnerFire() }
            end },
            { "Combat, fresh target, no DoTs, no Weaving", function()
                Combat()
            end },
            { "Combat, fresh target, 5 Weaving (other priest)", function()
                Combat()
                W.debuffs = { Weaving() }
            end },
            { "Combat, SW:P + Weaving up, MB ready, IF on cd", function()
                Combat()
                W.debuffs = { SWP(), Weaving() }
                CD( 14751, 120 )
            end },
            { "Combat, SW:P + Weaving up, MB on cooldown", function()
                Combat()
                W.debuffs = { SWP(), Weaving() }
                CD( 10947, 4 ); CD( 14751, 120 )
            end },
            { "Mid Mind Flay, MB on cooldown 4s", function()
                Combat()
                W.debuffs = { SWP(), Weaving() }
                CD( 10947, 4 ); CD( 14751, 120 )
                Flaying()
            end },
            { "Mid Mind Flay, MB ready", function()
                Combat()
                W.debuffs = { SWP(), Weaving() }
                CD( 10947, -0.1 ); CD( 14751, 120 )
                Flaying()
            end },
            { "Mid Mind Flay, MB ready, clipping off", function()
                H.Setting( "mind_blast_clip", false )
                Combat()
                W.debuffs = { SWP(), Weaving() }
                CD( 14751, 120 )
                Flaying()
            end },
            { "Mid Mind Flay, SW:P fell off", function()
                Combat()
                W.debuffs = { Weaving() }
                CD( 10947, 4 ); CD( 14751, 120 )
                Flaying()
            end },
            { "Combat, out of Shadowform", function()
                Combat()
                W.stance = 0
                W.debuffs = { SWP(), Weaving() }
            end },
            { "Low mana 10%, SW:P up, MB ready, IF on cd", function()
                Combat( 10 )
                W.debuffs = { SWP(), Weaving() }
                CD( 14751, 120 )
            end },
            { "Low mana 10%, SW:P down", function()
                Combat( 10 )
                W.debuffs = { Weaving() }
                CD( 14751, 120 )
            end },
            { "Low mana 10%, already wanding", function()
                Combat( 10 )
                W.debuffs = { SWP(), Weaving() }
                W.autoRepeat = true
                CD( 14751, 120 ); CD( 10947, 3 )
            end },
            { "Low mana 10%, Inner Focus + MB ready", function()
                Combat( 10 )
                W.debuffs = { SWP(), Weaving() }
            end },
            { "Low mana 10%, party, Weaving 2s left", function()
                Combat( 10 )
                W.groupSize = 5
                W.debuffs = { SWP(), Weaving( 2 ), Aura( 15286, 50, 0, 60 ) }
                CD( 14751, 120 )
            end },
            { "Low mana 10%, wand threshold 0", function()
                H.Setting( "wand_mana_pct", 0 )
                Combat( 10 )
                W.debuffs = { SWP(), Weaving() }
                CD( 14751, 120 ); CD( 10947, 4 )
            end },
            { "Party (5), no Vampiric Embrace", function()
                Combat()
                W.groupSize = 5
                W.debuffs = { SWP(), Weaving() }
            end },
            { "Solo, Vampiric Embrace = always", function()
                H.Setting( "vampiric_embrace", "always" )
                Combat()
                W.debuffs = { SWP(), Weaving() }
                CD( 14751, 120 ); CD( 10947, 4 )
            end },
            { "Raid (25), VE = in raids, SW:P up", function()
                H.Setting( "vampiric_embrace", "raid" )
                Combat()
                W.groupSize = 25
                W.debuffs = { SWP(), Weaving() }
                CD( 14751, 120 ); CD( 10947, 4 )
            end },
            { "Inner Focus setting off, MB ready", function()
                H.Setting( "inner_focus_mind_blast", false )
                Combat()
                W.debuffs = { SWP(), Weaving() }
            end },
            { "Smite filler off (no Mind Flay builds)", function()
                H.Setting( "smite_filler", false )
                Combat()
                W.debuffs = { SWP(), Weaving(), Aura( 15261, 8 + T, 0, 10 ) }
                CD( 14751, 120 ); CD( 10947, 4 )
            end },
            { "AoE: 4 enemies, SW:P on target", function()
                Combat()
                W.debuffs = { SWP(), Weaving() }
                CD( 14751, 120 ); CD( 10947, 4 )
                H.Plates( 3 )
            end },
            { "AoE: 4 enemies, SW:P spreading off", function()
                H.Setting( "swp_multidot", false )
                Combat()
                W.debuffs = { SWP(), Weaving() }
                CD( 14751, 120 ); CD( 10947, 4 )
                H.Plates( 3 )
            end },
            { "AoE: 4 enemies, Holy Nova threshold 0", function()
                H.Setting( "holy_nova_targets", 0 )
                Combat()
                W.debuffs = { SWP(), Weaving() }
                CD( 14751, 120 ); CD( 10947, 4 )
                H.Plates( 3 )
            end },
            { "Cooldowns toggle on, SW:P up, MB on cooldown", function()
                H.Hekili.DB.profile.toggles.cooldowns.value = true
                Combat()
                W.debuffs = { SWP(), Weaving() }
                CD( 14751, 120 ); CD( 10947, 4 )
            end },
            { "Cooldowns on, Power Infusion on self enabled", function()
                H.Setting( "power_infusion_self", true )
                H.Hekili.DB.profile.toggles.cooldowns.value = true
                Combat()
                W.debuffs = { SWP(), Weaving() }
                CD( 14751, 120 ); CD( 10947, 4 )
            end },
            { "Combat, target dying (5% hp)", function()
                Combat()
                W.target = Target( 5000 )
                W.debuffs = { Weaving() }
                CD( 14751, 120 ); CD( 10947, 4 )
            end },
        }
    end,
}
