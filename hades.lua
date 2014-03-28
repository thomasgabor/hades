--HADES a discrete environment simulator
here = string.match(arg[0], "^.*/") or "./"
package.path = here.."hexameter/?.lua;"..here.."lib/?.lua;"..package.path
require "hexameter"
require "serialize"
require "ostools"
local show = serialize.presentation


local me

auto = {} --unique value

world = nil
metaworld = nil

local parameters = ostools.parametrize(arg, {}, function(a,argument,message) print(a, argument, message) end)

local environment = {
    realm =
        parameters.name
        or parameters.me
        or parameters.realm
        or parameters.hades
        or parameters[1],
    world =
        parameters.world
        or parameters[2],
    hexameter =
        parameters.hexameter
        or parameters.hex,
    construction =
        tonumber(parameters.construction)
        or parameters.C and 1
        or 0
}


local clock = 0
local apocalypse = false
local next = {}
local subscriptions = {}

local time = function ()
    local runresults = {}
    return function(msgtype, author, space, parameter)
        local response = {}
        if (msgtype == "qry" or msgtype == "get") and string.match(space, "^state") then
            local state = {}
            for name,body in pairs(world) do
                state[name] = body.state or {}
            end
            table.insert(response, state)
            return response
        end
        if (msgtype == "qry" or msgtype == "get") and string.match(space, "^report") then
            local bodies = {}
            for name,body in pairs(world) do
                bodies[name] = body.tick or {} --spec: this leaves the tick space in the array, however, the client should only expect a true/false value
            end
            table.insert(response, {bodies=bodies})
            return response
        end
        if msgtype == "put" and string.match(space, "^signals") then
            for i,item in ipairs(parameter) do
                if type(item) == "table" and item.propagate == "all" then
                    item.propagate = nil
                    local receivers = {}
                    for name,body in pairs(world) do
                        if type(body.tick) == "table" then
                            for address,_ in pairs(body.tick) do
                                receivers[address] = true
                            end
                        end
                    end
                    for address,space in pairs(subscriptions.signals or {}) do
                        receivers[address] = space
                    end
                    table.insert(
                        next,
                        function ()
                            for receiver,space in pairs(receivers) do
                                hexameter.tell("put", receiver, (type(space) == "string") and space or "hades.signals", {item})
                            end
                        end
                    )
                end
                if type(item) == "table" and type(item.propagate) == "table" then
                    local receivers = item.propagate
                    item.propagate = nil
                    for _,receiver in pairs(receivers) do
                        table.insert(next, function () hexameter.put(receiver, "hades.signals", {item}) end)
                    end
                end
                if type(item) == "table" and item.type == "apocalypse" then
                    io.write("**  Received apocalypse signal, shutting down soon...\n\n")
                    table.insert(next, function () apocalypse = true end)
                end
            end
        end
        if msgtype == "put" and string.match(space, "^subscriptions") then
            for i,item in ipairs(parameter) do
                if type(item) == "table" and item.to then
                    subscriptions[item.to] = subscriptions[item.to] or {}
                    subscriptions[item.to][item.name or author] = item.space or "hades.subscription"
                end
            end
        end
        if (msgtype == "qry" or msgtype == "get") and string.match(space, "^sensors") then
            for i,item in ipairs(parameter) do
                for s,sensor in pairs(world[item.body].sensors) do
                    if item.type and sensor.type == item.type then
                        --TODO: check for tock, wait for untock?
                        table.insert(
                            response,
                            {
                                body=item.body,
                                type=sensor.type,
                                value=sensor.measure(world[item.body], world, item.control or {})
                            }
                        )
                    end
                end
            end
            return response
        end
        if msgtype == "put" and string.match(space, "^motors") then
            for i,item in ipairs(parameter) do
                for m,motor in pairs(world[item.body].motors) do
                    if item.type and motor.type == item.type then
                        --world[item.body].next = world[item.body].next or {}--needed later
                        table.insert(
                            next,
                            function ()
                                world[item.body] = motor.run(world[item.body], world, item.control or {})
                            end
                        )
                    end
                end
            end
        end
        if msgtype == "put" and string.match(space, "^ticks") then
            for i,item in ipairs(parameter) do
                world[item.body].tick = world[item.body].tick or {}
                world[item.body].tick[item.soul] = item.space or "hades.ticks"
            end
        end
        if msgtype == "put" and string.match(space, "^tocks") then --maybe implement command to set to auto
            for i,item in ipairs(parameter) do
                --TODO: check period parameter against current period (avoids race conditions)
                --TODO: check for non-existing item/body in world
                if not (world[item.body].tocked == auto or world[item.body].tocked == "auto") then
                    world[item.body].tocked = item.duration or 1
                end
            end
        end
        if msgtype == "put" and string.match(space, "^construction$") then
            for i,item in ipairs(parameter) do
                environment.construction = environment.construction - (item.steps or 1)
                table.insert(response, {missing=environment.construction, steps=item.steps or 1})
            end
            return response
        end
        if space == "remote" then
            for i,item in ipairs(parameter) do
                if metaworld.remote and item.call then
                    if metaworld.remote[item.call] then
                        table.insert(response, {result=metaworld.remote[item.call](item), origin=item})
                    elseif metaworld.remote["*"] then
                        table.insert(response, {result=metaworld.remote["*"](item), origin=item})
                    end                        
                end
            end
            return response
        end
        if space == "results" then
            if msgtype == "put" then
                for i,item in ipairs(parameter) do
                    if item.name then
                        runresults[item.name] = item.value
                    end
                end
            elseif msgtype == "qry" then
                if item.name and runresults[item.name] then
                    table.insert(response, runresults[item.name] or {})
                end
            end
            return response
        end
        return nil --making this explicit here
    end
end

for key,val in pairs(environment.hexameter) do
    print(key, val)
end

if environment.realm then
    me = environment.realm
else
    io.write("??  Enter an address:port for this component: ")
    me = io.read("*line")
end

if environment.world then
    io.write("::  Loading "..environment.world.."...")
    world = dofile(environment.world)
    metaworld = getmetatable(world) or {}
    io.write("\n")
else
    world = dofile("./scenarios/magicbrick/world.lua")
    metaworld = {}
    io.write("::  Using default \"magic brick world\".\n")
end

if not (type(world) == "table") then
    io.write("##  World does not exist. Aborting.\n")
end

--TODO: Add correctness check for world definition, i.e.
--      - "sensors" and "motors" field match the data structure, contain only one of each "type"
--      - all parts from "using" do actually exist


for t,thing in pairs(world) do
    thing.sensors = thing.sensors or {}
    thing.motors = thing.motors or {}
    thing.state = thing.state or {}
    thing.time = thing.time or {}
    thing.tick = thing.tick or {}
    thing.tocked = thing.tocked or 0
    if not (type(thing.time) == "table") then
        thing.time = {thing.time}
    end
end



hexameter.init(me, time, nil, nil, environment.hexameter)
io.write("::  Hades running. Please exit with Ctrl+C.\n")


while not apocalypse do
    hexameter.respond(0)
    while environment.construction > 0 do
        hexameter.respond(0)
    end
    --print("**  current friends:", serialize.literal(hexameter.friends())) --command-line option to turn this on?
    local alltocked = true
    local status = "**  [tock status] "
    for t,thing in pairs(world) do
        if not (thing.tocked == auto) then
          alltocked = alltocked and (thing.tocked > 0)
          status = status.."    "..t..": "..((thing.tocked > 0) and "tocked ("..thing.tocked..")" or "not tocked")
        end
    end
    status = status.."\n"
    io.write(status)
    if alltocked then
        clock = clock + 1
        io.write("\n\n\n..  Starting discrete time period #"..clock.."...\n")
        io.write("..  .......................................\n")
        for t,thing in pairs(world) do
            for p,process in pairs(thing.time) do
                if type(process) == "table" then
                    process.run(thing, world, clock)
                elseif type(process) == "function" then
                    process(thing, world, clock)
                end
            end
        end
        for a,action in ipairs(next) do
            action()
        end
        for t,thing in pairs(world) do
            if not (thing.tocked == auto or thing.tocked == "auto") then
                thing.tocked = thing.tocked - 1
            end
            io.write("    state of "..t.."\n")
            io.write("      "..(thing.print and thing.print(thing) or serialize.presentation(thing.state)).."\n")
        end
        io.write("..  .......................................\n\n")
        next = {}
        if not apocalypse then
            for t,thing in pairs(world) do
                for address,space in pairs(thing.tick) do
                    if space then --TODO: check if body is not tocked for a longer time, thus probably not wanting to be ticked
                        hexameter.put(address, space, {{period = clock}})
                    end
                end
            end
            for address,space in pairs(subscriptions.clock or {}) do
                if space then
                    hexameter.put(address, space, {{period = clock}})
                end
            end
        end
    end
end

hexameter.converse() --until zmq.LINGER works with the lua bindings, this is an acceptable solution
--hexameter.term()
io.write("**  Hades is complete, shutting down immediately.\n\n")
