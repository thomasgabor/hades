--tartaros plug-in for sensor/motor-simulation (and other deceptive phenomena)

local T = {}

local world

function T.init(tartaros, worldtable)
    world = worldtable
end

function T.sensor(me, type, control)
    for _,sensor in pairs(me.sensors) do
        if type == sensor.type then
            return sensor.measure(me, world, control or {})
        end
    end
    return nil
end

function T.motor(me, type, control)
    for _,motor in pairs(me.motors) do
        if type == motor.type then
            return motor.run(me, world, control or {})
        end
    end
    return nil
end

function T.can(me, action)
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

function T.combine(parts, newtype)
    local combinedtype, combinedclass
    for p,part in ipairs(parts) do
        combinedclass = combinedclass or part.class
        if not (combinedclass == part.class) then
            return nil
        end
        combinedtype = combinedtype and (combinedtype .. "+" .. part.type) or part.type
    end
    return {
        type = newtype or combinedtype,
        class = combinedclass,
        run = (combinedclass == "motor") and function (me, world, control)
            for m,motor in ipairs(parts) do
                me = motor.run(me, world, control)
            end
            return me
        end,
        measure = (combinedclass == "sensor") and function (me, world, control)
            return parts[1].measure(me, world, control)
            --TODO: expand this ina meaningful and flexible way
        end
    }
end

function T.proxy(part, origin, suffix)
    suffix = suffix or "proxy"
    return {
        type = part.type .. "-" .. suffix,
        class = part.class,
        run = (part.class == "motor") and function (me, world, control)
            hexameter.process("put", origin, "effect.ticks", {{}})
            hexameter.tell("put", origin, "subscriptions", {{to="finished", space="effect.tocks"}})
            local id = hexameter.ask("put", origin, "motors", {{body = me.name, type = part.type, control = control}})[1].id
            --TODO: This polling solution is totally ugly but works for now
            if false and id then
                local status = hexameter.ask("get", origin, "finished", {{id = id}})
                while not (status[1] and (status[1].id == id)) do
                    status = hexameter.ask("get", origin, "finished", {{id = id}})
                end
            end
            return me
        end,
        measure = (part.class == "sensor") and function (me, world, control)
            local id = hexameter.ask("qry", origin, "sensors", {{body = me.name, type = part.type, control = control}})[1].id
            --TODO: This polling solution is totally ugly but works for now
            if id then
                local status = hexameter.ask("get", origin, "finished", {{id = id}})
                while not (status[1] and (status[1].id == id)) do
                    status = hexameter.ask("get", origin, "finished", {{id = id}})
                end
                return status[1]
            end
            return {}
        end
    }
end

function T.mirror(body, targetaddress)
    local target = targetaddress --TODO: add more flexibility here
    if target then
        local newmotors = {}
        local newsensors = {}
        for m,motor in ipairs(body.motors) do
            newmotors[m] = T.combine({motor, T.proxy(motor, target)}, motor.type)
        end
        for s,sensor in ipairs(body.sensors) do
            newsensors[s] = T.combine({sensor, T.proxy(sensor, target)}, sensor.type)
        end
        body.motors = newmotors
        body.sensors = newsensors
    end
end

return T