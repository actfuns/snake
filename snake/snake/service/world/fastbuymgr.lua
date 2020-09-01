-- import module

local global = require "global"
local res = require "base.res"
local record = require "public.record"

local gamedefines = import(lualib_path("public.gamedefines"))
local stalldefines = import(service_path("stall.defines"))

function NewFastBuyMgr(...)
    local oMgr = CFastBuyMgr:New(...)
    return oMgr
end

CFastBuyMgr = {}
CFastBuyMgr.__index = CFastBuyMgr
inherit(CFastBuyMgr, logic_base_cls())

function CFastBuyMgr:New()
    local o = super(CFastBuyMgr).New(self)
    return o
end

-- 从 商城或商会 获得购买物品的价格，并进行元宝扣费
-- 不改变 商会物品的购买数目和涨跌
-- 不受购买限制， 背包空间限制 
-- 道具价格来源 iStoryType
-- 1 来源于 商会
-- 2 来源于 元宝商城
-- 3 采用 商会 和 元宝商城价格便宜者
-- 4 价格来源于摆摊，为银币

function CFastBuyMgr:ChangeGold2GoldCoin(iGold)
    local sFormula = res["daobiao"]["exchangemoney"][gamedefines.MONEY_TYPE.GOLD]["goldcoin"]
    local iGoldCoin = math.ceil(formula_string(sFormula, { value = iGold}))
    return iGoldCoin
end

function CFastBuyMgr:ChangeGoldCoin2Gold(iGoldCoin)
    local sFormula = res["daobiao"]["exchangemoney"][gamedefines.MONEY_TYPE.GOLDCOIN]["gold"]
    local iGold = formula_string(sFormula, {value = iGoldCoin})
    return iGold
end

-- 确保表中公式是向上取整的 math.ceil
function CFastBuyMgr:ChangeSilver2GoldCoin(iSilver)
    local sFormula = res["daobiao"]["exchangemoney"][gamedefines.MONEY_TYPE.SILVER]["goldcoin"]
    local iServerGrade = global.oWorldMgr:GetServerGrade()
    local iGoldCoin = math.ceil(formula_string(sFormula, {value = iSilver, SLV = iServerGrade}))
    return iGoldCoin
end

function CFastBuyMgr:ChangeGoldCoin2Silver(iGoldCoin)
    local sFormula = res["daobiao"]["exchangemoney"][gamedefines.MONEY_TYPE.GOLDCOIN]["silver"]
    local iServerGrade = global.oWorldMgr:GetServerGrade()
    local iSilver = math.ceil(formula_string(sFormula, {value = iGoldCoin, SLV = iServerGrade}))
    return iSilver
end

-- 快速购买物品，与客户端一样的取整方式，将兑换金币的元宝花费和兑换银币的元宝花费的浮点之和进行取整
function CFastBuyMgr:ChangeGoldandSilver2GoldCoin(iGold, iSilver)
    local iGoldCoin2Silver = 0
    local iGoldCoin2Gold = 0
    if iGold > 0 then
        local sFormula = res["daobiao"]["exchangemoney"][gamedefines.MONEY_TYPE.GOLD]["goldcoin"]
        iGoldCoin2Gold = formula_string(sFormula, {value = iGold})
    end
    if iSilver > 0 then
        local sFormula = res["daobiao"]["exchangemoney"][gamedefines.MONEY_TYPE.SILVER]["goldcoin"]
        local iServerGrade = global.oWorldMgr:GetServerGrade()
        iGoldCoin2Silver = formula_string(sFormula, {value = iSilver, SLV = iServerGrade})
    end
    return math.ceil(iGoldCoin2Silver + iGoldCoin2Gold)
end

-- 返回 0 则表示无该商品出售
function CFastBuyMgr:GetGuildPrice(iSid)
    local oGuild = global.oGuild
    local iGoldPrice = oGuild:GetItemPrice(iSid) or 0
    return iGoldPrice, gamedefines.MONEY_TYPE.GOLD
end

-- 返回 0 则表示无该商品出售
function CFastBuyMgr:GetStorePrice(iSid)
    local mShop = res["daobiao"]["npcstore"]["sid2id"][301]
    if not mShop then return 0 end

    local iGood = mShop[iSid]
    if not iGood then return 0 end

    local mData = res["daobiao"]["npcstore"]["data"][iGood]
    if not mData then return 0 end

    local mGoldCoin = mData["virtual_coin"] or {}
    local mCost = mGoldCoin[1003]
    local iGoldCoin = mCost["count"] or 0
    return iGoldCoin, gamedefines.MONEY_TYPE.GOLDCOIN
    -- return self:ChangeGoldCoin2Gold(iGoldCoin) , gamedefines.MONEY_TYPE.GOLD
end

-- 价格和品质使用行情价格 和 默认品质--1
function CFastBuyMgr:GetStallPrice(oPlayer, iSid)
    local iStallSid = stalldefines.EncodeSid(iSid)
    local oStall = global.oStallMgr:GetStallObj(oPlayer:GetPid())
    local iSilverPrice = oStall:GetDefaultPrice(iStallSid) or 0
    return iSilverPrice, gamedefines.MONEY_TYPE.SILVER
end

function CFastBuyMgr:C2GSFastBuyItemPrice(oPlayer, iSid, iStoreType)
    local iPrice, iMoneyType = self:GetItemPriceNew(oPlayer, iSid, iStoreType)
    local mNet = {
        sid = iSid,
        money_type = iMoneyType,
        price = iPrice
    }
    oPlayer:Send("GS2CFastBuyItemPrice", mNet)
end

function CFastBuyMgr:C2GSFastBuyItemListPrice(oPlayer, lSidList)
    local mNet = {}
    mNet["item_list"] = {}
    for _, mData in pairs(lSidList) do
        local iPrice, iMoneyType = self:GetItemPriceNew(oPlayer, mData.sid, mData.store_type)
        table.insert(mNet["item_list"], {sid = mData.sid, money_type = iMoneyType, price = iPrice})
    end
    oPlayer:Send("GS2CFastBuyItemListPrice", mNet)
end

--原来的价格是将元宝转换成金币,新的不进行转换,保持原有类型
function CFastBuyMgr:GetItemPriceNew(oPlayer, iSid, iStoreType)
    local iFindType = self:GetItemStoretypeInfo(iSid)
    if not iFindType and not iStoreType then
        record.warning("unknown the itemsid %d storetype", iSid)
        return 0, nil
    end
    iStoreType = iStoreType or iFindType

    local iPrice = 0
    local iMoneyType = nil
    if iStoreType == gamedefines.STORE_TYPE.GUILD then
        iPrice , iMoneyType = self:GetGuildPrice(iSid)
        if iPrice <= 0 then
            record.warning("cannot find the itemsid %d in guild",iSid)
            return 0, nil
        else
            return iPrice, iMoneyType
        end
    elseif iStoreType == gamedefines.STORE_TYPE.NPCSTORE then
        iPrice , iMoneyType = self:GetStorePrice(iSid)
        if iPrice <= 0 then
            record.warning("cannot find the itemsid %d in store 301",iSid)
            return 0, nil
        else
            return iPrice, iMoneyType
        end
    elseif iStoreType == gamedefines.STORE_TYPE.COMP then
        local iGuildPrice, iGuildMoneyType = self:GetGuildPrice(iSid)
        local iStorePrice, iStoreMoneyType= self:GetStorePrice(iSid)
        if iGuildPrice > 0 and iStorePrice > 0 then
            local iStoreGoldPrice = self:ChangeGoldCoin2Gold(iStorePrice)
            if iGuildPrice <= iStoreGoldPrice then
                iPrice = iGuildPrice
                iMoneyType = iGuildMoneyType
            else
                iPrice = iStorePrice
                iMoneyType = iStoreMoneyType
            end
        end
        if iPrice <= 0 then
            record.warning("cannot find the itemsid %d in store and guild", iSid)
            return 0, nil
        else
            return iPrice, iMoneyType
        end
    -- 摆摊货币类型为银币
    elseif iStoreType == gamedefines.STORE_TYPE.STALL then
        iPrice,iMoneyType = self:GetStallPrice(oPlayer, iSid) 
        if iPrice <= 0 then
            record.warning("cannot find the itemsid %d in stall", iSid)
            return 0, nil
        else
            return iPrice, iMoneyType
        end
    end
end

-- 根据物品iSid 和 iStoreType 获取物品的价格和类型，找不到物品 则返回 价格0，货币类型 nil
-- iStoreType 可根据使用的系统指定 iStoreType = nil 则通过默认的表查找
function CFastBuyMgr:GetItemPrice(oPlayer, iSid, iStoreType)
    local iPrice, iMoneyType = self:GetItemPriceNew(oPlayer, iSid, iStoryType)
    if iMoneyType == gamedefines.MONEY_TYPE.GOLDCOIN then
        iPrice = self:ChangeGoldCoin2Gold(iPrice)
        iMoneyType = gamedefines.MONEY_TYPE.GOLD
    end
    return iPrice, iMoneyType
end

function CFastBuyMgr:GetItemStoretypeInfo(iSid)
    return res["daobiao"]["fastbuy"][iSid]
end

-- {{[sid] = {amount = ,storetype = }})
-- 如果未指定storetype ,则 storetype 来自读表
-- 返回兑换道具需要的元宝数(金币兑换和银币兑换的浮点值之和进行取整)
function CFastBuyMgr:GetFastBuyCost(oPlayer, lItemList, sReason)
    local iTotalGold = 0
    local iTotalSilver = 0
    sReason = sReason or "快捷购买"
    local sForbidText = "不能" .. sReason
    for sid, mData in pairs(lItemList) do
        if mData.amount <= 0 then
            return false
        end
        local iPrice, iMoneyType = self:GetItemPrice(oPlayer, sid, mData.storetype)
        if iPrice <= 0 then
            record.warning("fastbuy cannot get the price itemsid %d storetype %d", sid, mData.storetype or 0)
            global.oToolMgr:DebugMsg(oPlayer:GetPid(), string.format("未配置道具%s快捷购买价格", sid))
            return false
        end
        if iMoneyType == gamedefines.MONEY_TYPE.GOLD then
            iTotalGold = iTotalGold + iPrice * mData.amount
        elseif iMoneyType == gamedefines.MONEY_TYPE.SILVER then
            iTotalSilver = iTotalSilver + iPrice * mData.amount
        elseif iMoneyType == gamedefines.MONEY_TYPE.GOLDCOIN then
            iTotalGold = iTotalGold + self:ChangeGoldCoin2Gold(iPrice) * mData.amount
        end
    end
    local iGoldCoin = self:ChangeGoldandSilver2GoldCoin(iTotalGold, iTotalSilver)
    return true, iGoldCoin
end

--旧的会将元宝转换成金币算,新的不会
function CFastBuyMgr:GetFastBuyCostNew(oPlayer, lItemList, sReason)
    local iTotalGold = 0
    local iTotalSilver = 0
    local iTotalGoldCoin = 0
    sReason = sReason or "快捷购买"
    local sForbidText = "不能" .. sReason
    for sid, mData in pairs(lItemList) do
        if mData.amount <= 0 then
            return false
        end
        local iPrice, iMoneyType = self:GetItemPriceNew(oPlayer, sid, mData.storetype)
        if iPrice <= 0 then
            record.warning("fastbuy cannot get the price itemsid %d storetype %d", sid, mData.storetype or 0)
            global.oToolMgr:DebugMsg(oPlayer:GetPid(), string.format("未配置道具%s快捷购买价格", sid))
            return false
        end
        if iMoneyType == gamedefines.MONEY_TYPE.GOLD then
            iTotalGold = iTotalGold + iPrice * mData.amount
        elseif iMoneyType == gamedefines.MONEY_TYPE.SILVER then
            iTotalSilver = iTotalSilver + iPrice * mData.amount
        elseif iMoneyType == gamedefines.MONEY_TYPE.GOLDCOIN then
            iTotalGoldCoin = iTotalGoldCoin + iPrice * mData.amount
        end
    end

    local mData = {
        goldcoin = iTotalGoldCoin,
        gold = iTotalGold,
        silver = iTotalSilver,
    }
    return true, mData
end

-- mCost 包含银币, 金币，道具的花费
function CFastBuyMgr:FastBuy(oPlayer, mCost, sReason, mArgs)
    local iSilver = mCost["silver"] or 0
    local iGold = mCost["gold"] or 0
    local iGoldCoin = mCost["goldcoin"] or 0
    local mCostItem = mCost["item"] or {}
    local mTrueUseItem = {}
    local mLackItem = {}
    local iGoldCoinToSilver = 0
    local iGoldCoinToGold = 0
    local iGoldCoinToItem = 0
    local mLogCost = {}
    for iSid, iAmount in pairs(mCostItem) do
        local iHasAmount = oPlayer:GetItemAmount(iSid)
        if iHasAmount < iAmount then
            mLackItem[iSid] = {amount = iAmount - iHasAmount}
            if iHasAmount > 0 then
                mTrueUseItem[iSid] = iHasAmount
            end
        else
            mTrueUseItem[iSid] = iAmount
        end
    end
    if next(mLackItem) then
        local bExist, mData = self:GetFastBuyCostNew(oPlayer, mLackItem, sReason)
        if not bExist then return end
        iGoldCoinToItem = mData.goldcoin
        iGold = iGold + mData.gold
        iSilver = iSilver + mData.silver
    end

    if iSilver > 0 and not oPlayer:ValidSilver(iSilver, {cancel_tip = true}) then
        iGoldCoinToSilver = self:ChangeSilver2GoldCoin(iSilver - oPlayer:GetSilver())
    end
    
    if iGold > 0 and not oPlayer:ValidGold(iGold, {cancel_tip = true}) then
        iGoldCoinToGold = self:ChangeGold2GoldCoin(iGold - oPlayer:GetGold())
    end

    local iGoldCoinToOther = iGoldCoinToSilver + iGoldCoinToGold + iGoldCoinToItem + iGoldCoin
    if iGoldCoinToOther > 0 then
        if not oPlayer:ValidGoldCoin(iGoldCoinToOther) then return end
    end

    if iGoldCoinToSilver > 0 then
        oPlayer:ExchangeMoneyByGoldCoin(gamedefines.MONEY_TYPE.SILVER, iGoldCoinToSilver, sReason, {cancel_tip = true})
    end
    if iSilver > 0 then
        oPlayer:ResumeSilver(iSilver, sReason, mArgs)
        mLogCost["silver"] = iSilver
    end

    if iGoldCoinToGold > 0 then
        oPlayer:ExchangeMoneyByGoldCoin(gamedefines.MONEY_TYPE.GOLD, iGoldCoinToGold, sReason, {cancel_tip = true})
    end
    if iGold > 0 then
        oPlayer:ResumeGold(iGold, sReason, mArgs)
        mLogCost["gold"] = iGold
    end

    if (iGoldCoinToItem + iGoldCoin) > 0 then
        oPlayer:ResumeGoldCoin(iGoldCoinToItem + iGoldCoin, sReason, mArgs)
        mLogCost["goldcoin"] = iGoldCoinToItem + iGoldCoin
    end

    mLogCost["item"] = {}
    for iSid, iAmount in pairs(mTrueUseItem) do
        oPlayer:RemoveItemAmount(iSid, iAmount, sReason, mArgs)
        mLogCost["item"][iSid] = iAmount
    end
    return true, mLogCost
end
