local global = require "global"
local skynet = require "skynet"
local interactive =  require "base.interactive"

local itembase = import(service_path("item/other/otherbase"))

CItem = {}
CItem.__index = CItem
inherit(CItem,itembase.CItem)
CItem.m_ItemType = "pellet"

function NewItem(sid)
    local o = CItem:New(sid)
    return o
end

function CItem:TrueUse(who,target)
    local oNotifyMgr = global.oNotifyMgr
    local sMsg = global.oToolMgr:GetTextData(1042, {"itemtext"})
    oNotifyMgr:Notify(who:GetPid(), sMsg)
    return true
end

function CItem:ItemColor()
    return self:GetItemData()["quality"] or 0
end
