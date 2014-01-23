local type = type
local string = string
local tostring = tostring
local error = error
local pairs = pairs
local ipairs = ipairs
local stdprint = print
local unpack = unpack
local print = print
local os = os
local table = table
local tonumber = tonumber
module(...)

function dir(path)
    return string.match(path, "^.*/") or "./"
end

function call(parameters)

end

function parametrize(arguments, defaults, errorhandler)
    errorhandler = errorhandler or function(a,argument,message) return true end
    if not arguments[0] then
        if not errorhandler(0, "<CALL>", "argument for called file missing") then return nil end
    end
    local parameters = defaults or {}
    parameters[0] = arguments[0]
    local i = 1
    local munchedby = false
    for a,argument in ipairs(arguments) do
        if munchedby then
            parameters[munchedby] = argument
            munchedby = false
        else
            local name, value = string.match(argument, "^%-%-([a-zA-Z][a-zA-Z0-9%-]*)=(.*)$") --forme: --world=foo.lua
            if name then
                parameters[name] = value
            else
                name = string.match(argument, "^%-%-([a-zA-Z][a-zA-Z0-9%-]*)$") --forme: --world foo.lua
                if name then
                    munchedby = name
                else
                    name = string.match(argument, "^%-([a-zA-Z0-9]+)$") --forme: -Rf
                    if name then
                        for flag in string.gmatch(name, ".") do
                            parameters[flag] = true
                        end
                    else
                        if string.match(argument, "^%-") then
                            if not errorhandler(a, argument, "malformed parameter name") then return nil end
                        else
                            parameters[i] = argument
                            i = i + 1
                        end
                    end
                end
            end
        end
    end
    if munchedby then
        if not errorhandler(#arguments, munchedby, "value expected but not given") then return nil end
    end
    return parameters
end

function elect(query, foundation, by)
    by = by or function(name, value) return name end
    local all = false
    local selection = {}
    for part in string.gmatch(query..",", "([^,]*),") do
        if not (part == "") then
            if (part == "...") or (part == "+...") then
                all = true
            elseif part == "-..." then
                all = false
            else
                local prefix = string.match(part, "^(.)")
                local name = string.gsub(part, "^[-\+]", "")
                if prefix == "-" then
                    selection[name] = false 
                else
                    selection[name] = true
                end
            end
        end
    end
    if type(foundation) == "table" then
        local result = {}
        for name,value in pairs(foundation) do
            local selector = by(name, value)
            if all then
                if (selection[selector] == nil) or (selection[selector] == true) then
                    result[name] = value
                end --if false do not add
            else
                if (selection[selector] == true) then
                    result[name] = value
                end --if false or nil do not add
            end
        end
        return result
    end
    return all, selection
end

function select(query, as, pad)
    pad = pad or function(start, stop)
        local result = {}
        local starthost, startport = string.match(start, "^(.-)([0-9]+)$")
        local stophost, stopport = string.match(stop, "^(.-)([0-9]+)$")
        if not (starthost == stophost) then
            return nil
        end
        for i = tonumber(startport)+1, tonumber(stopport)-1, (tonumber(startport) < tonumber(stopport) and 1 or -1) do
            table.insert(result, starthost..i)
        end
        return result
    end
    as = as or function(name)
        return name
    end
    local selectionset = {}
    local preselection = {}
    local padded = false
    local last = nil
    for part in string.gmatch(query..",", "([^,]*),") do
        if not (part == "") then
            if string.match(part, "^\+?\.\.\.$") then
                padded = "+"
            elseif part == "-..." then
                padded = "-"
            else
                local prefix = string.match(part, "^(.)")
                local name = string.gsub(part, "^[-\+]", "")
                if padded then
                    for i,item in ipairs(pad(last, name) or {}) do
                        if padded == "-" then
                            if selectionset[item] then
                                selectionset[item] = nil
                            end
                        else
                            if not selectionset[item] then
                                selectionset[item] = true
                                table.insert(preselection, item)
                            end
                        end
                    end 
                end
                if prefix == "-" then
                    if selectionset[name] then
                        selectionset[name] = nil
                    end
                else
                    if not selectionset[name] then
                        selectionset[name] = true
                        table.insert(preselection, name)
                    end
                end
                last = name
                padded = false
            end
        end
    end
    local selection = {}
    for i,item in ipairs(preselection) do
        if selectionset[item] then
            table.insert(selection, as(item))
        end
    end
    return selection
end