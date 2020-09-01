local global = require "global"
local res = require "base.res"
local record = require "public.record"
local extend = require "base.extend"

local datactrl = import(lualib_path("public.datactrl"))
local loadschedule = import(service_path("schedule.loadschedule"))
local gamedefines = import(lualib_path("public.gamedefines"))

CScheduleCtrl = {}
CScheduleCtrl.__index = CScheduleCtrl
inherit(CScheduleCtrl, datactrl.CDataCtrl)

-- 添加周活动 TODO
function CScheduleCtrl:New(pid)
    local o = super(CScheduleCtrl).New(self, {pid = pid})
    o.m_mSchedules = {}
    o.m_iRewardEnergy = 0
    o.m_mRetrieveObj = {}
    o:Dirty()
    return o
end

function CScheduleCtrl:Release()
    for _, oSchedule in pairs(self.m_mSchedules) do
        baseobj_safe_release(oSchedule)
    end
    for _, oRetrieve in pairs(self.m_mRetrieveObj) do
        baseobj_safe_release(oRetrieve)        
    end
    super(CScheduleCtrl).Release(self)
end

function CScheduleCtrl:Load(mData)
    local mData = mData or {}
    local mSchedule = mData.schedules or {}
    for _, data in pairs(mSchedule) do
        local oSchedule = loadschedule.LoadSchedule(data["id"], data)
        if oSchedule then
        --assert(oSchedule, string.format("schedule id error:%s,%s", self:GetInfo("pid"), data["id"]))
            self.m_mSchedules[oSchedule:ID()] = oSchedule
            oSchedule:Init(self:GetInfo("pid"))
        else
            record.warning(string.format("load schedule lost %s",data["id"]))
        end
    end
    self:SetData("dayno", mData.dayno)
    self:SetData("weekno", mData.weekno)
    self:SetData("reward", mData.reward)
    self:SetData("last_day_point", mData.ldpoint or 0)
    self.m_iRewardEnergy = mData.energy or 0

    local iPid = self:GetInfo("pid")
    for iDayNo, mInfo in pairs(mData.retrieves or {}) do
        local oRetrieve = CRetrieve:New(iDayNo, iPid)
        oRetrieve:Load(mInfo)
        self.m_mRetrieveObj[iDayNo] = oRetrieve
    end
    self:Refresh(true)
end

function CScheduleCtrl:Save()
    local mData = {}
    local mSchedule = {}

    for k, oSchedule in pairs(self.m_mSchedules) do
        table.insert(mSchedule, oSchedule:Save())
    end
    mData.schedules = mSchedule
    mData.dayno = self:GetData("dayno")
    mData.weekno = self:GetData("weekno")
    mData.reward = self:GetData("reward")
    mData.ldpoint = self:GetData("last_day_point")
    mData.energy = self.m_iRewardEnergy

    local mRetrieve = {}
    for iDayNo, oRetrieve in pairs(self.m_mRetrieveObj) do
        mRetrieve[iDayNo] = oRetrieve:Save()
    end
    mData.retrieves = mRetrieve
    return mData
end

function CScheduleCtrl:UnDirty()
    super(CScheduleCtrl).UnDirty(self)
    for _, oSchedule in pairs(self.m_mSchedules) do
        if oSchedule:IsDirty() then
            oSchedule:UnDirty()
        end
    end
    for _, oRetrieve in pairs(self.m_mRetrieveObj) do
        if oRetrieve:IsDirty() then
            oRetrieve:UnDirty()
        end
    end
end

function CScheduleCtrl:IsDirty()
    local bDirty = super(CScheduleCtrl).IsDirty(self)
    if bDirty then
        return true
    end
    for _,oSchedule in pairs(self.m_mSchedules) do
        if oSchedule:IsDirty() then
            return true
        end
    end
    for _, oRetrieve in pairs(self.m_mRetrieveObj) do
        if oRetrieve:IsDirty() then
            return true
        end
    end
    return false
end

function CScheduleCtrl:OnLogin(oPlayer, bReEnter)
    self:GS2CSchedule()
end

function CScheduleCtrl:OnNewHour5(oPlayer, mNow)
    self:Refresh()
    oPlayer.m_oScheduleCtrl:RefreshMaxTimes(1008)

    local oHuodong = global.oHuodongMgr:GetHuodong("retrieveexp")
    if oHuodong then
        oHuodong:OnPlayerNewHour5(oPlayer, mNow)
    end
end

function CScheduleCtrl:Refresh(bNoSync)
    local todayno = get_morningdayno()
    local weekno = get_morningweekno()
    local bChanged = false
    if todayno > self:GetData("dayno", 0) then
        self:ResetDaily(true)
        bChanged = true
    end
    if weekno > self:GetData("weekno", 0) then
        self:ResetWeekly(true)
        bChanged = true
    end
    if bChanged and not bNoSync then
        self:GS2CSchedule()
    end
end

function CScheduleCtrl:ResetDaily(bNoSync)
    local iReward = self:GetData("reward", 0)
    local iTotalPoint = self:GetTotalPoint(false)
    local mSchedules = {}
    local iPid = self:GetInfo("pid")
    for iScheduleId, oSchedule in pairs(self.m_mSchedules) do
        if not oSchedule:NeedResetDaily() then
            mSchedules[iScheduleId] = oSchedule
        else
            baseobj_delay_release(oSchedule)
            local oNewSchedule = loadschedule.CreateSchedule(iScheduleId)
            oNewSchedule:Init(iPid)
            mSchedules[iScheduleId] = oNewSchedule
        end
    end
    self:Dirty()
    self.m_mSchedules = mSchedules
    self.m_iRewardEnergy = 0
    self:SetData("dayno", get_morningdayno())
    self:SetData("reward", 0)
    self:SetData("last_day_point", iTotalPoint)
    --self:SendRewardMail(iReward, iTotalPoint)
    if not bNoSync then
        self:GS2CSchedule()
    end
end

-- 日程模块设计为不存档周信息，需要实现周日程不在日程内实现
--（设计思路找陈淦&王宝平），改由活动模块自己记录，
-- 通过重写活动的GetDoneTimes并调用RefreshMaxTimes推送到前端
function CScheduleCtrl:ResetWeekly(bNoSync)
    self:Dirty()
    local iPid = self:GetInfo("pid")
    local mSchedules = {}
    for iScheduleId, oSchedule in pairs(self.m_mSchedules) do
        if not oSchedule:NeedResetWeekly() then
            mSchedules[iScheduleId] = oSchedule
        else
            baseobj_delay_release(oSchedule)
            local oNewSchedule = loadschedule.CreateSchedule(iScheduleId)
            oNewSchedule:Init(iPid)
            mSchedules[iScheduleId] = oNewSchedule
        end
    end
    self.m_mSchedules = mSchedules
    self:SetData("weekno", get_morningweekno())
    if not bNoSync then
        self:GS2CSchedule()
    end
end

function CScheduleCtrl:GetActiveRewardInfo()
    return res["daobiao"]["schedule"]["active"]
end

function CScheduleCtrl:AddByName(sName)
    local id = loadschedule.GetScheduleIdByName(sName)
    if id then
        self:Add(id)
    end
end

function CScheduleCtrl:Add(id)
    self:Refresh()
    local oSchedule = self.m_mSchedules[id]
    if not oSchedule then
        oSchedule = loadschedule.CreateSchedule(id)
        self.m_mSchedules[id] = oSchedule
        oSchedule:Init(self:GetInfo("pid"))
        self:Dirty()
    end
    local iAddPoint = oSchedule:Add()
    self:TryRewardEnergy()
    self:GS2CRefreshSchedule(oSchedule)
    self:TryRewardChumoPoint(id)
    
    safe_call(self.TriggerEvent,self,"addactive",{pid=self:GetInfo("pid"),addpoint=iAddPoint,totalpoint=self:GetTotalPoint(true)})

    -- 活跃礼包触发奖励检测会频繁
    local oPlayer = global.oWorldMgr:GetOnlinePlayerByPid(self:GetInfo("pid"))
    if oPlayer then
        local oHuodong = global.oHuodongMgr:GetHuodong("activepoint")
        if oHuodong then
            safe_call(oHuodong.CheckReward, oHuodong, oPlayer, iAddPoint, true)
        end
        safe_call(oPlayer.AddOrgHuoYue, oPlayer, iAddPoint)
    end

    -- 称谓逻辑100点活跃加称谓
    -- local oTitleMgr = global.oTitleMgr
    -- oTitleMgr:SetHuoYueTitle(self:GetInfo("pid"), self:GetTotalPoint(true), iAddPoint)  
    self:FireScheduleDone(id)
    -- self:HandleRetrieve(id, 1)
end

function CScheduleCtrl:AddDoneTimes(id)
    self:Refresh()
    local oSchedule = self.m_mSchedules[id]
    if not oSchedule then
        oSchedule = loadschedule.CreateSchedule(id)
        self.m_mSchedules[id] = oSchedule
        oSchedule:Init(self:GetInfo("pid"))
        self:Dirty()
    end
    
    oSchedule:AddDoneTimes()
    self:GS2CRefreshSchedule(oSchedule)
    self:FireScheduleDone(id)
    -- self:HandleRetrieve(id, 1)
end

function CScheduleCtrl:DeleteSchedule(id)
    if self.m_mSchedules[id] then
        self.m_mSchedules[id] = nil
        self:Dirty()
    end
end

function CScheduleCtrl:RefreshSchedule(id)
    local oSchedule = self.m_mSchedules[id]
    if not oSchedule then
        return
    else
        self:GS2CRefreshSchedule(oSchedule)
    end
end

function CScheduleCtrl:CreateSchedule(id)
    local oSchedule = self.m_mSchedules[id]
    if not oSchedule then
        oSchedule = loadschedule.CreateSchedule(id)
        self.m_mSchedules[id] = oSchedule
        oSchedule:Init(self:GetInfo("pid"))
        self:Dirty()
    end
    self:GS2CRefreshSchedule(oSchedule)
end

function CScheduleCtrl:GetDoneTimes(id)
    self:Refresh()
    local oSchedule = self.m_mSchedules[id]
    if not oSchedule then
        return 0
    end
    return oSchedule:GetDoneTimes()
end

function CScheduleCtrl:RefreshMaxTimes(id)
    self:Refresh()
    local oSchedule = self.m_mSchedules[id]
    if not oSchedule then
        oSchedule = loadschedule.CreateSchedule(id)
        self.m_mSchedules[id] = oSchedule
        oSchedule:Init(self:GetInfo("pid"))
        self:Dirty()
    end
    self:GS2CRefreshSchedule(oSchedule)
end

function CScheduleCtrl:GetActivePoint(id)
    self:Refresh()
    local oSchedule = self.m_mSchedules[id]
    if not oSchedule then
        return 0
    end
    return oSchedule:GetActivePoint()
end

function CScheduleCtrl:GetTotalPoint(bRefresh)
    if bRefresh then
        self:Refresh()
    end

    local total = 0
    for _, oSchedule in pairs(self.m_mSchedules) do
        total = total + oSchedule:GetActivePoint()
    end
    return total
end

function CScheduleCtrl:GetLastDayPoint()
    return self:GetData("last_day_point") or 0
end

function CScheduleCtrl:IsDone(id)
    self:Refresh()
    local oSchedule = self.m_mSchedules[id]
    if not oSchedule then
        return false
    end
    return oSchedule:IsDone()
end

function CScheduleCtrl:IsFullTimes(id)
    self:Refresh()
    local oSchedule = self.m_mSchedules[id]
    if not oSchedule then
        return false
    end
    local bRet = oSchedule:IsFullTimes()
    return bRet
end

function CScheduleCtrl:HasReward()
    local mActiveReward = self:GetActiveRewardInfo()
    local iTotPoint = self:GetTotalPoint(true)
    local maxidx = 0
    for idx, info in pairs(mActiveReward) do
        if iTotPoint >= info["point"] and idx > maxidx then
            maxidx = idx
        end
    end

    local iRewardMask = self:GetData("reward", 0)
    for i=1,maxidx do
        if 1 << i & iRewardMask == 0 then
            return true
        end
    end
    return false
end

function  CScheduleCtrl:SendRewardMail(iReward, iTotalPoint)
    local mActiveReward = self:GetActiveRewardInfo()
    local mItem = {} 
    for _, mActive in ipairs(mActiveReward) do 
        local idx = mActive.id
        if iReward & (1 << idx)  ~= 1 << idx then
            local iPoint = mActive["point"] or 999
            if iPoint < iTotalPoint  then
                local mItemList = self:GetRewardItemList(mActive)
                for _, oItem in ipairs(mItemList) do
                    if oItem then 
                        table.insert(mItem, oItem)
                    end
                end
                local iExp = self:GetRewardExp(mActive)
                if 0 < iExp then
                    local  oItem = global.oItemLoader:ExtCreate(1005)
                    oItem:SetData("Value", iExp)
                    table.insert(mItem, oItem)
                end
                local iSliver = self:GetRewardSilver(mActive)
                if 0 < iSliver then
                    local oItem = global.oItemLoader:ExtCreate(1002)
                    oItem:SetData("Value", iSliver)
                    table.insert(mItem, oItem)
                end
            end
        end
    end
    local oMailMgr = global.oMailMgr
    local mData, name = oMailMgr:GetMailInfo(2002)
    if table_count(mItem)  > 0 then
        oMailMgr:SendMail(0, name, self:GetInfo("pid"), mData, 0, mItem)
    end
end

function CScheduleCtrl:GetRewardItemList(mRewardinfo)
    local mItemList = {}
    for _, iteminfo in ipairs(mRewardinfo["item"]) do
        local oItem = global.oItemLoader:ExtCreate(iteminfo["sid"])
        if iteminfo["amount"] > 1 then
            if oItem:ItemType() == "virtual" then
                oItem:SetData("Value", iteminfo["amount"])
            else
                oItem:SetAmount(iteminfo["amount"])
            end
        end
        if iteminfo["bind"] ~= 0 then
            oItem:Bind(self:GetInfo("pid"))
        end
        table.insert(mItemList, oItem)
    end

    return mItemList
end

function CScheduleCtrl:GetRewardExp(mRewardinfo)
     if not mRewardinfo then
        return 0
    end

    local sExp = mRewardinfo["exp"]
    if sExp and sExp ~= "" and sExp ~= "0" then
        local oWorldMgr = global.oWorldMgr
        local oPlayer = oWorldMgr:GetOnlinePlayerByPid(self:GetInfo("pid"))
        if oPlayer  then
            local iExp =formula_string(sExp, {lv = oPlayer:GetGrade()})
            assert(iExp, string.format("schedule reward exp err: %s", sExp))
            return iExp
        end    
    end

    return 0
end

function CScheduleCtrl:GetRewardSilver(mRewardinfo)
    if not mRewardinfo then
        return 0
    end

    local sSliver = mRewardinfo["silver"]
    if sSliver and sSliver ~= "" and sSliver ~= "0" then
        local oWorldMgr = global.oWorldMgr
        local oPlayer = oWorldMgr:GetOnlinePlayerByPid(self:GetInfo("pid"))
        if oPlayer then
            local iSliver = formula_string(sSliver, {lv = oPlayer:GetGrade()})
            assert(iSliver, string.format("schedule reward silver err: %s", sSliver))
            return iSliver
        end
    end

    return 0
end

function CScheduleCtrl:GetReward(idx)
    self:Refresh()
    local iReward = self:GetData("reward", 0)
    if iReward & (1 << idx) == 1 << idx then
        return
    end
    local point = self:GetActiveRewardInfo()[idx]["point"] or 999
    if self:GetTotalPoint(true) < point then
        return
    end
    local oWorldMgr = global.oWorldMgr
    local oPlayer = oWorldMgr:GetOnlinePlayerByPid(self:GetInfo("pid"))
    if oPlayer then
        if oPlayer.m_oItemCtrl:GetCanUseSpaceSize() <= 0 then
            local oNotifyMgr = global.oNotifyMgr
            oNotifyMgr:Notify(oPlayer:GetPid(), "你的背包已满，请清理后再领取")
            return
        end
        self:Dirty()
        iReward = iReward | (1 << idx)
        self:SetData("reward", iReward)

        self:Reward(oPlayer, idx)
        oPlayer:Send("GS2CGetScheduleReward", {["rewardidx"]=iReward})
    end
end

function CScheduleCtrl:Reward(oPlayer, rewardidx)
    local rewardinfo = self:GetActiveRewardInfo()[rewardidx]
    local mRatio = {}
    local mIdx = {}
    
    self:RewardItem(oPlayer, rewardinfo)

    local iExp = self:GetRewardExp(rewardinfo) 
    if 0 < iExp then 
        oPlayer:RewardExp(iExp, "schedule", {bEffect = true})
    end
    local iSliver = self:GetRewardSilver(rewardinfo)
    if 0 < iSliver then 
        oPlayer:RewardSilver(iSliver, "schedule")
    end
end

function CScheduleCtrl:RewardItem(oPlayer, rewardinfo)
    local mItemList = self:GetRewardItemList(rewardinfo)
    for _, oItem in ipairs(mItemList) do 
        if oItem then
            oPlayer:RewardItem(oItem, "schedule")
        end
    end
end

function CScheduleCtrl:PointExtraRewardKey(idx)
    return "schedule_reward_" .. idx
end

function CScheduleCtrl:TryPointExtraReward(oPlayer, idx)
    local iReward = self:GetData("reward", 0)
    if iReward & (1 << idx) == 1 << idx then
        return
    end
    local sKey = self:PointExtraRewardKey(idx)
    if oPlayer.m_oTodayMorning:Query(sKey, 0) == 1 then 
        return
    end
    self:Reward(oPlayer, idx)
    self:Dirty()
    iReward = iReward | (1 << idx)
    self:SetData("reward", iReward)
    oPlayer.m_oTodayMorning:Set(sKey, 1)
end

function CScheduleCtrl:TryRewardEnergy()
    local oWorldMgr = global.oWorldMgr
    local oPlayer = oWorldMgr:GetOnlinePlayerByPid(self:GetInfo("pid"))
    local iTotalPoint = self:GetTotalPoint(false)
    local mRewardInfo = self:GetActiveRewardInfo()
    local iPointLimit = 100
    local iSemiPointLimit = 60
    if iTotalPoint >= iPointLimit then
        -- 大于等于 100 奖励轻音仙子之灵
        self:TryPointExtraReward(oPlayer, 6)
    elseif iTotalPoint >= iSemiPointLimit then
        -- 大于等于 60 奖励轻音仙子之灵
        self:TryPointExtraReward(oPlayer, 7)
    end
    for index , mInfo in ipairs(mRewardInfo) do
        if iTotalPoint >= mInfo.point and (self.m_iRewardEnergy & (1<<(index-1))) == 0 then
            self:Dirty()
            self.m_iRewardEnergy = self.m_iRewardEnergy | (1<<(index-1))
            local sFormula = mInfo["energy"]
            if sFormula~="" then
                local iEnergy =formula_string(sFormula, {lv = oPlayer:GetGrade()})
                if iEnergy > 0 then
                    local iOldEnergy = oPlayer:GetEnergy()
                    oPlayer:AddEnergy(iEnergy, "日程", {cancel_tip=true, cancel_chat=true})
                    local iNewEnergy = oPlayer:GetEnergy()
                    if iOldEnergy<iNewEnergy then
                        global.oChatMgr:HandleMsgChat(oPlayer,string.format("获得活力#G%s#n点",(iNewEnergy-iOldEnergy)))
                    end
                end
            end
            return
        end
    end
end

function CScheduleCtrl:GS2CSchedule()
    local oHuodongMgr = global.oHuodongMgr
    local mNet = {}
    local mState = {}
    for sHDName, info in pairs(oHuodongMgr:HuodongState()) do
        table.insert(mState, info)
    end
    mNet["hdlist"] = mState
    local mActive = {}
    for k, oSchedule in pairs(self.m_mSchedules) do
        table.insert(mActive, oSchedule:PackData())
    end
    mNet["schedules"] = mActive
    mNet["activepoint"] = self:GetTotalPoint(true)
    mNet["rewardidx"]  = self:GetData("reward", 0)

    mNet["curtime"] = get_time()
    local oWorldMgr = global.oWorldMgr
    local oPlayer = oWorldMgr:GetOnlinePlayerByPid(self:GetInfo("pid"))
    if oPlayer then
        local iPoint, iPointLimit = oPlayer.m_oBaseCtrl:GetDoublePoint()
        mNet["db_point"] = iPoint
        mNet["db_point_limit"] = iPointLimit
        oPlayer:Send("GS2CSchedule",mNet)
    end
end

function CScheduleCtrl:GS2CRefreshSchedule(oSchedule)
    local oHuodongMgr = global.oHuodongMgr
    local mNet = {}
    mNet["schedule"] = oSchedule:PackData()
    mNet["activepoint"] = self:GetTotalPoint(true)
    local oWorldMgr = global.oWorldMgr
    local oPlayer = oWorldMgr:GetOnlinePlayerByPid(self:GetInfo("pid"))
    if oPlayer then
        oPlayer:Send("GS2CRefreshSchedule",mNet)
    end
end

function CScheduleCtrl:GetScheduleById(iSchedule)
    return self.m_mSchedules[iSchedule]
end

function CScheduleCtrl:HandleRetrieve(iSchedule, iCnt)
    local oSchedule = self.m_mSchedules[iSchedule]
    if not oSchedule then return end

    local iCurDayNo = get_morningdayno()
    local oRetrieve = self:GetRetrieveObj(iCurDayNo)
    if not oRetrieve then
        oRetrieve = self:AddRetrieveObj(iCurDayNo)
    end
    oRetrieve:DoSchedule(iSchedule, iCnt)    
    self:Dirty()
end

function CScheduleCtrl:RemoveRetrieveObj(iDayNo)
    local oRetrieve = self.m_mRetrieveObj[iDayNo]
    if oRetrieve then
        self.m_mRetrieveObj[iDayNo] = nil
        baseobj_delay_release(oRetrieve)
        self:Dirty()
    end
end

function CScheduleCtrl:AddRetrieveObj(iDayNo)
    local oRetrieve = CRetrieve:New(iDayNo, self:GetInfo("pid"))
    self.m_mRetrieveObj[iDayNo] = oRetrieve
    self:Dirty()
    return oRetrieve
end

function CScheduleCtrl:GetRetrieveObj(iDayNo)
    return self.m_mRetrieveObj[iDayNo]
end

function CScheduleCtrl:GetAllRetrieveObj()
    return self.m_mRetrieveObj
end

function CScheduleCtrl:GetCanRetrieveObj(iCurDayNo)
    local mRetrieve = {}
    for index = 1, gamedefines.RETRIEVE_EXP_DAY do
        local iDayNo = iCurDayNo - index
        local oRetrieve = self:GetRetrieveObj(iDayNo)
        if oRetrieve then
            mRetrieve[iDayNo] = oRetrieve
        end
    end
    return mRetrieve
end

function CScheduleCtrl:FireScheduleDone(iScheduleId)
    self:TriggerEvent(gamedefines.EVENT.SCHEDULE_DONE, {scheduleId = iScheduleId})
end

function CScheduleCtrl:FireFengyaoDone()
    self:TriggerEvent(gamedefines.EVENT.FENGYAO_DONE, {})
end

function CScheduleCtrl:FireJJCFightEnd()
    self:TriggerEvent(gamedefines.EVENT.JJC_FIGHT_END, {})
end

function CScheduleCtrl:FireTrialFightStart()
    self:TriggerEvent(gamedefines.EVENT.TRIAL_FIGHT_START, {})
end

function CScheduleCtrl:TryRewardChumoPoint(iScheduleId)
    local mConfig = res["daobiao"]["moneypoint"]["scheduleid_2_chumotype"]
    if not mConfig[iScheduleId] then return end
    local oPlayer = global.oWorldMgr:GetOnlinePlayerByPid(self:GetInfo("pid"))
    if not oPlayer then return end
    oPlayer:RawRewardChumoPoint(mConfig[iScheduleId], mConfig[iScheduleId])
end

CRetrieve = {}
CRetrieve.__index = CRetrieve
inherit(CRetrieve, datactrl.CDataCtrl)

function CRetrieve:New(iDayNo, iPid)
    local o = super(CRetrieve).New(self, {pid = iPid})
    o.m_iDayNo = iDayNo
    o.m_mSchedules = {}
    o.m_mRetrieves = {}
    o.m_bCalculate = false
    return o
end

function CRetrieve:Save()
    local mData = {}
    mData.schedules = self.m_mSchedules
    mData.retrieves = self.m_mRetrieves
    mData.calculate = self.m_bCalculate
    return mData
end

function CRetrieve:Load(mData)
    if not mData then return end
    
    self.m_mSchedules = mData.schedules or {}
    self.m_mRetrieves = mData.retrieves or {}
    self.m_bCalculate = mData.calculate
end

function CRetrieve:DoSchedule(iSchedule, iCnt)
    if not iSchedule or iCnt <= 0 then return end

    if iSchedule == 1004 then
        local iPid = self:GetInfo("pid")
        local oPlayer = global.oWorldMgr:GetOnlinePlayerByPid(iPid)
        if oPlayer then
            local iBaseCnt = oPlayer.m_oTodayMorning:Query("ghost_base", 0)
            local iHasCnt = self.m_mSchedules[iSchedule] or 0
            if iBaseCnt > iHasCnt then
                self.m_mSchedules[iSchedule] = iBaseCnt
                self:Dirty()
            end
        end
    else
        local iHasCnt = self.m_mSchedules[iSchedule] or 0
        self.m_mSchedules[iSchedule] = iHasCnt + iCnt
        self:Dirty()
    end
end

function CRetrieve:GetScheduleTime(iSchedule)
    return self.m_mSchedules[iSchedule] or 0
end

function CRetrieve:isCalculate()
    return self.m_bCalculate
end

function CRetrieve:SetCalculate()
    self.m_bCalculate = true
    self:Dirty()
end

function CRetrieve:SetRetrieveCnt(iSchedule, iCnt)
    self.m_mRetrieves[iSchedule] = iCnt
    self:Dirty()
end

function CRetrieve:GetRetrieveCnt(iSchedule)
    return self.m_mRetrieves[iSchedule] or 0
end

function CRetrieve:GetAllRetrieve()
    return self.m_mRetrieves
end


