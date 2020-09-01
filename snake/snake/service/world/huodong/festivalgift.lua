local global = require "global"
local res = require "base.res"
local extend = require "base.extend"
local record = require "public.record"

local huodongbase = import(service_path("huodong.huodongbase"))
local rewardmonitor = import(service_path("rewardmonitor"))
local gamedefines = import(lualib_path("public.gamedefines"))

function NewHuodong(sHuodongName)
    return CHuodong:New(sHuodongName)
end

CHuodong = {}
CHuodong.__index = CHuodong
CHuodong.m_sTempName = "节日礼包"
inherit(CHuodong, huodongbase.CHuodong)

function CHuodong:New(sHuodongName)
    local o = super(CHuodong).New(self, sHuodongName)
    o.m_iScheduleId = 1037
    return o
end

-- m_mFestivalInfo = { id : id  }
-- m_mNextFestivalInfo = { id : id }
function CHuodong:Init()
    self.m_mFestivalInfo = {}
    self.m_mNextFestivalInfo = {}
end

function CHuodong:NeedSave()
    return true
end

function CHuodong:Save()
    local mData = {}
    mData.year = self.m_iYear
    return mData
end

-- 初始为2018年
function CHuodong:Load(mData)
    mData = mData or {}
    self.m_iYear = mData.year or 2018
    local mNow = get_timetbl()
    self:InitCurFestival(mNow)
    self:InitNextFestival(mNow)
end

function CHuodong:MergeFrom(mFromData)
    return true
end

function CHuodong:GetDateToNumber(mNow)
    mNow = mNow or get_timetbl()
    return tonumber(mNow.date.month) * 100 + tonumber(mNow.date.day)
end

function CHuodong:GetNumberToDate(iDate)
    local mDate = {}
    local iMod
    mDate.month = iDate // 100
    iMod = iDate % 100
    mDate.day = iMod
    return mDate
end

function CHuodong:SetHuodongStateStart(sTime, iOpenTimestamp)
    global.oHuodongMgr:SetHuodongState(self.m_sName, self.m_iScheduleId, gamedefines.ACTIVITY_STATE.STATE_START, sTime, iOpenTimestamp)
end

function CHuodong:SetHuodongStateEnd(sTime, iOpenTimestamp)
    global.oHuodongMgr:SetHuodongState(self.m_sName, self.m_iScheduleId, gamedefines.ACTIVITY_STATE.STATE_END, sTime, iOpenTimestamp)
end

function CHuodong:InitCurFestival(mNow)
    local bOldFestival = nil
    if next(self.m_mFestivalInfo) then
        bOldFestival = true
    end

    self.m_mFestivalInfo = {}
    mNow = mNow or get_timetbl()
    if mNow.date.year > self.m_iYear then
        self.m_iYear = self.m_iYear + 1
        self:Dirty()
    end
    local iDate = self:GetDateToNumber(mNow)
    local mRewardConfig = self:GetRewardConfig()
    for _, mFestival in ipairs(mRewardConfig) do
        if mFestival.start_date <= iDate and mFestival.end_date >= iDate then
            self.m_mFestivalInfo[mFestival.id] = mFestival.id
        end
    end

    if next(self.m_mFestivalInfo) then
        self:SetHuodongStateStart("全天", nil)
        self:NotifyOnlinePlayer()
    else
        if bOldFestival then
            self:SetHuodongStateEnd("全天", nil)
        end
    end
end

function CompStartDate(a, b)
    return a.start_date < b.start_date
end

function CHuodong:InitNextFestival(mNow)
    self.m_mNextFestivalInfo = {}
    mNow = mNow or get_timetbl()
    local iDate = self:GetDateToNumber(mNow)
    local lNextFestivalDate = self:GetNextFestivalDateList(iDate)
    table.sort(lNextFestivalDate, CompStartDate)
    local mNextDate = lNextFestivalDate[1]
    for _, mNextFestivalDate in ipairs(lNextFestivalDate) do
        if mNextFestivalDate.start_date == mNextDate.start_date then
            self.m_mNextFestivalInfo[mNextFestivalDate.id] = mNextFestivalDate.id
        end
    end
end

function CHuodong:NewHour(mNow)
    local iHour = mNow.date.hour
    if iHour == 0 then
        self:NewHour0(mNow)
    end
end

function CHuodong:NewHour0(mNow)
    mNow = mNow or get_timetbl()
    self:InitCurFestival(mNow)
    self:InitNextFestival(mNow)
end

function CHuodong:RefreshPlayerSchedule(pid)
    local oPlayer = global.oWorldMgr:GetOnlinePlayerByPid(pid)
    if oPlayer then
        if not self:ValidFestival() then
            oPlayer.m_oScheduleCtrl:DeleteSchedule(self.m_iScheduleId)
        else
            oPlayer.m_oScheduleCtrl:CreateSchedule(self.m_iScheduleId)
        end
    end
end

function CHuodong:NotifyOnlinePlayer()
    local lAllOnlinePid = {}
    for _,oPlayer in pairs(global.oWorldMgr:GetOnlinePlayerList()) do
        table.insert(lAllOnlinePid, oPlayer:GetPid())
    end
    local FunRefresh = function(pid)
        self:RefreshPlayerSchedule(pid)
    end
    global.oToolMgr:ExecuteList(lAllOnlinePid, 500, 500, 0, "festivalgiftNewHour0", FunRefresh)
end

function CHuodong:OnLogin(oPlayer, bReEnter)
    if not self:ValidFestival() then
        oPlayer.m_oScheduleCtrl:DeleteSchedule(self.m_iScheduleId)
    else
        oPlayer.m_oScheduleCtrl:CreateSchedule(self.m_iScheduleId)
    end
end

function CHuodong:ValidFestival()
    if next(self.m_mFestivalInfo) then
        return true
    else
        return false
    end
end

-- 等级不足条件要单独做一次
function CHuodong:ValidGetFestivalGift(oPlayer)
    local oToolMgr = global.oToolMgr
    if not oToolMgr:IsSysOpen("FESTIVALGIFT",oPlayer, true) then
        if  oToolMgr:GetSysOpenPlayerGrade("FESTIVALGIFT") > oPlayer:GetGrade() then
            return false, 1003
        end
        return false, 1001
    end
    if not self:ValidFestival() then
        return false, 1001
    end
    local mRewardConfig = self:GetRewardConfig()
    local bIsRewarded = true
    for _, iKey in pairs(self.m_mFestivalInfo) do
        if not self:IsPlayerRewarded(oPlayer, iKey) then
            bIsRewarded = false
        end
    end
    if bIsRewarded then
        return false, 1002
    end
    return true, 1004
end

function CHuodong:GetHuodongTextData(oPlayer, iText)
    local sRetText
    if iText == 1001 or iText == 1002 then
        sRetText = self:GetTextData(iText)
    elseif iText == 1003 then
        sRetText = self:GetTextData(iText)
        local iOpenGrade = global.oToolMgr:GetSysOpenPlayerGrade("FESTIVALGIFT")
        sRetText = global.oToolMgr:FormatColorString(sRetText, {grade = iOpenGrade})
    elseif iText == 1004 then
        sRetText = self:GetCurFestivalDialog()
    elseif iText == 1005 then
        sRetText = self:GetNextFestivalDialog()
    end
    return sRetText
end

function CHuodong:GetFestivalGift(oPlayer)
    local bIsFestival, iText = self:ValidGetFestivalGift(oPlayer)
    if not bIsFestival then
        if not iText then
            local sText = self:GetHuodongTextData(oPlayer,iText)
            global.oNotifyMgr:Notify(oPlayer:GetPid(), sText)
        end
        return
    end
    local mRewardConfig = self:GetRewardConfig()

    -- 不允许进入临时背包
    local lItemList = {}
    local lItemIdx = {}
    for _, iKey in pairs(self.m_mFestivalInfo) do
        if not self:IsPlayerRewarded(oPlayer, iKey) then
            local lCurFestivalItemIdx = self:RewardId2ItemIdx(mRewardConfig[iKey].reward_id)
            for _, iItemIdx in pairs(lCurFestivalItemIdx) do
                local mItemUnit = self:InitRewardItem(oPlayer, iItemIdx, {})
                list_combine(lItemList, mItemUnit["items"])
            end
            list_combine(lItemIdx, lCurFestivalItemIdx)
        end
    end
    if next(lItemList) then
        local pid = oPlayer:GetPid()
        if not oPlayer:ValidGiveitemlist(lItemList, {cancel_tip = false}) then
            return
        end
    end

    for _, iKey in pairs(self.m_mFestivalInfo) do
        self:SetPlayerRewarded(oPlayer,iKey)
        local iRewardId = mRewardConfig[iKey].reward_id
        local mLogData = {}
        mLogData.reward_id = iRewardId
        mLogData.fest_date = mRewardConfig[iKey].date
        mLogData.fest_name = mRewardConfig[iKey].name
        record.log_db("huodong", "festivalgift_rewarded", {pid = oPlayer:GetPid(), info = mLogData})
        self:Reward(oPlayer:GetPid(), iRewardId)
    end
    oPlayer.m_oScheduleCtrl:RefreshSchedule(self.m_iScheduleId)
end

function CHuodong:IsPlayerRewarded(oPlayer, iKey)
    local mGiftInfo = oPlayer:Query(self:GetSaveKey(),{})
    local mRewardConfig = self:GetRewardConfig()
    local sName = mRewardConfig[iKey].sname
    if not mGiftInfo[sName] or mGiftInfo[sName] < self.m_iYear then
        return false
    else
        return true
    end
end

function CHuodong:SetPlayerRewarded(oPlayer, iKey)
    local mGiftInfo = oPlayer:Query(self:GetSaveKey(),{})
    local mRewardConfig = self:GetRewardConfig()
    local sName = mRewardConfig[iKey].sname
    if not mGiftInfo[sName] or mGiftInfo[sName] < self.m_iYear then
        mGiftInfo[sName] = self.m_iYear
        oPlayer:Set(self:GetSaveKey(), mGiftInfo)
    end
end

function CHuodong:GetCurFestivalDialog()
    if next(self.m_mFestivalInfo) then
        local mRewardConfig = self:GetRewardConfig()
        local mName = {}
        local iDate
        for _, iKey in pairs(self.m_mFestivalInfo) do
            local mFestival = mRewardConfig[iKey]
            table.insert(mName, mFestival.name)
        end
        local sName = table.concat(mName, "、")
        local sText = self:GetTextData(1004)
        return global.oToolMgr:FormatColorString(sText, { festival = sName})
    else
        return self:GetTextData(1001)
    end
end

function CHuodong:GetNextFestivalDialog()
    if next(self.m_mNextFestivalInfo) then
        local mRewardConfig = self:GetRewardConfig()
        local mName = {}
        local iDate
        for _, iKey in pairs(self.m_mNextFestivalInfo) do
            local mFestival = mRewardConfig[iKey]
            table.insert(mName, mFestival.name)
            iDate = mFestival.start_date
        end
        local sName = table.concat(mName, "、")
        local mDate = self:GetNumberToDate(iDate)
        local sDate = tostring(mDate.month) .. "月" .. tostring(mDate.day) .. "日"
        local sText = self:GetTextData(1005)
        local iOpenGrade = global.oToolMgr:GetSysOpenPlayerGrade("FESTIVALGIFT")
        return global.oToolMgr:FormatColorString(sText, {date = sDate, festival = sName, grade = iOpenGrade})
    else
        return self:GetTextData(1006)
    end
end

function CHuodong:GetSaveKey()
    return "festivalgift_endtime"
end

function CHuodong:GetConfig()
    return nil
end

function CHuodong:RewardId2ItemIdx(iRewardId)
    local mReward = res["daobiao"]["reward"]["festivalgift"]["reward"]
    return mReward[iRewardId].item
end

function CHuodong:GetRewardConfig()
    local mRewardConfig = res["daobiao"]["huodong"]["festivalgift"]["reward"]
    return mRewardConfig
end

function CHuodong:GetNextFestivalDateList(iDate)
    local mRewardConfig = self:GetRewardConfig()
    local lStartDate = {}
    for index, mFestival in pairs(mRewardConfig) do
        if mFestival.start_date > iDate then
            table.insert(lStartDate, { start_date = mFestival.start_date, id = mFestival.id})
        end
    end
    -- 跨年,需要新表，默认节日为 1月 1日 元旦
    if not next(lStartDate) then
        for id, mValue in ipairs(mRewardConfig) do
            if mValue.sname == "yuandan" then
                table.insert(lStartDate,{start_date = mValue.start_date ,id = mValue.id})
                break
            end
        end
    end
    return lStartDate
end

function CHuodong:TestOp(iFlag, mArgs)
    local pid = mArgs[#mArgs]
    local oMaster = global.oWorldMgr:GetOnlinePlayerByPid(pid)
    if iFlag == 100 then
        global.oChatMgr:HandleMsgChat(oMaster, [[
100 - huodongop festivalgift
103 - 活动状态设置为开启（日程使用）
104 - 活动状态设置未关闭（日程使用）
105 - 清空玩家奖励领取记录
106 - 重新初始化（更改节日配置后需要）
107 - 查询玩家领取奖励信息
        ]])
    elseif iFlag == 103 then
        self:SetHuodongStateStart("全天",nil)
    elseif iFlag == 104 then
        self:SetHuodongStateEnd("全天",nil)
    elseif iFlag == 105 then
        oMaster:Set(self:GetSaveKey(), nil) 
    elseif iFlag == 106 then
        local mNow = get_timetbl()
        self:InitCurFestival(mNow)
        self:InitNextFestival(mNow)
    elseif iFlag == 107 then
        local sText = extend.Table.serialize(oMaster:Query(self:GetSaveKey(), {}))
        global.oChatMgr:HandleMsgChat(oMaster,sText )
    elseif iFlag == 108 then
        local oSchedule = oMaster.m_oScheduleCtrl.m_mSchedules[self.m_iScheduleId]
        local sText = extend.Table.serialize(oSchedule)
         global.oChatMgr:HandleMsgChat(oMaster, sText)
    elseif iFlag == 109 then
        local sText = extend.Table.serialize(self.m_mFestivalInfo) .. extend.Table.serialize(self.m_mNextFestivalInfo)
        global.oChatMgr:HandleMsgChat(oMaster, sText)
    end
end
