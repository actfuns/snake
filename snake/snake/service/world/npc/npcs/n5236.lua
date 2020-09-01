local global = require "global"
local schoolteacher = import(service_path("npc/schoolteacher"))

CNpc = {}
CNpc.__index = CNpc
inherit(CNpc, schoolteacher.CNpc)

function NewGlobalNpc(npctype)
    local o = CNpc:New(npctype)
    return o
end

function CNpc:New(npctype)
    local o = super(CNpc).New(self, npctype)
    return o
end
