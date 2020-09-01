local global = require "global"
local res = require "base.res"
local record = require "public.record"
local extend = require "base.extend"
local taskobj = import(service_path("task/taskobj"))
local taskdefines = import(service_path("task/taskdefines"))

function NewTask(taskid)
    local o = CTask:New(taskid)
    return o
end

CTask = {}
CTask.__index = CTask
CTask.m_sName = "baotu"
CTask.m_sTempName = "摸金寻龙"
inherit(CTask, taskobj.CTask)

function CTask:Init()
    super(CTask).Init(self)
    self.m_iScheduleID = 1028
end

function CTask:IsLogTaskWanfa()
    return true
end

function CTask:AfterMissionDone(iPid)
    local oPlayer = global.oWorldMgr:GetOnlinePlayerByPid(iPid)
    if not oPlayer then return end

    local iTask = self.m_ID
    oPlayer.m_oScheduleCtrl:Add(self.m_iScheduleID)
    global.oTaskHandler:TryAcceptBaotuTask(oPlayer, false, {[iTask] = 1})
end

function CTask:ValidFight(pid,npcobj,iFight)
    local bRet = super(CTask).ValidFight(self, pid, npcobj, iFight)
    if not bRet then return bRet end

    local oPlayer = global.oWorldMgr:GetOnlinePlayerByPid(pid)
    if oPlayer:IsSingle() or oPlayer:IsTeamLeader() then
        return true
    end
    return false
end
