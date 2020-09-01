local global = require "global"
local skynet = require "skynet"
local res = require "base.res"

local itembase = import(service_path("item/other/otherbase"))

function NewItem(sid)
    local o = CItem:New(sid)
    return o
end

CItem = {}
CItem.__index = CItem
CItem.m_iWarItemID = 1007
inherit(CItem,itembase.CItem)

function CItem:New(sid)
    local o = super(CItem).New(self,sid)
    return o
end

function CItem:TrueUse(oPlayer, iTarget, iCostAmount, mArgs)
    local oHD = global.oHuodongMgr:GetHuodong("nianshou")
    if oHD then
        oHD:TryRefreshNormalByPlayer(oPlayer)
    end
end

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
    return {level=self.m_iLevel, sid=self:SID(), amount=self:GetAmount(), cal_type=0}
end

function CItem:CanUseOnKS()
    return false
end
