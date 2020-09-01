local global = require "global"
local npcobj = import(service_path("npc/npcobj"))

CNpc = {}
CNpc.__index = CNpc
inherit(CNpc,npcobj.CGlobalNpc)

function NewGlobalNpc(npctype)
    local o = CNpc:New(npctype)
    return o
end

function CNpc:New(npctype)
    local o = super(CNpc).New(self,npctype)
    return o
end

function CNpc:do_look(oPlayer)
    local oHuodongMgr = global.oHuodongMgr
    local oTask = global.oSchoolPassHandler:GetTask(oPlayer)
    local npcid = self:ID()
    if oTask and oTask:GetEvent(npcid) then
        local func = function(oPlayer, mData)
            local oNpc = global.oNpcMgr:GetObject(npcid)
            if oNpc then
                oNpc:NpcResponse(oPlayer, mData)
            end
        end
        local sText = self:GetText(oPlayer)
        local sChoose = "参加试炼"
        sText = string.format("%s%s%s", sText, "&Q", sChoose)
        local oHuodong = oHuodongMgr:GetHuodong("schoolpass")
        oHuodong:SayText(oPlayer:GetPid(), self, sText, func)
        return
    end
    local pid = oPlayer:GetPid()
    local sText  = self:GetText(oPlayer)
    local menulist = {}
    local oLiuMai  = oHuodongMgr:GetHuodong("liumai")
    if oLiuMai and oLiuMai.m_mShouXimate[pid] then
        sText = sText .. "Q" .. "改变造型"
        table.insert(menulist,1)
    end
    self:SayRespond(pid,sText,nil, function (oPlayer, mData)
        local oNpcMgr = global.oNpcMgr
        local oNpc = oNpcMgr:GetObject(npcid)
        if oNpc then
            oNpc:Respond(oPlayer, mData,menulist)
        end
    end)
end

function CNpc:Respond(oPlayer,mData,menulist)
    local pid = oPlayer:GetPid()
    local iAnswer = mData["answer"]
    iAnswer = menulist[iAnswer]
    if iAnswer ==1 then     --liumai
        local hdobj = global.oHuodongMgr:GetHuodong("liumai")
        if hdobj then
            hdobj:SetSXNPCModel(pid)
        end
    end
end

function CNpc:NpcResponse(oPlayer, mData)
    if mData["answer"] == 1 then
        global.oSchoolPassHandler:Fight(oPlayer, self:ID())
    end
end

