--tartaros plug-in for static environment specification (and other recurring tasks)

--this version of sisyphos provides functions to specify a graph-based world model

local S = {}

local world
local graph = {nodes={}, edges={}}

function S.edition()
    return "sisyphos_graph"
end

function S.init(tartaros, worldtable)
    world = worldtable
    local metaworld = getmetatable(world)
    metaworld.tartaros.sisyphos_graph.state = metaworld.tartaros.sisyphos_graph.state or {nodes={}, edges={}}
    graph = metaworld.tartaros.sisyphos_graph.state
end

function S.revive(originalstate)
    graph = originalstate
    return originalstate
end

function S.stuff()
    return graph
end

function S.makenode(x, y, cost, objects)
    local newnode = {x=x, y=y, cost=cost or 0, objects=objects or {}}
    graph.nodes[x] = graph.nodes[x] or {}
    graph.nodes[x][y] = newnode
    return newnode
end

function S._makenode(item)
    return S.makenode(item.x, item.y, item.cost, item.objects)
end


function S.removenode(x, y)
    if graph.nodes[x] then
        graph.nodes[x][y] = nil
        return true
    end
    return false
end

function S._removenode(item)
    return S.removenode(item.x, item.y)
end

function S.getnode(x, y)
    if type(x) == "table" then
        x, y = x.x, x.y
    end
    if graph.nodes[x] then
        return graph.nodes[x][y]
    end
    return nil
end

function S._getnode(item)
    return S.getnode(item.x, item.y)
end

function S.getedges(x, y)
    if type(x) == "table" then
        x, y = x.x, x.y
    end
    if graph.edges[x] then
        return graph.edges[x][y] or {}
    end
    return {}
end

function S._getedges(item)
    return S.getedges(item.x, item.y)
end

function S.getedge(from, to)
    if not from or not to or not from.x or not from.y or not to.x or not to.y then
        return false
    end
    if graph.edges[from.x] and graph.edges[from.x][from.y] and graph.edges[from.x][from.y][to.x] then
        return graph.edges[from.x][from.y][to.x][to.y]
    end
    return nil
end

function S._getedge(item)
    return S.getedge(item.from, item.to)
end

function S.makeedge(from, to, cost)
    if not from.x or not from.y or not to.x or not to.y then
        return false
    end
    local newedge = {from=from, to=to, cost=cost or 0}
    graph.edges[from.x] = graph.edges[from.x] or {}
    graph.edges[from.x][from.y] = graph.edges[from.x][from.y] or {}
    graph.edges[from.x][from.y][to.x] = graph.edges[from.x][from.y][to.x] or {}
    graph.edges[from.x][from.y][to.x][to.y] = newedge
    return newedge
end

function S._makeedge(item)
    return S.makeedge(item.from, item.to, item.cost)
end

function S.removeedge(from, to)
    if not from.x or not from.y or not to.x or not to.y then
        return false
    end
    if graph.edges[from.x] and graph.edges[from.x][from.y] and graph.edges[from.x][from.y][to.x] then
        graph.edges[from.x][from.y][to.x][to.y] = nil
        return true
    end
    return false
end

function S._removeedge(item)
    --print("&&&&& EDGE REMOVED")
    return removeedge(item.from, item.to)
end

local counters = {}

function S.makeobject(x, y, object)
    if not x or not y or not graph.nodes[x] or not graph.nodes[x][y] then
        return false
    end
    if not graph.nodes[x][y].objects then
        graph.nodes[x][y].objects = {}
    end
    if not object.class then
        object.class = "object"
    end
    if not object.id then
        counters[object.class] = counters[object.class] and (counters[object.class] + 1) or 1
        object.id = object.class.."-"..counters[object.class]
    end
    graph.nodes[x][y].objects[object.id] = object
end

function S._makeobject(item)
    return makeobject(item.x, item.y, item.object)
end

local homes = {}

function S.makehome(x, y)
    homes[x] = homes[x] or {}
    homes[x][y] = true
end

function S._makehome(item)
    return makehome(item.x, item.y)
end

function S.ishome(x, y)
    if homes[x] and homes[x][y] then
        return "yes"
    else
        return "no"
    end
end

function S._ishome(item)
    return S.ishome(item.x, item.y)
end

function S.allhomes()
    local positions = {}
    for x,entry in pairs(homes) do
        for y,slot in pairs(entry) do
            if slot then
                local home = S.getnode(x, y)
                table.insert(positions, home)
            end
        end
    end
    return positions
end

local labels = {}

function S.label(x, y, name)
    labels[name] = {x = x, y = y}
end

function S._label(item)
    return S.label(item.x, item.y, item.name)
end

function S.lookup(name)
    if labels[name] and labels[name].x and labels[name].y and graph.nodes[labels[name].x] then
        return graph.nodes[labels[name].x][labels[name].y]
    end
    return nil
end

function S._lookup(item)
    return S.lookup(item.name)
end

return S