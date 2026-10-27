local addon, ns = ...
local Hekili = _G[ addon ]

if not Hekili.IsEra() then return end

local class, state = Hekili.Class, Hekili.State


-- Points spent in a talent tab.  The 1.15.8+ client moved this to C_SpecializationInfo; the
-- GetTalentTabInfo() fallback returns ( specId, name, description, icon, pointsSpent, ... ).
local function GetTabPoints( tab )
    if C_SpecializationInfo and C_SpecializationInfo.GetSpecializationInfo then
        local points = select( 7, C_SpecializationInfo.GetSpecializationInfo( tab ) )
        if type( points ) == "number" then return points end
    end

    if GetTalentTabInfo then
        local r1, r2, r3, r4, r5 = GetTalentTabInfo( tab )
        if type( r5 ) == "number" then return r5 end
        if type( r3 ) == "number" then return r3 end
    end

    return 0
end
ns.GetTabPoints = GetTabPoints


-- Changed setting defaults.  Hekili saves every setting in the profile (defaults included), so a new default would never
-- reach existing installs; a class module lists { name, from, to } in spec.settingMigrations (append-only), and each one is
-- applied once per profile to settings still at the old default.  Settings the player changed are left alone.
function ns.MigrateSettings( spec )
    local s = class.specs[ spec ]
    local p = Hekili.DB and Hekili.DB.profile.specs[ spec ]
    if not ( s and s.settingMigrations and p ) then return end
    p.settings = p.settings or {}
    local done = p.settingsMigrated or 0
    for i = done + 1, #s.settingMigrations do
        local m = s.settingMigrations[ i ]
        if p.settings[ m.name ] == m.from then p.settings[ m.name ] = m.to end
    end
    p.settingsMigrated = #s.settingMigrations
end

function ns.updateTalents()
    for _, tal in pairs( state.talent ) do
        tal.enabled = false
        tal.rank = 0
    end

    for k, v in pairs( class.talents ) do
        local talent = rawget( state.talent, k ) or {}
        talent.enabled = false
        talent.rank = 0

        -- v = { talentID, maxRank, rank1SpellID, rank2SpellID, ... }; check the highest rank first.
        for i = #v, 3, -1 do
            local spell = v[i]
            local ability = class.abilities[ spell ]

            if ability then
                -- This is a talent, but it could also be an ability with multiple ranks.
                local spellID = select( 7, GetSpellInfo( ability.name ) ) or spell
                if IsPlayerSpell( spellID ) then
                    talent.enabled = true
                    talent.rank = i - 2
                    break
                end
            elseif IsPlayerSpell( spell ) then
                talent.enabled = true
                talent.rank = i - 2
                break
            end
        end

        state.talent[ k ] = talent
    end

    local spec = state.spec.id or select( 3, UnitClass( "player" ) )

    ns.MigrateSettings( spec )

    -- Classic Era has no "global cooldown" spell (61304); track the GCD through the class's
    -- cooldown-free spell named by its module (spec:RegisterOptions{ gcd = ... }).
    local gcdSpell = class.specs[ spec ] and class.specs[ spec ].options and class.specs[ spec ].options.gcd
    if gcdSpell and class.abilities.global_cooldown then
        class.abilities.global_cooldown.id = gcdSpell
        ns.GCDSpellID = gcdSpell
        -- The GCD spell needn't be one of the class's abilities (e.g. Holy Light rank 1); lookups by ID must still resolve.
        if not class.abilities[ gcdSpell ] then class.abilities[ gcdSpell ] = class.abilities.global_cooldown end
    end

    if not Hekili.DB.profile.specs[ spec ].usePackSelector then return end

    -- Swap priorities if needed.
    local tab1, tab2, tab3 = GetTabPoints( 1 ), GetTabPoints( 2 ), GetTabPoints( 3 )

    local fromPackage = Hekili.DB.profile.specs[ spec ].package

    -- Pack selector defaults are only copied into autoPacks once the options panel has been built;
    -- until then, fall back to each selector's default so a fresh install picks the right priority.
    local selectorDefaults = {}
    for _, setting in ipairs( class.specs[ spec ].settings ) do
        selectorDefaults[ setting.name ] = setting.default
    end

    for _, selector in ipairs( class.specs[ spec ].packSelectors ) do
        local toPackage = Hekili.DB.profile.specs[ state.spec.id ].autoPacks[ selector.key ]
        if toPackage == nil then toPackage = selectorDefaults[ selector.key ] end
        toPackage = toPackage or "none"

        if not rawget( Hekili.DB.profile.packs, toPackage ) then toPackage = "none" end

        if type( selector.condition ) == "function" and selector.condition( tab1, tab2, tab3 ) or
            type( selector.condition ) == "number" and
                ( selector.condition == 1 and tab1 > max( tab2, tab3 ) or
                  selector.condition == 2 and tab2 > max( tab1, tab3 ) or
                  selector.condition == 3 and tab3 > max( tab1, tab2 ) ) then

            if toPackage ~= "none" and fromPackage ~= toPackage then
                Hekili.DB.profile.specs[ spec ].package = toPackage
                C_Timer.After( Hekili.PLAYER_ENTERING_WORLD and 0 or 5, function() Hekili:Notify( toPackage .. " priority activated." ) end )
            end
            break
        end
    end
end


-- Classic Era has no glyphs.  Keep the registration method so shared class code can call it.
local HekiliSpecMixin = ns.HekiliSpecMixin

function HekiliSpecMixin:RegisterGlyphs( glyphs )
    for id, name in pairs( glyphs ) do
        self.glyphs[ id ] = name
    end
end

function ns.updateGlyphs() end
