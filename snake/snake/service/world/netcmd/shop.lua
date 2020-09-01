local global = require "global"
local skynet = require "skynet"
local record = require "public.record"

local gamedefines = import(lualib_path("public.gamedefines"))

function C2GSBuyGood(oPlayer,mData)
    local iShop = mData.shop 
    local iGood = mData.goodid
    local iAmount = mData.amount
    local iMoneyType = mData.moneytype
    global.oShopMgr:BuyGood(oPlayer,iShop,iGood,iAmount,iMoneyType)
end

function C2GSEnterShop(oPlayer,mData)
    local iShop = mData.shop 
    global.oShopMgr:OpenShop(oPlayer,iShop)
    -- 给商店对应积分的获取信息
    global.oShopMgr:DailyRewardMoneyInfo(oPlayer,iShop)
end
