local global = require "global"
local skynet = require "skynet"

local itembase = import(service_path("item/equip/i22901"))

function NewItem(sid)
    local o = CItem:New(sid)
    return o
end

CItem = {}
CItem.__index = CItem
inherit(CItem,itembase.CItem)
CItem.m_EngageType = 2

function CItem:New(sid)
    local o = super(CItem).New(self,sid)
    return o
end
