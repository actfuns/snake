local global = require "global"
local npcobj = import(service_path("npc/npcobj"))

CNpc = {}
CNpc.__index = CNpc
inherit(CNpc, npcobj.CGlobalNpc)

function NewGlobalNpc(npctype)
    local o = CNpc:New(npctype)
    return o
end

local function DoRespond(oPlayer, mData, iNpc)
    local oNpc = global.oNpcMgr:GetObject(iNpc)
    if oNpc then
        oNpc:DoRespond(oPlayer, mData.answer)
    end
end

function CNpc:do_look(oPlayer)
    local oHuodong = self:GetHuodong()
    local iNpc = self:ID()
    local func = function(oPlayer, mData)
        DoRespond(oPlayer, mData, iNpc)
    end
    local iText = oHuodong:ValidGiveTask(oPlayer)
    if iText == 1 then return end
    local sText = oHuodong:GetHuodongTextData(oPlayer, iText)
    self:SayRespond(oPlayer:GetPid(), sText, nil, func)
end

function CNpc:DoRespond(oPlayer, iAnswer)
    local oHuodong = self:GetHuodong()
    local iText = oHuodong:ValidGiveTask(oPlayer)
    if iAnswer == 1 then
        if iText == 1005 or iText == 1006 then
            oHuodong:CheckGiveTask(oPlayer)
        elseif iText == 1004 or iText == 1009 or iText == 1010 or iText == 1011 then
            oPlayer:Send("GS2CHuodongIntroduce", { id = 17000 })
        elseif iText == 1015 then
            local pid = oPlayer:GetPid()
            local iCurRound = oHuodong:GetCurRound(pid)
            oHuodong:FindPathToNpc(pid, iCurRound)
        end
    elseif iAnswer == 2 then
        if iText == 1005 or iText == 1006 then
            oPlayer:Send("GS2CHuodongIntroduce", { id = 17000 })
        end
    end
end

function CNpc:GetHuodong()
    return global.oHuodongMgr:GetHuodong("imperialexam")
end