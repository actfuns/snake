local global = require "global"
local skynet = require "skynet"

local itembase = import(service_path("item/other/warbase"))

function NewItem(sid)
    local o = CItem:New(sid)
    return o
end

CItem = {}
CItem.__index = CItem
CItem.m_iWarItemID = 1002
CItem.m_iLevel = 2
CItem.m_iCalType = 2
inherit(CItem,itembase.CItem)

function CItem:PackWarArgsInfo()
    local m = super(CItem).PackWarArgsInfo(self)
    m["mp"] = "level*4+20"
    return m
end