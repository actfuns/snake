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
    local sMsg = oHuodong:GetTextData(1001)
    self:SayRespond(oPlayer:GetPid(), sMsg, nil, func)
end

function CNpc:DoRespond(oPlayer, iAnswer)
    if iAnswer == 1 then
        local oHuodong = self:GetBuddy()
        oHuodong:CheckGiveTask(oPlayer, self, true)
    elseif iAnswer == 2 then
        oPlayer:Send("GS2CGuessGameIntroduce", {})
    end
end

function CNpc:GetBuddy()
    return global.oHuodongMgr:GetHuodong("guessgame")
end

function DoRespond(oPlayer, mData, iNpc)
    local oNpc = global.oNpcMgr:GetObject(iNpc)
    if oNpc then
        oNpc:DoRespond(oPlayer, mData.answer)
    end
end
