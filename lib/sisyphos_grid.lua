--tartaros plug-in for static environment specification (and other recurring tasks)

--this verison of sisyphos provides functions to specify a grid-based world model

local S = {}

local world
local statics = {}

function S.edition()
    return "sisyphos_grid"
end

function S.load(tartaros, worldtable)
    world = worldtable
    local metaworld = getmetatable(world)
    metaworld.tartaros.sisyphos = metaworld.tartaros.sisyphos or {}
    metaworld.tartaros.sisyphos.statics = metaworld.tartaros.sisyphos.statics or {}
    statics = metaworld.tartaros.sisyphos.statics
end

function S.stuff()
    return statics
end

function S.place(object, x, y)
    statics[x] = statics[x] or {}
    statics[x][y] = statics[x][y] or {}
    table.insert(statics[x][y], object)
end

function S.placemultiple(object, xs, ys)
    if not (type(xs) == "table") then xs = {xs} end
    if not (type(ys) == "table") then ys = {ys} end
    for _,x in pairs(xs) do
        for _,y in pairs(ys) do
            S.place(object, x, y)
        end
    end
end

function S.range(start, stop, step)
    step = step or 1
    local result = {}
    local i = start
    while i <= stop do
        table.insert(result, i)
        i = i + step
    end
    return result
end

function S.thereis(x, y, class)
    if not statics[x] then return false end
    if not statics[x][y] then return false end
    for _, object in pairs(statics[x][y]) do
        if object.class == class then
            return true
        end
    end
    return false
end

function S.accessible(x, y)
    if not statics[x] then return true end
    if not statics[x][y] then return true end
    for _, object in pairs(statics[x][y]) do
        if not object.accessible then
            return false
        end
    end
    return true
end

function S.space()
    return {
        class = "space",
        accessible = true
    }
end

function S.nest()
    return {
        class = "nest",
        accessible = true
    }
end

function S.resource()
    return {
        class = "resource",
        accessible = true
    }
end

function S.wall()
    return {
        class = "wall",
        accessible = false
    }
end

return S