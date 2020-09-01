--import module

local global = require "global"
local res = require "base.res"
local taskobj = import(service_path("task/taskobj"))
local gamedefines = import(lualib_path("public.gamedefines"))
local analy = import(lualib_path("public.dataanaly"))

CTask = {}
CTask.__index = CTask
CTask.m_sName = "story"
CTask.m_sTempName = "主线任务"
CTask.m_iSysType = gamedefines.GAME_SYS_TYPE.SYS_TYPE_STORY
inherit(CTask,taskobj.CTask)

function CTask:New(taskid)
    local o = super(CTask).New(self,taskid)
    local iLinkId = global.oTaskLoader:GetLinkHeads(self.m_sName)[taskid]
    if iLinkId then
        o:SetLinkId(iLinkId)
    end
    return o
end

-- 主线不可放弃
function CTask:Abandon()
    return
end

function CTask:OnAddDone(oPlayer)
    super(CTask).OnAddDone(self, oPlayer)
    self:PromoteChapterSection(oPlayer)
    self:ReCheckVusual(oPlayer)
    self:ReCheckGhostEye(oPlayer)
end

function CTask:GainStoryChapterPiece(pid, iChapter, iPiece)
    local oPlayer = global.oWorldMgr:GetOnlinePlayerByPid(pid)
    if not oPlayer then
        return
    end
    oPlayer.m_oTaskCtrl:GainStoryChapterPiece(iChapter, iPiece)
end

function CTask:OtherScript(pid,npcobj,s,mArgs)
    -- if string.sub(s,1,3) == "CHP" then
    --     local iChapter, iPiece = table.unpack(split_string(string.sub(s,4,-1), ":", tonumber))
    --     self:GainStoryChapterPiece(pid, iChapter, iPiece)
    --     return true
    -- end
end

function CTask:OnLogin(oPlayer, bReEnter)
    local bRemain = super(CTask).OnLogin(self, oPlayer, bReEnter)
    if not bRemain then
        return false
    end

    if not bReEnter then
        self:PromoteChapterSection(oPlayer)
        self:ReCheckVusual(oPlayer, true)
        self:ReCheckGhostEye(oPlayer)
    end
    return true
end

function CTask:ReCheckGhostEye(oPlayer)
    local mTaskData = global.oTaskLoader:GetTaskBaseData(self:GetId())
    local iGhostEyeOpen = mTaskData.ghost_eye or 0
    oPlayer.m_oActiveCtrl.m_oVisualMgr:SetGhostEye(oPlayer, iGhostEyeOpen)
end

function CTask:ReCheckVusual(oPlayer, bOnLogin)
    local mTaskData = global.oTaskLoader:GetTaskBaseData(self:GetId())
    local iVisualConfigId = mTaskData.visual_config or 0
    oPlayer.m_oTaskCtrl:SetCurStoryVisualConfig(iVisualConfigId, bOnLogin, "task:" .. self:GetId())
end

function CTask:PromoteChapterSection(oPlayer)
    local mTaskData = global.oTaskLoader:GetTaskBaseData(self:GetId())
    local mChapterSection = mTaskData.chapter_progress or {}
    local iChapter, iSection = (mChapterSection.chapter or 0), (mChapterSection.section or 0)
    oPlayer.m_oTaskCtrl:TryPromoteStoryChapterSection(iChapter, iSection)
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

function CTask:GetXiayiDifficultyLimit()
    return res["daobiao"]["moneypoint"]["other_limit"]["story_difficulty"]['value']
end

function CTask:DealBeforeOnWarWin(oWar, pid, npcobj, mWarCbArgs)
    local oLeader = global.oWorldMgr:GetOnlinePlayerByPid(pid)
    if oLeader and self:TaskType() == gamedefines.TASK_TYPE.TASK_NPC_FIGHT then
        local mWarResult = {}
        mWarResult.lLastFighterPid = self:GetFighterList(oLeader, mWarCbArgs)
        mWarResult.iLastLeaderPid = pid
        mWarResult.iLastWarIdx = oWar.m_iIdx
        self.m_mLastWarResult = mWarResult
    end
end

function CTask:MissionDone(npcobj, mAgrs)
    if self.m_mLastWarResult and self:TaskType() == gamedefines.TASK_TYPE.TASK_NPC_FIGHT then
        local mWarResult = self.m_mLastWarResult
        self:TryRewardFighterXiayiPoint(mWarResult.iLastLeaderPid, mWarResult.lLastFighterPid, {iWarIdx = mWarResult.iLastWarIdx})
        self.m_mLastWarResult = nil
    end
    super(CTask).MissionDone(self, npcobj, mAgrs)
end

function CTask:TryRewardFighterXiayiPoint(iLeaderPid,lFighterPid,mAgrs)
    local mConfig = self:GetTollGateData(mAgrs.iWarIdx)
    local iDifficulty = mConfig["difficulty"][1]
    if not iDifficulty then return end
    if iDifficulty < self:GetXiayiDifficultyLimit() then return end

    local  function FilterFighter(iLeaderPid, lFighterPid)
        local lRetPid = {}
        for _,pid in pairs(lFighterPid) do
            if pid ~= iLeaderPid then
                table.insert(lRetPid, pid)
            end
        end
        return lRetPid
    end
    local lRewardPid = self:RewardFighterFilter(iLeaderPid, lFighterPid, FilterFighter)
    local oLeader = global.oWorldMgr:GetOnlinePlayerByPid(iLeaderPid)
    if not oLeader then return end
    local iLeaderOrgID = oLeader:GetOrgID()
    for _, pid in pairs(lRewardPid) do
        local oFighter = global.oWorldMgr:GetOnlinePlayerByPid(pid)
        if oFighter then
            if oFighter:GetOrgID() == iLeaderOrgID and oFighter:GetOrgID() ~= 0 then
                self:RewardXiayiPoint(oFighter, "story_fight2","主线剧情同帮派")
            else
                self:RewardXiayiPoint(oFighter, "story_fight", "主线剧情")
            end
        end
    end
end

function CTask:RewardExp(oPlayer, iExp)
    oPlayer:RewardExp(iExp, self.m_sName, {bEffect = false, bIgnoreFortune = true})
end

function CTask:SummonExpEffect()
    return false
end

function CTask:PartnerExpEffect()
    return false
end

function CTask:AfterMissionDone(iPid)
    local iTaskID = self:GetId()
    local oPlayer = global.oWorldMgr:GetOnlinePlayerByPid(iPid)
    if oPlayer then
        local mRes = res["daobiao"]["huodong"]["grow"]["taskend"]
        if mRes[iTaskID] then
            oPlayer:MarkGrow(mRes[iTaskID]["growid"])
        end
    end
end

function CTask:LogAnalyInfo(oPlayer)
    if not oPlayer then return end

    local mAnalyLog = oPlayer:BaseAnalyInfo()
    mAnalyLog["main_step_type"] = self:TaskType()
    mAnalyLog["operation"] = 2
    mAnalyLog["main_step_id"] = self:GetId()
    local mReward = oPlayer:GetTemp("reward_content", {})
    mAnalyLog["reward_detail"] = analy.table_concat(mReward)
    analy.log_data("MainStep", mAnalyLog)

    local mAnalyLog = oPlayer:BaseAnalyInfo()
    mAnalyLog["step_id"] = self:GetId()
    mAnalyLog["operation"] = 2
    analy.log_data("NewplayerGuide", mAnalyLog)
end

-- @Override
function CTask:IsWarTeamMembersShareDone(oWar, iWarCallerPid, npcobj, mWarCbArgs)
    return true
end

function NewTask(taskid)
    local o = CTask:New(taskid)
    return o
end

