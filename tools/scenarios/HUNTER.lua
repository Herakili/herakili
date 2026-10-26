-- Hunter builds and combat scenarios for tools/harness.lua.
-- Talent points are Beast Mastery / Marksmanship / Survival (in-game tree order).

local BUILDS = {
    [ "8/31/12" ] = { -- Marksmanship raid build
        19556, 19585,                                                    -- BM: Imp. Aspect of the Hawk 5, Endurance Training 3
        19420, 19431, 19434, 19455, 19500, 19490, 19503, 24691, 19511, 19506, -- MM: Efficiency 5, Lethal Shots 5, Aimed Shot, Imp. Arcane 2, Hawk Eye 3, Mortal Shots 5, Scatter, Barrage 3, RWS 5, Trueshot Aura
        24295, 19153, 19160, 19298, 24283,                               -- SV: Monster/Humanoid Slaying 3, Savage Strikes 2, Deflection 3, Surefooted 3
    },
    [ "31/20/0" ] = { -- Beast Mastery
        19556, 19587, 19612, 19575, 19620, 19573, 19602, 19577, 20895, 19592, 19625, 19574, -- BM: ..., Intimidation, Spirit Bond 2, Bestial Discipline 2, Frenzy 5, Bestial Wrath
        19420, 19431, 19434, 19490,                                      -- MM: Efficiency 5, Lethal Shots 5, Aimed Shot, Mortal Shots 5
    },
    [ "0/21/30" ] = { -- Survival
        19420, 19431, 19434, 19458, 19490,                               -- MM: Efficiency 5, Lethal Shots 5, Aimed Shot, Imp. Arcane 5, Mortal Shots 5
        24295, 19153, 19300, 19160, 19259, 19263, 24283, 19373, 19306, 24297, 19386, -- SV: ..., Deterrence, Surefooted 3, Killer Instinct 3, Counterattack, Lightning Reflexes 5, Wyvern Sting
    },
    [ "0/0/0" ] = {},
}

local GEAR = { [ 16 ] = 17076, [ 18 ] = 19361 }                       -- Bonereaver's Edge, Ashjre'thul (crossbow)

return {
    builds = BUILDS,
    defaultBuild = "8/31/12",

    reset = function( H )
        local W = H.W
        W.powerType, W.mana, W.manaMax = 0, 4000, 4000
        W.forms, W.stance = {}, 0
        W.equip = GEAR
        W.speed = 0
        W.baseMana = 1720 -- level-60 hunter base mana (percent costs: Bestial Wrath, Revive Pet)
        W.pet = nil
        -- reset() also runs once before the addon is loaded (H.Hekili is nil then).  Cooldowns off unless a scenario turns them on.
        local toggles = H.Hekili and H.Hekili.DB and H.Hekili.DB.profile.toggles
        if toggles then toggles.cooldowns.value = false end
        if H.LEVEL >= 10 then
            -- The first reset (at login) gets a minimal H without the helpers.
            if H.Pet then H.Pet( "Cat", "Cat" )
            else W.pet = { guid = "Pet-0-1-1-1-1-0000000099", name = "Cat", family = "Cat", health = 2000, healthMax = 2000, friendly = true } end
        end
    end,

    scenarios = function( H )
        local W, Target, Aura, CLEU, GUIDS = H.W, H.Target, H.Aura, H.CLEU, H.GUIDS
        local function Hawk() return Aura( 25296, 3000, 0, 3600 ) end
        local function CD( duration ) return { start = W.time, duration = duration } end
        local function Mark() return Aura( 14325, 100, 0, 120 ) end
        local function Ranged( health, boss )
            local t = Target( health, boss )
            t.distance = 25
            return t
        end
        -- Auto Shot fires every 2.9 s (UnitRangedDamage); the last one `ago` seconds before the scenario's final update,
        -- which is forced 3.9 s in (the scenario runs 4 s).
        local function ShotAgo( ago )
            local at = 3.9 - ago
            while at < 0.1 do at = at + 2.9 end
            H.At( 3.9, function() H.Fire( "PLAYER_TARGET_CHANGED" ) end )
            H.At( at, function() H.Cast( 75 ) end )
        end
        local function TSA() return Aura( 20906, 1500, 0, 1800 ) end
        local function Serpent() return Aura( 25295, 12, 0, 15 ) end
        -- In combat at range: Hawk + Trueshot Aura up, target Marked and Serpent Stung, Auto Shot running.
        local function Fight( mana )
            W.inCombat, W.autoRepeat, W.mana = true, true, mana or 4000
            W.target, W.buffs, W.debuffs = Ranged(), { Hawk(), TSA() }, { Mark(), Serpent() }
        end

        return {
            -- Out of combat.
            { "OOC: target at 25 yd, no aspect", function()
                W.target = Ranged()
            end },
            { "OOC: Hawk up, target at 25 yd, no Mark", function()
                W.target, W.buffs = Ranged(), { Hawk(), TSA() }
            end },
            { "OOC: Hawk up, target marked (opener)", function()
                W.target, W.buffs, W.debuffs = Ranged(), { Hawk(), TSA() }, { Mark() }
            end },
            { "OOC: no pet", function()
                W.target, W.buffs = Ranged(), { Hawk(), TSA() }
                W.pet = nil
            end },
            { "OOC: pet dead", function()
                W.target, W.buffs = Ranged(), { Hawk(), TSA() }
                if W.pet then W.pet.health = 0 end
            end },
            { "OOC: Aspect of the Cheetah up, target at 25 yd", function()
                W.target, W.buffs, W.debuffs = Ranged(), { Aura( 5118, 3000, 0, 3600 ), TSA() }, { Mark() }
            end },

            -- Single target, ranged.
            { "Combat: Auto Shot off, target at 25 yd", function()
                Fight()
                W.autoRepeat = false
            end },
            { "Combat: Auto Shot just fired", function()
                Fight(); ShotAgo( 0.1 )
            end },
            { "Combat: 1.5 s since Auto Shot", function()
                Fight(); ShotAgo( 1.5 )
            end },
            { "Combat: 1.5 s since Auto Shot, Aimed Shot clipped", function()
                H.Setting( "aimed_shot_mode", "clipped" )
                Fight(); ShotAgo( 1.5 )
            end },
            { "Combat: Auto Shot + Multi-Shot only", function()
                H.Setting( "aimed_shot_mode", "none" )
                Fight(); ShotAgo( 1.5 )
            end },
            { "Combat: shot due in 0.3 s, Aimed Shot on cd", function()
                Fight(); ShotAgo( 2.6 )
                W.cooldowns[ 20904 ] = CD( 9 )
            end },
            { "Combat: shot due in 0.3 s, no clip check", function()
                H.Setting( "multishot_clip", false )
                Fight(); ShotAgo( 2.6 )
                W.cooldowns[ 20904 ] = CD( 9 )
            end },
            { "Combat: Aimed + Multi on cd, 80% mana", function()
                Fight( 3200 ); ShotAgo( 0.5 )
                W.cooldowns[ 20904 ], W.cooldowns[ 25294 ] = CD( 9 ), CD( 12 )
            end },
            { "Combat: Aimed + Multi on cd, 30% mana", function()
                Fight( 1200 ); ShotAgo( 0.5 )
                W.cooldowns[ 20904 ], W.cooldowns[ 25294 ] = CD( 9 ), CD( 12 )
            end },
            { "Combat: 5% mana", function()
                Fight( 200 ); ShotAgo( 0.5 )
            end },
            { "Combat: moving", function()
                Fight(); ShotAgo( 0.5 )
                W.speed = 7
            end },
            { "Combat: no Hunter's Mark", function()
                Fight(); ShotAgo( 0.5 )
                W.debuffs = { Serpent() }
            end },
            { "Combat: Aspect of the Cheetah up", function()
                Fight(); ShotAgo( 0.5 )
                W.buffs = { Aura( 5118, 3000, 0, 3600 ), TSA() }
            end },
            { "Combat: Multi-Shot ST off, Aimed on cd", function()
                H.Setting( "multishot_st", false )
                Fight(); ShotAgo( 0.5 )
                W.cooldowns[ 20904 ] = CD( 9 )
            end },

            -- Serpent Sting by group type.
            { "Solo: no Serpent Sting, Aimed on cd", function()
                Fight(); ShotAgo( 0.5 ); W.debuffs = { Mark() }
                W.cooldowns[ 20904 ] = CD( 9 )
            end },
            { "Raid (25): no Serpent Sting, Aimed on cd", function()
                W.groupSize = 25
                Fight(); ShotAgo( 0.5 ); W.debuffs = { Mark() }
                W.cooldowns[ 20904 ] = CD( 9 )
            end },
            { "Raid (25), Serpent Sting 'always'", function()
                H.Setting( "serpent_sting", "always" )
                W.groupSize = 25
                Fight(); ShotAgo( 0.5 ); W.debuffs = { Mark() }
                W.cooldowns[ 20904 ] = CD( 9 )
            end },

            -- Cooldowns.
            { "Boss: cooldowns ready (toggle on)", function()
                Fight(); ShotAgo( 0.5 )
                W.target = Ranged( 1000000, true )
                H.Hekili.DB.profile.toggles.cooldowns.value = true
            end },

            -- AoE.
            { "AoE: 3 enemies hit", function()
                Fight(); ShotAgo( 1.0 )
                for i = 1, 3 do
                    CLEU( "SPELL_DAMAGE", GUIDS.player, "Creature-0-1-1-1-1234-000000000" .. i, 25294, "Multi-Shot", 1, 300, -1, 1, 0, 0, 0, false, false )
                end
            end },
            { "AoE: 5 enemies hit, Multi-Shot on cd", function()
                Fight(); ShotAgo( 1.0 )
                W.cooldowns[ 25294 ] = CD( 12 )
                for i = 1, 5 do
                    CLEU( "SPELL_DAMAGE", GUIDS.player, "Creature-0-1-1-1-1234-000000000" .. i, 25294, "Multi-Shot", 1, 300, -1, 1, 0, 0, 0, false, false )
                end
            end },

            -- Melee range.
            { "Melee: target in melee range", function()
                Fight()
                W.target = Target()
            end },
            { "Melee: just dodged", function()
                Fight()
                W.target = Target()
                CLEU( "SWING_MISSED", W.target.guid, GUIDS.player, "DODGE", false, 0 )
            end },
            { "Melee: Raptor Strike on cd", function()
                Fight()
                W.target = Target()
                W.cooldowns[ 14266 ] = CD( 9 )
            end },
            { "Melee: boss, Raptor Strike on cd", function()
                Fight()
                W.target = Target( 1000000, true )
                W.cooldowns[ 14266 ] = CD( 9 )
            end },
            { "Melee: just parried (Survival: Counterattack)", function()
                Fight()
                W.target = Target()
                W.cooldowns[ 14266 ] = CD( 9 )
                CLEU( "SWING_MISSED", W.target.guid, GUIDS.player, "PARRY", false, 0 )
            end },

            -- Pet.
            { "Combat: no pet", function()
                Fight(); ShotAgo( 0.5 )
                W.pet = nil
            end },
            { "Combat: pet dead", function()
                Fight(); ShotAgo( 0.5 )
                if W.pet then W.pet.health = 0 end
            end },
            { "Combat: pet dead, revive in combat on", function()
                H.Setting( "revive_in_combat", true )
                Fight(); ShotAgo( 0.5 )
                if W.pet then W.pet.health = 0 end
            end },
            { "Combat: pet at 25% health", function()
                Fight(); ShotAgo( 0.5 )
                if W.pet then W.pet.health = 500 end
            end },
            { "Combat: pet at 25%, Mend Pet off", function()
                H.Setting( "mend_pet_health", 0 )
                Fight(); ShotAgo( 0.5 )
                if W.pet then W.pet.health = 500 end
            end },
        }
    end,
}
