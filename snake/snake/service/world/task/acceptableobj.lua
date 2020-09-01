local global = require "global"
local record = require "public.record"
local datactrl = import(lualib_path("public.datactrl"))
local taskdefines = import(service_path("task/taskdefines"))

-- 可接任务管理
CAcceptableMgr = {}
CAcceptableMgr.__index = CAcceptableMgr
inherit(CAcceptableMgr, datactrl.CDataCtrl)

local mKindLinkShow = {
    -- test = 1,
    side = 1,
    lead = 1,
}

local mKindLinkDoneRecorder = {
    -- test = "m_mDoneTests",
    side = 1,
    lead = 1,
}

local mKindAutoUpgradeAccept = {
    side = 1,
    lead = 1,
}

function CAcceptableMgr:New(pid)
    local o = super(CAcceptableMgr).New(self, {pid=pid})
    o.m_Owner = pid
    -- TODO 暂不实现，用以运营中策划替换任务用
    -- o.m_iDoneTrunkPhase = 0 -- 完成过主线的阶段记录（暂定chapter概念一致）
    -- o.m_mDoneBranchs = {} -- 完成过支线链的记录
    -- o.m_mDoneTests = {} -- 完成过测试任务链的记录（测试用）
    o.m_mDoneLinks = {} -- 完成过链
    o.m_mRecAcceptableTask = {} -- 存盘记录的可接任务 taskid:_ 可接任务
    o.m_tmp_mAllAcceptableTask = {} -- 内存临时维护的全部可接任务 taskid:_ 可接任务
    -- TODO 以后可能考虑加玩法Id或者对应的计数（也可能是玩法与前端单独对接，前端读那些数据来显示可接）
    return o
end

function CAcceptableMgr:Save()
    local mData = {}
    -- mData.done_trunk_phase = self.m_iDoneTrunkPhase
    -- mData.done_branchs = table_to_db_key(self.m_mDoneBranchs)
    -- mData.done_tests = table_to_db_key(self.m_mDoneTests)
    local mDoneLinks = {}
    for sDirName, mRecLinks in pairs(self.m_mDoneLinks) do
        mDoneLinks[sDirName] = table_to_db_key(mRecLinks)
    end
    mData.done_links = mDoneLinks
    mData.acceptable_tasks = table_to_db_key(self.m_mRecAcceptableTask)
    return mData
end

function CAcceptableMgr:Load(mData)
    -- self.m_iDoneTrunkPhase = mData.done_trunk_phase
    -- for k, v in pairs(mData.done_branchs or {}) do
    --     self.m_mDoneBranchs[tonumber(k)] = v
    -- end
    -- for k, v in pairs(mData.done_tests or {}) do
    --     self.m_mDoneTests[tonumber(k)] = v
    -- end
    self.m_mDoneLinks = {}
    for sDirName, mDB in pairs(mData.done_links or {}) do
        self.m_mDoneLinks[sDirName] = table_to_int_key(mDB)
    end
    self.m_mRecAcceptableTask = table_to_int_key(mData.acceptable_tasks or {})
end

function CAcceptableMgr:ClearAll()
    self:ClearDoneLinkRec()
    self:ClearAcceptableRec()
end

function CAcceptableMgr:ClearDoneLinkRec()
    self.m_mDoneLinks = {}
end

function CAcceptableMgr:ClearAcceptableRec()
    self.m_mRecAcceptableTask = {}
end

ST_INIT = {
    OK = 0,
    INITED = 1,
}

function CAcceptableMgr:OnLogin(bReEnter)
    -- 初始化
    if ST_INIT.INITED == self:TryInit() then
        -- nothing
    end
    self:MakeAcceptable()
    self:SendAcceptable()
    local oPlayer = global.oWorldMgr:GetOnlinePlayerByPid(self.m_Owner)
    self:AutoUpgradeAccept(oPlayer)
end

-- function CAcceptableMgr:OnLogout()
--     -- 事件解注册在宿主对象内执行，毋须登出时解注册
--     self:UnregisterTasks()
-- end

function CAcceptableMgr:TryInit()
    if self.m_bInited then
        return ST_INIT.INITED
    end
    self:Init()
    self.m_bInited = true
    return ST_INIT.OK
end

function CAcceptableMgr:Init()
    -- self:MakeAcceptable()
    self:RegisterTasks()
end

function CAcceptableMgr:GetTaskSaveData(iTaskId)
    return self.m_mRecAcceptableTask[iTaskId]
end

function CAcceptableMgr:ToBackupAbandonTaskData(oPlayer, oTask)
    local isDone = oTask:IsDone()
    if isDone then
        return
    end
    local iLinkId = oTask:GetLinkId()
    if not iLinkId then
        return
    end
    local sKindDir = oTask:GetDirName()
    if table_get_depth(self.m_mDoneLinks, {sKindDir, iLinkId}) then
        record.error("to backup task with link has done, skip. pid:%d, taskid:%d, taskkind:%s, linkid:%d", oPlayer:GetPid(), oTask:GetId(), sKindDir, iLinkId)
        return
    end
    -- 测试期，任务有问题，放弃会存起来，需要用delacceptable重新领到身上
    oPlayer.m_oTaskCtrl.m_oAcceptableMgr:SetSingleTaskAcceptable(oTask:GetId(), oTask:Save())
    -- 备份任务不要设置链（因为实质是设置头任务）
end

-- 事件taskdefines.EVENT.ADD_TASK
function CAcceptableMgr:DoOnEventAddTask(iEvent, mData)
    local oTask = mData.task
    self:UnsetSingleTaskAcceptable(oTask:GetId(), true)
end

-- 同类任务重新显示（前端做效率高很多，但是逻辑不能达到后端这样复杂）
-- 先由前端实现，此处接口屏蔽
-- 事件taskdefines.EVENT.DEL_TASK
function CAcceptableMgr:DoOnEventDelTask(iEvent, mData)
    -- local oTask = mData.task
    -- local isDone = oTask:IsDone()
    -- if isDone then
    --     self:MakeAcceptable()
    --     self:SendAcceptable()
    -- end
end
-- function CAcceptableMgr.OnEventDelTask(iEvent, mData)
--     CAcceptableMgr.DoOnEventDelTask(iEvent, mData)
-- end

-- 事件taskdefines.EVENT.UNLOCK_TAG
function CAcceptableMgr:DoOnEventUnlockTag(iEvent, mData)
    -- 有优化空间
    self:MakeAcceptable()
    self:SendAcceptable()
end

function CAcceptableMgr:UnregisterTasks()
    local oPlayer = global.oWorldMgr:GetOnlinePlayerByPid(self.m_Owner)
    oPlayer.m_oTaskCtrl:DelEvent(self, taskdefines.EVENT.UNLOCK_TAG)
    oPlayer.m_oTaskCtrl:DelEvent(self, taskdefines.EVENT.ADD_TASK)
    oPlayer.m_oTaskCtrl:DelEvent(self, taskdefines.EVENT.DEL_TASK)
end

function OnEventTaskUnlockTag(iEvent, mData)
    local pid = mData.pid
    local oPlayer = global.oWorldMgr:GetOnlinePlayerByPid(pid)
    if not oPlayer then
        return
    end
    local oAcceptableMgr = oPlayer.m_oTaskCtrl.m_oAcceptableMgr
    oAcceptableMgr:DoOnEventUnlockTag(iEvent, mData)
end

function OnEventAddTask(iEvent, mData)
    local pid = mData.pid
    local oPlayer = global.oWorldMgr:GetOnlinePlayerByPid(pid)
    if not oPlayer then
        return
    end
    local oAcceptableMgr = oPlayer.m_oTaskCtrl.m_oAcceptableMgr
    oAcceptableMgr:DoOnEventAddTask(iEvent, mData)
end

function CAcceptableMgr:RegisterTasks()
    local oPlayer = global.oWorldMgr:GetOnlinePlayerByPid(self.m_Owner)
    oPlayer.m_oTaskCtrl:AddEvent(self, taskdefines.EVENT.UNLOCK_TAG, function(iEvent, mData)
        OnEventTaskUnlockTag(iEvent, mData)
    end
    )
    oPlayer.m_oTaskCtrl:AddEvent(self, taskdefines.EVENT.ADD_TASK, function(iEvent, mData)
        OnEventAddTask(iEvent, mData)
    end
    )
    -- 暂时不做DEL_TASK处理（前端有对应逻辑处理了）
end

function CAcceptableMgr:OnTaskConfigUpdate(oPlayer)
    self:MakeAcceptable()
    self:SendAcceptable()
    self:AutoUpgradeAccept(oPlayer)
end

function CAcceptableMgr:OnUpGradeEnd(oPlayer, iFromGrade, iToGrade)
    self:MakeAcceptable()
    self:SendAcceptable()
    self:AutoUpgradeAccept(oPlayer)
end

function CAcceptableMgr:AutoUpgradeAccept(oPlayer)
    for sDir, _ in pairs(mKindAutoUpgradeAccept) do
        local mLinkInfo = global.oTaskLoader:GetLinkHeads(sDir)
        for taskid, iLinkId in pairs(mLinkInfo) do
            if self.m_tmp_mAllAcceptableTask[taskid] then
                -- local mTaskData = global.oTaskLoader:GetTaskBaseData(taskid)
                -- local mPreCondi = global.oTaskLoader:GetPreCondition(taskid)
                if global.oTaskHandler:IsTaskVisible(oPlayer, taskid) then
                    global.oTaskHandler:GiveTask(oPlayer, taskid)
                end
            end
        end
    end
end

-- 设置单个任务可接
function CAcceptableMgr:SetSingleTaskAcceptable(taskid, mSaveData)
    if not self.m_mRecAcceptableTask[taskid] then
        self:Dirty()
        self.m_mRecAcceptableTask[taskid] = mSaveData
    end
    if not self.m_tmp_mAllAcceptableTask[taskid] then
        self.m_tmp_mAllAcceptableTask[taskid] = true
        -- self:MakeAcceptable()
        self:SendAcceptable()
    end
end

function CAcceptableMgr:UnsetSingleTaskAcceptable(taskid, bSync)
    if self.m_mRecAcceptableTask[taskid] then
        self:Dirty()
        self.m_mRecAcceptableTask[taskid] = nil
    end
    if self.m_tmp_mAllAcceptableTask[taskid] then
        self.m_tmp_mAllAcceptableTask[taskid] = nil
        -- self:MakeAcceptable()
        if bSync then
            self:SendAcceptable()
        end
    end
end

-- 设置任务链可接
function CAcceptableMgr:SetTaskLinkAcceptable(sDirName, iLinkId)
    if table_get_depth(self.m_mDoneLinks, {sDirName, iLinkId}) then
        return
    end
    local mLinkInfo = global.oTaskLoader:GetLinkInfo(sDirName, iLinkId)
    if not mLinkInfo then
        return
    end
    local iTaskHead = mLinkInfo["head"]
    if not iTaskHead then
        return
    end
    self:SetSingleTaskAcceptable(iTaskHead, true)
end

function CAcceptableMgr:CanTaskAcceptable(mHasBackupAccLinks, oPlayer, iTaskid, iLinkId, sKindDir)
    if iTaskid <= 0 then
        return false
    end
    if self.m_mRecAcceptableTask[iTaskid] then
        return true
    end
    if iLinkId then
        local sKindDir = global.oTaskLoader:GetDir(iTaskid)
        -- 存在中断方式进入可接列表的同链任务
        if table_get_depth(mHasBackupAccLinks, {sKindDir, iLinkId}) then
            return false
        end
        -- 完成的link
        if sKindDir and table_get_depth(self.m_mDoneLinks, {sKindDir, iLinkId}) then
            return false
        end
    end
    -- 身上进行中任务的link(由ValidAddTask来检查)(出现在列表由前端屏蔽)
    -- 因[领取一个任务后，同kind任务不可领]的处理在每个任务完成和领取时都要检查，故先不在后端实现，由前端处理
    if not global.oTaskHandler:IsTaskVisible(oPlayer, iTaskid) then
        return false
    end
    return true
end

function CAcceptableMgr:MakeAcceptable()
    local iPid = self.m_Owner
    local oPlayer = global.oWorldMgr:GetOnlinePlayerByPid(iPid)
    if not oPlayer then
        return
    end
    self.m_tmp_mAllAcceptableTask = {}

    local mHasBackupAccLinks = {}
    for _, iTaskId in ipairs(table_key_list(self.m_mRecAcceptableTask)) do
        local mSaveData = self.m_mRecAcceptableTask[iTaskId]
        if type(mSaveData) == "table" then
            local iLinkId = table_get_depth(mSaveData, {"data", "linkid"})
            if iLinkId then
                local sKindDir = global.oTaskLoader:GetDir(iTaskId)
                if table_get_depth(self.m_mDoneLinks, {sKindDir, iLinkId}) then
                    record.error("backuped task link has done, del backup. pid:%d, taskid:%d, taskkind:%s, linkid:%d", iPid, iTaskId, sKindDir, iLinkId)
                    self.m_mRecAcceptableTask[iTaskId] = nil
                    goto continue
                else
                    table_set_depth(mHasBackupAccLinks, {sKindDir}, iLinkId, true)
                end
            end
        end
        self.m_tmp_mAllAcceptableTask[iTaskId] = true
        ::continue::
    end

    local mHasLinks = oPlayer.m_oTaskCtrl:ListLinks()

    for sKindDir, _ in pairs(mKindLinkShow) do
        local mLinkHeads = global.oTaskLoader:GetLinkHeads(sKindDir)
        -- 虽然是for循环，但是iLinkId都是不重复的
        for iHeadTaskid, iLinkId in pairs(mLinkHeads) do
            if not table_get_depth(mHasLinks, {sKindDir, iLinkId}) then
                if self:CanTaskAcceptable(mHasBackupAccLinks, oPlayer, iHeadTaskid, iLinkId, sKindDir) then
                    self.m_tmp_mAllAcceptableTask[iHeadTaskid] = true
                end
            end
        end
    end
end

function CAcceptableMgr:IsTaskAcceptable(iTaskid)
    return self.m_tmp_mAllAcceptableTask[iTaskid]
end

function CAcceptableMgr:SendAcceptable()
    local oPlayer = global.oWorldMgr:GetOnlinePlayerByPid(self.m_Owner)
    if not oPlayer then
        return
    end
    local mNet = {
        taskids = table_key_list(self.m_tmp_mAllAcceptableTask),
    }
    oPlayer:Send("GS2CAcceptableTasks", mNet)
end

function CAcceptableMgr:IsLinkDone(sDirName, iLinkId)
    return table_get_depth(self.m_mDoneLinks, {sDirName, iLinkId})
end

function CAcceptableMgr:RecLinkDone(sDirName, iLinkId)
    local bCanRecord = mKindLinkDoneRecorder[sDirName]
    if not bCanRecord then
        return
    end
    local mRecorder = table_get_set_depth(self.m_mDoneLinks, {sDirName})
    if mRecorder[iLinkId] then
        return
    end
    mRecorder[iLinkId] = true
    self:Dirty()
end

-- -- TODO 暂时无用
-- function CAcceptableMgr:RecTrunkDone(iLinkId)
--     self:Dirty()
--     self.m_iDoneTrunkPhase = iLinkId
-- end
