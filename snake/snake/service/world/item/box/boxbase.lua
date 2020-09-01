local global = require "global"
local skynet = require "skynet"

local itembase = import(service_path("item/itembase"))

CItem = {}
CItem.__index = CItem
inherit(CItem, itembase.CItem)
CItem.m_ItemType = "boxbase"

function NewItem(sid)
    local o = CItem:New(sid)
    return o
end

function CItem:TrueUse(oWho, iTarget, iCostAmount, mArgs)
    oWho:Send("GS2COpenBoxUI", {box_sid = self:SID()})
    return true
end
