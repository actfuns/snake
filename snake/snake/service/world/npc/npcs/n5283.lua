local global = require "global"
local npcobj = import(service_path("npc/npcobj"))

CNpc = {}
CNpc.__index = CNpc
inherit(CNpc, npcobj.CGlobalNpc)

function NewGlobalNpc(npctype)
    local o = CNpc:New(npctype)
    return o
end

function CNpc:do_look(oPlayer)
    local oHuodong = self:GetBuddy()
    local iNpc = self:ID()
    local func = function(oPlayer, mData)
        DoRespond(oPlayer, mData, iNpc)
    end
    local sMsg = oHuodong:GetTextData(4001)
    self:SayRespond(oPlayer:GetPid(), sMsg, nil, func)
end

function CNpc:DoRespond(oPlayer, iAnswer)
    if iAnswer == 1 then
        local oHuodong = self:GetBuddy()
        oHuodong:TryEnterPrepareRoom(oPlayer)
    elseif iAnswer == 2 then
        --TODO 顺便改火眼金睛的协议
        oPlayer:Send("GS2CHuodongIntroduce", {id=10029})
    end
end

function CNpc:GetBuddy()
    return global.oHuodongMgr:GetHuodong("orgwar")
end

function DoRespond(oPlayer, mData, iNpc)
    local oNpc = global.oNpcMgr:GetObject(iNpc)
    if oNpc then
        oNpc:DoRespond(oPlayer, mData.answer)
    end
end
