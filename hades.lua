--HADES a discrete environment simulator
package.path = (string.match(arg[0], "^.*/") or "./").."hexameter/?.lua;"..package.path
require "hexameter"
require "serialize"
local show = serialize.presentation


local me

local auto = {} --unique value

world = nil

local clock = 0
local apocalypse = false

local next = {}

local time = function ()
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
                    table.insert(
                        next,
                        function ()
                            for receiver,_ in pairs(receivers) do
                                print("SEND SIGNAL", receiver)
                                hexameter.tell("put", receiver, "hades.signals", {item})
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
                --TODO: check for non-existing item/body in world
                world[item.body].tocked = item.duration or 1
            end
        end
        return nil --making this explicit here
    end
end

if arg[1] then
    me = arg[1]
else
    io.write("??  Enter an address:port for this component: ")
    me = io.read("*line")
end

if arg[2] then
    io.write("::  Loading "..arg[2].."...")
    world = dofile(arg[2])
    io.write("\n")
else
    world = dofile("./scenarios/magicbrick/world.lua")
    io.write("::  Using default \"magic brick world\".\n")
end

if not (type(world) == "table") then
    io.write("##  World does not exist. Aborting.\n")
end

--TODO: Add correctness check for world definition, i.e.
--      - "sensors" and "motors" field match the data structure, contain only one of each "type"
--      - all parts from "using" do actually exist

sensor = function(me, type, control)
    for _,sensor in pairs(me.sensors) do
        if type == sensor.type then
            return sensor.measure(me, world, control or {})
        end
    end
    return nil
end

motor = function(me, type, control)
    for _,motor in pairs(me.motors) do
        if type == motor.type then
            return motor.run(me, world, control or {})
        end
    end
    return nil
end

can = function(me, action)
    if action.class == "sensor" then
        for _,sensor in pairs(me.sensors) do
            if sensor.type == action.type then
                return true
            end
        end
        return false
    end
    if action.class == "motor" then
        for _,motor in pairs(me.motors) do
            if motor.type == action.type then
                return true
            end
        end
        return false
    end
    return false
end

for t,thing in pairs(world) do
    thing.sensors = thing.sensors or {}
    thing.motors = thing.motors or {}
    thing.state = thing.state or {}
    thing.time = thing.time or {}
    thing.tick = thing.tick or {}
    thing.tocked = thing.tocked or 0
end

hexameter.init(me, time)
io.write("::  Hades running. Please exit with Ctrl+C.\n")


while not apocalypse do
    hexameter.respond(0)
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
                process.run(thing, world, clock)
            end
        end
        for a,action in ipairs(next) do
            action()
        end
        for t,thing in pairs(world) do
            if not (thing.tocked == auto) then
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
                    if space then
                        hexameter.put(address, space, {{period = clock}})
                    end
                end
            end
        end
    end
end

hexameter.converse() --until zmq.LINGER works with the lua bindings, this is an acceptable solution
hexameter.term()
io.write("**  Hades is complete, shutting down immediately.\n\n")
