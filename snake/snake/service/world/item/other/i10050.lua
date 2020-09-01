local global = require "global"
local skynet = require "skynet"

local itembase = import(service_path("item/other/warbase"))

function NewItem(sid)
    local o = CItem:New(sid)
    return o
end

CItem = {}
CItem.__index = CItem
CItem.m_iWarItemID = 1006
CItem.m_iCalType = 1
inherit(CItem,itembase.CItem)

function CItem:PackWarArgsInfo()
    local m = super(CItem).PackWarArgsInfo(self)
    m["sp"] = math.floor(self:Quality() * 0.8)
    m["quality"] = self:Quality()
    return m
end