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

function expand(path)
    return string.gsub(path, "\~", os.getenv("HOME"))
end

function dir(path)
    return string.match(path, "^.*/") or "./"
end

function call(...)
    local callstring = ""
    for _,parameter in ipairs(arg) do
        if type(parameter) == "table" then
            for i,item in ipairs(parameter) do
                callstring = callstring..item.." "
            end
        else
            callstring = callstring..parameter.." "
        end
    end
    return os.execute(callstring)
end

function usrerr(message, state)
    io.write("##  ", string.gsub(message, "\n", "\n    "), "\n")
    if (type(state) == "table") and #state > 0 then
        io.write("##  The following variable values may help you fixing this error:\n")
        for name,value in pairs(state) do
            io.write("    ", name, " = ", value, "\n")
        end
    end
    os.exit()
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
            local name, value = string.match(argument, "^%-%-([a-zA-Z][a-zA-Z0-9%-:]*)=(.*)$") --forme: --world=foo.lua
            if name then
                parameters[name] = value
            else
                name = string.match(argument, "^%-%-([a-zA-Z][a-zA-Z0-9%-:]*)$") --forme: --world foo.lua
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
    for key,value in pairs(parameters) do
        local group, name = string.match(key, "^([a-zA-Z0-9%-]+):([a-zA-Z0-9%-:]*)$")
        if group then
            if not parameters[group] then
                parameters[group] = {}
            end
            if type(parameters[group]) == "table" then
                parameters[group][name] = value
            end
        end
    end
    return parameters
end

function group(name, parameters)
    local arguments = {}
    for key,val in pairs(parameters) do
        table.insert(arguments, "--"..name..":"..key.."="..val)
    end
    return arguments
end

function argumentize()
    --TODO: write function that turns parameter tables back into lists of argument strings that can be passed to ostools.call()
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
                local name = string.gsub(part, "^[-%+]", "")
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
        if start and stop then
            local starthost, startport = string.match(start, "^(.-)([0-9]+)$")
            local stophost, stopport = string.match(stop, "^(.-)([0-9]+)$")
            if not (starthost == stophost) then
                return nil
            end
            for i = tonumber(startport)+1, tonumber(stopport)-1, (tonumber(startport) < tonumber(stopport) and 1 or -1) do
                table.insert(result, starthost..i)
            end
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
    local function save(sign, value)
        if sign == "-" then
            if selectionset[value] then
                selectionset[value] = nil
            end
        else
            if not selectionset[value] then
                selectionset[value] = true
                table.insert(preselection, value)
            end
        end
    end
    for part in string.gmatch(query..",", "([^,]*),") do
        if not (part == "") then
            if string.match(part, "^%+?%.%.%.$") then
                padded = "+"
            elseif part == "-..." then
                padded = "-"
            else
                local prefix = string.match(part, "^(.)")
                local name = string.gsub(part, "^[-%+]", "")
                if padded then
                    for i,item in ipairs(pad(last, name) or {}) do
                        save(padded, item)
                    end 
                end
                save(prefix, name)
                last = name
                padded = false
            end
        end
    end
    if padded then
        for i,item in ipairs(pad(last, nil) or {}) do
            save(padded, item)
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