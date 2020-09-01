local global = require "global"
local res = require "base.res"
local extend = require "base/extend"
local datactrl = import(lualib_path("public.datactrl"))
local xuanshangbase = import(service_path("task.xuanshang.xuanshangbase"))
local rewardmonitor = import(service_path("rewardmonitor"))
local record = require "public.record"
local taskdefines = import(service_path("task/taskdefines"))
local net = require "base.net"

local STATE = {
    NOACCEPT = 1,
    ACCEPTED = 2,
    DONE = 3,
}

local MAX_TIMES = 5
local COST_ITEM = 11038
local HELP_REWARD = 2001

local SHOW_LIMIT = 3

function NewXuanShangCtrl(pid)
    local o = CXuanShangCtrl:New(pid)
    return o
end

CXuanShangCtrl = {}
CXuanShangCtrl.__index = CXuanShangCtrl
inherit(CXuanShangCtrl, datactrl.CDataCtrl)

function CXuanShangCtrl:New(pid)
    local o = super(CXuanShangCtrl).New(self)
    o.m_iPid = pid
    o.m_iMorningDayNo = 0
    o.m_mTasks = {}
    o.m_lConfigTaskIds = {}
    o.m_mConfigStarRadio = {}
    o.m_oRewardMonitor = rewardmonitor.NewMonitor("xuanshang", {"reward", "xuanshang"})
    o.m_bTipFlag = false --四星五星的刷新提示标记
    return o
end

function CXuanShangCtrl:GetPid()
    return self.m_iPid
end

function CXuanShangCtrl:GetPlayer()
    local iPid = self:GetPid()
    return global.oWorldMgr:GetOnlinePlayerByPid(iPid)
end

function CXuanShangCtrl:OnLogin(bReEnter)
    local oPlayer = self:GetPlayer()

    if not bReEnter then
        oPlayer.m_oTaskCtrl:AddEvent(self, taskdefines.EVENT.DEL_TASK, function(iEvent, mData)
            local oPlayer = global.oWorldMgr:GetOnlinePlayerByPid(mData.pid)
            if oPlayer then
                oPlayer.m_oTaskCtrl.m_oXuanShangCtrl:AbandonTask(oPlayer, mData.task)
            end
        end)
    end

    if not self:IsOpenXuanShang(oPlayer) then
        return
    end

    if not bReEnter then
        self:InitConfig()
        self:CheckTimeout()
    end

    if table_count(self.m_mTasks) < SHOW_LIMIT then
        self:RefreshAllTask()
    end

    --兼容
    local iNewTimes = oPlayer.m_oTodayMorning:Query("xuanshang_accept_times", 0)
    local iOldTimes = oPlayer.m_oScheduleCtrl:GetDoneTimes(1031)
    if iNewTimes == 0 and iOldTimes > 0 then
        oPlayer.m_oTodayMorning:Set("xuanshang_accept_times", iOldTimes)
    end

    self:GS2CRefreshXuanShang()
end

function CXuanShangCtrl:OnUpGradeEnd(oPlayer, iFromGrade, iToGrade)
    if table_count(self.m_mTasks) == 0 and self:IsOpenXuanShang(oPlayer) then
        self:InitConfig()
        self:CheckTimeout()
        if table_count(self.m_mTasks) < SHOW_LIMIT then
            self:RefreshAllTask()
        end
        self:GS2CRefreshXuanShang()
    end
end

function CXuanShangCtrl:InitConfig()
    local lLimit = self:GetConfigLimit()
    if lLimit and lLimit[1] then
        MAX_TIMES = lLimit[1].max_times or MAX_TIMES
        COST_ITEM = lLimit[1].cost_item or COST_ITEM
        HELP_REWARD = lLimit[1].reward or HELP_REWARD
    end

    local mConfig = self:GetConfig()
    for _,mInfo in pairs(mConfig) do
        self.m_mConfigStarRadio[mInfo.id] = mInfo.ratio
    end
    self.m_lConfigTaskIds = self:GetConfigTaskIds()
end


function CXuanShangCtrl:OnLogout(iPid)
    local oPlayer = self:GetPlayer()
    oPlayer.m_oTaskCtrl:DelEvent(self, taskdefines.EVENT.DEL_TASK)
end

function CXuanShangCtrl:Release()
    for _, oInfo in pairs(self.m_mTasks) do
        if oInfo.task and oInfo.status == STATE.NOACCEPT then
            baseobj_safe_release(oInfo.task)
        end
    end
    self.m_mTasks = nil

    if self.m_oRewardMonitor then
        baseobj_safe_release(self.m_oRewardMonitor)
    end
    self.m_oRewardMonitor = nil

    super(CXuanShangCtrl).Release(self)
end

function CXuanShangCtrl:Save()
    local mTaskData = {}
    for iTaskId, oInfo in pairs(self.m_mTasks) do
        if oInfo.task then
            mTaskData[db_key(iTaskId)] = oInfo
        end
    end
    local mData = {
        tipflag = self.m_bTipFlag,
        tasks = mTaskData,
        dayno = self.m_iMorningDayNo,
    }
    return mData
end

function CXuanShangCtrl:Load(mData)
    if not mData then
        return
    end

    for sTaskId, oInfo in pairs(mData.tasks or {}) do
        local iTaskId = tonumber(sTaskId)
        if iTaskId then
            local oTask = global.oTaskLoader:CreateTask(iTaskId)
            if oTask then
                oTask:Load(oInfo.task)
                oInfo.task = oTask
                self.m_mTasks[iTaskId] = oInfo
            end
        end
    end

    local oPlayer = self:GetPlayer()
    if not oPlayer then return end
    local iCurMorningDayNo = get_morningdayno(get_time())
    if iCurMorningDayNo ~= mData.dayno and self:IsOpenXuanShang(oPlayer) then
        self:CheckTimeout()
        return
    end
    
    self.m_bTipFlag = mData.tipflag or false
    self.m_iMorningDayNo = mData.dayno or iCurMorningDayNo
end

function CXuanShangCtrl:GetStarFactor(iTaskId)
    local fFactor = 1 
    if self.m_mTasks[iTaskId] then
        local iStar = self.m_mTasks[iTaskId].star
        local mConfig = self:GetConfig()
        if iStar and mConfig[iStar] then
            fFactor = mConfig[iStar].factor / 100
        end
    end
    return fFactor
end

function CXuanShangCtrl:GetStar(iTaskId)
    if self.m_mTasks[iTaskId] then
        return self.m_mTasks[iTaskId].star
    end
    return 1
end

function CXuanShangCtrl:CreateOneTask()
    local iTaskId = self:CreateTaskId()
    if not iTaskId then return end
    local iStar = extend.Random.choosekey(self.m_mConfigStarRadio)

    local oTask = global.oTaskLoader:CreateTask(iTaskId)
    if oTask then
        local mData = {
            task = oTask,
            status = STATE.NOACCEPT,
            npcid = iTaskId,
            star = iStar,
        }
        self.m_mTasks[iTaskId] = mData
    end
end

function CXuanShangCtrl:CreateTaskId()
    local iNewTaksId
    if #self.m_lConfigTaskIds == 0 then
        self:InitConfig()
    end

    for i=1, #self.m_lConfigTaskIds do
        local iTaskId = extend.Random.random_choice(self.m_lConfigTaskIds)
        if not self.m_mTasks[iTaskId] then
            iNewTaksId = iTaskId
            break
        end
    end
    return iNewTaksId
end

function CXuanShangCtrl:RefreshAllTask()
    self:Dirty()
    local iTaskCnt = table_count(self.m_mTasks)
    if iTaskCnt == 0 then
        for i=1, SHOW_LIMIT do
            self:CreateOneTask()
        end
    else
        local oPlayer = self:GetPlayer()
        for iTaskId, oInfo in pairs(self.m_mTasks) do
            local iStatus = oInfo.status
            if iStatus == STATE.NOACCEPT or iStatus == STATE.DONE then
                self.m_mTasks[iTaskId] = nil
            end

            --防止报错不能刷新
            if oPlayer then
                local bHas = oPlayer.m_oTaskCtrl:HasTask(iTaskId)
                if iStatus == STATE.ACCEPTED and not bHas then
                    self.m_mTasks[iTaskId] = nil
                end
            end
        end

        iTaskCnt = table_count(self.m_mTasks)
        for i=1, SHOW_LIMIT-iTaskCnt do
            self:CreateOneTask()
        end
    end
end

function CXuanShangCtrl:OnNewHour5(oPlayer)
    if self.m_oRewardMonitor then
        self.m_oRewardMonitor:ClearRecordInfo()
    end
    self:CheckTimeout(true)
    self:GS2CRefreshXuanShang()
end

function CXuanShangCtrl:CheckTimeout(bIsNewDay)
    local iCurMorningDayNo = get_morningdayno(get_time())
    if bIsNewDay or self.m_iMorningDayNo ~= iCurMorningDayNo then
        self:RefreshAllTask()
        local oldDayNo = self.m_iMorningDayNo
        self.m_iMorningDayNo = iCurMorningDayNo
        self.m_bTipFlag = false

        local oPlayer = self:GetPlayer()
        if oPlayer then
            local mLogData = oPlayer:LogData()
            mLogData.old_dayno = oldDayNo or 0
            mLogData.new_dayno = iCurMorningDayNo or 0
            mLogData.taskids = table_key_list(self.m_mTasks)
            record.user("task", "new_xuanshang_task", mLogData)
        end
    end
end

function CXuanShangCtrl:TaskDone(oTask)
    local iTaskId = oTask:GetId()
    if self.m_mTasks[iTaskId] then
        self.m_mTasks[iTaskId].status = STATE.DONE
        self:GS2CRefreshXuanShangUnit(iTaskId)

        local oPlayer = self:GetPlayer()
        if oPlayer and oPlayer:HasTeam() and oPlayer:IsTeamLeader() then
            self:TeamOtherMemberReward(oPlayer, oTask)
        end

        if self:IsAllTaskDone() then
            self:RefreshAllTask()
            self:GS2CRefreshXuanShang()
        end
    end
end

function CXuanShangCtrl:IsAllTaskDone()
    for iTaskId, oInfo in pairs(self.m_mTasks) do
        if oInfo.status ~= STATE.DONE then
            return false
        end
    end
    return true
end

function CXuanShangCtrl:TeamOtherMemberReward(oPlayer, oTask)
    local lMember = oPlayer:GetTeamMember()
    local iPid = self:GetPid()
    for _, iMemPid in ipairs(lMember) do
        if iMemPid ~= iPid then
            local oMember = global.oWorldMgr:GetOnlinePlayerByPid(iMemPid)
            if oMember then
                oMember.m_oTaskCtrl.m_oXuanShangCtrl:TryHelpReward(oTask)
            end
        end
    end
end

function CXuanShangCtrl:TryHelpReward(oTask)
    local oPlayer = self:GetPlayer()  
    if not oPlayer then return end
    -- local bFlag = self.m_oRewardMonitor:CheckRewardGroup(self:GetPid(), HELP_REWARD, 1)
    local oRewardMonitor = global.oTaskMgr:GetTaskRewardMonitor()
    local mRecord = oRewardMonitor and oRewardMonitor.m_mRecord or {}
    local iTimes = table_get_depth(mRecord, {self:GetPid(), "xuanshang", tostring(HELP_REWARD)}) or 0
    local bFlag = iTimes < 10
    if bFlag then
        if oTask then
            local iPid = self:GetPid()
            oTask:Reward(iPid, HELP_REWARD, { team_member = true })
        end
    else
        local sMsg = self:GetTextData(900017)
        oPlayer:NotifyMessage(sMsg)
    end
end

function CXuanShangCtrl:CheckAcceptValid() 
    local oPlayer = self:GetPlayer()
    if not oPlayer then return end

    local oNotifyMgr = global.oNotifyMgr
    if not self:IsOpenXuanShang(oPlayer) then   
        local sMsg = self:GetTextData(900012)
        oPlayer:NotifyMessage(sMsg)
        return false
    end

    local iDoneTimes = oPlayer.m_oTodayMorning:Query("xuanshang_accept_times", 0)
    if iDoneTimes >= MAX_TIMES then
        local sMsg = self:GetTextData(900013)
        oPlayer:NotifyMessage(sMsg)
        return false
    end

    -- local iDoneTimes = oPlayer.m_oScheduleCtrl:GetDoneTimes(1031)
    -- if iDoneTimes >= MAX_TIMES then
    --     local sMsg = self:GetTextData(900013)
    --     oPlayer:NotifyMessage(sMsg)
    --     return false
    -- end
    
    local LIMIT_GRADE = res["daobiao"]["open"]["XUANSHANG"]["p_level"]
    if not oPlayer:IsSingle() and oPlayer:IsTeamLeader() then
        local lMemName = {}
        for _, iPid in ipairs(oPlayer:GetTeamMember()) do
            if iPid ~= oPlayer:GetPid() then
                local oMember = global.oWorldMgr:GetOnlinePlayerByPid(iPid)
                if oMember and oMember:GetGrade() < LIMIT_GRADE then
                    table.insert(lMemName, oMember:GetName())
                end
            end
        end

        if #lMemName > 0 then
            local sMsg = table.concat(lMemName, ",")
            sMsg = global.oToolMgr:FormatColorString(self:GetTextData(900014), {role = sMsg})
            oPlayer:NotifyMessage(sMsg)
            return false
        end
    end 
    return true
end

function CXuanShangCtrl:C2GSOpenXuanShangView()
    if not self:CheckAcceptValid() then
        return 
    end
    
    if table_count(self.m_mTasks) < SHOW_LIMIT then
        self:RefreshAllTask()
    end
    self:GS2CRefreshXuanShang()

    local oPlayer = self:GetPlayer()
    if oPlayer then
        oPlayer:Send("GS2COpenXuanShangView", {})
    end
end

function CXuanShangCtrl:GetAllTaskInfo()
    local lTasks = {}
    for iTaskId, oInfo in pairs(self.m_mTasks) do
        local mData = {
            taskid = iTaskId,
            npcid = oInfo.npcid,
            star = oInfo.star,
            status = oInfo.status
        }
        table.insert(lTasks, mData)
    end
    return lTasks
end

function CXuanShangCtrl:GS2CRefreshXuanShang(bOnlyCount)
    local oPlayer = self:GetPlayer()
    local mData = {
        count = oPlayer.m_oTodayMorning:Query("xuanshang_accept_times", 0)
    }
    if not bOnlyCount then
        mData.tasks = self:GetAllTaskInfo()
    end
    mData = net.Mask("GS2CRefreshXuanShang", mData)
    oPlayer:Send("GS2CRefreshXuanShang", mData)
end

function CXuanShangCtrl:GS2CRefreshXuanShangUnit(iTaskId)
    local oInfo= self.m_mTasks[iTaskId]
    if not oInfo then return end

    local mData = {
        taskid = iTaskId,
        npcid = oInfo.npcid,
        star = oInfo.star,
        status = oInfo.status,
    }
    local oPlayer = self:GetPlayer()
    if oPlayer then
        oPlayer:Send("GS2CRefreshXuanShangUnit", { task = mData })
    end
end

function CXuanShangCtrl:C2GSAcceptXuanShangTask(oPlayer, iTaskId)
    for iTaksId, oInfo in pairs(self.m_mTasks) do
        if oInfo.status == STATE.ACCEPTED then
            local sMsg = self:GetTextData(900016)
            oPlayer:NotifyMessage(sMsg)
            return
        end
    end

    local oInfo= self.m_mTasks[iTaskId]
    if not oInfo then return end
    local iStatus = oInfo.status
    if oInfo.task and iStatus == STATE.NOACCEPT then
        local bSuc = oPlayer.m_oTaskCtrl:AddTask(oInfo.task)
        if bSuc then
            self:Dirty()
            oPlayer.m_oTodayMorning:Add("xuanshang_accept_times", 1)
            self.m_mTasks[iTaskId].status = STATE.ACCEPTED            
            self:GS2CRefreshXuanShangUnit(iTaskId)
            self:GS2CRefreshXuanShang(true)
        end
    end
end

--刷新怪物
function CXuanShangCtrl:C2GSRefreshXuanShang(oPlayer, iFastBuy)
    local iDoneTimes = oPlayer.m_oScheduleCtrl:GetDoneTimes(1031)
    if iDoneTimes >= MAX_TIMES then
        local sMsg = self:GetTextData(900013)
        oPlayer:NotifyMessage(sMsg)
        return
    end

    if not self.m_bTipFlag and self:CheckFourFiveStarTask() then
        oPlayer:Send("GS2CXuanShangStarTip", {})
        return
    end

    if iFastBuy and iFastBuy > 0 then
        local mCost = {item = {[COST_ITEM] = 1}}
        local bSucc, mLogCost = global.oFastBuyMgr:FastBuy(oPlayer, mCost, "快捷刷新悬赏", {cancel_tip = false})
        if not bSucc then return end
    else
        if oPlayer:GetItemAmount(COST_ITEM) < 1 then
            local sMsg = self:GetTextData(900015)
            oPlayer:NotifyMessage(sMsg)
            return
        end

        if not oPlayer:RemoveItemAmount(COST_ITEM, 1, "悬赏任务") then
            return
        end
    end


    self:RefreshAllTask()
    self:GS2CRefreshXuanShang()
end

function CXuanShangCtrl:CheckFourFiveStarTask(oPlayer)
    for iTaskId, oInfo in pairs(self.m_mTasks) do
        local iStatus = oInfo.status
        if iStatus == STATE.NOACCEPT and oInfo.star >= 4  then
            return true
        end
    end
    return false
end

function CXuanShangCtrl:C2GSXuanShangStarTip(oPlayer, iConfirm, iTipFlag, iFastBuy)
    self.m_bTipFlag = iTipFlag == 1
    if iConfirm == 1 then
        if iFastBuy and iFastBuy > 0 then
            local mCost = {item = {[COST_ITEM] = 1}}
            local bSucc, mLogCost = global.oFastBuyMgr:FastBuy(oPlayer, mCost, "快捷刷新悬赏", {cancel_tip = false})
            if not bSucc then return end
        elseif not oPlayer:RemoveItemAmount(COST_ITEM, 1, "悬赏任务") then
            local sMsg = self:GetTextData(900015)
            oPlayer:NotifyMessage(sMsg)
            return
        end

        self:RefreshAllTask()
        self:GS2CRefreshXuanShang()
    end
end

function CXuanShangCtrl:AbandonTask(oPlayer, oTask)
    local iTaskId = oTask:GetId()
    local oInfo= self.m_mTasks[iTaskId]
    if not oInfo then return end
    local iStatus = oInfo.status
    if oInfo.task and iStatus == STATE.ACCEPTED and oInfo.star then
        self:Dirty()
        local iStar = oInfo.star
        local oTask = global.oTaskLoader:CreateTask(iTaskId)
        if oTask then
            local mData = {
                task = oTask,
                status = STATE.NOACCEPT,
                npcid = iTaskId,
                star = iStar,
            }
            self.m_mTasks[iTaskId] = mData
            self:GS2CRefreshXuanShangUnit(iTaskId)
        end
    end
end

function CXuanShangCtrl:GetTextData(iText)
    return global.oToolMgr:GetTextData(iText, {"task_ext"})
end

function CXuanShangCtrl:GetConfig()
    return table_get_depth(res, {"daobiao", "xuanshang_config"})
end

function CXuanShangCtrl:GetConfigLimit()
    return table_get_depth(res, {"daobiao", "xuanshang_limit"})
end

function CXuanShangCtrl:GetConfigTaskIds()
    local mData = table_get_depth(res, {"daobiao", "task", "xuanshang", "task"})
    local lIds = table_key_list(mData)
    return lIds
end

function CXuanShangCtrl:IsOpenXuanShang(oPlayer)
    return global.oToolMgr:IsSysOpen("XUANSHANG", oPlayer, true)
end

function CXuanShangCtrl:TestOp(oMaster, oPlayer, sCmd, mArgs)
    local iPid = oMaster:GetPid()
    if sCmd == 100 then
        for iTaskId, oInfo in pairs(self.m_mTasks) do
            if oInfo.task and oInfo.status == STATE.ACCEPTED then
                self.m_mTasks[iTaskId].status = STATE.ACCEPTED            
                oPlayer.m_oTaskCtrl:RemoveTask(oInfo.task)
            end
        end
        self.m_mTasks = {}
        global.oNotifyMgr:Notify(iPid, "清空任务")
    elseif sCmd == 101 then
        self.m_mTasks = {}
        global.oNotifyMgr:Notify(iPid, "清空任务")
    elseif sCmd == 102 then
        local iTaskId = mArgs.task
        local iStar = mArgs.star

        if not iTaskId or not iStar then
            global.oNotifyMgr:Notify(iPid, "参数错误")
            return
        end

        if #self.m_lConfigTaskIds == 0 then
            self:InitConfig()
        end

        local isHave = false
        for _, id in ipairs(self.m_lConfigTaskIds) do
            if id == iTaskId then
                isHave = true
                break
            end
        end

        if not isHave then
            global.oNotifyMgr:Notify(iPid, "没有该任务")
            return
        end

        if iStar < 0 or iStar > 5 then
            global.oNotifyMgr:Notify(iPid, "星级错误，星级1-5星")
            return
        end

        local mTaskInfo = self.m_mTasks[iTaskId]
        if mTaskInfo and mTaskInfo.star == iStar and mTaskInfo.status ~= STATE.DONE then
            global.oNotifyMgr:Notify(iPid, "已经有该任务了")
            return
        end

        local iTaskCnt = table_count(self.m_mTasks)
        if iTaskCnt == 0 then
            self:RefreshAllTask()
        else
            for iId, oInfo in pairs(self.m_mTasks) do
                local iStatus = oInfo.status
                if iStatus == STATE.NOACCEPT or iStatus == STATE.DONE then
                    self.m_mTasks[iId] = nil
                end
            end

            iTaskCnt = table_count(self.m_mTasks)
            for i=1, SHOW_LIMIT-iTaskCnt do
                if i == 1 then
                    local oTask = global.oTaskLoader:CreateTask(iTaskId)
                    if oTask then
                        local mData = {
                            task = oTask,
                            status = STATE.NOACCEPT,
                            npcid = iTaskId,
                            star = iStar,
                        }
                        self.m_mTasks[iTaskId] = mData
                    end
                else
                    self:CreateOneTask()
                end
            end
        end
        self:GS2CRefreshXuanShang()
        global.oNotifyMgr:Notify(iPid, "悬赏刷新")
    end
end
