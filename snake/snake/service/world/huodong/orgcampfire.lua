--import module
local global  = require "global"
local extend = require "base.extend"
local res = require "base.res"
local net = require "base.net"
local interactive = require "base.interactive"
local record = require "public.record"

local gamedefines = import(lualib_path("public.gamedefines"))
local orgdefines = import(service_path("org.orgdefines"))
local huodongbase = import(service_path("huodong.huodongbase"))
local analy = import(lualib_path("public.dataanaly"))

local EXP_TICK_PREIOD = 15
local MAX_EXP_TICK_USER_CNT = 150
local MAX_BUFF_ADDS = 250
local GIFTABLE_PLAYER_CNT = 20
local GIFTABLE_PLAYER_CNT_MAX = 100
local CHOICE_CNT = 4

local QUESTION_TYPE = {
    UNDEFINED = 0,
    FIXED_CHOICE = 1,
    CUSTOM_CHOICE = 2,
    FILL_IN = 3,
}
local QUESTION_STATUS = {
    READY = 1,
    START = 2,
    END = 3,
}

local ERR = {
    HUODONG_STOPED = 1,
    NOT_HUODONG_USER = 2,
    -- 喝酒
    FULLED = 101,
    LACK_GOLD_COIN = 102,
    NO_ORG = 103,
    OVER_AMOUNT = 104,
    OVER_PERSON_LIMIT = 105,
    -- 情意结
    TARGET_OFFLINE = 201,
    OVER_GIVE_LIMIT = 202,
    OVER_RECEIVE_LIMIT = 203,
    TARGET_NOT_HUODONG_USER = 204,
    NO_TIE_ITEM = 205,
    DIFF_ORG = 206,
    TARGET_SELF = 207,
}


function GetTextData(iText)
    local oToolMgr = global.oToolMgr
    return oToolMgr:GetTextData(iText, {"huodong", "orgcampfire"})
end

function GetLibData(sTName)
    return table_get_depth(res, {"daobiao", "huodong", "orgcampfire", "question", sTName}) or {}
end

function GetHuodongConfig(sKey)
    return table_get_depth(res, {"daobiao", "huodong", "orgcampfire", "global_config", sKey})
end

function IsPlayerOrgScene(oPlayer, oScene)
    local oOrg = oPlayer:GetOrg()
    if not oOrg then
        return false
    end
    local iOrgSceneId = oOrg:GetOrgSceneID()
    local iSceneId = oScene:GetSceneId()
    return iSceneId == iOrgSceneId
end

function GetHuodong()
    local oHuodongMgr = global.oHuodongMgr
    return oHuodongMgr:GetHuodong("orgcampfire")
end

function NewHuodong(sHuodongName)
    return CHuodong:New(sHuodongName)
end

function NewChoiceQuestion(iQid, mQInfo)
    local o = CChoiceQuestion:New()
    o:Init(iQid, mQInfo)
    return o
end

function NewCustomChoiceQuestion(iQid, mQInfo, oBenchQuestion)
    local o = CCustomChoiceQuestion:New()
    o:Init(iQid, mQInfo)
    o:SetBench(oBenchQuestion)
    return o
end

function NewFillinQuestion(iQid, mQInfo)
    local o = CFillinQuestion:New()
    o:Init(iQid, mQInfo)
    return o
end


----------------------------------------------

CHuodong = {}
CHuodong.__index = CHuodong
CHuodong.m_sTempName = "帮派篝火"
inherit(CHuodong, huodongbase.CHuodong)

function CHuodong:New(sHuodongName)
    local o = super(CHuodong).New(self, sHuodongName)
    o.m_sName = sHuodongName
    o.m_iScheduleID = 1018
    o.m_mAccessableUsers = {} -- 可参与活动玩家
    o.m_iStartTime = nil
    return o
end

function CHuodong:IsOpenDay(iTime)
    return true
end

function _DoAsyncBatch(sBatchName, iTickPeriod, fTickable, fDeal)
    local oHuodong = GetHuodong()
    oHuodong:DelTimeCb(sBatchName)
    if fTickable() then
        oHuodong:AddTimeCb(sBatchName, iTickPeriod, function()
            _DoAsyncBatch(sBatchName, iTickPeriod, fTickable, fDeal)
        end)
        fDeal()
    end
end

function CHuodong:StopBatch(sBatchName)
    self:DelTimeCb(sBatchName)
end

function CHuodong:HasBatch(sBatchName)
    return self:GetTimeCb(sBatchName)
end

function CHuodong:AsyncBatch(sBatchName, iTickPeriod, fTickable, fDeal)
    _DoAsyncBatch(sBatchName, iTickPeriod, fTickable, fDeal)
end

function CHuodong:ResetStartTime()
    local lStartTimepoint = GetHuodongConfig("start_timepoint")
    local iStartHour = lStartTimepoint[1] or 0
    local iStartMin = lStartTimepoint[2] or 0
    local iStartTimestampe = self:AnalyseTodayTime(iStartHour, iStartMin)
    local iPrepareSec = GetHuodongConfig("prepare_sec") or 0
    local iOpendTimestampe = iStartTimestampe + iPrepareSec
    return iStartTimestampe, iOpendTimestampe
end

function CHuodong:GetStartTime()
    -- return super(CHuodong).GetStartTime(self)
    local iStartTimestampe, iOpendTimestampe = self:ResetStartTime()
    self.m_iStartTime = iOpendTimestampe
    return get_time_format_str(self.m_iStartTime, "%H:%M")
    -- local iReadySec = GetHuodongConfig("ready_sec") or 0
    -- local iCalcOpenSec = iStartMin * 60 + (iPrepareSec or 0) -- + (iReadySec or 0)
    -- local iCalcOpenHour = (iStartHour + iCalcOpenSec // 3600) % 24
    -- local iCalcOpenMin = iCalcOpenSec % 3600 // 60
    -- return string.format("%02d:%02d", iCalcOpenHour, iCalcOpenMin)
end

function CHuodong:NewDay(mNow)
    self.m_iStartTime = nil
end

function CHuodong:Init()
    super(CHuodong).Init(self)

    if self.m_oQuestionMgr then
        baseobj_delay_release(self.m_oQuestionMgr)
    end
    self.m_oQuestionMgr = CQuestionMgr:New()
    if self.m_oCampfireMgr then
        baseobj_delay_release(self.m_oCampfireMgr)
    end
    self.m_oCampfireMgr = CCampfireMgr:New()
    if self.m_oDrinkMgr then
        baseobj_delay_release(self.m_oDrinkMgr)
    end
    self.m_oDrinkMgr = CDrinkMgr:New()
    if self.m_oTieMgr then
        baseobj_delay_release(self.m_oTieMgr)
    end
    self.m_oTieMgr = CTieMgr:New()
    if self.m_oSender then
        baseobj_delay_release(self.m_oSender)
    end
    self.m_oSender = CSender:New()

    self.m_iState = gamedefines.ACTIVITY_STATE.STATE_END
end

function CHuodong:OnServerStartEnd()
    -- self:InitOnlinePlayersAccessable()
    -- TODO 判断当前时间，是否立刻SetupRun/设置日程状态
    -- if self:IsOpenDay() then
    --     self:NotifyScheduleState(gamedefines.ACTIVITY_STATE.STATE_READY)
    -- end
    self:CheckWillOpen()
end

function CHuodong:Release()
    baseobj_safe_release(self.m_oQuestionMgr)
    self.m_oQuestionMgr = nil
    baseobj_safe_release(self.m_oCampfireMgr)
    self.m_oCampfireMgr = nil
    baseobj_safe_release(self.m_oDrinkMgr)
    self.m_oDrinkMgr = nil
    baseobj_safe_release(self.m_oTieMgr)
    self.m_oTieMgr = nil
    baseobj_safe_release(self.m_oSender)
    self.m_oSender = nil
    super(CHuodong).Release(self)
end

-- function CHuodong:InitOnlinePlayersAccessable()
--     local mOnlines = global.oWorldMgr:GetOnlinePlayerList()
--     for pid, oPlayer in pairs(mOnlines) do
--         self:TouchAccessability(oPlayer)
--     end
-- end

-- function CHuodong:TouchAccessability(oPlayer)
--     if oPlayer:GetGrade() < MIN_ABLE_HUODONG_GRADE then
--         return false
--     end
--     self.m_mAccessableUsers[oPlayer:GetPid()] = true
--     return true
-- end

function CHuodong:RunReady(iReadySec, iOpenSec)
    self:DelTimeCb("to_ready")
    self.m_iReadyEndTime = get_time() + iReadySec
    self:ReadyOpen()
    if iReadySec <= 0 then
        self:RunOpen(iOpenSec)
    else
        self:DelTimeCb("to_open")
        self:AddTimeCb("to_open", (iReadySec) * 1000, function()
            local oHuodong = GetHuodong()
            oHuodong:RunOpen(iOpenSec)
        end)
    end
end

function CHuodong:RunOpen(iOpenSec)
    self:DelTimeCb("to_open")
    self:Open()
    if iOpenSec <= 0 then
        self:RunStop()
    else
        self:DelTimeCb("to_stop")
        self:AddTimeCb("to_stop", (iOpenSec) * 1000, function()
            local oHuodong = GetHuodong()
            oHuodong:RunStop()
        end)
    end
end

function CHuodong:RunStop()
    self:DelTimeCb("to_stop")
    self:Stop()
end

-- 执行时间计划开启活动，支持GM指令
function CHuodong:SetupRun(iPrepareSec, iReadySec, iOpenSec, bInner)
    if not global.oToolMgr:IsSysOpen("ORG_CAMPFIRE") then
        return
    end
    if bInner then
        self:DelTimeCb("to_inner_setup")
    end
    if self.m_bSetup then
        return
    end
    -- 防止真实活动开启时间与gm开启时间相撞
    if not self:IsEnd() then
        return
    end
    self.m_bSetup = true

    local iNow = get_time()
    self.m_iPrepareTimestamp = iNow
    self.m_iReadyTimestamp = self.m_iPrepareTimestamp + iPrepareSec
    self.m_iOpenTimestamp = self.m_iReadyTimestamp + iReadySec
    self.m_iStopTimestamp = self.m_iOpenTimestamp + iOpenSec
    self.m_iStartTime = self.m_iReadyTimestamp

    self:Prepare()
    if iPrepareSec <= 0 then
        self:RunReady(iReadySec, iOpenSec)
    else
        self:DelTimeCb("to_ready")
        self:AddTimeCb("to_ready", iPrepareSec * 1000, function()
            local oHuodong = GetHuodong()
            oHuodong:RunReady(iReadySec, iOpenSec)
        end)
    end
end

function CHuodong:Clear()
    self.m_bSetup = nil
    self:DelTimeCb("to_ready")
    self:DelTimeCb("to_open")
    self:DelTimeCb("to_stop")
    self.m_iStartTime = nil
    self.m_iPrepareTimestamp = nil
    self.m_iReadyTimestamp = nil
    self.m_iOpenTimestamp = nil
    self.m_iStopTimestamp = nil
    self:ClearChuanwenTick()
end

function CHuodong:GetStartTimestamp()
    return self.m_iOpenTimestamp
end

function CHuodong:ClearSetup()
    self:Stop()
end

function CHuodong:NewHour(mNow)
    super(CHuodong).NewHour(self, mNow)
    local iHour = mNow.date.hour
    local lStartTimepoint = GetHuodongConfig("start_timepoint")
    local iStartHour = lStartTimepoint[1] or 0
    if iHour ~= iStartHour then
        return
    end
    local iStartMin = lStartTimepoint[2] or 0
    local iDelaySec = iStartMin * 60
    if iDelaySec <= 0 then
        iDelaySec = 1
    end
    self:DelTimeCb("to_inner_setup")
    self:AddTimeCb("to_inner_setup", iDelaySec * 1000, function()
        local oHuodong = GetHuodong()
        oHuodong:OnInnerSetup()
    end)
end

function CHuodong:OnInnerSetup()
    local iPrepareSec = GetHuodongConfig("prepare_sec") or 0
    local iReadySec = GetHuodongConfig("ready_sec") or 0
    local iOpenSec = GetHuodongConfig("open_sec") or 0
    self:SetupRun(iPrepareSec, iReadySec, iOpenSec, true)
end

function CHuodong:AnalyseTodayTime(iHour, iMin)
    local mCurrDate = os.date("*t", get_time())
    return os.time({
        year = mCurrDate.year,
        month = mCurrDate.month,
        day = mCurrDate.day,
        hour = tonumber(iHour),
        min = tonumber(iMin),
        sec = 0,
    })
end

function CHuodong:CheckWillOpen()
    local iNow = get_time()
    self:DelTimeCb("to_inner_setup")
    if not self:IsOpenDay(iNow) then
        return
    end
    local iStartTimestampe, iOpendTimestampe = self:ResetStartTime()
    self.m_iStartTime = iOpendTimestampe
    -- 暂不考虑跨天
    if iOpendTimestampe <= iNow then
        self:NotifyScheduleState(gamedefines.ACTIVITY_STATE.STATE_END)
        return
    end
    if iNow < iStartTimestampe then
        self:NotifyScheduleState(gamedefines.ACTIVITY_STATE.STATE_READY)
        self:AddTimeCb("to_inner_setup", (iStartTimestampe - iNow) * 1000, function()
            local oHuodong = GetHuodong()
            oHuodong:OnInnerSetup()
        end)
    else -- 准备时间不足
        local iReadySec = GetHuodongConfig("ready_sec") or 0
        local iOpenSec = GetHuodongConfig("open_sec") or 0
        self:SetupRun(iOpendTimestampe - iNow, iReadySec, iOpenSec, true)
    end
end

function CHuodong:Reset()
    self.m_iReadyEndTime = 0
    self.m_oDrinkMgr:Clear()
    self.m_oQuestionMgr:ClearData()
    self.m_oCampfireMgr:Clear()
end

function CHuodong:Prepare()
    if self.m_iState ~= gamedefines.ACTIVITY_STATE.STATE_END then
        return
    end
    record.info("orgcampfire prepare")
    self.m_iPrepareTimestamp = get_time()
    self:Reset()
    -- FIXME 所有对场景内org玩家的广播，改为先管理活动玩家注册数据，从其中进行广播
    global.oNotifyMgr:BroadcastOrgsMembersInScene("GS2CCampfireInHuodongScene", {is_in = 1})
    self:NotifyState()
    self:NotifyScheduleState(gamedefines.ACTIVITY_STATE.STATE_READY)
    self:RegisterOrgs()
    self:PrepareQuestions()
end

function CHuodong:Stop()
    local bEnded = self:IsEnd()
    record.info("orgcampfire stop")
    self:Clear()
    self:Reset()
    self.m_iState = gamedefines.ACTIVITY_STATE.STATE_END
    self:UnregisterOrgs()
    self.m_oQuestionMgr:End()
    self.m_oCampfireMgr:End()
    self.m_oTieMgr:End()
    self:NotifyStop(bEnded)
    self:TryStopRewardMonitor()
    global.oRedPacketMgr:StopAutoSendActiveRP()
    -- global.oNotifyMgr:BroadcastOrgsMembersInScene("GS2CCampfireInHuodongScene", {is_in = 0})
end

function CHuodong:ReadyOpen()
    if self.m_iState == gamedefines.ACTIVITY_STATE.STATE_READY then
        return
    end
    record.info("orgcampfire ready")
    self.m_iState = gamedefines.ACTIVITY_STATE.STATE_READY
    self.m_iReadyTimestamp = get_time()
    global.oNotifyMgr:BroadcastOrgsMembersInScene("GS2CCampfireInHuodongScene", {is_in = 1})
    self:TryStartRewardMonitor()
    self.m_oCampfireMgr:Prepare()
    self.m_oQuestionMgr:Ready()
    self:NotifyToOpen()
    self:RegisterOrgs()
    if not self:IsQuestionPrepared() then
        self:PrepareQuestions()
    end
    self:TouchAllPlayersAddSchedule()
end

function CHuodong:NotifyOpen()
    global.oNotifyMgr:BroadcastOrgsMembersInScene("GS2CCampfireInHuodongScene", {is_in = 1})
    self:NotifyState()
    self:NotifyScheduleState(gamedefines.ACTIVITY_STATE.STATE_START)
    self:ChuanwenOnStateChange()
end

function CHuodong:Open()
    if self.m_iState == gamedefines.ACTIVITY_STATE.STATE_START then
        return
    end
    record.info("orgcampfire open")
    self:RegisterOrgs()
    self.m_iOpenTimestamp = get_time()
    self.m_iState = gamedefines.ACTIVITY_STATE.STATE_START
    self:TryStartRewardMonitor()
    if not self:IsQuestionPrepared() then
        self:PrepareQuestions(true)
    end
    self:NotifyOpen()
    self.m_oCampfireMgr:Start()
    self.m_oQuestionMgr:Start(GetHuodongConfig("question_cnt") * GetHuodongConfig("question_stay"))
    global.oRedPacketMgr:StartAutoSendActiveRP()
end

function CHuodong:PrepareStop()
    record.info("orgcampfire preparestop")
end

function CHuodong:OnEventEnterScene(iEvType, mData)
    local bReEnter = (iEvType == gamedefines.EVENT.PLAYER_REENTER_SCENE)
    local oPlayer = mData.player
    local oToScene = mData.scene
    self:OnPlayerEnterScene(oPlayer, oToScene, bReEnter)
end

function CHuodong:OnEventLeaveScene(iEvType, mData)
    local oPlayer = mData.player
    local oFromScene = mData.scene
    self:OnPlayerLeaveScene(oPlayer, oFromScene)
end

function CHuodong:RegisterOrg(oOrg)
    local iScene = oOrg:GetOrgSceneID()
    local oScene = global.oSceneMgr:GetScene(iScene)
    local fCbEnter = function(iEvType, mData)
        local oHuodong = GetHuodong()
        oHuodong:OnEventEnterScene(iEvType, mData)
    end
    local fCbReEnter = function(iEvType, mData)
        local oHuodong = GetHuodong()
        oHuodong:OnEventEnterScene(iEvType, mData)
    end
    oScene:AddEvent(self, gamedefines.EVENT.PLAYER_ENTER_SCENE, fCbEnter)
    oScene:AddEvent(self, gamedefines.EVENT.PLAYER_REENTER_SCENE, fCbEnter)

    local fCbLeaveScene = function(iEvType, mData)
        local oHuodong = GetHuodong()
        oHuodong:OnEventLeaveScene(iEvType, mData)
    end
    oScene:AddEvent(self, gamedefines.EVENT.PLAYER_LEAVE_SCENE, fCbLeaveScene)
end

function CHuodong:OnOrgMemberJoin(oPlayer, oTOrg)
    self:ReSync(oPlayer)
end

function CHuodong:OnOrgMemberLeave(oPlayer, oTOrg)
    -- 离开帮派即立即离开活动场景
    oPlayer:Send("GS2CCampfireInHuodongScene", {is_in = 0})
end

function CHuodong:OnPlayerEnterScene(oPlayer, oToScene, bReEnter)
    self:ReSync(oPlayer, bReEnter)
    self:TouchAddSchedule(oPlayer, bReEnter)
end

function CHuodong:OnPlayerLeaveScene(oPlayer, oFromScene)
    self.m_oSender:SendPlayerWithinOrgScene(oPlayer, oFromScene, "GS2CCampfireInHuodongScene", {is_in = 0})
end

function CHuodong:UnregisterOrg(oOrg)
    local iScene = oOrg:GetOrgSceneID()
    local oScene = global.oSceneMgr:GetScene(iScene)
    oScene:DelEvent(self, gamedefines.EVENT.PLAYER_ENTER_SCENE)
    oScene:DelEvent(self, gamedefines.EVENT.PLAYER_REENTER_SCENE)
    oScene:DelEvent(self, gamedefines.EVENT.PLAYER_LEAVE_SCENE)
end

function CHuodong:UnregisterOrgs()
    if not self.m_bRegistered then
        return
    end
    self.m_bRegistered = nil
    local oOrgMgr = global.oOrgMgr
    oOrgMgr:DelEvent(self, gamedefines.EVENT.CREATE_ORG)
    oOrgMgr:DelEvent(self, gamedefines.EVENT.LEAVE_ORG)
    oOrgMgr:DelEvent(self, gamedefines.EVENT.JOIN_ORG)
    local mOrgs = global.oOrgMgr:GetNormalOrgs()
    for iOrgId, oOrg in pairs(mOrgs) do
        self:UnregisterOrg(oOrg)
    end
end

function CHuodong:OnEventLeaveOrg(iEvType, mData)
    local pid = mData.pid
    local oPlayer = global.oWorldMgr:GetOnlinePlayerByPid(pid)
    if not oPlayer then
        return
    end
    local oTOrg = mData.org
    self:OnOrgMemberLeave(oPlayer, oTOrg)
end

function CHuodong:OnEventCreateOrg(iEvType, mData)
    local oNewOrg = mData.org
    self:RegisterOrg(oNewOrg)
end

function CHuodong:OnEventJoinOrg(iEvType, mData)
    local pid = mData.pid
    local oPlayer = global.oWorldMgr:GetOnlinePlayerByPid(pid)
    if not oPlayer then
        return
    end
    local oTOrg = mData.org
    self:OnOrgMemberJoin(oPlayer, oTOrg)
end

function CHuodong:RegisterOrgs()
    if self.m_bRegistered then
        return
    end
    self.m_bRegistered = true
    global.oOrgMgr:AddEvent(self, gamedefines.EVENT.CREATE_ORG, function(iEvType, mData)
        local oHuodong = GetHuodong()
        oHuodong:OnEventCreateOrg(iEvType, mData)
    end)
    local fCbLeaveOrg = function(iEvType, mData)
        local oHuodong = GetHuodong()
        oHuodong:OnEventLeaveOrg(iEvType, mData)
    end
    global.oOrgMgr:AddEvent(self, gamedefines.EVENT.LEAVE_ORG, fCbLeaveOrg)
    local fCbJoinOrg = function(iEvType, mData)
        local oHuodong = GetHuodong()
        oHuodong:OnEventJoinOrg(iEvType, mData)
    end
    global.oOrgMgr:AddEvent(self, gamedefines.EVENT.JOIN_ORG, fCbJoinOrg)
    local mOrgs = global.oOrgMgr:GetNormalOrgs()
    for iOrgId, oOrg in pairs(mOrgs) do
        self:RegisterOrg(oOrg)
    end
end

function CHuodong:IsStoped()
    return self:GetState() == gamedefines.ACTIVITY_STATE.STATE_END
end

function CHuodong:GetState()
    return self.m_iState
end

function CHuodong:IsEnd()
    return self.m_iState == gamedefines.ACTIVITY_STATE.STATE_END
end

function CHuodong:GetStateLeftTime()
    local iState = self:GetState()
    if iState == gamedefines.ACTIVITY_STATE.STATE_READY then
        return self.m_iOpenTimestamp - get_time()
    elseif iState == gamedefines.ACTIVITY_STATE.STATE_START then
        return self.m_iStopTimestamp - get_time()
    end
    return -1
end

function CHuodong:PackStateInfo()
    local iState = self:GetState()
    local mNet = {
        state = iState,
        lefttime = self:GetStateLeftTime(),
    }
    return mNet
end

function CHuodong:NotifyState(mAppendInfoArgs)
    local mNet = self:PackStateInfo()
    if mAppendInfoArgs then
        mNet = table_combine(mNet, mAppendInfoArgs)
    end
    mNet = net.Mask("GS2CCampfireInfo", mNet)
    global.oNotifyMgr:WorldBroadcast("GS2CCampfireInfo", mNet)
end

function CHuodong:NotifyScheduleState(iState)
    local sTime
    if self.m_iStartTime then
        sTime = get_time_format_str(self.m_iStartTime, "%H:%M")
    else
        sTime = self:GetStartTime()
    end
    global.oHuodongMgr:SetHuodongState(self.m_sName, self:ScheduleID(), iState, sTime)
end

function CHuodong:TickChuanwenToOpen()
    self:DelTimeCb("chuanwen_toopen")
    self:AddTimeCb("chuanwen_toopen", GetHuodongConfig("to_open_chuanwen_tick_sec") * 1000, function()
        local oHuodong = GetHuodong()
        oHuodong:TickChuanwenToOpen()
    end)
    global.oChatMgr:HandleSysChat(GetTextData(4001), gamedefines.SYS_CHANNEL_TAG.RUMOUR_TAG)
end

function CHuodong:TickChuanwenOpened()
    self:DelTimeCb("chuanwen_opened")
    self:AddTimeCb("chuanwen_opened", GetHuodongConfig("opened_chuanwen_tick_sec") * 1000, function()
        local oHuodong = GetHuodong()
        oHuodong:TickChuanwenOpened()
    end)
    global.oChatMgr:HandleSysChat(GetTextData(4003), gamedefines.SYS_CHANNEL_TAG.RUMOUR_TAG)
end

function CHuodong:ClearChuanwenTick()
    self:DelTimeCb("chuanwen_toopen")
    self:DelTimeCb("chuanwen_opened")
end

function CHuodong:ChuanwenOnStateChange()
    self:ClearChuanwenTick()
    local iState = self:GetState()
    if iState == gamedefines.ACTIVITY_STATE.STATE_READY then
        self:TickChuanwenToOpen()
    elseif iState == gamedefines.ACTIVITY_STATE.STATE_START then
        global.oChatMgr:HandleSysChat(GetTextData(4002), gamedefines.SYS_CHANNEL_TAG.RUMOUR_TAG)
        self:TickChuanwenOpened()
    end
end

function CHuodong:NotifyToOpen()
    -- local mNet = {
    --     state = self:GetState(),
    --     drink_buff_adds = 0,
    -- }
    -- mNet = net.Mask("GS2CCampfireInfo", mNet)
    -- global.oNotifyMgr:WorldBroadcast("GS2CCampfireInfo", mNet)
    self:NotifyState({drink_buff_adds = 0})
    self:NotifyScheduleState(gamedefines.ACTIVITY_STATE.STATE_START)

    local iWaitTime = (self.m_iReadyEndTime or 0) - get_time()
    if iWaitTime < 0 then
        iWaitTime = 0
    end
    local mNet = {time = iWaitTime}
    global.oNotifyMgr:WorldBroadcast("GS2CCampfirePreOpen", mNet)
    self:ChuanwenOnStateChange()
end

function CHuodong:NotifyStop(bEnded)
    self:NotifyState()
    self:ChuanwenOnStateChange()
    self:NotifyScheduleState(gamedefines.ACTIVITY_STATE.STATE_END)
    if not bEnded then
        -- 传闻
        global.oChatMgr:HandleSysChat(GetTextData(3001), gamedefines.SYS_CHANNEL_TAG.RUMOUR_TAG)
    end
end

function CHuodong:CanHuodongAddSchedule()
    if self:IsEnd() then
        return false
    end
    return true
end

function CHuodong:CanPlayerAddSchedule(oPlayer)
    -- if not self:CanHuodongAddSchedule() then
    --     return false
    -- end
    if not self:IsHuodongUser(oPlayer) then
        return false
    end
    return true
end

function CHuodong:TryAddPlayerSchedule(iPid)
    local oPlayer = global.oWorldMgr:GetOnlinePlayerByPid(iPid)
    if not oPlayer then
        return
    end
    if not self:CanPlayerAddSchedule(oPlayer) then
        return
    end
    oPlayer.m_oScheduleCtrl:AddByName("orgcampfire")
end

function CHuodong:TouchAllPlayersAddSchedule()
    self.m_lScheduleAdders = {}
    for iOrgId, oOrg in pairs(global.oOrgMgr:GetNormalOrgs()) do
        local iScene = oOrg:GetOrgSceneID()
        local oScene = global.oSceneMgr:GetScene(iScene)
        local lPids = oScene:GetAllPlayerIds()
        list_combine(self.m_lScheduleAdders, lPids)
    end
    self:TryAsyncAddSchedule()
end

function CHuodong:TouchAddSchedule(oPlayer, bReEnter)
    if bReEnter then
        return
    end
    if not self:CanPlayerAddSchedule(oPlayer) then
        return
    end
    self.m_lScheduleAdders = self.m_lScheduleAdders or {}
    local iPid = oPlayer:GetPid()
    table.insert(self.m_lScheduleAdders, iPid)
    self:TryAsyncAddSchedule()
end

function CHuodong:HasScheduleAdders()
    return self.m_lScheduleAdders and #self.m_lScheduleAdders > 0
end

function CHuodong:DealScheduleAdders()
    if not self:CanHuodongAddSchedule() then
        self.m_lScheduleAdders = {}
        return
    end
    local iDealCnt = 100
    while iDealCnt > 0 do
        iDealCnt = iDealCnt - 1
        local iPid = table.remove(self.m_lScheduleAdders)
        if not iPid then
            return
        end
        self:TryAddPlayerSchedule(iPid)
    end
end

function CHuodong:TryAsyncAddSchedule()
    if self:HasBatch("AddSchedule") then
        return
    end
    local fTickable = function()
        local oHuodong = GetHuodong()
        return oHuodong:HasScheduleAdders()
    end
    local fDeal = function()
        local oHuodong = GetHuodong()
        return oHuodong:DealScheduleAdders()
    end
    self:AsyncBatch("AddSchedule", 1000, fTickable, fDeal)
end

function CHuodong:ReSync(oPlayer, bReEnter)
    -- reenter表示重进场
    if bReEnter or self:IsEnd() then
        return
    end
    local oNowScene = oPlayer.m_oActiveCtrl:GetNowScene()
    local bInHuodongScene = IsPlayerOrgScene(oPlayer, oNowScene)
    oPlayer:Send("GS2CCampfireInHuodongScene", {is_in = bInHuodongScene and 1 or 0})
    local iDrinkBuffAdds = 0
    if not self:IsEnd() then
        local iOrgId = oPlayer:GetOrgID()
        iDrinkBuffAdds = self.m_oDrinkMgr:GetDrinkBuffAdds(iOrgId)
    end
    local mNet = self:PackStateInfo()
    mNet.drink_buff_adds = iDrinkBuffAdds
    mNet = net.Mask("GS2CCampfireInfo", mNet)
    oPlayer:Send("GS2CCampfireInfo", mNet)

    -- if self:IsHuodongUser(oPlayer) then
    if bInHuodongScene then
        self.m_oQuestionMgr:SendLogin(oPlayer)
    end
end

function CHuodong:OnLogin(oPlayer, bReEnter)
    if not bReEnter then
        -- -- 注册玩家可参与活动
        -- if not self:TouchAccessability(oPlayer) then
        --     oPlayer:AddEvent(self, gamedefines.EVENT.ON_UPGRADE, function(iEvType, mData)
        --         self:TouchAccessability(mData.player)
        --     end)
        -- end
    end
    self:ReSync(oPlayer)
end

function CHuodong:OnLogout(oPlayer)
end

function CHuodong:PrepareQuestions(bSimple)
    self.m_oQuestionMgr:ClearData()
    self.m_oQuestionMgr:Prepare(bSimple)
end

function CHuodong:IsQuestionPrepared()
    return self.m_oQuestionMgr:IsPrepared()
end

function CHuodong:GetBuffDrinkAdds(oPlayer)
    local iOrgId = oPlayer:GetOrgID()
    local iDrinkBuffAdds = self.m_oDrinkMgr:GetDrinkBuffAdds(iOrgId)
    return iDrinkBuffAdds
end

function CHuodong:GetBuffTeamAdds(oPlayer)
    -- 暂不用oOrg:GetTempData("campfire_drink_buff_adds", 0)
    local iTeamOnlineSize = oPlayer:GetTeamSize(true)
    if iTeamOnlineSize > 1 then
        iTeamOnlineSize = iTeamOnlineSize - 1
        return iTeamOnlineSize * GetHuodongConfig("adds_per_member")
    else
        return 0
    end
end

function CHuodong:GetBuffAdds(oPlayer)
    local iDrinkAdds = self:GetBuffDrinkAdds(oPlayer)
    local iTeamAdds = self:GetBuffTeamAdds(oPlayer)
    local iAdds = iTeamAdds + iDrinkAdds
    local iMaxAdds = GetHuodongConfig("max_adds") or MAX_BUFF_ADDS
    return math.min(iAdds, iMaxAdds)
end

function CHuodong:TestOp(sCmd, mArgs)
    local oNotifyMgr = global.oNotifyMgr
    local pid = table.remove(mArgs)
    local oWorldMgr = global.oWorldMgr
    local oPlayer = oWorldMgr:GetOnlinePlayerByPid(pid)
    if sCmd == "init" then
        self:Init()
    elseif sCmd == "prepare" then
        self:Prepare()
    elseif sCmd == "ready" then
        self:ReadyOpen()
    elseif sCmd == "open" then
        self:Open()
    elseif sCmd == "stop" then
        self:Stop()
    elseif sCmd == "event" then
        self:UnregisterOrgs()
        self:RegisterOrgs()
    elseif sCmd == "showques" then
        local lQues = self.m_oQuestionMgr.m_lQuestionList
        local mBench = self.m_oQuestionMgr.m_mCustomBench
        if not lQues then
            oNotifyMgr:Notify(pid, "无题目")
        else
            oNotifyMgr:Notify(pid, "题目:" .. table.concat(lQues, ',') .. " | 替补:" .. extend.Table.serialize(mBench))
        end
    elseif sCmd == "corr" then
        local iCorrectCnt = self.m_oQuestionMgr.m_mAnswerCount[pid]
        oNotifyMgr:Notify(pid, string.format("当前答对：%s", iCorrectCnt))
    elseif sCmd == "ques" then
        local iRound = mArgs[1]
        local iTotal = #(self.m_oQuestionMgr.m_lQuestionList)
        self.m_oQuestionMgr.m_iStatus = QUESTION_STATUS.START
        self.m_oQuestionMgr:SendQuestion(iRound, iTotal, 10)
    elseif sCmd == "reques" then
        local iStay = GetHuodongConfig("question_stay")
        self.m_oQuestionMgr:End()
        self.m_oQuestionMgr:ClearData()
        self.m_oQuestionMgr:InitPool(false, mArgs)
        self.m_oQuestionMgr:Start(GetHuodongConfig("question_cnt") * iStay)
        self.m_oQuestionMgr:SendLogin(oPlayer)
        self.m_oQuestionMgr.m_iStatus = QUESTION_STATUS.START
        self.m_oQuestionMgr.m_iRound = 0
        self.m_oQuestionMgr:SendNext(iStay)
    elseif sCmd == "answer" then
        local sFillAnswer = ""
        if #mArgs < 2 then
            oNotifyMgr:Notify(pid, "需要答案")
        elseif #mArgs >= 3 then
            sFillAnswer = mArgs[3]
        end
        local iQid = mArgs[1]
        local iAnswer = mArgs[2]
        self.m_oQuestionMgr:Answer(oPlayer, iQid, iAnswer, sFillAnswer)
    elseif sCmd == "addfire" then
        self.m_oCampfireMgr:SetupCampfires()
    elseif sCmd == "delfire" then
        self.m_oCampfireMgr:ClearCampfires()
    elseif sCmd == "drink" then
        local iAmount = mArgs[1]
        if not iAmount then
            oNotifyMgr:Notify(pid, "需要数量")
        end
        self.m_oDrinkMgr:CallDrink(oPlayer, iAmount)
    elseif sCmd == "qtie" then
        self.m_oTieMgr:QueryGiftables(oPlayer)
    elseif sCmd == "tie" then
        local iTarget = mArgs[1]
        if not iTarget then
            oNotifyMgr:Notify(pid, "需要目标pid")
        end
        local bQuick = mArgs[2]
        self.m_oTieMgr:CallGive(oPlayer, iTarget, bQuick)
    elseif sCmd == "hour" then
        local iHour = mArgs[1] or 0
        self:NewHour(get_daytime({anchor=iHour}))
    elseif sCmd == "stat" then
        local sMsg = string.format("state:%s, reg:%s", self:GetState(), self.m_bRegistered)
        oNotifyMgr:Notify(pid, sMsg)
    end
    oNotifyMgr:Notify(pid, "执行完毕")
end

function CHuodong:IsHuodongUser(oPlayer)
    -- TODO 等级? 这个设定会将场景广播的效率降到角色级，如果不加入此设定，此处便不需要判断
    local oNowScene = oPlayer.m_oActiveCtrl:GetNowScene()
    return IsPlayerOrgScene(oPlayer, oNowScene)
end

function CHuodong:GetInScenePids()
    local mOrgs = global.oOrgMgr:GetNormalOrgs()
    local mScenePids = {}
    for iOrgId, oOrg in pairs(mOrgs) do
        local iScene = oOrg:GetOrgSceneID()
        local oScene = global.oSceneMgr:GetScene(iScene)
        local lPids = oScene:GetAllPlayerIds()
        if next(lPids) then
            mScenePids[iOrgId] = lPids
        end
    end
    return mScenePids
end

function CHuodong:TryEnterOrgScene(oPlayer)
    local iPid = oPlayer:GetPid()
    local oOrg = oPlayer:GetOrg()
    if not oOrg then return end
    if oPlayer:InWar() then
        self:Notify(iPid, 1104)
        return
    end
    if oPlayer:IsFixed() then
        return
    end
    local oTeam = oPlayer:HasTeam()
    if oTeam and not oPlayer:IsTeamLeader() and not oTeam:IsShortLeave(oPlayer:GetPid()) then
        self:Notify(iPid, 1105)
        return
    end
    if oPlayer:GetNowScene():GetSceneId() == oOrg:GetOrgSceneID() then
        self:Notify(iPid, 1106)
        return true
    end
    return oOrg:EnterOrgScene(oPlayer)
end

---------------------------------------------
CComponent = {}
CComponent.__index = CComponent
inherit(CComponent, logic_base_cls())

function CComponent:New()
    return super(CComponent).New(self)
end

function CComponent:GetHuodong()
    return GetHuodong()
end

function CComponent:NotifyErr(oPlayer, iErr, xArg)
    local oNotifyMgr = global.oNotifyMgr
    local pid = oPlayer:GetPid()
    if iErr == ERR.TARGET_OFFLINE then
        oNotifyMgr:Notify(pid, GetTextData(1000))
    elseif iErr == ERR.FULLED then
        oNotifyMgr:Notify(pid, GetTextData(1001))
    elseif iErr == ERR.NOT_HUODONG_USER then
        oNotifyMgr:Notify(pid, GetTextData(1002))
    elseif iErr == ERR.HUODONG_STOPED then
        oNotifyMgr:Notify(pid, GetTextData(1003))
    elseif iErr == ERR.LACK_GOLD_COIN then
        oNotifyMgr:Notify(pid, GetTextData(1004))
    elseif iErr == ERR.NO_ORG then
        oNotifyMgr:Notify(pid, GetTextData(1005))
    elseif iErr == ERR.OVER_AMOUNT then
        if xArg and xArg > 0 then
            oNotifyMgr:Notify(pid, global.oToolMgr:FormatColorString(GetTextData(1014), {amount = xArg}))
        else
            oNotifyMgr:Notify(pid, GetTextData(1006))
        end
    elseif iErr == ERR.OVER_PERSON_LIMIT then
        if xArg and xArg > 0 then
            oNotifyMgr:Notify(pid, global.oToolMgr:FormatColorString(GetTextData(1014), {amount = xArg}))
        else
            oNotifyMgr:Notify(pid, GetTextData(1007))
        end
    elseif iErr == ERR.OVER_GIVE_LIMIT then
        oNotifyMgr:Notify(pid, GetTextData(1008))
    elseif iErr == ERR.OVER_RECEIVE_LIMIT then
        oNotifyMgr:Notify(pid, GetTextData(1009))
    elseif iErr == ERR.TARGET_NOT_HUODONG_USER then
        oNotifyMgr:Notify(pid, GetTextData(1010))
    elseif iErr == ERR.NO_TIE_ITEM then
        oNotifyMgr:Notify(pid, GetTextData(1011))
    elseif iErr == ERR.DIFF_ORG then
        oNotifyMgr:Notify(pid, GetTextData(1012))
    elseif iErr == ERR.TARGET_SELF then
        oNotifyMgr:Notify(pid, GetTextData(1013))
    end
end
---------------------------------------------
CSender = {}
CSender.__index = CSender
inherit(CSender, CComponent)

function CSender:BuildMembers(sNetMessage, mNet)
end

-- TODO 等级? 这个设定会将场景广播的效率降到角色级，如果不加入此设定，此处便不需要判断
function CSender:FilterHuodongPlayers(mPids)
    -- return grade ok pids
end

function CSender:SendPlayerWithinOrgScene(oPlayer, oScene, sNetMessage, mNet)
    if IsPlayerOrgScene(oPlayer, oScene) then
        oPlayer:Send(sNetMessage, mNet)
    end
end
----------------------------------------------
CQuestionMgr = {}
CQuestionMgr.__index = CQuestionMgr
inherit(CQuestionMgr, CComponent)

function CQuestionMgr:New()
    local o = super(CQuestionMgr).New(self)
    o.m_iRound = nil
    o.m_iRoundEndTime = 0
    o.m_iDispatchId = 0
    o.m_lValidatingOrgs = extend.Queue.create()
    o.m_mAllQuestions = {}
    o.m_mAnswerCount = {}
    return o
end

function CQuestionMgr:DispatchId()
    self.m_iDispatchId = self.m_iDispatchId + 1
    return self.m_iDispatchId
end

function CQuestionMgr:IsPrepared()
    return self.m_bPrepared
end

function CQuestionMgr:Status()
    return self.m_iStatus
end

function CQuestionMgr:End()
    self:DelTimeCb("Next")
    self:CutPrepareQuestions()
    if global.oOrgMgr then
        -- oHuodongMgr的初始化比oOrgMgr赋值要早
        global.oOrgMgr:DelEvent(self, gamedefines.EVENT.CREATE_ORG)
    end
    if self.m_iStatus == QUESTION_STATUS.END then
        return
    end
    self.m_iStatus = QUESTION_STATUS.END
    self.m_bPrepared = false
    local mNet = {
        state = self:Status(),
    }
    global.oNotifyMgr:BroadcastOrgsMembersInScene("GS2CCampfireQuestionState", mNet)
end

function CQuestionMgr:ClearData()
    self.m_iRound = nil
    self.m_bPrepared = false
    self.m_mAnswerCount = {}
    self:CutPrepareQuestions()
    self:ClearPool()
end

function CQuestionMgr:Prepare(bSimple)
    self.m_bPrepared = true
    self:InitPool(bSimple) -- 不再填充帮派题的选项，由每题生成时准备下一题的选项内容
end

function CQuestionMgr:Release()
    self:ClearData()
    if global.oOrgMgr then
        global.oOrgMgr:DelEvent(self, gamedefines.EVENT.CREATE_ORG)
    end
    super(CQuestionMgr).Release(self)
end

function CQuestionMgr:ClearPool()
    self:DelTimeCb("Next")
    self.m_mCustomBench = {}
    self.m_lQuestionList = {}
    for iQid, oQues in pairs(self.m_mAllQuestions) do
        baseobj_safe_release(oQues)
    end
    self.m_mAllQuestions = {}
end

function CQuestionMgr:InitPool(bSimple, mArgs)
    if table_count(self.m_mAllQuestions) > 0 then
        self:ClearPool()
    end
    -- 筛选问题(预留备选)
    local mFixedChoiceLib = GetLibData("fixed_choice")
    local iQuestionCnt = GetHuodongConfig("question_cnt")
    assert(table_count(mFixedChoiceLib) >= iQuestionCnt, "fixed choice question lib lack, need at least " .. iQuestionCnt)
    local mCustomChoiceLib = GetLibData("custom_choice")
    local mFillinLib = GetLibData("fill_in")

    local iFillinCnt
    if mArgs and mArgs.all_org then
        iFillinCnt = 0
    else
        iFillinCnt = math.random(0, math.min(table_count(mFillinLib), iQuestionCnt))
    end
    local iChoiceCnt = iQuestionCnt - iFillinCnt
    local iMaxCustomChoiceCnt = math.min(table_count(mCustomChoiceLib), iChoiceCnt)
    local iCustomChoiceCnt
    if mArgs and mArgs.all_org then
        iCustomChoiceCnt = iMaxCustomChoiceCnt
    else
        iCustomChoiceCnt = math.random(0, iMaxCustomChoiceCnt)
    end

    local lFixedChoiceIds = extend.Random.random_size(table_key_list(mFixedChoiceLib), iChoiceCnt)
    local lCustomChoiceIds = extend.Random.random_size(table_key_list(mCustomChoiceLib), iCustomChoiceCnt)
    local lBenchIds = extend.Random.random_size(lFixedChoiceIds, iCustomChoiceCnt)
    lFixedChoiceIds = extend.Array.sub(lFixedChoiceIds, lBenchIds)
    local lFillinIds = extend.Random.random_size(table_key_list(mFillinLib), iFillinCnt)

    -- 定制题的替补
    self.m_mCustomBench = extend.Table.list_combine_map(lCustomChoiceIds, lBenchIds)
    local lAllQids = list_combine(list_combine(table_copy(lFixedChoiceIds), lCustomChoiceIds), lFillinIds)
    -- 全部题的顺序
    self.m_lQuestionList = extend.Random.random_size(lAllQids, #lAllQids)
    local mLogData = {
        ques_list = table_deep_copy(self.m_lQuestionList),
        ques_bench = table_deep_copy(self.m_mCustomBench),
    }
    record.log_db("huodonginfo", "campfire_new_questions", mLogData)

    -- 题对象
    self.m_mAllQuestions = {}
    for _, iQid in ipairs(lFixedChoiceIds) do
        local mQInfo = mFixedChoiceLib[iQid]
        assert(mQInfo, "question fixed_choice null question:" .. iQid)
        local oQuestion = NewChoiceQuestion(iQid, mQInfo)
        self.m_mAllQuestions[iQid] = oQuestion
    end
    for _, iQid in ipairs(lFillinIds) do
        local mQInfo = mFillinLib[iQid]
        assert(mQInfo, "question fill_in null question:" .. iQid)
        local oQuestion = NewFillinQuestion(iQid, mQInfo)
        self.m_mAllQuestions[iQid] = oQuestion
    end
    for _, iQid in ipairs(lBenchIds) do
        local mQInfo = mFixedChoiceLib[iQid]
        assert(mQInfo, "question fixed_choice null question:" .. iQid)
        local oQuestion = NewChoiceQuestion(iQid, mQInfo)
        self.m_mAllQuestions[iQid] = oQuestion
    end
    for _, iQid in ipairs(lCustomChoiceIds) do
        local mQInfo = mCustomChoiceLib[iQid]
        assert(mQInfo, "question custom_choice null question:" .. iQid)
        local iBenchQid = self.m_mCustomBench[iQid]
        local oBenchQuestion = iBenchQid and self.m_mAllQuestions[iBenchQid]
        local oQuestion = NewCustomChoiceQuestion(iQid, mQInfo, oBenchQuestion)
        self.m_mAllQuestions[iQid] = oQuestion
    end
    -- if not bSimple then
    --     self:ValidateCustomChoices()
    -- end
end

function CQuestionMgr:OnEventCreateOrg(iEvType, mData)
    local oNewOrg = mData.org
    self:OnOrgCreateQuesValidate(oNewOrg)
end

function CQuestionMgr:ValidateCustomChoices()
    self:CutPrepareQuestions()
    if table_count(self.m_mCustomBench) == 0 then
        return
    end
    local iNextRound = self.m_iRound + 1
    local oQuestion = self:GetQuestionByRound(iNextRound)
    if not oQuestion or oQuestion.m_iType ~= QUESTION_TYPE.CUSTOM_CHOICE then
        return
    end

    self.m_bValidatingCustom = true

    extend.Queue.init(self.m_lValidatingOrgs, table_key_list(global.oOrgMgr:GetNormalOrgs()))
    -- 心跳填充各帮派问题答案
    -- TODO 与其使用tick，可以考虑开新的service，hash开多个线程工作（方案改为每题出题前tick，一次一题，量级较小，用新service可能异步处理提升不大）
    if extend.Queue.qsize(self.m_lValidatingOrgs) > 0 then
        self:TickValidateCustom()
    end
end

function CQuestionMgr:OnOrgCreateQuesValidate(oOrg)
    if not self.m_bValidatingCustom then
        return
    end
    local iNextRound = self.m_iRound + 1
    local oQuestion = self:GetQuestionByRound(iNextRound)
    if not oQuestion or oQuestion.m_iType ~= QUESTION_TYPE.CUSTOM_CHOICE then
        return
    end
    extend.Queue.enqueue(self.m_lValidatingOrgs, oOrg:OrgID())
    -- 当前为唯一新加入数据，重开tick
    if extend.Queue.qsize(self.m_lValidatingOrgs) == 1 then
        self:TickValidateCustom()
    end
end

function CQuestionMgr:TickValidateCustomLater()
    self:DelTimeCb("prepare_custom")
    self:AddTimeCb("prepare_custom", 1000, function()
        local oMgr = GetHuodong().m_oQuestionMgr
        oMgr:TickValidateCustom()
    end)
end

function CQuestionMgr:TickValidateCustom()
    self:DelTimeCb("prepare_custom")
    if not self.m_bValidatingCustom then
        return
    end
    self:DealTickValidateCustom(70)
    if extend.Queue.qsize(self.m_lValidatingOrgs) > 0 then
        self:TickValidateCustomLater()
    end
end

function CQuestionMgr:DealTickValidateCustom(iCnt)
    local iNextRound = self.m_iRound + 1
    local oQuestion = self:GetQuestionByRound(iNextRound)
    if not oQuestion or oQuestion.m_iType ~= QUESTION_TYPE.CUSTOM_CHOICE then
        return
    end
    while iCnt > 0 do
        if extend.Queue.qsize(self.m_lValidatingOrgs) <= 0 then
            return
        end
        local iOrgId = extend.Queue.dequeue(self.m_lValidatingOrgs)
        safe_call(self.ValidateCustom, self, iOrgId, oQuestion)
        iCnt = iCnt - 1
    end
end

function CQuestionMgr:ValidateCustom(iOrgId, oQuestion)
    local oOrg = global.oOrgMgr:GetNormalOrg(iOrgId)
    if not oOrg then
        -- 帮派解散则不处理
        return
    end
    local iCustomType = oQuestion:GetCustomType()
    local sTargetName, lOtherNames = self:GenCustomAnswers(oOrg, iCustomType)
    if sTargetName and lOtherNames and #lOtherNames == CHOICE_CNT - 1 then
        oQuestion:SetOrgChoices(iOrgId, sTargetName, lOtherNames)
    end
end

function CQuestionMgr:GenCustomAnswers(oOrg, iType)
    if iType == 1 then -- 帮派评分最高成员
        -- TODO 等评分系统完成再处理
    elseif iType == 2 then -- 帮主
        return self:SelectOneByOrgPostion(oOrg, orgdefines.ORG_POSITION.LEADER)
    elseif iType == 3 then -- 副帮主
        return self:SelectOneByOrgPostion(oOrg, orgdefines.ORG_POSITION.DEPUTY)
    elseif iType == 4 then -- 执剑使
        return self:SelectOneByOrgHonor(oOrg, orgdefines.ORG_HONOR.MOSTPOINT)
    elseif iType == 5 then -- 客卿
        return self:SelectOneByOrgHonor(oOrg, orgdefines.ORG_HONOR.STRONGEST)
    elseif iType == 6 then -- 帮派正式成员数
        local iCnt = oOrg:GetMemberCnt()
        local iMax = oOrg:GetMaxMemberCnt()
        return tostring(iCnt), self:SelectCntWithinRange(0, 50, iCnt, iMax)
    elseif iType == 7 then -- 学徒成员数
        local iCnt = oOrg:GetXueTuCnt()
        local iMax = oOrg:GetMaxXuetuCnt()
        return tostring(iCnt), self:SelectCntWithinRange(0, 50, iCnt, iMax)
    elseif iType == 8 then -- 长老数
        local iCnt = oOrg:GetPositionCnt(orgdefines.ORG_POSITION.ELDER)
        local iMax = oOrg:GetPosMaxCnt(orgdefines.ORG_POSITION.ELDER)
        return tostring(iCnt), self:SelectCntWithinRange(0, 6, iCnt, iMax)
    elseif iType == 9 then -- 车夫数
        local iCnt = oOrg:GetPositionCnt(orgdefines.ORG_POSITION.CARTER)
        local iMax = oOrg:GetPosMaxCnt(orgdefines.ORG_POSITION.CARTER)
        return tostring(iCnt), self:SelectCntWithinRange(0, 20, iCnt, iMax)
    elseif iType == 10 then -- 精英数
        local iCnt = oOrg.m_oMemberMgr:GetEliteCnt()
        local iMax = oOrg:GetEliteMaxNum()
        return tostring(iCnt), self:SelectCntWithinRange(0, 30, iCnt, iMax)
    elseif iType == 11 then -- 宝贝数
        local iCnt = oOrg:GetPositionCnt(orgdefines.ORG_POSITION.FAIRY)
        local iMax = oOrg:GetPosMaxCnt(orgdefines.ORG_POSITION.FAIRY)
        return tostring(iCnt), self:SelectCntWithinRange(0, 4, iCnt, iMax)
    end
end

function CQuestionMgr:GetRandomRanged(iLower, iUpper, iCnt)
    assert(iCnt > 1)
    if (iUpper - iLower) / iCnt >= 2 then
        local lAnswers = {}
        while #lAnswers < iCnt do
            local iAnswer = math.random(iLower, iUpper)
            if not extend.Array.find(lAnswers, iAnswer) then
                table.insert(lAnswers, iAnswer)
            end
        end
        return lAnswers
    elseif (iUpper - iLower + 1) >= iCnt then
        local lRange = {}
        for i = iLower, iUpper do
            table.insert(lRange, i)
        end
        return extend.Random.random_size(lRange, iCnt)
    else
        assert(nil, "range [%d,%d] short for cnt:%d", iLower, iUpper, iCnt)
    end
end

function CQuestionMgr:SelectCntWithinRange(iLower, iUpper, iExclude, iMax)
    assert(iUpper - iLower + 1 - CHOICE_CNT > 0, "campfire org question prepare answer: range too short")
    if iMax and (iMax - iLower + 1 - CHOICE_CNT > 0) then
        iUpper = iMax
    end
    local lAnswers = self:GetRandomRanged(iLower, iUpper, CHOICE_CNT)
    local iPos = extend.Array.find(lAnswers, iExclude)
    if iPos then
        table.remove(lAnswers, iPos)
    else
        table.remove(lAnswers)
    end
    return extend.Table.filter(lAnswers, function(v) return tostring(v) end)
end

function CQuestionMgr:GetRestKeys(mA, mB, lExclude)
    local lRes = {}
    for k,v in pairs(mA) do
        if not extend.Array.find(lExclude, k) then
            table.insert(lRes, k)
        end
    end
    for k,v in pairs(mB) do
        if not extend.Array.find(lExclude, k) then
            table.insert(lRes, k)
        end
    end
    return lRes
end

function CQuestionMgr:SelectOneByOrgHonor(oOrg, iHonor, bForbidNull)
    local lTargetIds = oOrg:GetMemIdsByHonor(iHonor)
    return self:SelectOrgMemberNames(oOrg, lTargetIds, bForbidNull)
end

function CQuestionMgr:SelectOneByOrgPostion(oOrg, iPos, bForbidNull)
    local lTargetIds = oOrg:GetMemIdsByPosition(iPos)
    return self:SelectOrgMemberNames(oOrg, lTargetIds, bForbidNull)
end

function CQuestionMgr:SelectOrgMemberNames(oOrg, lTargetIds, bForbidNull)
    local mNormalMembers = oOrg.m_oMemberMgr:GetMemberMap()
    local mXueTuMembers = oOrg.m_oMemberMgr:GetXueTuMap()
    local iRestCnt = table_count(mNormalMembers) + table_count(mXueTuMembers) - #lTargetIds
    local iWrongChoiceCnt = CHOICE_CNT - 1
    local lOtherIds = self:GetRestKeys(mNormalMembers, mXueTuMembers, lTargetIds)
    local iNeedMoreCnt = 0
    local sTargetName
    local lOtherNames = {}
    if #lTargetIds > 0 then
        local iTargetId = extend.Random.random_choice(lTargetIds)
        sTargetName = oOrg:GetMember(iTargetId):GetName()
        if not bForbidNull and math.random(1, 10) <= 9 then  -- use null
            table.insert(lOtherNames, "无")
            iWrongChoiceCnt = iWrongChoiceCnt - 1
        end
    else
        sTargetName = "无"
    end
    if iRestCnt > iWrongChoiceCnt then
        lOtherIds = extend.Random.random_size(lOtherIds, iWrongChoiceCnt)
    elseif iRestCnt < iWrongChoiceCnt then
        iNeedMoreCnt = iWrongChoiceCnt - iRestCnt
    end
    for _, iMemId in ipairs(lOtherIds) do
        local oMember = oOrg:GetMember(iMemId)
        local sMemName = ""
        if oMember then
            sMemName = oMember:GetName()
        else
            local oXueTu = oOrg:GetXueTu(iMemId)
            if oXueTu then
                sMemName = oXueTu:GetName()
            end
        end
        table.insert(lOtherNames, sMemName)
    end
    local oToolMgr = global.oToolMgr
    while iNeedMoreCnt > 0 do
        local sName = oToolMgr:GenRandomRoleName()
        if not extend.Array.find(lOtherNames, sName) then
            table.insert(lOtherNames, sName)
            iNeedMoreCnt = iNeedMoreCnt - 1
        end
    end
    return sTargetName, lOtherNames
end

function CQuestionMgr:ValidAsk()
    if not self:IsStart() then
        return false
    end
    return true
end

-- 发送题目
function CQuestionMgr:SendQuestion(iRound, iTotal, iStay)
    if not self:ValidAsk() then
        return false
    end
    local oQuestion = self:GetQuestionByRound(iRound)
    if not oQuestion then
        return false
    end
    oQuestion:BroadcastQuestion(iRound, iTotal, iStay)
    return true
end

function CQuestionMgr:IsStart()
    return self:Status() == QUESTION_STATUS.START
end

function CQuestionMgr:IsEnd()
    return self:Status() == QUESTION_STATUS.END
end

function CQuestionMgr:ValidAnswer(oPlayer, iQid)
    local oNotifyMgr = global.oNotifyMgr
    local iPid = oPlayer:GetPid()

    -- check time
    if not self:IsStart() then
        oNotifyMgr:Notify(iPid, GetTextData(1003))
        return false
    end
    local iRound = self.m_iRound
    if not iRound then
        oNotifyMgr:Notify(iPid, GetTextData(1015))
        return false
    end
    local iOriginQid = self.m_lQuestionList[iRound]
    if iQid ~= iOriginQid then
        local iBenchQid = self.m_mCustomBench[iOriginQid]
        if iQid ~= iBenchQid then
            oNotifyMgr:Notify(iPid, GetTextData(1016))
            return false
        end
    end
    local oQuestion = self:GetQuestion(iQid)
    if not oQuestion then
        oNotifyMgr:Notify(iPid, GetTextData(1016))
        return false
    end
    -- 仅可回答一次
    if oQuestion:HasAnswered(oPlayer) then
        oNotifyMgr:Notify(iPid, GetTextData(1017))
        return false
    end
    return true
end

function CQuestionMgr:Answer(oPlayer, iQid, iAnswer, sFillAnswer)
    if not self:ValidAnswer(oPlayer, iQid) then
        return
    end

    -- check question
    local oQuestion = self:GetQuestion(iQid)
    if not oQuestion then
        return
    end

    -- check answer
    local bCorrect, iRewardId, mRewardContent = oQuestion:Answer(oPlayer, iAnswer, sFillAnswer)
    local iCorrectCnt = self:CountOnCorrect(oPlayer, bCorrect)
    oQuestion:ShowCorrectAnswer(oPlayer, bCorrect, iCorrectCnt)
    local mLogData = oPlayer:LogData()
    mLogData.round = self.m_iRound
    mLogData.ques_id = iQid
    mLogData.correct = bCorrect
    mLogData.rewardid = iRewardId or 0
    local oHuodong = GetHuodong()
    local mContentCopy = oHuodong:SimplifyReward(oPlayer, mRewardContent or {})
    mLogData.reward = mContentCopy
    record.user("huodong", "campfire_answer", mLogData)
    safe_call(self.LogAnlayInfo, self, oPlayer)
end

function CQuestionMgr:LogAnlayInfo(oPlayer)
    if not oPlayer then return end

    -- 第一次答题
    local iCount = 0
    for _, oQuestion in pairs(self.m_mAllQuestions) do
        if oQuestion:HasAnswered(oPlayer) then
            iCount = iCount + 1
        end

        if iCount > 1 then return end
    end

    local mAnalyLog = oPlayer:BaseAnalyInfo()
    mAnalyLog["turn_times"] = 0
    mAnalyLog["operation"] = 1
    mAnalyLog["activity_type"] = "org_campfire"
    analy.log_data("TimelimitActivity", mAnalyLog)
end

function CQuestionMgr:CountOnCorrect(oPlayer, bCorrect)
    local iPid = oPlayer:GetPid()
    local iCorrectCnt = self.m_mAnswerCount[iPid] or 0
    if not bCorrect then
        return iCorrectCnt
    end
    iCorrectCnt = iCorrectCnt + 1
    self.m_mAnswerCount[iPid] = iCorrectCnt
    return iCorrectCnt
end

function CQuestionMgr:SetQuestion(iQid, oQuestion)
    self.m_mAllQuestions[iQid] = oQuestion
end

-- 可能使用的是替补
function CQuestionMgr:GetOrgRealQuestion(iOrgId, oQuestion)
    if not oQuestion then
        return nil
    end
    return oQuestion:GetOrgRealQuestion(iOrgId)
end

function CQuestionMgr:GetQuestionByRound(iRound)
    local iQid = self.m_lQuestionList[iRound]
    if not iQid then
        return nil
    end
    return self:GetQuestion(iQid)
end

function CQuestionMgr:GetQuestion(iQid)
    return self.m_mAllQuestions[iQid]
end

function CQuestionMgr:CutPrepareQuestions()
    -- 中止ValidateCustomChoices心跳
    self.m_bValidatingCustom = nil
    -- self.m_lValidatingRestCustomTypes = nil
    extend.Queue.clear(self.m_lValidatingOrgs)
    self:DelTimeCb("prepare_custom")
end

function CQuestionMgr:Ready()
    self.m_iStatus = QUESTION_STATUS.READY
end

function CQuestionMgr:FirstValidateCustomChoices()
    global.oOrgMgr:AddEvent(self, gamedefines.EVENT.CREATE_ORG, function(iEvType, mData)
        local oMgr = GetHuodong().m_oQuestionMgr
        oMgr:OnEventCreateOrg(iEvType, mData)
    end)
    self:ValidateCustomChoices()
end

function CQuestionMgr:Start(iStartStay)
    self:CutPrepareQuestions()
    self.m_iStatus = QUESTION_STATUS.START
    local f1 = function ()
        local oMgr = GetHuodong().m_oQuestionMgr
        oMgr:End()
    end
    self:DelTimeCb("End")
    self:AddTimeCb("End", iStartStay * 1000, f1)
    local mNet = {
        state = self:Status(),
    }
    global.oNotifyMgr:BroadcastOrgsMembersInScene("GS2CCampfireQuestionState", mNet)
    self.m_iRound = 0 -- 答题启动需要设值

    -- TODO 理应找前面一点时间来执行，但是没有配置这样的执行时间片，就现在直接开始构造帮派答案吧
    self:FirstValidateCustomChoices()

    self:SendNext(GetHuodongConfig("question_stay"))
end

function CQuestionMgr:OnNextQuestion()
    self:SendNext(GetHuodongConfig("question_stay"))
end

function CQuestionMgr:SendNext(iStay)
    self:DelTimeCb("Next")
    if not self:IsStart() then
        return
    end
    if not self.m_iRound then
        return
    end
    local iRound = self.m_iRound + 1
    local iTotal = #(self.m_lQuestionList)
    if iRound > iTotal then
        self:End()
    end
    self.m_iRound = iRound
    self.m_iRoundEndTime = get_time() + iStay
    if not self:SendQuestion(iRound, iTotal, iStay) then
        record.error("orgcampfire question send null, curRound=%d,totalRound=%d", iRound, iTotal)
        self:End()
        return
    end
    if iRound < iTotal then
        local f1 = function ()
            local oMgr = GetHuodong().m_oQuestionMgr
            oMgr:OnNextQuestion()
        end
        self:DelTimeCb("Next")
        self:AddTimeCb("Next", iStay * 1000, f1)
        self:ValidateCustomChoices()
    else
        local f1 = function ()
            local oMgr = GetHuodong().m_oQuestionMgr
            oMgr:End()
        end
        self:DelTimeCb("End")
        self:AddTimeCb("End", iStay * 1000, f1)
    end
end

function CQuestionMgr:DesireQuestion(oPlayer)
    local iOrgId = oPlayer:GetOrgID()
    if not iOrgId or iOrgId == 0 then
        return
    end
    if self:IsEnd() then
        oPlayer:NotifyMessage(global.oToolMgr:FormatColorString(GetTextData(5002)))
        return
    end
    local oHuodong = GetHuodong()
    local iSecToStart = oHuodong:GetStartTimestamp() - get_time()
    if iSecToStart > 0 then
        oPlayer:NotifyMessage(global.oToolMgr:FormatColorString(GetTextData(5001), {time = iSecToStart}))
        return
    end
    local iRound = self.m_iRound or 0
    local iTotal = #(self.m_lQuestionList)
    local iAnswered = 0
    local oQuestion = self:GetOrgRealQuestion(iOrgId, self:GetQuestionByRound(iRound))
    if oQuestion then
        if oQuestion:HasAnswered(oPlayer) then
            if iRound >= iTotal then
                oPlayer:NotifyMessage(global.oToolMgr:FormatColorString(GetTextData(5004)))
                return
            end
        else
            -- 暂不重发
            return
        end
    end
    local iStay = (self.m_iRoundEndTime or 0) - get_time()
    if iStay > 0 then
        oPlayer:NotifyMessage(global.oToolMgr:FormatColorString(GetTextData(5003), {time = iStay}))
        return
    end
end

function CQuestionMgr:SendLogin(oPlayer)
    local iOrgId = oPlayer:GetOrgID()
    if not iOrgId or iOrgId == 0 then
        return
    end
    if not self:IsStart() then
        local mNet = {
            state = self:Status(),
        }
        oPlayer:Send("GS2CCampfireQuestionState", mNet)
        return
    end

    local iRound = self.m_iRound or 0
    local iTotal = #(self.m_lQuestionList)
    local iAnswered = 0
    local oQuestion = self:GetOrgRealQuestion(iOrgId, self:GetQuestionByRound(iRound))
    if oQuestion then
        if oQuestion:HasAnswered(oPlayer) then
            iAnswered = 1
        else
            local iStay = (self.m_iRoundEndTime or 0) - get_time()
            if iStay > 0 then
                local mQuestionData = oQuestion:MakeOrgQuestionNetData(iOrgId, iRound, iTotal, iStay)
                oPlayer:Send("GS2CCampfireQuestion", mQuestionData)
            else
                -- 是否需要下行
            end
        end
    end
    local iPid = oPlayer:GetPid()
    local iCorrectCnt = self.m_mAnswerCount[iPid] or 0
    local mNet = {
        cur_round = iRound,
        total_round = iTotal,
        answered = iAnswered,
        state = self:Status(),
        correct_cnt = iCorrectCnt,
    }
    oPlayer:Send("GS2CCampfireQuestionState", mNet)
end
------------------------------------------------


CQuestion = {}
CQuestion.__index = CQuestion
CQuestion.m_iType = QUESTION_TYPE.UNDEFINED
CQuestion.m_sTName = ""
inherit(CQuestion, CComponent)

function CQuestion:New()
    local o = super(CQuestion).New(self)
    return o
end

function CQuestion:Init(iQid, mQInfo)
    self.m_iID = iQid
    self.m_mAnswered = {}
end

function CQuestion:GetLibQuestionData(iQid)
    local mLibData = GetLibData(self.m_sTName)
    if mLibData then
        return mLibData[iQid]
    end
end

function CQuestion:Type()
    return self.m_iType
end

function CQuestion:SetType(iQuestionType)
    self.m_iType = iQuestionType
end

function CQuestion:QId()
    return self.m_iID
end

function CQuestion:PackQuestion()
    return {
        id = self:QId(),
        type = self:Type(),
    }
end

function CQuestion:FillPackData(mQuestionData, iRound, iTotal, iStay)
    mQuestionData.cur_round = iRound
    mQuestionData.total_round = iTotal
    mQuestionData.time = iStay
    return mQuestionData
end

function CQuestion:MakeOrgQuestionNetData(iOrgId, iRound, iTotal, iStay)
    local mQuestionData = self:PackQuestion()
    return self:FillPackData(mQuestionData, iRound, iTotal, iStay)
end

function CQuestion:GetOrgRealQuestion(iOrgId)
    return self
end

function CQuestion:SendToOrg(oOrg, iRound, iTotal, iStay)
    local mQuestionData = self:MakeOrgQuestionNetData(oOrg:OrgID(), iRound, iTotal, iStay)
    if not mQuestionData then
        return
    end
    global.oNotifyMgr:BroadcastOneOrgMembersInScene(oOrg, "GS2CCampfireQuestion", mQuestionData)
end

function CQuestion:BroadcastQuestion(iRound, iTotal, iStay, mOrgs)
    local mQuestionData = self:PackQuestion()
    self:FillPackData(mQuestionData, iRound, iTotal, iStay)
    if not mOrgs then
        mOrgs = global.oOrgMgr:GetNormalOrgs()
    end
    for iOrgId, oOrg in pairs(mOrgs) do
        global.oNotifyMgr:BroadcastOneOrgMembersInScene(oOrg, "GS2CCampfireQuestion", mQuestionData)
    end
end

function CQuestion:Answer(oPlayer, iAnswer, sFillAnswer)
    self:OnAnswer(oPlayer, iAnswer, sFillAnswer)
    local bCorrect = self:IsCorrect(oPlayer, iAnswer, sFillAnswer)
    local iRewardId, mRewardContent
    if bCorrect then
        iRewardId, mRewardContent = self:Correct(oPlayer, iAnswer, sFillAnswer)
    else
        iRewardId, mRewardContent = self:Wrong(oPlayer, iAnswer, sFillAnswer)
    end
    return bCorrect, iRewardId, mRewardContent
end

function CQuestion:HasAnswered(oPlayer)
    return self.m_mAnswered[oPlayer:GetPid()]
end

function CQuestion:OnAnswer(oPlayer, iAnswer, sFillAnswer)
    self.m_mAnswered[oPlayer:GetPid()] = iAnswer or true
end

function CQuestion:Correct(oPlayer, iAnswer, sFillAnswer)
    local oHuodong = self:GetHuodong()
    local iRewardId = GetHuodongConfig("correct_reward")
    return iRewardId, oHuodong:Reward(oPlayer:GetPid(), iRewardId, {})
end

function CQuestion:Wrong(oPlayer, iAnswer, sFillAnswer)
    local oHuodong = self:GetHuodong()
    local iRewardId = GetHuodongConfig("wrong_reward")
    return iRewardId, oHuodong:Reward(oPlayer:GetPid(), iRewardId, {})
end

function CQuestion:IsCorrect(oPlayer, iAnswer, sFillAnswer)
end

function CQuestion:GetCorrectAnswer(oPlayer)
end

function CQuestion:ShowCorrectAnswer(oPlayer, bCorrect, iCorrectCnt)
    local iCorrect = self:GetCorrectAnswer(oPlayer)
    -- if not iCorrect then
    --     -- 需要通知前端关闭界面
    -- end
    oPlayer:Send("GS2CCampfireCorrectAnswer", {
        id = self:QId(),
        answer = iCorrect,
        iscorrect = bCorrect and 1 or 0,
        correct_cnt = iCorrectCnt,
    })
end

------------------------------------------

CChoiceQuestion = {}
CChoiceQuestion.__index = CChoiceQuestion
CChoiceQuestion.m_iType = QUESTION_TYPE.FIXED_CHOICE
CChoiceQuestion.m_sTName = "fixed_choice"
inherit(CChoiceQuestion, CQuestion)

function CChoiceQuestion:New()
    local o = super(CChoiceQuestion).New(self)
    return o
end

function CChoiceQuestion:PackQuestion()
    local mData = super(CChoiceQuestion).PackQuestion(self)
    mData.choices = self:Choices()
    return mData
end

-- 第1项是正确答案，self.m_lChoiceIdxs存的乱序
function CChoiceQuestion:IsCorrect(oPlayer, iAnswer, sFillAnswer)
    return self.m_iCorrectAnswer == iAnswer
end

function CChoiceQuestion:GetCorrectAnswer(oPlayer)
    return self.m_iCorrectAnswer
end

function CChoiceQuestion:Choices()
    return self.m_lChoices
end

function CChoiceQuestion:Init(iQid, mQInfo)
    super(CChoiceQuestion).Init(self, iQid, mQInfo)
    local lChoices = mQInfo.choices
    local lChoiceIdxs = table_key_list(lChoices)
    lChoiceIdxs = extend.Random.random_size(lChoiceIdxs, #lChoiceIdxs)
    self.m_lChoices = {}
    for iAnswer, iChoiceIdx in ipairs(lChoiceIdxs) do
        if iChoiceIdx == 1 then
            self.m_iCorrectAnswer = iAnswer
        end
        table.insert(self.m_lChoices, lChoices[iChoiceIdx])
    end
    -- local lChoices = table_copy(mQInfo.choices)
    -- local iCorrect = math.random(1, #lChoices)
    -- local sCorrect = table.remove(lChoices, 1)
    -- lChoices = extend.Random.random_size(lChoices, #lChoices)
    -- table.insert(lChoices, iCorrect, sCorrect)
    -- self.m_lChoices = lChoices
    -- self.m_iCorrectAnswer = iCorrect
end

------------------------------------------

CCustomChoiceQuestion = {}
CCustomChoiceQuestion.__index = CCustomChoiceQuestion
CCustomChoiceQuestion.m_iType = QUESTION_TYPE.CUSTOM_CHOICE
CCustomChoiceQuestion.m_sTName = "custom_type"
inherit(CCustomChoiceQuestion, CQuestion)

function CCustomChoiceQuestion:New()
    local o = super(CChoiceQuestion).New(self)
    o.m_mValidChoices = {}
    o.m_oBench = nil
    return o
end

function CCustomChoiceQuestion:Init(iQid, mQInfo)
    super(CCustomChoiceQuestion).Init(self, iQid, mQInfo)
    self.m_iCustomTypeId = mQInfo.custom_type
    self.m_iCorrectAnswer = math.random(1, 4)
end

function CCustomChoiceQuestion:SetBench(oBenchQuestion)
    self.m_oBench = oBenchQuestion
end

-- 为动态数据填充值，使之有效
function CCustomChoiceQuestion:SetOrgChoices(iOrgId, sCorrect, lOthers)
    local lOthers = extend.Random.random_size(lOthers, #lOthers)
    table.insert(lOthers, self.m_iCorrectAnswer, sCorrect)
    self.m_mValidChoices[iOrgId] = lOthers
end

function CCustomChoiceQuestion:IsCorrect(oPlayer, iAnswer, sFillAnswer)
    return self.m_iCorrectAnswer == iAnswer
end

function CCustomChoiceQuestion:GetCorrectAnswer(oPlayer)
    return self.m_iCorrectAnswer
end

function CCustomChoiceQuestion:ChoicesByOrg(iOrgId)
    local lChoices = self.m_mValidChoices[iOrgId]
    return lChoices
end

function CCustomChoiceQuestion:GetCustomType()
    return self.m_iCustomTypeId
end

function CCustomChoiceQuestion:PackQuestionByOrg(iOrgId)
    local lChoices = self:ChoicesByOrg(iOrgId)
    if not lChoices then
        return nil
    end
    local mData = self:PackQuestion()
    mData.choices = lChoices
    return mData
end

-- @Override
function CCustomChoiceQuestion:MakeOrgQuestionNetData(iOrgId, iRound, iTotal, iStay)
    local mQuestionData = self:PackQuestionByOrg(iOrgId)
    if mQuestionData then
        self:FillPackData(mQuestionData, iRound, iTotal, iStay)
        return mQuestionData
    end
end

-- @Override
function CCustomChoiceQuestion:BroadcastQuestion(iRound, iTotal, iStay, mOrgs)
    if not mOrgs then
        mOrgs = global.oOrgMgr:GetNormalOrgs()
    end
    local oHuodong = self:GetHuodong()
    local mBenchOrgs = {}
    for iOrgId, oOrg in pairs(mOrgs) do
        local oRealQuestion = self:GetOrgRealQuestion(iOrgId)
        if oRealQuestion == self then
            self:SendToOrg(oOrg, iRound, iTotal, iStay)
        else
            -- 发送替补题目
            oRealQuestion:SendToOrg(oOrg, iRound, iTotal, iStay)
        end
    end
    -- if next(mBenchOrgs) then
    --     local oBenchQuestion = self.m_oBench
    --     if oBenchQuestion then
    --         oBenchQuestion:BroadcastQuestion(iRound, iTotal, iStay, mBenchOrgs)
    --     end
    -- end
end

function CCustomChoiceQuestion:GetOrgRealQuestion(iOrgId)
    local mQuestionData = self:PackQuestionByOrg(iOrgId)
    if mQuestionData then
        return self
    end
    local oBenchQuestion = self.m_oBench
    return oBenchQuestion
end

------------------------------------------

CFillinQuestion = {}
CFillinQuestion.__index = CFillinQuestion
CFillinQuestion.m_iType = QUESTION_TYPE.FILL_IN
CFillinQuestion.m_sTName = "fill_in"
inherit(CFillinQuestion, CQuestion)

function CFillinQuestion:New()
    local o = super(CFillinQuestion).New(self)
    return o
end

function CFillinQuestion:IsCorrect(oPlayer, iAnswer, sFillAnswer)
    local iQid = self:QId()
    local mQInfo = self:GetLibQuestionData(iQid)
    if not mQInfo then
        return false
    end
    return mQInfo.answer == sFillAnswer
end
------------------------------------------
CCampfireMgr = {}
CCampfireMgr.__index = CCampfireMgr
inherit(CCampfireMgr, CComponent)

function CCampfireMgr:New()
    local o = super(CCampfireMgr).New(self)
    o.m_lExpTickingUsers = extend.Queue.create()
    o.m_bActive = false
    return o
end

function CCampfireMgr:SetupCampfires()
    self.m_bSetuped = true

    local iEffectType = GetHuodongConfig("campfireeffect")
    if not iEffectType then
        return
    end
    global.oOrgMgr:AddEvent(self, gamedefines.EVENT.CREATE_ORG, function(iEvType, mData)
        local oMgr = GetHuodong().m_oCampfireMgr
        oMgr:OnOrgCreateSetFire(mData)
    end)
    local mOrgs = global.oOrgMgr:GetNormalOrgs()
    self.m_iCampfireEffectType = iEffectType
    for iOrgId, oOrg in pairs(mOrgs) do
        self:SetOrgCampfire(oOrg, iEffectType)
    end
end

function CCampfireMgr:OnOrgCreateSetFire(mData)
    local oOrg = mData.org
    local iEffectType = self.m_iCampfireEffectType
    if not iEffectType then
        return
    end
    self:SetOrgCampfire(oOrg, iEffectType)
end

function CCampfireMgr:SetOrgCampfire(oOrg, iEffectType)
    local oHuodong = self:GetHuodong()
    local iScene = oOrg:GetOrgSceneID()
    local oScene = global.oSceneMgr:GetScene(iScene)
    local oTempEffect = oHuodong:CreateTempEffect(iEffectType)
    oHuodong:EffectEnterScene(oTempEffect, iScene, oTempEffect:PosInfo())
end

function CCampfireMgr:ClearCampfires()
    if not self.m_bSetuped then
        return
    end
    self.m_bSetuped = nil

    local iEffectType = self.m_iCampfireEffectType
    if not iEffectType then
        return
    end
    local oHuodong = self:GetHuodong()
    oHuodong:RemoveTempEffectByType(iEffectType)

    global.oOrgMgr:DelEvent(self, gamedefines.EVENT.CREATE_ORG)
end

function CCampfireMgr:Prepare()
    self:SetupCampfires()
end

function CCampfireMgr:Clear()
    self:ClearCampfires()
end

function CCampfireMgr:Start()
    self.m_bActive = true
    self:SetExpTickTimer()
end

function CCampfireMgr:SetExpTickTimer()
    self:DelTimeCb("exptick")
    self:AddTimeCb("exptick", EXP_TICK_PREIOD * 1000, function()
        local oMgr = GetHuodong().m_oCampfireMgr
        oMgr:OnExpTick()
    end)
end

function CCampfireMgr:OnExpTick()
    -- 遍历玩家发经验
    if not self:IsActive() then
        self:DelTimeCb("exptick")
        return
    end
    if extend.Queue.qsize(self.m_lExpTickingUsers) > 0 then
        self.m_bExpTickDelayed = true
        return
    end
    self.m_bExpTickDelayed = nil
    self:SetExpTickTimer()
    self:DoTickExp()
end

function CCampfireMgr:DoTickExp()
    local oHuodong = self:GetHuodong()
    local mScenePids = oHuodong:GetInScenePids()
    self:AppendExpUsers(mScenePids)

    if not self:GetTimeCb("touch_exptick_on") then
        self:AddTimeCb("touch_exptick_on", 1, function()
            local oMgr = GetHuodong().m_oCampfireMgr
            oMgr:TouchExpUsersTick()
        end)
    end
end

function CCampfireMgr:AppendExpUsers(mScenePids)
    if not self:IsActive() then
        return
    end
    -- if not self.m_lExpTickingUsers then
    --     self.m_lExpTickingUsers = extend.Queue.create()
    -- end
    for iOrgId, lPids in pairs(mScenePids) do
        extend.Queue.enqueue(self.m_lExpTickingUsers, lPids)
    end
end

function CCampfireMgr:DealSomeUsersExp(iCnt)
    local iW = 5
    iCnt = iCnt * iW
    -- local sExp = GetHuodongConfig("tick_exp")
    -- assert(sExp, "orgcampfire tick_exp unconfiged")
    while iCnt > 0 do
        if extend.Queue.qsize(self.m_lExpTickingUsers) <= 0 then
            return
        end
        local lScenePids = extend.Queue.get_item(self.m_lExpTickingUsers, 1)
        while iCnt > 0 do
            local iPid = table.remove(lScenePids)
            if not iPid then
                extend.Queue.dequeue(self.m_lExpTickingUsers)
                break
            end
            local oPlayer = global.oWorldMgr:GetOnlinePlayerByPid(iPid)
            if oPlayer then
                if self:IsPlayerInHuodong(oPlayer) then
                    safe_call(self.RewardPlayerExp, self, oPlayer)
                    iCnt = iCnt - iW
                end
            else
                iCnt = iCnt - 1
            end
        end
    end
end

function CCampfireMgr:IsPlayerInHuodong(oPlayer)
    if not self:IsActive() then
        return false
    end
    local oHuodong = self:GetHuodong()
    return oHuodong:IsHuodongUser(oPlayer)
end

function CCampfireMgr:RewardPlayerExp(oPlayer)
    local oHuodong = self:GetHuodong()
    local iRewardId = GetHuodongConfig("campfire_tick_reward")
    local iBuffAdds = oHuodong:GetBuffAdds(oPlayer)
    local mRewardContent = oHuodong:Reward(oPlayer:GetPid(), iRewardId, {argenv = {buff_add_rate = (iBuffAdds / 100)}})
    local iExp = 0
    if mRewardContent then
        iExp = mRewardContent.exp or 0
    end
    -- local iExp = math.floor(formula_string(sExp, {buff_add_rate = (iBuffAdds / 100), lv = oPlayer:GetGrade()}))
    if iExp > 0 then
        local mLogData = oPlayer:LogData()
        mLogData.exp = iExp
        mLogData.adds = iBuffAdds
        record.user("huodong", "campfire_reward_fire_exp", mLogData)
        -- oHuodong:RewardExp(oPlayer, iExp)
    end
end

function CCampfireMgr:TouchExpUsersTick()
    if self:GetTimeCb("exptick_user") then
        return
    end
    if not self:IsActive() then
        return
    end
    self:DealSomeUsersExp(50)
    -- 做完部分角色，检查后面是否继续
    if extend.Queue.qsize(self.m_lExpTickingUsers) > 0 then
        self:DelTimeCb("exptick_user")
        self:AddTimeCb("exptick_user", 200, function()
            local oMgr = GetHuodong().m_oCampfireMgr
            oMgr:TouchExpUsersTick()
        end)
    else
        -- self.m_bExpUsersTicking = nil
        -- 所有人的经验发完，并且已经延迟过，立刻下一跳
        if self.m_bExpTickDelayed then
            self:OnExpTick()
        end
    end
end

function CCampfireMgr:IsActive()
    return self.m_bActive
end

function CCampfireMgr:End()
    self.m_bActive = false
    self.m_bExpTickDelayed = nil
    -- self.m_bExpUsersTicking = nil
    extend.Queue.clear(self.m_lExpTickingUsers)
    self:DelTimeCb("exptick")
    self:DelTimeCb("exptick_user")
    self:ClearCampfires()
end

------------------------------------------
CDrinkMgr = {}
CDrinkMgr.__index = CDrinkMgr
inherit(CDrinkMgr, CComponent)

function CDrinkMgr:New()
    local o = super(CDrinkMgr).New(self)
    o.m_mDrinkCnt = {}
    o.m_mDrinkPersonCnt = {}
    return o
end

function CDrinkMgr:CanDrink(oPlayer, iAmount)
    local oHuodong = self:GetHuodong()
    if oHuodong:IsEnd() then
        return false, ERR.HUODONG_STOPED
    end
    local iOrgId = oPlayer:GetOrgID()
    if not iOrgId or iOrgId == 0 then
        return false, ERR.NO_ORG
    end
    if not oHuodong:IsHuodongUser(oPlayer) then
        return false, ERR.NOT_HUODONG_USER
    end
    local iCurOrgDrinkAmount = self:GetDrinkAmount(iOrgId)
    local iMaxOrgDrink = GetHuodongConfig("max_org_drink")
    if iCurOrgDrinkAmount >= iMaxOrgDrink then
        return false, ERR.FULLED
    end
    local iCanForOrg = iMaxOrgDrink - iCurOrgDrinkAmount
    local iPersonLimit = GetHuodongConfig("max_user_drink")
    local iCanForPerson = 999999
    if iPersonLimit and iPersonLimit > 0 then
        iCanForPerson = iPersonLimit - self:GetPersonDrinkAmount(oPlayer:GetPid())
        if iCanForPerson < iAmount then
            return false, ERR.OVER_PERSON_LIMIT, math.min(iCanForOrg, iCanForPerson)
        end
    end
    if iCanForOrg < iAmount then
        return false, ERR.OVER_AMOUNT, math.min(iCanForOrg, iCanForPerson)
    end
    return true
end

function CDrinkMgr:Purchase(oPlayer, iAmount, oOnlyItem)
    local iSid = GetHuodongConfig("drink_item")
    assert(iSid and iSid > 0, "orgcampfire drink_item unconfiged")
    local mConfig = global.oItemLoader:GetItemData(iSid)
    assert(mConfig, "orgcampfire drink_price unconfiged")
    local iDrinkPrice = mConfig.buyPrice
    assert(iDrinkPrice and iDrinkPrice > 0, "orgcampfire drink_price unconfiged")
    local iHasAmount = oPlayer.m_oItemCtrl:GetItemAmount(iSid, true)
    local iSubAmount, iGoldcoinAmount = 0, 0
    if iHasAmount > iAmount then
        iSubAmount, iGoldcoinAmount = iAmount, 0
    else
        iSubAmount = iHasAmount
        iGoldcoinAmount = iAmount - iSubAmount
    end
    local iGoldcoinPrice = iGoldcoinAmount * iDrinkPrice
    if iGoldcoinAmount > 0 then
        if not oPlayer:ValidMoneyByType(gamedefines.MONEY_TYPE.GOLDCOIN, iGoldcoinPrice) then
            -- self:NotifyErr(oPlayer, ERR.LACK_GOLD_COIN)
            return false
        end
    end

    if iSubAmount > 0 then
        if oOnlyItem then
            local iItemAmount = oOnlyItem:GetAmount()
            if iItemAmount < iSubAmount then
                oPlayer:RemoveOneItemAmount(oOnlyItem, iItemAmount, "orgcampfire drink")
                oPlayer:RemoveItemAmount(iSid, iSubAmount - iItemAmount, "orgcampfire drink")
            else
                oPlayer:RemoveOneItemAmount(oOnlyItem, iSubAmount, "orgcampfire drink")
            end
        else
            oPlayer:RemoveItemAmount(iSid, iSubAmount, "orgcampfire drink")
        end
    end
    if iGoldcoinPrice > 0 then
        oPlayer:ResumeMoneyByType(gamedefines.MONEY_TYPE.GOLDCOIN, iGoldcoinPrice, "orgcampfire drink")
    end
    local mLogData = oPlayer:LogData()
    mLogData.sub_item_amount = iSubAmount
    mLogData.item = iSid
    mLogData.sub_goldcoin = iGoldcoinPrice
    mLogData.drink_amount = iAmount
    record.user("huodong", "campfire_drink_purchase", mLogData)
    return true
end

function CDrinkMgr:CheckCanUseDrinkItem(oPlayer, oItem)
    local bCan, iErr, xArg = self:CanDrink(oPlayer, 1)
    if not bCan then
        local sMsg
        if iErr == ERR.HUODONG_STOPED then
            sMsg = global.oToolMgr:FormatColorString(GetTextData(1101), {item = oItem:TipsName()})
            oPlayer:NotifyMessage(sMsg)
        elseif iErr == ERR.NO_ORG then
            sMsg = global.oToolMgr:FormatColorString(GetTextData(1102), {item = oItem:TipsName()})
            oPlayer:NotifyMessage(sMsg)
        elseif iErr == ERR.NOT_HUODONG_USER then
            sMsg = global.oToolMgr:FormatColorString(GetTextData(1103), {item = oItem:TipsName()})
            oPlayer:NotifyMessage(sMsg)
        else
            self:NotifyErr(oPlayer, iErr, xArg)
        end
        return false
    end
    return true
end

function CDrinkMgr:DoDrinkItem(oPlayer, oItem, iAmount)
    if iAmount > oItem:GetAmount() then
        oPlayer:NotifyMessage("使用数量不足")
        return
    end
    local oOrg = oPlayer:GetOrg()
    if not oOrg then
        self:NotifyErr(oPlayer, ERR.NO_ORG)
        return
    end
    if not self:Purchase(oPlayer, iAmount, oItem) then
        return
    end
    self:DoDrinkEffect(oPlayer, iAmount)
end

function CDrinkMgr:DoDrinkAmount(oPlayer, iAmount)
    local oOrg = oPlayer:GetOrg()
    if not oOrg then
        self:NotifyErr(oPlayer, ERR.NO_ORG)
        return
    end
    if not self:Purchase(oPlayer, iAmount) then
        return
    end
    self:DoDrinkEffect(oPlayer, iAmount)
end

function CDrinkMgr:DoDrinkEffect(oPlayer, iAmount)
    local iPid = oPlayer:GetPid()
    local oOrg = oPlayer:GetOrg()
    assert(oOrg, "DoDrinkEffect without org, pid:%d", iPid)
    local iOrgId = oOrg:OrgID()
    -- 记录次数
    self.m_mDrinkCnt[iOrgId] = (self.m_mDrinkCnt[iOrgId] or 0) + iAmount
    self.m_mDrinkPersonCnt[iPid] = (self.m_mDrinkPersonCnt[iPid] or 0) + iAmount
    -- 通知
    local iDrinkBuffAdds = self:GetDrinkBuffAdds(iOrgId)
    local mNet = {drink_buff_adds = iDrinkBuffAdds}
    mNet = net.Mask("GS2CCampfireInfo", mNet)
    global.oNotifyMgr:BroadcastOneOrgMembersInScene(oOrg, "GS2CCampfireInfo", mNet)
    local sText = GetTextData(2001)
    local sMsg = global.oToolMgr:FormatColorString(sText, {
        role = oPlayer:GetName(),
        amount = iAmount,
        item = global.oItemLoader:GetItemNameBySid(GetHuodongConfig("drink_item")),
        adds = (iDrinkBuffAdds) .. "%",
    })
    global.oNotifyMgr:SendOrgChat(sMsg, iOrgId, {pid = 0})
    -- 奖励
    local oHuodong = self:GetHuodong()
    local iRewardId = GetHuodongConfig("drink_reward")
    local mRewardContent = oHuodong:Reward(iPid, iRewardId, {reward_check_cnt = iAmount, argenv = {cnt = iAmount}})
    local iTotalDrinkRewardOrgOffer = 0
    if mRewardContent then
        iTotalDrinkRewardOrgOffer = mRewardContent.org_offer or 0
    end
    -- local iDrinkRewardOrgOffer = GetHuodongConfig("drink_reward_orgoffer")
    -- local iTotalDrinkRewardOrgOffer = iDrinkRewardOrgOffer * iAmount
    -- oHuodong:RewardOrgOffer(oPlayer, iTotalDrinkRewardOrgOffer)

    local mLogData = oPlayer:LogData()
    mLogData.orgid = iOrgId
    mLogData.drink_person_cnt = self.m_mDrinkPersonCnt[iPid]
    mLogData.drink_org_cnt = self.m_mDrinkCnt[iOrgId]
    mLogData.drink_amount = iAmount
    mLogData.reward_orgoffer = iTotalDrinkRewardOrgOffer
    record.user("huodong", "campfire_drink_reward", mLogData)
end

function CDrinkMgr:CallDrink(oPlayer, iAmount)
    if not iAmount or iAmount <= 0 then
        return
    end
    local bCan, iErr, xArg = self:CanDrink(oPlayer, iAmount)
    if not bCan then
        self:NotifyErr(oPlayer, iErr, xArg)
        return
    end
    self:DoDrinkAmount(oPlayer, iAmount)
end

function CDrinkMgr:CallUseDrinkItem(oPlayer, oItem, iAmount)
    if not self:CheckCanUseDrinkItem(oPlayer, oItem) then
        return
    end
    self:DoDrinkItem(oPlayer, oItem, 1)
end

function CDrinkMgr:Clear()
    self.m_mDrinkCnt = {}
    self.m_mDrinkPersonCnt = {}
end

function CDrinkMgr:IsDrinkFulled(iOrgId)
    return self:GetDrinkAmount(iOrgId) >= GetHuodongConfig("max_org_drink")
end

function CDrinkMgr:GetDrinkBuffAdds(iOrgId)
    return self:GetDrinkAmount(iOrgId) * GetHuodongConfig("adds_per_drink")
end

function CDrinkMgr:GetPersonDrinkAmount(pid)
    return self.m_mDrinkPersonCnt[pid] or 0
end

function CDrinkMgr:GetDrinkAmount(iOrgId)
    if not iOrgId or iOrgId == 0 then
        return 0
    else
        return self.m_mDrinkCnt[iOrgId] or 0
    end
end

------------------------------------------
CTieMgr = {}
CTieMgr.__index = CTieMgr
inherit(CTieMgr, CComponent)

function CTieMgr:New()
    local o = super(CTieMgr).New(self)
    o.m_mGiveTimes = {}
    o.m_mReceiveTimes = {}
    o.m_mReceiveFrom = {}
    return o
end

function CTieMgr:Clear()
    self.m_mGiveTimes = {}
    self.m_mReceiveTimes = {}
    self.m_mReceiveFrom = {}
end

function CTieMgr:End()
    self:Clear()
end

function CTieMgr:CanGive(oPlayer)
    if (self.m_mGiveTimes[oPlayer:GetPid()] or 0) >= GetHuodongConfig("tie_give_limit") then
        return false, ERR.OVER_GIVE_LIMIT
    end
    return true
end

function CTieMgr:CanReceive(oPlayer)
    if (self.m_mReceiveTimes[oPlayer:GetPid()] or 0) >= GetHuodongConfig("tie_receive_limit") then
        return false, ERR.OVER_RECEIVE_LIMIT
    end
    return true
end

function CTieMgr:ValidHuodongUser(oPlayer)
    local iOrgId = oPlayer:GetOrgID()
    if not iOrgId or iOrgId == 0 then
        return false, ERR.NO_ORG
    end
    local oHuodong = self:GetHuodong()
    if oHuodong:IsEnd() then
        return false, ERR.HUODONG_STOPED
    end
    if not oHuodong:IsHuodongUser(oPlayer) then
        return false, ERR.NOT_HUODONG_USER
    end
    return true
end

function CTieMgr:ValidGive(oPlayer, oTarget, bThankOnly)
    if oPlayer:GetOrgID() ~= oTarget:GetOrgID() then
        return false, ERR.DIFF_ORG
    end
    local iCan, iErr = self:ValidHuodongUser(oPlayer)
    if not iCan then
        return false, iErr
    end
    local oHuodong = self:GetHuodong()
    if not oHuodong:IsHuodongUser(oTarget) then
        return false, ERR.TARGET_NOT_HUODONG_USER
    end
    if not bThankOnly then
        local iCan, iErr = self:CanGive(oPlayer)
        if not iCan then
            return false, iErr
        end
        local iCan, iErr = self:CanReceive(oTarget)
        if not iCan then
            return false, iErr
        end
    end
    return true
end

function CTieMgr:ValidQueryToGive(oPlayer)
    local oHuodong = self:GetHuodong()
    if oHuodong:IsEnd() then
        return false, ERR.HUODONG_STOPED
    end
    local iCan, iErr = self:ValidHuodongUser(oPlayer)
    if not iCan then
        return false, iErr
    end
    local iCan, iErr = self:CanGive(oPlayer)
    if not iCan then
        return false, iErr
    end
    return true
end

function CTieMgr:ValidGiveTo(oPlayer, iTarget, bThankOnly)
    local iPid = oPlayer:GetPid()
    if iPid == iTarget then
        return false, ERR.TARGET_SELF
    end
    local oTarget = global.oWorldMgr:GetOnlinePlayerByPid(iTarget)
    if not oTarget then
        return false, ERR.TARGET_OFFLINE
    end
    return self:ValidGive(oPlayer, oTarget, bThankOnly)
end

function CTieMgr:Purchase(oPlayer, oOnlyItem)
    local oNotifyMgr = global.oNotifyMgr
    -- 物品/元宝检查
    local iSid = GetHuodongConfig("tie_item")
    assert(iSid and iSid > 0, "orgcampfire tie_item unconfiged")
    local mConfig = global.oItemLoader:GetItemData(iSid)
    assert(mConfig, "orgcampfire tie_price unconfiged")
    local iTiePrice = mConfig.buyPrice
    assert(iTiePrice and iTiePrice > 0, "orgcampfire tie_price unconfiged")
    local iHasAmount = oPlayer.m_oItemCtrl:GetItemAmount(iSid, true)
    local iSubAmount, iGoldcoinAmount = 1, 0
    if iHasAmount <= 0 then
        iSubAmount, iGoldcoinAmount = 0, 1
        -- self:NotifyErr(oPlayer, ERR.NO_TIE_ITEM)
        -- return
    end
    local iGoldcoinPrice = iGoldcoinAmount * iTiePrice
    if iGoldcoinAmount > 0 then
        if not oPlayer:ValidMoneyByType(gamedefines.MONEY_TYPE.GOLDCOIN, iGoldcoinPrice) then
            return false
        end
    end
    if iSubAmount > 0 then
        -- 扣除物品
        oPlayer:RemoveItemAmount(iSid, iSubAmount, "orgcampfire give_tie")
    end
    if iGoldcoinPrice > 0 then
        oPlayer:ResumeMoneyByType(gamedefines.MONEY_TYPE.GOLDCOIN, iGoldcoinPrice, "orgcampfire give_tie")
    end
    local mLogData = oPlayer:LogData()
    mLogData.sub_item_amount = iSubAmount
    mLogData.item = iSid
    mLogData.sub_goldcoin = iGoldcoinPrice
    record.user("huodong", "campfire_tie_purchase", mLogData)
    return true
end

function CTieMgr:CallGive(oPlayer, iTarget, bQuick)
    -- 目标检查
    local iPid = oPlayer:GetPid()
    local oTarget = global.oWorldMgr:GetOnlinePlayerByPid(iTarget)
    local bCan, iErr = self:ValidGiveTo(oPlayer, iTarget)
    if not bCan then
        self:NotifyErr(oPlayer, iErr)
        return
    end
    if not self:Purchase(oPlayer) then
        return
    end
    self:DoTieEffect(oPlayer, oTarget, bQuick)
end

function CTieMgr:DoTieEffect(oPlayer, oTarget, bQuick)
    local iPid = oPlayer:GetPid()
    local iTarget = oTarget:GetPid()
    -- 记录
    self.m_mGiveTimes[iPid] = (self.m_mGiveTimes[iPid] or 0) + 1
    self.m_mReceiveTimes[iTarget] = (self.m_mReceiveTimes[iTarget] or 0) + 1
    table_set_depth(self.m_mReceiveFrom, {iTarget}, iPid, 1)
    -- 发奖
    local iGiverExp = self:RewardPlayerExp(oPlayer)
    local iReceiverExp = self:RewardPlayerExp(oTarget)

    local mLogData = {
        giver = iPid,
        receiver = iTarget,
        isquick = bQuick,
        giver_exp = iGiverExp,
        receiver_exp = iReceiverExp,
        giver_gived_cnt = self.m_mGiveTimes[iPid],
        receiver_received_cnt = self.m_mReceiveTimes[iTarget],
    }
    record.log_db("huodonginfo", "campfire_give_tie", mLogData)

    -- 无论是否快速答谢都需要弹窗
    local mNet = {
        fromer = iPid,
        fromer_name = oPlayer:GetName(),
        exp = iReceiverExp,
    }
    oTarget:Send("GS2CCampfireGotGift", mNet)
    self:SyncGiftTimes(oPlayer)
    self:SyncGiftTimes(oTarget)
end

function CTieMgr:FilterSceneGiftables(oPlayer, oOrg, pid)
    local bCan, iErr = self:ValidGiveTo(oPlayer, pid)
    if not bCan then
        return nil
    end
    local oTarget = global.oWorldMgr:GetOnlinePlayerByPid(pid)
    return {
        pid = pid,
        name = oTarget:GetName(),
        icon = oTarget:GetIcon(),
        grade = oTarget:GetGrade(),
        title_info = oTarget:GetTitleInfo(),
        org_pos = oOrg:GetPosition(pid),
    }
end

function CTieMgr:OnQuerySceneGiftables(iPid, lPids)
    local oPlayer = global.oWorldMgr:GetOnlinePlayerByPid(iPid)
    if not oPlayer then
        return
    end
    local oOrg = oPlayer:GetOrg()
    if not oOrg then
        self:NotifyErr(oPlayer, ERR.NO_ORG)
        return
    end
    local iQueryAmount = GetHuodongConfig("tie_query_player_amount")
    if not iQueryAmount then
        iQueryAmount = GIFTABLE_PLAYER_CNT
    elseif iQueryAmount <= 0 then
        iQueryAmount = GIFTABLE_PLAYER_CNT
    elseif iQueryAmount > GIFTABLE_PLAYER_CNT_MAX then
        iQueryAmount = GIFTABLE_PLAYER_CNT_MAX
    end
    local mGiftablePlayers = extend.Table.randomfiltermap(lPids, iQueryAmount, function(_, pid)
        return self:FilterSceneGiftables(oPlayer, oOrg, pid)
    end)
    self:SyncGiftTimes(oPlayer)
    oPlayer:Send("GS2CCampfireShowGiftables", {
        players = table_value_list(mGiftablePlayers),
    })
end

function CTieMgr:SyncGiftTimes(oPlayer)
    local iPid = oPlayer:GetPid()
    oPlayer:Send("GS2CCampfireGiftTimes", {
        given_times = self.m_mGiveTimes[iPid] or 0,
        give_times_limit = GetHuodongConfig("tie_give_limit") or 0,
        received_times = self.m_mReceiveTimes[iPid] or 0,
        receive_times_limit = GetHuodongConfig("tie_receive_limit") or 0,
    })
end

function CTieMgr:CheckCanUseTieItem(oPlayer, oItem)
    local bCan, iErr = self:ValidQueryToGive(oPlayer)
    if not bCan then
        local sMsg
        if iErr == ERR.HUODONG_STOPED then
            sMsg = global.oToolMgr:FormatColorString(GetTextData(1101), {item = oItem:TipsName()})
            oPlayer:NotifyMessage(sMsg)
        elseif iErr == ERR.NO_ORG then
            sMsg = global.oToolMgr:FormatColorString(GetTextData(1102), {item = oItem:TipsName()})
            oPlayer:NotifyMessage(sMsg)
        elseif iErr == ERR.NOT_HUODONG_USER then
            sMsg = global.oToolMgr:FormatColorString(GetTextData(1103), {item = oItem:TipsName()})
            oPlayer:NotifyMessage(sMsg)
        else
            self:NotifyErr(oPlayer, iErr)
        end
        return false
    end
    return true
end

function CTieMgr:CallUseTieItem(oPlayer, oItem, iAmount)
    if not self:CheckCanUseTieItem(oPlayer, oItem) then
        return
    end
    self:QueryGiftables(oPlayer)
end

-- TODO 需要考虑缓存式优化方案、可以使用新的service
function CTieMgr:QueryGiftables(oPlayer)
    -- 点击频繁拦截处理 TODO
    local bCan, iErr = self:ValidQueryToGive(oPlayer)
    if not bCan then
        self:NotifyErr(oPlayer, iErr)
        return
    end
    local iPid = oPlayer:GetPid()
    local oOrg = oPlayer:GetOrg()
    local iScene = oOrg:GetOrgSceneID()
    local oScene = global.oSceneMgr:GetScene(iScene)
    -- FIXME 活动内玩家改为玩家注册记录在world服，不去scene服异步查询
    oScene:QueryRemote("all_players", {}, function (mRecord, mData)
        local oMgr = GetHuodong().m_oTieMgr
        oMgr:OnQuerySceneGiftablePlayers(mRecord, iPid, mData)
    end)
end

function CTieMgr:OnQuerySceneGiftablePlayers(mRecord, iPid, mData)
    local m = mData.data
    local lPids
    if m then
        lPids = m.pids
    else
        lPids = {}
    end
    self:OnQuerySceneGiftables(iPid, lPids)
end

function CTieMgr:ThankGift(oPlayer, iTargetId)
    local iPid = oPlayer:GetPid()
    if not table_get_depth(self.m_mReceiveFrom, {iTargetId, iPid}) then
        return
    end
    local oTarget = global.oWorldMgr:GetOnlinePlayerByPid(iTargetId)
    if not oTarget then
        return
    end
    local iCan, iErr = self:ValidGiveTo(oPlayer, iTargetId, true)
    if not iCan then
        return
    end
    oTarget:Send("GS2CCampfireThankGift", {
        thanker = iPid,
        thanker_name = oPlayer:GetName(),
    })
end

function CTieMgr:RewardPlayerExp(oPlayer)
    local oHuodong = self:GetHuodong()
    local iRewardId = GetHuodongConfig("tie_reward")
    local mRewardContent = oHuodong:Reward(oPlayer:GetPid(), iRewardId, {})
    if mRewardContent then
        return mRewardContent.exp or 0
    end
    return 0
    -- local sExp = GetHuodongConfig("tie_exp")
    -- local iExp = math.floor(formula_string(sExp, oHuodong:GetRewardEnv(oPlayer)))
    -- if iExp > 0 then
    --     oHuodong:RewardExp(oPlayer, iExp)
    -- end
    -- return iExp
end

------------------------------------------
