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

return T