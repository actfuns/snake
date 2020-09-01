local global = require "global"
local skynet = require "skynet"
local res = require "base.res"
local record = require "public.record"
local gamedefines = import(lualib_path("public.gamedefines"))
local analylog = import(lualib_path("public.analylog"))

function NewWingMgr()
    return CWingMgr:New()
end

CWingMgr = {}
CWingMgr.__index = CWingMgr
inherit(CWingMgr, logic_base_cls())

function CWingMgr:New()
    local o = super(CWingMgr).New(self)
    return o
end

function CWingMgr:WingUpStar(oPlayer, iUseGoldCoin)
    if not global.oToolMgr:IsSysOpen("WING", oPlayer, true) then
        return
    end

    local oEquip = oPlayer.m_oItemCtrl:GetWing()
    if not oEquip then
        return
    end

    local iPid = oPlayer:GetPid()
    local oCtrl = oPlayer.m_oWingCtrl
    local iCurrStar = oCtrl:GetStar()
    local iMaxStar = oCtrl:GetMaxStar()
    if iCurrStar >= iMaxStar then
        self:Notify(iPid, 1001)
        return
    end
    local iNeedExp = oCtrl:GetUpStarUseExp(iCurrStar+1)
    if iNeedExp <= 0 then
        self:Notify(iPid, 1001)
        return
    end

    local bGoldCoin = iUseGoldCoin == 1
    local mConfig = self:GetConfig()
    local iNeedSid = mConfig.star_cost
    local iHasAmount = oPlayer:GetItemAmount(iNeedSid)
    if iHasAmount <= 0 and not bGoldCoin then
        self:Notify(iPid, 1004)
        return
    end

    local oCacheItem = global.oItemLoader:GetItem(iNeedSid)
    local iOneAdd = oCacheItem:CalItemFormula(oPlayer)
    local sReason = "羽翼升星"
    local sAddReason = ""
    local iTotalAdd = 0
    local iNeedAmount = math.ceil(iNeedExp / iOneAdd)
    local mCostItem = {[iNeedSid] = iNeedAmount}
    local mAnaly = {}

    if not bGoldCoin then
        local iCostAmount = math.min(iHasAmount, iNeedAmount)
        oPlayer:RemoveItemAmount(iNeedSid, iCostAmount, sReason)
        iTotalAdd = iOneAdd * iCostAmount
        sAddReason = string.format("%s(%s)", oCacheItem:Name(), iCostAmount)
        mAnaly[iNeedSid] = iCostAmount
    else
        local bSucc, mLogCost = global.oFastBuyMgr:FastBuy(oPlayer, {item=mCostItem}, sReason)
        if not bSucc then return end

        iTotalAdd = iOneAdd * iNeedAmount

        sAddReason = sAddReason .. string.format("%s(%s)、", oCacheItem:Name(), mLogCost["item"][iNeedSid] or 0)
        sAddReason = sAddReason .. string.format("goldcoin(%s)", mLogCost.goldcoin or 0)
        mAnaly[iNeedSid] = mLogCost["item"][iNeedSid]
        mAnaly[gamedefines.MONEY_TYPE.GOLDCOIN] = mLogCost.goldcoin
    end
    if iTotalAdd > 0 then
        self:Notify(iPid, 1002, {amount = iTotalAdd})
        oCtrl:AddExp(iTotalAdd, sAddReason)
        analylog.LogSystemInfo(oPlayer, "upstar_wing", nil, mAnaly)
    end
end

function CWingMgr:WingUpLevel(oPlayer, iUseGoldCoin)
    if not global.oToolMgr:IsSysOpen("WING", oPlayer, true) then
        return
    end

    local oEquip = oPlayer.m_oItemCtrl:GetWing()
    if not oEquip then
        return
    end

    local iPid = oPlayer:GetPid()
    local oCtrl = oPlayer.m_oWingCtrl
    local iCurrStar = oCtrl:GetStar()
    local iMaxStar = oCtrl:GetMaxStar()
    if iCurrStar < iMaxStar then
        self:Notify(iPid, 2001)
        return
    end
    local iLevel = oCtrl:GetLevel()
    local iMaxLevel = oCtrl:GetMaxLevel()
    if iLevel >= iMaxLevel then
        self:Notify(iPid, 2002)
        return
    end

    local mLevelCost = self:GetUpLevelCost()
    if not mLevelCost[iLevel+1] then
        self:Notify(iPid, 2002)
        return
    end

    local mConfig = self:GetConfig()
    local sReason = "羽翼升阶"
    local lReason = {}
    local bGoldCoin = iUseGoldCoin == 1
    local lUnEnoughItem = {}
    local mCostItem = {}
    local mAnaly = {}

    local lCostList = mLevelCost[iLevel+1].up_level_cost
    for _, mCost in ipairs(lCostList) do
        local iSid = mCost.sid
        local iAmount = mCost.amount
        mCostItem[iSid] = iAmount
        local iHasAmount = oPlayer:GetItemAmount(iSid)
        if iHasAmount < iAmount then
            local oItem = global.oItemLoader:GetItem(iSid)
            table.insert(lUnEnoughItem, oItem:Name())
        end
    end
    if not bGoldCoin then
        if #lUnEnoughItem > 0 then
            self:Notify(iPid, 2004, {item=table.concat(lUnEnoughItem, "、")})
            return
        end
        for _, mCost in ipairs(lCostList) do
            oPlayer:RemoveItemAmount(mCost.sid, mCost.amount, sReason)
            table.insert(lReason, string.format("%s(%s)", mCost.sid, mCost.amount))
            mAnaly[mCost.sid] = mCost.amount
        end
    else
        local bSucc, mLogCost = global.oFastBuyMgr:FastBuy(oPlayer, {item=mCostItem}, sReason)
        if not bSucc then return end

        for iSid, iAmount in pairs(mLogCost.item or {}) do
            table.insert(lReason, string.format("%s(%s)", iSid, iAmount))
            mAnaly[iSid] = iAmount
        end
        if mLogCost.goldcoin then
            table.insert(lReason, string.format("goldcoin(%s)", mLogCost.goldcoin))
            mAnaly[gamedefines.MONEY_TYPE.GOLDCOIN] = mLogCost.goldcoin
        end
    end

    oCtrl:AddLevel(1, table.concat(lReason, "、"))
    analylog.LogSystemInfo(oPlayer, "uplevel_wing", nil, mAnaly)
end

function CWingMgr:WieldWing(oPlayer)
    if not global.oToolMgr:IsSysOpen("WING", oPlayer) then
        return
    end

    local oEquip = oPlayer.m_oItemCtrl:GetWing()
    if oEquip then
        return
    end
   
    local mConfig = self:GetConfig()
    local iPid = oPlayer:GetPid() 
    local iSid = mConfig.wield_sid

    local iAmount = oPlayer:GetItemAmount(iSid)
    if iAmount < 1 then
        self:Notify(oPlayer:GetPid(), 6001)
        return
    end
    
    local oEquip = oPlayer.m_oItemCtrl:GetOneItem(iSid)
    oPlayer.m_oItemCtrl:AddWing(oEquip)
    local mRefresh = oPlayer.m_oWingCtrl:CalBaseAttr()
    global.oScoreCache:Dirty(oPlayer:GetPid(), "wingctrl")
    oPlayer.m_oWingCtrl:PropWingChange({id=1})
    oPlayer.m_oWingCtrl:PropWingChange(mRefresh, true)
    oPlayer:MarkGrow(51)
    
    local lWings = oPlayer.m_oWingCtrl:GetLevelUnlockWings()
    if #lWings > 0 then
        oPlayer.m_oWingCtrl:SetShowWing(lWings[#lWings])
    end
end

function CWingMgr:ActiveWing(oPlayer, iWing)
    if not global.oToolMgr:IsSysOpen("WING", oPlayer, true) then
        return
    end

    local oEquip = oPlayer.m_oItemCtrl:GetWing()
    if not oEquip then
        return
    end

    local iPid = oPlayer:GetPid()
    local mAllWing = self:GetWingInfo()
    if not mAllWing[iWing] then
        self:Notify(iPid, 3001)
        return
    end
    if mAllWing[iWing].time_wing ~= 1 then
        self:Notify(iPid, 3001)
        return
    end

    local oWing = oPlayer.m_oWingCtrl:GetTimeWing(iWing)
    if oWing then
        self:Notify(iPid, 3002)
        return
    end

    local iDays = mAllWing[iWing].days
    local lActiveCost = mAllWing[iWing].active_cost
    local oCtrl = oPlayer.m_oWingCtrl
    local lUnEnough = {}
    local mAnaly = {}

    for _, mCost in ipairs(lActiveCost) do
        if oPlayer:GetItemAmount(mCost.sid) < mCost.amount then
            local oItem = global.oItemLoader:GetItem(mCost.sid)
            table.insert(lUnEnough, oItem:Name())
        end
    end

    if #lUnEnough > 0 then
        self:Notify(iPid, 3003, {item=table.concat(lUnEnough, "、")})
        return
    end

    local sReason = "激活翅膀-"..mAllWing[iWing].name
    local lReason = {}
    for _, mCost in ipairs(lActiveCost) do
        oPlayer:RemoveItemAmount(mCost.sid, mCost.amount, sReason)
        table.insert(lReason, string.format("%s(%s)", mCost.sid, mCost.amount))
        mAnaly[mCost.sid] = mCost.amount
    end

    oPlayer:MarkGrow(51)
    oCtrl:AddTimeWing(iWing, table.concat(lReason, "、"))
    self:Notify(iPid, 3004, {wing=mAllWing[iWing].name})
    analylog.LogSystemInfo(oPlayer, "buytime_wing", iWing, mAnaly)
end

function CWingMgr:AddWingTime(oPlayer, iWing, iTime)
    if not global.oToolMgr:IsSysOpen("WING", oPlayer, true) then
        return
    end

    local oEquip = oPlayer.m_oItemCtrl:GetWing()
    if not oEquip then
        return
    end

    local iPid = oPlayer:GetPid()
    local mAllWing = self:GetWingInfo()
    if not mAllWing[iWing] then
        self:Notify(iPid, 3001)
        return
    end

    local oWing = oPlayer.m_oWingCtrl:GetTimeWing(iWing)
    if not oWing then
        self:Notify(iPid, 4001)
        return
    end
    if oWing:IsForever() then
        self:Notify(iPid, 4002)
        return
    end
    
    local iCostMoney, iMoneyType = nil, nil
    for _, mBuy in ipairs(mAllWing[iWing].buy_times) do
        if mBuy.days == iTime then
            iCostMoney, iMoneyType = mBuy.cost, mBuy.money_type
        end
    end
    if not iCostMoney or not iMoneyType then
        self:Notify(iPid, 4003)
        return
    end

    local sReason = string.format("翅膀(%s)续费", iWing)
    if res["daobiao"]["item"][iMoneyType] then
        if oPlayer:GetItemAmount(iMoneyType) < iCostMoney then
            local oItem = global.oItemLoader:GetItem(iMoneyType)
            self:Notify(iPid, 3003, {item=oItem:Name()})
            return
        end
        oPlayer:RemoveItemAmount(iMoneyType, iCostMoney, sReason)
    else
        if not oPlayer:ValidMoneyByType(iMoneyType, iCostMoney) then
            return
        end
        oPlayer:ResumeMoneyByType(iMoneyType, iCostMoney, sReason)
    end

    if iTime == -1 then
        oWing:SetTime(iTime)
        self:Notify(iPid, 4005, {wing=mAllWing[iWing].name})
    else
        oWing:AddTime(iTime*24*3600)
        self:Notify(iPid, 4004, {wing=mAllWing[iWing].name, time=iTime})
    end
    oPlayer.m_oWingCtrl:CalNextExpireTime()
    oPlayer.m_oWingCtrl:CheckSelf(oPlayer)
    oPlayer.m_oWingCtrl:OnAddTimeWing(iWing)
    --oPlayer.m_oWingCtrl:RefreshOneTimeWing(iWing)
    
    local mLogData = oPlayer:LogData()
    local iExpire = oWing:GetExpire()
    mLogData.wing = iWing
    mLogData.expire = iExpire == -1 and "永久" or get_format_time(iExpire)
    record.log_db("wing", "time_wing", mLogData)

    local mAnaly = {[iMoneyType] = iCostMoney}
    analylog.LogSystemInfo(oPlayer, "buytime_wing", iWing, mAnaly)
end

function CWingMgr:SetShowWing(oPlayer, iWing)
    if not global.oToolMgr:IsSysOpen("WING", oPlayer, true) then
        return
    end

    local oEquip = oPlayer.m_oItemCtrl:GetWing()
    if not oEquip then
        return
    end

    local iPid = oPlayer:GetPid()
    if iWing ~= 0 then
        local mAllWing = oPlayer.m_oWingCtrl:GetAllWing()
        if not mAllWing[iWing] then
            self:Notify(iPid, 3001)
            return
        end
    
        local oWing = oPlayer.m_oWingCtrl:GetTimeWing(iWing)
        if oWing and oWing:IsExpire() then
            self:Notify(iPid, 5001)
            return
        end
    end

    oPlayer.m_oWingCtrl:SetShowWing(iWing)
end

function CWingMgr:GetConfig()
    return res["daobiao"]["wing"]["config"][1]
end

function CWingMgr:GetUpLevelCost()
    return res["daobiao"]["wing"]["up_level"]
end

function CWingMgr:GetWingInfo()
    return res["daobiao"]["wing"]["wing_info"]
end

function CWingMgr:GetWingEffect(iWing, iSchool, mEnv)
    local mWing = res["daobiao"]["wing"]["wing_info"][iWing]
    local iEffect = mWing["wing_effect"][iSchool]
    local sEffect = res["daobiao"]["wing"]["wing_effect"][iEffect]["wing_effect"]
    return formula_string(sEffect, mEnv or {})
end

function CWingMgr:Notify(iPid, iChat, mReplace)
    local oNotifyMgr = global.oNotifyMgr
    local sMsg = global.oToolMgr:GetTextData(iChat, {"wing"})
    if mReplace then
        sMsg = global.oToolMgr:FormatColorString(sMsg, mReplace)
    end
    oNotifyMgr:Notify(iPid, sMsg)
end

