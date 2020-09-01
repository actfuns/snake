local global = require "global"
local npcobj = import(service_path("npc/npcs/n5236"))

CNpc = {}
CNpc.__index = CNpc
inherit(CNpc, npcobj.CNpc)

function NewGlobalNpc(npctype)
    local o = CNpc:New(npctype)
    return o
end

