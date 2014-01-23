here = string.match(arg[0], "^.*/") or "./"
package.path = here.."?.lua;"..here.."hexameter/?.lua;"..package.path
require "hexameter"
require "serialize"
require "ostools"
local show = serialize.presentation


local apocalypse = false
local parameters = ostools.parametrize(arg, {}, function(a,argument,message) print(a, argument, message) end)
local environment = {
    world = parameters.world or parameters[1] or error("Charon: Please pass a world file as a parameter"), --TODO: write own error function here
    bodies = parameters.bodies or "...",
    addresses =
        parameters.addresses and ostools.select(parameters.addresses)
        or (parameters.ports and ostools.select(parameters.ports, function(name) return "localhost:"..name end)
        or ostools.select("localhost:55555,...,localhost:55565,-localhost:55556,-localhost:55559")), --TODO: think about a more reasonable default
    hades = parameters.hades or nil,
    results = parameters.results or "...",
    doomsday = tonumber(parameters.doomsday) or 0,
    hadeslog = parameters.hadeslog or "/dev/null",
    psychelog = parameters.psychelog or "/dev/null",
    dryrun = parameters.T or false,
}

--handy for debugging
--print(show(parameters))
--print(show(environment.addresses))

it = environment.world
if it then
    io.write("::  Loading "..it.."...")
    world = dofile(it)
    there = ostools.dir(it)
    io.write("\n")
else
    io.write("##  Please provide a world file as first parameter!\n")
    os.exit()
end

local addresspool = environment.addresses
local usedaddresses = {}
local function address(preferred)
    if preferred and not usedaddresses[preferred] then
        if type(preferred) == "string" then
            local todelete = nil
            for a,address in ipairs(addresspool) do
                if address == preferred then
                    todelete = a
                end
            end
            table.remove(addresspool, todelete)
            usedaddresses[preferred] = true
        end
        return preferred
    end
    local best = addresspool[1]
    table.remove(addresspool, 1)
    usedaddresses[best] = true
    return best
end


local psycheinstances = {}
local resultsensors = {}
for name,body in pairs(ostools.elect(environment.bodies, world)) do
    if body.obolos and body.obolos.psyche then
        local psycheaddr = address(body.obolos.psyche)
        psycheinstances[psycheaddr] = psycheinstances[psycheaddr] and (psycheinstances[psycheaddr]..","..name) or name
    end
    if body.obolos and body.obolos.results then
        if type(body.obolos.results) == "table" then
            for resultname,result in pairs(body.obolos.results) do
                if type(result) == "table" then
                    result.body = result.body or name
                    table.insert(resultsensors, {name=name..":"..resultname, query=result}) --TODO: make some type checks
                elseif type(result) == "string" then
                    table.insert(resultsensors, {name=name..":"..resultname, query={type=result, body=name}})
                else
                    error("Charon: Cannot process requested result specification of "..name)
                end
            end
        end
    end
end
resultsensors = ostools.elect(environment.results, resultsensors, function(_, sensor) return sensor.name end)

io.write("**  Charon will collect the following results: ")
local first = true
for r, resultsensor in pairs(resultsensors) do
    io.write((not first and ", " or "")..resultsensor.name.."("..resultsensor.query.type..")")
    first = nil
end
io.write((first and "NONE" or "").."\n")



--[[--old code
local characterfiles = {}
for name,body in pairs(world) do
    if body.obolos and type(body.obolos) == "table" and body.obolos.psyche then
        local psyche = body.obolos.psyche
        if type(psyche) == "string" then
            characterfiles[psyche] = characterfiles[psyche] and characterfiles[psyche]..","..name or name
        end
    end
end

print(show(characterfiles))

os.execute("lua "..here.."hades.lua localhost:55555 "..it.." > /dev/null &")
--os.execute("lua "..here.."psyche.lua localhost:55555 localhost:55557 ...,-platon,-observ "..here.."../Academia/Sources/Lua/mathetes.lua > /dev/null &")
--os.execute("lua "..here.."psyche.lua localhost:55555 localhost:55558 platon "..here.."../Academia/Sources/Lua/platon.lua > /dev/null &")

local i = 2 --TODO: can start at 1 when we have a solution for starting the console automatically
for file,bodies in pairs(characterfiles) do
    os.execute("lua "..here.."psyche.lua localhost:55555 localhost:"..(baseport+i).." "..bodies.." "..there..file.." > /dev/null &")
    i = i + 1
end]]


if environment.dryrun then
    io.write("**  Charon shut down because \"dry run\" was specified.\n")
    os.exit()
end

local realm = address(environment.hades)
io.write("::  Starting HADES on "..realm.."\n")
os.execute("lua "..here.."hades.lua "..realm.." "..it.." > "..environment.hadeslog.." &")

for psycheaddress,psychebodies in pairs(psycheinstances) do
    if type(psycheaddress) == "string" then
        io.write("::  Starting PSYCHE for "..psychebodies.." on "..psycheaddress.."\n")
        os.execute("lua "..here.."psyche.lua "..realm.." "..psycheaddress.." "..psychebodies.." "..it.." > "..environment.psychelog.." &")
    elseif psycheaddress == true then
        local adhocaddress = address()
        io.write("::  Starting PSYCHE for "..psychebodies.." on "..adhocaddress.."\n")
        os.execute("lua "..here.."psyche.lua "..realm.." "..adhocaddress.." "..psychebodies.." "..it.." > "..environment.psychelog.." &")
    end
end

local time = function ()
    return function(msgtype, author, space, parameter)
        if msgtype == "put" and space == "hades.ticks" then
            for i,item in pairs(parameter) do
                if environment.doomsday > 0 and item.period >= environment.doomsday then
                    io.write("**  Charon reports:\n")
                    local measured = false
                    for r,resultsensor in pairs(resultsensors) do
                        measured = true
                        local measurements = hexameter.ask("qry", realm, "sensors", {resultsensor.query})
                        io.write("        ", resultsensor.name, ": ")
                        local first = true
                        for m,measurement in pairs(measurements) do
                            for resultname,resultvalue in pairs(measurement.value) do
                                io.write((not first and ", " or ""), resultname, "=", resultvalue)
                                first = false
                            end
                        end
                        io.write("\n")
                    end
                    if not measured then
                        io.write("        NOTHING (no results specified)\n")
                    end
                    hexameter.put(realm, "signals", {{type="apocalypse", propagate="all"}})
                end
                hexameter.put(realm, "tocks", {{body="observ"}})
            end
        end
        if msgtype == "put" and space == "hades.signals" then
            for _,item in ipairs(parameter) do
                if type(item) == "table" and item.type == "apocalypse" then
                    apocalypse = true
                end
            end
        end
    end
end

local me = address(environment.charon)
hexameter.init(me, time)
io.write("**  Charon is listening on "..me.."\n")

hexameter.put(realm, "ticks", {{body="observ", soul=me}})

while not apocalypse do
    hexameter.respond(0)
end

hexameter.converse() --until zmq.LINGER works with the lua bindings, this is an acceptable solution
hexameter.term()
io.write("**  Charon shut down.\n")