local global = require "global"
local skynet = require "skynet"
local res = require "base.res"
local itembase = import(service_path("item/itembase"))


function NewItem(sid)
    local o = CItem:New(sid)
    return o
end

CItem = {}
CItem.__index = CItem
CItem.m_ItemType = "equip"
inherit(CItem,itembase.CItem)


