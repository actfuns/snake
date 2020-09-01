local global = require "global"
local npcobj = import(service_path("npc/npcobj"))
local res = require "base.res"

CNpc = {}
CNpc.__index = CNpc
inherit(CNpc, npcobj.CGlobalNpc)

function NewGlobalNpc(npctype)
    local o = CNpc:New(npctype)
    return o
end

function CNpc:do_look(oPlayer)
    local oHuodong = self:GetJieBai()
    if not oHuodong then return end

    local iNpc = self:ID()
    local func = function(oPlayer, mData)
        DoRespond(oPlayer, mData, iNpc)
    end

    local iGrade = oPlayer:GetGrade()
    local sMsg = oHuodong:GetTextData(1090)
    local LIMIT_GRADE = res["daobiao"]["open"]["JIEBAI"]["p_level"]
    if iGrade < LIMIT_GRADE then
        sMsg = string.sub(sMsg, 1, string.find(sMsg, "&Q"))
    end
    self:SayRespond(oPlayer:GetPid(), sMsg, nil, func)
end

function CNpc:DoRespond(oPlayer, iAnswer)
    if iAnswer == 1 then
        oPlayer:Send("GS2CJiaBaiClickNpc", { flag = 1 })
    elseif iAnswer == 2 then
        oPlayer:Send("GS2CJiaBaiClickNpc", { flag = 2 })
    elseif iAnswer == 3 then
        oPlayer:Send("GS2CJiaBaiClickNpc", { flag = 3 })
    end
end

function CNpc:GetJieBai()
    return global.oHuodongMgr:GetHuodong("jiebai")
end

function DoRespond(oPlayer, mData, iNpc)
    local oNpc = global.oNpcMgr:GetObject(iNpc)
    if oNpc then
        oNpc:DoRespond(oPlayer, mData.answer)
    end
end
