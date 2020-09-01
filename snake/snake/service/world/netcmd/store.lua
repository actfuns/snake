local global = require "global"
local skynet = require "skynet"
local record = require "public.record"

local gamedefines = import(lualib_path("public.gamedefines"))
local analy = import(lualib_path("public.dataanaly"))


function C2GSExchangeGold(oPlayer, mData)
    local iStoreItemID = mData["store_itemid"]
    local res = require "base.res"
    local mStoreItem = res["daobiao"]["goldstore"][iStoreItemID]
    if mStoreItem then
        local iCoinCost = mStoreItem.gold_coin_cost
        local iGainCount = mStoreItem.gold_gains
        if oPlayer:ValidGoldCoin(iCoinCost, "元宝不足") then
            oPlayer:ResumeGoldCoin(iCoinCost, "金币商城兑换")
            oPlayer:RewardGold(iGainCount, "金币商城兑换")

            local mLogData = oPlayer:LogData()
            mLogData["goldcoin"] = iCoinCost
            mLogData["gold"] = iGainCount
            record.log_db("economic", "exchange_gold", mLogData)
        end
    else
        local oNotifyMgr = global.oNotifyMgr
        oNotifyMgr:Notify(oPlayer:GetPid(), "购买物品不存在")
    end
end

function C2GSExchangeSilver(oPlayer, mData)
    local iStoreItemID = mData["store_itemid"]
    local res = require "base.res"
    local mStoreItem = res["daobiao"]["silverstore"][iStoreItemID]
    if mStoreItem then
        local iCoinCost = mStoreItem.gold_coin_cost
        if oPlayer:ValidGoldCoin(iCoinCost, "元宝不足") then
            local iExtraGain = mStoreItem.reward_silver
            local sFormula = mStoreItem.sliver_gains_formula
            local oWorldMgr = global.oWorldMgr
            local iServerGrade = oPlayer:GetServerGrade()
            local iGainCount = formula_string(sFormula, {SLV = iServerGrade})
            oPlayer:ResumeGoldCoin(iCoinCost, "银币商城兑换")
            oPlayer:RewardSilver(iGainCount + iExtraGain, "银币商城兑换")

            local mLogData = oPlayer:LogData()
            mLogData["goldcoin"] = iCoinCost
            mLogData["silver"] = iGainCount + iExtraGain
            record.log_db("economic", "exchange_silver", mLogData)
        end
    else
        local oNotifyMgr = global.oNotifyMgr
        oNotifyMgr:Notify(oPlayer:GetPid(), "购买物品不存在")
    end
end

function C2GSNpcStoreBuy(oPlayer, mData)
    local iBuyId = mData["buy_id"]
    local iBuyCount = mData["buy_count"]
    oPlayer.m_oStoreCtrl:DoBuy(oPlayer, iBuyId, iBuyCount)
end

function C2GSFastBuyItem(oPlayer, mData)
    local iItem = mData.item_id
    local iCnt = mData.cnt
    if iCnt <= 0 then return end

    local mConfig = global.oItemLoader:GetItemData(iItem)
    if not mConfig then return end

    local iPrice = mConfig.buyPrice
    if not iPrice or iPrice <= 0 then
        oPlayer:NotifyMessage("不可快速购买")
        return
    end
    
    if not oPlayer:ValidGoldCoin(iPrice * iCnt, {tip = "元宝不足，购买失败！"}) then return end

    oPlayer:ResumeGoldCoin(iPrice * iCnt, "快速购买")
    local oItem = global.oItemLoader:Create(iItem)
    oItem:SetAmount(iCnt)
    if iItem == 10010 then
        local iVal = oItem:CalEnergy(oPlayer) * iCnt
        oPlayer:AddEnergy(iVal, "快速购买")
    else
        oPlayer:RewardItem(oItem, "快速购买")
    end
    oPlayer:NotifyMessage("购买成功!")
end

function C2GSExChangeDanceBook(oPlayer, mData)
    local oSkillCtrl = oPlayer.m_oSkillCtrl
    if oSkillCtrl then
        oSkillCtrl:C2GSExChangeDanceBook(oPlayer)
    end
end


