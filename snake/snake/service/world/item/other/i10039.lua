local global = require "global"
local skynet = require "skynet"

local itembase = import(service_path("item/other/warbase"))

function NewItem(sid)
    local o = CItem:New(sid)
    return o
end

CItem = {}
CItem.__index = CItem
CItem.m_iWarItemID = 1003
inherit(CItem,itembase.CItem)

-- 可否使用扣减
function CItem:CanSubOnWarUse()
    return false
end

function CItem:HasWarLock()
    return true
end

function CItem:PackWarArgsInfo()
    local mArgs = super(CItem).PackWarArgsInfo(self)
    mArgs.hp_rates = {50} -- 递减
    mArgs.succ_rates = {50, 100}
    return mArgs
end
