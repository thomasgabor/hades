-- CHARON
here = string.match(arg[0], "^.*/") or "./"
package.path = here.."?.lua;"..here.."hexameter/?.lua;"..here.."lib/?.lua;"..package.path
require "hexameter"
require "serialize"
require "ostools"
local show = serialize.presentation

--using globals here, it, there, world, metaworld, charon

local parameters = ostools.parametrize(arg, {}, function(a,argument,message) print(a, argument, message) end)

if parameters.H or parameters.h or parameters.help then
    ostools.call("cat", here.."lib/help.txt")
    io.write("\n")
    os.exit()
end

it= parameters.world and ostools.expand(parameters.world)
    or parameters[1] and ostools.expand(parameters[1])
    or ostools.usrerr("Please pass a world file as a parameter to Charon")


--handy for debugging
--print(show(parameters))
--print(show(environment.addresses))


io.write("::  Loading "..it.."...\n")
world = dofile(it)
metaworld = getmetatable(world or {})
charon = metaworld.charon or {}
there = ostools.dir(it)


-- set up environment
environment = {
    world = it,
    bodies = parameters.bodies or "...",
    results = parameters.results or "...",
    addresses =
        parameters.addresses and ostools.select(parameters.addresses)
        or parameters.ports and ostools.select(parameters.ports, function(name) return "localhost:"..name end)
        or charon.addresses and ostools.select(charon.addresses)
        or charon.ports and ostools.select(charon.ports, function(name) return "localhost:"..name end)
        or ostools.select("localhost:55555,...,localhost:55595"),
    hades =
        parameters.hades
        or charon.hades
        or nil,
    charon =
        parameters.charon
        or charon.charon
        or charon.me
        or charon.port
        or nil,
    avatar =
        parameters.avatar
        or charon.avatar
        or nil,
    doomsday =
        tonumber(parameters.doomsday)
        or charon.doomsday
        or 0,
    hadeslog =
        parameters.hadeslog
        or charon.hadeslog
        or "/dev/null",
    psychelog =
        parameters.psychelog
        or charon.psychelog
        or "/dev/null",
    resultlog =
        parameters.resultlog and ostools.expand(parameters.resultlog)
        or charon.resultlog and ostools.expand(charon.resultlog)
        or nil,
    runname =
        parameters.runname
        or nil,
    ghost =
        parameters.ghost
        or nil,
    dryrun = parameters.T or false,
    bootup = parameters.U or false,
    shutdown = parameters.D or false,
    freerun = parameters.F or false
}


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
                    ostools.usrerr("Charon cannot process requested result specification "..resultname.." of "..name)
                end
            end
        end
    end
    if body.obolos and body.obolos.mission then
        if type(body.obolos.mission) == "table" then
            for taskname,task in pairs(body.obolos.mission) do
                charon.mission = charon.mission or {}
                task.name = task.name or name..":"..taskname
                task.body = task.body or name
                table.insert(charon.mission, task)
            end
        end
    end
end
resultsensors = ostools.elect(environment.results, resultsensors, function(_, sensor) return sensor.name end)

if environment.ghost then
    local ghostaddress = address()
    io.write("::  Only starting GHOST on ", ghostaddress, "\n")
    ostools.call("lua", here.."hexameter/ghost.lua", ghostaddress, here.."lib/hades.ghost", "--", "enter hades "..environment.ghost)
    os.exit()
end

io.write("**  Charon will collect the following results: ")
local first = true
for r, resultsensor in pairs(resultsensors) do
    io.write((not first and ", " or "")..resultsensor.name.."("..resultsensor.query.type..")")
    first = nil
end
io.write((first and "NONE" or "").."\n")

if environment.dryrun then
    io.write("**  Charon shut down because \"dry run\" was specified.\n")
    os.exit()
end

local realm = address(environment.hades)
local apocalypse = false
local time = function ()
    return function(msgtype, author, space, parameter)
        if msgtype == "put" and (space == "hades.ticks" or space == "hades.subscription.clock") then
            for i,item in pairs(parameter) do
                local finished = false
                if (not environment.freerun) and charon.mission then
                    if not (type(charon.mission) == "table") then
                        charon.mission = {charon.mission}
                    end
                    local accomplished = true
                    for taskname,task in pairs(charon.mission) do
                        local measurements = hexameter.ask("qry", realm, "sensors", {{body=task.body, type=task.type, control=task.control}})
                        if type(task.goal) == "table" then
                            local measured = false
                            for m,measurement in pairs(measurements) do
                                measured = true
                                for goalname,goal in pairs(task.goal) do
                                    if type(measurement.value) == "table" then
                                        if not (measurement.value[goalname] == goal) then
                                            accomplished = false
                                        end
                                    else
                                        accomplished = false
                                    end
                                end
                            end
                            if not measured then
                                accomplished = false
                            end
                        elseif type(task.goal) == "function" then
                            if not task.goal(measurement.value) then
                                accomplished = false
                            end
                        else
                            if not (measurement.value == task.goal) then
                                accomplished = false
                            end
                        end
                    end
                    if accomplished then
                        finished = true
                    end
                end
                if finished or (environment.doomsday > 0 and item.period >= environment.doomsday) then
                    io.write("**  Charon reports:\n")
                    local resultlog, err = environment.resultlog and io.open(environment.resultlog, environment.runname and "a" or "w")
                    if environment.runname then
                        resultlog:write("# RUN ", (environment.runname == "..." and os.time() or environment.runname), "\n")
                    end
                    local measured = false
                    for r,resultsensor in pairs(resultsensors) do
                        measured = true
                        local measurements = hexameter.ask("qry", realm, "sensors", {resultsensor.query})
                        io.write("        ", resultsensor.name, ": ")
                        if resultlog then resultlog:write(resultsensor.name, ",\t") end
                        for m,measurement in pairs(measurements) do
                            local first = true
                            if type(measurement.value) == "table" then
                                for resultname,resultvalue in pairs(measurement.value) do
                                    io.write((not first and ", " or ""), resultname, "=", resultvalue)
                                    if resultlog then resultlog:write((not first and ", " or ""), resultname, "=", resultvalue) end
                                    first = false
                                end
                            else
                                io.write(measurement.value)
                                if resultlog then resultlog:write(measurement.value) end
                            end
                        end
                        io.write("\n")
                        if resultlog then resultlog:write("\n") end
                    end
                    if not measured then
                        io.write("        NOTHING (no results specified)\n")
                    end
                    if resultlog then resultlog:write("\n"); resultlog:close() end
                    hexameter.put(realm, "signals", {{type="apocalypse", propagate="all"}})
                end
                if environment.avatar then
                    hexameter.put(realm, "tocks", {{body=environment.avatar}})
                end
            end
        end
        if msgtype == "put" and (space == "hades.signals" or space == "hades.subscription.signals") then
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


if environment.shutdown then
    for s,step in ipairs(charon.ferry or {}) do
        if step.halt and step.recycle and type(step.address) == "string" and hexameter.wonder("qry", step.address, "net.life", {{charon="wondering"}}) then
            step.halt = step.halt(there, step.address)
            if step.halt then
                ostools.call(step.halt, "&")
            end
        end
    end
    io.write("**  Charon shut down all recyclable external components and itself.\n")
    os.exit()
end


io.write("::  Starting HADES on "..realm.."\n")
ostools.call("lua", here.."hades.lua", realm, it, "> "..environment.hadeslog, "&")
hexameter.ask("qry", realm, "net.life", {{answer=42}}) --wait for hades to be online

if environment.avatar then
    hexameter.put(realm, "ticks", {{body=environment.avatar, soul=me}})
    hexameter.put(realm, "tocks", {{body=environment.avatar}})
else
    hexameter.put(realm, "subscriptions", {{to="clock", space="hades.subscription.clock"}, {to="signals", space="hades.subscription.signals"}})
end


for psycheaddress,psychebodies in pairs(psycheinstances) do
    if type(psycheaddress) == "string" then
        io.write("::  Starting PSYCHE for "..psychebodies.." on "..psycheaddress.."\n")
        ostools.call("lua", here.."psyche.lua", realm, psycheaddress, psychebodies, it, "--prefix", "["..psycheaddress.."]", "> "..environment.psychelog, "&")
    elseif psycheaddress == true then
        local adhocaddress = address()
        io.write("::  Starting PSYCHE for "..psychebodies.." on "..adhocaddress.."\n")
        ostools.call("lua", here.."psyche.lua", realm, adhocaddress, psychebodies, it, "--prefix", "["..adhocaddress.."]", "> "..environment.psychelog, "&")
    end
end


for s,step in ipairs(charon.ferry or {}) do
    local component = nil
    if type(step.address) == "string" then
        if step.recycle and hexameter.wonder("qry", step.address, "net.life", {{charon="wondering"}}) then
            component = step.address
            step.recycled = true
        elseif step.recycle then
            component = step.address --TODO: Parse for recycle component addresses at the beginning of CHARON and exlcude these from the address pool
        else
            component = address(step.address)
            step.address = component
        end
    elseif step.address == true then
        component = address()
        step.address = component
    end
    if step.recycled then
        io.write("**  Using already running ", step.name and step.name or "custom step "..s, " on ", step.address or "???", "\n")
    else
        if type(step.run) == "function" then
            if component then
                step.run = step.run(there, component)
            else
                step.run = step.run(there)
            end
        end
        io.write("::  Running ", step.name and step.name or "custom step "..s, component and " on "..component or "", "\n")
        if step.run then
            ostools.call(step.run, "&")
        end
    end
end

while not apocalypse do
    hexameter.respond(0)
end

for s,step in ipairs(charon.ferry or {}) do
    if step.halt and not step.recycled and not (environment.bootup and step.recycle) then
        step.halt = step.halt(there, step.address)
        if step.halt then
            ostools.call(step.halt, "&")
        end
    end
end


hexameter.converse() --until zmq.LINGER works with the lua bindings, this is an acceptable solution
hexameter.term()
io.write("**  Charon shut down.\n")