local type = type
local string = string
local tostring = tostring
local error = error
local pairs = pairs
local ipairs = ipairs
local unpack = unpack
local print = print
local os = os
local io = io
local table = table
local tonumber = tonumber
module(...)

function shallowcopy(original)
    if type(original) == "table" then
        local copy = {}
        for key,val in pairs(original) do
            copy[key] = val
        end
        return copy
    else
        return original
    end
end

function deepcopy(original)
    if type(original) == "table" then
        local copy = {}
        for key,val in pairs(original) do
            copy[key] = deepcopy(val)
        end
        return copy
    else
        return original
    end
end

function shallowupdate(...)
    local arg = {...}
    local updates = arg
    local base = {}
    for _,update in ipairs(updates) do
        for key,val in pairs(update or {}) do
            base[key] = val
        end
    end
    return base
end

function deepupdate(...)
    local arg = {...}
    local updates = arg
    local base = {}
    for _,update in ipairs(updates) do
        for key,val in pairs(update or {}) do
            if type(base[key]) == "table" and type(val) == "table" then
                base[key] = deepupdate(base[key], val)
            else
                base[key] = deepcopy(val)
            end
        end
    end
    return base
end