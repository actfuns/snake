local global = require "global"
local res = require "base.res"
local interactive = require "base.interactive"
local record = require "public.record"
local extend = require "base.extend"
local net = require "base.net"
local gamedefines = import(lualib_path("public.gamedefines"))
local huodongbase = import(service_path("huodong.huodongbase"))

local STATUS_UNCHARGE = 0
local STATUS_REWARD = 1
local STATUS_REWARDED = 2


function NewHuodong(sHuodongName)
    return CHuodong:New(sHuodongName)
end

CHuodong = {}
CHuodong.__index = CHuodong
CHuodong.m_sTempName = "元宝大礼"
inherit(CHuodong, huodongbase.CHuodong)

function CHuodong:New(sHuodongName)
    local o = super(CHuodong).New(self, sHuodongName)
    o:Init()
    return o
end

function CHuodong:Init()
    self.m_mPlayerGoldCoin = {}
end

function CHuodong:NeedSave()
    return true
end

function CHuodong:Save()
    local mData = {}

    mData.player_goldcoin = {}
    for iPid, mInfo in pairs(self.m_mPlayerGoldCoin) do
        mData.player_goldcoin[db_key(iPid)] = mInfo
    end
    return mData
end

function CHuodong:Load(m)
    if not m then return end

    for sPid, mInfo in pairs(m.player_goldcoin or {}) do
        self.m_mPlayerGoldCoin[tonumber(sPid)] = mInfo
    end
end

function CHuodong:MergeFrom(mFromData)
    if not mFromData or not next(mFromData) then
        return false, "huodong charge without data"
    end
    self:Dirty()
    for sPid, mInfo in pairs(mFromData.player_goldcoin or {}) do
        self.m_mPlayerGoldCoin[tonumber(sPid)] = mInfo
    end
    return true
end

--商品价值：单位（元）
function CHuodong:GetProductRmb(sProductKey)
    local mData = res["daobiao"]["pay"][sProductKey]
    if not mData then
        record.error("GetProductRmb error: no such product %s", sProductKey)
        return 0
    end
    local iValue = mData["value"]
    if not iValue or iValue <= 0 then
        record.error("GetProductRmb error: product %s error value %s", sProductKey, iValue)
        return 0
    end
    return math.floor(iValue / 100)
end

---- 每日礼包 -----

function CHuodong:PackDayGift(oPlayer)
    local mInfo = self:GetDayGiftConfig()
    local lResult = {}
    for sKey, mData in pairs(mInfo) do
        local mUnit = {}
        mUnit.key = sKey
        if sKey == "gift_day_all" then
            mUnit.val = oPlayer:Query(sKey) and 1 or 0
        else
            mUnit.val = oPlayer.m_oTodayMorning:Query(sKey, STATUS_UNCHARGE)
            mUnit.val = mUnit.val | self:QueryAllGiftInfoByKey(oPlayer, sKey)
        end
        table.insert(lResult, mUnit)
    end
    return lResult
end

function CHuodong:GenDayGiftKey()
    local mInfo = self:GetDayGiftConfig()
    return table_key_list(mInfo)
end

function CHuodong:OnCharge(oPlayer, iValue, sKeyWord, sProductKey)
    --记录充值
    self:RecordCharge(oPlayer, sProductKey)

    local lDayKeyWord = self:GenDayGiftKey()
    if sKeyWord == "gift_day_all" then
        self:CheckGiveUnGetReward(oPlayer)
        if not oPlayer:Query("gift_day_all") then
            local iStatus = STATUS_UNCHARGE 
            for _, sKey in ipairs(lDayKeyWord) do
                if sKey == "gift_day_all" then goto continue end
                local iKeepStatus = oPlayer.m_oTodayMorning:Query(sKey, STATUS_UNCHARGE)
                if iKeepStatus > iStatus then
                    iStatus = iKeepStatus
                end
--                if self:ValidRewardDayGift(oPlayer, sKey) == 1002 then
--                    oPlayer.m_oTodayMorning:Set(sKey, STATUS_REWARD)
--                    self:TryRewardDayGift(oPlayer, sKey, true)
--                end
                ::continue::
            end
            local iDay = iStatus == STATUS_UNCHARGE and 0 or 1
            self:InitAllDayGiftInfo(oPlayer, iDay, true)
        end
    elseif extend.Array.find(lDayKeyWord, sKeyWord) then
        if self:ValidRewardDayGift(oPlayer, sKeyWord) == 1002 then
            oPlayer.m_oTodayMorning:Set(sKeyWord, STATUS_REWARD)
            self:TryRewardDayGift(oPlayer, sKeyWord, true)
        end
    elseif extend.Array.find({"grade_gift1", "grade_gift2"}, sKeyWord) then
        local iRet = self:ValidRewardGradeGift(oPlayer, sKeyWord, 0)
        if iRet == 1002 then
            oPlayer:Set(sKeyWord, STATUS_REWARD)
            self:TryRewardGradeGift(oPlayer, sKeyWord, 0, true)
        else
            record.warning("can't charge again grade_gift:%s %s %s %s", oPlayer:GetPid(), sKeyWord, sProductKey, iRet)
        end
    --elseif extend.Array.find({"goldcoin_gift_1", "goldcoin_gift_2"}, sKeyWord) then
    elseif extend.Array.find({"goldcoin_gift_1",}, sKeyWord) then
        self:GoldCoinChargeReward(oPlayer, sKeyWord, true)
        if oPlayer:Query(sKeyWord,STATUS_UNCHARGE) ~= STATUS_REWARD then
            oPlayer:Set(sKeyWord,STATUS_REWARD)
        end
    elseif extend.Array.find({"goldcoin_gift_2",}, sKeyWord) then
        self:GoldCoinChargeReward(oPlayer, sKeyWord, true)
        if oPlayer:Query(sKeyWord,STATUS_UNCHARGE) ~= STATUS_REWARD then
            oPlayer:Set(sKeyWord,STATUS_REWARD)
        end
    end
    safe_call(self.HandleRebateGift, self, oPlayer, sProductKey, 1)
end

function CHuodong:RecordCharge(oPlayer, sProductKey)
    local mData = res["daobiao"]["pay"][sProductKey]
    if mData then
        local mCharge = oPlayer:GetAllCharge()
        local iValue = mData["value"]
        local iRmb = math.floor(iValue / 100)
        local iGoldCoin = math.floor(iValue / 10)
        mCharge.rmb = mCharge.rmb + iRmb
        mCharge.goldcoin = mCharge.goldcoin + iGoldCoin
        oPlayer:Set("all_charge", mCharge)
    end
end

function CHuodong:ValidRewardDayGift(oPlayer, sKeyWord)
    if not global.oToolMgr:IsSysOpen("GIFT_DAY", oPlayer, true) then  
        return 1001
    end
    local iStatus = self:QueryAllGiftInfoByKey(oPlayer, sKeyWord)
    if iStatus == STATUS_REWARDED then
        return 1003
    end
    if iStatus == STATUS_REWARD then
        return 1
    end
    if oPlayer.m_oTodayMorning:Query(sKeyWord, 0) <= 0 then
        return 1002
    end
    if oPlayer.m_oTodayMorning:Query(sKeyWord, 0) > 1 then
        return 1003
    end
    return 1
end

function CHuodong:QueryAllGiftInfoByKey(oPlayer, sKeyWord)
    self:CheckGiveUnGetReward(oPlayer)
    
    local sKey = "gift_day_all"
    local mAllGiftInfo = oPlayer:Query(sKey)
    if not mAllGiftInfo then return 0 end

    local iDayNo = self:GetMorningDayNo(oPlayer:GetPid())
    local lUrl = {"reward_list", tostring(iDayNo), sKeyWord}
    local iStatus = table_get_depth(mAllGiftInfo, lUrl)
    return iStatus or 0
end

function CHuodong:SetAllGiftInfoByKey(oPlayer, sKeyWord, iVal)
    local sKey = "gift_day_all"
    local mAllGiftInfo = oPlayer:Query(sKey)
    if not mAllGiftInfo then return 0 end

    local iDayNo = self:GetMorningDayNo(oPlayer:GetPid())
    local lUrl = {"reward_list", tostring(iDayNo)}
    local mReward = table_get_depth(mAllGiftInfo, lUrl)
    if mReward then
        mReward[sKeyWord] = iVal
        oPlayer:Set(sKey, mAllGiftInfo)
    end
end

function CHuodong:InitAllDayGiftInfo(oPlayer, iDay, bCharge)
    local sKey = "gift_day_all"
    local iKeepDay = 6
    local iStartDay = self:GetMorningDayNo(oPlayer:GetPid()) + iDay
    local iEndDay = iStartDay + iKeepDay
    local lRewardList = {}
    local iTotalGold = 0
    local mConfig = self:GetDayGiftConfig()
    local lDayKeyWord = self:GenDayGiftKey()
    extend.Array.remove(lDayKeyWord, "gift_day_all")

    --oPlayer:ChargeGold(mData.goldcoin_first, mData.payid)
    local iTotalGold = mConfig[sKey].goldcoin_first
    oPlayer:ChargeGold(iTotalGold, mConfig[sKey].payid)

    for i = iStartDay, iEndDay do
        local mUnit = {}
        for _, sKey in ipairs(lDayKeyWord) do
            mUnit[sKey] = STATUS_REWARD
        end
        lRewardList[tostring(i)] = mUnit
    end
    local mAllGiftInfo = {
        start_day = iStartDay,
        end_day = iEndDay,
        reward_list = lRewardList,
    }
    oPlayer:Set(sKey, mAllGiftInfo)

    if iDay == 0 then
        self:CheckGiveUnGetReward(oPlayer, iStartDay)
    else
        self:Notify(oPlayer:GetPid(), 1005)
    end
    self:RefreshDayGiftInfo(oPlayer, sKey)

    local sProductKey = mConfig[sKey].payid
    local mInfo = {
        keyword = sKey,
        day = iDay,
        action = "reward_all_day_gift",
        payid = sProductKey
    }
    record.log_db("huodong", "charge", {pid=oPlayer:GetPid(), info=mInfo})

    if bCharge then
        local mData, sName = global.oMailMgr:GetMailInfo(1041)
        local mReplace = {rmb=self:GetProductRmb(sProductKey)}
        mData.context = global.oToolMgr:FormatColorString(mData.context, mReplace)
        global.oMailMgr:SendMailNew(0, sName, oPlayer:GetPid(), mData)
    end
end

function CHuodong:CheckGetAllDayReward(oPlayer)
    local sKey = "gift_day_all"
    local mAllGiftInfo = oPlayer:Query(sKey)
    if not mAllGiftInfo then return end

    local mConfig = self:GetDayGiftConfig()
    local lDayKeyWord = self:GenDayGiftKey()
    extend.Array.remove(lDayKeyWord, "gift_day_all")

    for i = mAllGiftInfo.start_day, mAllGiftInfo.end_day do
        local mReward = mAllGiftInfo.reward_list[tostring(i)]
        for _, sKey in ipairs(lDayKeyWord) do
            if mReward[sKey] ~= STATUS_REWARDED then
                return
            end
        end
    end
    return true
end

function CHuodong:CheckGiveUnGetReward(oPlayer, iCheckDay)
    local sKey = "gift_day_all"
    local mAllGiftInfo = oPlayer:Query(sKey)
    if not mAllGiftInfo then return end

    local iDayNo = iCheckDay or (self:GetMorningDayNo(oPlayer:GetPid()) - 1)
    local iStartDay = mAllGiftInfo.start_day
    if not iStartDay or iDayNo < iStartDay then
        return
    end
  
    local mConfig = self:GetDayGiftConfig()
    local lDayKeyWord = self:GenDayGiftKey()
    extend.Array.remove(lDayKeyWord, "gift_day_all")

    local iEndDay = mAllGiftInfo.end_day 
    local lRewardList = mAllGiftInfo.reward_list
    local mRewardKey = {}
    for i = iStartDay, math.min(iEndDay, iDayNo) do
        local mReward = lRewardList[tostring(i)]
        if not mReward then goto continue end
        for _, sKey in ipairs(lDayKeyWord) do
            local mData = mConfig[sKey]
            if mReward[sKey] ~= STATUS_REWARDED and mData then
                mReward[sKey] = STATUS_REWARDED 
                local iGift1 = mRewardKey[mData.gift_1] or 0
                mRewardKey[mData.gift_1] = iGift1 + 1
                local iGift2 = mRewardKey[mData.gift_2] or 0
                mRewardKey[mData.gift_2] = iGift2 + 1
            end
        end
        ::continue::
    end

    if iDayNo > iEndDay then
        oPlayer:Set(sKey, nil)
    else
        oPlayer:Set(sKey, mAllGiftInfo)
    end

    if self:CheckGetAllDayReward(oPlayer) then
        oPlayer:Set(sKey, nil)
    end

    if next(mRewardKey) or not oPlayer:Query(sKey) then
        local mArgs = {cancel_tip=true,send_mail=true}
        local iPid = oPlayer:GetPid()
        for iReward, iAmount in pairs(mRewardKey) do
            for i = 1, iAmount do
                self:Reward(iPid, iReward, mArgs)
            end
        end
        self:Notify(oPlayer:GetPid(), 1006)

        local mNet = {}
        mNet.gift_day_list = self:PackDayGift(oPlayer)
        mNet = net.Mask("GS2CChargeGiftInfo", mNet)
        oPlayer:Send("GS2CChargeGiftInfo", mNet)
    end
end

function CHuodong:CheckCanBuyGift(oPlayer, sKeyWord)
    local mConfig = self:GetDayGiftConfig()[sKeyWord]
    if not mConfig then return end

    local oHuodong = global.oHuodongMgr:GetHuodong("welfare")
    local sKey = oHuodong:GetRebateGiftKey()
    local iTotal = oPlayer:Query(sKey, 0)
    local mNet = {reward_key = sKeyWord}
    if iTotal < mConfig.charge_goldcoin_need then
        mNet.can_buy = 0
        self:Notify(oPlayer:GetPid(), 1007, {amount=mConfig.charge_goldcoin_need})
    else
        mNet.can_buy = 1
    end
    oPlayer:Send("GS2CChargeCheckBuy", mNet)
end

function CHuodong:TryRewardDayGift(oPlayer, sKeyWord, bCharge)
    local mConfig = self:GetDayGiftConfig()
    local mData = mConfig[sKeyWord]
    if not mData then return end

    local iPid = oPlayer:GetPid()
    local iReward1 = mData.gift_1
    local iReward2 = mData.gift_2
    local iRet = self:ValidRewardDayGift(oPlayer, sKeyWord)
    if iRet ~= 1 then
        self:Notify(oPlayer:GetPid(), iRet)
    else
        if oPlayer.m_oTodayMorning:Query(sKeyWord) == STATUS_REWARD then
            oPlayer.m_oTodayMorning:Set(sKeyWord, STATUS_REWARDED)
            oPlayer:ChargeGold(mData.goldcoin_first, mData.payid)
        else
            self:SetAllGiftInfoByKey(oPlayer, sKeyWord, STATUS_REWARDED)
            self:CheckGiveUnGetReward(oPlayer)
        end
        self:Reward(iPid, iReward1, {send_mail=true})
        self:Reward(iPid, iReward2, {send_mail=true})
    end

    self:RefreshDayGiftInfo(oPlayer, sKeyWord)

    local sProductKey = mData.payid
    local mInfo = {
        keyword = sKeyWord,
        ret = iRet,
        action = "reward_day_gift",
        payid = sProductKey
    }
    record.log_db("huodong", "charge", {pid=oPlayer:GetPid(), info=mInfo})

    if bCharge then
        local mData, sName = global.oMailMgr:GetMailInfo(1041)
        local mReplace = {rmb=self:GetProductRmb(sProductKey)}
        mData.context = global.oToolMgr:FormatColorString(mData.context, mReplace)
        global.oMailMgr:SendMailNew(0, sName, iPid, mData)
    end
end

function CHuodong:RefreshDayGiftInfo(oPlayer, sKey)
    local mUnit = {}
    mUnit.key = sKey
    if sKey == "gift_day_all" then
        mUnit.val = oPlayer:Query(sKey) and 1 or 0
    else
        mUnit.val = oPlayer.m_oTodayMorning:Query(sKey, STATUS_UNCHARGE)
        mUnit.val = mUnit.val | self:QueryAllGiftInfoByKey(oPlayer, sKey)
    end
    oPlayer:Send("GS2CChargeRefreshUnit", {unit = mUnit})
end

-------------------元宝大礼------------------
function CHuodong:GetMorningDayNo(iPid, iTime)
    if iPid and self.m_mTestDayNo and self.m_mTestDayNo[iPid] then
        return self.m_mTestDayNo[iPid]
    end
    return get_morningdayno(iTime)
end

function CHuodong:NewDay(mNow)
    local iTime = mNow and mNow.time or get_time()
    local iCheckDay = self:GetMorningDayNo(nil, iTime) - 1
    for iPid, mInfo in pairs(self.m_mPlayerGoldCoin) do
        for sKey, mData in pairs(mInfo) do
            safe_call(self.TryRewardGoldCoinGiftByMail, self, iPid, sKey, iCheckDay)
        end
    end
end

function CHuodong:CanBuyGoldCoinGift(iPid, sKey)
    local oPlayer = global.oWorldMgr:GetOnlinePlayerByPid(iPid)
    if oPlayer then
        return global.oToolMgr:IsSysOpen("GIFT_GOLDCOIN", oPlayer)
    end
    return false
end

function CHuodong:TryRewardGoldCoinGiftByMail(iPid, sKey, iCheckDay)
    local mInfo = table_get_depth(self.m_mPlayerGoldCoin, {iPid, sKey})
    if not mInfo then return end

    local mConfig = self:GetGoldCoinGiftConfig()
    local mGift = mConfig[sKey]
    if not mGift then return end

    if iCheckDay > mInfo.last_day then 
        local mData, sName = global.oMailMgr:GetMailInfo(1010)
        local mReplace = {amount=mGift.goldcoin_after}
        mData.context = global.oToolMgr:FormatColorString(mData.context, mReplace)
        global.oMailMgr:SendMailNew(0, sName, iPid, mData, {goldcoin=mGift.goldcoin_after})
    
        mInfo.last_day = iCheckDay
        if iCheckDay >= mInfo.end_day then
            self.m_mPlayerGoldCoin[iPid][sKey] = nil
            local mData, sName = global.oMailMgr:GetMailInfo(1009)
            global.oMailMgr:SendMailNew(0, sName, iPid, mData)
        end
        self:Dirty()

        local mLogInfo = {
            keyword = sKey,
            data = mInfo,
            action = "goldcoin_gift_mail",
        }
        record.log_db("huodong", "charge", {pid=iPid, info=mLogInfo})
    end

    local oPlayer = global.oWorldMgr:GetOnlinePlayerByPid(iPid)
    if oPlayer then
        self:RefreshGoldCoinGiftUnit(oPlayer, sKey)
    end
end

function CHuodong:TryRewardGoldCoinGift(oPlayer, sKey)
    --后续奖励， 初次奖励不在此领取
    local mConfig = self:GetGoldCoinGiftConfig()
    local mGift = mConfig[sKey]
    if not mGift then return end
   
    local iPid = oPlayer:GetPid()
    local mData = table_get_depth(self.m_mPlayerGoldCoin, {iPid, sKey})
    if not mData then return end

    local iCurDay = self:GetMorningDayNo(iPid)
    if iCurDay == mData.last_day then
        self:Notify(iPid, 1003)
        return
    end

    if iCurDay > mData.end_day then
        self.m_mPlayerGoldCoin[iPid][sKey] = nil
        self:Dirty()
        return
    end

    oPlayer:RewardGoldCoin(mGift.goldcoin_after, mGift.payid)
    self.m_mPlayerGoldCoin[iPid][sKey]["last_day"] = iCurDay

    if iCurDay == mData.end_day then
        self.m_mPlayerGoldCoin[iPid][sKey] = nil
        local mData, sName = global.oMailMgr:GetMailInfo(1009)
        global.oMailMgr:SendMailNew(0, sName, iPid, mData)
    end
    self:Dirty()
    self:RefreshGoldCoinGiftUnit(oPlayer, sKey)

    local mInfo = {
        keyword = sKey,
        data = mData,
        action = "goldcoin_gift_after",
        payid = mGift.payid
    }
    record.log_db("huodong", "charge", {pid=iPid, info=mInfo})
end

function CHuodong:GoldCoinChargeReward(oPlayer, sKey, bCharge)
    --初次奖励
    local iPid = oPlayer:GetPid()

    if not self:CanBuyGoldCoinGift(iPid, sKey) then
        return
    end

    local mConfig = self:GetGoldCoinGiftConfig()
    local mGift = mConfig[sKey]
    if not mGift then return end

    local iCurDay = self:GetMorningDayNo(iPid)
    local iContinue = mGift.days - 1
    local mData = table_get_depth(self.m_mPlayerGoldCoin, {iPid, sKey})
    if mData and mData.end_day < iCurDay then
        mData = nil
    end
 
    if not mData then
        mData = {last_day=iCurDay-1, start_day=iCurDay, end_day=iCurDay+iContinue}
        table_set_depth(self.m_mPlayerGoldCoin, {iPid}, sKey, mData)
    else
        mData.end_day = mData.end_day + mGift.days
    end
    oPlayer:ChargeGold(mGift.goldcoin_first, mGift.payid)
    self:Dirty()
    self:RefreshGoldCoinGiftUnit(oPlayer, sKey)

    local sProductKey = mGift.payid
    local mInfo = {
        keyword = sKey,
        data = mData,
        action = "goldcoin_gift_first",
        payid = sProductKey
    }
    record.log_db("huodong", "charge", {pid=iPid, info=mInfo})

    if bCharge then
        local iMail = 1042
        if sKey == "goldcoin_gift_2" then
            iMail = 1043
        end
        local mData, sName = global.oMailMgr:GetMailInfo(iMail)
        local mReplace = {rmb=self:GetProductRmb(sProductKey)}
        mData.context = global.oToolMgr:FormatColorString(mData.context, mReplace)
        global.oMailMgr:SendMailNew(0, sName, iPid, mData)
    end
end

function CHuodong:RefreshGoldCoinGiftUnit(oPlayer, sKey)
    local mUnit = {}
    mUnit.key = sKey
    mUnit.val, mUnit.days = self:GetGoldCoinStatus(oPlayer:GetPid(), sKey)
    oPlayer:Send("GS2CChargeRefreshUnit", {unit = mUnit})
end

function CHuodong:GetGoldCoinStatus(iPid, sKey)
    local mData = table_get_depth(self.m_mPlayerGoldCoin, {iPid, sKey})
    if not mData then return STATUS_UNCHARGE, nil end

    local iCurrDay = self:GetMorningDayNo(iPid)
    if mData.end_day < iCurrDay then
        return STATUS_UNCHARGE , nil
    end

    if mData.last_day < iCurrDay then
        return STATUS_REWARD, mData.end_day - iCurrDay
    else
        return STATUS_REWARDED, mData.end_day - iCurrDay
    end
end

function CHuodong:PackGoldCoinGift(oPlayer)
    local mNet = {}
    local iPid = oPlayer:GetPid()
    local mConfig = self:GetGoldCoinGiftConfig()
    local iCurDay = self:GetMorningDayNo(iPid)
    for sKey, _ in pairs(mConfig) do
        local mTmp = {}
        mTmp.key = sKey
        mTmp.val, mTmp.days = self:GetGoldCoinStatus(iPid, sKey)
        table.insert(mNet, mTmp)
    end
    return mNet
end

--------------------一本万利------------------
function CHuodong:ShowGradeGiftUI(oPlayer, iFromGrade, iGrade)
    if oPlayer:Query("grade_gift1", STATUS_UNCHARGE) > STATUS_UNCHARGE then
        return
    end

    local lGrade = self:GetBaseConfig()["grade_gift_ui"]
    local bShow = false
    for i = iFromGrade + 1, iGrade do
        if table_in_list(lGrade, i) then
            oPlayer:Send("GS2CShowGradeGiftUI", {})
            break
        end
    end
end

function CHuodong:ValidRewardGradeGift(oPlayer, sType, iGrade)
    if not global.oToolMgr:IsSysOpen("GIFT_GRADE", oPlayer, true) then
        return 1001
    end
    if oPlayer:Query(sType, STATUS_UNCHARGE) <= STATUS_UNCHARGE then
        return 1002
    end
    if oPlayer:GetGrade() < iGrade then
        return 1004, {grade=iGrade}
    end
    local sKey = string.format("%s_%s", sType, iGrade)
    if oPlayer:Query(sKey, STATUS_UNCHARGE) == STATUS_REWARDED then
        return 1003
    end
    return 1
end

function CHuodong:TryRewardGradeGift(oPlayer, sType, iGrade, bCharge)
    local iRet, mReplace = self:ValidRewardGradeGift(oPlayer, sType, iGrade)
    if iRet ~= 1 then
        self:Notify(oPlayer:GetPid(), iRet, mReplace)
        return
    end

    local sKey = string.format("%s_%s", sType, iGrade)
    local mConfig = self:GetGradeGift()
    local mGift = mConfig[sKey]
    if not mGift then return end

    oPlayer:Set(sKey, STATUS_REWARDED)
    if iGrade ~= 0 then
        oPlayer:RewardGoldCoin(mGift.goldcoin, mGift.payid)
        self:RefreshGradeGiftUnit(oPlayer, sKey)
    else
        oPlayer:ChargeGold(mGift.goldcoin, mGift.payid)
        local mNet = {}
        mNet.gift_grade_list = self:PackGradeGift(oPlayer)
        mNet = net.Mask("GS2CChargeGiftInfo", mNet)
        oPlayer:Send("GS2CChargeGiftInfo", mNet)
    end

    local sProductKey = mGift.payid
    local mInfo = {
        keyword = sKey,
        action = "grade_gift",
        payid = sProductKey
    }
    record.log_db("huodong", "charge", {pid=oPlayer:GetPid(), info=mInfo})

    if bCharge then
        local mData, sName = global.oMailMgr:GetMailInfo(1044)
        local mReplace = {rmb=self:GetProductRmb(sProductKey)}
        mData.context = global.oToolMgr:FormatColorString(mData.context, mReplace)
        global.oMailMgr:SendMailNew(0, sName, oPlayer:GetPid(), mData)
    end
end

function CHuodong:GetGradeGiftStatus(oPlayer, sKey)
    local sType = string.sub(sKey, 1, 11)
    local iStatus = oPlayer:Query(sType, STATUS_UNCHARGE)
    if iStatus == STATUS_UNCHARGE then
        return STATUS_UNCHARGE
    else
        return oPlayer:Query(sKey, STATUS_REWARD)
    end
end

function CHuodong:PackGradeGift(oPlayer, sKey)
    local mConfig = self:GetGradeGift()
    local mNet = {}
    for sKey, _ in pairs(mConfig) do
        local mUnit = {}
        mUnit.key = sKey
        mUnit.val = self:GetGradeGiftStatus(oPlayer, sKey)
        table.insert(mNet, mUnit)
    end
    return mNet
end

function CHuodong:RefreshGradeGiftUnit(oPlayer, sKey)
    local mUnit = {}
    mUnit.key = sKey
    mUnit.val = self:GetGradeGiftStatus(oPlayer, sKey)
    oPlayer:Send("GS2CChargeRefreshUnit", {unit=mUnit})
end

function CHuodong:Notify(iPid, iChat, mReplace)
    local oNotifyMgr = global.oNotifyMgr
    local sMsg = self:GetTextData(iChat)
    if mReplace then
        sMsg = global.oToolMgr:FormatColorString(sMsg, mReplace)
    end
    oNotifyMgr:Notify(iPid, sMsg)
end

function CHuodong:OnLogin(oPlayer, bReEnter)
    self:AddUpgradeEvent(oPlayer)
    local mNet = {}
    mNet.gift_day_list = self:PackDayGift(oPlayer)
    mNet.gift_goldcoin_list = self:PackGoldCoinGift(oPlayer)
    mNet.gift_grade_list = self:PackGradeGift(oPlayer)
    mNet = net.Mask("GS2CChargeGiftInfo", mNet)
    oPlayer:Send("GS2CChargeGiftInfo", mNet)
    self:GS2CRplGoldCoinGift(oPlayer)

    self:ChargeLogin(oPlayer)
end

function CHuodong:CalAllCharge(oPlayer)
    local sKey = "all_charge"
    if oPlayer:Query(sKey) then return end
    local iCharegeGoldCoin = oPlayer:Query("rebate_gold_coin", 0)
    local iCharegeRmb = math.floor(iCharegeGoldCoin / 10)
    oPlayer:Set(sKey, {rmb = iCharegeRmb, goldcoin = iCharegeGoldCoin})
end

--计算玩家从商城充值的人民币和元宝数,为兼容线上用户数据
function CHuodong:CalStoreCharge(oPlayer)
    local sKey = "store_charge"
    if oPlayer:Query(sKey) then return end

    local iCharegeRmb = 0
    local iCharegeGoldCoin = 0
    local mConfig = self:GetChargeConfig()
    for iKey, mInfo in pairs(mConfig) do
        local sKey = self:GenKey(iKey)
        local iCnt = oPlayer:Query(sKey, 0)
        if iCnt > 0 then
            local iRmb = mInfo.RMB * iCnt
            local iGoldCoin = mInfo.gold_coin_gains * iCnt
            iCharegeRmb = iCharegeRmb + iRmb
            iCharegeGoldCoin = iCharegeGoldCoin + iGoldCoin
        end
    end
    oPlayer:Set(sKey, {rmb = iCharegeRmb, goldcoin = iCharegeGoldCoin})
end

function CHuodong:OnUpgrade(oPlayer, iFromGrade, iGrade)
    self:ShowGradeGiftUI(oPlayer, iFromGrade, iGrade)
end

function CHuodong:GetBaseConfig()
    return res["daobiao"]["huodong"][self.m_sName]["config"][1]
end

function CHuodong:GetDayGiftConfig()
    return res["daobiao"]["huodong"][self.m_sName]["day_gift"]
end

function CHuodong:GetGoldCoinGiftConfig()
    return res["daobiao"]["huodong"][self.m_sName]["goldcoin_gift"]
end

function CHuodong:GetGradeGift()
    return res["daobiao"]["huodong"][self.m_sName]["grade_gift"]
end

---------------------充值----------------
function CHuodong:PayForGold(oPlayer, sKey, sProductKey)
    self:RecordCharge(oPlayer, sProductKey)

    local mConfig = self:GetChargeConfig()
    local iKey = tonumber(sKey)
    local mInfo = mConfig[iKey]
    if not mInfo then return end

    local sKeepKey = self:GenKey(iKey)
    local iCnt = oPlayer:Query(sKeepKey, 0)
    local iGoldCoin = mInfo.gold_coin_gains
    local sMsg = string.format("获得%d#cur_1", iGoldCoin)
    local iExtGoldCoin = 0
    if iCnt <= 0 then
        iExtGoldCoin = mInfo.first_reward
    else
        iExtGoldCoin = mInfo.reward_gold_coin
    end

    --记录玩家从商城充值的总人民币和元宝数
    local sKey = "store_charge"
    local mCharge = oPlayer:GetStoreCharge()
    mCharge.rmb = mCharge.rmb + mInfo.RMB
    mCharge.goldcoin = mCharge.goldcoin + iGoldCoin
    oPlayer:Set(sKey, mCharge)

    oPlayer:Set(sKeepKey, 1+iCnt)
    oPlayer:ChargeGold(iGoldCoin, mInfo.payid, {cancel_tip=true})
    if iExtGoldCoin > 0 then
        oPlayer:RewardGoldCoin(iExtGoldCoin, mInfo.payid, {cancel_tip=true})
        sMsg = sMsg .. string.format("额外赠送%d#cur_2", iExtGoldCoin)
    end
    self:RefreshPayForGold(oPlayer, sKeepKey)
    oPlayer:NotifyMessage(sMsg)
    safe_call(self.HandlePayGift, self, oPlayer, sProductKey)
    safe_call(self.HandleRebateGift, self, oPlayer, sProductKey, 1)
    safe_call(self.OnPayForGold, self, oPlayer,sProductKey)
    local iPid = oPlayer:GetPid()
    local mLogInfo = {
        action = "pay_for_gold",
        goldcoin = iGoldCoin,
        cnt = oPlayer:Query(sKeepKey, 0),
        payid = mInfo.payid
    }
    record.log_db("huodong", "charge", {pid=iPid, info=mLogInfo})

    local mData, sName = global.oMailMgr:GetMailInfo(1040)
    local mReplace = {rmb=self:GetProductRmb(sProductKey), coin=iGoldCoin, extcoin=iExtGoldCoin}
    mData.context = global.oToolMgr:FormatColorString(mData.context, mReplace)
    global.oMailMgr:SendMailNew(0, sName, iPid, mData)
    self:RewardRplGoldCoinGift(oPlayer, iGoldCoin)
end

function CHuodong:GenKey(iKey)
    return string.format("goldcoinstore_%s", iKey)
end

function CHuodong:GetChargeConfig()
    return res["daobiao"]["goldcoinstore"]
end

function CHuodong:RefreshPayForGold(oPlayer, sKey)
    local mUnit = {}
    mUnit.key = sKey
    mUnit.val = oPlayer:Query(sKey, STATUS_UNCHARGE)
    oPlayer:Send("GS2CRefreshGoldCoinUnit", {unit = mUnit})
end

function CHuodong:ChargeLogin(oPlayer)
    local mConfig = self:GetChargeConfig()
    local lChargeList = {}
    for iKey, mInfo in pairs(mConfig) do
        local sKey = self:GenKey(iKey)
        local iVal = oPlayer:Query(sKey, STATUS_UNCHARGE)
        local mUnit = {key = sKey, val = iVal}
        table.insert(lChargeList, mUnit)
    end
    oPlayer:Send("GS2CPayForGoldInfo", {goldcoin_list = lChargeList})
end

function CHuodong:HandlePayGift(oPlayer, sProductKey)
    local oHuodong = global.oHuodongMgr:GetHuodong("welfare")
    if oHuodong then
        oHuodong:HandlePayGift(oPlayer, sProductKey)
    end
end

function CHuodong:HandleRebateGift(oPlayer, sProductKey, iAmount)
    local oHuodong = global.oHuodongMgr:GetHuodong("welfare")
    if oHuodong then
        local mData = res["daobiao"]["pay"][sProductKey]
        if not mData then
            record.warning("HandleRebateGift error-1 %s %s, %d", oPlayer:GetPid(),sProductKey, iAmount)
            return
        end
        local iValue = mData["value"]
        local iGoldCoin = math.floor(iValue / 10 * iAmount)
        if iGoldCoin <= 0 then
            record.warning("HandleRebateGift error-2 %s %s, %d", oPlayer:GetPid(),sProductKey, iAmount)
            return
        end
        oHuodong:HandleRebateGift(oPlayer, iGoldCoin)
    end
end

function CHuodong:OnPayForGold(oPlayer,sProductKey)
    self:PreOnPayForGold(oPlayer,sProductKey)
    local pid = oPlayer:GetPid()
    local sKeepKey = self:GenKey(8)
    local iCnt = oPlayer:Query(sKeepKey, 0)
    -- if sProductKey == "com.cilu.dhxx.gold_648" and iCnt == 1 then
    --     local oRedPacketMgr = global.oRedPacketMgr
    --     local mArgs = {}
    --     mArgs.cw_replace = {}
    --     mArgs.cw_replace.pid = string.format("****%s%s",math.floor(pid/10)%10,pid%10)
    --     safe_call(oRedPacketMgr.SysAddRedPacket, oRedPacketMgr, 3001,nil,mArgs)
    -- end
    local oHuodong = global.oHuodongMgr:GetHuodong("everydaycharge")
    if oHuodong then
        safe_call(oHuodong.CheckReward, oHuodong, oPlayer,sProductKey)
    end
    oHuodong = global.oHuodongMgr:GetHuodong("superrebate")
    if oHuodong then
        safe_call(oHuodong.CheckReward, oHuodong, oPlayer,sProductKey)
    end
    oHuodong = global.oHuodongMgr:GetHuodong("totalcharge")
    if oHuodong then
        safe_call(oHuodong.CheckReward, oHuodong, oPlayer,sProductKey)
    end
    oHuodong = global.oHuodongMgr:GetHuodong("continuouscharge")
    if oHuodong then
        safe_call(oHuodong.CheckReward, oHuodong, oPlayer,sProductKey)
    end
end

function CHuodong:PreOnPayForGold(oPlayer,sProductKey)
    local mData = res["daobiao"]["pay"][sProductKey]
    if mData["func"] == "pay_for_gold" then --记录每天充值获得元宝额度
        oPlayer.m_oTodayMorning:Add(gamedefines.TODAY_PAY_GOLDCOIN,math.floor(mData.value/10))
    end
end

function CHuodong:RewardRplGoldCoinGift(oPlayer, iCharge)
    local mRplGoldCoinGift = oPlayer.m_oTodayMorning:Query("rplgoldcoingift", {})
    if #mRplGoldCoinGift <= 0 then return end
    local mUse = table.remove(mRplGoldCoinGift, 1)
    oPlayer.m_oTodayMorning:Set("rplgoldcoingift", mRplGoldCoinGift)

    self:GS2CRplGoldCoinGift(oPlayer)

    local iAmount = math.ceil((mUse.multiple - 1)* iCharge)
    local pid = oPlayer:GetPid()
    local sShape = string.format("1004(Value=%d)",iAmount)
    local oItem = global.oItemLoader:ExtCreate(sShape)
    oItem:Bind(pid)
    local oMailMgr = global.oMailMgr
    local mData, sName = oMailMgr:GetMailInfo(mUse.mail)
    mData.context = global.oToolMgr:FormatColorString(mData.context, {multiple = mUse.multiple, charge = iCharge})
    oMailMgr:SendMailNew(0, sName, pid, mData, { items = {oItem}})
end

function CHuodong:GS2CRplGoldCoinGift(oPlayer)
    local mRplGoldCoinGift = oPlayer.m_oTodayMorning:Query("rplgoldcoingift",{})
    local mNet = {}
    if #mRplGoldCoinGift <= 0 then
        mNet.flag = 0
        mNet.multiple = 0
    else
        mNet.flag = 1
        mNet.multiple = mRplGoldCoinGift[1].multiple * 100
    end
    oPlayer:Send("GS2CRplGoldCoinGift", mNet)
end

function CHuodong:InsertRplGoldCoinGift(oPlayer, iMultiple, iMailId, mArgs)
    local mRplGoldCoinGift = oPlayer.m_oTodayMorning:Query("rplgoldcoingift", {})
    table.insert(mRplGoldCoinGift, {reason = self.m_sName, multiple = iMultiple, mail = iMailId})
    oPlayer.m_oTodayMorning:Set("rplgoldcoingift", mRplGoldCoinGift)
    if #mRplGoldCoinGift == 1 then
        self:GS2CRplGoldCoinGift(oPlayer)
    end
end

-----------------Test--------------------
function CHuodong:TestOp(iFlag, mArgs)
    local iPid = mArgs[#mArgs]
    local oMaster = global.oWorldMgr:GetOnlinePlayerByPid(iPid)
    local oNotifyMgr = global.oNotifyMgr
    if iFlag == 100 then
        global.oNotifyMgr:Notify(iPid, [[
        101 - 模拟充值1元
        102 - 模拟充值3元
        103 - 模拟充值6元
        104 - 模拟充值10元
        201 - 模拟充值18(元宝大礼1)
        202 - 模拟充值30(元宝大礼2)
        203 - 领取元宝大礼
        204 - 离线发放元宝大礼
        205 - 模拟刷天 {1}
        301 - 模拟充值88(一本万利1)
        302 - 模拟充值188(一本万利2)
        303 - 领取等级元宝 {sType, grade}
        401 - 模拟充值 {iType}
        402 - 清除首次充值648标记
        403 - 清除充值一本万利标记
        404 - 清除充值周卡标记
        405 - 清除充值月卡标记
        406 - 648标记
        501 - 数据中心充值LOG
        ]])
    elseif iFlag == 101 then
        self:OnCharge(oMaster, 1, "gift_day_1", "com.cilu.dhxx.giftbag_1")
    elseif iFlag == 102 then
        self:OnCharge(oMaster, 3, "gift_day_2", "com.cilu.dhxx.giftbag_3")
    elseif iFlag == 103 then
        self:OnCharge(oMaster, 6, "gift_day_3", "com.cilu.dhxx.giftbag_6")
    elseif iFlag == 104 then
        self:OnCharge(oMaster, 10, "gift_day_all", "com.cilu.dhxx.giftbag_60")
    elseif iFlag == 201 then
        self:OnCharge(oMaster, 18, "goldcoin_gift_1", "com.cilu.dhxx.card_18")
    elseif iFlag == 202 then
        self:OnCharge(oMaster, 30, "goldcoin_gift_2", "com.cilu.dhxx.card_30")
    elseif iFlag == 203 then
        local sType = mArgs[1]
        self:TryRewardGoldCoinGift(oMaster, sType)
    elseif iFlag == 204 then
        self:NewDay(get_daytime({}))
    elseif iFlag == 205 then
        -- self.m_iTestDayNo = get_morningdayno() + mArgs[1]
        if not self.m_mTestDayNo then
            self.m_mTestDayNo = {}
        end
        self.m_mTestDayNo[iPid] = get_morningdayno() + mArgs[1]
        self:NewDay(get_daytime({}))
    elseif iFlag == 301 then
        self:OnCharge(oMaster, 88, "grade_gift1", "com.cilu.dhxx.grow_68")
    elseif iFlag == 302 then
        self:OnCharge(oMaster, 188, "grade_gift2", "com.cilu.dhxx.grow_98")
    elseif iFlag == 303 then
        local sType = mArgs[1]
        local iGrade = mArgs[2]
        self:TryRewardGradeGift(oMaster, sType, iGrade, true)
    elseif iFlag == 401 then
        local sKey = mArgs[1]
        local mConfig = self:GetChargeConfig()
        local iKey = tonumber(sKey)
        local mInfo = mConfig[iKey]
        self:PayForGold(oMaster, mArgs[1], mInfo.payid)
    elseif iFlag == 402 then
        local sKeepKey = self:GenKey(8)
        oMaster:Set(sKeepKey,nil)
        oNotifyMgr:Notify(iPid,"清除成功")
    elseif iFlag == 403 then
        oMaster:Set("grade_gift1",nil)
        oMaster:Set("grade_gift2",nil)
        oNotifyMgr:Notify(iPid,"清除成功")
    elseif iFlag == 404 then
        oMaster:Set("goldcoin_gift_1",nil)
        oNotifyMgr:Notify(iPid,"清除成功")
    elseif iFlag == 405 then
        oMaster:Set("goldcoin_gift_2",nil)
        oNotifyMgr:Notify(iPid,"清除成功")
    elseif iFlag == 406 then
        local sKeepKey = self:GenKey(8)
        local iCnt  = oMaster:Query(sKeepKey,0)
        oNotifyMgr:Notify(iPid,string.format("次数%s",iCnt))
    elseif iFlag == 501 then
        local mOrder = {
            amount = 600,
            product_key = "com.cilu.dhxx.gold_6",
            product_amount = 1,
            orderid = math.random(10001, 99999),
        }
        global.oPayMgr:PaySuccessLog(oMaster:GetPid(), mOrder)
    elseif iFlag == 502 then
        local mOrder = {
            product_key = mArgs[1],
            product_amount = 1,
        }
        global.oPayMgr:DealSucceedOrder(oMaster:GetPid(), mOrder)
    end
end


