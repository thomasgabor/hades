local T = {}

local inhabitants = {}
local environment = {}
local world, metaworld


-- local functions

local function deepcopy(table)
    if type(table) == "table" then
        local newtable = {}
        for key,val in pairs(table) do
            newtable[key] = deepcopy(val)
        end
        return newtable
    else
        return table
    end
end

local function update(base, changes, recursive)
    local newtable = deepcopy(base)
    for key,val in pairs(changes or {}) do
        if recursive and type(val) == "table" and type(newtable[key]) == "table" then
            newtable[key] = update(newtable[key], val, true)
        else
            newtable[key] = val
        end
    end
    return newtable
end


--tartaros interfae

function T.write(content)
    if content then
        if environment and environment.prefix then
            io.write(environment.prefix, "  ", content)
        else
            io.write(content)
        end
    end
end

function T.writeln(content)
    write(content)
    io.write("\n")
end

T.print = T.writeln

function T.init(worldbase, metaworldbase, environmentbase)
    world = worldbase or {}
    metaworld = metaworldbase or {}
    metaworld.tartaros = metaworld.tartaros or {}
    setmetatable(world, metaworld)
    environment = environmentbase or {}
    return world, metaworld
end

function T.create(params)
    return T.init({}, {}, params)
end

function T.load(name, importing, params)
    if not inhabitants[name] then
        local inhabitant
        if type(name) == "string" then
            inhabitant = require(name)
        elseif type(name) == "table" then
            inhabitant = name
        elseif type(name) == "function" then
            inhabitant = name(T, world, update(environment, params))
        else
            return false
        end
        inhabitants[name] = inhabitant
        T[name] = inhabitant
        if type(inhabitant.init) == "function" then
            inhabitant.init(T, world, update(environment, params))
        end
        if importing then
            for key,val in pairs(inhabitant) do
                if not (key == "init") and not (key == "halt") then
                    T[key] = val
                end
            end
        end
    end
    return inhabitants[name]
end

function T.unload(name, imported, params)
    if inhabitants[name] then
        local inhabitant = inhabitants[name]
        if imported then
            for key,val in pairs(inhabitant) do
                T[key] = nil
            end
        end
        if type(inhabitant.halt) == "function" then
            inhabitant.halt(T, world, params)
        end
        T[name] = nil
        inhabitants[name] = nil
        return true
    end
    return false
end

function T.clone(original, name, changes)
    world[name] = update(world[original], changes, true)
end

return T


