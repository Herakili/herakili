-- Mage builds and combat scenarios for tools/harness.lua.  Talent tabs: 1 Arcane, 2 Fire, 3 Frost.

local BUILDS = {
    [ "10/0/41" ] = { -- Frost (raid / leveling): Winter's Chill, Ice Barrier
        12592, 12840, 12577,                                            -- Arcane: Subtlety 2, Focus 3, Arcane Concentration 5
        16766, 29440, 15053, 11165, 12953, 12472, 12488, 16758, 12519, 12985, 11958, 12490, 28595, 11426, -- Frost
    },
    [ "0/34/17" ] = { -- Fire: Improved Scorch, Pyroblast, Blast Wave, Combustion
        12341, 12848, 12353, 18460, 12350, 11366, 12873, 29076, 11368, 11113, 12400, 11129, -- Fire
        16766, 29440, 15053, 12953, 12472,                              -- Frost: Imp. Frostbolt 5, Precision 3, Ice Shards 5, Piercing Ice 3, Cold Snap
    },
    [ "31/0/20" ] = { -- Arcane Power / Frost
        12592, 12842, 12577, 12469, 18464, 12043, 12503, 15060, 12042, 12606, 11255, -- Arcane: ..., PoM, Arcane Mind 5, AI 3, AP
        16766, 29440, 15053, 12953, 12472, 12519,                       -- Frost: ..., Cold Snap, Frost Channeling 3
    },
    [ "0/0/0" ] = {},
}

local WAND = 11287 -- Lesser Magic Wand
local GEMS = { 8008, 8007, 5513, 5514 } -- Mana Ruby, Citrine, Jade, Agate

return {
    builds = BUILDS,
    defaultBuild = "10/0/41",

    reset = function( H )
        local W = H.W
        W.powerType = 0
        W.manaMax = H.LEVEL >= 60 and 7000 or ( 100 + 60 * H.LEVEL )
        W.mana = W.manaMax
        W.equip = { [ 16 ] = 19356, [ 18 ] = WAND } -- Staff of the Shadow Flame, wand
        W.itemCounts = {}
        for _, gem in ipairs( GEMS ) do W.itemCounts[ gem ] = 1 end
        -- reset() also runs once before the addon is loaded (H.Hekili is nil then).
        local toggles = H.Hekili and H.Hekili.DB and H.Hekili.DB.profile.toggles
        if toggles then
            toggles.cooldowns.value, toggles.defensives.value, toggles.interrupts.value = true, true, true
        end
    end,

    scenarios = function( H )
        local W, Target, Aura, CLEU, GUIDS = H.W, H.Target, H.Aura, H.CLEU, H.GUIDS
        -- Mage Armor (or Frost Armor below level 34), Arcane Intellect, Ice Barrier.
        local function Buffed( extra )
            local b = { Aura( H.LEVEL >= 34 and 22783 or 7301, 1500, 0, 1800 ), Aura( H.LEVEL >= 56 and 10157 or 1460, 1500, 0, 1800 ),
                Aura( 13033, 50, 0, 60 ) }
            for _, a in ipairs( extra or {} ) do b[ #b + 1 ] = a end
            return b
        end
        local function Fight( extra )
            W.inCombat, W.target, W.buffs = true, Target(), Buffed( extra )
        end
        -- A spell (or every rank of one, so it holds at any level) on cooldown.
        local function OnCooldown( id, remaining, duration )
            for _, x in ipairs( type( id ) == "table" and id or { id } ) do
                W.cooldowns[ x ] = { start = W.time - ( duration - remaining ), duration = duration }
            end
        end
        -- The client tables also list Season of Discovery copies of Fire Blast (400616-400623) on the skill line; the
        -- harness may resolve "Fire Blast" to one of them, so they go on cooldown too.
        local FIRE_BLAST = { 2136, 2137, 2138, 8412, 8413, 10197, 10199, 400616, 400618, 400619, 400620, 400621, 400622, 400623 }
        local FROST_NOVA = { 122, 865, 6131, 10230 }
        local CONE_OF_COLD = { 120, 8492, 10159, 10160, 10161 }
        local BLAST_WAVE = { 11113, 13018, 13019, 13020, 13021 }
        local ICE_BARRIER = { 11426, 13031, 13032, 13033 }
        local function NoCooldowns()
            OnCooldown( 12042, 150, 180 ) -- Arcane Power
            OnCooldown( 12043, 150, 180 ) -- Presence of Mind
            OnCooldown( 11129, 150, 180 ) -- Combustion
        end
        -- Enemies hit by an AoE spell at range (damage-based target detection).
        -- Nameplates out of nameplateRange are authoritative (Hekili then ignores damage hits on them), so this models
        -- enemy nameplates switched off.
        local function RangedPack( n, spellID, name )
            W.cvars.nameplateShowEnemies = "0"
            W.target.distance = 25
            H.Plates( n - 1 )
            for i, p in ipairs( W.plates ) do p.distance = 25 end
            local guids = { W.target.guid }
            for i = 1, n - 1 do guids[ #guids + 1 ] = W.plates[ i ].guid end
            for _, guid in ipairs( guids ) do
                W.cleu = { n = 23, W.time, "SPELL_DAMAGE", false, GUIDS.player, "Tester", 0x511, 0,
                    guid, "Mob", 0xa48, 0, spellID, name, 16, 300, -1, 16, 0, 0, 0, false, false }
                H.Fire( "COMBAT_LOG_EVENT_UNFILTERED" )
                W.cleu = nil
            end
        end

        return {
            -- Out of combat.
            { "Out of combat, unbuffed, target", function()
                W.target = Target()
            end },
            { "Out of combat, Ice Armor setting, armor missing", function()
                H.Setting( "armor", "ice" )
                W.target, W.buffs = Target(), { Aura( 10157, 1500, 0, 1800 ) }
            end },
            { "Out of combat, buffed, no mana gems", function()
                W.target, W.buffs = Target(), Buffed()
                W.itemCounts = {}
            end },
            { "Out of combat, buffed, gems, Ice Barrier down", function()
                W.target, W.buffs = Target(), { Aura( 22783, 1500, 0, 1800 ), Aura( 10157, 1500, 0, 1800 ) }
            end },
            { "Out of combat, buffed, gems (opener)", function()
                W.target, W.buffs = Target(), Buffed()
            end },
            { "Out of combat, opener, Pyroblast opener off", function()
                H.Setting( "pyroblast_opener", false )
                W.target, W.buffs = Target(), Buffed()
            end },

            -- Single target.
            { "Combat, full mana, single target", function()
                Fight()
            end },
            { "Combat, single target, cooldowns used", function()
                Fight()
                NoCooldowns()
            end },
            { "Combat, single target, Cooldowns toggle off", function()
                Fight()
                H.Hekili.DB.profile.toggles.cooldowns.value = false
            end },
            { "Combat, moving, single target", function()
                Fight()
                NoCooldowns()
                W.speed = 7
            end },
            { "Combat, moving, Fire Blast on cooldown, target 25 yd", function()
                Fight()
                NoCooldowns()
                W.speed, W.target.distance = 7, 25
                OnCooldown( FIRE_BLAST, 7.5, 8 )
            end },
            { "Combat, target casting (Counterspell)", function()
                Fight()
                NoCooldowns()
                W.target.casting = { spellID = 10, start = W.time, finish = W.time + 8, channel = true } -- Blizzard: interrupt ASAP
            end },
            { "Combat, 10% health", function()
                Fight()
                NoCooldowns()
                W.health = 400
            end },
            { "Combat, Ice Barrier down and on cooldown", function()
                W.inCombat, W.target = true, Target()
                W.buffs = { Aura( 22783, 1500, 0, 1800 ), Aura( 10157, 1500, 0, 1800 ) }
                NoCooldowns()
                OnCooldown( ICE_BARRIER, 25, 30 )
            end },

            -- Fire: Improved Scorch.
            { "Fire: no Fire Vulnerability", function()
                Fight()
                NoCooldowns()
            end },
            { "Fire: 3 Fire Vulnerability stacks", function()
                Fight()
                NoCooldowns()
                W.debuffs = { Aura( 22959, 25, 3, 30 ) }
            end },
            { "Fire: 5 stacks, 20 s left", function()
                Fight()
                NoCooldowns()
                W.debuffs = { Aura( 22959, 24, 5, 30 ) }
            end },
            { "Fire: 5 stacks, about to drop", function()
                Fight()
                NoCooldowns()
                W.debuffs = { Aura( 22959, 7, 5, 30 ) }
            end },
            { "Fire: no stacks, Scorch stacks setting off", function()
                H.Setting( "scorch_stacks", false )
                Fight()
                NoCooldowns()
            end },
            { "Fire: 5 stacks, 30% mana (no Fire Blast weave)", function()
                Fight()
                NoCooldowns()
                W.debuffs = { Aura( 22959, 24, 5, 30 ) }
                W.mana = 0.3 * W.manaMax
                W.itemCounts = {}
            end },

            -- Arcane.
            { "Clearcasting up", function()
                Fight( { Aura( 12536, 10, 0, 15 ) } )
                NoCooldowns()
            end },
            { "Clearcasting up, Missiles on Clearcasting off", function()
                H.Setting( "clearcasting_missiles", false )
                Fight( { Aura( 12536, 10, 0, 15 ) } )
                NoCooldowns()
            end },
            { "Arcane main nuke setting: Fireball", function()
                H.Setting( "arcane_nuke", "fireball" )
                Fight()
                NoCooldowns()
            end },
            { "Arcane Power up, Presence of Mind ready", function()
                Fight( { Aura( 12042, 12, 0, 15 ) } )
                OnCooldown( 12042, 168, 180 )
                OnCooldown( 11129, 150, 180 )
            end },

            -- AoE.
            { "AoE: 3 enemies on you", function()
                Fight()
                NoCooldowns()
                H.Plates( 2 )
            end },
            { "AoE: 6 enemies on you", function()
                Fight()
                NoCooldowns()
                H.Plates( 5 )
            end },
            { "AoE: 6 enemies on you, Frost Nova and CoC on cd", function()
                Fight()
                NoCooldowns()
                H.Plates( 5 )
                OnCooldown( FROST_NOVA, 15, 25 )
                OnCooldown( CONE_OF_COLD, 6, 10 )
                OnCooldown( BLAST_WAVE, 30, 45 )
                OnCooldown( 12472, 300, 600 )
            end },
            { "AoE: 6 enemies on you, frozen", function()
                Fight()
                NoCooldowns()
                H.Plates( 5 )
                W.debuffs = { Aura( 10230, 6, 0, 8 ) }
                OnCooldown( FROST_NOVA, 20, 25 )
                OnCooldown( BLAST_WAVE, 30, 45 )
            end },
            { "AoE: 6 enemies on you, Frost Nova setting off", function()
                H.Setting( "aoe_frost_nova", false )
                Fight()
                NoCooldowns()
                H.Plates( 5 )
                OnCooldown( BLAST_WAVE, 30, 45 )
            end },
            { "AoE: 4 enemies at range (Blizzard hits)", function()
                Fight()
                NoCooldowns()
                RangedPack( 4, 10187, "Blizzard" )
            end },
            { "AoE: 7 enemies at range (Blizzard hits)", function()
                Fight()
                NoCooldowns()
                RangedPack( 7, 10187, "Blizzard" )
            end },

            -- Mana.
            { "Combat, 50% mana, mana gems", function()
                Fight()
                NoCooldowns()
                W.mana = 0.5 * W.manaMax
            end },
            { "Combat, 80% mana, mana gems", function()
                Fight()
                NoCooldowns()
                W.mana = 0.8 * W.manaMax
            end },
            { "Combat, 12% mana, no gems, Evocation ready", function()
                Fight()
                NoCooldowns()
                W.mana = 0.12 * W.manaMax
                W.itemCounts = {}
            end },
            { "Combat, 8% mana, no gems, Evocation on cd", function()
                Fight()
                NoCooldowns()
                W.mana = 0.08 * W.manaMax
                W.itemCounts = {}
                OnCooldown( 12051, 300, 480 )
            end },
            { "Combat, 8% mana, already wanding", function()
                Fight()
                NoCooldowns()
                W.mana = 0.08 * W.manaMax
                W.itemCounts = {}
                W.autoRepeat = true
                OnCooldown( 12051, 300, 480 )
            end },
            { "Combat, 15% mana, wanding, target 25 yd", function()
                Fight()
                NoCooldowns()
                W.target.distance = 25
                W.mana = 0.15 * W.manaMax
                W.itemCounts = {}
                W.autoRepeat = true
                OnCooldown( 12051, 300, 480 )
            end },
            { "Combat, 25% mana, wanding (back to spells)", function()
                Fight()
                NoCooldowns()
                W.mana = 0.25 * W.manaMax
                W.itemCounts = {}
                W.autoRepeat = true
                OnCooldown( 12051, 300, 480 )
            end },
            { "AoE: 6 enemies on you, moving, Frost Nova on cd", function()
                Fight()
                NoCooldowns()
                H.Plates( 5 )
                W.speed = 7
                OnCooldown( FROST_NOVA, 15, 25 )
                OnCooldown( BLAST_WAVE, 30, 45 )
            end },
            { "Combat, 8% mana, wand setting 0", function()
                H.Setting( "wand_mana_pct", 0 )
                Fight()
                NoCooldowns()
                W.mana = 0.08 * W.manaMax
                W.itemCounts = {}
                OnCooldown( 12051, 300, 480 )
            end },
        }
    end,
}
