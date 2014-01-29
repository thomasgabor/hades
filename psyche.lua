-- PSYCHE system character emulation
here = string.match(arg[0], "^.*/") or "./"
package.path = here.."hexameter/?.lua;"..here.."lib/?.lua;"..package.path
require "hexameter"
require "serialize"
require "ostools"
local show = serialize.presentation

local possess = {} --unique flag
local avoid = {}   --unique flag

local realm, me, character

local bodies = {}
local souls = {}
local allsouls = false

local world

local defaultbehavior = function() --TODO: implement at least a simple, but meaningful default behavior!
    return function()
    end
end

if arg[1] then
    realm = arg[1]
else
    io.write("??  Enter an address:port for the world simulator: ")
    realm = io.read("*line")
end

if arg[2] then
    me = arg[2]
else
    io.write("??  Enter an address:port for this component: ")
    me = io.read("*line")
end

if arg[3] then
    for part in string.gmatch(arg[3]..",", "([^,]*),") do
        if not (part == "") then
            if part == "..." then
                allsouls = true
            else
                local firstchar = string.match(part, "^(.)")
                local name = string.gsub(part, "^[-\+]", "")
                if firstchar == "-" then
                    souls[name] = avoid
                else
                    souls[name] = possess
                end
            end
        end
    end
    local bodystr = ""
    local beginning = true
    bodystr = bodystr..(allsouls and "all bodies except " or "bodies ")
    for name,rule in pairs(souls) do
        if (allsouls and (rule == avoid) or (rule == possess)) then
            bodystr = bodystr..(beginning and "" or ", ")..name
            beginning = false
        end
    end
    io.write("::  Controlling "..bodystr..".\n")
else
    allsouls = true
    io.write("::  Controlling all bodies by default.\n")
end

if arg[4] then
    io.write("::  Loading "..arg[4].."...")
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
                    characters[name] = body.psyche(realm, me)
                elseif type(body.psyche) == "string" then --behavior by body-specific behavior program file
                    characters[name] = dofile(there..body.psyche)(realm, me)
                    --io.write(name.." specified by "..world[name].psyche.."\n")
                else
                    characters[name] = defaultbehavior(realm, me)
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
    io.write("\n")
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
                print()
                print()
                print("::  Entering time period #"..clock)
                for name,addresses in pairs(bodies) do
                    if (allsouls and not (souls[name] == avoid)) or (souls[name] == possess) then
                        print()
                        print("::  Computing "..name)
                        character(clock, name)
                        hexameter.tell("put", realm, "tocks", {{body=name}})
                    end
                end
            end
        end
        if msgtype == "put" and space == "hades.signals" then
            for _,item in ipairs(parameter) do
                if type(item) == "table" and item.type == "apocalypse" then
                    io.write("**  Received apocalypse signal, shutting down.\n")
                    apocalypse = true
                end
            end
        end
    end
end

hexameter.init(me, story)

io.write("::  Psyche running. Please exit with Ctrl+C.\n")

hexameter.meet(realm)

bodies = hexameter.ask("qry", realm, "report", {{}})[1].bodies --TODO: Hardcoding [1] is probably a bit hacky
io.write("##  Recognized "..show(bodies).."\n")

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
hexameter.term()