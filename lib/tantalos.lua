module(..., package.seeall)

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