module(..., package.seeall)

statics = {}

function place(object, x, y)
    statics[x] = statics[x] or {}
    statics[x][y] = statics[x][y] or {}
    table.insert(statics[x][y], object)
end

function placemultiple(object, xs, ys)
    if not (type(xs) == "table") then xs = {xs} end
    if not (type(ys) == "table") then ys = {ys} end
    for _,x in pairs(xs) do
        for _,y in pairs(ys) do
            place(object, x, y)
        end
    end
end

function range(start, stop, step)
    step = step or 1
    local result = {}
    local i = start
    while i <= stop do
        table.insert(result, i)
        i = i + step
    end
    return result
end

function thereis(x, y, class)
    if not statics[x] then return false end
    if not statics[x][y] then return false end
    for _, object in pairs(statics[x][y]) do
        if object.class == class then
            return true
        end
    end
    return false
end

function accessible(x, y)
    if not statics[x] then return true end
    if not statics[x][y] then return true end
    for _, object in pairs(statics[x][y]) do
        if not object.accessible then
            return false
        end
    end
    return true
end

function space()
    return {
        class = "space",
        accessible = true
    }
end

function nest()
    return {
        class = "nest",
        accessible = true
    }
end

function resource()
    return {
        class = "resource",
        accessible = true
    }
end

function wall()
    return {
        class = "wall",
        accessible = false
    }
end