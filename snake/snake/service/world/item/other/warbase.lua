local global = require "global"
local skynet = require "skynet"

local itembase = import(service_path("item/other/pelletbase"))

function NewItem(sid)
    local o = CItem:New(sid)
    return o
end

CItem = {}
CItem.__index = CItem
CItem.m_iWarItemID = 1001
-- 主要用于计算抗药性　0级不参与抗药性计算
CItem.m_iLevel = 0
-- 1:3级药和酒 2:2级药次数累计
CItem.m_iCalType = 0
inherit(CItem,itembase.CItem)

function CItem:ValidUseInWar()
    return true
end

function CItem:PackWarUseInfo()
    local mData = {}
    -- mData["itemid"] = self.m_ID
    mData["waritemid"] = self.m_iWarItemID
    mData["args"] = self:PackWarArgsInfo()
    mData["tips"] = self:TipsName()
    return mData
end

function CItem:PackWarArgsInfo()
    return {level=self.m_iLevel, sid=self:SID(), amount=self:GetAmount(), cal_type=self.m_iCalType}
end

