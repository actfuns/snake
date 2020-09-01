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
CItem.m_iLevel = 3
CItem.m_iCalType = 1
inherit(CItem,itembase.CItem)

function CItem:PackWarArgsInfo()
    -- 回蓝 品质*等级*0.15+等级*5+30
    local m = super(CItem).PackWarArgsInfo(self)
    m["mp"] = string.format("%d*level*0.15+level*5+30", self:Quality()) 
    return m
end