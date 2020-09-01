local skynet = require "skynet"
local global = require "global"
local res = require "base.res"
local record = require "public.record"
local gamedefines = import(lualib_path("public.gamedefines"))
local taskdefines = import(service_path("task/taskdefines"))

function NewRunRingMgr(...)
    return CRunRingMgr:New()
end

CRunRingMgr = {}
CRunRingMgr.__index = CRunRingMgr
CRunRingMgr.m_iScheduleID = 1030
inherit(CRunRingMgr, logic_base_cls())

function CRunRingMgr:New()
    local o = super(CRunRingMgr).New(self)
    return o
end

function CRunRingMgr:GetGlobalConfig(sKey, rDefault)
    return table_get_depth(res, {"daobiao", "task", "runring", "global_config", sKey}) or rDefault
end

function CRunRingMgr:IsSysOpen(oPlayer)
    if not global.oToolMgr:IsSysOpen("RUNRING") then
        return false
    end
    local iGrade = oPlayer:GetGrade()
    local iOpenGradeLower = global.oToolMgr:GetSysOpenPlayerGrade("RUNRING")
    if iGrade < iOpenGradeLower then
        local sMsg = global.oToolMgr:GetTextData(63025, {"task_ext"})
        sMsg = global.oToolMgr:FormatColorString(sMsg, {
            grade = iOpenGradeLower,
        })
        oPlayer:NotifyMessage(sMsg)
        return false
    end
    local sOpenGradeUpper = self:GetGlobalConfig("open_grade_upper")
    if sOpenGradeUpper and #sOpenGradeUpper > 0 then
        local iServerGrade = oPlayer:GetServerGrade()
        local iOpenGradeUpper = formula_string(sOpenGradeUpper, {SLV = iServerGrade})
        if iGrade > iOpenGradeUpper then
            local sMsg = global.oToolMgr:GetTextData(63026, {"task_ext"})
            oPlayer:NotifyMessage(sMsg)
            return false
        end
    end
    return true
end

function CRunRingMgr:CurRing(oPlayer)
    -- return oPlayer.m_oWeekMorning:Query("runring_ring", 0)
    return oPlayer.m_oTaskCtrl:GetData("runring_ring", 0)
end

function CRunRingMgr:SetRing(oPlayer, iRing)
    return oPlayer.m_oTaskCtrl:SetData("runring_ring", iRing)
end

function CRunRingMgr:IncreaseRing(oPlayer)
    return self:SetRing(oPlayer, self:CurRing(oPlayer) + 1)
end

function CRunRingMgr:DefaultGrantNpc()
    return self:GetGlobalConfig("grant_npc", 0)
end

function CRunRingMgr:AccpetTimes(oPlayer)
    return oPlayer.m_oWeekMorning:Query("runring_accept_times", 0)
end

function CRunRingMgr:SetAccpetTimes(oPlayer, iTimes)
    oPlayer.m_oWeekMorning:Set("runring_accept_times", iTimes)
    oPlayer.m_oScheduleCtrl:RefreshMaxTimes(self.m_iScheduleID)
end

function CRunRingMgr:RecAccpetTimes(oPlayer)
    local iCur = oPlayer.m_oWeekMorning:Add("runring_accept_times", 1)
    oPlayer.m_oScheduleCtrl:RefreshMaxTimes(self.m_iScheduleID)
    return iCur
end

function CRunRingMgr:MaxRing()
    return self:GetGlobalConfig("max_ring" or 0)
end

function CRunRingMgr:MaxWeekAcceptTimes()
    return self:GetGlobalConfig("week_accept_times" or 0)
end

function CRunRingMgr:LeftAcceptTimes(oPlayer)
    return self:MaxWeekAcceptTimes() - self:AccpetTimes(oPlayer)
end

function CRunRingMgr:HasAcceptTimes(oPlayer)
    return self:LeftAcceptTimes(oPlayer) > 0
end

function CRunRingMgr:AcceptWeek(oPlayer, oGrantNpc)
    if not self:HasAcceptTimes(oPlayer) then
        oPlayer:NotifyMessage("本周领取次数用完")
        return
    end
    local npcid = oGrantNpc:ID()
    self:ConfirmPayForAccept(oPlayer, npcid)
end

function CRunRingMgr:OnAnswerSkipFight(oPlayer, mData, iGoldcoin, iTaskId, iNpcid)
    if mData.answer == 1 then
        -- 不足自动弹充值界面
        if not oPlayer:ValidMoneyByType(gamedefines.MONEY_TYPE.GOLDCOIN, iGoldcoin) then
            return
        end
        local oTask = global.oTaskMgr:GetUserTask(oPlayer, iTaskId, true)
        if oTask then
            oTask:SkipTaskWithGoldcoin(oPlayer, iGoldcoin, iNpcid)
        end
    end
end

function CRunRingMgr:OnDoneShopBuy(oPlayer, mData, iOwner, iTaskId)
    if mData.answer ~= 1 then
        return
    end
    local oOwner
    if iOwner == oPlayer:GetPid() then
        oOwner = oPlayer
    else
        oOwner = global.oWorldMgr:GetOnlinePlayerByPid(iOwner)
    end
    if not oOwner then
        return
    end
    local oTask = global.oTaskMgr:GetUserTask(oOwner, iTaskId, true)
    if oTask then
        oTask:TrySubmit(oOwner)
    end
end

function CRunRingMgr:ConfirmPayForAccept(oPlayer, npcid)
    local mNet = global.oToolMgr:GetTextData(63027, {"task_ext"})
    local sAcceptSilverCost = self:GetGlobalConfig("accept_silver_cost", "0")
    local iServerGrade = oPlayer:GetServerGrade()
    local iCostSilver = formula_string(sAcceptSilverCost, {SLV = iServerGrade})
    if iCostSilver <= 0 then
        self:DealAcceptWeek(oPlayer, npcid)
        return
    end
    mNet.sContent = global.oToolMgr:FormatColorString(mNet.sContent, {
        silver = iCostSilver,
        max_ring = self:MaxRing(),
    })
    global.oCbMgr:SetCallBack(oPlayer:GetPid(), "GS2CConfirmUI", mNet, nil, function(oPlayer, mData)
        global.oRunRingMgr:PayForAccept(oPlayer, mData, iCostSilver, npcid)
    end)
end

function CRunRingMgr:PayForAccept(oPlayer, mData, iCostSilver, npcid)
    if mData.answer == 1 then
        if not oPlayer:ValidMoneyByType(gamedefines.MONEY_TYPE.SILVER, iCostSilver) then
            return
        end
        oPlayer:ResumeMoneyByType(gamedefines.MONEY_TYPE.SILVER, iCostSilver, "runring accept")
        self:DealAcceptWeek(oPlayer, npcid)
    end
end

function CRunRingMgr:DealAcceptWeek(oPlayer, npcid)
    local oGrantNpc = global.oNpcMgr:GetObject(npcid)
    self:RecAccpetTimes(oPlayer)
    self:AcceptTask(oPlayer, oGrantNpc)
end

function CRunRingMgr:AcceptTask(oPlayer, oGrantNpc)
    oPlayer.m_oTaskCtrl:SetData("runring_ring", nil)
    self:GoOnRing(oPlayer, oGrantNpc)
end

function CRunRingMgr:TryAskForAcceptNewRound(oPlayer)
    local iLeftAcceptTimes = self:LeftAcceptTimes(oPlayer)
    if iLeftAcceptTimes <= 0 then
        return
    end
    local mNet = global.oToolMgr:GetTextData(63030, {"task_ext"})
    mNet.sContent = global.oToolMgr:FormatColorString(mNet.sContent, {
        amount = iLeftAcceptTimes,
    })
    global.oCbMgr:SetCallBack(oPlayer:GetPid(), "GS2CConfirmUI", mNet, nil, function(oPlayer, mData)
        global.oRunRingMgr:PathToGrantNpc(oPlayer, mData)
    end)
end

function CRunRingMgr:PathToGrantNpc(oPlayer, mData)
    if mData.answer ~= 1 then
        return
    end
    local pid = oPlayer:GetPid()
    local npctype = self:GetGlobalConfig("grant_npc", 0)
    local oNpc = global.oNpcMgr:GetGlobalNpc(npctype)
    local iMap = oNpc:MapId()
    local mPosInfo = oNpc:PosInfo()
    local mNet = {
        map_id = iMap,
        pos_x = mPosInfo.x,
        pos_y = mPosInfo.y,
        autotype = 1,
    }
    local fCbFunc = function()
        global.oRunRingMgr:OnPathDoneToClickNpc(pid, npctype)
    end
    global.oCbMgr:SetCallBack(pid, "AutoFindPath", mNet, nil, fCbFunc)
end

function CRunRingMgr:OnPathDoneToClickNpc(pid, npctype)
    local oNpc = global.oNpcMgr:GetGlobalNpc(npctype)
    local oPlayer = global.oWorldMgr:GetOnlinePlayerByPid(pid)
    if oPlayer then
        oNpc:do_look(oPlayer)
    end
end

function CRunRingMgr:GoOnRing(oPlayer, oGrantNpc, bNoAuto)
    local iRing = self:CurRing(oPlayer)
    if iRing >= self:MaxRing() then
        self:TryAskForAcceptNewRound(oPlayer)
        return
    end
    local iTaskType = self:SelectTaskType(iRing + 1)
    if not iTaskType then
        return
    end
    local iTaskId = self:SelectTaskByType(iTaskType)
    if not iTaskId then
        return
    end
    self:GiveTask(oPlayer, iTaskId, oGrantNpc, bNoAuto)
end

-- 任务自动流程中剧情依然挂载着（自动点任务不等剧情结束）
-- 策划可能会轻易调整这个设置
function CRunRingMgr:IsAutoTaskWithPlot()
    return true
end

function CRunRingMgr:GiveTask(oPlayer, iTaskId, oGrantNpc, bNoAuto)
    local oTask = global.oTaskLoader:CreateTask(iTaskId)
    if not oTask then
        return false
    end
    local iRing = self:IncreaseRing(oPlayer)
    if not oGrantNpc then
        record.warning("runring task got no grantnpc, pid:%d, ring:%d, taskid:%d", oPlayer:GetPid(), iRing, iTaskId)
        local iGrantNpctype = self:DefaultGrantNpc()
        oGrantNpc = global.oNpcMgr:GetGlobalNpc(iGrantNpctype)
    end
    oTask:SetData("no_autostart", bNoAuto)
    oPlayer:AddTask(oTask, oGrantNpc)

    if self:IsAutoTaskWithPlot() then
        -- 自动开始流程
        if not bNoAuto then
            oTask:TrySubmit(oPlayer)
        end
    end
end

function CRunRingMgr:SelectTaskByType(iTaskType)
    return table_get_depth(res, {"daobiao", "task", "runring", "type_tasks", iTaskType, "taskid"})
end

function CRunRingMgr:SelectTaskType(iRing)
    local iRingGroup = self:GetRingGroup(iRing)
    if not iRingGroup then
        return nil
    end
    local mRingRatioData = table_get_depth(res, {"daobiao", "task", "runring", "ring_accept_ratio", iRingGroup, "accept_task_ratio"})
    if not mRingRatioData then
        return nil
    end
    return table_choose_key(mRingRatioData)
end

function CRunRingMgr:GetRingGroup(iRing)
    local mRingGroupData = table_get_depth(res, {"daobiao", "task", "runring", "ring_accept_ratio"})
    for iRingGroup, mData in pairs(mRingGroupData) do
        if iRing >= mData.ring_lower and iRing <= mData.ring_upper then
            return iRingGroup
        end
    end
end

function CRunRingMgr:TryNotifyRewardFightHelpFull(oPlayer)
    if not self:CanRewardFightHelp(oPlayer) then
        local sMsg = global.oToolMgr:GetTextData(63034, {"task_ext"})
        oPlayer:NotifyMessage(sMsg)
    end
end

function CRunRingMgr:CanRewardFightHelp(oPlayer)
    return self:GetRewardFightHelp(oPlayer) < self:GetGlobalConfig("week_rwd_help_fight_times", 0)
end

function CRunRingMgr:RecRewardFightHelp(oPlayer)
    oPlayer.m_oWeekMorning:Add("runring_rwd_help_fight_times", 1)
end

function CRunRingMgr:GetRewardFightHelp(oPlayer)
    return oPlayer.m_oWeekMorning:Query("runring_rwd_help_fight_times", 0)
end

function CRunRingMgr:SetRewardFightHelp(oPlayer, iTimes)
    oPlayer.m_oWeekMorning:Set("runring_rwd_help_fight_times", iTimes)
end

-- function CRunRingMgr:RecCallFightHelp(oPlayer)
--     oPlayer.m_oWeekMorning:Add("runring_call_help_fight_times", 1)
-- end

function CRunRingMgr:CanCallItemHelp(oPlayer)
    return self:GetCallItemHelp(oPlayer) < self:GetGlobalConfig("week_call_help_item_times", 0)
end

function CRunRingMgr:RecCallItemHelp(oPlayer)
    oPlayer.m_oWeekMorning:Add("runring_call_help_item_times", 1)
end

function CRunRingMgr:GetCallItemHelp(oPlayer)
    return oPlayer.m_oWeekMorning:Query("runring_call_help_item_times", 0)
end

function CRunRingMgr:SetCallItemHelp(oPlayer, iTimes)
    oPlayer.m_oWeekMorning:Set("runring_call_help_item_times", iTimes)
end

function CRunRingMgr:CanGiveItemHelp(oPlayer)
    return self:GetGiveItemHelp(oPlayer) < self:GetGlobalConfig("week_help_item_times", 0)
end

function CRunRingMgr:RecGiveItemHelp(oPlayer)
    oPlayer.m_oWeekMorning:Add("runring_give_help_item_times", 1)
end

function CRunRingMgr:GetGiveItemHelp(oPlayer)
    return oPlayer.m_oWeekMorning:Query("runring_give_help_item_times", 0)
end

function CRunRingMgr:SetGiveItemHelp(oPlayer, iTimes)
    oPlayer.m_oWeekMorning:Set("runring_give_help_item_times", iTimes)
end

function CRunRingMgr:HelpGiveSubmitTask(oPlayer, iTarget, iTaskId, iCreateWeekNo, iRing, bSkipClickCheck)
    if oPlayer:GetPid() == iTarget then
        local sMsg = global.oToolMgr:GetTextData(63010, {"task_ext"})
        oPlayer:NotifyMessage(sMsg)
        return
    end
    local oTarget = global.oWorldMgr:GetOnlinePlayerByPid(iTarget)
    if not oTarget then
        local sMsg = global.oToolMgr:GetTextData(63009, {"task_ext"})
        oPlayer:NotifyMessage(sMsg)
        return
    end
    local oTask = global.oTaskMgr:GetUserTask(oTarget, iTaskId, true)
    if not oTask then
        local sMsg = global.oToolMgr:GetTextData(63008, {"task_ext"})
        oPlayer:NotifyMessage(sMsg)
        return
    end
    if not self:CheckCanGiveItemHelp(oPlayer) then
        return
    end
    oTask:OnGiveHelp(oPlayer, iCreateWeekNo, iRing, bSkipClickCheck)
end

function CRunRingMgr:CheckCanGiveItemHelp(oPlayer)
    if not self:CanGiveItemHelp(oPlayer) then
        local iMaxGiveHelpTimes = self:GetGlobalConfig("week_help_item_times", 0)
        local sMsg = global.oToolMgr:GetTextData(63029, {"task_ext"})
        sMsg = global.oToolMgr:FormatColorString(sMsg, {
            amount = iMaxGiveHelpTimes,
        })
        oPlayer:NotifyMessage(sMsg)
        return false
    end
    return true
end

function CRunRingMgr:OnGiveHelpBuyCallback(oPlayer, mData, iTarget, iTaskId, iCreateWeekNo, iRing)
    if mData.answer == 1 then
        self:HelpGiveSubmitTask(oPlayer, iTarget, iTaskId, iCreateWeekNo, iRing, true)
        return
    end
end

function CRunRingMgr:OnGiveItemHelpCallback(oPlayer, mData, iTarget, iTaskId, iCreateWeekNo, iRing)
    local oTarget = global.oWorldMgr:GetOnlinePlayerByPid(iTarget)
    if not oTarget then
        local sMsg = global.oToolMgr:GetTextData(63009, {"task_ext"})
        oPlayer:NotifyMessage(sMsg)
        return
    end
    local oTask = global.oTaskMgr:GetUserTask(oTarget, iTaskId, true)
    if not oTask then
        local sMsg = global.oToolMgr:GetTextData(63008, {"task_ext"})
        oPlayer:NotifyMessage(sMsg)
        return
    end
    oTask:OnHelpTakeItemUICallback(oPlayer, mData, iCreateWeekNo, iRing)
end

function CRunRingMgr:HasTask(oPlayer)
    for iTaskId, oTask in pairs(oPlayer.m_oTaskCtrl:TaskList()) do
        if oTask:Type() == taskdefines.TASK_KIND.RUNRING then
            return oTask
        end
    end
end


--test op-----------------------------------------------
local mCmdFuncs = {
    ["reset_acc"] = function(oMaster, oPlayer, mArgs)
        global.oRunRingMgr:SetAccpetTimes(oPlayer, nil)
        oMaster:NotifyMessage("已重置")
    end,
    ["set_acc"] = function(oMaster, oPlayer, mArgs)
        local iTimes = mArgs and mArgs.time
        if not iTimes then
            oMaster:NotifyMessage("需参数{time=1}")
            return
        end
        global.oRunRingMgr:SetAccpetTimes(oPlayer, iTimes)
        oMaster:NotifyMessage("已设为:" .. iTimes or 0)
    end,
    ["set_ring"] = function(oMaster, oPlayer, mArgs)
        local iRing = mArgs and mArgs.ring
        if not iRing then
            oMaster:NotifyMessage("需参数{ring=100}")
            return
        end
        global.oRunRingMgr:SetRing(oPlayer, iRing)
        local oTask = global.oRunRingMgr:HasTask(oPlayer)
        if oTask then
            oTask:SetRing()
            oTask:Refresh()
        end
        oMaster:NotifyMessage("已设为:" .. iRing or 0)
    end,
    ["get_times"] = function(oMaster, oPlayer, mArgs)
        local mSetter = {
            call_item_help = "GetCallItemHelp",
            give_item_help = "GetGiveItemHelp",
            rwd_fight_help = "GetRewardFightHelp",
            accept_times = "AccpetTimes",
        }
        local mRet = {}
        for sKey, sFunc in pairs(mSetter) do
            local iTimes = global.oRunRingMgr[sFunc](global.oRunRingMgr, oPlayer, iCallItemHelpTimes)
            mRet[sKey] = iTimes
        end
        if not next(mRet) then
            oMaster:NotifyMessage("无取值，使用key：" .. table.concat(table_key_list(mSetter), ","))
            return
        else
            oMaster:NotifyMessage("取值结果：" .. serialize_table(mRet))
        end
    end,
    ["set_times"] = function(oMaster, oPlayer, mArgs)
        mArgs = mArgs or {}
        local mSetter = {
            call_item_help = "SetCallItemHelp",
            give_item_help = "SetGiveItemHelp",
            rwd_fight_help = "SetRewardFightHelp",
            accept_times = "SetAccpetTimes",
        }
        local bCalled = false
        for sKey, sFunc in pairs(mSetter) do
            local iTimes = mArgs[sKey]
            if iTimes then
                global.oRunRingMgr[sFunc](global.oRunRingMgr, oPlayer, iTimes)
                bCalled = true
            end
        end
        if not bCalled then
            oMaster:NotifyMessage("无设值，使用key：" .. table.concat(table_key_list(mSetter), ","))
            return
        else
            oMaster:NotifyMessage("设值完成")
        end
    end,
}

function CRunRingMgr:TestOp(oMaster, oPlayer, sCmd, mArgs)
    sCmd = sCmd or ""
    local func = mCmdFuncs[sCmd]
    if not func then
        oMaster:NotifyMessage(string.format("空指令\n全函数如下:\n%s", table.concat(table_key_list(mCmdFuncs), ",\n")))
        return
    end
    func(oMaster, oPlayer, mArgs)
end
