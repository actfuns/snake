--import module

local global = require "global"
local skynet = require "skynet"
local res = require "base.res"
local record = require "public.record"

local datactrl = import(lualib_path("public.datactrl"))
local gamedefines = import(lualib_path("public.gamedefines"))
local analy = import(lualib_path("public.dataanaly"))

local WEEK_MAINTAIN_SHOP = {301, 302, 303}

CStoreCtrl = {}
CStoreCtrl.__index = CStoreCtrl
inherit(CStoreCtrl, datactrl.CDataCtrl)

function CStoreCtrl:New(iPid)
    local o = super(CStoreCtrl).New(self,{pid=iPid})
    o:Init()
    return o
end

function CStoreCtrl:Init()
    self.m_mBuyItem = {}
    self.m_iDiscountEnd = 0
end

function CStoreCtrl:Release()
    self.m_mBuyItem = {}
    super(CStoreCtrl).Release(self)
end

function CStoreCtrl:Load(mData)
    if not mData then return end

    for sShop, mBuy in pairs(mData.buy_item or {}) do
        local iShop = tonumber(sShop)
        self.m_mBuyItem[iShop] = {}
        for sItem, iCnt in pairs(mBuy) do
            self.m_mBuyItem[iShop][tonumber(sItem)] = iCnt
        end
    end
    self.m_iDiscountEnd = mData.discount_end or 0
end

function CStoreCtrl:Save()
    local mBuyItem = {}
    for iShop, mBuy in pairs(self.m_mBuyItem) do
        local mTemp = {}
        for iItem, iCnt in pairs(mBuy) do
            mTemp[db_key(iItem)] = iCnt
        end
        mBuyItem[db_key(iShop)] = mTemp
    end

    local mData = {
        buy_item = mBuyItem,
        discount_end = self.m_iDiscountEnd
    }
    return mData
end

function CStoreCtrl:GetPid()
    return self:GetInfo("pid")
end

function CStoreCtrl:OnLogin(oPlayer)
    self:RefreshWeekMaintain()
    self:GS2CLoginStoreInfo(oPlayer)

    if self:IsSelfDiscountOpen() then
        self:AddDiscountCb()
        self:GS2CDiscountTime()
    end
end

function CStoreCtrl:NewHour5()
    self:RefreshWeekMaintain(true)    
end

function CStoreCtrl:RefreshWeekMaintain(bClient)
    local oPlayer = global.oWorldMgr:GetOnlinePlayerByPid(self:GetPid())
    if not oPlayer then return end

    if oPlayer.m_oWeekMorning:Query("shop_refresh", 0) >= 1 then
        return
    end

    oPlayer.m_oWeekMorning:Set("shop_refresh", 1)
    for _, iShop in pairs(WEEK_MAINTAIN_SHOP) do
        self:RefreshStore(iShop)      
    end

    if bClient then
        self:GS2CLoginStoreInfo(oPlayer)    
    end
end

-- 如何清除过去的冗余数据？
function CStoreCtrl:RefreshStore(iShop)
    self.m_mBuyItem[iShop] = nil
    self:Dirty()
end

function CStoreCtrl:GS2CLoginStoreInfo(oPlayer)
    if not oPlayer then return end
    local mNet = {}
    mNet.item_info = self:PackAllLimitGood()
    oPlayer:Send("GS2CLoginStoreInfo", mNet)
end

function StoreLimitTimeDiscountCb(iPid)
    local oPlayer = global.oWorldMgr:GetOnlinePlayerByPid(iPid)
    if oPlayer then
        local oStoryCtrl = oPlayer.m_oStoreCtrl
        oStoryCtrl:Dirty()
        oStoryCtrl.m_iDiscountEnd = 0
        oStoryCtrl:GS2CDiscountTime()
    end
end

function CStoreCtrl:AddDiscountCb()
    local iSub = self.m_iDiscountEnd - get_time()
    local iPid = self:GetPid()
    if iSub > 0 then
        self:DelTimeCb("StoreLimitTimeDiscount")
        self:AddTimeCb("StoreLimitTimeDiscount", iSub * 1000, function()
            StoreLimitTimeDiscountCb(iPid)
        end)
    end
end

function CStoreCtrl:AddDiscountTime(iHour)
    self:Dirty()

    if self.m_iDiscountEnd < get_time() then
        self.m_iDiscountEnd = 0
    end

    if self.m_iDiscountEnd == 0 then
        self.m_iDiscountEnd = get_time() + iHour*3600
    else
        self.m_iDiscountEnd = self.m_iDiscountEnd + iHour*3600
    end
    self:AddDiscountCb()
    self:GS2CDiscountTime(true)
end

function CStoreCtrl:IsSelfDiscountOpen()
    return self.m_iDiscountEnd >= get_time()
end

function CStoreCtrl:GS2CDiscountTime(bShowTip)
    local oPlayer = global.oWorldMgr:GetOnlinePlayerByPid(self:GetPid())
    if not oPlayer then return end

    local mNet = {
        discount_end = self.m_iDiscountEnd,
        show_tip = bShowTip and 1 or 0,
    }
    oPlayer:Send("GS2CLimitTimeDiscountInfo", mNet)
end

function CStoreCtrl:GetShopItem(iBuy)
    return res["daobiao"]["npcstore"]["data"][iBuy]
end

function CStoreCtrl:GetDayLimitFlag(iShop, iBuy)
    return string.format("storeday_%s_%s", iShop, iBuy)
end

function CStoreCtrl:GetWeekLimitFlag(iShop, iBuy)
    return string.format("storeweek_%s_%s",iShop, iBuy)
end

function CStoreCtrl:GetForeverLimitFlag(iShop, iBuy)
    return string.format("storeforever_%s_%s",iShop, iBuy)
end

function CStoreCtrl:GetDayBuyCnt(oPlayer, iShop, iBuy)
    local sKey = self:GetDayLimitFlag(iShop, iBuy)
    return oPlayer.m_oTodayMorning:Query(sKey, 0)
end

function CStoreCtrl:GetWeekBuyCnt(oPlayer, iShop, iBuy)
    local sKey = self:GetWeekLimitFlag(iShop, iBuy)
    return oPlayer.m_oWeekMorning:Query(sKey, 0)
end

function CStoreCtrl:GetForeverBuyCnt(oPlayer, iShop, iBuy)
    local sKey = self:GetForeverLimitFlag(iShop, iBuy)
    return oPlayer:Query(sKey, 0)
end

function CStoreCtrl:AddDayBuyCnt(oPlayer, iShop, iBuy, iBuyCount)
    local sKey = self:GetDayLimitFlag(iShop, iBuy)
    oPlayer.m_oTodayMorning:Add(sKey, iBuyCount)
end

function CStoreCtrl:AddWeekBuyCnt(oPlayer, iShop, iBuy, iBuyCount)
    local sKey = self:GetWeekLimitFlag(iShop, iBuy)
    oPlayer.m_oWeekMorning:Add(sKey, iBuyCount)
end

function CStoreCtrl:AddForeverBuyCnt(oPlayer, iShop, iBuy, iBuyCount)
    local sKey = self:GetForeverLimitFlag(iShop, iBuy)
    local iCurCnt = oPlayer:Query(sKey, 0)
    oPlayer:Set(sKey, iCurCnt + iBuyCount)
end

function CStoreCtrl:PackAllLimitGood()
    local mShopData = res["daobiao"]["npcstore"]["data"]
    local oPlayer = global.oWorldMgr:GetOnlinePlayerByPid(self:GetPid())
    local mNet = {}
    for iBuy, mShopItem in pairs(mShopData) do
        if mShopItem["day_limit"] + mShopItem['week_limit'] + mShopItem["forever_limit"] > 0 then
            local mItem = self:PackLimitGood(oPlayer, iBuy)
            table.insert(mNet, mItem)
        end
    end
    return mNet
end

function CStoreCtrl:PackLimitGood(oPlayer,iBuy)
    local mShopItem = self:GetShopItem(iBuy)
    local mNet = {}
    mNet.limit = mShopItem["day_limit"] + mShopItem["week_limit"] + mShopItem["forever_limit"]
    if mNet.limit <= 0 then return end
    local iShop = mShopItem["shop_id"]
    mNet.item_id = iBuy
    mNet.day_buy_cnt = math.max(0, self:GetDayBuyCnt(oPlayer, iShop, iBuy))
    mNet.week_buy_cnt = math.max(0, self:GetWeekBuyCnt(oPlayer, iShop, iBuy))
    mNet.forever_buy_cnt = math.max(0, self:GetForeverBuyCnt(oPlayer, iShop, iBuy))
    return mNet
end

function CStoreCtrl:ValidBuy(oPlayer, iBuy, iBuyCount)
    local mShopItem = self:GetShopItem(iBuy)
    if (iBuyCount <= 0) or (not mShopItem) then 
        return false 
    end
    local iTotalCnt = mShopItem.item_count * iBuyCount
    local lGive = {
        [mShopItem.item_id] = iTotalCnt
    }
    local oNotifyMgr = global.oNotifyMgr
    local pid = oPlayer:GetPid()
    if not oPlayer:ValidGive(lGive) then
        oNotifyMgr:Notify(pid, "背包空间不足，请先整理背包")
        return false
    end

    if oPlayer:GetGrade() < mShopItem["limit_level"] then
        oNotifyMgr:Notify(pid, "玩家等级不足")
        return  false
    end

    -- 判断限购物品
    local iShop = mShopItem["shop_id"]
    if mShopItem["day_limit"] > 0 then
        local iDayBuy = self:GetDayBuyCnt(oPlayer, iShop, iBuy)
        if mShopItem["day_limit"] < iDayBuy + iBuyCount then
            oNotifyMgr:Notify(pid, "物品天售出数量不足")
            return false
        end
    end
    
    if mShopItem["week_limit"] > 0 then
        local iWeekBuy = self:GetWeekBuyCnt(oPlayer, iShop, iBuy)
        if mShopItem["week_limit"] < iWeekBuy + iBuyCount then
            oNotifyMgr:Notify(pid, "物品周售出数量不足")
            return false
        end
    end

    if mShopItem["forever_limit"] > 0 then
        local iForeverBuy = self:GetForeverBuyCnt(oPlayer, iShop, iBuy)
        if mShopItem["forever_limit"] < iForeverBuy + iBuyCount then
            oNotifyMgr:Notify(pid, "物品永久售出数量不足")
            return false
        end
    end

    local fDiscount = 1
    local bDiscount = self:IsSelfDiscountOpen()
    if mShopItem.shop_id == 301 and bDiscount then
        local fConfigDiscount = mShopItem.limittime_discount
        if mData.all_money > 0 and fConfigDiscount and fConfigDiscount > 0 then
            fDiscount = fConfigDiscount / 10
        end
    end
        
    local bSucc = true
    for iCostSID, mCostData in pairs(mShopItem["virtual_coin"]) do
        local iCostVal = mCostData.count
        local iAllCost = iBuyCount * math.floor(iCostVal * fDiscount)
        if bDiscount and mData.all_money > 0 and iAllCost ~= mData.all_money then
            oNotifyMgr:Notify(oPlayer:GetPid(), "商品价格变化，请重新购买")
            return
        end

        if iCostSID == gamedefines.MONEY_VIRTUAL_ITEM.GOLD and not oPlayer:ValidGold(iAllCost, {tip = "金币不足，购买失败！"}) then
            bSucc = false
            break
        elseif iCostSID == gamedefines.MONEY_VIRTUAL_ITEM.SILVER and not oPlayer:ValidSilver(iAllCost, {tip = "银币不足，购买失败！"}) then
            bSucc = false
            break
        -- 1003 没有专门的非绑定元宝 所以根据商店自己判断
        elseif iCostSID == gamedefines.MONEY_VIRTUAL_ITEM.GOLDCOIN then
            local lTrueGoldShop = res["daobiao"]["storemoneytype"][1]["truegoldcoin"]
            if table_in_list(lTrueGoldShop, iShop) then
                if not oPlayer:ValidTrueGoldCoin(iAllCost, {tip = "非绑定元宝不足，购买失败！"}) then
                    bSucc = false
                    break
                end
            elseif not oPlayer:ValidGoldCoin(iAllCost, {tip = "元宝不足，购买失败！"}) then
                bSucc = false
                break
            end
        elseif iCostSID == gamedefines.MONEY_VIRTUAL_ITEM.RPLGOLD and  not oPlayer:ValidRplGoldCoin(iAllCost, {tip = "绑定元宝不足，购买失败！"}) then
            bSucc = false 
        end
    end
    return bSucc
end

function CStoreCtrl:DoBuy(oPlayer, iBuy, iBuyCount)
    if not self:ValidBuy(oPlayer, iBuy, iBuyCount) then return end
    local oNotifyMgr = global.oNotifyMgr
    local sReason = "npc商城购买"
    local mShopItem = self:GetShopItem(iBuy)
    local iShop = mShopItem["shop_id"]
    local iTotalCnt = mShopItem.item_count * iBuyCount
    local lGiveItem = {
        [mShopItem.item_attr] = iTotalCnt
    }

    local fDiscount = 1
    local bDiscount = self:IsSelfDiscountOpen()
    if mShopItem.shop_id == 301 and bDiscount then
        local fConfigDiscount = mShopItem.limittime_discount
        if mData.all_money > 0 and fConfigDiscount and fConfigDiscount > 0 then
            fDiscount = fConfigDiscount / 10
        end
    end

    local iPrice, iCurrency, iRemain, iOldGoldCoin = 0, 0, 0, oPlayer:GetGoldCoin()
    for iCostSID, mCostData in pairs(mShopItem["virtual_coin"]) do
        local iCostVal = mCostData.count
        local iAllCost = iBuyCount * math.floor(iCostVal * fDiscount)
        if iCostSID == gamedefines.MONEY_VIRTUAL_ITEM.GOLD then
            oPlayer:ResumeGold(iAllCost, sReason)
            iPrice = math.floor(iCostVal * fDiscount)
            iCurrency = gamedefines.MONEY_TYPE.GOLD
            iRemain = oPlayer:GetGold()
        elseif iCostSID == gamedefines.MONEY_VIRTUAL_ITEM.SILVER then
            oPlayer:ResumeSilver(iAllCost, sReason)
            iPrice = math.floor(iCostVal * fDiscount) 
            iCurrency = gamedefines.MONEY_TYPE.SILVER
            iRemain = oPlayer:GetSilver()
        elseif iCostSID == gamedefines.MONEY_VIRTUAL_ITEM.GOLDCOIN then
            local lTrueGoldShop = res["daobiao"]["storemoneytype"][1]["truegoldcoin"]
            if table_in_list(lTrueGoldShop, iShop) then
                oPlayer:ResumeTrueGoldCoin(iAllCost, sReason)
                iPrice = math.floor(iCostVal * fDiscount)
                iCurrency = gamedefines.MONEY_TYPE.TRUE_GOLDCOIN 
                iRemain = oPlayer:GetTrueGoldCoin()
            else
                oPlayer:ResumeGoldCoin(iAllCost, sReason)
                iPrice = math.floor(iCostVal * fDiscount)
                iCurrency = gamedefines.MONEY_TYPE.GOLDCOIN
                iRemain = oPlayer:GetGoldCoin()
            end
        elseif iCostSID == gamedefines.MONEY_VIRTUAL_ITEM.RPLGOLD then
            oPlayer:ResumeRplGoldCoin(iAllCost, sReason)
            iPrice = math.floor(iCostVal * fDiscount)
            iCurrency = gamedefines.MONEY_TYPE.RPLGOLD
            iRemain = oPlayer:GetRplGoldCoin(iAllCost, sReason)
        end
    end

    if mShopItem["day_limit"] > 0 then
        self:AddDayBuyCnt(oPlayer, iShop, iBuy, iBuyCount)
    end

    if mShopItem["week_limit"] > 0 then
        self:AddWeekBuyCnt(oPlayer, iShop, iBuy, iBuyCount)
    end
    
    if mShopItem["forever_limit"] > 0 then
        self:AddForeverBuyCnt(oPlayer, iShop, iBuy, iBuyCount)
    end

    local mArgs = {cancel_tip = true}
    if mShopItem["bind"] and mShopItem["bind"] > 0 then
        mArgs.bind = 1
    end
    oPlayer:GiveItem(lGiveItem, sReason,mArgs)
    oNotifyMgr:ItemNotify(oPlayer:GetPid(), {sid=mShopItem.item_id, amount=iTotalCnt, type=1})
    local mUpdateLimitGood = self:PackLimitGood(oPlayer, iBuy)
    if mUpdateLimitGood then
        local mNet = {}
        mNet.item_info = {mUpdateLimitGood}
        oPlayer:Send("GS2CUpdateStoreInfo", mNet)
    end

    local mLogData = oPlayer:LogData()
    mLogData["cost"] = mShopItem["virtual_coin"]
    mLogData["buy"] = lGiveItem
    record.log_db("economic", "store_buy", mLogData)

    -- 数据中心
    local iTotal = iBuyCount * math.floor(iPrice * fDiscount)
    local mAnalyLog = oPlayer:BaseAnalyInfo()
    mAnalyLog["yuanbao_before"] = iOldGoldCoin
    mAnalyLog["consume_yuanbao"] = 0
    if iCurrency == gamedefines.MONEY_TYPE.GOLDCOIN then
        mAnalyLog["consume_yuanbao"] = iTotal
    end
    mAnalyLog["yuanbao_bd_before"] = 0
    mAnalyLog["consume_yuanbao_bd"] = 0
    mAnalyLog["shop_id"] = iShop
    mAnalyLog["shop_sub_id"] = 1
    mAnalyLog["currency_type"] = iCurrency
    mAnalyLog["item_id"] = mShopItem["item_id"]
    mAnalyLog["price"] = iPrice
    mAnalyLog["num"] = iBuyCount
    mAnalyLog["consume_count"] = iTotal
    mAnalyLog["remain_currency"] = iRemain
    analy.log_data("MallBuy", mAnalyLog)
end

function CStoreCtrl:TestOp(iFlag, mArgs)
    if iFlag == 100 then
        local sMsg = [[
100 - npcstoreop 100 (helper)
101 - 清空商品的永久性限购 101 { 商品编号}
1001 - 执行一次刷周将无用数据删除
        ]]
        global.oChatMgr:HandleMsgChat(oMaster, sMsg)
    elseif iFlag == 101 then
        local iBuyId = mArgs[1]
        local mShopItem = res["daobiao"]["npcstore"]["data"][iBuyId]
        if mShopItem["forever_limit"] <= 0 then return end
        local sKey = self:GetForeverLimitFlag(mShopItem["shop_id"], iBuyId)
        local oPlayer = global.oWorldMgr:GetOnlinePlayerByPid(self:GetPid())
        oPlayer:Set(sKey, nil)
        if self.m_mBuyItem[mShopItem["shop_id"]] then
            self.m_mBuyItem[mShopItem["shop_id"]] = nil
        end
        local iForeverBuy = oPlayer:Query(sKey, 0)
        local mNet = {}
        mNet.item_info = {{item_id = iBuyId, buy_cnt = 0}}
        mNet.forever_item_info = {{item_id = iBuyId, forever_buy_cnt = iForeverBuy}}
        oPlayer:Send("GS2CUpdateStoreInfo", mNet)
    end
end
