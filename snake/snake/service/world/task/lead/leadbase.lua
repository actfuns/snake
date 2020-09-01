local global = require "global"
local taskobj = import(service_path("task/taskobj"))
local gamedefines = import(lualib_path("public.gamedefines"))

CTask = {}
CTask.__index = CTask
CTask.m_sName = "lead"
CTask.m_sTempName = "引导任务"
inherit(CTask, taskobj.CTask)

function CTask:New(taskid)
    local o = super(CTask).New(self,taskid)
    local iLinkId = global.oTaskLoader:GetLinkHeads(self.m_sName)[taskid]
    if iLinkId then
        o:SetLinkId(iLinkId)
    end
    return o
end

function CTask:AfterMissionDone(pid)
    super(CTask).AfterMissionDone(self, pid)
end

function CTask:RewardMissionDone(pid, npcobj, mRewardArgs)
    super(CTask).RewardMissionDone(self, pid, npcobj, mRewardArgs)
end

function CTask:Remove()
    if not self.m_bClearly then
        local oPlayer = global.oWorldMgr:GetOnlinePlayerByPid(self:GetOwner())
        if oPlayer then
            global.oTaskMgr:TryBackupAcceptable(oPlayer, self)
            global.oTaskMgr:TryRecLinkDone(oPlayer, self)
        end
    end
    super(CTask).Remove(self)
end

function CTask:Reward(pid, sIdx, mArgs)
    local oPlayer = global.oWorldMgr:GetOnlinePlayerByPid(pid)
    if not oPlayer then
        return
    end
    local oRewardMonitor = global.oTaskMgr:GetStoryTaskRewardMonitor()
    if oRewardMonitor then
        if not oRewardMonitor:CheckRewardGroup(pid, self.m_sName, self:GetId(), 1, mArgs) then
            return
        end
    end
    return super(CTask).Reward(self, pid, sIdx, mArgs)
end

-- 不可放弃
function CTask:Abandon()
    return
end

-- @Override
function CTask:IsWarTeamMembersShareDone(oWar, iWarCallerPid, npcobj, mWarCbArgs)
    return true
end

function CTask:OnAddDone(oPlayer)
    super(CTask).OnAddDone(self, oPlayer)

    local oPlayer = global.oWorldMgr:GetOnlinePlayerByPid(self:GetOwner())
    if not oPlayer then return end

    --合宠引导任务,有神犬骑兵直接完成
    if self:GetId() == 30029 then
        local oSummons = oPlayer.m_oSummonCtrl.m_mSummons
        for _, oSummon in pairs(oSummons) do
            local sSid = oSummon:GetData("sid")
            if sSid == 1003 then
                self:MissionDone()
                break
            end
        end
    end
end

function CTask:GetConfigLinkId()
    local mConfig = global.oTaskLoader:GetKindLinks("lead")
    local mBaseData = self:GetTaskBaseData()

    for iLinkId, mData in pairs(mConfig) do
        local iCurTaskId = mData.head
        --指引任务一个链上不会超过20个这么多
        for i=1, 20 do
            if not iCurTaskId then
                break
            end
            if self:GetId() == iCurTaskId then
                return iLinkId
            end
            local mTaskData = mBaseData["task"][iCurTaskId]
            if mTaskData and mTaskData._next_task then
                iCurTaskId = mTaskData._next_task
            end
        end     
    end
end

function NewTask(taskid)
    local o = CTask:New(taskid)
    return o
end
