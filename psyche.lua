-- PSYCHE system character emulation
package.path = (string.match(arg[0], "^.*/") or "./").."hexameter/?.lua;"..package.path
require "hexameter"
require "serialize"
local show = serialize.presentation

local possess = {} --unique flag
local avoid = {}   --unique flag

local realm, me, character

local bodies = {}
local souls = {}
local allsouls = false

if arg[1] then
    realm = arg[1]
else
    io.write("??  Enter an address:port for the world simulator: ")
    realm = io.read("*line")
end

if arg[2] then
    me = arg[2]
else
    io.write("??  Enter an address:port for this component: ")
    me = io.read("*line")
end

if arg[3] then
    for part in string.gmatch(arg[3]..",", "([^,]*),") do
        if not (part == "") then
            if part == "..." then
                allsouls = true
            else
                local firstchar = string.match(part, "^(.)")
                local name = string.gsub(part, "^[-\+]", "")
                if firstchar == "-" then
                    souls[name] = avoid
                else
                    souls[part] = possess
                end
            end
        end
    end
    local bodystr = ""
    local beginning = true
    bodystr = bodystr..(allsouls and "all bodies except " or "bodies ")
    for name,rule in pairs(souls) do
        if (allsouls and (rule == avoid) or (rule == possess)) then
            bodystr = bodystr..(beginning and "" or ", ")..name
            beginning = false
        end
    end
    io.write("::  Controlling "..bodystr..".\n")
else
    allsouls = true
    io.write("::  Controlling all bodies by default.\n")
end

if arg[4] then
    io.write("::  Loading "..arg[4].."...")
    character = dofile(arg[4])(realm, me)
    io.write("\n")
else
    character = function () end
    --TODO: implement at least a simple, but meaningful default behavior!
end

local story = function ()
    local clock = 0
    return function(msgtype, author, space, parameter)
        if msgtype == "put" and space == "hades.ticks" then
            local newclock = clock
            for _,item in pairs(parameter) do
                newclock = item.period > newclock and item.period or newclock
            end
            if newclock > clock then
                clock = newclock
                print()
                print()
                print("::  Entering time period #"..clock)
                for name,addresses in pairs(bodies) do
                    if (allsouls and not (souls[name] == avoid)) or (souls[name] == possess) then
                        print()
                        print("::  Computing "..name)
                        character(clock, name)
                        hexameter.tell("put", realm, "tocks", {{body=name}})
                    end
                end
            end
        end
    end
end

hexameter.init(me, story)

io.write("::  Psyche running. Please exit with Ctrl+C.\n")

hexameter.meet(realm)
hexameter.converse()

bodies = hexameter.ask("qry", realm, "report", {{}})[1].bodies --TODO: Hardcoding [1] is probably a bit hacky
io.write("##  Recognized "..show(bodies).."\n")

for name,addresses in pairs(bodies) do
    if (allsouls and not (souls[name] == avoid)) or (souls[name] == possess) then
        hexameter.put(realm, "ticks", {{body=name, soul=me}})
        hexameter.put(realm, "tocks", {{body=name}})
    end
end

while true do
    hexameter.respond(0)
end