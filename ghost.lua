--GHOST hands-on scel terminal
package.path = (string.match(arg[0], "^.*/") or "./").."hexameter/?.lua;"..package.path
require "hexameter"
require "serialize"
local show = serialize.presentation

local commands
local me, target, environment, focus
local hiddenvars = {}

local function interpret(parameter)
    return loadstring("return "..parameter)()
end

function multiarg(argument)
    if not (type(argument) == "string") then
        return argument
    end
    local parapattern = "^%s*(%w+)%s+(.*)$"
    local args = {}
    argument = argument.." "
    while string.match(argument, parapattern) do
        table.insert(args, (string.gsub(argument, parapattern, "%1")))
        argument = string.gsub(argument, parapattern, "%2")
    end
    if not string.match(argument, "^%s*$") then
        table.insert(args, interpret(argument))
    end
    return unpack(args)
end

function dualarg(argument)
    return string.match(argument, "%s*(%S+)%s+(%S+)%s*$")
end

function extract(argument)
    local parameter,space = string.match(argument, "^%s*(.+)%s*@%s*(.+)%s*$")
    return interpret(parameter), space
end

local function primitive(type)
    return function(argument)
        local parameter, space = extract(argument)
        hexameter.tell(type, target, space, {parameter})
    end
end

local function execute(input)
    local command = string.match(input, "^(%w+)%s*")
    local argument = string.gsub(input, "^(%w+)%s*", "")
    local call = commands[environment][command] or commands["standard"][command] or commands["user"][command]
    if type(call) == "function" then
        call(argument, me, target, environment, focus, hiddenvars)
    else
        io.write("##  unrecognized command \"", command or "<none>", "\"\n")
    end
end

local function run(file)
    local buffer = ""
    local top = true
    for line in io.lines(file) do
        if not string.match(line, "^%s*$") then
            if not string.match(line, "^%s*#") then
                if string.match(line, "^%s*//") then
                    top = false
                elseif string.match(line, "%s*\\\\") then
                    execute(buffer)
                    buffer = ""
                    top = true
                else
                    if top then
                        execute(line)
                    else
                        buffer = buffer..line.."\n"
                    end
                end
            end
        end
    end
end

commands = {
    standard = {
        lua = function (argument)
            print("%%  ", loadstring("return "..argument)())
        end,
        target = function (argument)
            if string.match(argument, "^%s*$") then
                target = me
            elseif string.match(argument, "^%d+$") then
                target = "localhost:"..argument
            else    
                target = argument
            end
        end,
        qry = primitive("qry"),
        get = primitive("get"),
        put = primitive("put"),
        respond = function ()
            hexameter.respond()
        end,
        quit = function ()
            --hexameter.term()
            os.exit()
        end,
        meet = function (argument)
            --argument = string.gsub(argument, "%s", "")
            commands.standard.target(argument)
            hexameter.meet(target)
        end,
        friends = function ()
            print("==  ", serialize.literal(hexameter.friends()))
        end,
        checkex = function (argument)
            local parameter, space = extract(argument)
            local result = hexameter.ask("qry", me, space, {parameter})
            print("^^  ", serialize.data(result))
        end,
        check = function (argument)
            local parameter, space = extract(argument)
            local result = hexameter.process("qry", target, space, {parameter})
            print("^^  ", serialize.data(result))
        end,
        enter = function (argument)
            local env, focus = multiarg(argument)
            if commands[env] then
                if commands[environment].exit then
                    commands[environment].exit()
                end
                environment = env
                if commands[environment].init then
                    commands[environment].init(focus)
                end
            else
                print("## command environment \"", env, "\" does not exist.")
            end
        end,
        help = function ()
            io.write("~~  available commands: help")
            for name,command in pairs(commands.standard) do
                if not (name == "help") then
                    io.write(", "..name)
                end
            end
            io.write("\n")
        end,
        define = function (argument)
            local name, body = multiarg(argument)
            commands.user[name] = body
        end,
        alt = function (argument) --TODO: augment this with error messages in cases in which it doesn't work as expected!
            local original,new = dualarg(argument)
            commands.user[new] = commands.user[original]
        end,
        include = function(argument)
            print("::  Loading "..argument.."...")
            run(argument)
        end
    },
    user = {},
    hades = {
        init = function (argument)
            focus = multiarg(argument)
            if not focus then
                io.write("??  Enter body to be controlled: ")
                focus = io.read("*line")
            end
        end,
        tock = function (argument)
            local duration = tonumber(argument)
            hexameter.tell("put", target, "tocks", {{body=focus, duration=duration}})
        end,
        sensor = function (argument)
            local type, control = multiarg(argument)
            local result = hexameter.ask("qry", target, "sensors", {{body=focus, type=type, control=control}})
            print("++  ", serialize.data(result))
        end,
        motor = function (argument)
            local type, control = multiarg(argument)
            hexameter.tell("put", target, "motors", {{body=focus, type=type, control=control}})
        end,
        --from here on, these are specific commands to control specific motors, which may or may not be available thorugh hades
        --TODO: put these commands in external libraries, which are loaded by ghost commands in the scenarios' respective prooimion/greeting scripts
        ["do"] = function (argument)
            local type, control = multiarg(argument)
            hexameter.tell("put", target, "motors", {
                {body=focus, type=type, control=control},
                {body=focus, type="perform", control={actions={type=type, control=control}}}
            })
            --hexameter.tell("put", target, "motors", {{body=focus, type="perform", control={actions={type=type, control=control}}}})
        end,
        --you'll find this in the greeting.ghost now!
        --teach = function (argument)
        --    local action, control = multiarg(argument)
        --    hexameter.tell("put", target, "motors", {{body=focus, type="teach", control={idea={action=action, control=control}}}})
        --end
    }
}

commands.standard.l = commands.standard.lua
commands.standard.t = commands.standard.target
commands.standard.q = commands.standard.quit
commands.standard.m = commands.standard.meet
commands.standard.e = commands.standard.enter
commands.standard.re = commands.standard.respond
commands.standard.ch = commands.standard.check
commands.standard.fs = commands.standard.friends
commands.standard.ch = commands.standard.check
commands.standard.def = commands.standard.define
commands.standard.inc = commands.standard.include

if arg[1] then
    me = arg[1]
else
    io.write("??  Enter an address:port for this component: ")
    me = io.read("*line")
end

hexameter.init(me, nil, {"networking", "forwarding", "flagging", "verbose"})
target = me
environment = "standard"
focus = ""

if arg[2] then
    run(arg[2])
end

while true do
    io.write("[", me, "] for [", target, "]> ")
    if not (environment == "standard") then
        if not (focus == "") then
            io.write("{", focus, "|", environment, "} ")
        else
            io.write("{", environment, "} ")
        end
    end
    local input = io.read("*line")
    execute(input)
end