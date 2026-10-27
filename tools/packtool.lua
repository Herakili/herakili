-- Offline helper for Hekili priority packs.
--
-- Usage (run from the repository root, with LIBS pointing at a folder that
-- contains LibDeflate/LibDeflate.lua and Ace3/AceSerializer-3.0/AceSerializer-3.0.lua):
--
--   LIBS=/path/to/libs lua5.1 tools/packtool.lua decode <Class.lua> <PackName>
--   LIBS=/path/to/libs lua5.1 tools/packtool.lua encode <file.simc> <PackName> <specID> [author] [desc]
--
-- `decode` prints the payload of a pack registered with spec:RegisterPack().
-- `encode` builds a pack string from a SimC-style action list, the same format
-- Hekili's in-game "Import" accepts, and prints it.

local libs = os.getenv( "LIBS" ) or "Libs"

-- Minimal WoW environment for the libraries.
local registry = {}
LibStub = setmetatable( {
    NewLibrary = function( self, name, minor )
        local lib = registry[ name ] or {}
        registry[ name ] = lib
        return lib, nil
    end,
    GetLibrary = function( self, name ) return registry[ name ] end,
}, { __call = function( self, name ) return registry[ name ] end } )

strmatch, strsub, strbyte, strchar, format = string.match, string.sub, string.byte, string.char, string.format
tinsert, tconcat, wipe = table.insert, table.concat, function( t ) for k in pairs( t ) do t[ k ] = nil end return t end
geterrorhandler = function() return print end
string.trim = string.trim or function( s ) return ( s:gsub( "^%s+", "" ):gsub( "%s+$", "" ) ) end

dofile( libs .. "/LibDeflate/LibDeflate.lua" )
dofile( libs .. "/Ace3/AceSerializer-3.0/AceSerializer-3.0.lua" )

local LibDeflate = registry[ "LibDeflate" ] or require( "LibDeflate" )
local Serializer = registry[ "AceSerializer-3.0" ]


local function TableToString( t )
    local serialized = Serializer:Serialize( t )
    local compressed = LibDeflate:CompressDeflate( serialized, { level = 5 } )
    return "Hekili:" .. LibDeflate:EncodeForPrint( compressed )
end

local function StringToTable( s )
    s = s:gsub( "^Hekili:", "" )
    local decoded = assert( LibDeflate:DecodeForPrint( s ), "Unable to decode." )
    local decompressed = assert( LibDeflate:DecompressDeflate( decoded ), "Unable to decompress." )
    local ok, t = Serializer:Deserialize( decompressed )
    assert( ok, t )
    return t
end


local function Dump( v, indent, seen )
    indent = indent or ""
    if type( v ) ~= "table" then
        return type( v ) == "string" and format( "%q", v ) or tostring( v )
    end
    local keys = {}
    for k in pairs( v ) do keys[ #keys + 1 ] = k end
    table.sort( keys, function( a, b )
        if type( a ) == type( b ) then return a < b end
        return type( a ) == "number"
    end )
    local out = { "{" }
    for _, k in ipairs( keys ) do
        out[ #out + 1 ] = format( "%s  [%s] = %s,", indent, type( k ) == "string" and format( "%q", k ) or tostring( k ), Dump( v[ k ], indent .. "  " ) )
    end
    out[ #out + 1 ] = indent .. "}"
    return table.concat( out, "\n" )
end


local function ReadFile( path )
    local f = assert( io.open( path, "r" ) )
    local s = f:read( "*a" )
    f:close()
    return s
end


-- Borrow Hekili's own condition cleanup (Options.lua Sanitize, Utils.lua SpaceOut),
-- so offline packs match what the in-game SimC importer would produce.
local Sanitize, SpaceOut
do
    local function Extract( path, from, to )
        local src = ReadFile( path )
        local s = assert( src:find( from, 1, true ), "Missing in " .. path .. ": " .. from )
        local e = to and assert( src:find( to, s, true ), "Missing in " .. path .. ": " .. to ) or #src
        return src:sub( s, e - 1 )
    end

    local env = setmetatable( { insert = table.insert, ns = {} }, { __index = _G } )

    local utils = Extract( "Utils.lua", "function ns.SpaceOut", "\nend\n" ) .. "\nend\n"
    local options = Extract( "Options.lua", "local function make_substitutions", "local function strsplit" )

    local chunk = assert( loadstring( utils .. "\n" .. options .. "\nreturn Sanitize" ) )
    setfenv( chunk, env )
    Sanitize = chunk()
    SpaceOut = env.ns.SpaceOut
end

local function CleanCondition( value )
    local warnings = {}
    value = value:gsub( "(|)([^|])", "%1|%2" ):gsub( "|||", "||" )
    value = Sanitize( "c", value, 0, warnings )
    return SpaceOut( value )
end


-- Parse SimC-style lines ("actions.list+=/action,key=value,...") into Hekili's list format.
local function ParseSimC( text )
    local lists, order = {}, {}

    for line in text:gmatch( "[^\r\n]+" ) do
        line = line:gsub( "^%s+", "" ):gsub( "%s+$", "" )
        if line ~= "" and not line:match( "^#" ) then
            local list, body = line:match( "^actions%.?([%w_]*)%+?=/?(.+)$" )
            assert( list, "Unparseable line: " .. line )
            if list == "" then list = "default" end

            if not lists[ list ] then
                lists[ list ] = {}
                order[ #order + 1 ] = list
            end

            local entry = { enabled = true }
            local first = true

            -- Conditions can contain commas inside parentheses, so split carefully.
            local depth, start = 0, 1
            local parts = {}
            for i = 1, #body do
                local c = body:sub( i, i )
                if c == "(" then depth = depth + 1
                elseif c == ")" then depth = depth - 1
                elseif c == "," and depth == 0 then
                    parts[ #parts + 1 ] = body:sub( start, i - 1 )
                    start = i + 1
                end
            end
            parts[ #parts + 1 ] = body:sub( start )

            for _, part in ipairs( parts ) do
                if first then
                    entry.action = part
                    first = false
                else
                    local k, v = part:match( "^([%w_]+)=(.*)$" )
                    assert( k, "Bad option '" .. part .. "' in: " .. line )
                    if k == "if" or k == "condition" then k = "criteria" end
                    if k == "criteria" or k == "target_if" or k == "value" or k == "value_else" or k == "sec" or k == "wait" then
                        v = CleanCondition( v )
                    end
                    if k == "name" and ( entry.action == "call_action_list" or entry.action == "run_action_list" ) then
                        entry.list_name = v
                    elseif k == "name" and entry.action == "variable" then
                        entry.var_name = v
                    elseif k == "use_off_gcd" or k == "use_while_casting" or k == "strict" or k == "cycle_targets" or k == "for_next" then
                        entry[ k ] = tonumber( v )
                    else
                        entry[ k ] = v
                    end
                end
            end

            if entry.action == "variable" then entry.op = entry.op or "set" end

            lists[ list ][ #lists[ list ] + 1 ] = entry
        end
    end

    return lists, order
end


local cmd = arg[ 1 ]

if cmd == "decode" then
    local src = ReadFile( arg[ 2 ] )
    local name = arg[ 3 ]
    local pack = src:match( 'RegisterPack%(%s*"' .. name .. '"%s*,%s*[%d%.]+%s*,%s*%[%[(.-)%]%]' )
    assert( pack, "Pack not found: " .. name )
    print( Dump( StringToTable( pack ) ) )

elseif cmd == "decodestr" then
    print( Dump( StringToTable( io.read( "*a" ):gsub( "%s+$", "" ) ) ) )

elseif cmd == "encode" or cmd == "embed" then
    local simc, name, specID, author, desc

    if cmd == "encode" then
        simc, name, specID, author, desc = arg[ 2 ], arg[ 3 ], arg[ 4 ], arg[ 5 ], arg[ 6 ]
    else
        simc, name, specID, author, desc = arg[ 3 ], arg[ 4 ], arg[ 5 ], arg[ 6 ], arg[ 7 ]
    end

    local profile = ReadFile( simc )
    local lists = ParseSimC( profile )
    -- Date and time, so a rebuild on the same day still counts as newer (Hekili only updates built-in packs when the version increases).
    local now = os.date( "%Y%m%d.%H%M" )
    local serial = {
        type = "package",
        name = name,
        date = tonumber( now ),
        payload = {
            spec = tonumber( specID ),
            source = "https://github.com/herakili/herakili",
            author = author or "Herakili",
            desc = desc or "",
            profile = profile,
            date = tonumber( now ),
            version = tonumber( now ),
            warnings = "",
            builtIn = false,
            lists = lists,
        },
    }
    local encoded = TableToString( serial )

    if cmd == "encode" then
        print( encoded )
    else
        -- Replace spec:RegisterPack( "<name>", ... ) in the class file, or add it before the first pack selector.
        local path = arg[ 2 ]
        local src = ReadFile( path )
        local line = format( 'spec:RegisterPack( "%s", %s, [[%s]] )', name, now, encoded )
        local pattern = 'spec:RegisterPack%(%s*"' .. name:gsub( "%p", "%%%0" ) .. '"%s*,%s*[%d%.]+%s*,%s*%[%[.-%]%]%s*%)'
        local s, e = src:find( pattern )

        if s then
            src = src:sub( 1, s - 1 ) .. line .. src:sub( e + 1 )
        else
            local anchor = src:find( "spec:RegisterPackSelector", 1, true )
            assert( anchor, "No spec:RegisterPackSelector found to insert before in " .. path )
            src = src:sub( 1, anchor - 1 ) .. line .. "\n\n" .. src:sub( anchor )
        end

        local f = assert( io.open( path, "w" ) )
        f:write( src )
        f:close()
        print( format( "Embedded %s (%d lists) into %s", name, ( function() local n = 0 for _ in pairs( lists ) do n = n + 1 end return n end )(), path ) )
    end

else
    print( "usage: packtool.lua decode <Class.lua> <PackName>\n" ..
           "       packtool.lua decodestr < pack.txt\n" ..
           "       packtool.lua encode <file.simc> <PackName> <specID> [author] [desc]\n" ..
           "       packtool.lua embed <Class.lua> <file.simc> <PackName> <specID> [author] [desc]" )
end
