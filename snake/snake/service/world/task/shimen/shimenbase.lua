local global = require "global"
local record = require "public.record"
local res = require "base.res"

local taskobj = import(service_path("task/taskobj"))
local taskdefines = import(service_path("task/taskdefines"))
local gamedefines = import(lualib_path("public.gamedefines"))
local analy = import(lualib_path("public.dataanaly"))

CTask = {}
CTask.__index = CTask
CTask.m_sName = "shimen"
CTask.m_sTempName = "门派修行"
CTask.m_sStatisticsName = "task_shimen"
CTask.m_iSysType = gamedefines.GAME_SYS_TYPE.SYS_TYPE_SHIMEN
inherit(CTask,taskobj.CTask)

function CTask:New(taskid)
    local o = super(CTask).New(self,taskid)
    return o
end

function CTask:GetNextRing(iRing)
    local iNewRing = iRing + 1
    local iRoundRings = taskdefines.SHIMEN_INFO.RINGS_PER_ROUND
    if iNewRing > iRoundRings then
        iNewRing = iNewRing % iRoundRings
    end
    return iNewRing
end

-- PS. 只能使用Remove，因为需要先删任务并在Reward升级触发TouchShimen前按正确Ring发放下一步
function CTask:Remove()
    super(CTask).Remove(self)

    if not self:IsDone() then
        return
    end
    local pid = self.m_Owner
    local oPlayer = global.oWorldMgr:GetOnlinePlayerByPid(pid)
    if not oPlayer then
        return
    end
    if oPlayer.m_oTodayMorning:Query("perfect_shimen") then
        return
    end

    local iRing = self:GetCurRing()
    -- 完成环数+1
    local iDoneCnt = 1 + global.oShimenMgr:GetShimenTodayDoneRing(oPlayer)

    -- 设置师门今日完成数
    global.oShimenMgr:RecordShimenTodayDoneRing(oPlayer, iDoneCnt)
    -- 师门本周完成记次
    global.oShimenMgr:RecordShimenWeekDoneInc(oPlayer, self)

    if iDoneCnt == 10 then
        self:Reward(pid, taskdefines.SHIMEN_INFO.DAILY_REWARD_SP_RING_TBL_1, {limit_type = "extra"})
        oPlayer:MarkGrow(7)
    elseif iDoneCnt == 20 then
        self:Reward(pid, taskdefines.SHIMEN_INFO.DAILY_REWARD_SP_RING_TBL_2, {limit_type = "extra"})
    end

    -- 记录统计次数
    safe_call(self.RecordPlayerCnt, self, {[pid]=true})

    local mLogData = oPlayer:LogData()
    mLogData.taskid = self:GetId()
    mLogData.ring = iRing
    mLogData.done_cnt_daily = iDoneCnt
    mLogData.done_cnt_weekly = oPlayer.m_oWeekMorning:Query("shimen_done", 0)
    record.user("task", "shimen_done", mLogData)

    local iRingMax = taskdefines.SHIMEN_INFO.LIMIT_RINGS
    if iDoneCnt <= iRingMax then
        if iDoneCnt == iRingMax then
            global.oNotifyMgr:Notify(pid, "恭喜您已经完成师傅今天布置的作业")
        else
            oPlayer.m_oTaskCtrl:AddShimenTask()
        end
    end
    global.oShimenMgr:SyncInfo(oPlayer)
    oPlayer.m_oTaskCtrl:FireShimenDone(iRing, iDoneCnt)
end

function CTask:Setup()
    self:SetCurRing()
    super(CTask).Setup(self)
end

function CTask:SetCurRing(iRing)
    local oPlayer = global.oWorldMgr:GetOnlinePlayerByPid(self:GetOwner())
    local iDoneRing = global.oShimenMgr:GetShimenTodayDoneRing(oPlayer)
    local iRing = iDoneRing + 1
    self:SetData("Ring", iRing)
end

function CTask:GetCurRing()
    return self:GetData("Ring", 1)
end

function CTask:TransStringFuncRing(pid, npcobj)
    return self:GetCurRing()
end

function CTask:TransFuncTable()
    local mTable = super(CTask).TransFuncTable(self)
    mTable["ring"] = "TransStringFuncRing" -- 可以直接写掉这份数据，反正不会删掉原本应该的方法
    return mTable
end

function CTask:TransCountingStr()
    local oPlayer = global.oWorldMgr:GetOnlinePlayerByPid(self:GetOwner())
    assert(oPlayer, "shimen task offline to get doneRing")
    return string.format("(%d/%d)", self:GetCurRing(), taskdefines.SHIMEN_INFO.LIMIT_RINGS)
end

function CTask:Name()
    -- local sRing = self:TransStringFuncRing() .. "环"
    return super(CTask).Name(self) .. self:TransCountingStr()
end

function CTask:GetRewardEnv(oAwardee)
    local mEnv = super(CTask).GetRewardEnv(self, oAwardee)
    mEnv.ring = self:GetCurRing()
    return mEnv
end

function CTask:Reward(pid, sIdx, mArgs)
    local oPlayer = global.oWorldMgr:GetOnlinePlayerByPid(pid)
    if not oPlayer then
        return
    end
    local oRewardMonitor = global.oTaskMgr:GetTaskRewardMonitor()
    if oRewardMonitor then
        if not mArgs then
            mArgs = {}
        end
        local sLimitType = mArgs.limit_type or "total"
        if not oRewardMonitor:CheckRewardGroup(pid, self.m_sName, sLimitType, 1, mArgs) then
            return
        end
    end
    return super(CTask).Reward(self, pid, sIdx, mArgs)
end

function CTask:Load(mData)
    super(CTask).Load(self, mData)
end

-- @Override
function CTask:FindMirrorMonster(mMonsterData, npcobj)
    local oPlayer = global.oWorldMgr:GetOnlinePlayerByPid(self:GetOwner())
    if oPlayer then
        return global.oShimenMgr:GetShimenOnlineFightMirrorPlayer(oPlayer)
    end
    return nil
end

-- @Override
function CTask:PackMirrorExtInfo(oMirror)
    return {
        school = oMirror:GetSchool(),
    }
end

-- @Override
function CTask:GetMirrorMonsterData(mMonsterData, npcobj)
    return npcobj:GetMirrorInfo()
end

-- @Override
function CTask:GetMirrorSummonMonsterData(mMonsterData, npcobj)
    local mMirrorInfo = npcobj:GetMirrorInfo()
    if mMirrorInfo then
        return mMirrorInfo.summ
    end
    return nil
end

-- @Override
function CTask:SetMirrorMonsterAttr(mAttrData, oWar, mMonsterData, mMirror, npcobj, bSummon)
    -- 填充镜像战斗数据
    if mMirror then
        mAttrData.grade = mMirror.grade
        mAttrData.name = mMirror.name
        mAttrData.model_info = mMirror.model_info
        local iSchool
        if mMirror.ext then
            iSchool = mMirror.ext.school
        end
        -- 暂不支持m_mTestWarAttr
        self:SetNormalMonsterAttr(mAttrData, oWar, mMonsterData, {school = iSchool})
    elseif not bSummon then
        -- no mirror
        if npcobj then
            mAttrData.name = npcobj:Name()
            mAttrData.model_info = npcobj:ModelInfo()
        else
            mAttrData.name = "默认镜像"
            mAttrData.model_info = self:MakeMonsterModelByConfig(mMonsterData)
        end
        self:SetNormalMonsterGrade(mAttrData, oWar, mMonsterData)
        self:SetNormalMonsterAttr(mAttrData, oWar, mMonsterData)
    else
        assert(false, "mirror_summon null, cannot create")
    end
end

-- @Override
function CTask:GetMonsterDataActiveSkills(mMonsterData, mExtArgs)
    local iSchool = mExtArgs.school
    if iSchool then
        local mActiveSkills = table_get_depth(res, {"daobiao", "fight", "shimen", "mirror_school", iSchool, "activeSkills"})
        if mActiveSkills then
            return mActiveSkills
        end
    end
    return super(CTask).GetMonsterDataActiveSkills(self, mMonsterData, mExtArgs)
end

-- @Override
function CTask:ParseWarriorData(oWar, npcobj, mMonsterData, mCampInfo)
    local mRealMonsterData = {}
    local lRealMonsterPos = {}
    local lMonsterPos = mCampInfo.monster_pos
    local iMPosIdxStart, iMPosIdxEnd = 0, 0
    for idx, mData in pairs(mMonsterData) do
        local iMonsterIdx = mData.monsterid
        local iCnt = mData.count
        iMPosIdxStart = iMPosIdxEnd + 1
        iMPosIdxEnd = iMPosIdxStart - 1 + iCnt
        local mMonsterData = self:GetMonsterData(iMonsterIdx)
        if mMonsterData.name == "$mirror_summ" then
            if not self:GetMirrorSummonMonsterData(mData, npcobj) then
                goto continue
            end
        end
        mRealMonsterData[idx] = mData
        if lMonsterPos and #lMonsterPos > 0 then
            for i = iMPosIdxStart, iMPosIdxEnd do
                table.insert(lRealMonsterPos, lMonsterPos[i])
            end
        end
        ::continue::
    end
    mCampInfo.monster_pos = lRealMonsterPos
    return mRealMonsterData, mCampInfo
end

-- 数据中心
function CTask:LogAnalyInfo(oPlayer)
    if not oPlayer then return end

    local mAnalyLog = oPlayer:BaseAnalyInfo()
    mAnalyLog["category"] = self:TaskType()
    mAnalyLog["turn_times"] = self:GetCurRing()
    mAnalyLog["win_mark"] = true
    local mReward = oPlayer:GetTemp("reward_content", {})
    mAnalyLog["reward_detail"] = analy.table_concat(mReward)
    local mConsume = oPlayer:GetTemp("consume_content", {})
    mAnalyLog["consume_detail"] = analy.table_concat(mConsume)
    analy.log_data("ProfessionTask", mAnalyLog)
end

---------------------------------------
CCaptureTask = {}
CCaptureTask.__index = CCaptureTask
inherit(CCaptureTask, CTask)

ITEM_CAPTURE = 10039

function CCaptureTask:OnAddDone(oPlayer)
    super(CTask).OnAddDone(self, oPlayer)
    if oPlayer.m_oItemCtrl:GetItemAmount(ITEM_CAPTURE, true) > 0 then
        return
    end
    local itemobj = global.oItemLoader:Create(ITEM_CAPTURE)
    itemobj:SetAmount(1)
    oPlayer:RewardItem(itemobj, "shimen_capture")
end

function CCaptureTask:OnWarFail(oWar, pid, npcobj, mWarCbArgs)
    if not mWarCbArgs then
        mWarCbArgs = {}
    end
    mWarCbArgs.silent = true
    super(CCaptureTask).OnWarFail(self, oWar, pid, npcobj, mWarCbArgs)
    if mWarCbArgs.win then
        global.oNotifyMgr:Notify(pid, "三十六计走为上策，俺逃耶")
        if npcobj then
            -- 更新npc位置
            if self:IsNpcTaskClientObj(npcobj) then
                self:ReRandClientNpcPos(npcobj)
            end
        end
    end
end

function CCaptureTask:OnWarWin(oWar, pid, npcobj, mWarCbArgs)
    -- 收伏任务普通获胜按失败结算
    if not self.m_tmp_Captured then
        if not mWarCbArgs then
            mWarCbArgs = {}
        end
        mWarCbArgs.win = true
        self:OnWarFail(oWar, pid, npcobj, mWarCbArgs)
        return
    end
    super(CCaptureTask).OnWarWin(self, oWar, pid, npcobj, mWarCbArgs)
end

function CCaptureTask:OnMonsterCreate(oWar, oMonster, mData, npcobj)
    if mData.name == "$npc" then
        -- 是否需要判断oMonster:IsBoss()
        if not self.m_tmp_mToCaptureTypes then
            self.m_tmp_mToCaptureTypes = {}
        end
        self.m_tmp_mToCaptureTypes[oMonster:Type()] = 1
    end
end

function CCaptureTask:CreateWar(pid, npcobj, iFight)
    self.m_tmp_mToCaptureTypes = {}
    super(CCaptureTask).CreateWar(self, pid, npcobj, iFight)
end

function CCaptureTask:OnWarCapture(pid, mData)
    local bSucc = mData.succ
    local iWarId = mData.warid
    local iTargetType = mData.target_type
    local oWar = global.oWarMgr:GetWar(iWarId)
    -- 抓捕结果
    if bSucc then
        if self.m_tmp_mToCaptureTypes[iTargetType] then
            -- 结束战斗
            self.m_tmp_Captured = true
            oWar:ForceRemoveWar(1)
        end
    end
end

function CCaptureTask:DefineOtherCallbacks(oWar, pid, npcobj)
    local taskid = self:GetId()
    return {
        ["OnWarCapture"] = function(mData)
            local oPlayer = global.oWorldMgr:GetOnlinePlayerByPid(pid)
            if not oPlayer then
                return
            end
            local oTask = oPlayer.m_oTaskCtrl:GetTask(taskid)
            if not oTask then
                return
            end
            oTask:OnWarCapture(pid, mData)
        end,
    }
end

----------------------------------------
function NewTask(taskid)
    local iType = global.oTaskLoader:GetTaskBaseData(taskid)["tasktype"]
    if iType == gamedefines.TASK_TYPE.TASK_CAPTURE then
        return CCaptureTask:New(taskid)
    end
    local o = CTask:New(taskid)
    return o
end
