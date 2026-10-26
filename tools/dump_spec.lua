-- Load a class module with a recording stub and print what it registers, one record per line:
--   ability <key> <id> <copy ids...> | aura <key> <id> <copy ids...> | talent <key> <talentID> <maxRank> <rank ids...>
--
-- Usage: luajit tools/dump_spec.lua Era/Warrior.lua WARRIOR

local path, CLASS = arg[ 1 ], arg[ 2 ] or "WARRIOR"

local records = {}
local function ids( copy )
    local out = {}
    if type( copy ) == "number" then out[ 1 ] = copy
    elseif type( copy ) == "table" then
        for _, v in ipairs( copy ) do if type( v ) == "number" then out[ #out + 1 ] = v end end
    end
    return out
end

local spec = setmetatable( {}, { __index = function() return function() end end } )
function spec:RegisterAbilities( t )
    for k, v in pairs( t ) do
        records[ #records + 1 ] = { "ability", k, v.id or 0, ids( v.copy ), item = v.item }
    end
end
function spec:RegisterAuras( t )
    for k, v in pairs( t ) do
        if not v.alias then records[ #records + 1 ] = { "aura", k, v.id or 0, ids( v.copy ) } end
    end
end
function spec:RegisterTalents( t )
    for k, v in pairs( t ) do
        local ranks = {}
        for i = 3, #v do ranks[ #ranks + 1 ] = v[ i ] end
        records[ #records + 1 ] = { "talent", k, v[ 1 ], ranks, max = v[ 2 ] }
    end
end

-- Minimal environment for loading the module.
local anything = setmetatable( {}, { __index = function( t, k ) return t end, __call = function( t ) return t end } )
local env = setmetatable( {
    UnitClassBase = function() return CLASS end,
    Enum = { PowerType = setmetatable( {}, { __index = function() return 0 end } ) },
    max = math.max, min = math.min, floor = math.floor,
}, { __index = function( t, k ) return _G[ k ] or anything end } )

local hekili = setmetatable( { NewSpecialization = function() return spec end, Class = anything, State = anything }, { __index = function() return anything end } )
env.Hekili = hekili

_G.Hekili = hekili
local chunk = assert( loadfile( path ) )
setfenv( chunk, env )
chunk( "Hekili", setmetatable( {}, { __index = function() return anything end } ) )
-- The module reads Hekili via _G[ addon ].
env[ "Hekili" ] = hekili

table.sort( records, function( a, b ) return a[ 1 ] .. a[ 2 ] < b[ 1 ] .. b[ 2 ] end )
for _, r in ipairs( records ) do
    local extra = r[ 1 ] == "talent" and ( " " .. r.max ) or ""
    io.write( r[ 1 ], " ", r[ 2 ], " ", tostring( r[ 3 ] ), extra, " ", table.concat( r[ 4 ], " " ), "\n" )
end
