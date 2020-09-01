-- 每日任务
local global = require "global"
local res = require "base.res"
local record = require "public.record"
local gamedefines = import(lualib_path("public.gamedefines"))
local taskdefines = import(service_path("task/taskdefines"))
local datactrl = import(lualib_path("public.datactrl"))
local behaviorevmgr = import(service_path("player/behaviorevmgr"))
local rewardmonitor = import(service_path("rewardmonitor"))

function GetEverydaySpTask(sKey)
    return table_get_depth(res, {"daobiao", "everyday_task", "sptask", sKey})
end

function GetAllEverydayCondiData()
    return table_get_depth(res, {"daobiao", "everyday_task", "condi"})
end

function GetEverydayTaskData(iETId)
    if not iETId then
        return table_get_depth(res, {"daobiao", "everyday_task", "task"})
    else
        return table_get_depth(res, {"daobiao", "everyday_task", "task", iETId})
    end
end

---------------------
CEverydayCtrl = {}
CEverydayCtrl.__index = CEverydayCtrl
CEverydayCtrl.m_sName = "everydaytask"
inherit(CEverydayCtrl, datactrl.CDataCtrl)

function NewEverydayCtrl(pid)
    local o = CEverydayCtrl:New(pid)
    o:TryStartRewardMonitor()
    return o
end

function OnEvCallback(iEvType, mData, iPid)
    local oPlayer = global.oWorldMgr:GetOnlinePlayerByPid(iPid)
    if not oPlayer then
        return
    end
    oPlayer.m_oTaskCtrl.m_oEverydayCtrl:OnBehaviorEvTrigger(iEvType, mData)
end

function CEverydayCtrl:New(pid)
    local o = super(CEverydayCtrl).New(self)
    o.m_iPid = pid
    o.m_iMorningDayNo = 0
    o.m_mGotTasks = {}
    -- 注册的行为 {iBehav = {iETId = 1, ...}, ...}
    o.m_mRegBehaviors = {}
    -- 注册行为的任务反查 {iETId = {iBehav = 1, ...}, ...}
    o.m_mLookupRegTasks = {}
    -- 接入behaviorevmgr
    o.m_oBehaviorEvCtrl = behaviorevmgr.NewBehaviorEvCtrl(pid, OnEvCallback)
    return o
end

function CEverydayCtrl:Release()
    for iETId, oETask in pairs(self.m_mGotTasks) do
        baseobj_safe_release(oETask)
    end
    self.m_mGotTasks = nil
    if self.m_oBehaviorEvCtrl then
        self.m_oBehaviorEvCtrl:Clear()
        baseobj_safe_release(self.m_oBehaviorEvCtrl)
        self.m_oBehaviorEvCtrl = nil
    end
    if self.m_oRewardMonitor then
        baseobj_safe_release(self.m_oRewardMonitor)
    end
    super(CEverydayCtrl).Release(self)
end

function CEverydayCtrl:GetPid()
    return self.m_iPid
end

function CEverydayCtrl:Save()
    if not next(self.m_mGotTasks) then
        return
    end
    local mTaskData = {}
    for iETId, oETask in pairs(self.m_mGotTasks) do
        mTaskData[db_key(iETId)] = oETask:Save()
    end
    return {tasks = mTaskData, dayno = self.m_iMorningDayNo}
end

function CEverydayCtrl:Load(mData)
    if not mData then
        return
    end
    local iCurMorningDayNo = get_morningdayno(get_time())
    self.m_iMorningDayNo = mData.dayno
    -- 超时没有额外逻辑处理，可以直接放弃恢复
    if iCurMorningDayNo ~= mData.dayno then
        self:Dirty()
        return
    end
    -----------------------------

    for sETId, mTaskData in pairs(mData.tasks or {}) do
        local iETId = tonumber(sETId)
        if iETId then
            local oETask = CEverydayTask:New(iETId)
            oETask:Load(mTaskData)
            self.m_mGotTasks[iETId] = oETask
        end
    end
end

function CEverydayCtrl:IsDirty()
    if super(CEverydayCtrl).IsDirty(self) then
        return true
    end
    for iETId, oETask in pairs(self.m_mGotTasks) do
        if oETask:IsDirty() then
            return true
        end
    end
end

function CEverydayCtrl:UnDirty()
    super(CEverydayCtrl).UnDirty(self)
    for iETId, oETask in pairs(self.m_mGotTasks) do
        oETask:UnDirty()
    end
end

function CEverydayCtrl:TouchRegAllBehaviors()
    for iETId, oETask in pairs(self.m_mGotTasks) do
        if not oETask:IsRewarded() and not oETask:IsDone() then
            local mConfigData = GetEverydayTaskData(iETId)
            if mConfigData then
                local lBehaviors = mConfigData.condi
                for _, iBehav in ipairs(lBehaviors) do
                    table_set_depth(self.m_mRegBehaviors, {iBehav}, iETId, 1)
                    table_set_depth(self.m_mLookupRegTasks, {iETId}, iBehav, 1)
                end
            end
        end
    end
    self.m_oBehaviorEvCtrl:TouchRegBehaviorEvs(table_key_list(self.m_mRegBehaviors))
end

function CEverydayCtrl:AcceptByCondi()
    local iPid = self:GetPid()
    local oPlayer = global.oWorldMgr:GetOnlinePlayerByPid(iPid)
    if not oPlayer then
        return
    end
    local lUpdated = {}
    local iGrade = oPlayer:GetGrade()
    local mAllData = GetEverydayTaskData()
    for iETId, mData in pairs(mAllData) do
        if self.m_mGotTasks[iETId] then
            goto continue
        end
        if iGrade < mData.open_grade then
            goto continue
        end
        self:Dirty()
        local oETask = CEverydayTask:New(iETId, mData)
        self.m_mGotTasks[iETId] = oETask
        self:TryRegTaskBehaviors(iETId)
        table.insert(lUpdated, iETId)
        ::continue::
    end
    -- self:TouchRegBehaviorEvs()
    if #lUpdated then
        local lSpUpdated = self:RecheckSpTasks()
        if lSpUpdated then
            list_combine(lUpdated, lSpUpdated)
        end
        return lUpdated
    else
        return nil
    end
end

function CEverydayCtrl:RecheckSpTasks()
    -- 针对全任务完成类型改计数
    return self:RefreshCondiAllTasks()
end

function CEverydayCtrl:TryRegTaskBehaviors(iETId)
    local mConfigData = GetEverydayTaskData(iETId)
    if not mConfigData then return end
    local lBehaviors = mConfigData.condi
    for _, iBehav in ipairs(lBehaviors) do
        if not self.m_mRegBehaviors[iBehav] then
            self.m_oBehaviorEvCtrl:TryRegBehavior(iBehav)
        end
        table_set_depth(self.m_mRegBehaviors, {iBehav}, iETId, 1)
        table_set_depth(self.m_mLookupRegTasks, {iETId}, iBehav, 1)
    end
end

function CEverydayCtrl:TryUnRegTaskBehaviors(iETId)
    local oPlayer = global.oWorldMgr:GetOnlinePlayerByPid(self:GetPid())
    if not oPlayer then
        return
    end
    local mETBehaviors = self.m_mLookupRegTasks[iETId]
    if not mETBehaviors then
        return
    end
    self.m_mLookupRegTasks[iETId] = nil
    for iBehav, _ in pairs(mETBehaviors) do
        table_del_depth_casc(self.m_mRegBehaviors, {iBehav}, iETId)
        if not self.m_mRegBehaviors[iBehav] then
            self.m_oBehaviorEvCtrl:TryUnRegBehavior(iBehav)
        end
    end
end

function CEverydayCtrl:ReNew()
    self:Dirty()
    -- 全部超时
    self:TouchUnRegAllBehaviors()
    self.m_mGotTasks = {}
    -- 等级领取
    self:AcceptByCondi()
end

function CEverydayCtrl:NewDayMorning(oPlayer)
    self:TouchTimeout()
    self:TryStopRewardMonitor()
    self:GS2CAllEverydayTaskInfo()
end

function CEverydayCtrl:TouchTimeout()
    local iCurMorningDayNo = get_morningdayno(get_time())
    if self.m_iMorningDayNo ~= iCurMorningDayNo then
        local oPlayer = global.oWorldMgr:GetOnlinePlayerByPid(self:GetPid())
        local mLogData
        if oPlayer then
            mLogData = oPlayer:LogData()
            mLogData.old_dayno = self.m_iMorningDayNo or 0
            mLogData.new_dayno = iCurMorningDayNo or 0
        end
        self.m_iMorningDayNo = iCurMorningDayNo
        self:ReNew()
        if mLogData then
            mLogData.taskids = table_key_list(self.m_mGotTasks)
            record.user("task", "new_everyday_task", mLogData)
        end
    end
end

function CEverydayCtrl:TouchUnRegAllBehaviors()
    if self.m_oBehaviorEvCtrl then
        self.m_oBehaviorEvCtrl:Clear()
    end
    self.m_mRegBehaviors = {}
    self.m_mLookupRegTasks = {}
end

function CEverydayCtrl:OnLogin(bReEnter)
    if not bReEnter then
        self:TouchTimeout()
        self:TouchRegAllBehaviors()
    end
    self:GS2CAllEverydayTaskInfo()
end

function CEverydayCtrl:OnLogout()
    self:TouchUnRegAllBehaviors()
end

function CEverydayCtrl:OnUpGradeEnd(oPlayer, iToGrade, iFromGrade)
    -- 领取新的任务，刷新现有任务的计数
    local lUpdated = self:AcceptByCondi()
    if lUpdated then
        self:GS2CUpdateEverydayTasks(lUpdated)
    end
end

function CEverydayCtrl:OnBehaviorEvTrigger(iEvType, mData)
    if not next(self.m_mRegBehaviors) then
        return
    end
    local mTriggerTimes = self.m_oBehaviorEvCtrl:TriggerBehaviorEvent(iEvType, mData)
    local mHitTasks = {}
    for iBehav, iCnt in pairs(mTriggerTimes) do
        local mETasks = self.m_mRegBehaviors[iBehav]
        for iETId, _ in pairs(mETasks) do
            mHitTasks[iETId] = (mHitTasks[iETId] or 0) + iCnt
        end
    end
    local lUpdateETs = {}
    for iETId, iTimes in pairs(mHitTasks) do
        local oETask = self.m_mGotTasks[iETId]
        if oETask and not oETask:IsRewarded() and not oETask:IsDone() then
            local bChanged = oETask:CountOn(iTimes)
            if bChanged then
                table.insert(lUpdateETs, iETId)
                if oETask:IsDone() then
                    self:TryUnRegTaskBehaviors(iETId)
                end
            end
        end
    end
    if #lUpdateETs == 0 then
        return
    end

    -- 特殊任务刷数据
    local lSpUpdated = self:RecheckSpTasks()
    if lSpUpdated then
        list_combine(lUpdateETs, lSpUpdated)
    end
    self:GS2CUpdateEverydayTasks(lUpdateETs)
end

function CEverydayCtrl:GS2CAllEverydayTaskInfo()
    local iPid = self:GetPid()
    local oPlayer = global.oWorldMgr:GetOnlinePlayerByPid(iPid)
    if not oPlayer then
        return
    end
    local mNetTasks = {}
    for iETId, oETask in pairs(self.m_mGotTasks) do
        table.insert(mNetTasks, oETask:PackNetInfo())
    end
    oPlayer:Send("GS2CAllEverydayTaskInfo", {all = mNetTasks})
end

function CEverydayCtrl:GS2CUpdateEverydayTasks(lUpdateETs)
    if #lUpdateETs <= 0 then
        return
    end
    local iPid = self:GetPid()
    local oPlayer = global.oWorldMgr:GetOnlinePlayerByPid(iPid)
    if not oPlayer then
        return
    end
    local mNetTasks = {}
    for _, iETId in ipairs(lUpdateETs) do
        local oETask = self.m_mGotTasks[iETId]
        if oETask then
            table.insert(mNetTasks, oETask:PackNetInfo())
        end
    end
    oPlayer:Send("GS2CUpdateEverydayTasks", {updates = mNetTasks})
end

function CEverydayCtrl:RefreshCondiAllTasks()
    local iCondiAllTasksETId = GetEverydaySpTask("condi_all_tasks")
    local lUpdateETIds = {}
    if iCondiAllTasksETId then
        local oSpETask = self.m_mGotTasks[iCondiAllTasksETId]
        if oSpETask and not oSpETask:IsRewarded() then
            local iMaxCnt = 0
            local iDoneCnt = 0
            for iETId, oETask in pairs(self.m_mGotTasks) do
                if iETId ~= iCondiAllTasksETId then
                    iMaxCnt = iMaxCnt + 1
                    if oETask:IsDone() then
                        iDoneCnt = iDoneCnt + 1
                    end
                end
            end
            if oSpETask:SetCount(iDoneCnt, iMaxCnt) then
                table.insert(lUpdateETIds, iCondiAllTasksETId)
            end
        end
    end
    if #lUpdateETIds then
        return lUpdateETIds
    end
end

function CEverydayCtrl:GetTask(iETId)
    return self.m_mGotTasks[iETId]
end

function CEverydayCtrl:RewardTask(oPlayer, iETId)
    local oETask = self.m_mGotTasks[iETId]
    if not oETask then
        oPlayer:NotifyMessage("任务已超时")
        return
    end
    if oETask then
        local iLastReqTime = oETask:GetReqTime()
        if iLastReqTime and get_time() - iLastReqTime <= 1 then
            return
        end
        oETask:SetReqTime()
        if oETask:IsRewarded() then
            oPlayer:NotifyMessage("已领取该任务奖励")
            return
        elseif not oETask:IsDone() then
            oPlayer:NotifyMessage("请先完成该任务")
            return
        else
            oETask:Reward(oPlayer)
            oPlayer:Send("GS2CUpdateEverydayTasks", {updates = {oETask:PackNetInfo(),}})
        end
    end
end

function CEverydayCtrl:CheckRewardMonitor(iPid, iId, iCnt, mArgs)
    if self.m_oRewardMonitor then
        if not self.m_oRewardMonitor:CheckRewardGroup(iPid, "everyday", iId, iCnt, mArgs) then
            return false
        end
    end
    return true
end

function CEverydayCtrl:TryStartRewardMonitor()
    if not self.m_oRewardMonitor then
        local lUrl = {"reward", self.m_sName}
        local o = rewardmonitor.NewMonitor(self.m_sName, lUrl)
        self.m_oRewardMonitor = o
    end
end

function CEverydayCtrl:TryStopRewardMonitor()
    if self.m_oRewardMonitor then
        self.m_oRewardMonitor:ClearRecordInfo()
    end
end

---------------------
CEverydayTask = {}
CEverydayTask.__index = CEverydayTask
CEverydayTask.m_sName = "everydaytask"
inherit(CEverydayTask, datactrl.CDataCtrl)

function CEverydayTask:New(iETId, mConfigData)
    local o = super(CEverydayTask).New(self)
    o.m_ID = iETId
    o.m_iCurCnt = 0
    o.m_iMaxCnt = 0
    if mConfigData then
        o.m_iMaxCnt = mConfigData.cnt
    end
    return o
end

function CEverydayTask:Save()
    return {
        max_cnt = self.m_iMaxCnt,
        cur_cnt = self.m_iCurCnt,
        rewarded = self.m_bReward or nil,
    }
end

function CEverydayTask:Load(mData)
    self.m_iMaxCnt = mData.max_cnt or 0
    self.m_iCurCnt = mData.cur_cnt or 0
    self.m_bReward = mData.rewarded
end

function CEverydayTask:PackNetInfo()
    return {
        taskid = self.m_ID,
        max_cnt = self.m_iMaxCnt or 0,
        cur_cnt = self.m_iCurCnt or 0,
        rewarded = self.m_bReward and 1 or 0,
    }
end

function CEverydayTask:IsRewarded()
    return self.m_bReward
end

function CEverydayTask:Reward(oPlayer)
    if self.m_bReward then
        return
    end
    local mConfigData = GetEverydayTaskData(self.m_ID)
    assert(mConfigData, string.format("everydaytask no configdata, pid:%d, etid:%s", oPlayer:GetPid(), self.m_ID))
    local iRewardId = mConfigData.rewardid
    assert(iRewardId, string.format("everydaytask no rewardid, pid:%d, etid:%s", oPlayer:GetPid(), self.m_ID))
    self:Dirty()
    self.m_bReward = true
    if not oPlayer.m_oTaskCtrl.m_oEverydayCtrl:CheckRewardMonitor(oPlayer:GetPid(), self.m_ID, 1, mArgs) then
        return
    end
    global.oRewardMgr:RewardByGroup(oPlayer, "everydaytask", iRewardId, mArgs)
    -- TODO log rewardmgr的log可能不便于查询
end

function CEverydayTask:GetReqTime()
    return self.m_iReqTime
end

function CEverydayTask:SetReqTime()
    self.m_iReqTime = get_time()
end

-- @return: bChanged
function CEverydayTask:CountOn(iTimes)
    if self:IsDone() then
        return false
    end
    self:Dirty()
    self.m_iCurCnt = self.m_iCurCnt + iTimes
    if self.m_iCurCnt > self.m_iMaxCnt then
        self.m_iCurCnt = self.m_iMaxCnt
    end
    return true
end

function CEverydayTask:IsDone()
    return (self.m_iCurCnt or 0) >= (self.m_iMaxCnt or 0)
end

function CEverydayTask:SetCount(iDoneCnt, iMaxCnt)
    if self.m_iCurCnt == iDoneCnt and self.m_iMaxCnt == iMaxCnt then
        return
    end
    self:Dirty()
    self.m_iCurCnt = iDoneCnt
    self.m_iMaxCnt = iMaxCnt
    return true
end

function CEverydayTask:Max()
    return self.m_iMaxCnt
end

-------------------
-- CEverydayAllDoneTask = {}
-- CEverydayAllDoneTask.__index = CEverydayAllDoneTask
-- CEverydayAllDoneTask.m_sName = "everydaytask"
-- inherit(CEverydayAllDoneTask, CEverydayTask)

-- function CEverydayAllDoneTask:New(iETId)
--     local o = super(CEverydayAllDoneTask).New(self)
--     return o
-- end
