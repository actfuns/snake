local skynet = require "skynet"
local global = require "global"
local extend = require "base.extend"
local record = require "public.record"
local res = require "base.res"

local datactrl = import(lualib_path("public.datactrl"))
local tasknet = import(service_path("netcmd/task"))
local taskdefines = import(service_path("task/taskdefines"))
local acceptableobj = import(service_path("task/acceptableobj"))
local gamedefines = import(lualib_path("public.gamedefines"))
local taskeveryday = import(service_path("task/everyday"))
local taskanleictrl = import(service_path("task/anleictrl"))
local taskxuanshangctrl = import(service_path("task/xuanshangctrl"))
local analy = import(lualib_path("public.dataanaly"))

local max = math.max
local min = math.min

function GetTaskExtData()
    local mData = res["daobiao"]["task_ext"] or {}
    return mData
end

CTaskDataMgr = {}
CTaskDataMgr.__index = CTaskDataMgr
inherit(CTaskDataMgr, datactrl.CDataCtrl)

function CTaskDataMgr:New(pid)
    local o = super(CTaskDataMgr).New(self, {pid = pid})
    return o
end


CTaskCtrl = {}
CTaskCtrl.__index = CTaskCtrl
inherit(CTaskCtrl, datactrl.CDataCtrl)

function CTaskCtrl:New(pid)
    local o = super(CTaskCtrl).New(self, {pid = pid})
    o.m_Owner = pid
    o.m_List = {} -- 身上的任务
    o.m_oAcceptableMgr = acceptableobj.CAcceptableMgr:New(pid)
    o.m_oEverydayCtrl = taskeveryday.NewEverydayCtrl(pid)
    o.m_oAnLeiCtrl = taskanleictrl.NewAnleiCtrl(pid)
    o.m_oXuanShangCtrl = taskxuanshangctrl.NewXuanShangCtrl(pid)
    o.m_mTagUnlocks = {}
    -- o.m_mStoryChapterPieces = {}
    o.m_mStoryChapterSection = {} -- 当前章节
    o.m_mRewardedChapter = {}
    o.m_tmp_iStoryVisualConfig = 0 -- 视觉id设置(登录时一定要检查，故做临时变量)
    return o
end

function CTaskCtrl:GetOwner()
    return self.m_Owner
end

function CTaskCtrl:Release()
    for _,oTask in pairs(self.m_List) do
        baseobj_safe_release(oTask)
    end
    self.m_List = nil
    baseobj_safe_release(self.m_oAcceptableMgr)
    self.m_oAcceptableMgr = nil
    baseobj_safe_release(self.m_oEverydayCtrl)
    self.m_oEverydayCtrl = nil
    baseobj_delay_release(self.m_oAnLeiCtrl)
    self.m_oAnLeiCtrl = nil
    baseobj_delay_release(self.m_oXuanShangCtrl)
    self.m_oXuanShangCtrl = nil
    super(CTaskCtrl).Release(self)
end

function CTaskCtrl:Save()
    local mData = {}
    mData["Data"] = self.m_mData
    -- mData["cur_chapter"] = self.m_iCurStoryChapter
    -- mData["chapter_pieces"] = table_to_db_key(self.m_mStoryChapterPieces)
    mData["chapter_section"] = self.m_mStoryChapterSection
    mData["rewarded_chapter"] = table_to_db_key(self.m_mRewardedChapter or {})
    -- mData["story_visual"] = self.m_tmp_iStoryVisualConfig

    local mTaskData = {}
    for taskid,oTask in pairs(self.m_List) do
        mTaskData[db_key(taskid)] = oTask:Save()
    end
    mData["TaskData"] = mTaskData

    mData.tag_unlocks = table_to_db_key(self.m_mTagUnlocks or {})

    mData.acceptable = self.m_oAcceptableMgr:Save()
    mData.everyday = self.m_oEverydayCtrl:Save()
    mData.xuanshang = self.m_oXuanShangCtrl:Save()

    return mData
end

function CTaskCtrl:Load(mData)
    mData = mData or {}
    self.m_mData = mData["Data"] or {}
    -- self.m_iCurStoryChapter = mData["cur_chapter"] or 0
    -- self.m_mStoryChapterPieces = table_to_int_key(mData["chapter_pieces"] or {})
    self.m_mStoryChapterSection = mData["chapter_section"] or {}
    self.m_mRewardedChapter = table_to_int_key(mData["rewarded_chapter"] or {})
    -- self.m_tmp_iStoryVisualConfig = mData["story_visual"]

    local mTaskData = mData["TaskData"] or {}
    for taskid,mArgs in pairs(mTaskData) do
        taskid = tonumber(taskid)
        local oTask = global.oTaskLoader:LoadTask(taskid,mArgs)
        oTask:SetOwner(self.m_Owner)
        self.m_List[taskid] = oTask
    end

    self.m_mTagUnlocks = table_to_int_key(mData.tag_unlocks or {})

    self.m_oAcceptableMgr:Load(mData.acceptable or {})
    self.m_oEverydayCtrl:Load(mData.everyday)
    self.m_oXuanShangCtrl:Load(mData.xuanshang)
end

-- 身上有某分类的任务
function CTaskCtrl:GotTaskKind(iKind)
    for _,oTask in pairs(self.m_List) do
        if oTask:Type() == iKind then
            return oTask
        end
    end
    return false
end

-- 身上有某链任务
function CTaskCtrl:GotTaskLink(sKindDir, iLinkId)
    return table_get_depth(self:ListLinks(), {sKindDir, iLinkId})
end

function CTaskCtrl:ValidAddTask(oTask)
    local taskid = oTask:GetId()
    if self.m_List[taskid] then
        return false, taskdefines.TASK_ERROR.HAS_TASK_LIMIT
    end
    local iKind = oTask:Type()
    if global.oTaskLoader:CanKindMultiLinks(iKind) then
        local iLinkId = oTask:GetLinkId()
        if iLinkId then
            local sKindDir = oTask:GetDirName()
            if self:GotTaskLink(sKindDir, iLinkId) then
                return false, taskdefines.TASK_ERROR.HAS_TASK_LIMIT
            end
        end
    else
        if self:GotTaskKind(iKind) then
            return false, taskdefines.TASK_ERROR.HAS_TASK_LIMIT
        end
    end
    return true
end

-- TODO 直接传oTask不妥，意味着创建失败是要析构的，此处的消耗显多余
-- @return: <bool>succ, <int>errNo
function CTaskCtrl:CanAddTask(oTask)
    local bPass, iErr = self:ValidAddTask(oTask)
    if not bPass then
        baseobj_delay_release(oTask)
        return false, iErr
    end
    local oWorldMgr = global.oWorldMgr
    local iPid = self.m_Owner
    local oPlayer = oWorldMgr:GetOnlinePlayerByPid(iPid)
    local bPass, iErr = global.oTaskHandler:IsTaskVisible(oPlayer, oTask:GetId())
    if not bPass then
        baseobj_delay_release(oTask)
        return false, iErr
    end
    local iKind = oTask:Type()
    local bPass, iErr = oTask:PreCondition(oPlayer)
    if not bPass then
        if extend.Table.find({taskdefines.TASK_KIND.TRUNK, taskdefines.TASK_KIND.TEST}, iKind) then
            -- 领取失败的任务要重新可接
            self.m_oAcceptableMgr:SetSingleTaskAcceptable(oTask:GetId(), true)
        end
        baseobj_delay_release(oTask)
        return false, iErr
    end
    return true
end

--  极不安全，现在由前端处理确认框，如果需要启用此代码，需要将oTask初始化位置调整，此处只应使用taskid
-- function OnConfirmAddTask(oPlayer, npcid, mData)
--     local oTask = self.m_tmp_oConfirmingTask
--     if not oTask then
--         return
--     end
--     local oNpc = oTask:GetNpcObj(npcid)
--     local iAnswer = mData["answer"]
--     if iAnswer == 1 then
--         oPlayer.m_oTaskCtrl:DoAddTask(oTask, oNpc)
--     else
--         baseobj_delay_release(oTask)
--         self.m_tmp_oConfirmingTask = nil
--     end
-- end

-- -- 领取任务前出现confirm菜单
-- function CTaskCtrl:ToConfirmAddTask(oTask, npcobj)
--     if not npcobj then
--         return false
--     end
--     local iLinkId = oTask:GetLinkId()
--     if not iLinkId then
--         return false
--     end
--     local mLinkInfo = global.oTaskLoader:GetLinkInfo(oTask:GetDirName(), iLinkId)
--     if not mLinkInfo then
--         return false
--     end
--     local sConfirm = mLinkInfo.confirm
--     if not sConfirm or 0 == #sConfirm then
--         return false
--     end
--     local iPid = self.m_Owner
--     self.m_tmp_oConfirmingTask = oTask
--     local npcid = npcobj.m_ID
--     local cbFunc = function (oPlayer, mData)
--         oPlayer.m_oTaskCtrl:OnConfirmAddTask(oPlayer, npcid, mData)
--     end
--     npcobj:SayRespond(iPid, sConfirm .. "&Q确认&Q取消", nil, cbFunc, nil, nil, true)
--     return true
-- end

function CTaskCtrl:AddTaskById(taskid, npcobj, bForce, mArgs)
    local oTask = global.oTaskLoader:CreateTask(taskid)
    if not oTask then
        return
    end
    self:AddTask(oTask, npcobj, bForce, mArgs)
end

function CTaskCtrl:AddTask(oTask, npcobj, bForce, mArgs)
    if not bForce then
        local bPass, iErr = self:CanAddTask(oTask)
        if not bPass then
            return false, iErr
        end
    end
    return self:DoAddTask(oTask, npcobj, mArgs)
end

function CTaskCtrl:DoAddTask(oTask, npcobj, mArgs)
    local taskid = oTask:GetId()
    local sDirName = oTask.m_sName
    local iLinkId = global.oTaskLoader:GetLinkIdByHead(sDirName, taskid) or global.oTaskLoader:GetTaskBaseData(taskid).linkid
    if iLinkId then
        if self.m_oAcceptableMgr:IsLinkDone(sDirName, iLinkId) then
            record.error(debug.traceback(string.format('AddTask[%d] but LinkDone, rec-only, task got go on', taskid)))
        end
    end
    self:Dirty()
    local oWorldMgr = global.oWorldMgr
    local iPid = self.m_Owner
    local oPlayer = oWorldMgr:GetOnlinePlayerByPid(iPid)
    oTask:SetOwner(iPid)

    local mAccSaveData = self.m_oAcceptableMgr:GetTaskSaveData(taskid)
    local mLogData = oPlayer:LogData()
    mLogData.taskid = taskid
    mLogData.back_data = mAccSaveData or 0
    record.user("task", "add_task", mLogData)

    if mAccSaveData and type(mAccSaveData) == "table" and mAccSaveData.data then
        oTask:Load(mAccSaveData)
    else
        oTask:Config(iPid,npcobj, mArgs)
    end

    oTask:SetCreateTime()
    oTask:ConfigTimeOut()
    oTask:Setup()

    self.m_List[taskid] = oTask
    self:GS2CAddTask(oTask)

    if oTask:HasFollowNpc() then
        self:RefreshFollowNpcs()
    end

    oTask:OnAddDone(oPlayer)
    oTask:LogTaskWanfaInfo(oPlayer, 1)

    -- 数据中心
    if oTask:GetDirName() == "story" then
        local mAnalyLog = oPlayer:BaseAnalyInfo()
        mAnalyLog["step_id"] = oTask:GetId()
        mAnalyLog["operation"] = 1
        analy.log_data("NewplayerGuide", mAnalyLog)

        local mAnalyLog = oPlayer:BaseAnalyInfo()
        mAnalyLog["main_step_type"] = oTask:TaskType()
        mAnalyLog["operation"] = 1
        mAnalyLog["main_step_id"] = oTask:GetId()
        mAnalyLog["consume_detail"] = ""
        mAnalyLog["reward_detail"] = ""
        analy.log_data("MainStep", mAnalyLog)        
    end

    -- TODO 后面的直接完成等处理要改为DisplayMgr回调
    oTask:PlayAcceptPlots(iPid,npcobj)

    self:TriggerEvent(taskdefines.EVENT.ADD_TASK, {pid=iPid, task=oTask})

    -- 检查任务是否可以直接完成
    if oTask:CheckDirectlyDone(npcobj) then
        oTask:MissionReach(npcobj)
        return true
    end

    return true
end

-- function CTaskCtrl:PreRemoveTask(oTask)
--     local iPid = self.m_Owner
--     self:TriggerEvent(taskdefines.EVENT.PRE_DEL_TASK, {pid=iPid, task=oTask})
-- end

function CTaskCtrl:RemoveTask(oTask)
    if oTask:IsTeamTask() then
        assert(nil, string.format("teamtask can not call by oTaskCtrl, taskid:%d,callerPid:%d", oTask:GetId(), self:GetOwner()))
        return
    end
    local taskid = oTask:GetId()
    if not self.m_List[taskid] then
        return
    end
    local iPid = self.m_Owner
    local oPlayer = global.oWorldMgr:GetOnlinePlayerByPid(iPid)
    if oPlayer then
        local mLogData = oPlayer:LogData()
        mLogData.taskid = taskid
        mLogData.is_done = oTask:GetDone()
        record.user("task", "remove_task", mLogData)
    end
    self:Dirty()
    self.m_List[taskid] = nil
    self:GS2CRemoveTask(oTask)
    self:TriggerEvent(taskdefines.EVENT.DEL_TASK, {pid=iPid, task=oTask})
end

function CTaskCtrl:TaskList()
    return self.m_List
end

function CTaskCtrl:GetTask(taskid)
   return self.m_List[taskid]
end

function CTaskCtrl:HasTask(taskid)
   local oTask = self.m_List[taskid]
    if oTask then
        return oTask
    end
    return false
end

-- @return: {sKindDir: {iLinkId:taskid, ...}, ...}
function CTaskCtrl:ListLinks()
    local mLinks = {}
    for _,oTask in pairs(self.m_List) do
        local iLinkId = oTask:GetLinkId()
        if iLinkId then
            local sKindDir = oTask:GetDirName()
            local mKindLinks = table_get_set_depth(mLinks, {sKindDir})
            mKindLinks[iLinkId] = oTask:GetId()
        end
    end
    return mLinks
end

function CTaskCtrl:HasAnlei(iMapId)
    self.m_oAnLeiCtrl:IsMapHasAnlei(iMapId)
end

function CTaskCtrl:IsDirty()
    local bDirty = super(CTaskCtrl).IsDirty(self)
    if bDirty then
        return true
    end
    if self.m_oAcceptableMgr:IsDirty() then
        return true
    end
    if self.m_oEverydayCtrl:IsDirty() then
        return true
    end
    if self.m_oXuanShangCtrl:IsDirty() then
        return true
    end
    for taskid,oTask in pairs(self.m_List) do
        if oTask:IsDirty() then
            return true
        end
    end
    return false
end

function CTaskCtrl:UnDirty()
    super(CTaskCtrl).UnDirty(self)
    self.m_oAcceptableMgr:UnDirty()
    self.m_oEverydayCtrl:UnDirty()
    self.m_oXuanShangCtrl:UnDirty()
    for taskid,oTask in pairs(self.m_List) do
        if oTask:IsDirty() then
            oTask:UnDirty()
        end
    end
end

function CTaskCtrl:GS2CAddTask(oTask)
    oTask:GS2CAddTask(self:GetOwner())
end

function CTaskCtrl:GS2CRemoveTask(oTask)
    local mNet = {}
    mNet["taskid"] = oTask:GetId()
    mNet["is_done"] = oTask:PackIsDone()
    local oWorldMgr = global.oWorldMgr
    local oPlayer = oWorldMgr:GetOnlinePlayerByPid(self.m_Owner)
    if oPlayer then
        oPlayer:Send("GS2CDelTask",mNet)
    end
end

function CTaskCtrl:OnLogout()
    self.m_oEverydayCtrl:OnLogout()
    self.m_oXuanShangCtrl:OnLogout()
    for _, taskid in pairs(table_key_list(self.m_List)) do
        local oTask = self.m_List[taskid]
        if oTask then 
            oTask:OnLogout(oPlayer)
        end
    end
end

function CTaskCtrl:OnLogin(oPlayer,bReEnter)
    local mNet = {}
    local mData = {}
    for _, taskid in pairs(table_key_list(self.m_List)) do
        local oTask = self.m_List[taskid]
        if oTask then
            oTask:OnLogin(oPlayer, bReEnter)
        end
    end
    -- login可能会删任务、加新任务，需要处理完后再重新扫描
    -- PS. 感觉也可以处理为下行LoginTask后再遍历OnLogin处理
    for taskid, oTask in pairs(self.m_List) do
        if is_gs_server() then
            table.insert(mData, oTask:PackTaskInfo())
        end
    end
    mNet["taskdata"] = mData
    if oPlayer then
        oPlayer:Send("GS2CLoginTask",mNet)
    end
    local pid = oPlayer:GetPid()

    self:TouchShimen(oPlayer)

    if not bReEnter then
        self:MakeTitleRegister()
    end

    self:SyncStoryChapters(oPlayer)

    self:SyncUnlockedTags(oPlayer)

    self.m_oAcceptableMgr:OnLogin(bReEnter) -- 此处会获得新任务
    self.m_oEverydayCtrl:OnLogin(bReEnter)
    self.m_oXuanShangCtrl:OnLogin(bReEnter)
    if global.oYibaoMgr then
        global.oYibaoMgr:OnLogin(oPlayer, bReEnter)
    end
    self:TodayAssistExp(oPlayer)
end

function CTaskCtrl:LoginEnd(bReEnter)
    self.m_oAnLeiCtrl:LoginEnd(bReEnter)
end

function CTaskCtrl:IsTaskTitleAvailable(oPlayer, iTid)
    if not iTid then
        return false
    end
    local mTitlePrelocks = table_get_depth(res, {"daobiao", "task_ext", "tasktitle", "titles", iTid, "prelocks"})
    if not mTitlePrelocks then
        return
    end
    local f = function(_,iTag)
        return not self:IsTagLocked(iTag)
    end
    return table_all_true(mTitlePrelocks, f)
end


function CTaskCtrl:DoOnEventUnlockTag(oPlayer, mData)
    local oPlayer = global.oWorldMgr:GetOnlinePlayerByPid(self.m_Owner)
    if not oPlayer then
        return
    end
    local iTag = mData.tag
    local oTitleCtrl = oPlayer.m_oTitleCtrl
    local lLock2Titles = table_get_depth(res, {"daobiao", "task_ext", "tasktitle", "locks", iTag})
    if not lLock2Titles then
        return
    end
    for _, iTid in ipairs(lLock2Titles) do
        if not oTitleCtrl:GetTitleByTid(iTid) then
            if self:IsTaskTitleAvailable(oPlayer, iTid) then
                oTitleCtrl:AddTitle(oPlayer, iTid)
            end
        end
    end
end

function OnEventUnlockTag(iEvType, mData)
    local oPlayer = global.oWorldMgr:GetOnlinePlayerByPid(mData.pid)
    if not oPlayer then
        return
    end
    oPlayer.m_oTaskCtrl:DoOnEventUnlockTag(oPlayer, mData)
end

function CTaskCtrl:MakeTitleRegister()
    local oPlayer = global.oWorldMgr:GetOnlinePlayerByPid(self.m_Owner)
    if not oPlayer then
        return
    end
    self:AddEvent(self, taskdefines.EVENT.UNLOCK_TAG, function(iEvType, mData)
        OnEventUnlockTag(iEvType, mData)
    end)
end

function CTaskCtrl:OnNewHour5(oPlayer)
    self:TouchShimen(oPlayer)
    self:TouchGuessGame()
    if global.oYibaoMgr then
        global.oYibaoMgr:TouchYibaoTasks(oPlayer)
    end
    self.m_oEverydayCtrl:NewDayMorning(oPlayer)
    self.m_oXuanShangCtrl:OnNewHour5(oPlayer)
end

-- TODO 改为cron
function CTaskCtrl:CheckTimeCb()
    for _, taskid in pairs(table_key_list(self.m_List)) do
        local oTask = self.m_List[taskid]
        if oTask then
            oTask:CheckTimeCb()
        end
    end
end

function CTaskCtrl:TouchGuessGame()
    local oTask = self:GotTaskKind(taskdefines.TASK_KIND.GUESSGAME)
    if oTask then
        oTask:Abandon()
    end
end

function CTaskCtrl:TouchShimen(oPlayer, bReset)
    if is_ks_server() then return end

    local iGrade = oPlayer:GetGrade()
    local oHasTask = self:GotTaskKind(taskdefines.TASK_KIND.SHIMEN)
    if not global.oToolMgr:IsSysOpen("SHIMEN", oPlayer, true) then
        if oHasTask then
            oHasTask:FullRemove()
        end
    elseif not oHasTask then
        self:TouchShimenNew(oPlayer)
    else
        oHasTask:Refresh()
    end
    global.oShimenMgr:SyncInfo(oPlayer)
end

function CTaskCtrl:TouchShimenNew(oPlayer)
    -- 师门任务的特殊处理
    local iDoneRing = global.oShimenMgr:GetShimenTodayDoneRing(oPlayer)
    local iShimenType = taskdefines.TASK_KIND.SHIMEN
    local oTask = self:GotTaskKind(iShimenType)

    if iDoneRing >= taskdefines.SHIMEN_INFO.LIMIT_RINGS then
        if oTask then
            oTask:FullRemove()
        end
    else
        if not oTask then
            self:AddShimenTask()
        end
    end
end

function CTaskCtrl:OnUpGradeEnd(oPlayer, iFromGrade, iToGrade)
    for _, taskid in pairs(table_key_list(self.m_List)) do
        local oTask = self.m_List[taskid]
        if oTask then
            oTask:CheckGrade(iToGrade)
        end
    end

    self:TouchShimen(oPlayer)

    self.m_oAcceptableMgr:OnUpGradeEnd(oPlayer, iFromGrade, iToGrade)
    self.m_oEverydayCtrl:OnUpGradeEnd(oPlayer, iFromGrade, iToGrade)
    self.m_oXuanShangCtrl:OnUpGradeEnd(oPlayer, iFromGrade, iToGrade)

    self:TodayAssistExp(oPlayer)
end

function CTaskCtrl:_CheckSelf()
    -- 流程与结构调整
    -- local iPid = self.m_Owner
    -- local oWorldMgr = global.oWorldMgr
    -- local oPlayer = oWorldMgr:GetOnlinePlayerByPid(iPid)
    -- if not oPlayer then
    --     return
    -- end
    -- local oNowScene = oPlayer.m_oActiveCtrl:GetNowScene()
    -- if not oNowScene then
    --     return
    -- end
    -- local iMapId = oNowScene:MapId()
    -- for _, taskid in pairs(table_key_list(self.m_List)) do
    --     local oTask = self.m_List[taskid]
    --     if oTask then
    --         if oTask:IsAnlei() and oTask:ValidTriggerAnlei(iMapId) then
    --             oTask.m_oAnLeiCtrl:CheckTriggerAnLei(iPid,iMapId)
    --         end
    --     end
    -- end
end

function CTaskCtrl:GetShimenLvsData()
    return res["daobiao"]["shimenlv"]
end

function CTaskCtrl:GetShimenRatio()
    return res["daobiao"]["shimentaskratio"]
end

function CTaskCtrl:ValidGiveShimenTask()
    local oWorldMgr = global.oWorldMgr
    local oPlayer = oWorldMgr:GetOnlinePlayerByPid(self.m_Owner)
    if not oPlayer then
        return false
    end
    if not global.oToolMgr:IsSysOpen("SHIMEN", oPlayer, true) then
        return false
    end
    if oPlayer.m_oTodayMorning:Query("perfect_shimen") then
        return false
    end
    if global.oShimenMgr:GetShimenTodayDoneRing(oPlayer) >= taskdefines.SHIMEN_INFO.LIMIT_RINGS then
        return false
    end
    return true
end

function CTaskCtrl:GetShimenLv(oPlayer)
    local iGrade = oPlayer:GetGrade()
    for iShimenLv, mLvData in pairs(self:GetShimenLvsData()) do
        if iGrade <= mLvData.lv_ceil and iGrade >= mLvData.lv_floor then
            return iShimenLv
        end
    end
    return nil
end

-- 根据等级来选择随机表
function CTaskCtrl:GetShimenTask()
    local oPlayer = global.oWorldMgr:GetOnlinePlayerByPid(self.m_Owner)
    if not oPlayer then
        return nil
    end
    local iShimenLv = self:GetShimenLv(oPlayer)
    if not iShimenLv then
        return nil
    end

    local iSchool = oPlayer:GetSchool()
    local mShimenRatioData = self:GetShimenRatio()
    local mRatios = table_get_depth(mShimenRatioData, {iSchool, iShimenLv})
    if not mRatios then
        return nil
    end

    local iTask = table_choose_key(mRatios)
    local taskobj = global.oTaskLoader:CreateTask(iTask)
    return taskobj
end

function CTaskCtrl:AddShimenTask()
    if not self:ValidGiveShimenTask() then
        return nil
    end
    local taskobj = self:GetShimenTask()
    if not taskobj then
        return nil
    end
    self:AddTask(taskobj)
    return taskobj.m_ID
end

function CTaskCtrl:GetAllUnlockedTags()
    return self.m_mTagUnlocks
end

function CTaskCtrl:LockTag(iTag)
    if not self.m_mTagUnlocks[iTag] then
        return
    end
    self:Dirty()
    self.m_mTagUnlocks[iTag] = nil
    local iPid = self:GetOwner()
    local oPlayer = global.oWorldMgr:GetOnlinePlayerByPid(iPid)
    if oPlayer then
        self:SyncTagLockState(oPlayer, iTag)
    end
    self:TriggerEvent(taskdefines.EVENT.LOCK_TAG, {pid=iPid, tag=iTag})
end

function CTaskCtrl:UnlockTag(iTag)
    local iPid = self:GetOwner()
    local mDefinedTags = GetTaskExtData().taglock
    assert(mDefinedTags and mDefinedTags[iTag], string.format("task taglock undefined in taglock.xlsx, pid=%d,tag=%s", iPid, iTag))
    if self.m_mTagUnlocks[iTag] then
        return
    end
    self:Dirty()
    self.m_mTagUnlocks[iTag] = true
    local oPlayer = global.oWorldMgr:GetOnlinePlayerByPid(iPid)
    if oPlayer then
        self:SyncTagLockState(oPlayer, iTag)
    end
    self:TriggerEvent(taskdefines.EVENT.UNLOCK_TAG, {pid=iPid, tag=iTag})
end

function CTaskCtrl:IsTagLocked(iTag)
    return not self.m_mTagUnlocks[iTag]
end

function CTaskCtrl:RecLinkDone(sDirName, iLinkId)
    if not iLinkId then
        return
    end
    self.m_oAcceptableMgr:RecLinkDone(sDirName, iLinkId)
end

function CTaskCtrl:DoPlayStoryAnime(iAnimeId, fCallBack)
    self.m_tmp_mStoryAnime = {
        anime = iAnimeId,
    }
    local mNet = {
        anime_id = iAnimeId,
    }
    global.oCbMgr:SetCallBack(self:GetOwner(), "GS2CPlayAnime", mNet, nil, fCallBack)
end

function CTaskCtrl:PlayStoryAnime(iAnimeId)
    local fCallBack = function(oPlayer, mData)
        local oTaskCtrl = oPlayer.m_oTaskCtrl
        if not oTaskCtrl then
            return
        end
        oTaskCtrl:OnStoryAnimeCallback(oPlayer, mData)
    end
    self:DoPlayStoryAnime(iAnimeId, fCallBack)
end

function CTaskCtrl:PlayStoryAnimeFight(iAnimeId, iTaskid, npcid)
    local fCallBack = function(oPlayer, mData)
        local oTaskCtrl = oPlayer.m_oTaskCtrl
        if not oTaskCtrl then
            return
        end
        oTaskCtrl:OnStoryAnimeFightCallback(oPlayer, mData, iTaskid, npcid)
    end
    self:DoPlayStoryAnime(iAnimeId, fCallBack)
end

function CTaskCtrl:DealStoryAnimeCallbackCommon(oPlayer, mData)
    -- PS.认定只有一个剧情动画可以播放，暂时要求前端当前动画未播放完毕又开新动画不上行前一个session回调
    self.m_tmp_mStoryAnime = nil
    if mData.reenter == 1 then
        global.oSceneMgr:ReEnterScene(oPlayer)
    end
end

function CTaskCtrl:OnStoryAnimeCallback(oPlayer, mData)
    self:DealStoryAnimeCallbackCommon(oPlayer, mData)
end

function CTaskCtrl:OnStoryAnimeFightCallback(oPlayer, mData, iTaskid, npcid)
    self:DealStoryAnimeCallbackCommon(oPlayer, mData)
    local oTask = global.oTaskMgr:GetUserTask(oPlayer, iTaskid, true)
    oTask:OnAnimeFightEnd(oPlayer, npcid, mData.answer)
end

function CTaskCtrl:OnStoryAnimeQteEnd(oPlayer, iAnimeId, iQteId, bSucc)
    if not bSucc then
        return
    end
    assert(iAnimeId and iQteId, string.format("story anime[%s] qte[%s] null", iAnimeId, iQteId))
    if not self.m_tmp_mStoryAnime then
        return
    end
    if self.m_tmp_mStoryAnime.anime ~= iAnimeId then
        return
    end

    local iRewardId = table_get_depth(res, {"daobiao", "story_anime_qte", iAnimeId, iQteId, "rewardid"})
    if iRewardId and iRewardId > 0 then
        if self:CheckTaskRewardMonitor(oPlayer:GetPid(), "qte", iRewardId) then
            global.oRewardMgr:RewardByGroup(oPlayer, "qte", iRewardId)
        end
    end
end

function CTaskCtrl:CheckTaskRewardMonitor(iPid, sGroupName, iRewardId, mArgs)
    local oRewardMonitor = global.oTaskMgr:GetTaskRewardMonitor()
    if oRewardMonitor and not oRewardMonitor:CheckRewardGroup(iPid, sGroupName, iRewardId, 1, mArgs) then
        return false
    end
    return true
end

function CTaskCtrl:PackStoryChapterInfo(iChapter)
    local mNet = {
        chapter = iChapter,
        pieces = self.m_mStoryChapterPieces[iChapter] or {},
        rewarded = self.m_mRewardedChapter[iChapter],
    }
    return mNet
end

-- function CTaskCtrl:GetCurStoryChapter()
--     return self.m_iCurStoryChapter
-- end

function CTaskCtrl:TryPromoteStoryChapterSection(iChapter, iSection)
    if iChapter <= 0 then
        return
    end
    local mCurChapterSection = table_get_set_depth(self, {"m_mStoryChapterSection"})
    local iCurChapter, iCurSection = (mCurChapterSection.chapter or 0), (mCurChapterSection.section or 0)
    if iChapter < iCurChapter then
        return
    elseif iChapter > iCurChapter then
        mCurChapterSection.chapter = iChapter
        mCurChapterSection.section = iSection
    else -- iChapter == iCurChapter
        if iSection <= iCurSection then
            return
        end
        mCurChapterSection.section = iSection
    end
    self:Dirty()

    local iPid = self.m_Owner
    local oPlayer = global.oWorldMgr:GetOnlinePlayerByPid(iPid)
    if oPlayer then
        local mLogData = oPlayer:LogData()
        mLogData.old_chapter = iCurChapter
        mLogData.old_section = iCurSection
        mLogData.new_chapter = iChapter
        mLogData.new_section = iSection
        record.user("task", "promote_chapter", mLogData)

        local mNet = {
            chapter_section = self:PackStoryChapterSection(),
        }
        oPlayer:Send("GS2CStoryChapterInfo", mNet)
    end
end

function CTaskCtrl:IsChapterProceedFull(iChapter)
    if not self.m_mStoryChapterSection then
        return false
    end
    local iCurChapter = (self.m_mStoryChapterSection.chapter or 0)
    if iChapter < iCurChapter then
        return true
    end
    if iChapter > iCurChapter then
        return false
    end
    local iTotolProceeds = global.oTaskLoader:GetStoryChapterInfo(iCurChapter)["proceeds"]
    if not iTotolProceeds then
        return false
    end
    if (self.m_mStoryChapterSection.section or 0) >= iTotolProceeds then
        return true
    end
    return false
end

function CTaskCtrl:IsChapterOpen(oPlayer, iChapter)
    local iNeedGrade = global.oTaskLoader:GetStoryChapterInfo(iChapter).grade or 0
    if oPlayer:GetGrade() < iNeedGrade then
        return false
    end
    local iCurChapter = ((self.m_mStoryChapterSection or {}).chapter or 0)
    if iCurChapter < iChapter - 1 then
        return false
    end
    -- for i = 1, (iChapter - 1) do
    --     if not self:IsChapterProceedFull(i) then
    --         return false
    --     end
    -- end
    return true
end

function CTaskCtrl:RewardStoryChapter(oPlayer, iChapter)
    if self.m_mRewardedChapter[iChapter] then
        return
    end
    if not self:IsChapterOpen(oPlayer, iChapter) then
        return
    end
    if not self:IsChapterProceedFull(iChapter) then
        return
    end
    local iRewardId = global.oTaskLoader:GetStoryChapterInfo(iChapter)["reward"]
    if not iRewardId then
        return
    end

    local mLogData = oPlayer:LogData()
    mLogData.chapter = iChapter
    mLogData.rewardid = iRewardId
    record.user("task", "reward_chapter", mLogData)

    self.m_mRewardedChapter[iChapter] = 1
    self:Dirty()
    local oRewardMonitor = global.oTaskMgr:GetStoryTaskRewardMonitor()
    if oRewardMonitor and oRewardMonitor:CheckRewardGroup(oPlayer:GetPid(), "storychapter", iChapter) then
        global.oRewardMgr:RewardByGroup(oPlayer, "story", iRewardId)
    end
    oPlayer:Send("GS2CStoryChapterRewarded", {chapter = iChapter})
end

function CTaskCtrl:PackStoryChapterSection()
    local mCurChapterSection = self.m_mStoryChapterSection or {}
    return {
        chapter = mCurChapterSection.chapter or 0,
        section = mCurChapterSection.section or 0,
    }
end

function CTaskCtrl:SyncStoryChapters(oPlayer)
    local mNet = {
        chapter_section = self:PackStoryChapterSection(),
        chapter_rewarded = table_key_list(self.m_mRewardedChapter),
    }
    oPlayer:Send("GS2CLoginStoryInfo", mNet)
end

function CTaskCtrl:SyncUnlockedTags(oPlayer)
    local mNet = {
        tags = table_key_list(self.m_mTagUnlocks),
    }
    oPlayer:Send("GS2CLoginUnlockedTags", mNet)
end

function CTaskCtrl:SyncTagLockState(oPlayer, iTag)
    local mNet = {
        tag = iTag,
        unlock = self.m_mTagUnlocks[iTag] and 1 or 0,
    }
    oPlayer:Send("GS2CUnlockTag", mNet)
end

function CTaskCtrl:RefreshFollowNpcs()
    local iPid = self.m_Owner
    local oPlayer = global.oWorldMgr:GetOnlinePlayerByPid(iPid)
    if oPlayer then
        self:RePackFollowNpcs()
        oPlayer:SyncFollowers()
    end
end

function CTaskCtrl:RePackFollowNpcs()
    local lInfo = {}
    for _,oTask in pairs(self:TaskList()) do
        local lFollows = oTask:PackFollowNpcsSceneInfo()
        if lFollows then
            lInfo = list_combine(lInfo, lFollows)
        end
    end
    -- TODO 组队任务暂时不支持，暂离情况会难处理
    -- local oPlayer = global.oWorldMgr:GetOnlinePlayerByPid(self.m_Owner)
    -- local oTeam = oPlayer:HasTeam()
    -- if oTeam then
    --     for _,oTask in pairs(oTeam:TaskList()) do
    --         local lFollows = oTask:PackFollowNpcsSceneInfo()
    --         if lFollows then
    --             lInfo = list_combine(lInfo, lFollows)
    --         end
    --     end
    -- end
    self.m_tmp_mFollowNpcs = lInfo
    return lInfo
end

function CTaskCtrl:FollowersInfo()
    if not self.m_tmp_mFollowNpcs then
        self:RePackFollowNpcs()
    end
    return self.m_tmp_mFollowNpcs
end

function CTaskCtrl:TestChapterOp(oPlayer, sOrder, xArgs)
    local pid = oPlayer:GetPid()
    if "full" == sOrder then
        if "number" ~= type(xArgs) then
            global.oNotifyMgr:Notify(pid, "参数不对")
            return
        end
        local iChapter = xArgs
        local iTotolProceeds = global.oTaskLoader:GetStoryChapterInfo(iChapter)["proceeds"] or 0
        self.m_mStoryChapterSection = {chapter = iChapter, section = iTotolProceeds}
        local mNet = {
            chapter_section = self:PackStoryChapterSection(),
        }
        oPlayer:Send("GS2CStoryChapterInfo", mNet)
    elseif "reset" == sOrder then
        -- self.m_iCurStoryChapter = nil
        -- self.m_mStoryChapterPieces = {}
        self.m_mStoryChapterSection = {}
        self.m_mRewardedChapter = {}
        self:SyncStoryChapters(oPlayer)
    end
    global.oNotifyMgr:Notify(pid, "执行完毕")
end

function CTaskCtrl:GetCurStoryVisualConfig()
    return self.m_tmp_iStoryVisualConfig or 0
end

-- 某个任务做了设置，当前任务会按照配置更改可见性，其他不变
function CTaskCtrl:SetCurStoryVisualConfig(iVisualConfigId, bOnLogin, sSource)
    if not bOnLogin and self:GetCurStoryVisualConfig() == iVisualConfigId then
        return
    end
    self.m_tmp_iStoryVisualConfig = iVisualConfigId
    if not iVisualConfigId or iVisualConfigId == 0 then
        return
    end
    -- 设置下行
    local mVisualConfigData = table_get_depth(res, {"daobiao", "task", "story", "visual_config", iVisualConfigId})
    if not mVisualConfigData then
        record.warning("task set visual_config null, configid:%d, source:%s", iVisualConfigId, sSource)
        return
    end
    local iPid = self:GetOwner()
    local oPlayer = global.oWorldMgr:GetOnlinePlayerByPid(iPid)
    local lNpcTypes = mVisualConfigData.show_npc
    if #lNpcTypes > 0 then
        oPlayer.m_oActiveCtrl.m_oVisualMgr:SetNpcVisible(oPlayer, lNpcTypes, true)
    end
    local lNpcTypes = mVisualConfigData.hide_npc
    if #lNpcTypes > 0 then
        oPlayer.m_oActiveCtrl.m_oVisualMgr:SetNpcVisible(oPlayer, lNpcTypes, false)
    end
    local lSEffIds = mVisualConfigData.show_scene_effect
    if #lSEffIds > 0 then
        oPlayer.m_oActiveCtrl.m_oVisualMgr:SetSceneEffectVisible(oPlayer, lSEffIds, true)
    end
    local lSEffIds = mVisualConfigData.hide_scene_effect
    if #lSEffIds > 0 then
        oPlayer.m_oActiveCtrl.m_oVisualMgr:SetSceneEffectVisible(oPlayer, lSEffIds, false)
    end
end

function CTaskCtrl:PackBackendInfo()
    local lInfos = {}
    for _, oTask in pairs(self.m_List) do
        table.insert(lInfos, oTask:PackBackendInfo())
    end
    return lInfos
end

function CTaskCtrl:MissionDone(oTask, npcobj, mArgs)
    local iPid = self:GetOwner()
    local oWorldMgr = global.oWorldMgr
    local oPlayer = oWorldMgr:GetOnlinePlayerByPid(iPid)

    global.oTaskMgr:DealMissionDone(oTask, iPid, npcobj, mArgs)
end

function CTaskCtrl:NextTask(oFromTask, iTaskid, npcobj, mArgs)
    local iLinkId
    if oFromTask then
        iLinkId = oFromTask:GetLinkId()
        self:MissionDone(oFromTask, npcobj, mArgs)
    end

    local oTask = global.oTaskLoader:CreateTask(iTaskid)
    if not oTask then
        return
    end
    if iLinkId then
        oTask:InitLinkId(iLinkId)
    end
    self:AddTask(oTask, npcobj, false, mArgs)
end

function CTaskCtrl:FireShimenDone(iRing, iDoneCnt)
    self:TriggerEvent(gamedefines.EVENT.SHIMEN_DONE, {ring = iRing, donecnt = iDoneCnt})
end

function CTaskCtrl:FireGhostDone(iRing)
    self:TriggerEvent(gamedefines.EVENT.GHOST_DONE, {ring = iRing})
end

function CTaskCtrl:FireYibaoDoneSub()
    self:TriggerEvent(gamedefines.EVENT.YIBAO_DONE_SUB, {})
end

function CTaskCtrl:TodayAssistExp(oPlayer)
    local mData = res["daobiao"]["task_ext"]["taskassist"][1]
    assert(mData, "CPromoteCtrl get config errror")
    local sMaxAssistExp = mData.max_exp
    local iMaxAssistExp = formula_string(sMaxAssistExp, { lv = oPlayer:GetGrade() })
    local iAssistExp = oPlayer.m_oTodayMorning:Query("task_assist_exp", 0)
    local mNet = {
        assist_exp = iAssistExp,
        max_assist_exp = iMaxAssistExp
    }
    oPlayer:Send("GS2CAssistExp", mNet)
end
