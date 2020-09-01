local global = require "global"
local skynet = require "skynet"

local itembase = import(service_path("item/other/warbase"))

function NewItem(sid)
    local o = CItem:New(sid)
    return o
end

CItem = {}
CItem.__index = CItem
CItem.m_iWarItemID = 1001
CItem.m_iLevel = 3
CItem.m_iCalType = 1
inherit(CItem,itembase.CItem)

function CItem:PackWarArgsInfo()
    -- 品质*8+300
    local m = super(CItem).PackWarArgsInfo(self)
    m["hp"] = self:Quality() * 10 + 300
    return m
end