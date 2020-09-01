local global = require "global"
local skynet = require "skynet"
local interactive =  require "base.interactive"

local itembase = import(service_path("item/itembase"))

function NewItem(sid)
    local o = CItem:New(sid)
    return o
end

CItem = {}
CItem.__index = CItem
inherit(CItem,itembase.CItem)
CItem.m_ItemType = "shenhun"

function CItem:Level()
    return self:GetItemData()["level"]
end

function CItem:PartPos()
    return self:GetItemData()["pos"]
end
