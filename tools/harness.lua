-- Offline test harness: runs the addon against a model of the Classic Era client.
--
-- Usage (from the repository root, after tools/fetch-era-api.sh and python3 tools/era_data.py):
--   luajit tools/harness.lua [Hekili_Vanilla.toc] [CLASS] [talent points, e.g. 17/34/0]
-- Builds and combat scenarios per class live in tools/scenarios/<CLASS>.lua.
--
-- What is modelled faithfully, from the client's own data (tools/.era-api):
--   * Only APIs that exist on Era resolve (native API, FrameXML, deprecation fallbacks); harness stubs for
--     anything else are reported and dropped.  GlobalStrings and Enum come from the client tables.
--   * Spells: GetSpellInfo & co. answer from SpellName/Spell; a level 60 character of the class knows its
--     trainable ranks plus the talents of the chosen build (see BUILDS).
--   * Items: unknown item IDs make Item:ContinueOnItemLoad error, as the 1.15.8+ client does.
--   * Events: registering an event the client doesn't have errors.  SetJustifyH/V validate their argument.
-- Then it runs login, spec detection, priority restore/selection, compiles every priority entry, and plays
-- combat scenarios (SCENARIOS) through the real recommendation engine, printing what the display shows.
-- Exit code 1 if anything errored.

local TOC = arg[ 1 ] or "Hekili_Vanilla.toc"
local CLASS = arg[ 2 ] or "WARRIOR"
local BUILD = arg[ 3 ]
-- Character level (HARNESS_LEVEL); spells above it are unknown.  Use build 0/0/0 below level 10.
local LEVEL = tonumber( os.getenv( "HARNESS_LEVEL" ) or "" ) or 60

local CLASSES = {
    WARRIOR = { "Warrior", 1 }, PALADIN = { "Paladin", 2 }, HUNTER = { "Hunter", 3 }, ROGUE = { "Rogue", 4 },
    PRIEST = { "Priest", 5 }, SHAMAN = { "Shaman", 7 }, MAGE = { "Mage", 8 }, WARLOCK = { "Warlock", 9 }, DRUID = { "Druid", 11 },
}
local className, classID = CLASSES[ CLASS ][ 1 ], CLASSES[ CLASS ][ 2 ]

local function ReadFile( path )
    local f = io.open( path, "r" )
    if not f then return nil end
    local s = f:read( "*a" )
    f:close()
    return s
end

local TOOLS_DIR = arg[ 0 ]:match( "^(.*)/" ) or "."
local API_DIR = TOOLS_DIR .. "/.era-api/"

-- Per-class definition: tools/scenarios/<CLASS>.lua returns
--   { builds = { [ "a/b/c" ] = { talent rank spell IDs } }, defaultBuild = "a/b/c",
--     reset = function( H ) ... end,          -- class defaults before each scenario (power type, forms, gear)
--     scenarios = function( H ) return { { "name", function() ... end }, ... } end }
local CLASSDEF
do
    local path = TOOLS_DIR .. "/scenarios/" .. CLASS .. ".lua"
    local chunk = loadfile( path )
    if not chunk then
        print( "No scenario file for " .. CLASS .. " (" .. path .. ")." )
        os.exit( 2 )
    end
    CLASSDEF = chunk()
end
BUILD = BUILD or CLASSDEF.defaultBuild or "0/0/0"
local DATA_OK, DATA = pcall( dofile, API_DIR .. "era_data.lua" )
if not DATA_OK then
    print( "Missing client data: run tools/fetch-era-api.sh and python3 tools/era_data.py first.\n" .. tostring( DATA ) )
    os.exit( 2 )
end

-- Names the Era client provides.
local CLIENT = {}
for name in ( ReadFile( API_DIR .. "GlobalAPI.lua" ) or "" ):gmatch( '"([%w_%.:]+)"' ) do CLIENT[ name:match( "^([%w_]+)" ) ] = true end
for _, file in ipairs( { "FrameXML.txt", "Deprecated.txt" } ) do
    for name in ( ReadFile( API_DIR .. file ) or "" ):gmatch( "[^\r\n]+" ) do CLIENT[ name ] = true end
end
-- Frames and font objects created by Blizzard's XML (not visible in the Lua dumps).
for name in ( "UIParent Minimap MinimapCluster WorldFrame DEFAULT_CHAT_FRAME ChatFrame1 GameTooltip ItemRefTooltip " ..
              "GameFontNormal GameFontNormalSmall GameFontNormalLarge GameFontHighlight GameFontHighlightSmall " ..
              "GameFontHighlightLarge GameFontDisable GameFontDisableSmall ChatFontNormal SettingsPanel GameMenuFrame " ..
              "DropDownList1 ColorPickerFrame OpacitySliderFrame SpellBookFrame ActionButton1 PetActionButton1 " ..
              "StanceButton1 OverrideActionBarButton1 NORMAL_FONT_COLOR HIGHLIGHT_FONT_COLOR RED_FONT_COLOR " ..
              "GREEN_FONT_COLOR NORMAL_FONT_COLOR_CODE ITEM_QUALITY_COLORS RAID_CLASS_COLORS UISpecialFrames " ..
              "SlashCmdList hash_SlashCmdList StaticPopupDialogs" ):gmatch( "%S+" ) do
    CLIENT[ name ] = true
end


-- TOC metadata and file list.
local meta, files = {}, {}
for line in assert( ReadFile( TOC ), "missing " .. TOC ):gmatch( "[^\r\n]+" ) do
    local k, v = line:match( "^##%s*([%w%-]+):%s*(.-)%s*$" )
    if k then meta[ k ] = v
    elseif not line:match( "^#" ) and line:match( "%S" ) then files[ #files + 1 ] = ( line:gsub( "\\", "/" ):gsub( "%s+$", "" ) ) end
end

local errors = {}
local function Report( kind, msg )
    errors[ #errors + 1 ] = kind .. ": " .. tostring( msg )
    io.stderr:write( "ERROR [" .. kind .. "] " .. tostring( msg ) .. "\n" )
end


-- Permissive mocks for client namespaces we don't model in detail.
local mockMT = {}
local function Mock( name ) return setmetatable( { __mockname = name }, mockMT ) end
mockMT.__index = function( t, k )
    local v = Mock( rawget( t, "__mockname" ) .. "." .. tostring( k ) )
    rawset( t, k, v )
    return v
end
mockMT.__call = function( self ) return nil end


-- World model ----------------------------------------------------------------------------------------------

local W = {
    time = 1000, loggedIn = false, inCombat = false,
    -- Power: powerType is the primary resource (0 mana, 1 rage, 3 energy); combo = combo points on the target.
    powerType = 0, rage = 0, mana = 4000, manaMax = 4000, energy = 100, combo = 0,
    baseMana = 1200, -- percent-of-base-mana costs (e.g. Judgement 6%, Cat Form 55%) use this
    -- Shapeshift bar: forms = { spellID, ... } in bar order, stance = active index (0 = none).
    forms = {}, stance = 0,
    health = 4000, healthMax = 4000,
    pet = nil,       -- { guid, name, family, health, healthMax } or nil
    casting = nil,   -- player cast: { spellID, start, finish, channel = bool }
    equip = {},      -- inventory slot -> item ID (16 main hand, 17 off hand, 18 ranged)
    autoRepeat = false, -- Auto Shot / Shoot active
    target = nil,    -- { guid, name, health, healthMax, boss }
    plates = {},     -- extra hostile units in melee range: { guid, health, healthMax }
    buffs = {},      -- player buffs: { spellID, duration, expires }
    debuffs = {},    -- target debuffs
    cleu = nil,      -- current combat log payload
    cooldowns = {},  -- spellID -> { start, duration }
    cvars = { nameplateShowEnemies = "1" }, -- overrides of the client defaults
    groupSize = 0,   -- GetNumGroupMembers(): 0 solo, 2-5 party, 6-40 raid
    itemCounts = {}, -- item ID -> GetItemCount() (e.g. Soul Shards 6265); class reset() sets them
    speed = 0,       -- player movement speed (GetUnitSpeed); > 0 means moving
    totems = {},     -- GetTotemInfo: slot (1 fire, 2 earth, 3 water, 4 air) -> { name, remaining, duration }
    enchants = {},   -- GetWeaponEnchantInfo: { mh = { id, remaining }, oh = { id, remaining } } (temporary enchant IDs)
}

local function UnitData( unit )
    if unit == "target" then return W.target end
    if unit == "pet" then return W.pet end
    local n = type( unit ) == "string" and tonumber( unit:match( "^nameplate(%d+)$" ) )
    if n then
        if n == 1 then return W.target end
        return W.plates[ n - 1 ]
    end
end


-- Spells -----------------------------------------------------------------------------------------------------

local known = {}
do
    local cls = DATA.classes[ classID ]
    local build = ( CLASSDEF.builds or {} )[ BUILD ]
    if not build then
        print( "Unknown build " .. tostring( BUILD ) .. " for " .. CLASS .. "; using no talents." )
        build = {}
    end
    if cls then
        for _, id in ipairs( cls.base ) do known[ id ] = true end
        local talentRoots = {}
        for _, id in ipairs( build ) do
            known[ id ] = true
            talentRoots[ id ] = true
        end
        -- Ranks taught after an active talent (Bloodthirst 2-4, ...), if the talent's first rank is learned.
        for id, root in pairs( cls.talentTaught ) do
            if talentRoots[ root ] then known[ id ] = true end
        end
    end
    known[ 6603 ] = true -- Auto Attack
    -- Shoot (wands) comes with the Wands skill (not a class skill line) for priests, mages and warlocks.
    if classID == 5 or classID == 8 or classID == 9 then known[ 5019 ] = true end

    -- Below the level a rank is learned, it isn't known (talents need level 10+, one point per level).
    for id in pairs( known ) do
        local info = DATA.spells[ id ]
        if info and ( info[ 3 ] or 0 ) > LEVEL then known[ id ] = nil end
    end

    -- Skill lines also carry unranked effect spells (e.g. Execute's damage spell 20647) next to the ranked
    -- spellbook ones; those aren't in the spellbook, so drop unranked entries whose name also has ranks.
    local ranked = {}
    if cls then
        for _, id in ipairs( cls.base ) do
            local info = DATA.spells[ id ]
            if info and info[ 2 ]:match( "^Rank %d" ) then ranked[ info[ 1 ] ] = true end
        end
    end
    for id in pairs( known ) do
        local info = DATA.spells[ id ]
        if info and ranked[ info[ 1 ] ] and not info[ 2 ]:match( "^Rank %d" ) then known[ id ] = nil end
    end
end

local function RankNumber( id )
    local s = DATA.spells[ id ] and DATA.spells[ id ][ 2 ] or ""
    return tonumber( s:match( "Rank (%d+)" ) ) or 0
end

-- The class skill lines also list effect spells (e.g. the Last Stand buff) under a talent's name; a name only
-- resolves in the spellbook when the talent itself is learned, so drop those for unlearned talents.
do
    local cls = DATA.classes[ classID ]
    if cls then
        local unlearned = {}
        for _, t in ipairs( cls.talents ) do
            local learned = false
            for _, r in ipairs( t.ranks ) do if known[ r ] then learned = true end end
            if not learned then
                for _, r in ipairs( t.ranks ) do
                    if DATA.spells[ r ] then unlearned[ DATA.spells[ r ][ 1 ] ] = true end
                end
            end
        end
        for id in pairs( known ) do
            local info = DATA.spells[ id ]
            if info and unlearned[ info[ 1 ] ] then known[ id ] = nil end
        end
    end
end

local knownByName = {}
for id in pairs( known ) do
    local info = DATA.spells[ id ]
    if info then
        local cur = knownByName[ info[ 1 ] ]
        if not cur or RankNumber( id ) > RankNumber( cur ) then knownByName[ info[ 1 ] ] = id end
    end
end

local function ResolveSpell( x )
    if type( x ) == "number" then return DATA.spells[ x ] and x or nil end
    if type( x ) == "string" then
        local id = tonumber( x )
        if id then return DATA.spells[ id ] and id or nil end
        return knownByName[ x ]
    end
end

local ICON = 136243

local function GetSpellInfo( x )
    local id = ResolveSpell( x )
    if not id then return nil end
    local info = DATA.spells[ id ]
    return info[ 1 ], info[ 2 ], ICON, 0, 0, 5, id, ICON
end

local function SpellInfoTable( x )
    local id = ResolveSpell( x )
    if not id then return nil end
    return { name = DATA.spells[ id ][ 1 ], iconID = ICON, originalIconID = ICON, castTime = 0, minRange = 0, maxRange = 5, spellID = id }
end

local function SpellCooldown( x )
    local id = ResolveSpell( x )
    if not id then return 0, 0, 1, 1 end -- e.g. 61304, which Era doesn't have
    local cd = W.cooldowns[ id ]
    if cd and cd.start + cd.duration > W.time then return cd.start, cd.duration, 1, 1 end
    -- During the global cooldown, spells without a cooldown of their own report the GCD.
    if W.gcdStart and W.gcdStart + 1.5 > W.time then return W.gcdStart, 1.5, 1, 1 end
    return 0, 0, 1, 1
end

local function IsKnown( x ) local id = ResolveSpell( x ); return id ~= nil and known[ id ] == true end

-- GetSpellPowerCost from the client's SpellPower table.  Percent costs are of base mana (W.baseMana).
local POWER_NAMES = { [ 0 ] = "MANA", [ 1 ] = "RAGE", [ 2 ] = "FOCUS", [ 3 ] = "ENERGY", [ -2 ] = "HEALTH" }
local function SpellPowerCost( x )
    local id = ResolveSpell( x )
    local c = id and DATA.costs and DATA.costs[ id ]
    if not c then return id and {} or nil end
    local ptype, amount, pct = c[ 1 ], c[ 2 ], c[ 3 ]
    if ptype == 1 then amount = amount / 10 end -- rage is stored in tenths
    if pct and pct > 0 then amount = math.floor( pct * ( W.baseMana or 1000 ) / 100 ) end
    return { { type = ptype, name = POWER_NAMES[ ptype ] or "MANA", cost = amount, minCost = amount, costPercent = pct or 0,
               costPerSec = 0, requiredAuraID = 0, hasRequiredAura = false } }
end


-- Items ------------------------------------------------------------------------------------------------------

local function ItemID( x )
    if type( x ) == "number" then return x end
    if type( x ) == "string" then return tonumber( x ) or tonumber( x:match( "item:(%d+)" ) or "" ) end
end

local function GetItemInfo( x )
    local id = ItemID( x )
    local name = id and DATA.items[ id ]
    if not name then return nil end
    return name, "|cffffffff|Hitem:" .. id .. "|h[" .. name .. "]|h|r", 1, 1, 1, "Miscellaneous", "Junk", 20,
        ( DATA.equipLoc and DATA.equipLoc[ id ] ) or "", 134400, 0, 15, 0
end

-- Item mixin: a port of Blizzard_ObjectAPI/Classic/Item.lua (1.15.9).  On the live client
-- C_Item.DoesItemExistByID can be true for an ID that GetItemInfoInstant doesn't know (seen with Wrath potion
-- IDs), so ItemMixin:IsItemEmpty() is false while GetItemID() is nil, and ContinueOnItemLoad then indexes its
-- callback table with nil.  The harness models the worst case: DoesItemExistByID is true for any positive ID.
local function ItemInfoInstant( x )
    local id = ItemID( x )
    if id and DATA.items[ id ] then return id, "Miscellaneous", "Junk", "", 134400, 15, 0 end
end
local function DoesItemExistByID( x ) local id = ItemID( x ); return id ~= nil and id > 0 end

local ItemMT = { __index = {} }
local ItemMethods = ItemMT.__index
function ItemMethods:GetStaticBackingItem() return self.itemLink or self.itemID end
function ItemMethods:IsItemEmpty()
    if self:GetStaticBackingItem() then return not DoesItemExistByID( self:GetStaticBackingItem() ) end
    return true
end
function ItemMethods:GetItemID()
    if self:GetStaticBackingItem() then return ( ItemInfoInstant( self:GetStaticBackingItem() ) ) end
end
function ItemMethods:IsItemDataCached() return true end
function ItemMethods:GetItemName() return DATA.items[ self:GetItemID() or 0 ] end
function ItemMethods:GetItemLink() return select( 2, GetItemInfo( self.itemID ) ) end
function ItemMethods:GetItemIcon() return self:GetItemID() and 134400 or nil end
local itemCallbacks = {}
function ItemMethods:ContinueOnItemLoad( cb )
    if type( cb ) ~= "function" or self:IsItemEmpty() then error( "Usage: NonEmptyItem:ContinueOnLoad(callbackFunction)", 2 ) end
    local id = self:GetItemID()
    if id == nil then error( "Interface/AddOns/Blizzard_ObjectAPI/Classic/Item.lua:320: table index is nil", 2 ) end
    itemCallbacks[ id ] = itemCallbacks[ id ] or {}
    cb( true )
end
ItemMethods.ContinueWithCancelOnItemLoad = function( self, cb ) self:ContinueOnItemLoad( cb ); return function() end end

local Item = {
    CreateFromItemID = function( _, id ) return setmetatable( { itemID = id }, ItemMT ) end,
    CreateFromItemLink = function( _, link ) return setmetatable( { itemID = ItemID( link ) }, ItemMT ) end,
}


-- Frames -----------------------------------------------------------------------------------------------------

local frames = {}

local METHOD_PREFIXES = { "Set", "Get", "Is", "Has", "Enable", "Disable", "Show", "Hide", "Register", "Unregister", "Clear",
    "Create", "Start", "Stop", "Play", "Pause", "Finish", "Restart", "Lock", "Unlock", "Add", "Remove", "Can", "Raise", "Lower",
    "Hook", "Click", "Insert", "Scroll", "Update", "Reset", "Apply", "Adjust", "Highlight", "Unhighlight", "Allow", "Toggle",
    "Refresh", "Execute", "Flash", "Release", "Acquire", "Fade", "Append", "Dim", "Undim", "Load" }

local BARE_VERBS = { Show = true, Hide = true, Raise = true, Lower = true, Click = true, Play = true, Stop = true, Pause = true,
    Finish = true, Restart = true, Lock = true, Unlock = true, Enable = true, Disable = true, Toggle = true }

local NUMERIC_GETTERS = {
    GetSize = { 100, 100 }, GetLeft = { 0 }, GetRight = { 100 }, GetTop = { 100 }, GetBottom = { 0 }, GetCenter = { 50, 50 },
    GetAlpha = { 1 }, GetEffectiveAlpha = { 1 }, GetNumRegions = { 0 }, GetNumChildren = { 0 }, GetStringHeight = { 10 },
    GetLineHeight = { 10 }, GetTextWidth = { 10 }, GetUnboundedStringWidth = { 10 }, GetValue = { 0 }, GetMinMaxValues = { 0, 1 },
    GetFrameLevel = { 1 }, GetDrawLayer = { "ARTWORK", 0 }, GetFrameStrata = { "MEDIUM" }, GetNumPoints = { 0 },
    GetTexCoord = { 0, 0, 0, 1, 1, 0, 1, 1 }, GetVertexColor = { 1, 1, 1, 1 }, GetTextColor = { 1, 1, 1, 1 },
    GetWidth = { 100 }, GetHeight = { 100 }, GetScale = { 1 }, GetEffectiveScale = { 1 }, GetStringWidth = { 10 },
}

local frameMT = {
    __index = function( t, k )
        if type( k ) ~= "string" then return nil end
        if NUMERIC_GETTERS[ k ] then
            local values = NUMERIC_GETTERS[ k ]
            local fn = function() return unpack( values ) end
            rawset( t, k, fn )
            return fn
        end
        for _, prefix in ipairs( METHOD_PREFIXES ) do
            -- A bare verb is a method only for real widget verbs; "Highlight" or "Flash" alone are usually child regions.
            local bare = #k == #prefix and BARE_VERBS[ k ]
            if k:sub( 1, #prefix ) == prefix and ( bare or k:sub( #prefix + 1, #prefix + 1 ):match( "[A-Z]" ) ) then
                local fn = function() return Mock( tostring( rawget( t, "__mockname" ) ) .. ":" .. k .. "()" ) end
                rawset( t, k, fn )
                return fn
            end
        end
    end,
}

local JUSTIFY = { H = { LEFT = true, CENTER = true, RIGHT = true }, V = { TOP = true, MIDDLE = true, BOTTOM = true } }

local function NewFrame( frameType, name, parent )
    local f = setmetatable( { __mockname = tostring( name or frameType ) }, frameMT )
    f.__scripts, f.__events, f.__shown, f.__parent, f.__type = {}, {}, true, parent, frameType

    f.SetScript = function( self, script, fn ) self.__scripts[ script ] = fn end
    f.GetScript = function( self, script ) return self.__scripts[ script ] end
    f.HookScript = function( self, script, fn )
        local prev = self.__scripts[ script ]
        self.__scripts[ script ] = prev and function( ... ) prev( ... ); fn( ... ) end or fn
    end
    local function Register( self, e )
        if not DATA.events[ e ] then
            error( ( "%s:RegisterEvent(): Attempt to register unknown event \"%s\"" ):format( tostring( name or "Frame" ), tostring( e ) ), 2 )
        end
        self.__events[ e ] = true
    end
    f.RegisterEvent = Register
    f.RegisterUnitEvent = Register
    f.UnregisterEvent = function( self, e ) self.__events[ e ] = nil end
    f.UnregisterAllEvents = function( self ) self.__events = {} end
    f.IsEventRegistered = function( self, e ) return self.__events[ e ] end
    f.GetName = function() return name end
    f.GetObjectType = function() return frameType end
    f.IsObjectType = function( _, t ) return t == frameType end
    f.Show = function( self ) self.__shown = true end
    f.Hide = function( self ) self.__shown = false end
    f.SetShown = function( self, s ) self.__shown = not not s end
    f.IsShown = function( self ) return self.__shown end
    f.IsVisible = function( self ) return self.__shown end
    f.CreateTexture = function( self, n ) return NewFrame( "Texture", n, self ) end
    f.CreateFontString = function( self, n ) return NewFrame( "FontString", n, self ) end
    f.CreateAnimationGroup = function( self, n ) return NewFrame( "AnimationGroup", n, self ) end
    f.CreateAnimation = function( self, t, n ) return NewFrame( "Animation", n, self ) end
    f.NumLines = function() return 0 end
    f.GetText = function( self ) return self.__text end
    f.SetText = function( self, s ) self.__text = s end
    f.SetFormattedText = function( self, fmt, ... ) self.__text = fmt:format( ... ) end
    f.GetFont = function() return "Fonts\\ARIALN.TTF", 12, "" end
    f.SetJustifyH = function( self, v )
        if not JUSTIFY.H[ v ] then error( "Usage: self:SetJustifyH(justifyH)", 2 ) end
    end
    f.SetJustifyV = function( self, v )
        if not JUSTIFY.V[ v ] then error( "Usage: self:SetJustifyV(justifyV)", 2 ) end
    end
    f.GetParent = function( self ) return self.__parent or UIParent end
    f.SetParent = function( self, p ) self.__parent = p end
    frames[ #frames + 1 ] = f
    if name then _G[ name ] = f end
    return f
end

local function Fire( event, ... )
    local n = 0
    for _, f in ipairs( frames ) do
        if f.__events[ event ] and f.__scripts.OnEvent then
            local ok, err = pcall( f.__scripts.OnEvent, f, event, ... )
            if not ok then Report( event, err ) end
            n = n + 1
        end
    end
    return n
end


-- Auras ------------------------------------------------------------------------------------------------------

local function AuraList( unit, filter )
    if unit == "player" then return ( filter and filter:find( "HARMFUL" ) ) and {} or W.buffs end
    if unit == "target" then return ( filter and filter:find( "HARMFUL" ) ) and W.debuffs or {} end
    return {}
end

local function AuraData( a, unit )
    local info = DATA.spells[ a.spellID ]
    return {
        name = info and info[ 1 ] or "?", icon = ICON, applications = a.count or 0, dispelName = nil,
        duration = a.duration or 0, expirationTime = a.expires or 0, sourceUnit = "player", isStealable = false,
        spellId = a.spellID, canApplyAura = true, isBossAura = false, timeMod = 1, points = {}, auraInstanceID = a.spellID,
        isHelpful = unit == "player", isHarmful = unit ~= "player",
    }
end

local function UnpackAura( d )
    if not d then return nil end
    return d.name, d.icon, d.applications, d.dispelName, d.duration, d.expirationTime, d.sourceUnit, d.isStealable,
        false, d.spellId, d.canApplyAura, d.isBossAura, false, d.timeMod
end

local function AuraByIndex( unit, index, filter )
    local list = AuraList( unit, filter or ( unit == "player" and "HELPFUL" or "HARMFUL" ) )
    local a = list[ index ]
    return a and AuraData( a, unit ) or nil
end


-- Client API -------------------------------------------------------------------------------------------------

local timers = {}
local GUIDS = { player = "Player-1-00000001" }

local api = {
    -- Lua extensions and basics.
    strsplit = function( d, s, n )
        local out = {}
        for piece in ( s .. d ):gmatch( "(.-)" .. d:gsub( "%p", "%%%0" ) ) do out[ #out + 1 ] = piece end
        return unpack( out )
    end,
    strjoin = function( d, ... ) return table.concat( { ... }, d ) end,
    strtrim = function( s ) return ( s:gsub( "^%s+", "" ):gsub( "%s+$", "" ) ) end,
    strlower = string.lower, strupper = string.upper, strlen = string.len, strsub = string.sub, strfind = string.find,
    strmatch = string.match, strbyte = string.byte, strchar = string.char, strrep = string.rep, strrev = string.reverse,
    gsub = string.gsub, gmatch = string.gmatch, format = string.format, tostringall = function( ... ) return ... end,
    tinsert = table.insert, tremove = table.remove, tconcat = table.concat, sort = table.sort,
    wipe = function( t ) for k in pairs( t ) do t[ k ] = nil end return t end,
    floor = math.floor, ceil = math.ceil, abs = math.abs, max = math.max, min = math.min, mod = math.fmod,
    random = math.random, sqrt = math.sqrt, time = os.time, date = os.date,
    bit = rawget( _G, "bit" ) or require( "bit" ),
    debugstack = function() return "" end, debuglocals = function() return "" end,
    debugprofilestop = function() return os.clock() * 1000 end,
    geterrorhandler = function() return function( e ) Report( "error handler", e ) end end,
    seterrorhandler = function() end,
    hooksecurefunc = function() end, issecurevariable = function() return true end,
    securecall = function( f, ... ) if type( f ) == "function" then return f( ... ) end end,

    -- Game state.
    GetBuildInfo = function() return "1.15.9", "70003", "Sep 29 2026", tonumber( meta.Interface ) or 11509 end,
    GetTime = function() return W.time end,
    GetServerTime = function() return os.time() end,
    GetLocale = function() return "enUS" end,
    -- CVars: Era's defaults (nil for CVars the client doesn't have), with enemy nameplates switched on (V).
    GetCVar = function( k ) if W.cvars[ k ] ~= nil then return W.cvars[ k ] end return DATA.cvars and DATA.cvars[ k ] end,
    GetCVarBool = function( k )
        local v = W.cvars[ k ]
        if v == nil then v = DATA.cvars and DATA.cvars[ k ] end
        return v == "1"
    end,
    GetCVarDefault = function( k ) return DATA.cvars and DATA.cvars[ k ] end,
    SetCVar = function() end,
    IsLoggedIn = function() return W.loggedIn end,
    GetFramerate = function() return 60 end, GetNetStats = function() return 0, 0, 40, 40 end,
    GetRealmName = function() return "Realm" end, GetCurrentRegion = function() return 3 end,
    GetMaxPlayerLevel = function() return 60 end, GetExpansionLevel = function() return 0 end,
    IsShiftKeyDown = function() return false end, IsControlKeyDown = function() return false end, IsAltKeyDown = function() return false end,
    InCombatLockdown = function() return false end,
    GetScreenWidth = function() return 1920 end, GetScreenHeight = function() return 1080 end,
    GetPhysicalScreenSize = function() return 2560, 1440 end,
    GetCursorPosition = function() return 0, 0 end,
    CreateFrame = NewFrame,
    IsInInstance = function() return false, "none" end, GetInstanceInfo = function() return "Elwynn Forest", "none", 0, "", 5, 0, false, 0 end,
    GetZoneText = function() return "Elwynn Forest" end, GetRealZoneText = function() return "Elwynn Forest" end, GetSubZoneText = function() return "" end,
    IsMounted = function() return false end, IsFlying = function() return false end, IsResting = function() return false end,
    GetNumGroupMembers = function() return W.groupSize end, IsInGroup = function() return W.groupSize > 1 end, IsInRaid = function() return W.groupSize > 5 end,
    UnitInRaid = function() return nil end, UnitInParty = function() return false end,
    PlaySound = function() end, PlaySoundFile = function() end, StopSound = function() end,
    HideUIPanel = function() end, ShowUIPanel = function() end, ReloadUI = function() end,

    -- Classes on Era: IDs 1-11 without Death Knight (6) and Monk (10).
    GetNumClasses = function() return 11 end,
    GetClassInfo = function( i )
        for token, c in pairs( CLASSES ) do if c[ 2 ] == i then return c[ 1 ], token, i end end
    end,

    -- Units.
    UnitClass = function( u ) if u == "player" then return className, CLASS, classID end end,
    UnitClassBase = function( u ) if u == "player" then return CLASS, classID end end,
    -- HARNESS_RACE=Undead|NightElf|Troll|Dwarf|Gnome|Orc|Tauren (default Human), for racial abilities.
    UnitRace = function()
        local races = { Human = { "Human", "Human", 1 }, Orc = { "Orc", "Orc", 2 }, Dwarf = { "Dwarf", "Dwarf", 3 },
            NightElf = { "Night Elf", "NightElf", 4 }, Undead = { "Undead", "Scourge", 5 }, Tauren = { "Tauren", "Tauren", 6 },
            Gnome = { "Gnome", "Gnome", 7 }, Troll = { "Troll", "Troll", 8 } }
        local r = races[ os.getenv( "HARNESS_RACE" ) or "Human" ] or races.Human
        return r[ 1 ], r[ 2 ], r[ 3 ]
    end,
    UnitFactionGroup = function() return "Alliance", "Alliance" end,
    UnitSex = function() return 2 end,
    UnitLevel = function( u ) return u == "player" and LEVEL or ( UnitData( u ) and LEVEL or 0 ) end,
    UnitName = function( u ) if u == "player" then return "Tester", "Realm" end local d = UnitData( u ); return d and d.name or nil end,
    UnitGUID = function( u ) if u == "player" then return GUIDS.player end local d = UnitData( u ); return d and d.guid or nil end,
    UnitExists = function( u ) return u == "player" or UnitData( u ) ~= nil end,
    UnitIsUnit = function( a, b )
        if a == b then return true end
        local da, db = ( a == "player" ) and "p" or UnitData( a ), ( b == "player" ) and "p" or UnitData( b )
        return da ~= nil and da == db
    end,
    UnitCanAttack = function( a, b ) local d = UnitData( b ); return d ~= nil and not d.friendly end,
    UnitIsFriend = function( a, b ) local d = UnitData( b ); return b == "player" or ( d ~= nil and d.friendly == true ) end,
    UnitReaction = function( a, b ) local d = UnitData( b ); return d and ( d.friendly and 5 or 2 ) or 5 end,
    UnitCreatureFamily = function( u ) local d = UnitData( u ); return d and d.family end,
    HasPetUI = function() return W.pet ~= nil, false end,
    UnitIsDead = function( u ) local d = UnitData( u ); return d and d.health <= 0 or false end,
    UnitIsDeadOrGhost = function() return false end,
    UnitHealth = function( u ) if u == "player" then return W.health end local d = UnitData( u ); return d and d.health or 0 end,
    UnitHealthMax = function( u ) if u == "player" then return W.healthMax end local d = UnitData( u ); return d and d.healthMax or 0 end,
    UnitPower = function( u, t )
        if u == "pet" then return W.pet and W.pet.mana or 0 end
        if u ~= "player" then return 0 end
        t = t or W.powerType
        if t == 0 then return W.mana elseif t == 1 then return W.rage elseif t == 3 then return W.energy elseif t == 4 then return W.combo end
        return 0
    end,
    UnitPowerMax = function( u, t )
        if u == "pet" then return W.pet and W.pet.manaMax or 0 end
        if u ~= "player" then return 0 end
        t = t or W.powerType
        if t == 0 then return W.manaMax elseif t == 1 or t == 3 then return 100 elseif t == 4 then return 5 end
        return 0
    end,
    UnitPowerType = function( u )
        local t = ( u == "player" or u == nil ) and W.powerType or 0
        return t, ( { [ 0 ] = "MANA", [ 1 ] = "RAGE", [ 3 ] = "ENERGY" } )[ t ] or "MANA"
    end,
    UnitAffectingCombat = function( u ) return W.inCombat and ( u == "player" or UnitData( u ) ~= nil ) end,
    UnitClassification = function( u ) local d = UnitData( u ); return d and d.boss and "worldboss" or "normal" end,
    UnitCreatureType = function( u ) local d = UnitData( u ); return d and ( d.creatureType or "Humanoid" ) or nil end,
    UnitIsPlayer = function( u ) return u == "player" end,
    UnitIsTapDenied = function() return false end,
    UnitInVehicle = function() return false end, UnitHasVehicleUI = function() return false end, UnitOnTaxi = function() return false end,
    -- W.aggro: the target is attacking the player (threat status 3).
    UnitThreatSituation = function( u ) if u == "player" and W.target then return W.aggro and 3 or 0 end end,
    UnitDetailedThreatSituation = function( u ) if u == "player" and W.target then return W.aggro, W.aggro and 3 or 0, W.aggro and 100 or 50, 100, 1000 end end,
    UnitCastingInfo = function( u )
        local c = ( u == "player" and W.casting ) or ( UnitData( u ) and UnitData( u ).casting )
        if not c or c.channel then return nil end
        local name = DATA.spells[ c.spellID ] and DATA.spells[ c.spellID ][ 1 ] or "Spell"
        return name, name, ICON, c.start * 1000, c.finish * 1000, false, "cast", c.notInterruptible or false, c.spellID
    end,
    UnitChannelInfo = function( u )
        local c = ( u == "player" and W.casting ) or ( UnitData( u ) and UnitData( u ).casting )
        if not c or not c.channel then return nil end
        local name = DATA.spells[ c.spellID ] and DATA.spells[ c.spellID ][ 1 ] or "Spell"
        return name, name, ICON, c.start * 1000, c.finish * 1000, false, c.notInterruptible or false, c.spellID
    end,
    UnitRangedDamage = function() return 2.9, 150, 250, 0, 0, 1 end,
    UnitDamage = function() return 300, 400, 150, 200, 0, 0, 1 end,
    UnitAttackSpeed = function() return 2.6, 1.8 end,
    UnitAttackPower = function() return 1500, 200, 0 end, UnitRangedAttackPower = function() return 0, 0, 0 end,
    UnitStat = function() return 300, 300, 0, 0 end, UnitArmor = function() return 5000, 5000 end,
    GetCritChance = function() return 25 end, GetRangedCritChance = function() return 5 end, GetSpellCritChance = function() return 5 end,
    GetHaste = function() return 0 end, GetMeleeHaste = function() return 0 end, GetRangedHaste = function() return 0 end,
    UnitSpellHaste = function() return 0 end, GetCombatRating = function() return 0 end, GetCombatRatingBonus = function() return 0 end,
    GetUnitSpeed = function( u ) return ( u == "player" and W.speed or 0 ), 7, 7, 4.7 end, GetPlayerFacing = function() return 0 end,
    GetShapeshiftForm = function() return W.stance end,
    GetNumShapeshiftForms = function() return #W.forms end,
    GetShapeshiftFormInfo = function( i ) if W.forms[ i ] then return ICON, i == W.stance, true, W.forms[ i ] end end,
    GetShapeshiftFormID = function() return W.formID end,
    GetComboPoints = function( u, t ) return ( t == "target" or t == nil ) and W.target and W.combo or 0 end,
    CheckInteractDistance = function( u ) return UnitData( u ) ~= nil end,
    UnitInPhase = function( u ) return u == "player" or UnitData( u ) ~= nil end,
    UnitPhaseReason = function() return nil end,
    UnitIsPVP = function() return false end,
    UnitIsVisible = function( u ) return u == "player" or UnitData( u ) ~= nil end,
    UnitGetTotalAbsorbs = function() return 0 end,
    UnitGetIncomingHeals = function() return 0 end,
    UnitBuff = function( u, i, f ) return UnpackAura( AuraByIndex( u, i, "HELPFUL" ) ) end,
    UnitDebuff = function( u, i, f ) return UnpackAura( AuraByIndex( u, i, "HARMFUL" ) ) end,
    UnitAura = function( u, i, f ) return UnpackAura( AuraByIndex( u, i, f ) ) end,

    -- Spells.
    GetSpellInfo = GetSpellInfo,
    GetSpellTexture = function( x ) return ResolveSpell( x ) and ICON or nil end,
    GetSpellDescription = function( x ) return ResolveSpell( x ) and "" or nil end,
    GetSpellLink = function( x ) local id = ResolveSpell( x ); return id and ( "|cff71d5ff|Hspell:" .. id .. "|h[" .. DATA.spells[ id ][ 1 ] .. "]|h|r" ) or nil end,
    GetSpellCooldown = SpellCooldown,
    GetSpellPowerCost = SpellPowerCost,
    GetSpellCharges = function() return nil end,
    IsPlayerSpell = function( id ) return known[ id ] == true end,
    IsSpellKnown = function( id, pet ) return not pet and known[ id ] == true end,
    IsSpellKnownOrOverridesKnown = function( id, pet ) return not pet and known[ id ] == true end,
    IsUsableSpell = function( x ) return IsKnown( x ), false end,
    IsCurrentSpell = function() return false end,
    IsAutoRepeatSpell = function( x ) local id = ResolveSpell( x ); return W.autoRepeat and ( id == 75 or id == 5019 ) or false end,
    IsSpellInRange = function( x, u ) return UnitData( u ) and 1 or nil end,
    IsHarmfulSpell = function() return true end, IsHelpfulSpell = function() return false end,
    SpellIsTargeting = function() return false end,
    GetNumSpellTabs = function() return 0 end, GetSpellTabInfo = function() return nil end,
    GetSpellBookItemInfo = function() return nil end, GetSpellBookItemName = function() return nil end,
    HasPetSpells = function() return nil end, GetPetActionInfo = function() return nil end,
    GetNumTalentTabs = function() return 3 end, GetNumTalents = function() return 0 end,
    GetTalentInfo = function() return nil end,
    GetTalentTabInfo = function( i )
        local pts = {}
        for n in BUILD:gmatch( "%d+" ) do pts[ #pts + 1 ] = tonumber( n ) end
        return i, "Tab" .. i, "", ICON, pts[ i ] or 0
    end,
    GetActiveTalentGroup = function() return 1 end, GetNumTalentGroups = function() return 1 end,

    -- Items.
    GetItemInfo = GetItemInfo,
    GetItemInfoInstant = ItemInfoInstant,
    GetItemCount = function( x ) return W.itemCounts[ ItemID( x ) or 0 ] or 0 end, GetItemSpell = function() return nil end, GetItemIcon = function( x ) return DATA.items[ ItemID( x ) or 0 ] and 134400 or nil end,
    GetItemCooldown = function() return 0, 0, 1 end,
    IsUsableItem = function() return false end,
    IsEquippedItem = function( x ) local id = ItemID( x ); for _, e in pairs( W.equip ) do if e == id then return true end end return false end,
    HasWandEquipped = function() return W.equip[ 18 ] ~= nil and DATA.equipLoc ~= nil and DATA.equipLoc[ W.equip[ 18 ] ] == "INVTYPE_RANGEDRIGHT" end,
    IsEquippedItemType = function( t )
        local wanted = { Shields = "INVTYPE_SHIELD" }
        for _, e in pairs( W.equip ) do if DATA.equipLoc and DATA.equipLoc[ e ] == wanted[ t ] then return true end end
        return false
    end,
    IsItemInRange = function( x, u ) return UnitData( u ) ~= nil end,
    GetInventoryItemID = function( u, slot ) if u == "player" then return W.equip[ slot ] end end,
    GetInventoryItemLink = function( u, slot ) if u == "player" and W.equip[ slot ] then return select( 2, GetItemInfo( W.equip[ slot ] ) ) end end,
    GetInventoryItemTexture = function() return nil end, GetInventoryItemCooldown = function() return 0, 0, 0 end,
    GetInventorySlotInfo = function() return 1 end, GetWeaponEnchantInfo = function()
        local mh, oh = W.enchants.mh, W.enchants.oh
        return mh ~= nil, mh and mh.remaining * 1000 or 0, 0, mh and mh.id or nil,
            oh ~= nil, oh and oh.remaining * 1000 or 0, 0, oh and oh.id or nil
    end,
    GetTotemInfo = function( slot )
        local t = W.totems[ slot ]
        if not t then return false, "", 0, 0, 0 end
        return true, t.name, W.time - ( t.duration - t.remaining ), t.duration, ICON
    end,
    Item = Item,

    -- Action bars / bindings.
    GetBindingKey = function() return nil end, GetBindingText = function( k ) return k end,
    GetActionInfo = function() return nil end, GetActionTexture = function() return nil end, HasAction = function() return false end,
    GetMacroInfo = function() return nil end, GetMacroSpell = function() return nil end, GetMacroItem = function() return nil end,
    SetOverrideBindingClick = function() end, ClearOverrideBindings = function() end,
    RegisterStateDriver = function() end, UnregisterStateDriver = function() end, RegisterUnitWatch = function() end,

    -- Combat log.
    CombatLogGetCurrentEventInfo = function() if W.cleu then return unpack( W.cleu, 1, W.cleu.n ) end end,

    -- XML-created frames.
    UIParent = NewFrame( "Frame", "UIParent" ),
    Minimap = NewFrame( "Frame", "Minimap" ),
    DEFAULT_CHAT_FRAME = NewFrame( "ScrollingMessageFrame", "ChatFrame1" ),
    PixelUtil = setmetatable( { GetNearestPixelSize = function( v ) return v end, GetPixelToUIUnitFactor = function() return 1 end },
        { __index = function() return function() end end } ),
    RAID_CLASS_COLORS = setmetatable( {}, { __index = function() return { r = 1, g = 1, b = 1, colorStr = "ffffffff", GenerateHexColor = function() return "ffffffff" end } end } ),
    ITEM_QUALITY_COLORS = setmetatable( {}, { __index = function() return { r = 1, g = 1, b = 1, hex = "|cffffffff" } end } ),
    NORMAL_FONT_COLOR = { r = 1, g = 0.82, b = 0, GetRGB = function() return 1, 0.82, 0 end },
    HIGHLIGHT_FONT_COLOR = { r = 1, g = 1, b = 1, GetRGB = function() return 1, 1, 1 end },
    NORMAL_FONT_COLOR_CODE = "|cffffd200", HIGHLIGHT_FONT_COLOR_CODE = "|cffffffff", FONT_COLOR_CODE_CLOSE = "|r",
    RED_FONT_COLOR_CODE = "|cffff2020", GREEN_FONT_COLOR_CODE = "|cff20ff20", GRAY_FONT_COLOR_CODE = "|cff808080",
    SlashCmdList = {}, hash_SlashCmdList = {}, StaticPopupDialogs = {}, UISpecialFrames = {},
    Mixin = function( obj, ... )
        for i = 1, select( "#", ... ) do
            for k, v in pairs( ( select( i, ... ) ) ) do obj[ k ] = v end
        end
        return obj
    end,
    CreateFromMixins = function( ... ) return api.Mixin( {}, ... ) end,
    BackdropTemplateMixin = setmetatable( {}, { __index = function() return function() end end } ),
    WOW_PROJECT_ID = 2, WOW_PROJECT_CLASSIC = 2, WOW_PROJECT_MAINLINE = 1,
}

api.DEFAULT_CHAT_FRAME.AddMessage = function( _, msg ) io.write( "  [chat] " .. tostring( msg ):gsub( "|c%x%x%x%x%x%x%x%x", "" ):gsub( "|r", "" ) .. "\n" ) end
api.GameTooltip = NewFrame( "GameTooltip", "GameTooltip" )

-- Namespaces with modelled members; everything else in them is a permissive mock.
local function Namespace( name, members )
    return setmetatable( members, { __index = function( t, k ) local v = Mock( name .. "." .. k ); rawset( t, k, v ); return v end } )
end

api.C_Timer = Namespace( "C_Timer", {
    After = function( _, fn ) timers[ #timers + 1 ] = fn end,
    NewTimer = function( _, fn ) timers[ #timers + 1 ] = fn; return Mock( "Timer" ) end,
    NewTicker = function() return Mock( "Ticker" ) end,
} )
api.C_EventUtils = Namespace( "C_EventUtils", { IsEventValid = function( e ) return DATA.events[ e ] == true end } )
api.C_Item = Namespace( "C_Item", {
    DoesItemExistByID = DoesItemExistByID,
    GetItemInfo = GetItemInfo,
    GetItemInfoInstant = api.GetItemInfoInstant,
    GetItemNameByID = function( id ) return DATA.items[ id ] end,
    IsItemDataCachedByID = function() return true end,
    RequestLoadItemDataByID = function() end,
    GetItemCount = function( x ) return W.itemCounts[ ItemID( x ) or 0 ] or 0 end,
    IsEquippedItem = function() return false end,
    GetItemSpell = function() return nil end,
    GetItemIconByID = function() return 134400 end,
    IsItemInRange = api.IsItemInRange,
} )
api.C_Container = Namespace( "C_Container", { GetItemCooldown = function() return 0, 0, 1 end, GetContainerNumSlots = function() return 0 end } )
api.C_Spell = Namespace( "C_Spell", {
    GetSpellInfo = SpellInfoTable,
    GetSpellName = function( x ) local id = ResolveSpell( x ); return id and DATA.spells[ id ][ 1 ] end,
    GetSpellTexture = api.GetSpellTexture,
    DoesSpellExist = function( x ) return ResolveSpell( x ) ~= nil end,
    IsSpellDataCached = function() return true end,
    RequestLoadSpellData = function() end,
    GetSpellCooldown = function( x ) local s, d = SpellCooldown( x ); return { startTime = s, duration = d, isEnabled = true, modRate = 1 } end,
    GetSpellCharges = function() return nil end,
    IsSpellUsable = function( x ) return IsKnown( x ), false end,
    GetSpellPowerCost = SpellPowerCost,
    IsCurrentSpell = function() return false end,
    GetSpellDescription = function() return "" end,
    GetSpellLink = api.GetSpellLink,
    IsSpellInRange = function( x, u ) return UnitData( u ) ~= nil end,
} )
api.C_SpellBook = Namespace( "C_SpellBook", {
    IsSpellKnown = function( id ) return known[ id ] == true end,
    IsSpellInSpellBook = function( id ) return known[ id ] == true end,
    GetNumSpellBookSkillLines = function() return 0 end,
} )
api.C_UnitAuras = Namespace( "C_UnitAuras", {
    GetAuraDataByIndex = AuraByIndex,
    GetBuffDataByIndex = function( u, i ) return AuraByIndex( u, i, "HELPFUL" ) end,
    GetDebuffDataByIndex = function( u, i ) return AuraByIndex( u, i, "HARMFUL" ) end,
    GetPlayerAuraBySpellID = function( id ) for _, a in ipairs( W.buffs ) do if a.spellID == id then return AuraData( a, "player" ) end end end,
    GetAuraDataBySpellName = function() return nil end,
    GetAuraSlots = function() return nil end,
} )
api.C_NamePlate = Namespace( "C_NamePlate", {
    GetNamePlates = function()
        local out = {}
        if W.target then out[ 1 ] = { namePlateUnitToken = "nameplate1" } end
        for i in ipairs( W.plates ) do out[ #out + 1 ] = { namePlateUnitToken = "nameplate" .. ( i + 1 ) } end
        return out
    end,
    GetNamePlateForUnit = function( u ) if UnitData( u ) then return { namePlateUnitToken = u } end end,
} )
api.C_SpecializationInfo = Namespace( "C_SpecializationInfo", {
    GetActiveSpecGroup = function() return 1 end,
    GetNumSpecializationsForClassID = function() return 3 end,
    GetSpecializationInfo = function( i ) local _, n, d, ic, p = api.GetTalentTabInfo( i ); return i, n, d, ic, nil, nil, p end,
} )
api.C_AddOns = Namespace( "C_AddOns", {
    GetAddOnMetadata = function( _, key ) return meta[ key ] end,
    IsAddOnLoaded = function() return false end,
    LoadAddOn = function() return false end,
    GetNumAddOns = function() return 0 end,
} )
api.C_LossOfControl = Namespace( "C_LossOfControl", {
    GetActiveLossOfControlDataCount = function() return 0 end,
    GetActiveLossOfControlData = function() return nil end,
} )
api.C_Seasons = Namespace( "C_Seasons", { GetActiveSeason = function() return nil end, HasActiveSeason = function() return false end } )
api.AuraUtil = Namespace( "AuraUtil", { UnpackAuraData = UnpackAura, ForEachAura = function() end } )

-- Install the API, dropping (and reporting) stubs for names the Era client doesn't have.
local LUA_OK = { bit = true, time = true, date = true, sort = true, floor = true, ceil = true, abs = true, max = true,
    min = true, mod = true, random = true, sqrt = true, format = true, gsub = true, gmatch = true, WOW_PROJECT_ID = true,
    WOW_PROJECT_CLASSIC = true, WOW_PROJECT_MAINLINE = true, PixelUtil = true, Item = true, AuraUtil = true }
local dropped = {}
for k, v in pairs( api ) do
    if CLIENT[ k ] or LUA_OK[ k ] or DATA.strings[ k ] then
        _G[ k ] = v
    else
        dropped[ #dropped + 1 ] = k
    end
end
table.sort( dropped )
if #dropped > 0 then print( "Harness stubs not on the Era client (dropped): " .. table.concat( dropped, ", " ) ) end

string.trim = string.trim or api.strtrim
string.split = function( s, d, n ) return api.strsplit( d, s, n ) end
table.wipe = api.wipe

-- FrameXML constants with their real values (INVSLOT_*, CR_*, BOOKTYPE_SPELL, ...).
for k, v in pairs( DATA.constants or {} ) do
    if rawget( _G, k ) == nil then _G[ k ] = v end
end

-- Real Enum tables from the client.
do
    local enum = loadstring( ReadFile( API_DIR .. "LuaEnum.lua" ) or "" )
    if enum then enum() end
end

-- Deprecated globals that alias Enum values (present while loadDeprecationFallbacks is on, the default).
for name, path in pairs( DATA.enumAliases or {} ) do
    local v = _G
    for part in path:gmatch( "[^%.]+" ) do v = type( v ) == "table" and rawget( v, part ) or nil end
    if v ~= nil and rawget( _G, name ) == nil then _G[ name ] = v end
end

-- Unknown globals: GlobalStrings and client APIs resolve; anything else is nil, as on the client.
local unmodelled = {}
setmetatable( _G, { __index = function( t, k )
    if type( k ) ~= "string" then return nil end
    local s = DATA.strings[ k ]
    if s then return s end
    if CLIENT[ k ] then
        unmodelled[ k ] = true
        local v = Mock( k )
        rawset( t, k, v )
        return v
    end
end } )


-- Load the addon ---------------------------------------------------------------------------------------------

local ADDON, ns = "Hekili", {}
local loaded = 0

local function LoadLua( path )
    local src = assert( ReadFile( path ), "missing file: " .. path ):gsub( "^\239\187\191", "" )
    local chunk = assert( loadstring( src, "@" .. path ) )
    chunk( ADDON, ns )
    loaded = loaded + 1
end

local function LoadXML( path )
    local src = assert( ReadFile( path ), "missing file: " .. path ):gsub( "<!%-%-.-%-%->", "" )
    local dir = path:match( "^(.*)/" ) or "."
    for kind, file in src:gmatch( "<(%a+)%s+file%s*=%s*\"([^\"]+)\"" ) do
        local p = dir .. "/" .. file:gsub( "\\", "/" )
        -- The client keeps loading the remaining files after an error in one of them.
        local ok, err = pcall( function() if kind == "Script" then LoadLua( p ) elseif kind == "Include" then LoadXML( p ) end end )
        if not ok then Report( "load " .. p, err ) end
    end
end

for _, file in ipairs( files ) do
    local ok, err = pcall( function() if file:match( "%.xml$" ) then LoadXML( file ) else LoadLua( file ) end end )
    if not ok then Report( "load " .. file, err ) end
end
print( string.format( "Loaded %d files from %s (flavor %s), build %s, %d known spells.", loaded, TOC, tostring( meta[ "X-Flavor" ] ), BUILD,
    ( function() local n = 0 for _ in pairs( known ) do n = n + 1 end return n end )() ) )

local function RunTimers()
    local ran = 0
    while #timers > 0 and ran < 1000 do
        local fn = table.remove( timers, 1 )
        local ok, err = pcall( fn )
        if not ok then Report( "timer", err ) end
        ran = ran + 1
    end
end

local function Step( name, fn )
    local ok, err = pcall( fn )
    if not ok then Report( name, err ) end
    RunTimers()
end

-- HARNESS_SAVEDVARS=<path to a Hekili.lua SavedVariables file>: start from that saved profile, as the client
-- does before ADDON_LOADED (exercises upgrades from an existing profile).
do
    local sv = os.getenv( "HARNESS_SAVEDVARS" )
    if sv then
        local chunk = assert( loadfile( sv ) )
        chunk()
        print( "Loaded saved variables from " .. sv .. " (HekiliDB " .. ( rawget( _G, "HekiliDB" ) and "present" or "missing" ) .. ")" )
    end
end

-- Class defaults (power type, shapeshift bar, gear) before login.
if CLASSDEF.reset then
    CLASSDEF.reset( { W = W, LEVEL = LEVEL, BUILD = BUILD, DATA = DATA, Aura = function( id, r ) return { spellID = id, duration = r or 0, expires = r and ( W.time + r ) or 0 } end } )
end

Step( "ADDON_LOADED", function() Fire( "ADDON_LOADED", ADDON ) end )
Step( "PLAYER_LOGIN", function() W.loggedIn = true; Fire( "PLAYER_LOGIN" ) end )
Step( "PLAYER_ENTERING_WORLD", function() Fire( "PLAYER_ENTERING_WORLD", true, false ) end )
Step( "SPELLS_CHANGED", function() Fire( "SPELLS_CHANGED" ) end )

local Hekili = rawget( _G, "Hekili" )
if not Hekili or not Hekili.Class then
    print( "Hekili did not load." )
    os.exit( 1 )
end

local function count( t ) local n = 0 for _ in pairs( t or {} ) do n = n + 1 end return n end
local spec = Hekili.Class.specs[ classID ]
if not spec then Report( "spec", "class module for " .. CLASS .. " did not register spec " .. classID ) os.exit( 1 ) end

print( string.format( "Spec %d: %d abilities, %d auras, %d talents, %d settings, %d packs.",
    classID, count( spec.abilities ), count( spec.auras ), count( spec.talents ), count( spec.settings ), count( spec.packs ) ) )

local state = Hekili.State
print( "Detected spec: " .. tostring( rawget( state.spec, "id" ) ) )

do
    local names = {}
    for name, pack in pairs( Hekili.DB and Hekili.DB.profile.packs or {} ) do
        if type( pack ) == "table" and pack.builtIn then names[ #names + 1 ] = name end
    end
    table.sort( names )
    print( "Built-in priorities in the profile: " .. ( #names > 0 and table.concat( names, ", " ) or "none" ) )
    local specDB = Hekili.DB and Hekili.DB.profile.specs[ classID ]
    print( "Active priority: " .. tostring( specDB and specDB.package ) )
end

do
    local gcd = Hekili.Class.abilities.global_cooldown
    local id = gcd and gcd.id
    print( "GCD tracked through spell: " .. tostring( id ) .. " (" .. tostring( id and DATA.spells[ id ] and DATA.spells[ id ][ 1 ] or "not on Era" ) .. ")" )
end

-- Talents as the engine sees them.
do
    local on = {}
    for k, t in pairs( Hekili.Class.talents ) do
        local st = rawget( state.talent, k )
        if st and st.enabled then on[ #on + 1 ] = k .. " " .. tostring( st.rank ) end
    end
    table.sort( on )
    print( "Talents detected (" .. #on .. "): " .. table.concat( on, ", " ) )
end

-- HARNESS_DUMP=<file>: write every registered ability/aura (shared and class) for tools/check_shared.py.
do
    local path = os.getenv( "HARNESS_DUMP" )
    if path then
        local f = assert( io.open( path, "w" ) )
        local seen = {}
        for _, kind in ipairs( { "abilities", "auras" } ) do
            for key, a in pairs( Hekili.Class[ kind ] ) do
                if type( key ) == "string" and type( a ) == "table" and not seen[ a ] then
                    seen[ a ] = true
                    local item = rawget( a, "item" )
                    local ids = {}
                    local copy = rawget( a, "copy" )
                    if type( copy ) == "table" then for _, c in ipairs( copy ) do if type( c ) == "number" then ids[ #ids + 1 ] = c end end
                    elseif type( copy ) == "number" then ids[ 1 ] = copy end
                    f:write( string.format( "%s\t%s\t%s\t%s\t%s\n", kind == "abilities" and "ability" or "aura", key,
                        tostring( rawget( a, "id" ) or 0 ), type( item ) == "number" and item or ( type( item ) == "function" and "fn" or "-" ),
                        table.concat( ids, " " ) ) )
                end
            end
        end
        f:close()
    end
end

-- Compile every priority entry.
do
    local compileErrors = {}
    local origError = Hekili.Error
    Hekili.Error = function( self, msg ) compileErrors[ #compileErrors + 1 ] = tostring( msg ) end
    local okLS, errLS = pcall( function() Hekili.Scripts:LoadScripts() end )
    Hekili.Error = origError
    if not okLS then Report( "LoadScripts", errLS ) end

    local compiled, withLua = 0, 0
    for id, script in pairs( Hekili.Scripts.DB ) do
        compiled = compiled + 1
        if script.Lua then withLua = withLua + 1 end
        if script.Error then compileErrors[ #compileErrors + 1 ] = id .. ": " .. tostring( script.Error ) end
    end
    print( string.format( "Priority entries compiled: %d (%d with conditions), %d error(s).", compiled, withLua, #compileErrors ) )
    for _, e in ipairs( compileErrors ) do Report( "script", e ) end
end


-- Options panel: walk the AceConfig tree like the dialog does, calling the display callbacks of every node.
do
    local optErrors, visited = {}, 0
    local okBuild, errBuild = pcall( function() Hekili:RefreshOptions() end )
    if not okBuild then Report( "RefreshOptions", errBuild ) end

    local root = Hekili.Options
    local function call( node, field, info, path )
        local f = node[ field ]
        if type( f ) == "string" and info.handler and type( info.handler[ f ] ) == "function" then f = info.handler[ f ] end
        if type( f ) ~= "function" then return end
        local ok, err
        if type( node[ field ] ) == "string" then ok, err = pcall( f, info.handler, info ) else ok, err = pcall( f, info ) end
        if not ok then
            local key = field .. ": " .. tostring( err )
            if not optErrors[ key ] then optErrors[ key ] = path end
        end
    end

    local function walk( node, path, keys, handler, depth )
        if type( node ) ~= "table" or depth > 12 then return end
        handler = node.handler or handler
        visited = visited + 1
        local info = { options = root, handler = handler, type = node.type, option = node, arg = node.arg }
        for i, k in ipairs( keys ) do info[ i ] = k end

        -- Like AceConfigDialog: a hidden node (and its children) is never rendered.
        local hidden = node.hidden
        if type( hidden ) == "string" and handler and type( handler[ hidden ] ) == "function" then hidden = handler[ hidden ] end
        if type( hidden ) == "function" then
            local ok, h = pcall( hidden, info )
            if not ok then optErrors[ "hidden: " .. tostring( h ) ] = path; return end
            if h then return end
        elseif hidden == true then
            return
        end

        local fields = { "name", "desc", "disabled", "image", "width" }
        if node.type ~= "group" then fields[ #fields + 1 ] = "values"; fields[ #fields + 1 ] = "get" end
        for _, field in ipairs( fields ) do
            call( node, field, info, path )
        end
        for _, container in ipairs( { "args", "plugins" } ) do
            local children = node[ container ]
            if type( children ) == "table" then
                if container == "plugins" then
                    for _, plugin in pairs( children ) do
                        for k, child in pairs( plugin ) do
                            local nk = {}; for i, v in ipairs( keys ) do nk[ i ] = v end; nk[ #nk + 1 ] = k
                            walk( child, path .. "." .. tostring( k ), nk, handler, depth + 1 )
                        end
                    end
                else
                    for k, child in pairs( children ) do
                        local nk = {}; for i, v in ipairs( keys ) do nk[ i ] = v end; nk[ #nk + 1 ] = k
                        walk( child, path .. "." .. tostring( k ), nk, handler, depth + 1 )
                    end
                end
            end
        end
    end

    if type( root ) == "table" then walk( root, "Hekili", {}, root.handler or Hekili, 0 ) end
    local n = 0
    for msg, path in pairs( optErrors ) do
        n = n + 1
        Report( "options " .. path, msg )
    end
    print( string.format( "Options panel: %d nodes walked, %d distinct callback error(s).", visited, n ) )
end

-- Combat scenarios -------------------------------------------------------------------------------------------

local function Target( health, boss )
    return { guid = "Creature-0-1-1-1-1234-0000000001", name = "Training Target", health = health or 100000, healthMax = 100000, boss = boss }
end

local function Recs( display )
    local d = Hekili.DisplayPool and Hekili.DisplayPool[ display ]
    if not d or not d.Recommendations then return "(no display)" end
    local out = {}
    for i = 1, 4 do
        local r = d.Recommendations[ i ]
        if r and r.actionName then
            out[ #out + 1 ] = r.actionName .. ( r.time and r.time > 0 and string.format( "@%.1f", r.time ) or "" )
        end
    end
    return #out > 0 and table.concat( out, " > " ) or "(nothing)"
end

local function Tick( n, debugLast )
    local engine = Hekili.Engine
    for i = 1, n do
        -- Hekili logs one update and then turns debugging off; for HARNESS_DEBUG, log one near the end.
        if debugLast and i == n - 10 then Hekili.ActiveDebug = true end
        W.time = W.time + 0.1
        Hekili.freshFrame = true
        for _, f in ipairs( frames ) do
            local onUpdate = f.__scripts.OnUpdate
            if onUpdate and f.__shown then
                local ok, err = pcall( onUpdate, f, 0.1 )
                if not ok then Report( "OnUpdate " .. tostring( f:GetName() ), err ) end
            end
        end
        RunTimers()
    end
end

local function CLEU( subtype, sourceGUID, destGUID, ... )
    W.cleu = { n = 11 + select( "#", ... ), W.time, subtype, false, sourceGUID, "x", 0, 0, destGUID, "y", 0, 0, ... }
    Fire( "COMBAT_LOG_EVENT_UNFILTERED" )
    W.cleu = nil
end

-- Helpers for the class scenario files.
local H = {
    W = W, Fire = Fire, CLEU = CLEU, GUIDS = GUIDS, LEVEL = LEVEL, BUILD = BUILD, DATA = DATA, Hekili = Hekili, ns = ns,
    Target = Target,
    -- A player buff / target debuff entry: H.Aura( spellID, remaining, stacks, duration ).
    Aura = function( spellID, remaining, stacks, duration )
        return { spellID = spellID, count = stacks or 0, duration = duration or remaining or 0, expires = remaining and ( W.time + remaining ) or 0 }
    end,
    -- n extra hostile units in melee range (nameplates 2..n+1).
    Plates = function( n )
        W.plates = {}
        for i = 1, n do W.plates[ i ] = { guid = "Creature-0-1-1-1-1234-00000000" .. ( 10 + i ), health = 100000, healthMax = 100000 } end
        for i = 1, n + 1 do Fire( "NAME_PLATE_UNIT_ADDED", "nameplate" .. i ) end
    end,
    -- A real cast by the player, as the client reports it (combat log + unit event).
    Cast = function( spellID, destGUID )
        CLEU( "SPELL_CAST_SUCCESS", GUIDS.player, destGUID or ( W.target and W.target.guid ) or "", spellID,
            DATA.spells[ spellID ] and DATA.spells[ spellID ][ 1 ] or "Spell", 1 )
        Fire( "UNIT_SPELLCAST_SUCCEEDED", "player", "Cast-3-0-0-0-" .. spellID .. "-0", spellID )
    end,
}
H.Pet = function( name, family )
    W.pet = { guid = "Pet-0-1-1-1-1-0000000099", name = name or "Pet", family = family, health = 2000, healthMax = 2000, friendly = true }
    Fire( "UNIT_PET", "player" )
end

-- A class setting for this scenario only: H.Setting( "tank_mode", "always" ).  Restored before the next scenario.
local changedSettings = {}
H.Setting = function( key, value )
    local specDB = Hekili.DB.profile.specs[ classID ]
    if changedSettings[ key ] == nil then changedSettings[ key ] = { specDB.settings[ key ] } end
    specDB.settings[ key ] = value
end

local SCENARIOS = CLASSDEF.scenarios( H )

local function ResetWorld()
    local specDB = Hekili.DB.profile.specs[ classID ]
    for key, old in pairs( changedSettings ) do specDB.settings[ key ] = old[ 1 ] end
    changedSettings = {}
    W.groupSize, W.inCombat, W.target, W.plates, W.buffs, W.debuffs = 0, false, nil, {}, {}, {}
    W.casting, W.autoRepeat, W.gcdStart, W.cooldowns, W.aggro = nil, false, nil, {}, false
    W.speed = 0
    W.totems, W.enchants = {}, {}
    W.cvars.nameplateShowEnemies = "1"
    W.health = W.healthMax
    if CLASSDEF.reset then CLASSDEF.reset( H ) end
end

-- LibRangeCheck derives distance from per-item/spell ranges we don't model; answer from the world model instead.
do
    local RC = LibStub and LibStub( "LibRangeCheck-3.0", true )
    if RC then
        RC.GetRange = function( self, unit )
            local d = UnitData( unit )
            if not d then return nil, nil end
            local dist = d.distance or 3
            if dist <= 5 then return 0, 5 end
            return dist - 2, dist + 2
        end
    end
end

-- HARNESS_DEBUG=<part of a scenario name>: print Hekili's own decision log (what a Snapshot shows) for it.
local DEBUG_SCENARIO = os.getenv( "HARNESS_DEBUG" )

for _, sc in ipairs( SCENARIOS ) do
    local debugThis = DEBUG_SCENARIO and sc[ 1 ]:find( DEBUG_SCENARIO, 1, true )
    Hekili.ActiveDebug = nil
    -- Each scenario is a separate pull: leave combat and let enough time pass that Hekili doesn't resume the last fight.
    W.inCombat = false
    Fire( "PLAYER_REGEN_ENABLED" )
    W.time = W.time + 30
    ResetWorld()
    local ok, err = pcall( sc[ 2 ] )
    if not ok then Report( "scenario setup", err ) end
    Fire( "PLAYER_TARGET_CHANGED" )
    Fire( W.inCombat and "PLAYER_REGEN_DISABLED" or "PLAYER_REGEN_ENABLED" )
    Fire( "UNIT_POWER_UPDATE", "player", ( { [ 0 ] = "MANA", [ 1 ] = "RAGE", [ 3 ] = "ENERGY" } )[ W.powerType ] or "MANA" )
    Fire( "UNIT_POWER_FREQUENT", "player", "COMBO_POINTS" )
    Fire( "PLAYER_EQUIPMENT_CHANGED", 16 )
    Fire( "UNIT_AURA", "player" )
    Fire( "UPDATE_SHAPESHIFT_FORM" )
    if Hekili.Engine then Hekili.Engine.criticalUpdate = true end
    Tick( 40, debugThis )
    local okT, targets = pcall( Hekili.GetNumTargets, Hekili, true )
    print( string.format( "  %-50s Primary: %-55s targets: %s", sc[ 1 ], Recs( "Primary" ), okT and tostring( targets ) or ( "error " .. tostring( targets ) ) ) )
    if os.getenv( "HARNESS_TARGETDEBUG" ) and Hekili.TargetDebug then print( "    " .. Hekili.TargetDebug:gsub( "\n", "\n    " ) ) end
    W.gcdStart = nil
    if debugThis then
        -- Hekili's own decision log for the Primary display's last update (what a Snapshot shows).
        local d = ns.debug and ns.debug.Primary
        if d and d.log then
            for i = 1, math.min( ( d.index or #d.log + 1 ) - 1, 600 ) do print( "      | " .. tostring( d.log[ i ] ) ) end
        else
            print( "      | (no debug log recorded)" )
        end
        Hekili.ActiveDebug = nil
    end
end

-- Report ----------------------------------------------------------------------------------------------------

local um = {}
for k in pairs( unmodelled ) do um[ #um + 1 ] = k end
table.sort( um )
print( "Client APIs used but not modelled (permissive mocks): " .. table.concat( um, ", " ) )

if #errors > 0 then
    print( "\n" .. #errors .. " error(s):" )
    local seen = {}
    for _, e in ipairs( errors ) do
        if not seen[ e ] then print( "  " .. e:sub( 1, 400 ) ); seen[ e ] = true end
    end
    os.exit( 1 )
end
print( "\nNo errors." )
