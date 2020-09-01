local global = require "global"
local skynet = require "skynet"

local itembase = import(service_path("item/itembase"))

CItem = {}
CItem.__index = CItem
inherit(CItem,itembase.CItem)
CItem.m_ItemType = "virtual"

function CItem:RealObj()
    -- body
end

function CItem:Reward()
    -- body
end

function CItem:GetMaxAmount()
    return 1
end

function CItem:ValidReward(oPlayer, mArgs)
    return true
end

-- function CItem:PackItemInfo()
--     local mNet = super(CItem).PackItemInfo(self)
--     local iValue = self:GetData("Value")
--     if iValue then
--         mNet.amount = iValue
--     end
--     return mNet
-- end

function NewItem(sid)
    local o = CItem:New(sid)
    return o
end
