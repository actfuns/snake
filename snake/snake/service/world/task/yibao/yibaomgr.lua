local global = require "global"
local res = require "base.res"
local extend = require "base/extend"
local net = require "base.net"
local taskdefines = import(service_path("task/taskdefines"))
local gamedefines = import(lualib_path("public.gamedefines"))
local record = require "public.record"

function NewYibaoMgr()
    local o = CYibaoMgr:New()
    return o
end

CYibaoMgr = {}
CYibaoMgr.__index = CYibaoMgr
CYibaoMgr.m_sSysName = "异宝搜集"
inherit(CYibaoMgr, logic_base_cls())

function CYibaoMgr:New()
    local o = super(CYibaoMgr).New(self)
    return o
end

function CYibaoMgr:GetTextData(iText)
    return global.oToolMgr:GetTextData(iText, {"task_ext"})
end

function CYibaoMgr:GetYibaoLv(oPlayer)
    local iGrade = oPlayer:GetGrade()
    local mLvsData = table_get_depth(res, {"daobiao", "yibao_config", "seekitem_group_lv"})
    for iYibaoLv, mLvData in pairs(mLvsData) do
        if iGrade >= mLvData.grade_lower and iGrade <= mLvData.grade_upper then
            return iYibaoLv
        end
    end
end

function CYibaoMgr:CheckYibaoFinish(oPlayer)
    local oTaskCtrl = oPlayer.m_oTaskCtrl
    local oTask = oTaskCtrl:GetTask(taskdefines.YIBAO_INFO.MAIN_TASK)
    if not oTask then
        return
    end
    local fIsSubYibao = function (taskid, oTask)
        if taskid ~= taskdefines.YIBAO_INFO.MAIN_TASK and oTask:Type() == taskdefines.TASK_KIND.YIBAO then
            return oTask
        end
    end
    local mTasks = extend.Table.filtermap(oTaskCtrl:TaskList(), fIsSubYibao)
    if next(mTasks) then
        return
    end
    -- 领异宝总任务奖
    oTask:RewardYibaoMain()
end

-- 设定上任务要手动接，不能重设
function CYibaoMgr:ClearTasks(oPlayer)
    local oTaskCtrl = oPlayer.m_oTaskCtrl
    local iKindYibao = taskdefines.TASK_KIND.YIBAO
    local mAllTasks = oTaskCtrl:TaskList()
    for _, taskid in pairs(table_key_list(mAllTasks)) do
        local oTask = mAllTasks[taskid]
        if oTask and oTask:Type() == iKindYibao then
            oTask:FullRemove()
        end
    end
end

function CYibaoMgr:GetMainTask(oPlayer)
    local oTask = oPlayer.m_oTaskCtrl:GetTask(taskdefines.YIBAO_INFO.MAIN_TASK)
    return oTask
end

-- function CYibaoMgr:RandWithRatioData(mTempRatio, mMax, mCntRes, iTotalCnt, iNeedCnt)
--     -- 设置硬上限，如果找不满就直接填充
--     for times = 1, 3 do
--         for idx, mCntRange in pairs(mTempRatio) do
--             local iCnt = math.random(table.unpack(mCntRange))
--             -- if table.unpack(mCntRange) == 0 then
--             --     iCnt = 0
--             -- end
--             if iCnt <= 0 then
--                 goto continue
--             end
--             local iMax = mMax[idx]
--             local iLeftCnt = math.min(iMax - (mCntRes[idx] or 0), iNeedCnt - iTotalCnt)
--             assert(iLeftCnt > 0, string.format("RandYibaoRatio left err, has:%s, iMax[%d]:%d, iTotalCnt:%d", mCntRes[idx], idx, iMax, iTotalCnt))
--             if iCnt >= iLeftCnt then
--                 mTempRatio[idx] = nil
--                 iCnt = iLeftCnt
--             end
--             mCntRes[idx] = mCntRes[idx] or 0 + iCnt
--             iTotalCnt = iTotalCnt + iCnt

--             if iTotalCnt >= iNeedCnt then
--                 assert(iTotalCnt == iNeedCnt, "RandYibaoRatio get total overflow")
--                 return iTotalCnt
--             end
--             ::continue::
--         end
--     end
--     return iTotalCnt
-- end

-- function CYibaoMgr:RandOutTaskCntOld(oPlayer)
--     local mRatios = self:GetCntRatios() -- 概率数据源
--     local mTempRatio = {} -- 临时概率表
--     local mMax = {} -- 最大值查找表
--     local iTotalCnt = 0 -- 计数总计
--     local mCntRes = {} -- 计数结果
--     local iNeedCnt = taskdefines.YIBAO_INFO.SUB_TASK_CNT
--     -- local iNeedCnt = 17
--     for idx, mInfo in pairs(mRatios) do
--         local mCntRange = mInfo.cnt_range
--         local iMax = mInfo.max_cnt
--         if iMax == 0 then
--             iMax = #mInfo.tasks
--         else
--             iMax = math.min(iMax, #mInfo.tasks)
--         end
--         mMax[idx] = iMax
--         mTempRatio[idx] = table_deep_copy(mCntRange)
--     end
--     iTotalCnt = self:RandWithRatioData(mTempRatio, mMax, mCntRes, iTotalCnt, iNeedCnt)
--     if iTotalCnt >= iNeedCnt then
--         goto rand_done
--     end
--     for idx, mCntRange in pairs(mTempRatio) do
--         local iLower, iUpper = table.unpack(mCntRange)
--         if iLower == 0 then
--             mTempRatio[idx] = {1, iUpper}
--         end
--     end
--     iTotalCnt = self:RandWithRatioData(mTempRatio, mMax, mCntRes, iTotalCnt, iNeedCnt)
--     assert(iTotalCnt == iNeedCnt, "rand tasks cnt err, total:" .. iTotalCnt)
--     ::rand_done::
--     return mCntRes
-- end


function CYibaoMgr:OnLogin(oPlayer, bReEnter)
    self:TouchYibaoTasks(oPlayer)
end

function CYibaoMgr:TouchSubTasks(oPlayer)
    -- if is_production_env() then
    --     self:ClearTasks(oPlayer)
    --     return
    -- end
    if not global.oToolMgr:IsSysOpen("YIBAO", oPlayer, true) then
        self:ClearTasks(oPlayer)
        return
    end
    local oMainTask = self:GetMainTask(oPlayer)
    if not oMainTask or oMainTask:GetData("sub_inited") then
        return
    end
    self:GrantSubTasks(oPlayer, oMainTask)
end

function CYibaoMgr:ToOpenUI(oPlayer, oTaskPlayer)
    -- if is_production_env() then
    --     self:ClearTasks(oPlayer)
    --     return
    -- end
    if not global.oToolMgr:IsSysOpen("YIBAO", oTaskPlayer, true) then
        if oPlayer == oTaskPlayer then
            global.oNotifyMgr:Notify(oPlayer:GetPid(), "尚未开启" .. self.m_sSysName)
        else
            global.oNotifyMgr:Notify(oPlayer:GetPid(), oTaskPlayer:GetName() .. "尚未开启" .. self.m_sSysName)
        end
        self:ClearTasks(oTaskPlayer)
        return
    end
    local oMainTask = self:GetMainTask(oTaskPlayer)
    if not oMainTask then
        return
    end

    -- lazy方式初始化子任务
    self:TouchSubTasks(oTaskPlayer)

    self:SendYibaoUI(oPlayer, oTaskPlayer)
end

function CYibaoMgr:PackYibaoMainTaskInfo(oPlayer)
    local oMainTask = self:GetMainTask(oPlayer)
    if not oMainTask then
        return
    end
    return oMainTask:PackYibaoInfo()
end

function CYibaoMgr:PackYibaoSubTasksInfo(oPlayer)
    local mInfo = {}
    local iKindYibao = taskdefines.TASK_KIND.YIBAO
    for taskid, oTask in pairs(oPlayer.m_oTaskCtrl:TaskList()) do
        if taskid ~= taskdefines.YIBAO_INFO.MAIN_TASK then
            if oTask:Type() == iKindYibao then
                table.insert(mInfo, oTask:PackYibaoInfo())
            end
        end
    end
    return mInfo
end

function CYibaoMgr:SendYibaoUI(oPlayer, oTaskPlayer, mMask)
    local oMainTask = self:GetMainTask(oTaskPlayer)
    if not oMainTask then
        return
    end
    local mNet = {
        owner = oTaskPlayer:GetPid(),
        create_day = oMainTask:GetCreateMorningDay(),
    }
    if not mMask or mMask.main_yibao_info then
        mNet.main_yibao_info = self:PackYibaoMainTaskInfo(oTaskPlayer)
    end
    if not mMask or mMask.doing_yibao_info then
        mNet.doing_yibao_info = self:PackYibaoSubTasksInfo(oTaskPlayer)
    end
    if not mMask or mMask.done_yibao_info then
        local mYibaoDoneRecInfo = oMainTask:GetYibaoDoneRec()
        if mYibaoDoneRecInfo then
            mNet.done_yibao_info = table_value_list(mYibaoDoneRecInfo)
        else
            mNet.done_yibao_info = {}
        end
    end
    local mSeekedGather = self:GetGatherHelpSeeked(oTaskPlayer)
    mNet.seek_gather_tasks = table_key_list(mSeekedGather or {})
    if oPlayer == oTaskPlayer then
        mNet.seek_gather_max = taskdefines.YIBAO_INFO.MAX_HELP_GATHER_REQ_TASKS
    end
    mNet = net.Mask("GS2COpenYibaoUI", mNet)
    oPlayer:Send("GS2COpenYibaoUI", mNet)
end

-- 检查玩家是否可以进行此玩法
function CYibaoMgr:TouchYibaoTasks(oPlayer)
    -- if is_production_env() then
    --     self:ClearTasks(oPlayer)
    --     return
    -- end
    if not global.oToolMgr:IsSysOpen("YIBAO", oPlayer, true) then
        self:ClearTasks(oPlayer)
        return
    end
    if self:IsOverdue(oPlayer) then
        self:ClearTasks(oPlayer)
        return
    end
end

function CYibaoMgr:IsOverdue(oPlayer)
    local oMainTask = self:GetMainTask(oPlayer)
    if oMainTask then
        if oMainTask:GetCreateMorningDay() ~= get_morningdayno(get_time()) then
            return true
        end
    end
    return false
end

function CYibaoMgr:NewTasks(oPlayer)
    -- if is_production_env() then
    --     return
    -- end
    if not global.oToolMgr:IsSysOpen("YIBAO", oPlayer) then
        -- global.oNotifyMgr:Notify(oPlayer:GetPid(), "尚未开启" .. self.m_sSysName)
        return
    end
    -- 每天刷新调此接口，命中新任务发放
    local iYibaoTimes = oPlayer.m_oTodayMorning:Query("yibao_times", 0)
    local iMaxTimes = taskdefines.YIBAO_INFO.MAX_TIMES
    if iYibaoTimes >= iMaxTimes then
        global.oNotifyMgr:Notify(oPlayer:GetPid(), global.oToolMgr:FormatColorString(self:GetTextData(70018), {count = iMaxTimes})) -- 异宝收集每天只能进行iMaxTimes次
        return
    end
    -- 理论上，领取任务时应该已经没有旧任务了
    -- self:ClearTasks(oPlayer)
    oPlayer.m_oTodayMorning:Add("yibao_times", 1)
    self:GrantMainTask(oPlayer)
end

function CYibaoMgr:GrantMainTask(oPlayer)
    local oTaskCtrl = oPlayer.m_oTaskCtrl
    oTaskCtrl:AddTaskById(taskdefines.YIBAO_INFO.MAIN_TASK, nil, true)
    -- 滞后发放子任务，现在不予显示故不发任务
end

function CYibaoMgr:GrantSubTasks(oPlayer, oMainTask)
    local iYibaoLv = self:GetYibaoLv(oPlayer)
    if not iYibaoLv then
        assert(iYibaoLv, string.format("player no yibaolv, pid:%d, grade:%d", oPlayer:GetPid(), oPlayer:GetGrade()))
    end
    oMainTask:SetData("sub_inited", true)
    local oTaskCtrl = oPlayer.m_oTaskCtrl
    local mCnts = self:RandOutTaskCnt()
    local mRatios = self:GetCntRatios() -- 概率数据源
    local mArgs = {
        yibao_lv = iYibaoLv,
    }
    for idx, iCnt in pairs(mCnts) do
        local mAllTasks = mRatios[idx]["tasks"]
        local mRandTasks = extend.Random.random_size(mAllTasks, iCnt)
        for _, taskid in pairs(mRandTasks) do
            oTaskCtrl:AddTaskById(taskid, nil, true, mArgs)
        end
    end
end

function CYibaoMgr:RandOutTaskCnt()
    local mRatios = self:GetCntRatios() -- 概率数据源
    local iTotalCnt = 0 -- 计数总计
    local mCntRes = {} -- 计数结果
    local iNeedCnt = taskdefines.YIBAO_INFO.SUB_TASK_CNT
    for idx, mInfo in pairs(mRatios) do
        local mCntRange = mInfo.cnt_range
        local iMax = mInfo.max_cnt
        if not iMax or iMax == 0 then
            iMax = #mInfo.tasks
        else
            iMax = math.min(iMax, #mInfo.tasks)
        end

        local iLower, iUpper = table.unpack(mCntRange)
        local iCnt
        if iLower then
            iCnt = math.random(iLower, iUpper)
        else
            iCnt = iNeedCnt - iTotalCnt
        end
        if iCnt > iMax then
            iCnt = iMax
        end
        assert(iCnt >= 0, string.format("Yibao rand task cnt err, cnt[%d]:%d", idx, iCnt))
        if iCnt > 0 then
            iTotalCnt = iTotalCnt + iCnt
            mCntRes[idx] = iCnt
            if iTotalCnt >= iNeedCnt then
                assert(iTotalCnt == iNeedCnt, "Yibao rand task overflow, got:" .. iTotalCnt)
                break
            end
        end
    end
    return mCntRes
end

function CYibaoMgr:RecYibaoDoneInfo(oPlayer, oSubTask)
    local oMainTask = self:GetMainTask(oPlayer)
    if oMainTask and oMainTask~= oSubTask then
        oMainTask:RecYibaoDoneInfo(oSubTask:PackYibaoInfo(false))
        -- oPlayer:Send("GS2CYibaoTaskDone", {taskid = oSubTask:GetId()})
    end
end

function CYibaoMgr:GetYibaoDoneInfo(oPlayer)
    local oMainTask = self:GetMainTask(oPlayer)
    if oMainTask then
        return oMainTask:GetYibaoDoneRec()
    end
end

function CYibaoMgr:GetTaskData(taskid)
    local mData = table_get_depth(res, {"daobiao", "task", "yibao", "task", taskid})
    return mData
end

function CYibaoMgr:GetExploreName(iStar, iNameIdx)
    return table_get_depth(res, {"daobiao", "yibao_config", "star_info", iStar, "name", iNameIdx}) or ""
end

function CYibaoMgr:GetCntRatios()
    return table_get_depth(res, {"daobiao", "yibao_config", "type_cnt_ratio"})
end

-- 部分在线玩家5点刷新
function CYibaoMgr:RefreshSomeOnNewHour5()
    local mOnlinePids = self.m_mNewHour5Pids
    if not mOnlinePids then
        return
    end
    local iPeriodCnt = 0
    local oWorldMgr = global.oWorldMgr
    for i = 1, 500 do
        local pid = table.remove(mOnlinePids)
        if not pid then
            break
        end
        local oPlayer = oWorldMgr:GetOnlinePlayerByPid(pid)
        if oPlayer then
            -- self:TouchYibaoTasks(oPlayer)
            safe_call(self.TouchYibaoTasks, self, oPlayer)
        end
    end
    if next(mOnlinePids) then
        self.m_mNewHour5Pids = mOnlinePids
        self:CallTimer(1, "newhour5", function()
            global.oYibaoMgr:RefreshSomeOnNewHour5()
        end)
    else
        self.m_mNewHour5Pids = nil
    end
end

function CYibaoMgr:NewHour(mNow)
    local iHour = mNow.date.hour
    if iHour == 5 then
        self:NewHour5()
    end
end

function CYibaoMgr:NewHour5()
    local mOnlinePids = table_key_list(global.oWorldMgr:GetOnlinePlayerList())
    self.m_mNewHour5Pids = mOnlinePids
    self:RefreshSomeOnNewHour5()
end

function CYibaoMgr:CallTimer(iSec, sKey, func)
    if iSec > 0 then
        self:DelTimeCb(sKey)
        self:AddTimeCb(sKey, iSec * 1000, func)
    end
end

function CYibaoMgr:GetGatherHelpSeeked(oPlayer)
    local oMainTask = self:GetMainTask(oPlayer)
    assert(oMainTask, "yibao mainTask must has, pid:" .. oPlayer:GetPid())
    return oMainTask:GetYibaoHelpSeekedGathers()
end

function CYibaoMgr:RecGatherHelpSeeked(oPlayer, iTaskid)
    if iTaskid == taskdefines.YIBAO_INFO.MAIN_TASK then
        return
    end
    local oMainTask = self:GetMainTask(oPlayer)
    assert(oMainTask, "yibao mainTask must has, pid:" .. oPlayer:GetPid())
    oMainTask:RecYibaoHelpSeekedGathers(iTaskid)
    local oTask = oPlayer.m_oTaskCtrl:GetTask(iTaskid)
    if oTask then
        oTask:TouchIsHelpSeeked()
    end
end

function CYibaoMgr:IsGatherHelpSeeked(oPlayer, iTaskid)
    if iTaskid == taskdefines.YIBAO_INFO.MAIN_TASK then
        return false
    end
    local mSeekedGather = self:GetGatherHelpSeeked(oPlayer)
    if mSeekedGather and mSeekedGather[iTaskid] then
        return true
    end
    return false
end

function CYibaoMgr:CanSeekGatherHelp(oPlayer, iTaskid)
    if iTaskid == taskdefines.YIBAO_INFO.MAIN_TASK then
        return false
    end
    local mSeekedGather = self:GetGatherHelpSeeked(oPlayer)
    if not mSeekedGather then
        return true
    end
    if mSeekedGather[iTaskid] then
        return true
    end
    if table_count(mSeekedGather) < taskdefines.YIBAO_INFO.MAX_HELP_GATHER_REQ_TASKS then
        return true
    end
    return false
end

function CYibaoMgr:SeekHelpYibao(oPlayer, iTaskid)
    local iOrgID = oPlayer:GetOrgID()
    if iOrgID == 0 then
        oPlayer:Send("GS2COpenOrgUI", {})
        return
    end
    local oTask = self:GetValidSubTask(oPlayer, oPlayer:GetPid(), iTaskid)
    if not oTask then
        return
    end
    if oTask:Type() ~= taskdefines.TASK_KIND.YIBAO then
        return
    end
    oTask:SeekHelpYibao(oPlayer)
end

function CYibaoMgr:IsSubTaskDone(oPlayer, iTaskid)
    local oMainTask = self:GetMainTask(oPlayer)
    if not oMainTask then
        return false
    end
    local mDoneRec = oMainTask:GetYibaoDoneRec()
    if not mDoneRec then
        return false
    end
    return mDoneRec[iTaskid]
end

function CYibaoMgr:GetValidSubTask(oPlayer, iTargetPid, iTaskid, iCreateDay)
    local oNotifyMgr = global.oNotifyMgr
    local iPid = oPlayer:GetPid()
    local oTargetPlayer
    if iPid ~= iTargetPid then
        local iPlayerOrgID = oPlayer:GetOrgID()
        if 0 == iPlayerOrgID then
            oNotifyMgr:Notify(iPid, self:GetTextData(70012)) -- 你不在帮派中
            return nil
        end
        oTargetPlayer = global.oWorldMgr:GetOnlinePlayerByPid(iTargetPid)
        if not oTargetPlayer then
            if iPid ~= iTargetPid then
                oNotifyMgr:Notify(iPid, self:GetTextData(70013)) -- 对方已下线
            end
            return nil
        end
        local iTargetOrgID = oTargetPlayer:GetOrgID()
        if iTargetOrgID ~= iPlayerOrgID then
            oNotifyMgr:Notify(iPid, self:GetTextData(70014)) -- 对方与你不在同帮派
            return nil
        end
    else
        oTargetPlayer = oPlayer
    end
    local oTask = oTargetPlayer.m_oTaskCtrl:GetTask(iTaskid)
    if not oTask then
        if self:IsSubTaskDone(oTargetPlayer, iTaskid) then
            -- 如果要不同任务提示不同，那么要加单例访问
            if iPid ~= iTargetPid then
                oNotifyMgr:Notify(iPid, self:GetTextData(70015)) -- 任务已被其他玩家帮助完成
            else
                oNotifyMgr:Notify(iPid, self:GetTextData(70016)) -- 任务已完成
            end
        else
            oNotifyMgr:Notify(iPid, self:GetTextData(70017)) -- 任务已过期
        end
        return nil
    end
    -- 检查任务day是否一致
    if iCreateDay and iCreateDay ~= oTask:GetCreateMorningDay() then
        oNotifyMgr:Notify(iPid, self:GetTextData(70017)) -- 任务已过期
        return nil
    end
    return oTask
end

function CYibaoMgr:HelpSubmitYibao(oHelper, iTargetPid, iTaskid, iCreateDay)
    local oTask = self:GetValidSubTask(oHelper, iTargetPid, iTaskid, iCreateDay)
    if not oTask then
        return
    end
    oTask:HelpSubmitYibao(oHelper)
end

function CYibaoMgr:GiveHelpYibao(oHelper, iTargetPid, iTaskid, iCreateDay)
    local oTask = self:GetValidSubTask(oHelper, iTargetPid, iTaskid, iCreateDay)
    if not oTask then
        return
    end
    oTask:GiveHelpYibao(oHelper)
end


---test-----------------------------------
function CYibaoMgr:TestRandOutTasksId()
    local measure = require "measure"
    measure.start()
    local iTimes = 100
    for i = 1,iTimes do
        local mCnts = self:RandOutTaskCnt()
        local mRatios = self:GetCntRatios() -- 概率数据源
        for idx, iCnt in pairs(mCnts) do
            local mAllTasks = mRatios[idx]["tasks"]
            local mRandTasks = extend.Random.random_size(mAllTasks, iCnt)
            for _, taskid in pairs(mRandTasks) do
            end
        end
    end
    local iCost = measure.stop()
    record.debug ("[yibaomgr.lua:TestRandOutTasksId] dldebug ---times,Cost:", iTimes, iCost)
end

function CYibaoMgr:TestRandOutTasksCnt()
    local measure = require "measure"
    measure.start()
    local iTimes = 1000
    for i = 1,iTimes do
        self:RandOutTaskCnt()
    end
    local iCost = measure.stop()
    record.debug ("[yibaomgr.lua:TestRandOutTasksSubCnt] dldebug ---times,Cost:", iTimes, iCost)
end

function CYibaoMgr:TestRandOutTasksNewMain(oPlayer)
    local measure = require "measure"
    measure.start()
    local iTimes = 100
    for i = 1,iTimes do
        oPlayer.m_oTodayMorning:Set("yibao_times", nil)
        self:NewTasks(oPlayer)
        local oMainTask = self:GetMainTask(oPlayer)
        oMainTask:SetData("sub_inited", true)
    end
    local iCost = measure.stop()
    record.debug ("[yibaomgr.lua:TestRandOutTasksNewMain] dldebug ---times,Cost:", iTimes, iCost)
end

function CYibaoMgr:TestRandOutTasksNewSubs(oPlayer)
    local oMainTask = self:GetMainTask(oPlayer)
    local measure = require "measure"
    measure.start()
    local iTimes = 100
    for i = 1,iTimes do
        self:GrantSubTasks(oPlayer, oMainTask)
    end
    local iCost = measure.stop()
    record.debug ("[yibaomgr.lua:TestRandOutTasksNewSubs] dldebug ---times,Cost:", iTimes, iCost)
end

function CYibaoMgr:TestRandElement(oPlayer)
    local measure = require "measure"
    measure.start()
    local oTaskCtrl = oPlayer.m_oTaskCtrl
    local iTimes = 1000
    local mIds = {70001, 70002, 70003, 70011, 70012, 70013}
    for i = 1,iTimes do
        local taskid = mIds[math.random(1, #mIds)]
    end
    local iCost = measure.stop()
    record.debug ("[yibaomgr.lua:TestRandElement] dldebug ---times,Cost:", iTimes, iCost)
end

function CYibaoMgr:TestNewAnyTask(oPlayer)
    local measure = require "measure"
    measure.start()
    local oTaskCtrl = oPlayer.m_oTaskCtrl
    local iTimes = 1000
    local mIds = {70001, 70002, 70003, 70011, 70012, 70013}
    for i = 1,iTimes do
        local taskid = mIds[math.random(1, #mIds)]
        oTaskCtrl:AddTaskById(taskid, nil, true)
        -- self:ClearTasks(oPlayer)
        -- local oTask = global.oTaskLoader:CreateTask(taskid)
        -- oPlayer.m_oTaskCtrl:DoAddTask(oTask)
    end
    local iCost = measure.stop()
    record.debug ("[yibaomgr.lua:TestNewAnyTask] dldebug ---times,Cost:", iTimes, iCost)
end

function CYibaoMgr:TestCreateTask(oPlayer)
    for taskid,oTask in pairs(oPlayer.m_oTaskCtrl.m_List) do
        oTask:FullRemove()
    end
    local measure = require "measure"
    measure.start()
    local iTimes = 1000
    local mIds = {70001, 70002, 70003, 70011, 70012, 70013}
    for i = 1,iTimes do
        local taskid = mIds[math.random(1, #mIds)]
        local oTask = global.oTaskLoader:CreateTask(taskid)
    end
    local iCost = measure.stop()
    record.debug ("[yibaomgr.lua:TestCreateTask] dldebug ---times,Cost:", iTimes, iCost)
end

function CYibaoMgr:TestAppendTask(oPlayer)
    local measure = require "measure"

    local taskid = 70015
    local oTask = global.oTaskLoader:CreateTask(taskid)
    measure.start()
    local iTimes = 1000
    for i = 1,iTimes do
        oPlayer.m_oTaskCtrl:Dirty()
        oPlayer.m_oTaskCtrl.m_List[taskid] = nil
        oPlayer.m_oTaskCtrl:AddTask(oTask)
    end
    local iCost = measure.stop()
    record.debug ("[yibaomgr.lua:TestAppendTask70015] dldebug ---times,Cost:", iTimes, iCost)

    local taskid = 70001
    local oTask = global.oTaskLoader:CreateTask(taskid)
    measure.start()
    local iTimes = 1000
    for i = 1,iTimes do
        oPlayer.m_oTaskCtrl:Dirty()
        oPlayer.m_oTaskCtrl.m_List[taskid] = nil
        oPlayer.m_oTaskCtrl:AddTask(oTask)
    end
    local iCost = measure.stop()
    record.debug ("[yibaomgr.lua:TestAppendTask70001] dldebug ---times,Cost:", iTimes, iCost)
end

function CYibaoMgr:TestGatherTaskRandGroup(oPlayer)
    local taskid = 70015
    local pid = oPlayer:GetPid()
    local oTask = global.oTaskLoader:CreateTask(taskid)
    local measure = require "measure"
    measure.start()
    local iTimes = 1000
    for i = 1,iTimes do
        oTask:SubConfig(pid)
    end
    local iCost = measure.stop()
    record.debug ("[yibaomgr.lua:TestGatherTaskRandGroup] dldebug ---times,Cost:", iTimes, iCost)
end
function CYibaoMgr:TestStringOpr(oPlayer)
    local measure = require "measure"
    local iTimes = 30000
    local a,b,c = "主角","怪物","TESTER"
    local m = {x = a, y = b, z = c}
    measure.start()
    for i = 1,iTimes do
        local s = "{x}能够挂到{y}，但是{z}不允许{x}"
        s = string.gsub(s, '{x}', a)
        s = string.gsub(s, '{y}', b)
        s = string.gsub(s, '{z}', c)
        local s = "{x}能够挂到"
        s = string.gsub(s, '{x}', a)
    end
    local iCost = measure.stop()
    record.debug ("[yibaomgr.lua:TestStringGsub] dldebug ---times,Cost:", iTimes, iCost)

    measure.start()
    for i = 1,iTimes do
        local s = "%s能够挂到%s，但是%s不允许%s"
        s = string.format(s, a,b,c,a)
        local s = "%s能够挂到"
        s = string.format(s, a)
    end
    local iCost = measure.stop()
    record.debug ("[yibaomgr.lua:TestStringFormat] dldebug ---times,Cost:", iTimes, iCost)

    measure.start()
    for i = 1,iTimes do
        local s = "{x}能够挂到{y}，但是{z}不允许{x}"
        local itMatch = string.gmatch(s, '{(.-)}')
        for sCmd in itMatch do
        end
    end
    local iCost = measure.stop()
    record.debug ("[yibaomgr.lua:TestStringGmatch] dldebug ---times,Cost:", iTimes, iCost)

    measure.start()
    for i = 1,iTimes do
        local s = "{x}能够挂到{y}，但是{z}不允许{x}"
        local itMatch = string.gmatch(s, '{(.-)}')
        for sCmd in itMatch do
            s = string.gsub(s, string.format("{%s}", sCmd), m[sCmd])
        end
    end
    local iCost = measure.stop()
    record.debug ("[yibaomgr.lua:TestStringGmatchSub] dldebug ---times,Cost:", iTimes, iCost)

    measure.start()
    for i = 1,iTimes do
        local s = "%s能够挂到%s，但是%s不允许%s"
        local mt = {}
        for _, sCmd in pairs({'x','y','z','x'}) do
            table.insert(mt, m[sCmd])
        end
        s = string.format(s, table.unpack(mt))
    end
    local iCost = measure.stop()
    record.debug ("[yibaomgr.lua:TestStringFormatPreMatched] dldebug ---times,Cost:", iTimes, iCost)
end
---end test-------------------------------
