local global = require "global"
local res = require "base.res"
local interactive = require "base.interactive"
local record = require "public.record"
local extend = require "base.extend"
local net = require "base.net"
local gamedefines = import(lualib_path("public.gamedefines"))
local huodongbase = import(service_path("huodong.huodongbase"))

local STATUS_UNREACH = 0
local STATUS_REWARD = 1
local STATUS_REWARDED = 2

local SECOND_PAY_VALUE = 3000

--首冲类型
local FIRST_TYPE = {
    FIRST = 1,
    SECOND = 2,
    THIRD = 3,
}

local FIRST_PAY_KEY = {"first_pay_reward", "first_pay_reward_second", "first_pay_reward_third"}
local FIRST_PAY_EXTRA_KEY = {"first_pay_extra", "first_pay_extra_second", "first_pay_extra_third"}

function NewHuodong(sHuodongName)
    return CHuodong:New(sHuodongName)
end

CHuodong = {}
CHuodong.__index = CHuodong
CHuodong.m_sTempName = "普通运营活动"
inherit(CHuodong, huodongbase.CHuodong)

function CHuodong:New(sHuodongName)
    local o = super(CHuodong).New(self, sHuodongName)
    o:Init()
    return o
end

function CHuodong:Init()
    self:TryStartRewardMonitor()
end

function CHuodong:OnLogin(oPlayer, bReEnter)
    self:HandleLoginGift(oPlayer)
    self:HandleFirstPay(oPlayer)

    local mNet = {}
    mNet.first_pay_gift = self:PackFirstPayGift(oPlayer, FIRST_TYPE.FIRST)
    mNet.rebate_gift = self:PackRebateGift(oPlayer)
    mNet.login_gift = self:PackLoginGift(oPlayer)
    mNet.new_day_time = self:GetNewDayTime()
    mNet.second_pay_gift = self:PackSecondPayGift(oPlayer)
    mNet.first_pay_gift_second = self:PackFirstPayGift(oPlayer, FIRST_TYPE.SECOND)
    mNet.first_pay_gift_third = self:PackFirstPayGift(oPlayer, FIRST_TYPE.THIRD)
    mNet.store_charge_rmb = oPlayer:GetStoreCharge().rmb
    mNet = net.Mask("GS2CWelfareGiftInfo", mNet)
    oPlayer:Send("GS2CWelfareGiftInfo", mNet)
end

---------------------首充, 次充----------------
function CHuodong:HandlePayGift(oPlayer, sProductKey)
    local sPayKey = self:GetFirstPayKey(FIRST_TYPE.FIRST)
    if oPlayer:Query(sPayKey, STATUS_UNREACH) > 0 then 
        self:HandleSecondPayGift(oPlayer, sProductKey)
    end
    self:HandleFirstPay(oPlayer)
end

function CHuodong:HandleFirstPay(oPlayer)
    local sPayKeyFirst = self:GetFirstPayKey(FIRST_TYPE.FIRST)
    local sPayKeySecond = self:GetFirstPayKey(FIRST_TYPE.SECOND)
    local sPayKeyThird = self:GetFirstPayKey(FIRST_TYPE.THIRD)
    local iPayStatusFirst = oPlayer:Query(sPayKeyFirst, STATUS_UNREACH)
    local iPayStatusSecond = oPlayer:Query(sPayKeySecond, STATUS_UNREACH)
    local iPayStatusThird = oPlayer:Query(sPayKeyThird, STATUS_UNREACH)

    local iRmb = oPlayer:GetStoreCharge().rmb

    local bFlag = false
    if iRmb > 0 and oPlayer:Query(sPayKeyFirst, STATUS_UNREACH) <= 0 then
        self:HandleFirstPayStatus(oPlayer, FIRST_TYPE.FIRST)
        self:OnHandleFirstPayGift(oPlayer)
        bFlag = true
    end

    local mSecondData = self:GetFirstPayGift(FIRST_TYPE.SECOND)
    local mThirdData = self:GetFirstPayGift(FIRST_TYPE.THIRD)
    if iPayStatusSecond <= 0 and iRmb >= mSecondData.pay then
        self:HandleFirstPayStatus(oPlayer, FIRST_TYPE.SECOND)
        bFlag = true
    end

    if iPayStatusThird <= 0 and iRmb >= mThirdData.pay then
        self:HandleFirstPayStatus(oPlayer, FIRST_TYPE.THIRD)
        bFlag = true
    end

    --只刷充值钱数
    if not bFlag then
        self:RefreshFirstPayGift(oPlayer)
    end
end

function CHuodong:HandleFirstPayStatus(oPlayer, iType)
    local sPayKey = self:GetFirstPayKey(iType)
    local sPayExtraKey = self:GetFirstPayExtraKey(iType)
    local iPayStatus = oPlayer:Query(sPayKey, STATUS_UNREACH)
    local iPayExtraStatus = oPlayer:Query(sPayExtraKey, STATUS_UNREACH)

    local mData = self:GetFirstPayGift(iType)
    local iDay = mData.gift_day

    oPlayer:Set(sPayKey, STATUS_REWARD)
    if get_dayno(get_time()) - get_dayno(oPlayer:GetCreateTime()) < iDay then
        oPlayer:Set(sPayExtraKey, STATUS_REWARD)
    end
    self:RefreshFirstPayGift(oPlayer, iType)
end

function CHuodong:OnHandleFirstPayGift(oPlayer)
    local oRedPacketMgr = global.oRedPacketMgr
    oRedPacketMgr:AddRPBuff(oPlayer:GetPid(),2001)
end

function CHuodong:HandleSecondPayGift(oPlayer, sProductKey)
    if not global.oToolMgr:IsSysOpen("SECOND_PAY", oPlayer, true) then
        return
    end

    if oPlayer:Query(self:GetSecondPayKey(), STATUS_UNREACH) > 0 then return end

    local mPay = res["daobiao"]["pay"][sProductKey]
    if not mPay then
        record.warning("HandleSecondPayGift %s not find key %s", oPlayer:GetPid(), sProductKey)
        return
    end
    if mPay["value"] < SECOND_PAY_VALUE then return end

    oPlayer:Set(self:GetSecondPayKey(), STATUS_REWARD)    
    self:RefreshSecondPayGift(oPlayer)
end

function CHuodong:CalGiveReward(oPlayer, iReward, mGiveItem, iSummonCnt)
    local mRewardInfo = self:GetRewardData(iReward)
    local mRewardContent = self:GenRewardContent(oPlayer, mRewardInfo)
    for _, mItem in pairs(mRewardContent.items or {}) do
        for _, oItem in pairs(mItem.items) do
            mGiveItem[oItem:SID()] = (mGiveItem[oItem:SID()] or 0) + oItem:GetAmount()
        end
    end
    return mGiveItem, iSummonCnt
end

function CHuodong:TryRewardFirstPayGift(oPlayer, iType)
    if not global.oToolMgr:IsSysOpen("FIRST_PAY", oPlayer) then
        return
    end

    local sPayKey = self:GetFirstPayKey(iType)
    local sPayExtraKey = self:GetFirstPayExtraKey(iType)
    local iPayStatus = oPlayer:Query(sPayKey, STATUS_UNREACH)
    local iPayExtraStatus = oPlayer:Query(sPayExtraKey, STATUS_UNREACH)

    if iPayStatus ~= STATUS_REWARD then
        self:NotifyMessage(oPlayer, 1002) 
        return
    end

    -- 判断背包与宠物
    local mConfig = self:GetFirstPayGift(iType)
    local iReward1, iReward2 = mConfig["gift_1"], mConfig["gift_2"]

    --检查宠物
    local mGiveItem ,iSummonCnt = {}, 0
    local mRewardInfo = self:GetRewardData(iReward1)
    iSummonCnt = #mRewardInfo.summon
    if iPayExtraStatus == STATUS_REWARD then
        mRewardInfo = self:GetRewardData(iReward2)
        iSummonCnt = iSummonCnt + #mRewardInfo.summon
    end
    if oPlayer.m_oSummonCtrl:EmptySpaceCnt() < iSummonCnt then
        self:NotifyMessage(oPlayer, 1004)
        return
    end

    -- 检查背包空间
    local iNeedGrids = self:CountRewardItemProbableGrids(oPlayer, iReward1)
    if iPayExtraStatus == STATUS_REWARD then
        iNeedGrids = iNeedGrids + self:CountRewardItemProbableGrids(oPlayer, iReward2)
    end
    local iHasGrids = oPlayer.m_oItemCtrl:GetCanUseSpaceSize()
    if iNeedGrids > iHasGrids then
        self:NotifyMessage(oPlayer, 1003)
        return
    end

    oPlayer:Set(sPayKey, STATUS_REWARDED)
    if iPayExtraStatus == STATUS_REWARD then
        oPlayer:Set(sPayExtraKey, STATUS_REWARDED)
        self:Reward(oPlayer:GetPid(), iReward2)            
    end
    self:Reward(oPlayer:GetPid(), iReward1)
    self:RefreshFirstPayGift(oPlayer, iType)

    local mInfo = {
        action = "reward_first_pay_gfit",
        key = sPayKey
    }
    record.log_db("huodong", "welfare", {pid=oPlayer:GetPid(), info=mInfo})
end

function CHuodong:RefreshFirstPayGift(oPlayer, iType)
    local mNet = {}
    if iType then
        local lResult = self:PackFirstPayGift(oPlayer, iType)
        if iType == FIRST_TYPE.FIRST then
            mNet.first_pay_gift = lResult
        elseif iType == FIRST_TYPE.SECOND then
            mNet.first_pay_gift_second = lResult
        elseif iType == FIRST_TYPE.THIRD then
            mNet.first_pay_gift_third = lResult
        end
    end
    mNet.store_charge_rmb = oPlayer:GetStoreCharge().rmb
    mNet = net.Mask("GS2CWelfareGiftInfo", mNet)
    oPlayer:Send("GS2CWelfareGiftInfo", mNet)
end

function CHuodong:PackFirstPayGift(oPlayer, iType)
    local sPayKey = self:GetFirstPayKey(iType)
    local sPayExtraKey = self:GetFirstPayExtraKey(iType)
    local iPayKeyStatus = oPlayer:Query(sPayKey, STATUS_UNREACH)
    local iPayExtraKeyStatus = oPlayer:Query(sPayExtraKey, STATUS_UNREACH)
    local lResult = {
        {key = sPayKey, val = iPayKeyStatus},
        {key = "create_time", val = oPlayer:GetCreateTime()},
        {key = sPayExtraKey, val = iPayExtraKeyStatus},
    }
    return lResult
end

function CHuodong:GetFirstPayKey(iType)
    assert(iType and FIRST_PAY_KEY[iType])
    return FIRST_PAY_KEY[iType]
end

function CHuodong:GetFirstPayExtraKey(iType)
    assert(iType and FIRST_PAY_EXTRA_KEY[iType])
    return FIRST_PAY_EXTRA_KEY[iType]
end

function CHuodong:TryRewardSecondPayGift(oPlayer)
    if not global.oToolMgr:IsSysOpen("SECOND_PAY", oPlayer) then
        return
    end

    if oPlayer:Query(self:GetSecondPayKey(), STATUS_UNREACH) ~= STATUS_REWARD then
        self:NotifyMessage(oPlayer, 1014) 
        return
    end

    -- 判断背包与宠物
    local mConfig = self:GetSecondPayGift()
    local iReward = mConfig["gift"]
    local mRewardInfo = self:GetRewardData(iReward)
    if oPlayer.m_oSummonCtrl:EmptySpaceCnt() < #mRewardInfo.summon then
        self:NotifyMessage(oPlayer, 1004)
        return
    end

    -- 检查背包空间
    local iNeedGrids = self:CountRewardItemProbableGrids(oPlayer, iReward)
    local iHasGrids = oPlayer.m_oItemCtrl:GetCanUseSpaceSize()
    if iNeedGrids > iHasGrids then
        self:NotifyMessage(oPlayer, 1003)
        return
    end

    oPlayer:Set(self:GetSecondPayKey(), STATUS_REWARDED)
    self:Reward(oPlayer:GetPid(), iReward)
    
    self:RefreshSecondPayGift(oPlayer)
    local mInfo = {
        action = "reward_second_pay_gfit",
    }
    record.log_db("huodong", "welfare", {pid=oPlayer:GetPid(), info=mInfo})
end

function CHuodong:RefreshSecondPayGift(oPlayer)
    local mNet = {}
    mNet.second_pay_gift = self:PackSecondPayGift(oPlayer)
    mNet = net.Mask("GS2CWelfareGiftInfo", mNet)
    oPlayer:Send("GS2CWelfareGiftInfo", mNet)
end

function CHuodong:PackSecondPayGift(oPlayer)
    local lResult = {}
    table.insert(lResult, {
        key = self:GetSecondPayKey(),
        val = oPlayer:Query(self:GetSecondPayKey(), STATUS_UNREACH),
    })
    return lResult
end

function CHuodong:GetSecondPayKey()
    return "second_pay_reward"
end

function CHuodong:GetFirstPayGift(iType)
    local mData = res["daobiao"]["huodong"][self.m_sName]["first_pay_gift"]
    assert(mData, "CHuodong GetFirstPayGift first pay gift config error")
    local mTypeData
    if iType == FIRST_TYPE.FIRST then
        mTypeData = mData.first_gift
    elseif iType == FIRST_TYPE.SECOND then
        mTypeData = mData.first_gift_second
    elseif iType == FIRST_TYPE.THIRD then
        mTypeData = mData.first_gift_third
    end
    assert(mTypeData, string.format("CHuodong GetFirstPayGift error type %d", iType))
    return mTypeData
end

function CHuodong:GetSecondPayGift()
    return res["daobiao"]["huodong"][self.m_sName]["second_pay_gift"]["second_gift"]
end

---------------------充值返利----------------
function CHuodong:HandleRebateGift(oPlayer, iGoldCoin)
    if iGoldCoin <= 0 then return end

    local iValue = oPlayer:Query(self:GetRebateGiftKey(), 0)
    iValue = iValue + iGoldCoin
    oPlayer:Set(self:GetRebateGiftKey(), iValue)
    self:RefreshRebateGift(oPlayer)
end

function CHuodong:PackRebateGift(oPlayer)
    local mConfig = self:GetRebateGiftConfig()
    local mNet = {}
    for sKey, _ in pairs(mConfig) do
        local mUnit = {}
        mUnit.key = sKey
        mUnit.val = self:GetRebateGiftStatus(oPlayer, sKey)
        table.insert(mNet, mUnit)
    end
    local iValue = oPlayer:Query(self:GetRebateGiftKey(), 0)
    table.insert(mNet, {key=self:GetRebateGiftKey() ,val=iValue})
    return mNet
end

function CHuodong:RefreshRebateGift(oPlayer)
    local mNet = {}
    mNet.rebate_gift = self:PackRebateGift(oPlayer)
    mNet = net.Mask("GS2CWelfareGiftInfo", mNet)
    oPlayer:Send("GS2CWelfareGiftInfo", mNet)
end

function CHuodong:GetRebateGiftStatus(oPlayer, sKey)
    local iValue = oPlayer:Query(self:GetRebateGiftKey(), 0)
    if iValue <= 0 then return STATUS_UNREACH end 

    local mConfig = self:GetRebateGiftConfig()
    local mData = mConfig[sKey]
    local iStatus = oPlayer:Query(sKey, STATUS_UNREACH)
    if iStatus == STATUS_UNREACH and iValue >= mData["goldcoin"] then
        return STATUS_REWARD
    end
    return iStatus
end

function CHuodong:TryRewardRebateGift(oPlayer, sKey)
    local mConfig = self:GetRebateGiftConfig()
    local mData = mConfig[sKey]
    if self:GetRebateGiftStatus(oPlayer, sKey) ~= STATUS_REWARD then
        self:NotifyMessage(oPlayer, 1002) 
        return 
    end

    oPlayer:Set(sKey, STATUS_REWARDED)
    local iReward = mData["gift"]
    self:Reward(oPlayer:GetPid(), iReward)
    self:RefreshRebateGift(oPlayer)
    local mInfo = {
        action = "reward_rebate_gfit",
        key = sKey,
    }
    record.log_db("huodong", "welfare", {pid=oPlayer:GetPid(), info=mInfo})
end

function CHuodong:GetRebateGiftConfig()
    return res["daobiao"]["huodong"][self.m_sName]["rebate_gift"]
end

function CHuodong:GetRebateGiftKey()
    return "rebate_gold_coin"
end

-----------------七彩神灯--------------------
function CHuodong:HandleLoginGift(oPlayer, bClient)
    local iLoginVal = oPlayer:Query(self:GetLoginGiftDayKey(), 0)
    if iLoginVal >= 8 then return end

    if oPlayer.m_oToday:Query(self:GetLoginFlagKey(), 0) <= 0 then
        oPlayer.m_oToday:Set(self:GetLoginFlagKey(), 1)
        oPlayer:Set(self:GetLoginGiftDayKey(), iLoginVal + 1)
        if bClient then
            self:RefreshLoginGift(oPlayer)
        end
    end
end

function CHuodong:PackLoginGift(oPlayer, bClient)
    if not bClient and self:IsLoginGiftFinish(oPlayer) then
        return {}
    end

    local mConfig = self:GetLoginGiftConfig()
    local mNet = {}
    for sKey, _ in pairs(mConfig) do
        local mUnit = {}
        mUnit.key = sKey
        mUnit.val = self:GetLoginGiftStatus(oPlayer, sKey)
        table.insert(mNet, mUnit)
    end
    return mNet
end

function CHuodong:RefreshLoginGift(oPlayer, bClient)
    local mNet = {}
    mNet.login_gift = self:PackLoginGift(oPlayer, bClient)
    mNet.new_day_time = self:GetNewDayTime()
    mNet = net.Mask("GS2CWelfareGiftInfo", mNet)
    oPlayer:Send("GS2CWelfareGiftInfo", mNet)
end

function CHuodong:GetNewDayTime()
    local mTime = get_daytime({})
    return mTime.time - get_time()
end

function CHuodong:IsLoginGiftFinish(oPlayer)
    return oPlayer:Query(self:GetLoginGiftFinishKey(), 0) > 0
end

function CHuodong:GetLoginGiftStatus(oPlayer, sKey)
    local iLoginVal = oPlayer:Query(self:GetLoginGiftDayKey(), 0)
    if iLoginVal <= 0 then return STATUS_UNREACH end 

    local mConfig = self:GetLoginGiftConfig()
    local mData = mConfig[sKey]
    local iStatus = oPlayer:Query(sKey, STATUS_UNREACH)
    if iStatus == STATUS_UNREACH and iLoginVal >= mData["day"] then
        return STATUS_REWARD
    end
    return iStatus
end

function CHuodong:TryRewardLoginGift(oPlayer, sKey)
    local mConfig = self:GetLoginGiftConfig()
    local mData = mConfig[sKey]
    if not mData then return end

    if self:GetLoginGiftStatus(oPlayer, sKey) ~= STATUS_REWARD then 
        self:NotifyMessage(oPlayer, 1002) 
        return 
    end

    local iReward = mData["gift"]
    local mRewardInfo = self:GetRewardData(iReward)
    local iRide = tonumber(mRewardInfo.ride) or 0
    if iRide > 0 and not global.oToolMgr:IsSysOpen("RIDE_SYS", oPlayer, true) then
        local mSysData = res["daobiao"]["open"]["RIDE_SYS"]
        self:NotifyMessage(oPlayer, 1013, {level=mSysData.p_level, name=mSysData.name})
        return
    end 

    local iSummonCnt = #mRewardInfo.summon
    if oPlayer.m_oSummonCtrl:EmptySpaceCnt() < iSummonCnt then
        self:NotifyMessage(oPlayer, 1004)
        return
    end

    -- 检查背包空间
    local iNeedGrids = self:CountRewardItemProbableGrids(oPlayer, iReward)
    local iHasGrids = oPlayer.m_oItemCtrl:GetCanUseSpaceSize()
    if iNeedGrids > iHasGrids then
        oPlayer:NotifyMessage(global.oToolMgr:GetTextData(3010, {"text"}))
        return
    end
    oPlayer:Set(sKey, STATUS_REWARDED)
    local mConfig = self:GetLoginGiftConfig()
    local bAllReward = true 
    for sGiftKey ,_ in pairs(mConfig) do
        if self:GetLoginGiftStatus(oPlayer, sGiftKey) < STATUS_REWARDED then
            bAllReward = false
            break
        end
    end
    if bAllReward then
        oPlayer:Set(self:GetLoginGiftFinishKey(), 1)
    end
    self:Reward(oPlayer:GetPid(), iReward)
    self:RefreshLoginGift(oPlayer, true)

    local mInfo = {
        action = "reward_login_gfit",
        key = sKey,
    }
    record.log_db("huodong", "welfare", {pid=oPlayer:GetPid(), info=mInfo})
end

function CHuodong:NotifyMessage(oPlayer, iText, mRep)
    local sMsg = self:GetTextData(iText)
    if mRep then
        sMsg = global.oToolMgr:FormatColorString(sMsg, mRep)
    end
    oPlayer:NotifyMessage(sMsg)
end

function CHuodong:GetLoginGiftFinishKey()
    return "login_gift_finish"
end

function CHuodong:GetLoginFlagKey()
    return "login_gift_flag"
end

function CHuodong:GetLoginGiftDayKey()
    return "login_gift_days"
end

function CHuodong:GetLoginGiftConfig()
    return res["daobiao"]["huodong"][self.m_sName]["login_gift"]
end


function CHuodong:TestOp(iFlag, mArgs)
    local oChatMgr = global.oChatMgr
    local oNotifyMgr = global.oNotifyMgr
    local oWorldMgr = global.oWorldMgr
    local pid = mArgs[#mArgs]
    local oPlayer = oWorldMgr:GetOnlinePlayerByPid(pid)

    local mCommand={
        "100 指令查看",
        "101 清除首冲标记\nhuodongop welfare 101",
    }
    if iFlag == 100 then
        for idx=#mCommand,1,-1 do
            oChatMgr:HandleMsgChat(oPlayer,mCommand[idx])
        end
        oNotifyMgr:Notify(pid,"请看消息频道咨询指令")
    elseif iFlag  == 101 then
        oPlayer:Set(self:GetFirstPayKey(FIRST_TYPE.FIRST), nil)
        oPlayer:Set(self:GetFirstPayKey(FIRST_TYPE.SECOND), nil)
        oPlayer:Set(self:GetFirstPayKey(FIRST_TYPE.THIRD), nil)
        oPlayer:Set(self:GetSecondPayKey(), nil)
        oNotifyMgr:Notify(pid,"清除成功")
    end
end
