--tartaros plug-in for static environment specification (and other recurring tasks)

--FOR NOW, this code is experimental, please use sisyphos-grid or sisyphos-graph depending on your needs

local luatools = require "luatools"

local S = {}

local world
local statics = {}

function S.load(tartaros, worldtable)
    world = worldtable
    local metaworld = getmetatable(world)
    metaworld.tartaros.sisyphos = metaworld.tartaros.sisyphos or {}
    metaworld.tartaros.sisyphos.statics = metaworld.tartaros.sisyphos.statics or {}
    statics = metaworld.tartaros.sisyphos.statics
end


-- grid world ----------------------------------------------------------------------------------------------------------
local S.gridworld = {}

function S.gridworld.new(name)
    local gridworld = luatools.shallowcopy(S.gridworld)
    gridworld.statics = {}
    statics[name or "gridworld"] = gridworld.statics
    return gridworld
end

function S.gridworld.range(start, stop, step)
    step = step or 1
    local result = {}
    local i = start
    while i <= stop do
        table.insert(result, i)
        i = i + step
    end
    return result
end

function S.gridworld.stuff(self)
    return self
end

function S.gridworld.place(self, object, x, y)
    self.statics[x] = self.statics[x] or {}
    self.statics[x][y] = self.statics[x][y] or {}
    table.insert(self.statics[x][y], object)
end

function S.gridworld.placemultiple(self, object, xs, ys)
    if not (type(xs) == "table") then xs = {xs} end
    if not (type(ys) == "table") then ys = {ys} end
    for _,x in pairs(xs) do
        for _,y in pairs(ys) do
            self:place(object, x, y)
        end
    end
end

function S.gridworld.thereis(self, x, y, class)
    if not self.statics[x] then return false end
    if not self.statics[x][y] then return false end
    for _, object in pairs(self.statics[x][y]) do
        if object.class == class then
            return true
        end
    end
    return false
end

function S.gridworld.accessible(self, x, y)
    if not self.statics[x] then return true end
    if not self.statics[x][y] then return true end
    for _, object in pairs(self.statics[x][y]) do
        if not object.accessible then
            return false
        end
    end
    return true
end

function S.gridworld.space()
    return {
        class = "space",
        accessible = true
    }
end

function S.gridworld.nest()
    return {
        class = "nest",
        accessible = true
    }
end

function S.gridworld.resource()
    return {
        class = "resource",
        accessible = true
    }
end

function S.gridworld.wall()
    return {
        class = "wall",
        accessible = false
    }
end



-- graph world ---------------------------------------------------------------------------------------------------------

local S.graphworld = {}

function S.graphworld.new(name)
    local graphworld = luatools.shallowcopy(S.graphworld)
    graphworld.statics = {nodes={}, edges={}}
    statics[name or "graphworld"] = graphworld.statics
    return graphworld
end

return S