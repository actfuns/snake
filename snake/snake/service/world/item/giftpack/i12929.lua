local global = require "global"
local skynet = require "skynet"
local interactive =  require "base.interactive"

local itembase = import(service_path("item/giftpack/giftpackbase"))

CItem = {}
CItem.__index = CItem
inherit(CItem, itembase.CItem)

function NewItem(sid)
    local o = CItem:New(sid)
    return o
end

function CItem:TrueUse(oPlayer, iTarget, iCostAmount, mArgs)
    local oNotifyMgr = global.oNotifyMgr
    local sMsg = global.oToolMgr:GetTextData(1052, {"itemtext"})
    oNotifyMgr:Notify(oPlayer:GetPid(), sMsg)
    return true
end
