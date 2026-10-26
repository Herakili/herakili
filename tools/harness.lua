-- Offline load test: loads the addon in TOC order under a stubbed WoW environment.
--
-- Usage (from the repository root): luajit tools/harness.lua [Hekili_Vanilla.toc] [WARRIOR] [17/34/0]
--
-- It cannot simulate combat, but it catches syntax errors, load-time errors and failures in
-- OnInitialize / OnEnable / spec setup (class module, settings and built-in priority packs).

local TOC = arg[ 1 ] or "Hekili_Vanilla.toc"
local CLASS = arg[ 2 ] or "WARRIOR"
-- Talent points per tree, e.g. "17/34/0", used to test the automatic priority selection.
local POINTS = {}
for n in ( arg[ 3 ] or "0/0/0" ):gmatch( "%d+" ) do POINTS[ #POINTS + 1 ] = tonumber( n ) end
local loggedIn = false

local CLASSES = {
    WARRIOR = { "Warrior", 1 }, PALADIN = { "Paladin", 2 }, HUNTER = { "Hunter", 3 }, ROGUE = { "Rogue", 4 },
    PRIEST = { "Priest", 5 }, SHAMAN = { "Shaman", 7 }, MAGE = { "Mage", 8 }, WARLOCK = { "Warlock", 9 }, DRUID = { "Druid", 11 },
}

local function ReadFile( path )
    local f = io.open( path, "r" )
    if not f then return nil end
    local s = f:read( "*a" )
    f:close()
    return s
end

-- TOC metadata and file list.
local meta, files = {}, {}
for line in assert( ReadFile( TOC ), "missing " .. TOC ):gmatch( "[^\r\n]+" ) do
    local k, v = line:match( "^##%s*([%w%-]+):%s*(.-)%s*$" )
    if k then meta[ k ] = v
    elseif not line:match( "^#" ) and line:match( "%S" ) then files[ #files + 1 ] = ( line:gsub( "\\", "/" ):gsub( "%s+$", "" ) ) end
end


-- A permissive mock: any field is a mock, calling it returns nil.
local mockMT = {}
local function Mock( name ) return setmetatable( { __mockname = name }, mockMT ) end
mockMT.__index = function( t, k )
    local v = Mock( rawget( t, "__mockname" ) .. "." .. tostring( k ) )
    rawset( t, k, v )
    return v
end
mockMT.__call = function( self ) return Mock( rawget( self, "__mockname" ) .. "()" ) end

local missingGlobals = {}
local caughtErrors = 0
local timers = {}

-- Frames: record scripts and events so we can fire ADDON_LOADED / PLAYER_LOGIN.
local frames = {}
-- Widget methods are verbs (SetSize, GetWidth, Show, RegisterForClicks...); anything else is a plain field
-- and starts out nil, so "self.Icon = self.Icon or self:CreateTexture()" behaves like the client.
local METHOD_PREFIXES = { "Set", "Get", "Is", "Has", "Enable", "Disable", "Show", "Hide", "Register", "Unregister", "Clear",
    "Create", "Start", "Stop", "Play", "Pause", "Finish", "Restart", "Lock", "Unlock", "Add", "Remove", "Can", "Raise", "Lower",
    "Hook", "Click", "Insert", "Scroll", "Update", "Reset", "Apply", "Adjust", "Highlight", "Unhighlight", "Allow", "Toggle",
    "Refresh", "Lock", "Execute", "Flash", "Release", "Acquire", "Adjust", "Fade", "Append", "Dim", "Undim", "Load" }

local NUMERIC_GETTERS = {
    GetSize = { 100, 100 }, GetLeft = { 0 }, GetRight = { 100 }, GetTop = { 100 }, GetBottom = { 0 }, GetCenter = { 50, 50 },
    GetAlpha = { 1 }, GetEffectiveAlpha = { 1 }, GetNumRegions = { 0 }, GetNumChildren = { 0 }, GetStringHeight = { 10 },
    GetLineHeight = { 10 }, GetTextWidth = { 10 }, GetUnboundedStringWidth = { 10 }, GetValue = { 0 }, GetMinMaxValues = { 0, 1 },
    GetFrameLevel = { 1 }, GetDrawLayer = { "ARTWORK", 0 }, GetFrameStrata = { "MEDIUM" }, GetNumPoints = { 0 },
    GetTexCoord = { 0, 0, 0, 1, 1, 0, 1, 1 }, GetVertexColor = { 1, 1, 1, 1 }, GetTextColor = { 1, 1, 1, 1 },
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
            if k:sub( 1, #prefix ) == prefix and ( #k == #prefix or k:sub( #prefix + 1, #prefix + 1 ):match( "[A-Z]" ) ) then
                local fn = function() return Mock( tostring( rawget( t, "__mockname" ) ) .. ":" .. k .. "()" ) end
                rawset( t, k, fn )
                return fn
            end
        end
    end,
}

local function NewFrame( frameType, name, parent )
    local f = setmetatable( { __mockname = "Frame:" .. tostring( name ) }, frameMT )
    f.__scripts, f.__events = {}, {}
    f.SetScript = function( self, script, fn ) self.__scripts[ script ] = fn end
    f.GetScript = function( self, script ) return self.__scripts[ script ] end
    f.HookScript = function( self, script, fn ) self.__scripts[ script ] = self.__scripts[ script ] or fn end
    f.RegisterEvent = function( self, e ) self.__events[ e ] = true end
    f.RegisterUnitEvent = function( self, e ) self.__events[ e ] = true end
    f.UnregisterEvent = function( self, e ) self.__events[ e ] = nil end
    f.UnregisterAllEvents = function( self ) self.__events = {} end
    f.IsEventRegistered = function( self, e ) return self.__events[ e ] end
    f.GetName = function() return name end
    f.GetWidth = function() return 100 end
    f.GetHeight = function() return 100 end
    f.GetScale = function() return 1 end
    f.GetEffectiveScale = function() return 1 end
    f.IsShown = function() return false end
    f.IsVisible = function() return false end
    f.GetFrameLevel = function() return 1 end
    f.GetNumPoints = function() return 0 end
    f.GetObjectType = function() return frameType end
    f.CreateTexture = function( self, n ) return NewFrame( "Texture", n, self ) end
    f.CreateFontString = function( self, n ) return NewFrame( "FontString", n, self ) end
    f.CreateAnimationGroup = function( self ) return NewFrame( "AnimationGroup", nil, self ) end
    f.CreateAnimation = function( self ) return NewFrame( "Animation", nil, self ) end
    f.GetStringWidth = function() return 10 end
    f.NumLines = function() return 0 end
    f.GetText = function() return "" end
    f.GetFont = function() return "Fonts\\ARIALN.TTF", 12, "" end
    f.__parent = parent
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
            f.__scripts.OnEvent( f, event, ... )
            n = n + 1
        end
    end
    return n
end


-- Explicit WoW API stubs (only what matters for loading).
local className, classID = CLASSES[ CLASS ][ 1 ], CLASSES[ CLASS ][ 2 ]
local now = 1000

local api = {
    GetBuildInfo = function() return "1.15.9", "70003", "Sep 29 2026", tonumber( meta.Interface ) or 11509 end,
    GetAddOnMetadata = function( _, key ) return meta[ key ] end,
    GetTime = function() return now end,
    GetServerTime = function() return os.time() end,
    time = os.time, date = os.date, debugprofilestop = function() return now * 1000 end,
    GetLocale = function() return "enUS" end,
    GetCVar = function() return "0" end, GetCVarBool = function() return false end, SetCVar = function() end,
    UnitClass = function() return className, CLASS, classID end,
    UnitClassBase = function() return CLASS, classID end,
    UnitRace = function() return "Human", "Human", 1 end,
    UnitFactionGroup = function() return "Alliance", "Alliance" end,
    UnitLevel = function() return 60 end,
    UnitGUID = function( u ) return u == "player" and "Player-1-00000001" or nil end,
    UnitName = function() return "Tester", "Realm" end,
    UnitExists = function( u ) return u == "player" end,
    UnitIsUnit = function( a, b ) return a == b end,
    UnitHealth = function() return 4000 end, UnitHealthMax = function() return 4000 end,
    UnitPower = function() return 0 end, UnitPowerMax = function() return 100 end,
    UnitPowerType = function() return 1, "RAGE" end,
    UnitDamage = function() return 100, 150, 60, 90, 0, 0, 1 end,
    UnitAttackSpeed = function() return 2.6, 1.8 end,
    UnitBuff = function() return nil end, UnitDebuff = function() return nil end, UnitAura = function() return nil end,
    UnitAffectingCombat = function() return false end, InCombatLockdown = function() return false end,
    UnitCanAttack = function() return false end,
    GetShapeshiftForm = function() return 3 end,
    GetSpellInfo = function( id ) if id then return "Spell" .. tostring( id ), nil, 132282, 0, 0, 5, tonumber( id ) or 0 end end,
    GetSpellTexture = function() return 132282 end,
    GetSpellDescription = function() return "" end,
    IsPlayerSpell = function() return false end, IsSpellKnown = function() return false end,
    IsSpellKnownOrOverridesKnown = function() return false end,
    GetNumGroupMembers = function() return 0 end, IsInGroup = function() return false end, IsInRaid = function() return false end,
    GetNumTalentTabs = function() return 3 end,
    GetScreenWidth = function() return 1920 end, GetScreenHeight = function() return 1080 end,
    GetPhysicalScreenSize = function() return 2560, 1440 end,
    CreateFrame = NewFrame,
    hooksecurefunc = function() end,
    issecurevariable = function() return true end,
    securecall = function( f, ... ) if type( f ) == "function" then return f( ... ) end end,
    geterrorhandler = function() return function( e )
        caughtErrors = caughtErrors + 1
        io.stderr:write( "ERROR (caught by error handler): " .. tostring( e ) .. "\n" )
    end end,
    seterrorhandler = function() end,
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
    random = math.random, sqrt = math.sqrt,
    bit = { band = function( a, b ) return 0 end, bor = function( a, b ) return a end, lshift = function( a, b ) return a * 2 ^ b end, rshift = function( a, b ) return math.floor( a / 2 ^ b ) end },
    UIParent = NewFrame( "Frame", "UIParent" ),
    Minimap = NewFrame( "Frame", "Minimap" ),
    DEFAULT_CHAT_FRAME = NewFrame( "ScrollingMessageFrame", "ChatFrame1" ),
    PixelUtil = setmetatable( { GetNearestPixelSize = function( v ) return v end, GetPixelToUIUnitFactor = function() return 1 end },
        { __index = function() return function() end end } ),
    WOW_PROJECT_ID = 2, WOW_PROJECT_CLASSIC = 2, WOW_PROJECT_MAINLINE = 1,
    RAID_CLASS_COLORS = setmetatable( {}, { __index = function() return { r = 1, g = 1, b = 1, colorStr = "ffffffff", GenerateHexColor = function() return "ffffffff" end } end } ),
    Enum = setmetatable( { PowerType = { Rage = 1, Mana = 0, Energy = 3, Focus = 2, ComboPoints = 4, Health = -2 } }, { __index = function( t, k ) local v = setmetatable( {}, { __index = function() return 0 end } ); rawset( t, k, v ); return v end } ),
    C_Timer = {
        After = function( _, fn ) timers[ #timers + 1 ] = fn end,
        NewTimer = function( _, fn ) timers[ #timers + 1 ] = fn; return Mock( "Timer" ) end,
        NewTicker = function() return Mock( "Ticker" ) end,
    },
    SlashCmdList = {}, hash_SlashCmdList = {},
    HekiliDB = nil,

    GetRealmName = function() return "Realm" end, GetCurrentRegion = function() return 3 end,
    UnitSex = function() return 2 end, IsLoggedIn = function() return loggedIn end,
    GetFramerate = function() return 60 end, GetNetStats = function() return 0, 0, 40, 40 end,
    IsShiftKeyDown = function() return false end, IsControlKeyDown = function() return false end, IsAltKeyDown = function() return false end,
    GetBindingKey = function() return nil end, GetBindingText = function( k ) return k end,
    GetActionInfo = function() return nil end, GetActionTexture = function() return nil end, HasAction = function() return false end,
    GetMacroInfo = function() return nil end, GetMacroSpell = function() return nil end, GetMacroItem = function() return nil end,
    GetNumSpellTabs = function() return 0 end, GetSpellTabInfo = function() return nil end,
    GetInventoryItemID = function() return nil end, GetInventoryItemLink = function() return nil end,
    GetInventorySlotInfo = function() return 1 end, GetWeaponEnchantInfo = function() return nil end,
    GetSpellCooldown = function() return 0, 0, 1 end, GetSpellCharges = nil,
    GetShapeshiftFormInfo = function() return nil end, GetNumShapeshiftForms = function() return 3 end,
    IsInInstance = function() return false, "none" end, GetInstanceInfo = function() return "Elwynn", "none", 0, "", 5, 0, false, 0 end,
    GetZoneText = function() return "Elwynn" end, GetRealZoneText = function() return "Elwynn" end, GetSubZoneText = function() return "" end,
    IsMounted = function() return false end, IsFlying = function() return false end, IsResting = function() return false end,
    UnitIsDeadOrGhost = function() return false end, UnitIsDead = function() return false end, UnitInVehicle = function() return false end,
    UnitHasVehicleUI = function() return false end, UnitOnTaxi = function() return false end, UnitIsPlayer = function( u ) return u == "player" end,
    UnitThreatSituation = function() return nil end, UnitDetailedThreatSituation = function() return nil end,
    UnitCastingInfo = function() return nil end, UnitChannelInfo = function() return nil end,
    UnitStat = function() return 100, 100, 0, 0 end, UnitAttackPower = function() return 1200, 0, 0 end,
    UnitRangedAttackPower = function() return 0, 0, 0 end, UnitArmor = function() return 3000, 3000 end,
    GetCritChance = function() return 20 end, GetRangedCritChance = function() return 5 end, GetSpellCritChance = function() return 5 end,
    GetHaste = function() return 0 end, GetMeleeHaste = function() return 0 end, GetRangedHaste = function() return 0 end,
    UnitSpellHaste = function() return 0 end, GetCombatRating = function() return 0 end, GetCombatRatingBonus = function() return 0 end,
    GetSpellBonusDamage = function() return 0 end, GetSpellBonusHealing = function() return 0 end,
    GetPlayerFacing = function() return 0 end, GetUnitSpeed = function() return 0, 7, 7, 4.7 end,
    GetMoney = function() return 0 end, GetItemCount = function() return 0 end,
    GetItemInfo = function() return nil end, GetItemSpell = function() return nil end, GetItemIcon = function() return 134400 end,
    IsUsableItem = function() return false end, IsEquippedItem = function() return false end, IsEquippedItemType = function() return false end,
    GetSpellLink = function() return nil end, GetTalentInfo = function() return nil end,
    GetTalentTabInfo = function( i ) return i, "Tab" .. i, "", 132292, POINTS[ i ] or 0 end, GetNumTalents = function() return 0 end,
    GetActiveTalentGroup = function() return 1 end, GetNumTalentGroups = function() return 1 end,
    RegisterStateDriver = function() end, UnregisterStateDriver = function() end, RegisterUnitWatch = function() end,
    PlaySound = function() end, PlaySoundFile = function() end, StopSound = function() end,
    GetCursorPosition = function() return 0, 0 end, GetMouseFocus = function() return nil end,
    SetOverrideBindingClick = function() end, ClearOverrideBindings = function() end,
    InterfaceOptionsFrame_OpenToCategory = nil, HideUIPanel = function() end, ShowUIPanel = function() end,
    GetAddOnInfo = function() return nil end, GetNumAddOns = function() return 0 end,
    UnitInRaid = function() return nil end, UnitInParty = function() return false end, UnitGroupRolesAssigned = function() return "NONE" end,
    GetRaidRosterInfo = function() return nil end, UnitIsGroupLeader = function() return false end,
    IsSpellInRange = function() return nil end, IsItemInRange = function() return nil end, CheckInteractDistance = function() return false end,
    IsUsableSpell = function() return false, false end, IsCurrentSpell = function() return false end, IsAutoRepeatSpell = function() return false end,
    GetSpellBookItemInfo = function() return nil end, GetSpellBookItemName = function() return nil end,
    CombatLogGetCurrentEventInfo = function() return nil end,
    GetPlayerAuraBySpellID = nil,
    RegisterAddonMessagePrefix = function() return true end,
    SendChatMessage = function() end, ChatFrame_AddMessageEventFilter = function() end,
    ReloadUI = function() end, StaticPopup_Show = function() end, StaticPopupDialogs = {},
    GetLocalizedClass = nil, LOCALIZED_CLASS_NAMES_MALE = {}, CLASS_SORT_ORDER = {},
    GetClassInfo = function( id ) return "Warrior", "WARRIOR", id end, GetNumClasses = function() return 9 end,
    UNKNOWN = "Unknown", NONE = "None", YES = "Yes", NO = "No", OKAY = "Okay", CANCEL = "Cancel", ACCEPT = "Accept",
    CLOSE = "Close", DEFAULT = "Default", ENABLE = "Enable", DISABLE = "Disable", RESET = "Reset",
    SPELL_CASTING = "Casting", ITEM_QUALITY_COLORS = setmetatable( {}, { __index = function() return { r = 1, g = 1, b = 1, hex = "|cffffffff" } end } ),
    NORMAL_FONT_COLOR = { r = 1, g = 0.82, b = 0, GetRGB = function() return 1, 0.82, 0 end },
    HIGHLIGHT_FONT_COLOR = { r = 1, g = 1, b = 1, GetRGB = function() return 1, 1, 1 end },
    INVSLOT_FIRST_EQUIPPED = 1, INVSLOT_LAST_EQUIPPED = 19, INVSLOT_MAINHAND = 16, INVSLOT_OFFHAND = 17, INVSLOT_RANGED = 18,
    INVSLOT_AMMO = 0, INVSLOT_HEAD = 1, INVSLOT_NECK = 2, INVSLOT_SHOULDER = 3, INVSLOT_BODY = 4, INVSLOT_CHEST = 5,
    INVSLOT_WAIST = 6, INVSLOT_LEGS = 7, INVSLOT_FEET = 8, INVSLOT_WRIST = 9, INVSLOT_HAND = 10, INVSLOT_FINGER1 = 11,
    INVSLOT_FINGER2 = 12, INVSLOT_TRINKET1 = 13, INVSLOT_TRINKET2 = 14, INVSLOT_BACK = 15, INVSLOT_TABARD = 19,
    BOOKTYPE_SPELL = "spell", BOOKTYPE_PET = "pet", MAX_TALENT_TIERS = 7, NUM_TALENT_COLUMNS = 3,
    MAX_PARTY_MEMBERS = 4, MAX_RAID_MEMBERS = 40, MAX_BOSS_FRAMES = 5,
    LE_PARTY_CATEGORY_HOME = 1, LE_PARTY_CATEGORY_INSTANCE = 2,
    COMBATLOG_OBJECT_AFFILIATION_MINE = 1, COMBATLOG_OBJECT_TYPE_PLAYER = 1024, COMBATLOG_OBJECT_REACTION_HOSTILE = 64,
    COMBATLOG_OBJECT_CONTROL_PLAYER = 256, COMBATLOG_OBJECT_TYPE_PET = 4096, COMBATLOG_OBJECT_TYPE_GUARDIAN = 8192,
    debugstack = function() return "" end, debuglocals = function() return "" end,
    GetMaxPlayerLevel = function() return 60 end, GetExpansionLevel = function() return 0 end,
    IsTestBuild = function() return false end, IsPublicBuild = function() return true end,
    UnitPowerDisplayMod = function() return 1 end, GetPowerRegen = function() return 0, 0 end,
    GetManaRegen = function() return 0, 0 end, GetComboPoints = function() return 0 end,
    UnitIsFriend = function() return false end, UnitReaction = function() return 4 end, UnitClassification = function() return "normal" end,
    UnitCreatureType = function() return "Humanoid" end, UnitIsTapDenied = function() return false end,
    GetTotemInfo = function() return false end, GetPetActionInfo = function() return nil end, HasPetSpells = function() return nil end,
    GetRuneCooldown = nil, GetInventoryItemTexture = function() return nil end, GetInventoryItemCooldown = function() return 0, 0, 0 end,
    IsSpellOverlayed = function() return false end, IsHarmfulSpell = function() return true end, IsHelpfulSpell = function() return false end,
    SpellIsTargeting = function() return false end, GetSpellPowerCost = function() return {} end,
    CR_CRIT_MELEE = 9, CR_HASTE_MELEE = 18, CR_HASTE_RANGED = 19, CR_HASTE_SPELL = 20, CR_HIT_MELEE = 6,
}

api.DEFAULT_CHAT_FRAME.AddMessage = function( _, msg ) io.write( "  [chat] " .. tostring( msg ):gsub( "|c%x%x%x%x%x%x%x%x", "" ):gsub( "|r", "" ) .. "\n" ) end

string.trim = string.trim or api.strtrim
string.split = function( s, d, n ) return api.strsplit( d, s, n ) end
table.wipe = api.wipe

for k, v in pairs( api ) do _G[ k ] = v end
-- Unknown globals are nil, as on a real client (code often tests whether an API exists).
-- Names in MOCKED resolve to permissive mocks instead; every miss is recorded for the report.
local MOCKED = {}
for name in ( "C_AddOns C_Spell C_Item C_Container C_UnitAuras C_SpecializationInfo C_PlayerInfo C_PvP C_ClassColor " ..
              "C_ActionBar C_SpellBook C_CVar C_ChatInfo C_Map C_NamePlate C_TooltipInfo C_LossOfControl C_PetBattles " ..
              "C_EncounterJournal C_ClassTalents C_Traits C_EquipmentSet C_Soulbinds Settings SettingsPanel " ..
              "GameTooltip GameFontNormal GameFontHighlight GameFontHighlightSmall GameFontNormalSmall ChatFontNormal " ..
              "GameMenuFrame UISpecialFrames STANDARD_TEXT_FONT AuraUtil Item Spell " ..
              "ColorPickerFrame MinimapCluster WorldFrame SpellBookFrame BackdropTemplateMixin Mixin " ..
              "CreateFromMixins CreateColor C_Seasons C_GameRules C_Engraving C_Social C_FriendList C_BattleNet C_Texture C_StringUtil CreateTexturePool CreateFramePool CreateObjectPool CreateFontStringPool CreateFramePoolCollection ItemLocation PlayerLocation EquipmentManager_UnpackLocation C_TradeSkillUI C_Calendar C_DateAndTime C_QuestLog C_Reputation C_Container C_ToyBox C_MountJournal C_Covenants C_LevelLink C_PartyInfo C_Minimap C_EventUtils EventRegistry ScrollUtil" ):gmatch( "%S+" ) do
    MOCKED[ name ] = true
end

-- With tools/fetch-era-api.sh run, every native Era API (and C_ namespace) resolves to a mock, and the
-- real Enum tables are loaded; anything else stays nil, exactly like the client.
local API_DIR = ( arg[ 0 ]:match( "^(.*)/" ) or "." ) .. "/.era-api/"
local ERA_API = {}
do
    local src = ReadFile( API_DIR .. "GlobalAPI.lua" )
    if src then
        for name in src:gmatch( '"([%w_%.:]+)"' ) do
            ERA_API[ name:match( "^([%w_]+)" ) ] = true
        end
        for name in ( ReadFile( API_DIR .. "FrameXML.txt" ) or "" ):gmatch( "[^\r\n]+" ) do
            ERA_API[ name ] = true
        end
        local enum = loadstring( ReadFile( API_DIR .. "LuaEnum.lua" ) or "" )
        if enum then enum() end
        print( "Using the Classic Era API list from " .. API_DIR )
    else
        print( "No Era API list (run tools/fetch-era-api.sh); unknown globals are nil." )
    end
end

setmetatable( _G, { __index = function( t, k )
    if type( k ) ~= "string" then return nil end
    missingGlobals[ k ] = ( missingGlobals[ k ] or 0 ) + 1
    -- ALL_CAPS names approximate GlobalStrings (localized UI text such as BEST, CANCEL).
    if k:match( "^[A-Z][A-Z0-9_]+$" ) and not k:match( "^LE_" ) and not k:match( "^NUM_" ) then return k end
    if MOCKED[ k ] or ERA_API[ k ] then
        local v = Mock( k )
        rawset( t, k, v )
        return v
    end
end } )


-- Load a Lua file with ( addonName, ns ) varargs, as the client does.
local ADDON, ns = "Hekili", {}
local loaded = 0

local function LoadLua( path )
    local src = ReadFile( path )
    assert( src, "missing file: " .. path )
    src = src:gsub( "^\239\187\191", "" ) -- BOM
    local chunk, err = loadstring( src, "@" .. path )
    assert( chunk, err )
    chunk( ADDON, ns )
    loaded = loaded + 1
end

local function LoadXML( path )
    local src = ReadFile( path )
    assert( src, "missing file: " .. path )
    local dir = path:match( "^(.*)/" ) or "."
    src = src:gsub( "<!%-%-.-%-%->", "" )
    for kind, file in src:gmatch( "<(%a+)%s+file%s*=%s*\"([^\"]+)\"" ) do
        local p = dir .. "/" .. file:gsub( "\\", "/" )
        if kind == "Script" then LoadLua( p )
        elseif kind == "Include" then LoadXML( p ) end
    end
end

local ok, err = pcall( function()
    for _, file in ipairs( files ) do
        if file:match( "%.xml$" ) then LoadXML( file ) else LoadLua( file ) end
    end
end )

if not ok then
    print( "LOAD FAILED: " .. tostring( err ) )
    os.exit( 1 )
end
print( string.format( "Loaded %d files from %s (flavor %s).", loaded, TOC, tostring( meta[ "X-Flavor" ] ) ) )


-- Lifecycle: ADDON_LOADED -> OnInitialize, PLAYER_LOGIN -> OnEnable.
local steps = {
    { "ADDON_LOADED", function() io.write( "  handlers: " .. Fire( "ADDON_LOADED", ADDON ) .. ", AceAddon queue: " .. #( LibStub( "AceAddon-3.0" ).initializequeue ) .. ", Hekili.OnInitialize: " .. type( Hekili.OnInitialize ) .. "\n" ) end },
    { "PLAYER_LOGIN", function() loggedIn = true; Fire( "PLAYER_LOGIN" ) end },
    { "PLAYER_ENTERING_WORLD", function() io.write( "  PEW handlers: " .. Fire( "PLAYER_ENTERING_WORLD", true, false ) .. "\n" ) end },
}

for _, step in ipairs( steps ) do
    local ok, err = pcall( function()
        step[ 2 ]()
        -- Run timers scheduled by this step (and timers those schedule), as the client would shortly after.
        local ran = 0
        while #timers > 0 and ran < 500 do
            local fn = table.remove( timers, 1 )
            fn()
            ran = ran + 1
        end
    end )
    if not ok then
        print( step[ 1 ] .. " FAILED: " .. tostring( err ) )
        os.exit( 1 )
    end
    print( step[ 1 ] .. " ok" )
end


local Hekili = _G.Hekili
local spec = Hekili.Class.specs[ classID ]
assert( spec, "class module for " .. CLASS .. " did not register spec " .. classID )

local function count( t ) local n = 0 for _ in pairs( t or {} ) do n = n + 1 end return n end
print( string.format( "Spec %d: %d abilities, %d auras, %d talents, %d settings, %d packs.",
    classID, count( spec.abilities ), count( spec.auras ), count( spec.talents ), count( spec.settings ), count( spec.packs ) ) )

for name, pack in pairs( spec.packs ) do
    local data = Hekili:DeserializeActionPack( pack.import )
    assert( type( data ) == "table", "pack " .. name .. " failed to deserialize: " .. tostring( data ) )
    print( string.format( "  pack %-8s v%s: %d lists", name, tostring( pack.version ), count( data.payload.lists ) ) )
end

io.write( string.format( "class.packs after login: %d; state.spec.id = %s\n", count( Hekili.Class.packs ), tostring( rawget( Hekili.State.spec, "id" ) ) ) )
local okSC, errSC = pcall( function() Hekili:SpecializationChanged(); Hekili:RestoreDefaults() end )
io.write( "SpecializationChanged + RestoreDefaults: " .. ( okSC and "ok" or ( "FAILED " .. tostring( errSC ) ) ) .. "\n" )
io.write( string.format( "class.packs now: %d\n", count( Hekili.Class.packs ) ) )
-- Compile every priority entry with Hekili's own script compiler and collect condition errors.
do
    local compileErrors = {}
    local origError = Hekili.Error
    Hekili.Error = function( self, msg, ... ) compileErrors[ #compileErrors + 1 ] = tostring( msg ) end

    local okLS, errLS = pcall( function() Hekili.Scripts:LoadScripts() end )
    Hekili.Error = origError

    local compiled, withLua = 0, 0
    for id, script in pairs( Hekili.Scripts.DB ) do
        compiled = compiled + 1
        if script.Lua then withLua = withLua + 1 end
        if script.Error then compileErrors[ #compileErrors + 1 ] = id .. ": " .. tostring( script.Error ) end
    end

    io.write( string.format( "Scripts: %s; %d entries compiled (%d with conditions), %d error(s)\n",
        okLS and "loaded" or ( "LOAD FAILED " .. tostring( errLS ) ), compiled, withLua, #compileErrors ) )
    for _, e in ipairs( compileErrors ) do io.write( "  SCRIPT ERROR " .. e .. "\n" ) end
    if not okLS or #compileErrors > 0 then caughtErrors = caughtErrors + 1 end
end

local okDB, errDB = pcall( function()
    assert( type( Hekili.DB ) == "table", "Hekili.DB was not created (OnInitialize did not run?)" )
    local names = {}
    for name, pack in pairs( Hekili.DB.profile.packs ) do
        if type( pack ) == "table" and pack.builtIn then names[ #names + 1 ] = name end
    end
    table.sort( names )
    io.write( "Built-in packs in the profile: " .. ( #names > 0 and table.concat( names, ", " ) or "none" ) .. "\n" )
    local specDB = Hekili.DB.profile.specs[ classID ]
    io.write( "Active priority for spec " .. classID .. ": " .. tostring( specDB and specDB.package ) .. "\n" )
end )
if not okDB then io.stderr:write( "PROFILE CHECK FAILED: " .. tostring( errDB ) .. "\n" ) os.exit( 1 ) end

local shown = {}
for k, n in pairs( missingGlobals ) do shown[ #shown + 1 ] = k end
table.sort( shown )
io.write( "Globals served by mocks (" .. #shown .. "): " .. table.concat( shown, ", " ) )

if caughtErrors > 0 then
    io.stderr:write( "\n" .. caughtErrors .. " error(s) were caught by the error handler.\n" )
    os.exit( 1 )
end
