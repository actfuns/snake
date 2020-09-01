local global = require "global"
local res = require "base.res"
local interactive = require "base.interactive"
local record = require "public.record"

local gamedefines = import(lualib_path("public.gamedefines"))
local datactrl = import(lualib_path("public.datactrl"))
local analylog = import(lualib_path("public.analylog"))

CShop = {}
CShop.__index = CShop
inherit(CShop, datactrl.CDataCtrl)

function CShop:New(iShopID,sName)
    local o = super(CShop).New(self)
    o.m_sName = sName
    o.m_iID = iShopID
    return o
end

function CShop:Init()

end

function CShop:ShopID()
    return self.m_iID
end

function CShop:GetGoodData(iGood)
    local mShopData = res["daobiao"]["shop"][self.m_sName]
    assert(mShopData,string.format("error shop %s",self.m_sName))
    local mGoodData = mShopData[iGood]
    assert(mGoodData,string.format("error good %s %s",self.m_sName,iGood))
    return mGoodData
end

function CShop:GetShopData()
    local mShopData = res["daobiao"]["shop"][self.m_sName]
    assert(mShopData,string.format("error shop %s",self.m_sName))
    return mShopData
end

function CShop:GetTextData(iText)
    local oToolMgr = global.oToolMgr
    return oToolMgr:GetTextData(iText, {"shop"})
end

function CShop:GetDayLimitFlag(iGood)
    return string.format("shopday_%s_%s",self:ShopID(),iGood)
end

function CShop:GetWeekLimitFlag(iGood)
    return string.format("shopweek_%s_%s",self:ShopID(),iGood)
end

function CShop:GetForeverLimitFlag(iGood)
    return string.format("shopforever_%s_%s",self:ShopID(),iGood)
end

function CShop:ValidBuy(oPlayer,iGood,iAmount,iMoneyType)
    local oNotifyMgr = global.oNotifyMgr
    local oToolMgr = global.oToolMgr
    local iGrade = oPlayer:GetGrade()
    local pid = oPlayer:GetPid()
    local mGoodData = self:GetGoodData(iGood)

    if iAmount<= 0 then
        return false
    end

    if mGoodData["grade_limit"] > iGrade  then
        local sText  =  self:GetTextData(1001)
        sText = oToolMgr:FormatColorString(sText,{grade = mGoodData["grade_limit"]})
        oNotifyMgr:Notify(pid,sText)
        return false
    end

    local iDayLimit = mGoodData["day_limit"]
    if iDayLimit > 0 then
        local sDayLimitFlag = self:GetDayLimitFlag(iGood)
        local iCurCnt = oPlayer.m_oTodayMorning:Query(sDayLimitFlag,0)
        if iCurCnt>= iDayLimit then
            oNotifyMgr:Notify(pid,self:GetTextData(1002))
            return false
        end
        if iCurCnt+iAmount >iDayLimit then
            local sText  =  self:GetTextData(1007)
            sText = oToolMgr:FormatColorString(sText,{amount = iDayLimit})
            oNotifyMgr:Notify(pid,sText)
            return false
        end
    end

    local iWeekLimit = mGoodData["week_limit"]
    if iWeekLimit > 0 then
        local sWeekLimitFlag = self:GetWeekLimitFlag(iGood)
        local iCurCnt = oPlayer.m_oWeekMorning:Query(sWeekLimitFlag,0)
        if iCurCnt>= iWeekLimit then
            oNotifyMgr:Notify(pid,self:GetTextData(1003))
            return false
        end
        if iCurCnt+iAmount >iWeekLimit then
            local sText  =  self:GetTextData(1008)
            sText = oToolMgr:FormatColorString(sText,{amount = iWeekLimit})
            oNotifyMgr:Notify(pid,sText)
            return false
        end
    end
    local iForeverLimit = mGoodData["forever_limit"]
    if iForeverLimit > 0 then
        local sForeverLimitFlag = self:GetForeverLimitFlag(iGood)
        local iCurCnt = oPlayer:Query(sForeverLimitFlag, 0)
        if iCurCnt >= iForeverLimit then
            oNotifyMgr:Notify(pid,self:GetTextData(1003))
            return false
        end
        if iCurCnt+iAmount > iForeverLimit then
            local sText  =  self:GetTextData(1008)
            sText = oToolMgr:FormatColorString(sText,{amount = iForeverLimit})
            oNotifyMgr:Notify(pid,sText)
            return false
        end
    end

    local mMoney = mGoodData["money"]
    if not mMoney[iMoneyType] then
        local sText  =  self:GetTextData(1004)
        local sMoney = "未知货币"
        if gamedefines.MONEY_NAME[iMoneyType] then
            sMoney = gamedefines.MONEY_NAME[iMoneyType]
        end
        sText = oToolMgr:FormatColorString(sText,{money = sMoney})
        oNotifyMgr:Notify(pid,sText)
        return
    end
    local iNeedValue = math.floor(iAmount*mMoney[iMoneyType]["count"])
    if mGoodData["discount"]>0 then
        local iDisCount = mGoodData["discount"]
        assert(iDisCount>0 and iDisCount<100,string.format("error discount %s %s %s",self.m_sName,iGood,iDisCount))
        iNeedValue = math.floor(iNeedValue*(100-iDisCount)/100.0)
    end

    if not oPlayer:ValidMoneyByType(iMoneyType, iNeedValue) then
        return false
    end
    
    local sShape = mGoodData["item_attr"]
    local itemobj = global.oItemLoader:ExtCreate(sShape)
    if not itemobj then 
        return false
    end

    local iBind = mGoodData["bind"]
    if iBind and iBind > 0 then
        itemobj:Bind(oPlayer:GetPid())     
    end
    itemobj:SetAmount(iAmount)
    if not oPlayer:ValidGiveitemlist({itemobj}) then
        oNotifyMgr:Notify(pid,self:GetTextData(1006))
        return false
    end
    return true
end

function CShop:DoBuy(oPlayer,iGood,iAmount,iMoneyType)
    if not self:ValidBuy(oPlayer,iGood,iAmount,iMoneyType) then
        return
    end
    local oNotifyMgr = global.oNotifyMgr
    local oToolMgr = global.oToolMgr
    local oItemLoader= global.oItemLoader
    local iGrade = oPlayer:GetGrade()
    local pid = oPlayer:GetPid()
    local mGoodData = self:GetGoodData(iGood)

    local itemsid = mGoodData["itemsid"]
    local mMoney = mGoodData["money"]
    local iMoneyValue = math.floor(iAmount*mMoney[iMoneyType]["count"])
    if mGoodData["discount"]>0 then
        iMoneyValue = math.floor(iMoneyValue*(100-mGoodData["discount"])/100.0)
    end

    local mLogData = {}
    mLogData["pid"] = pid
    mLogData["name"] = oPlayer:GetName()
    mLogData["shop"] = self:ShopID()
    mLogData["good"] = iGood
    mLogData["amount"] = iAmount
    mLogData["moneytype"] = iMoneyType
    mLogData["moneyvalue"] = iMoneyValue
    record.log_db("shop", "buy_good", mLogData)

    oPlayer:ResumeMoneyByType(iMoneyType, iMoneyValue, string.format("shop_%s", self.m_sName))

    local iDayLimit = mGoodData["day_limit"]
    if iDayLimit > 0 then
        local sDayLimitFlag = self:GetDayLimitFlag(iGood)
        oPlayer.m_oTodayMorning:Add(sDayLimitFlag,iAmount)
    end

    local iWeekLimit = mGoodData["week_limit"]
    if iWeekLimit > 0 then
        local sWeekLimitFlag = self:GetWeekLimitFlag(iGood)
        oPlayer.m_oWeekMorning:Add(sWeekLimitFlag,iAmount)
    end
    local iForeverLimit = mGoodData["forever_limit"]
    if iForeverLimit > 0 then
        local sForeverLimitFlag = self:GetForeverLimitFlag(iGood)
        local iCurr = oPlayer:Query(sForeverLimitFlag, 0)
        oPlayer:Set(sForeverLimitFlag, iCurr+iAmount)
    end

    self:RewardItem(oPlayer,mGoodData["item_attr"],iAmount,mGoodData["bind"])

    if iWeekLimit>0 or iDayLimit >0 or iForeverLimit > 0 then
        self:RefreshGood(oPlayer,iGood)
    end

    analylog.LogMallBuy(oPlayer, self:ShopID(), iMoneyType, itemsid, iAmount, iMoneyValue)
    return true
end

--定制道具属性
function CShop:RewardItem(oPlayer,sShape,iAmount,iBind)
    local itemobj = global.oItemLoader:ExtCreate(sShape)
    if iBind and iBind > 0 then
        itemobj:Bind(oPlayer:GetPid())     
    end
    itemobj:SetAmount(iAmount)
    oPlayer:GiveItemobj({itemobj}, self.m_sName,{cancel_tip = true})
end

function CShop:RefreshGood(oPlayer,iGood)
    local mGoodData = self:PackGood(oPlayer,iGood)
    local mNet = {}
    mNet.shop = self:ShopID()
    mNet.good = mGoodData
    oPlayer:Send("GS2CRefreshGood",mNet)
end

function CShop:PackGood(oPlayer,iGood)
    local mGoodData = self:GetGoodData(iGood)
    local sDayLimitFlag = self:GetDayLimitFlag(iGood)
    local sWeekLimitFlag = self:GetWeekLimitFlag(iGood)
    local sForeverLimitFlag = self:GetForeverLimitFlag(iGood)
    local mMoney = mGoodData["money"]
    local mNetMoney  = {}
    for iMoneyType,mMoneyValue in pairs(mMoney) do
        table.insert(mNetMoney,{moneytype = iMoneyType,moneyvalue = mMoneyValue["count"]})
    end
    local mNet = {}
    mNet.goodid = iGood
    mNet.itemsid = mGoodData["itemsid"]
    mNet.discount = mGoodData["discount"]
    mNet.limit = mGoodData.day_limit + mGoodData.week_limit + mGoodData.forever_limit
    mNet.dayamount = math.max(0,mGoodData["day_limit"] - oPlayer.m_oTodayMorning:Query(sDayLimitFlag,0))
    mNet.weekamount = math.max(0,mGoodData["week_limit"] - oPlayer.m_oWeekMorning:Query(sWeekLimitFlag,0))
    mNet.foreveramount = math.max(0, mGoodData["forever_limit"] - oPlayer:Query(sForeverLimitFlag, 0))
    mNet.money = mNetMoney
    return mNet
end

function CShop:PackAllGood(oPlayer)
    local mNet = {}
    local mShopData = self:GetShopData()
    for iGood,_ in pairs(mShopData) do
        table.insert(mNet,self:PackGood(oPlayer,iGood))
    end
    return mNet
end

function CShop:OpenShop(oPlayer)
    local mAllGood = self:PackAllGood(oPlayer)
    local mNet = {}
    mNet.shop = self:ShopID()
    mNet.goodlist = mAllGood
    oPlayer:Send("GS2CEnterShop",mNet)
end

function CShop:DailyRewardMoneyInfo(oPlayer)
    local sMoney = string.upper(self.m_sName)
    local iAmount,lRewardInfo = 0, nil
    if sMoney == "XIAYIPOINT" then
        iAmount,lRewardInfo = oPlayer.m_oActiveCtrl:StatisticsXiayiPointSource()
    elseif sMoney == "LEADERPOINT" then
        iAmount,lRewardInfo = oPlayer.m_oActiveCtrl:StatisticsLeaderPointSource()
    elseif sMoney == "CHUMOPOINT" then
        iAmount,lRewardInfo = oPlayer.m_oActiveCtrl:StatisticsChumoPointSource()
    else
        return
    end
    
    if not lRewardInfo or iAmount == 0 then return end
    local mNet = {}
    mNet.moneytype = gamedefines.MONEY_TYPE[sMoney]
    mNet.dailyrewardamount = iAmount
    mNet.rewardmoneylist = {}
    for iKey,iValue in pairs(lRewardInfo) do
        if iValue > 0 then
            local mRewardSource = {}
            mRewardSource.source = iKey
            mRewardSource.moneyvalue = iValue
            table.insert(mNet.rewardmoneylist,mRewardSource)
        end
    end
    oPlayer:Send("GS2CDailyRewardMoneyInfo",mNet)
end

function CShop:GetBuyCost(iGood, iAmount, iMoneyType)
    local mGoodData = self:GetGoodData(iGood)
    if not mGoodData then
        record.warning(string.format("the shop_%s %d has no %d", self.m_sName, self.m_iID, iGood))
        return 0
    end
    local mMoney = mGoodData["money"]
    local iMoneyValue = math.floor(iAmount * mMoney[iMoneyType]["count"])
    if mGoodData["discount"] > 0 then
        iMoneyValue = math.floor(iMoneyValue * (100 - mGoodData["discount"]) / 100.0)
    end
    return iMoneyValue
end
