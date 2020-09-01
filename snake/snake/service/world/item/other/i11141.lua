local global = require "global"
local skynet = require "skynet"

local itembase = import(service_path("item/other/otherbase"))

function NewItem(sid)
    local o = CItem:New(sid)
    return o
end

CItem = {}
CItem.__index = CItem
inherit(CItem, itembase.CItem)

function CItem:TrueUse(oPlayer, iTarget, iCostAmount, mArgs)
    local oHuodong = global.oHuodongMgr:GetHuodong("orgcampfire")
    oHuodong.m_oTieMgr:CallUseTieItem(oPlayer, self, 1)
    return true
end

function CItem:CanUseOnKS()
    return false
end
