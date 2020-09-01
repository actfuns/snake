local global = require "global"
local res = require "base.res"
local taskobj = import(service_path("task/taskobj"))
local gamedefines = import(lualib_path("public.gamedefines"))

CSideTask = {}
CSideTask.__index = CSideTask
CSideTask.m_sName = "side"
CSideTask.m_sTempName = "支线任务"
inherit(CSideTask, taskobj.CTask)

function CSideTask:New(taskid)
    local o = super(CSideTask).New(self, taskid)
    local iLinkId = global.oTaskLoader:GetLinkHeads(self.m_sName)[taskid]
    if iLinkId then
        o:SetLinkId(iLinkId)
    end
    return o
end

function CSideTask:GetXiayiDifficultyLimit()
    return res["daobiao"]["moneypoint"]["other_limit"]["side_difficulty"]["value"]
end

function CSideTask:DealBeforeOnWarWin(oWar, pid, npcobj, mWarCbArgs)
    local oLeader = global.oWorldMgr:GetOnlinePlayerByPid(pid)
    if oLeader  and self:TaskType() == gamedefines.TASK_TYPE.TASK_NPC_FIGHT then
        local mWarResult = {}
        mWarResult.lLastFighterPid = self:GetFighterList(oLeader, mWarCbArgs)
        mWarResult.iLastLeaderPid = pid
        mWarResult.iLastWarIdx = oWar.m_iIdx
        self.m_mLastWarResult = mWarResult
    end
end

function CSideTask:MissionDone(npcobj, mArgs)
    if self.m_mLastWarResult and self:TaskType() == gamedefines.TASK_TYPE.TASK_NPC_FIGHT then
        local mWarResult = self.m_mLastWarResult
        self:TryRewardFighterXiayiPoint(mWarResult.iLastLeaderPid, mWarResult.lLastFighterPid, {iWarIdx = mWarResult.iLastWarIdx})
        self.m_mLastWarResult = nil
    end
    super(CSideTask).MissionDone(self, npcobj, mArgs)
end

function CSideTask:TryRewardFighterXiayiPoint(iLeaderPid, lFighterPid, mArgs)
    local m = self:GetTollGateData(mArgs.iWarIdx)
    local iDifficulty = m["difficulty"][1]
    if not iDifficulty then return end 
    if iDifficulty <  self:GetXiayiDifficultyLimit() then return end

    local function FilterFighter(iLeaderPid, lFighterPid)
        local lRetPid = {}
        for _, pid in pairs(lFighterPid) do
            if pid ~= iLeaderPid then
                table.insert(lRetPid, pid)
            end
        end
        return lRetPid
    end

    local lRewardPid = self:RewardFighterFilter(iLeaderPid, lFighterPid, FilterFighter)
    local oLeader = global.oWorldMgr:GetOnlinePlayerByPid(iLeaderPid)
    local iLeaderOrgID = oLeader:GetOrgID()
    for _, pid in pairs(lRewardPid) do
        local oFighter = global.oWorldMgr:GetOnlinePlayerByPid(pid)
        if oFighter then
            if oFighter:GetOrgID() == iLeaderOrgID and oFighter:GetOrgID() ~= 0 then
                self:RewardXiayiPoint(oFighter, "branch_fight2", "支线剧情同帮派")
            else
                self:RewardXiayiPoint(oFighter, "branch_fight", "支线剧情")
            end
        end
    end
end

function CSideTask:AfterMissionDone(pid)
    super(CSideTask).AfterMissionDone(self, pid)
end

function CSideTask:RewardMissionDone(pid, npcobj, mRewardArgs)
    super(CSideTask).RewardMissionDone(self, pid, npcobj, mRewardArgs)
end

function CSideTask:Remove()
    if not self.m_bClearly then
        local oPlayer = global.oWorldMgr:GetOnlinePlayerByPid(self:GetOwner())
        if oPlayer then
            global.oTaskMgr:TryBackupAcceptable(oPlayer, self)
            global.oTaskMgr:TryRecLinkDone(oPlayer, self)
        end
    end
    super(CSideTask).Remove(self)
end

function CSideTask:Reward(pid, sIdx, mArgs)
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
    return super(CSideTask).Reward(self, pid, sIdx, mArgs)
end

-- @Override
function CSideTask:IsWarTeamMembersShareDone(oWar, iWarCallerPid, npcobj, mWarCbArgs)
    return true
end

function CSideTask:SummonExpEffect()
    return false
end

function CSideTask:PartnerExpEffect()
    return false
end

function CSideTask:PlayerExpEffect()
    return false
end
function NewTask(taskid)
    local o = CSideTask:New(taskid)
    return o
end
