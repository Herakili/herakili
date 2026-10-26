-- Shaman builds and combat scenarios for tools/harness.lua.
-- Talent trees in points strings: Elemental / Enhancement / Restoration.

local BUILDS = {
    [ "31/0/20" ] = { -- Elemental (raid): Elemental Mastery + Nature's Swiftness
        16112, 16108, 16164, 16116, 16120, 29065, 16089, 16582, 16166,  -- Convection 5, Concussion 5, EF, Reverb 5, CoT 5, EotS 3, EFury, LM 5, EM
        16217, 16225, 16198, 16221, 16188, 16184,                       -- Tidal Focus 5, Totemic Focus 5, NG 3, Tidal Mastery 5, NS, Imp. Reinc 1
    },
    [ "21/30/0" ] = { -- Enhancement (two-hander): Stormstrike
        16112, 16108, 16161, 16164, 16116, 29179,                       -- Convection 5, Concussion 5, CoF 3, EF, Reverb 5, Ele Dev 2
        17489, 16305, 16295, 16269, 16284, 29080, 29193, 29088, 17364, 16254, -- AK 5, TS 5, ET 2, 2H 1, Flurry 5, EW 3, IWT 2, WM 5, SS, Antic. 1
    },
    [ "0/5/46" ] = { -- Restoration (healer): gets the Elemental priority
        17489,                                                          -- Ancestral Knowledge 5
        16229, 16217, 16240, 16225, 16198, 16234, 16189, 29191, 16208, 16221, 16188, 16213, 16190, -- ... NS, Purification 5, Mana Tide
    },
    [ "0/0/0" ] = {},
}

local ENH_GEAR = { [ 16 ] = 17073 }                   -- Earthshaker (two-handed mace)
local ELE_GEAR = { [ 16 ] = 17105, [ 17 ] = 17106 }   -- Aurastone Hammer + Malistar's Defender (shield)

-- Temporary enchant IDs (GetWeaponEnchantInfo): Windfury 4, Rockbiter 7, Flametongue 6.
local WINDFURY, ROCKBITER, FLAMETONGUE = 1669, 1664, 1666

return {
    builds = BUILDS,
    defaultBuild = "21/30/0",

    reset = function( H )
        local W = H.W
        W.powerType, W.mana, W.manaMax, W.baseMana = 0, 4000, 4000, 1240
        W.forms, W.stance = {}, 0
        -- Cooldowns toggle off unless a scenario turns it on.
        if H.Hekili and H.Hekili.DB then H.Hekili.DB.profile.toggles.cooldowns.value = false end
        W.equip = ( H.BUILD == "21/30/0" or H.BUILD == "0/0/0" ) and ENH_GEAR or ELE_GEAR
    end,

    scenarios = function( H )
        local W, Target, Aura, Setting = H.W, H.Target, H.Aura, H.Setting
        local ELE = H.BUILD ~= "21/30/0" and H.BUILD ~= "0/0/0"

        local function LS() return Aura( 10432, 500, 3, 600 ) end
        local function Imbue( id, remaining ) W.enchants.mh = { id = id or WINDFURY, remaining = remaining or 250 } end
        local function Totem( slot, name, remaining, duration )
            W.totems[ slot ] = { name = name, remaining = remaining or 100, duration = duration or 120 }
        end
        local function AllTotems()
            if ELE then
                Totem( 3, "Mana Spring Totem IV", 50, 60 )
                Totem( 1, "Searing Totem VI", 40, 55 )
            else
                Totem( 4, "Windfury Totem III" )
                Totem( 2, "Strength of Earth Totem V" )
                Totem( 3, "Mana Spring Totem IV", 50, 60 )
                Totem( 1, "Searing Totem VI", 40, 55 )
            end
        end
        local function ShockCD( remaining )
            for _, id in ipairs( { 10414, 29228, 10473 } ) do W.cooldowns[ id ] = { start = W.time - ( 6 - remaining ), duration = 6 } end
        end
        local function Ready()
            W.inCombat, W.target, W.buffs = true, Target(), { LS() }
            if not ELE then Imbue() end
            AllTotems()
        end

        if ELE then return {
            { "Out of combat, target in range", function()
                W.target, W.buffs = Target(), { LS() }
            end },
            { "Out of combat, no Lightning Shield", function()
                W.target = Target()
            end },
            { "Combat, no totems", function()
                W.inCombat, W.target, W.buffs = true, Target(), { LS() }
            end },
            { "Combat, totems up, everything ready (cooldowns on)", function()
                Ready()
                H.Hekili.DB.profile.toggles.cooldowns.value = true
            end },
            { "Combat, EM up, CL ready", function()
                Ready()
                W.buffs[ #W.buffs + 1 ] = Aura( 16166, 3600, 0, 3600 )
                W.cooldowns[ 16166 ] = { start = W.time - 1, duration = 180 }
            end },
            { "Combat, Elemental Mastery on cooldown", function()
                Ready()
                W.cooldowns[ 16166 ] = { start = W.time - 30, duration = 180 }
            end },
            { "Combat, EM + Chain Lightning on cooldown, no Flame Shock", function()
                Ready()
                W.cooldowns[ 16166 ] = { start = W.time - 30, duration = 180 }
                W.cooldowns[ 10605 ] = { start = W.time - 1, duration = 6 }
            end },
            { "Combat, EM/CL on cooldown, Flame Shock ticking", function()
                Ready()
                W.cooldowns[ 16166 ] = { start = W.time - 30, duration = 180 }
                W.cooldowns[ 10605 ] = { start = W.time - 1, duration = 6 }
                W.debuffs = { Aura( 29228, 10, 0, 12 ) }
            end },
            { "Combat, 45% mana (no single-target CL)", function()
                Ready()
                W.mana = 1800
                W.cooldowns[ 16166 ] = { start = W.time - 30, duration = 180 }
            end },
            { "Combat, 20% mana (low mana)", function()
                Ready()
                W.mana = 800
                W.cooldowns[ 16166 ] = { start = W.time - 30, duration = 180 }
            end },
            { "Combat, 20% mana, Clearcasting", function()
                Ready()
                W.mana = 800
                W.buffs[ #W.buffs + 1 ] = Aura( 16246, 12, 0, 15 )
                W.cooldowns[ 16166 ] = { start = W.time - 30, duration = 180 }
            end },
            { "Combat, 3 enemies (AoE)", function()
                Ready()
                W.cooldowns[ 16166 ] = { start = W.time - 30, duration = 180 }
                H.Plates( 2 )
            end },
            { "Combat, 3 enemies, Fire Nova gone off (on cooldown)", function()
                Ready()
                W.cooldowns[ 16166 ] = { start = W.time - 30, duration = 180 }
                W.cooldowns[ 11315 ] = { start = W.time - 6, duration = 15 }
                W.cooldowns[ 10605 ] = { start = W.time - 1, duration = 6 }
                W.totems[ 1 ] = nil
                H.Plates( 2 )
            end },
            { "Combat, 3 enemies, setting: no AoE totems", function()
                Ready()
                Setting( "aoe_totems", false )
                W.cooldowns[ 16166 ] = { start = W.time - 30, duration = 180 }
                W.cooldowns[ 10605 ] = { start = W.time - 1, duration = 6 }
                H.Plates( 2 )
            end },
            { "Combat, setting: Earth Shock on, Flame Shock ticking", function()
                Ready()
                Setting( "ele_earth_shock", true )
                W.cooldowns[ 16166 ] = { start = W.time - 30, duration = 180 }
                W.cooldowns[ 10605 ] = { start = W.time - 1, duration = 6 }
                W.debuffs = { Aura( 29228, 10, 0, 12 ) }
            end },
            { "Combat, setting: Flame Shock off", function()
                Ready()
                Setting( "ele_flame_shock", false )
                W.cooldowns[ 16166 ] = { start = W.time - 30, duration = 180 }
                W.cooldowns[ 10605 ] = { start = W.time - 1, duration = 6 }
            end },
            { "Combat, setting: CL mana 100 (CL for AoE only)", function()
                Ready()
                Setting( "ele_cl_mana", 100 )
                W.mana = 3600
                W.cooldowns[ 16166 ] = { start = W.time - 30, duration = 180 }
                W.debuffs = { Aura( 29228, 10, 0, 12 ) }
            end },
            { "Out of combat, setting: Flametongue imbue, none on", function()
                Setting( "ele_imbue", "flametongue_weapon" )
                W.target, W.buffs = Target(), { LS() }
            end },
            { "Out of combat, setting: totems before combat", function()
                Setting( "totems_precombat", true )
                W.target, W.buffs = Target(), { LS() }
            end },
            { "Combat, setting: Lightning Shield off, LS down", function()
                Ready()
                Setting( "lightning_shield", false )
                W.buffs = {}
                W.cooldowns[ 16166 ] = { start = W.time - 30, duration = 180 }
                W.debuffs = { Aura( 29228, 10, 0, 12 ) }
                W.cooldowns[ 10605 ] = { start = W.time - 1, duration = 6 }
            end },
        } end

        return {
            { "Out of combat, no imbue, no Lightning Shield", function()
                W.target = Target()
            end },
            { "Out of combat, Windfury imbue 30 s left", function()
                W.target, W.buffs = Target(), { LS() }
                Imbue( WINDFURY, 30 )
            end },
            { "Out of combat, imbue + LS up, target 20 yd", function()
                W.target, W.buffs = Target(), { LS() }
                Imbue()
                W.target.distance = 20
            end },
            { "Raid, out of combat, target 20 yd (no LB pull)", function()
                W.groupSize, W.target, W.buffs = 25, Target(), { LS() }
                Imbue()
                W.target.distance = 20
            end },
            { "Combat, imbue missing", function()
                Ready()
                W.enchants.mh = nil
            end },
            { "Combat, no totems", function()
                W.inCombat, W.target, W.buffs = true, Target(), { LS() }
                Imbue()
            end },
            { "Combat, Windfury Totem up, no earth/water/fire", function()
                W.inCombat, W.target, W.buffs = true, Target(), { LS() }
                Imbue()
                Totem( 4, "Windfury Totem III" )
            end },
            { "Combat, totems up, Stormstrike ready", function()
                Ready()
            end },
            { "Combat, Stormstrike debuff up (just used)", function()
                Ready()
                W.cooldowns[ 17364 ] = { start = W.time - 1, duration = 20 }
                W.debuffs = { Aura( 17364, 11, 2, 12 ) }
            end },
            { "Combat, SS on cooldown 12 s, no debuff", function()
                Ready()
                W.cooldowns[ 17364 ] = { start = W.time - 8, duration = 20 }
            end },
            { "Combat, SS ready in 4 s, no debuff (hold shock)", function()
                Ready()
                W.cooldowns[ 17364 ] = { start = W.time - 12, duration = 20 }
            end },
            { "Combat, 20% mana, SS debuff up (low mana)", function()
                Ready()
                W.mana = 800
                W.cooldowns[ 17364 ] = { start = W.time - 1, duration = 20 }
                W.debuffs = { Aura( 17364, 11, 2, 12 ) }
            end },
            { "Combat, Lightning Shield down", function()
                Ready()
                W.buffs = {}
            end },
            { "Combat, 3 enemies (AoE)", function()
                Ready()
                H.Plates( 2 )
            end },
            { "Combat, 3 enemies, Fire Nova gone off", function()
                Ready()
                W.totems[ 1 ] = nil
                W.cooldowns[ 11315 ] = { start = W.time - 6, duration = 15 }
                H.Plates( 2 )
            end },
            { "Combat, 3 enemies, setting: no AoE totems", function()
                Ready()
                Setting( "aoe_totems", false )
                H.Plates( 2 )
            end },
            { "Combat, setting: Frost Shock, SS debuff up", function()
                Ready()
                Setting( "enh_shock", "frost_shock" )
                W.cooldowns[ 17364 ] = { start = W.time - 1, duration = 20 }
                W.debuffs = { Aura( 17364, 11, 2, 12 ) }
            end },
            { "Combat, setting: Flame Shock, SS on cooldown", function()
                Ready()
                Setting( "enh_shock", "flame_shock" )
                W.cooldowns[ 17364 ] = { start = W.time - 1, duration = 20 }
            end },
            { "Combat, setting: no shocks, SS on cooldown", function()
                Ready()
                Setting( "enh_shock", "none" )
                W.cooldowns[ 17364 ] = { start = W.time - 1, duration = 20 }
                W.debuffs = { Aura( 17364, 11, 2, 12 ) }
            end },
            { "Combat, setting: shock mana 90%", function()
                Ready()
                Setting( "enh_shock_mana", 90 )
                W.mana = 3000
                W.cooldowns[ 17364 ] = { start = W.time - 1, duration = 20 }
                W.debuffs = { Aura( 17364, 11, 2, 12 ) }
            end },
            { "Out of combat, setting: Rockbiter imbue (has Windfury)", function()
                Setting( "enh_imbue", "rockbiter_weapon" )
                W.target, W.buffs = Target(), { LS() }
                Imbue()
            end },
            { "Out of combat, setting: no imbue, LS up", function()
                Setting( "enh_imbue", "none" )
                W.target, W.buffs = Target(), { LS() }
            end },
            { "Out of combat, setting: no LB pull, target 20 yd", function()
                Setting( "enh_lb_pull", false )
                W.target, W.buffs = Target(), { LS() }
                Imbue()
                W.target.distance = 20
            end },
            { "Out of combat, setting: totems before combat", function()
                Setting( "totems_precombat", true )
                W.target, W.buffs = Target(), { LS() }
                Imbue()
            end },
            { "Combat, setting: Grace of Air totem (WF up)", function()
                Ready()
                Setting( "enh_totem_air", "grace_of_air_totem" )
            end },
            { "Combat, setting: Lightning Shield off, LS down", function()
                Ready()
                Setting( "lightning_shield", false )
                W.buffs = {}
            end },
        }
    end,
}
