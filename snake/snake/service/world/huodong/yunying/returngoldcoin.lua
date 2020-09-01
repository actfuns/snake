local global = require "global"
local res = require "base.res"
local interactive = require "base.interactive"
local record = require "public.record"
local extend = require "base.extend"
local net = require "base.net"
local router = require "base.router"
local gamedefines = import(lualib_path("public.gamedefines"))
local huodongbase = import(service_path("huodong.huodongbase"))


function NewHuodong(sHuodongName)
    return CHuodong:New(sHuodongName)
end

CHuodong = {}
CHuodong.__index = CHuodong
CHuodong.m_sTempName = "公测返利"
inherit(CHuodong, huodongbase.CHuodong)

function CHuodong:OnUpgrade(oPlayer, iFromGrade, iGrade)
--    if not global.oToolMgr:IsSysOpen("RETURNGOLDCOIN", oPlayer, true) then
--        return
--    end
--    if iFromGrade < 10 and iGrade >= 10 then
    if iGrade >= 10 then
        if not oPlayer.m_mCbtPay then return end
        local iTotal = oPlayer.m_mCbtPay.paycount
        local mConfig = self:GetRewardConfigByPayCount(iTotal)
        if not mConfig then return end
        if oPlayer:Query("returngoldcoin_gift_1_time", 0) > 0 then
            return
        end
        if oPlayer:Query("returngoldcoin_gift_2_time", 0) > 0 then
            return
        end

        oPlayer:Set("returngoldcoin_gift_1_time", get_time()+mConfig.gift_1.timeout*60)
        oPlayer:Set("returngoldcoin_gift_2_time", get_time()+mConfig.gift_2.timeout*60)
        self:RefershReturnGoldCoin(oPlayer)
    end
end

function CHuodong:OnLogin(oPlayer, bReEnter)
    self:AddUpgradeEvent(oPlayer)
    if not oPlayer.m_mCbtPay then return end

    if not self:HasGetReward(oPlayer) and not oPlayer:Query("send_return_mail") then
        local mMail, sName = global.oMailMgr:GetMailInfo(2032)
        global.oMailMgr:SendMail(0, sName, oPlayer:GetPid(), mMail, 0)
        oPlayer:Set("send_return_mail", 1)
    end

    self:RefershReturnGoldCoin(oPlayer)
end

function CHuodong:HasGetReward(oPlayer)
    local mCbtPay = oPlayer.m_mCbtPay
    if mCbtPay.free_gift then
        return true
    end
    local iReward = self:PackRewardVal(mCbtPay)
    if iReward ~= 0 then
        return true
    end
    if oPlayer:Query("returngoldcoin_gift_1_buy", 0) > 0 then
        return true
    end
    if oPlayer:Query("returngoldcoin_gift_2_buy", 0) > 0 then
        return true
    end
    return false
end

function CHuodong:RefershReturnGoldCoin(oPlayer)
    local mCbtPay = oPlayer.m_mCbtPay
    local mNet = {
        cbtpay = mCbtPay.paycount,
        reward = self:PackRewardVal(mCbtPay),
        free_gift = mCbtPay.free_gift and 1 or 0,
        gift_1_time = oPlayer:Query("returngoldcoin_gift_1_time", 0),
        gift_1_buy = oPlayer:Query("returngoldcoin_gift_1_buy", 0),
        gift_2_time = oPlayer:Query("returngoldcoin_gift_2_time", 0),
        gift_2_buy = oPlayer:Query("returngoldcoin_gift_2_buy", 0),
    }
    oPlayer:Send("GS2CReturnGoldCoinRefresh", mNet)
end

function CHuodong:PackRewardVal(mCbtPay)
    local iResult = 0
    for sCnt, mInfo in pairs(mCbtPay.reward or {}) do
        iResult = iResult | 0x1<<(tonumber(sCnt)-1)
    end
    return iResult
end

function CHuodong:IsRewardByKey(mCbtPay, iKey)
    local iReward = self:PackRewardVal(mCbtPay)
    return iReward & 0x1<<(iKey-1) == 0x1<<(iKey-1)
end

function CHuodong:ValidGetReturnGoldCoin(oPlayer, iKey)
    if not global.oToolMgr:IsSysOpen("RETURNGOLDCOIN", oPlayer, true) then
        return 1009
    end

    if not oPlayer.m_mCbtPay then
        return 1002
    end
    local iTotal = oPlayer.m_mCbtPay.paycount
    assert(iTotal > 0)

    local mConfig = self:GetConfigByPayCount(iTotal)
    if not mConfig then return 1003 end

    local sKey = self:GetKeyWordByKey(iKey)
    if not sKey then return 1003 end

    local sReward = table_get_depth(mConfig, {sKey, "reward"})
    if not sReward or sReward == "0" then return 1003 end

    local iGrade = table_get_depth(mConfig, {sKey, "grade"})
    if oPlayer:GetGrade() < iGrade then
        return 1004
    end
    return 1
end

function CHuodong:C2GSReturnGoldCoinGetReturn(oPlayer, iKey)
    local iPid = oPlayer:GetPid()
    local iRet = self:ValidGetReturnGoldCoin(oPlayer, iKey)
    if iRet ~= 1 then
        self:Notify(iPid, iRet)
        return
    end

    if self:IsRewardByKey(oPlayer.m_mCbtPay, iKey) then
        self:Notify(iPid, 1001)
        return
    end

    local mArgs = {
        account = oPlayer:GetAccount(),
        channel = oPlayer:GetChannel(),
        pid = iPid,
        name = oPlayer:GetName(),
        key = iKey,
    }
    router.Request("cs", ".datacenter", "common", "TryGetReturnReward", mArgs,
    function(mRecord, mData)
        self:TryGetReturnReward1(iPid, iKey, mData.errcode, mData.cbtpay)
    end)
end

function CHuodong:TryGetReturnReward1(iPid, iKey, iErrCode, mCbtPay)
    local oPlayer = global.oWorldMgr:GetOnlinePlayerByPid(iPid)
    if not oPlayer then return end

    if iErrCode ~= 0 then
        if iErrCode == 1 then
            self:Notify(iPid, 1003)
        else
            self:Notify(iPid, 1001)
            oPlayer.m_mCbtPay = mCbtPay
            self:RefershReturnGoldCoin(oPlayer)
        end
        return
    end

    oPlayer.m_mCbtPay = mCbtPay
    local iRet = self:ValidGetReturnGoldCoin(oPlayer, iKey)
    if iRet ~= 1 then
        self:Notify(iPid, iRet)
        return
    end

    local iTotal = oPlayer.m_mCbtPay.paycount
    local mConfig = self:GetConfigByPayCount(iTotal)
    local sKey = self:GetKeyWordByKey(iKey)
    local sReward = mConfig[sKey].reward
    local mEnv = {money = iTotal}

    local mFormulaConfig = self:GetFormulaConfig()
    local mFormula = mFormulaConfig[sReward]
    local iGoldCoin, iRplGoldCoin = 0, 0
    if sReward == "all" then
        iGoldCoin = math.floor(formula_string(mFormulaConfig.goldcoin.formula, mEnv))
        iRplGoldCoin = math.floor(formula_string(mFormulaConfig.rplgoldcoin.formula, mEnv))
    elseif sReward == "goldcoin" then
        iGoldCoin = math.floor(formula_string(mFormula.formula, mEnv))
    else
        iRplGoldCoin = math.floor(formula_string(mFormula.formula, mEnv))
    end

    if iGoldCoin > 0 then
        oPlayer:ChargeGold(iGoldCoin, "封测返还")
    end
    if iRplGoldCoin > 0 then
        oPlayer:RewardGoldCoin(iRplGoldCoin, "封测返还")
    end
    self:RefershReturnGoldCoin(oPlayer)
    --TODO log
end

function CHuodong:ValidGetReturnFreeGift(oPlayer)
    if not global.oToolMgr:IsSysOpen("RETURNGOLDCOIN", oPlayer, true) then
        return 1009
    end

    if not oPlayer.m_mCbtPay then
        return 1006
    end
    local iTotal = oPlayer.m_mCbtPay.paycount
    assert(iTotal > 0)

    local mConfig = self:GetRewardConfigByPayCount(iTotal)
    if not mConfig then return 1006 end

    return 1
end

function CHuodong:C2GSReturnGoldCoinGetFreeGift(oPlayer)
    local iPid = oPlayer:GetPid()
    local iRet = self:ValidGetReturnFreeGift(oPlayer)
    if iRet ~= 1 then
        self:Notify(iPid, iRet)
        return
    end
    if oPlayer.m_mCbtPay.free_gift then
        self:Notify(iPid, 1007)
        return
    end

    local mArgs = {
        account = oPlayer:GetAccount(),
        channel = oPlayer:GetChannel(),
        pid = iPid,
        name = oPlayer:GetName(),
    }

    router.Request("cs", ".datacenter", "common", "TryGetFreeGift", mArgs,
    function(mRecord, mData)
        self:TryGetFreeGift(iPid, mData.errcode, mData.cbtpay)
    end)
end

function CHuodong:TryGetFreeGift(iPid, iErrCode, mCbtPay)
    local oPlayer = global.oWorldMgr:GetOnlinePlayerByPid(iPid)
    if not oPlayer then return end

    if iErrCode ~= 0 then
        if iErrCode == 1 then
            self:Notify(iPid, 1006)
        else
            self:Notify(iPid, 1007)
            oPlayer.m_mCbtPay = mCbtPay
            self:RefershReturnGoldCoin(oPlayer)
        end
        return
    end

    oPlayer.m_mCbtPay = mCbtPay
    local iRet = self:ValidGetReturnFreeGift(oPlayer)
    if iRet ~= 1 then
        self:Notify(iPid, iRet)
        return
    end

    local mConfig = self:GetRewardConfigByPayCount(mCbtPay.paycount)
    self:Reward(iPid, mConfig.reward_idx)
    self:RefershReturnGoldCoin(oPlayer)
end

function CHuodong:ValidBuyGift(oPlayer, iKey)
    if not oPlayer.m_mCbtPay then return 1008 end

    local iTotal = oPlayer.m_mCbtPay.paycount
    local mConfig = self:GetRewardConfigByPayCount(iTotal)
    if not mConfig then return 1008 end

    if iKey ~= 1 and iKey ~= 2 then
        return 1008
    end
    if not global.oToolMgr:IsSysOpen("RETURNGOLDCOIN", oPlayer, true) then
        return 1009
    end
    if iKey == 1 then
        if get_time() > oPlayer:Query("returngoldcoin_gift_1_time", 0) then
            return 1010
        end
        if oPlayer:Query("returngoldcoin_gift_1_buy", 0) >= 1 then
            return 1011
        end
        if oPlayer:GetGoldCoin() < mConfig.gift_1.cost then
            return 1012
        end
    else
        if get_time() > oPlayer:Query("returngoldcoin_gift_2_time", 0) then
            return 1010
        end
        if oPlayer:Query("returngoldcoin_gift_2_buy", 0) >= 1 then
            return 1011
        end
        if oPlayer:GetGoldCoin() < mConfig.gift_2.cost then
            return 1012
        end
    end
    return 1
end

function CHuodong:C2GSReturnGoldCoinBuyGift(oPlayer, iKey)
    local iPid = oPlayer:GetPid()
    local iRet = self:ValidBuyGift(oPlayer, iKey)
    if iRet ~= 1 then
        self:Notify(iPid, iRet)
        return
    end

    local iTotal = oPlayer.m_mCbtPay.paycount
    local mConfig = self:GetRewardConfigByPayCount(iTotal)
    local mReward, sKey
    if iKey == 1 then
        mReward = mConfig.gift_1
        sKey = "returngoldcoin_gift_1_buy"
    else
        mReward = mConfig.gift_2
        sKey = "returngoldcoin_gift_2_buy"
    end

    oPlayer:ResumeGoldCoin(mReward.cost, "封测返还购买神秘礼包")
    oPlayer:Set(sKey, 1)
    self:Reward(iPid, mReward.reward_idx)
    self:RefershReturnGoldCoin(oPlayer)
end

function CHuodong:Notify(iPid, iChat, mReplace)
    local oNotifyMgr = global.oNotifyMgr
    local sMsg = self:GetTextData(iChat)
    if mReplace then
        sMsg = global.oToolMgr:FormatColorString(sMsg, mReplace)
    end
    oNotifyMgr:Notify(iPid, sMsg)
end

function CHuodong:GetConfigByPayCount(iPay)
    local mConfig = self:GetConfig()
    for i, mInfo in pairs(mConfig) do
        if iPay <= mInfo.money_range.max then
            return mInfo
        end
    end
end

function CHuodong:GetRewardConfigByPayCount(iPay)
    local mConfig = self:GetRewardConfig()
    for i, mInfo in pairs(mConfig) do
        if iPay <= mInfo.money_range.max then
            return mInfo
        end
    end
end

function CHuodong:GetConfig()
    return res["daobiao"]["huodong"]["returngoldcoin"]["config"]
end

function CHuodong:GetFormulaConfig()
    return res["daobiao"]["huodong"]["returngoldcoin"]["formula_config"]
end

function CHuodong:GetRewardConfig()
    return res["daobiao"]["huodong"]["returngoldcoin"]["reward_config"]
end

function CHuodong:GetKeyWordByKey(iKey)
    local mTransTbl = {
        [1] = "first_reward",
        [2] = "second_reward",
        [3] = "third_reward",
    }
    return mTransTbl[iKey]
end

function CHuodong:TestOp(iFlag, mArgs)
    local iPid = mArgs[#mArgs]
    local oMaster = global.oWorldMgr:GetOnlinePlayerByPid(iPid)
    if iFlag == 100 then
        global.oNotifyMgr:Notify(iPid, [[
        101 - 设置cbt充值金额
        ]])
    elseif iFlag == 101 then
        oMaster.m_mCbtPay = {paycount=mArgs[1]}
        self:OnLogin(oMaster)
        local mInfo = {
            account = oMaster:GetAccount(),
            channel = oMaster:GetChannel(),
            paycount = mArgs[1],
        }
        router.Request("cs", ".datacenter", "common", "GmSetCbtData", mInfo,
        function(mRecord, mData)
            local oPlayer = global.oWorldMgr:GetOnlinePlayerByPid(iPid)
            if oPlayer then
                oPlayer.m_mCbtPay = mData.cbtpay 
                self:OnLogin(oPlayer)
            end
        end)
    elseif iFlag == 102 then
        self:C2GSReturnGoldCoinGetReturn(oMaster, mArgs[1])
    elseif iFlag == 103 then
        self:C2GSReturnGoldCoinGetFreeGift(oMaster)
    elseif iFlag == 104 then
        self:C2GSReturnGoldCoinBuyGift(oMaster, mArgs[1])
    end
end
