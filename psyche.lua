-- PSYCHE system character emulation

--[[
local dbgconnection = require "debugger"
dbgconnection("127.0.0.1", 10000, "psychekey")
--]]--

here = string.match(arg[0], "^.*/") or "./"
package.path = here.."hexameter/?.lua;"..here.."lib/?.lua;"..package.path
local hexameter = require "hexameter"
local serialize = require "serialize"
local ostools   = require "ostools"
local tartaros  = require "tartaros"
local write     = tartaros.write
local writeln   = tartaros.writeln
local show      = serialize.presentation

local possess = true
local avoid = false

local realm, me, character

local bodies = {}
local souls = {}
local allsouls = false

local world

local defaultbehavior = function() --TODO: implement at least a simple, but meaningful default behavior!
    return function()
    end
end

local parameters = ostools.parametrize(arg, {}, function(a,argument,message) print(a, argument, message) end)

local environment = {
    realm =
        parameters.realm
        or parameters.hades
        or parameters[1],
    psyche =
        parameters.name
        or parameters.me
        or parameters.psyche
        or parameters[2],
    bodies =
        parameters.bodies
        or parameters[3],
    character =
        parameters.character
        or parameters.behavior
        or parameters.world
        or parameters[4],
    prefix =
        parameters.prefix,
    hexameter =
        parameters.hexameter
        or parameters.hex,
    tartaros =
        parameters.tartaros
        or parameters.tar
        or {}
}

if environment.prefix and (type(environment.tartaros) == "table") and not environment.tartaros.prefix then
    environment.tartaros.prefix  = environment.prefix
end

tartaros.setup(environment.tartaros)

if environment.realm then
    realm = environment.realm
else
    io.write("??  Enter an address:port for the world simulator: ")
    realm = io.read("*line")
end

if environment.psyche then
    me = environment.psyche
else
    io.write("??  Enter an address:port for this component: ")
    me = io.read("*line")
end

if environment.bodies then
    allsouls, souls = ostools.elect(environment.bodies)
    local bodystr = ""
    local beginning = true
    bodystr = bodystr..(allsouls and "all bodies except " or "bodies ")
    for name,rule in pairs(souls) do
        if (allsouls and (rule == avoid) or (rule == possess)) then
            bodystr = bodystr..(beginning and "" or ", ")..name
            beginning = false
        end
    end
    write("::  Controlling "..bodystr..".\n")
else
    allsouls = true
    write("::  Controlling all bodies by default.\n")
end

if parameters[4] then
    writeln("::  Loading "..arg[4].."...")
    local there = ostools.dir(arg[4])
    package.path = there.."?.lua;"..package.path
    local specification = dofile(arg[4])
    if type(specification) == "function" then --assuming parameter was behavior program file
        character = specification(realm, me)
    elseif type(specification) == "table" then --assuming parameter was world file
        world = specification
        local characters = {}
        for name,body in pairs(world) do
            if (allsouls and not (souls[name] == avoid)) or (souls[name] == possess) then
                if type(body.psyche) == "function" then --behavior is specified in world file directly
                    characters[name] = body.psyche(realm, me, name)
                elseif type(body.psyche) == "string" then --behavior by body-specific behavior program file
                    characters[name] = dofile(there..body.psyche)(realm, me, name)
                    --io.write(name.." specified by "..world[name].psyche.."\n")
                else
                    characters[name] = defaultbehavior(realm, me, name)
                end
            end
        end
        character = function(clock, body)
            if characters[body] then
                return characters[body](clock, body)
            end
            return defaultbehavior(realm, me)(clock, body) --this should actually never occur here
        end
    end
    write("\n")
else
    character = defaultbehavior()
end

local apocalypse = false

local story = function ()
    local clock = 0
    return function(msgtype, author, space, parameter)
        if msgtype == "put" and space == "hades.ticks" then
            local newclock = clock
            for _,item in pairs(parameter) do
                newclock = item.period > newclock and item.period or newclock
            end
            if newclock > clock then
                clock = newclock
                writeln()
                writeln()
                writeln("::  Entering time period #"..clock)
                for name,addresses in pairs(bodies) do
                    if (allsouls and not (souls[name] == avoid)) or (souls[name] == possess) then
                        writeln()
                        writeln("::  Computing "..name)
                        character(clock, name)
                        hexameter.tell("put", realm, "tocks", {{body=name}})
                    end
                end
            end
        end
        if msgtype == "put" and space == "hades.signals" then
            for _,item in ipairs(parameter) do
                if type(item) == "table" and item.type == "apocalypse" then
                    write("**  Received apocalypse signal, shutting down.\n")
                    apocalypse = true
                end
            end
        end
    end
end

hexameter.init(me, story, nil, nil, environment.hexameter)

write("::  Psyche running. Please exit with Ctrl+C.\n")

hexameter.meet(realm)

bodies = hexameter.ask("qry", realm, "report", {{}})[1].bodies --TODO: Hardcoding [1] is probably a bit hacky
write("##  Recognized "..show(bodies).."\n")

for name,addresses in pairs(bodies) do
    if (allsouls and not (souls[name] == avoid)) or (souls[name] == possess) then
        hexameter.put(realm, "ticks", {{body=name, soul=me}})
        hexameter.put(realm, "tocks", {{body=name}})
    end
end

while not apocalypse do
    hexameter.respond(0)
end

hexameter.converse() --until zmq.LINGER works with the lua bindings, this is an acceptable solution
--hexameter.term()