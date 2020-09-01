-- import module

local global = require "global"
local res = require "base.res"
local record = require "public.record"

local gamedefines = import(lualib_path("public.gamedefines"))
local stalldefines = import(service_path("stall.defines"))
local fastbuymgr = import(service_path("fastbuymgr"))

function NewFastBuyMgr(...)
    local oMgr = CFastBuyMgr:New(...)
    return oMgr
end

CFastBuyMgr = {}
CFastBuyMgr.__index = CFastBuyMgr
inherit(CFastBuyMgr, fastbuymgr.CFastBuyMgr)

function CFastBuyMgr:ChangeSilver2GoldCoin(iSilver)
    assert(false, string.format("ks cant use this function"))
end

function CFastBuyMgr:ChangeGoldCoin2Silver(iGoldCoin)
    assert(false, string.format("ks cant use this function"))
end

-- 快速购买物品，与客户端一样的取整方式，将兑换金币的元宝花费和兑换银币的元宝花费的浮点之和进行取整
function CFastBuyMgr:ChangeGoldandSilver2GoldCoin(iGold, iSilver)
    assert(false, string.format("ks cant use this function"))
end

-- 返回 0 则表示无该商品出售
function CFastBuyMgr:GetGuildPrice(iSid)
    assert(false, string.format("ks cant use this function"))
end

-- 价格和品质使用行情价格 和 默认品质--1
function CFastBuyMgr:GetStallPrice(oPlayer, iSid)
    assert(false, string.format("ks cant use this function"))
end

function CFastBuyMgr:C2GSFastBuyItemPrice(oPlayer, iSid, iStoreType)
    local mNet = {
        sid = iSid,
        money_type = 0,
        price = 0
    }
    oPlayer:Send("GS2CFastBuyItemPrice", mNet)
end

function CFastBuyMgr:C2GSFastBuyItemListPrice(oPlayer, lSidList)
    local mNet = {}
    mNet["item_list"] = {}
    for _, mData in pairs(lSidList) do
        table.insert(mNet["item_list"], {sid = mData.sid, money_type = 0, price = 0})
    end
    oPlayer:Send("GS2CFastBuyItemListPrice", mNet)
end

-- mCost 包含银币, 金币，道具的花费
function CFastBuyMgr:FastBuy(oPlayer, mCost, sReason, mArgs)
end
