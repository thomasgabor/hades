module(..., package.seeall)

require "sisyphos"
require "tantalos"

function write(content)
    if content then
        if environment.prefix then
            io.write(environment.prefix, "  ", content)
        else
            io.write(content)
        end
    end
end

function writeln(content)
    write(content)
    io.write("\n")
end

--TODO: expand this with dynamic loading etc
--TODO: ...and text output handling