local global = require "global"
local npcobj = import(service_path("npc/npcobj"))

CNpc = {}
CNpc.__index = CNpc
inherit(CNpc,npcobj.CGlobalNpc)

function CNpc:New(npctype)
    local o = super(CNpc).New(self,npctype)
    return o
end

function CNpc:do_look(oPlayer)
    self:DoLookNpc(oPlayer)
end

function CNpc:DoLookNpc(oPlayer)
    local npcid = self:ID()
    local pid = oPlayer:GetPid()
    if not global.oToolMgr:IsSysOpen("RUNRING") then
        super(CNpc).do_look(self, oPlayer)
        return
    end
    -- if not global.oRunRingMgr:HasAcceptTimes(oPlayer) and global.oRunRingMgr:HasTask(oPlayer) then
    --     super(CNpc).do_look(self, oPlayer)
    --     return
    -- end
    local sText = self:GetText(oPlayer)
    local sOption1 = global.oToolMgr:GetTextData(63021, {"task_ext"})
    local sOption2 = global.oToolMgr:GetTextData(63031, {"task_ext"})
    sText = sText .. "&Q" .. sOption1 .. "&Q" .. sOption2
    self:SayRespond(pid, sText, nil, function(oPlayer, mData)
        local oNpc = global.oNpcMgr:GetObject(npcid)
        if oNpc then
            oNpc:OnClickNpcOptions(oPlayer, mData)
        end
    end)
end

function CNpc:OnClickNpcOptions(oPlayer, mData)
    local iAnswer = mData.answer
    if iAnswer == 1 then
        if not global.oRunRingMgr:HasAcceptTimes(oPlayer) then
            local sMsg = global.oToolMgr:GetTextData(63028, {"task_ext"})
            oPlayer:NotifyMessage(sMsg)
            return
        end
        if global.oRunRingMgr:HasTask(oPlayer) then
            local sMsg = global.oToolMgr:GetTextData(63022, {"task_ext"})
            oPlayer:NotifyMessage(sMsg)
            return
        end
        self:OpenRunringMenu(oPlayer)
    elseif iAnswer == 2 then
        oPlayer:Send("GS2CRunringIntro", {})
    end
end

function CNpc:OpenRunringMenu(oPlayer)
    local sText = global.oToolMgr:GetTextData(63023, {"task_ext"})
    sText = global.oToolMgr:FormatColorString(sText, {
        max_ring = global.oRunRingMgr:MaxRing(),
    })
    local pid = oPlayer:GetPid()
    local npcid = self:ID()
    local cbFunc = function(oPlayer, mData)
        local oNpc = global.oNpcMgr:GetObject(npcid)
        if oNpc then
            oNpc:OnClickRunringMenu(oPlayer, mData)
        end
    end
    self:SayRespond(pid, sText, nil, cbFunc, nil, true)
end

function CNpc:OnClickRunringMenu(oPlayer, mData)
    if mData.answer == 1 then
        if not global.oRunRingMgr:IsSysOpen(oPlayer) then
            return
        end
        global.oRunRingMgr:AcceptWeek(oPlayer, self)
    end
end

function NewGlobalNpc(npctype)
    local o = CNpc:New(npctype)
    return o
end
