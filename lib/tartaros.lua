local luatools = require "luatools"

local T = {}

local inhabitants = {}
local environment = {}
local parameters = {}
local world, metaworld


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
    T.write(content)
    io.write("\n")
end

T.print = T.writeln

function T.setup(parameterbase)
    parameters = (type(parameterbase) == "table") and parameterbase or {}
end

function T.env(name)
    return environment[name]
end

function T.init(worldbase, metaworldbase, environmentbase)
    world = worldbase or {}
    metaworld = metaworldbase or {}
    metaworld.tartaros = metaworld.tartaros or {}
    setmetatable(world, metaworld)
    environment = luatools.shallowupdate(environmentbase or {}, parameters)
    return world, metaworld
end

function T.create(params)
    return T.init({}, {}, params)
end

function T.load(name, importing, params)
    if not inhabitants[name] then
        metaworld.tartaros[name] = {}
        local inhabitant
        if type(name) == "string" then
            inhabitant = require(name)
        elseif type(name) == "table" then
            inhabitant = name
        elseif type(name) == "function" then
            inhabitant = name(T, world, luatools.shallowupdate(environment, params))
        else
            return false
        end
        inhabitants[name] = inhabitant
        T[name] = inhabitant
        if type(inhabitant.init) == "function" then
            inhabitant.init(T, world, luatools.shallowupdate(environment, params))
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

function T.publish(name, procedure)
    metaworld.remote = metaworld.remote or {}
    metaworld.remote[name] = procedure
    return procedure
    
end

function T.publishloaded(name, ...)
    local added = {}
    for _,member in pairs(arg or inhabitants[name] or {}) do
        if inhabitants[name][member] then
            T.publish(name.."."..member, inhabitants[name][member])
            added[name.."."..member] = true
        end
    end
    return added
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
        metaworld.tartaros[name] = nil
        return true
    end
    return false
end

function T.clone(original, name, changes)
    world[name] = luatools.deepupdate(world[original], changes)
    world[name].name = name
end

local originalstates = {}

function T.save()
    for name,inhabitant in pairs(inhabitants) do
        if inhabitant.save then
            originalstates[name] = inhabitant.save(luatools.deepcopy(metaworld.tartaros[name].state))
        else
            --print("%%% ", name)
            originalstates[name] = luatools.deepcopy(metaworld.tartaros[name].state)
        end
    end
end

function T.revive()
    for name,inhabitant in pairs(inhabitants) do
        if inhabitant.revive then
            metaworld.tartaros[name].state = inhabitant.revive(luatools.deepcopy(originalstates[name]))
        else
            --print("&&& ", name)
            metaworld.tartaros[name].state = luatools.deepcopy(originalstates[name])
        end
    end
end

return T


