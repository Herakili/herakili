-- Offline test harness: runs the addon against a model of the Classic Era client.
--
-- Usage (from the repository root, after tools/fetch-era-api.sh and python3 tools/era_data.py):
--   luajit tools/harness.lua [Hekili_Vanilla.toc] [WARRIOR] [17/34/0]
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
local BUILD = arg[ 3 ] or "17/34/0"
-- Character level (HARNESS_LEVEL); spells above it are unknown.  Use build 0/0/0 below level 10.
local LEVEL = tonumber( os.getenv( "HARNESS_LEVEL" ) or "" ) or 60

local CLASSES = {
    WARRIOR = { "Warrior", 1 }, PALADIN = { "Paladin", 2 }, HUNTER = { "Hunter", 3 }, ROGUE = { "Rogue", 4 },
    PRIEST = { "Priest", 5 }, SHAMAN = { "Shaman", 7 }, MAGE = { "Mage", 8 }, WARLOCK = { "Warlock", 9 }, DRUID = { "Druid", 11 },
}
local className, classID = CLASSES[ CLASS ][ 1 ], CLASSES[ CLASS ][ 2 ]

-- Talent builds: points per tree (in-game order) and the talent rank spells learned.
local BUILDS = {
    WARRIOR = {
        [ "17/34/0" ] = { -- Fury (dual wield)
            12663, 12659, 12679, 12963, 12867, 16494,                       -- Arms: Imp. HS 2, Imp. Rend 3, TM 5, Imp. OP 2, DW 3, Impale 2
            12838, 12856, 12861, 23588, 20503, 13048, 12328, 12974, 23881,  -- Fury: BV 5, Cruelty 5, IBS 5, DWS 5, Imp. Exec 2, Enrage 5, DW, Flurry 5, BT
        },
        [ "31/20/0" ] = { -- Arms (two-hander)
            12664, 12659, 12679, 12963, 12296, 12867, 12714, 16494, 12292, 12785, 12294, -- Arms: ... Anger Mgmt, 2H Spec 5, Impale 2, SS, Axe 5, MS
            12838, 12856, 13002, 12861,                                     -- Fury: BV 5, Cruelty 5, UW 5, IBS 5
        },
        [ "0/0/0" ] = {},
    },
}

local function ReadFile( path )
    local f = io.open( path, "r" )
    if not f then return nil end
    local s = f:read( "*a" )
    f:close()
    return s
end

local API_DIR = ( arg[ 0 ]:match( "^(.*)/" ) or "." ) .. "/.era-api/"
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
    rage = 0, stance = ( LEVEL >= 30 ) and 3 or 1, health = 4000, healthMax = 4000,
    target = nil,    -- { guid, name, health, healthMax, boss }
    plates = {},     -- extra hostile units in melee range: { guid, health, healthMax }
    buffs = {},      -- player buffs: { spellID, duration, expires }
    debuffs = {},    -- target debuffs
    cleu = nil,      -- current combat log payload
    cooldowns = {},  -- spellID -> { start, duration }
    cvars = { nameplateShowEnemies = "1" }, -- overrides of the client defaults
    groupSize = 0,   -- GetNumGroupMembers(): 0 solo, 2-5 party, 6-40 raid
}

local function UnitData( unit )
    if unit == "target" then return W.target end
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
    local build = ( BUILDS[ CLASS ] or {} )[ BUILD ] or {}
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


-- Items ------------------------------------------------------------------------------------------------------

local function ItemID( x )
    if type( x ) == "number" then return x end
    if type( x ) == "string" then return tonumber( x ) or tonumber( x:match( "item:(%d+)" ) or "" ) end
end

local function GetItemInfo( x )
    local id = ItemID( x )
    local name = id and DATA.items[ id ]
    if not name then return nil end
    return name, "|cffffffff|Hitem:" .. id .. "|h[" .. name .. "]|h|r", 1, 1, 1, "Miscellaneous", "Junk", 20, "", 134400, 0, 15, 0
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
    UnitRace = function() return "Human", "Human", 1 end,
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
    UnitCanAttack = function( a, b ) return UnitData( b ) ~= nil end,
    UnitIsFriend = function( a, b ) return b == "player" end,
    UnitReaction = function( a, b ) return UnitData( b ) and 2 or 5 end,
    UnitIsDead = function( u ) local d = UnitData( u ); return d and d.health <= 0 or false end,
    UnitIsDeadOrGhost = function() return false end,
    UnitHealth = function( u ) if u == "player" then return W.health end local d = UnitData( u ); return d and d.health or 0 end,
    UnitHealthMax = function( u ) if u == "player" then return W.healthMax end local d = UnitData( u ); return d and d.healthMax or 0 end,
    UnitPower = function( u, t ) if u == "player" and ( t == nil or t == 1 ) then return W.rage end return 0 end,
    UnitPowerMax = function( u, t ) if u == "player" and ( t == nil or t == 1 ) then return 100 end return 0 end,
    UnitPowerType = function( u ) return 1, "RAGE" end,
    UnitAffectingCombat = function( u ) return W.inCombat and ( u == "player" or UnitData( u ) ~= nil ) end,
    UnitClassification = function( u ) local d = UnitData( u ); return d and d.boss and "worldboss" or "normal" end,
    UnitCreatureType = function( u ) return UnitData( u ) and "Humanoid" or nil end,
    UnitIsPlayer = function( u ) return u == "player" end,
    UnitIsTapDenied = function() return false end,
    UnitInVehicle = function() return false end, UnitHasVehicleUI = function() return false end, UnitOnTaxi = function() return false end,
    UnitThreatSituation = function() return nil end, UnitDetailedThreatSituation = function() return nil end,
    UnitCastingInfo = function() return nil end, UnitChannelInfo = function() return nil end,
    UnitDamage = function() return 300, 400, 150, 200, 0, 0, 1 end,
    UnitAttackSpeed = function() return 2.6, 1.8 end,
    UnitAttackPower = function() return 1500, 200, 0 end, UnitRangedAttackPower = function() return 0, 0, 0 end,
    UnitStat = function() return 300, 300, 0, 0 end, UnitArmor = function() return 5000, 5000 end,
    GetCritChance = function() return 25 end, GetRangedCritChance = function() return 5 end, GetSpellCritChance = function() return 5 end,
    GetHaste = function() return 0 end, GetMeleeHaste = function() return 0 end, GetRangedHaste = function() return 0 end,
    UnitSpellHaste = function() return 0 end, GetCombatRating = function() return 0 end, GetCombatRatingBonus = function() return 0 end,
    GetUnitSpeed = function() return 0, 7, 7, 4.7 end, GetPlayerFacing = function() return 0 end,
    GetShapeshiftForm = function() return W.stance end,
    GetNumShapeshiftForms = function() return 3 end,
    GetShapeshiftFormInfo = function( i ) local ids = { 2457, 71, 2458 }; return ICON, i == W.stance, true, ids[ i ] end,
    GetComboPoints = function() return 0 end,
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
    GetSpellCharges = function() return nil end,
    IsPlayerSpell = function( id ) return known[ id ] == true end,
    IsSpellKnown = function( id, pet ) return not pet and known[ id ] == true end,
    IsSpellKnownOrOverridesKnown = function( id, pet ) return not pet and known[ id ] == true end,
    IsUsableSpell = function( x ) return IsKnown( x ), false end,
    IsCurrentSpell = function() return false end, IsAutoRepeatSpell = function() return false end,
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
    GetItemCount = function() return 0 end, GetItemSpell = function() return nil end, GetItemIcon = function( x ) return DATA.items[ ItemID( x ) or 0 ] and 134400 or nil end,
    GetItemCooldown = function() return 0, 0, 1 end,
    IsUsableItem = function() return false end, IsEquippedItem = function() return false end, IsEquippedItemType = function() return false end,
    IsItemInRange = function( x, u ) return UnitData( u ) ~= nil end,
    GetInventoryItemID = function() return nil end, GetInventoryItemLink = function() return nil end,
    GetInventoryItemTexture = function() return nil end, GetInventoryItemCooldown = function() return 0, 0, 0 end,
    GetInventorySlotInfo = function() return 1 end, GetWeaponEnchantInfo = function() return nil end,
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
    GetItemCount = function() return 0 end,
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

local function ShoutBuff() return { spellID = 25289, duration = 120, expires = W.time + 100 } end

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

local SCENARIOS = {
    { "Out of combat, target in range, no Battle Shout", function()
        W.inCombat, W.rage, W.target, W.plates, W.buffs = false, 20, Target(), {}, {}
    end },
    { "Combat, 60 rage, single target", function()
        W.inCombat, W.rage, W.target, W.plates, W.buffs = true, 60, Target(), {}, { ShoutBuff() }
    end },
    { "Combat, 10 rage, single target", function()
        W.inCombat, W.rage, W.target, W.plates, W.buffs = true, 10, Target(), {}, { ShoutBuff() }
    end },
    { "Combat, 60 rage, target at 15% (execute)", function()
        W.inCombat, W.rage, W.target, W.plates, W.buffs = true, 60, Target( 15000 ), {}, { ShoutBuff() }
    end },
    { "Combat, 60 rage, 3 enemies in melee", function()
        W.inCombat, W.rage, W.target, W.buffs = true, 60, Target(), { ShoutBuff() }
        W.plates = { { guid = "Creature-0-1-1-1-1234-0000000002", health = 100000, healthMax = 100000 },
                     { guid = "Creature-0-1-1-1-1234-0000000003", health = 100000, healthMax = 100000 } }
        for i = 1, 3 do Fire( "NAME_PLATE_UNIT_ADDED", "nameplate" .. i ) end
    end },
    { "Combat, 60 rage, 3 enemies hit, nameplates OFF", function()
        W.inCombat, W.rage, W.target, W.buffs, W.plates = true, 60, Target(), { ShoutBuff() }, {}
        W.cvars.nameplateShowEnemies = "0"
        -- Damage-based detection: we have recently hit three different mobs (hostile NPC flags 0xa48).
        if os.getenv( "HARNESS_TARGETDEBUG" ) then
            local sp = rawget( Hekili.DB.profile.specs, 1 )
            print( "    profile spec 1: damage=" .. tostring( sp and sp.damage ) .. " nameplates=" .. tostring( sp and sp.nameplates ) .. " damageRange=" .. tostring( sp and sp.damageRange ) )
            local orig = ns.updateTarget
            ns.updateTarget = function( id, t, mine ) print( "    updateTarget " .. tostring( id ) .. " mine=" .. tostring( mine ) ); return orig( id, t, mine ) end
        end
        -- Only ability damage counts (white swings go through Hekili's swing-timer branch instead), so: a Cleave/Whirlwind.
        for i = 1, 3 do
            W.cleu = { n = 23, W.time, "SPELL_DAMAGE", false, GUIDS.player, "Tester", 0x511, 0,
                "Creature-0-1-1-1-1234-000000000" .. i, "Mob", 0xa48, 0, 1680, "Whirlwind", 1, 600, -1, 1, 0, 0, 0, false, false }
            Fire( "COMBAT_LOG_EVENT_UNFILTERED" )
            W.cleu = nil
        end
    end },
    { "Out of combat, Battle Stance, target 20 yd away", function()
        W.cvars.nameplateShowEnemies = "1"
        W.inCombat, W.rage, W.target, W.plates, W.buffs, W.stance = false, 0, Target(), {}, { ShoutBuff() }, 1
        W.target.distance = 20
    end },
    { "Combat, Berserker Stance, 20 rage, target 15 yd away", function()
        W.inCombat, W.rage, W.target, W.plates, W.buffs, W.stance = true, 20, Target(), {}, { ShoutBuff() }, 3
        W.target.distance = 15
    end },
    { "Combat, 60 rage, GCD just triggered", function()
        W.inCombat, W.rage, W.target, W.plates, W.buffs = true, 60, Target(), {}, { ShoutBuff() }
        W.gcdStart = W.time + 3.9 -- the scenario ticks 4 s; this leaves ~1.4 s of GCD at the end
    end },
    -- Raid opener (setting "Open With Sunder Armor" = In raids, the default).
    { "Raid pull: Battle Stance, 0 rage, target 20 yd", function()
        W.groupSize, W.inCombat, W.rage, W.target, W.plates, W.buffs, W.stance = 25, false, 0, Target(), {}, { ShoutBuff() }, 1
        W.target.distance = 20
    end },
    { "Raid: just charged, Battle Stance, 15 rage", function()
        W.groupSize, W.inCombat, W.rage, W.target, W.plates, W.buffs, W.stance = 25, true, 15, Target(), {}, { ShoutBuff() }, 1
    end },
    { "Raid: Battle Stance, 5 rage (no rage for Sunder)", function()
        W.groupSize, W.inCombat, W.rage, W.target, W.plates, W.buffs, W.stance = 25, true, 5, Target(), {}, { ShoutBuff() }, 1
    end },
    { "Raid: Berserker Stance, 30 rage, no Sunder yet", function()
        W.groupSize, W.inCombat, W.rage, W.target, W.plates, W.buffs, W.stance = 25, true, 30, Target(), {}, { ShoutBuff() }, 3
    end },
    { "Raid: Berserker Stance, 30 rage, Sunder already cast", function()
        W.groupSize, W.inCombat, W.rage, W.target, W.plates, W.buffs, W.stance = 25, true, 30, Target(), {}, { ShoutBuff() }, 3
        W.debuffs = { { spellID = 11597, count = 1, duration = 30, expires = W.time + 29 } }
        -- Hekili records real casts from the combat log (SPELL_CAST_SUCCESS).
        CLEU( "SPELL_CAST_SUCCESS", GUIDS.player, W.target.guid, 11597, "Sunder Armor", 1 )
        Fire( "UNIT_SPELLCAST_SUCCEEDED", "player", "Cast-3-0-0-0-11597-0", 11597 )
    end },
    { "Party (5): Berserker Stance, 30 rage", function()
        W.groupSize, W.inCombat, W.rage, W.target, W.plates, W.buffs, W.debuffs, W.stance = 5, true, 30, Target(), {}, { ShoutBuff() }, {}, 3
    end },
    { "Battle Stance, 30 rage, target just dodged", function()
        W.groupSize, W.debuffs = 0, {}
        W.inCombat, W.rage, W.target, W.plates, W.buffs, W.stance = true, 30, Target(), {}, { ShoutBuff() }, 1
        CLEU( "SWING_MISSED", GUIDS.player, W.target.guid, "DODGE", false, 0 )
    end },
}

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
    local ok, err = pcall( sc[ 2 ] )
    if not ok then Report( "scenario setup", err ) end
    Fire( "PLAYER_TARGET_CHANGED" )
    Fire( W.inCombat and "PLAYER_REGEN_DISABLED" or "PLAYER_REGEN_ENABLED" )
    Fire( "UNIT_POWER_UPDATE", "player", "RAGE" )
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
    W.stance = ( LEVEL >= 30 ) and 3 or 1
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
