local global = require "global"
local npcobj = import(service_path("npc/npcobj"))
local taskdefines = import(service_path("task/taskdefines"))

CNpc = {}
CNpc.__index = CNpc
inherit(CNpc, npcobj.CGlobalNpc)

function CNpc:New(npctype)
    local o = super(CNpc).New(self, npctype)
    return o
end

function CNpc:do_look(oPlayer)
    local npctype = self:Type()
    if oPlayer.m_oActiveCtrl.m_oVisualMgr:GetNpcVisible(oPlayer, npctype) == 0 then
        return
    end
    local oTask = global.oSchoolPassHandler:GetTask(oPlayer)
    local npcid = self:ID()
    local sText
    if oTask and oTask:GetEvent(npcid) then
        sText = global.oHuodongMgr:CallHuodongFunc("schoolpass", "GetTextData", 1002)
    end
    local iSchool = oPlayer:GetSchool()
    local iSchoolTeacher = global.oToolMgr:GetSchoolTeacher(iSchool)
    if npctype == iSchoolTeacher then
        local oHasTask = oPlayer.m_oTaskCtrl:GotTaskKind(taskdefines.TASK_KIND.SHIMEN)
        if not oHasTask or oHasTask:Target() ~= self:Type() then
            local sOption = global.oToolMgr:GetTextData(1101, {"task_ext"})
            if not sText then
                sText = self:GetText(oPlayer)
            end
            local iOptPos = string.find(sText, "&Q")
            if not iOptPos then
                sText = sText .. "&Q" .. sOption
            else
                sText = string.sub(sText, 1, iOptPos) .. "&Q" .. sOption .. string.sub(sText, iOptPos + 1)
            end
        end
    end
    if not sText then
        super(CNpc).do_look(self, oPlayer)
        return
    end
    local pid = oPlayer:GetPid()
    local func = function(oPlayer, mData)
        local oNpc = global.oNpcMgr:GetObject(npcid)
        if oNpc then
            oNpc:NpcResponse(oPlayer, mData)
        end
    end
    self:SayRespond(pid, sText, nil, func)
end

function CNpc:NpcResponse(oPlayer, mData)
    local iAnswer = mData.answer or 0
    local npctype = self:Type()
    local iSchool = oPlayer:GetSchool()
    local iSchoolTeacher = global.oToolMgr:GetSchoolTeacher(iSchool)
    local bNoClickShimenTask
    if npctype ~= iSchoolTeacher then
        bNoClickShimenTask = true
    else
        local oHasTask = oPlayer.m_oTaskCtrl:GotTaskKind(taskdefines.TASK_KIND.SHIMEN)
        if oHasTask and oHasTask:Target() == self:Type() then
            bNoClickShimenTask = true
        end
    end
    if bNoClickShimenTask then
        iAnswer = iAnswer + 1
    end

    if iAnswer == 1 then
        self:ClickToShimenTask(oPlayer)
    elseif iAnswer == 2 then
        global.oSchoolPassHandler:Fight(oPlayer, self:ID())
    end
end

function CNpc:ClickToShimenTask(oPlayer)
    local oHasTask = oPlayer.m_oTaskCtrl:GotTaskKind(taskdefines.TASK_KIND.SHIMEN)
    if not global.oToolMgr:IsSysOpen("SHIMEN", oPlayer) then
        if oHasTask then
            oHasTask:FullRemove()
        end
        -- local sTips = global.oToolMgr:GetTextData(1102, {"task_ext"})
        -- oPlayer:NotifyMessage(global.oToolMgr:FormatColorString(sTips, {grade = global.oToolMgr:GetSysOpenPlayerGrade("SHIMEN")}))
        return
    end
    if not oHasTask then
        local iDoneRing = global.oShimenMgr:GetShimenTodayDoneRing(oPlayer)
        if iDoneRing >= taskdefines.SHIMEN_INFO.LIMIT_RINGS then
            local sTips = global.oToolMgr:GetTextData(1103, {"task_ext"})
            oPlayer:NotifyMessage(sTips)
            return
        end
        oPlayer.m_oTaskCtrl:TouchShimenNew(oPlayer)
        return
    end
    if oHasTask:Target() == self:Type() then
        -- 执行任务
        if oHasTask:CanTaskSubmit(self) then
            oHasTask:DoNpcEvent(oPlayer:GetPid(), self:ID())
            return
        end
    end
    local sTips = global.oToolMgr:GetTextData(1104, {"task_ext"})
    oPlayer:NotifyMessage(sTips)
end
