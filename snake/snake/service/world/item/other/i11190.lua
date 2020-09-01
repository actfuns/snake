local global = require "global"
local skynet = require "skynet"
local res = require "base.res"
local extend = require "base.extend"
local record = require "public.record"

local itembase = import(service_path("item.other.otherbase"))
local itemdefines = import(service_path("item/itemdefines"))
local gamedefines = import(lualib_path("public.gamedefines"))

function NewItem(sid)
    local o = CItem:New(sid)
    return o
end

CItem = {}
CItem.__index = CItem
inherit(CItem,itembase.CItem)

function CItem:TrueUse(oPlayer, iTarget, iCostAmount, mArgs)
    local oHuodong = global.oHuodongMgr:GetHuodong("fuyuanbox")
    if oHuodong then
    	oHuodong:FindPathToFuYuanBox(oPlayer)
    	return
    end
    return true
end

function CItem:CanUseOnKS()
    return false
end
