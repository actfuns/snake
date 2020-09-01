local global = require "global"
local record = require "public.record"
local res = require "base.res"

local gamedefines = import(lualib_path("public.gamedefines"))
local analy = import(lualib_path("public.dataanaly"))

function NewOperatorObj(...)
    local o = COperator:New(...)
    return o
end

--可卖不可买
mTmpShield = {
}

COperator = {}
COperator.__index = COperator
inherit(COperator, logic_base_cls())

function COperator:New(oTaskObj, ...)
    local o = super(COperator).New(self)
    o.m_oTaskObj = oTaskObj
    o:Init()
    return o
end

function COperator:Init()
end

function COperator:GetData()
    --获取导表数据来源
    return self.m_oTaskObj.m_mCatalog
end

function COperator:GetDataByGoodId(iGood)
    if mTmpShield[iGood] then
        return
    end
    return self.m_oTaskObj:GetItem(iGood)
end

function COperator:PackUnit(iGood, oPlayer)
    --打包单元数据内容
    local oItem = self:GetDataByGoodId(iGood)
    if not oItem then return end
    
    local sKey = "guild_buy_"..iGood
    local mNet = {}
    mNet.good_id = iGood
    mNet.sid = oItem:SID()
    mNet.amount = oItem:GetAmount()
    mNet.price = oItem:GetPrice()
    mNet.up_flag = oItem:GetUpFlag()
    mNet.has_buy = oPlayer.m_oTodayMorning:Query(sKey, 0)

    return mNet
end

function COperator:PackData(iCat, iSub, oPlayer)
    --打包所有数据
    local mResult = {}
    local mData = self:GetData()
    local mInfo = table_get_depth(mData, {iCat, iSub})

    for iGood, oItem in pairs(mInfo or {}) do
        if oItem:GetTableAttr("can_buy") == 1 then
            local mUnit = self:PackUnit(iGood, oPlayer)
            if mUnit then
                table.insert(mResult, mUnit)
            end
        end
    end
    return mResult
end

function COperator:SendData(oPlayer, iCat, iSub)
    --发送界面数据到客户端
    local mData = self:PackData(iCat, iSub, oPlayer)
    local mNet = {}
    mNet.cat_id = iCat
    mNet.sub_id = iSub
    mNet.data = mData
    oPlayer:Send("GS2COpenGuild", mNet)
end

function COperator:SendUnit(oPlayer, iGood)
    local mNet = self:PackUnit(iGood, oPlayer)
    if not mNet then return end
    oPlayer:Send("GS2CItemUnit", mNet)
end

function COperator:CheckBuy(oPlayer, iGood, iAmount)
    --检测是否可以购买
    local oItem = self:GetDataByGoodId(iGood)
    if not oItem then return 1001, 1 end
    
    local iSLV = global.oWorldMgr:GetServerGrade()
    if oItem:GetTableAttr("slv") > iSLV then
        return 1005, 1
    end

    if oItem:GetTableAttr("can_buy") ~= 1 then
        return 1005, 1
    end

    if iAmount<= 0 or iAmount>oItem:GetAmount() then
        return 1001, 1
    end

    local iDayBuyLimit = oItem:GetTableAttr("day_buy_limit")
    local sKey = "guild_buy_"..iGood
    if iDayBuyLimit > 0 and oPlayer.m_oTodayMorning:Query(sKey, 0)+iAmount > iDayBuyLimit then
        return 1011, 0
    end
    
    local iTotal = oItem:GetPrice() * iAmount
    if not oPlayer:ValidGold(iTotal, {cancel_tip=1}) then
        return 1002, 0
    end

    local iSid = oItem:SID()
    local mArgs = {[iSid] = function(itemobj)
        return self:CheckCombine(itemobj)
    end}
    if not oPlayer:ValidGive({[iSid] = iAmount}, mArgs) then
        return 1003, 0
    end

    local iMaxPrice = oItem:GetTableAttr("max_price")
    local iTruePrice = oItem:GetTruePrice()
    local bForbid,iForbidBuyyingPrice = oItem:GetDayForbidBuyyingPrice()
    if not bForbid then 
        if iTruePrice > iForbidBuyyingPrice and iTruePrice < iMaxPrice then
            return 1010,0
        end
    end

    return 1, 1
end

function COperator:CheckCombine(itemobj)
    return itemobj:IsGuildItem()
end

function COperator:DoBuy(oPlayer, iGood, iAmount)
    --购买操作
    local iRet, iRefresh = self:CheckBuy(oPlayer, iGood, iAmount)
    if iRet ~= 1 then
        if iRet == 1010 then
            local oItem = self:GetDataByGoodId(iGood)
            self:Notify(oPlayer, iRet, {item = oItem:Name()} )
        else
            self:Notify(oPlayer, iRet)
        end
    else
        local mLogData = oPlayer:LogData()
        local oItem = self:GetDataByGoodId(iGood)

        mLogData["sid"] = oItem:SID()
        mLogData["amount"] = iAmount
        mLogData["price_old"] = oItem:GetPrice()

        oItem:AddAmount(-iAmount)
        self:ResumeMoney(oPlayer, oItem, iAmount)
        self:RewardItem(oPlayer, oItem, iAmount)
        self:FloatPrice(oItem, iAmount)

        mLogData["price_now"] = oItem:GetPrice()
        mLogData["guild_amount"] = oItem:GetAmount()
        record.log_db("economic", "guild_buy", mLogData)

        -- 数据中心log
        local mAnalyLog = oPlayer:BaseAnalyInfo()
        mAnalyLog["operation"] = 2
        mAnalyLog["shop_id"] = 0
        mAnalyLog["currency_type"] = gamedefines.MONEY_TYPE.GOLD
        mAnalyLog["item_id"] = oItem:SID()
        mAnalyLog["num"] = iAmount
        mAnalyLog["consume_count"] = oItem:GetPrice() * iAmount
        mAnalyLog["remain_currency"] = oPlayer:GetGold()
        analy.log_data("ItemBuy", mAnalyLog)
    end

    if iRefresh == 1 then
        self:SendUnit(oPlayer, iGood)
    end
end

function COperator:ResumeMoney(oPlayer, oItem, iAmount)
    local iPrice = oItem:GetPrice()
    local iTotal = iPrice * iAmount
    -- local sReason = string.format("guild_buy_%d", oItem:SID())
    local sReason = "商会购买"
    oPlayer:ResumeGold(iTotal, sReason)
end

function COperator:RewardItem(oPlayer, oProxyItem, iAmount)
    local oNotifyMgr = global.oNotifyMgr
    local oChatMgr = global.oChatMgr
    local iPrice = oProxyItem:GetPrice()
    local iMax = oProxyItem:GetMaxAmount()
    local mArgs = {}
    mArgs.cancel_tip = true 
    mArgs.cancel_chat = true 
    local sMsg = "购买了%s个%s"
    local iGood = oProxyItem:GoodId()
    if 1266 <= iGood and iGood <= 1268 then
        local lGiveItem, sTipsName = {}, nil
        for i = 1, iAmount do
            local oNewItem = self:CreateItem(oProxyItem, 1)
            sTipsName = oNewItem:TipsName()
            local bCombine = false
            for _,oItem in pairs(lGiveItem) do
                if oItem:ValidCombine(oNewItem) then
                    oItem:AddAmount(1)
                    bCombine = true
                    baseobj_delay_release(oNewItem)
                    break
                end
            end
            if not bCombine then
                table.insert(lGiveItem, oNewItem)
            end
        end
        if not oPlayer:ValidGiveitemlist(lGiveItem, mArgs) then
            local mMail, sName = global.oMailMgr:GetMailInfo(9013)
            global.oMailMgr:SendMailNew(0, sName, oPlayer:GetPid(), mMail, {items=lGiveItem})
            oPlayer:NotifyMessage("背包格数量不足，已通过邮件发放，请前往邮箱查收")  
        else
            oPlayer:GiveItemobj(lGiveItem, "guild_buy",mArgs)
        end
        sMsg = string.format(sMsg,iAmount,sTipsName)
    else
        if iAmount <= iMax then
            local oItem = self:CreateItem(oProxyItem, iAmount)
            oPlayer:RewardItem(oItem, "guild_buy",mArgs)
            sMsg = string.format(sMsg,iAmount,oItem:TipsName())
        else
            local iGroup, iRet = iAmount//iMax, iAmount%iMax
            for i = 1, iGroup do
                local oItem = self:CreateItem(oProxyItem, iMax)
                oPlayer:RewardItem(oItem, "guild_buy",mArgs)
                sMsg = string.format(sMsg,iAmount,oItem:TipsName())
            end
            if iRet > 0 then
                local oItem = self:CreateItem(oProxyItem, iRet)
                oPlayer:RewardItem(oItem, "guild_buy",mArgs)
                sMsg = string.format(sMsg,iAmount,oItem:TipsName())
            end
        end
    end
    oNotifyMgr:ItemNotify(oPlayer:GetPid(), {sid=oProxyItem:SID(), amount=iAmount, type=1})
    oChatMgr:HandleMsgChat(oPlayer, sMsg)

    local iDayBuyLimit = oProxyItem:GetTableAttr("day_buy_limit")
    if iDayBuyLimit > 0 then
        local sKey = "guild_buy_"..oProxyItem:GoodId()
        oPlayer.m_oTodayMorning:Add(sKey, iAmount)
        local iRet = math.max(0, iDayBuyLimit - oPlayer.m_oTodayMorning:Query(sKey,0))
        if iRet <= 0 then
            self:Notify(oPlayer, 1012, {amount=iDayBuyLimit, item=oProxyItem.m_oDataCtrl:TipsName()})
        else
            self:Notify(oPlayer, 1013, {amount=iRet, item=oProxyItem.m_oDataCtrl:TipsName()})
        end
    end
end

function COperator:CreateItem(oProxyItem, iAmount)
    local oItem = global.oItemLoader:Create(oProxyItem:SID())
    oItem:SetData("guild_buy_price", oProxyItem:GetPrice())
    oItem:SetAmount(iAmount)
    return oItem
end

function COperator:FloatPrice(oProxyItem, iAmount)
    local iStandard = oProxyItem:GetTableAttr("standard")
    local iGradeLimit = global.oWorldMgr:GetServerGrade()
    local iSLV = oProxyItem:GetTableAttr("slv")
    local iPrice = oProxyItem:GetTruePrice()
    if iAmount > 0 then
        local iUpRatio = oProxyItem:GetTableAttr("up_ratio")
        local iFloatUnit = (iStandard/iGradeLimit) * iSLV * iPrice / 10000 * iUpRatio
        oProxyItem:SetPrice(iPrice + math.max(0, iFloatUnit*iAmount))
    else
        local iFloatUnit = (iStandard/iGradeLimit) * iSLV * iPrice / 10000
        oProxyItem:SetPrice(iPrice + math.min(0, iFloatUnit*iAmount))
    end
    
    local iLastPrice = oProxyItem:GetLastPrice()
    local iCurrPrice = oProxyItem:GetPrice()
    oProxyItem:SetUpFlag(iCurrPrice - iLastPrice)
end

function COperator:CheckSell(oPlayer, iItem, iAmount)
    --检测是否可以出售
    if iAmount < 1 then return 1009 end
    local oItem = oPlayer:HasItem(iItem)
    if not oItem then
        return 1006
    end
    if oItem:GetAmount() < iAmount then
        return 1007
    end
    if oItem:IsBind() then
        return 1009
    end
    if oItem:IsLocked() then
        return 1008
    end
    local iGood = self.m_oTaskObj:GetItemGoodId(oItem:SID())
    if not iGood or iGood <= 0 then
        return 1008
    end

    local mInfo = self.m_oTaskObj:GetDataByGoodId(iGood)
    if not mInfo or mInfo["can_sell"] ~= 1 then
        return 1008
    end

    if mInfo.slv > global.oWorldMgr:GetServerGrade() then
        return 1016, {slv = mInfo.slv}
    end
    return 1
end

function COperator:DoSell(oPlayer, iItem, iAmount)
    --出售物品
    local iRet, mReplace = self:CheckSell(oPlayer, iItem, iAmount)
    if iRet ~= 1 then
        self:Notify(oPlayer, iRet, mReplace)
        return
    end

    local oItem = oPlayer:HasItem(iItem)
    local iPrice, iTax,iTotal = 0, 0, 0

    local iGood = self.m_oTaskObj:TransToGoodId(oItem)
    local oProxyItem = self:GetDataByGoodId(iGood)
    if oProxyItem then
        if oItem:IsGuildItem() then
            iPrice = math.min(oItem:GetData("guild_buy_price"), oProxyItem:GetPrice())
            iTax = oProxyItem:GetTableAttr("tax")
        else
            iPrice = oProxyItem:GetPrice()
            iTax = 25
        end

        local mLogData = oPlayer:LogData()
        mLogData["sid"] = oItem:SID()
        mLogData["sell_amount"] = iAmount
        mLogData["sell_price"] = iPrice
        mLogData["price_old"] = oProxyItem:GetPrice()
    
        iTotal = math.floor(iPrice * (100 - iTax) / 100 * iAmount)
        oPlayer:RemoveOneItemAmount(oItem,iAmount,"sell")
        oPlayer:RewardGold(iTotal, "guild_sell")
        oProxyItem:AddAmount(iAmount)
        self:FloatPrice(oProxyItem, -iAmount)
        self:SendUnit(oPlayer, iGood)
        self:RecordWarning(oPlayer, 1, iTotal)

        mLogData["price_now"] = oProxyItem:GetPrice()
        mLogData["guild_amount"] = oProxyItem:GetAmount()
        record.log_db("economic", "guild_sell", mLogData)
    else
        local mInfo = self.m_oTaskObj:GetDataByGoodId(iGood)
        iPrice = mInfo.base_price
        iTax = mInfo.tax or 25
        iTotal = math.floor(iPrice * (100 - iTax) / 100 * iAmount)
        oPlayer:RemoveOneItemAmount(oItem,iAmount,"sell")
        oPlayer:RewardGold(iTotal, "guild_sell")
        self:RecordWarning(oPlayer, 1, iTotal)

        local mLogData = oPlayer:LogData()
        mLogData["sid"] = oItem:SID()
        mLogData["sell_amount"] = iAmount
        mLogData["sell_price"] = iPrice
        mLogData["price_old"] = iPrice
        mLogData["price_now"] = iPrice
        mLogData["guild_amount"] = mInfo.amount
        record.log_db("economic", "guild_sell", mLogData)
    end
end

function COperator:Notify(oPlayer, iChat, mReplace)
    local oNotifyMgr = global.oNotifyMgr
    local sMsg = self:FormatMsg(iChat, mReplace)
    oNotifyMgr:Notify(oPlayer:GetPid(), sMsg)
end

function COperator:DebugMsg(iPid, sMsg)
    if not is_production_env() then
        global.oNotifyMgr:Notify(iPid, sMsg)
    end
end

function COperator:FormatMsg(iChat, mReplace)
    local oToolMgr = global.oToolMgr
    local sMsg = oToolMgr:GetTextData(iChat, {"guild"})
    if mReplace then
        sMsg = oToolMgr:FormatColorString(sMsg, mReplace)
    end
    return sMsg
end

function COperator:RecordWarning(oPlayer, iSellCnt, iSellPrice)
    local mData = res["daobiao"]["guild"]["guild_config"][1]
    if iSellCnt and iSellCnt > 0 then
        oPlayer.m_oTodayMorning:Add("guild_sell_cnt", iSellCnt)
    end
    if iSellPrice and iSellPrice > 0 then
        oPlayer.m_oTodayMorning:Add("guild_sell_price", iSellPrice)
    end
    local iCnt = oPlayer.m_oTodayMorning:Query("guild_sell_cnt", 0)
    local iPrice = oPlayer.m_oTodayMorning:Add("guild_sell_price", 0)
    local iPid = oPlayer:GetPid()
    if iCnt > mData.guild_sell_cnt_limit or iPrice > mData.guild_sell_price_limit then
        record.warning("%s guild sell over limit sell_cnt:%d, sell_price:%d", iPid, iCnt, iPrice)
        self:DebugMsg(iPid, string.format("超出商会原定限制%d, %d(%d), %d(%d)",
            iPid, 
            iCnt,
            mData.guild_sell_cnt_limit,
            iPrice,
            mData.guild_sell_price_limit))
    end
end

