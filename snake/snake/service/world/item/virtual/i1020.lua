local global = require "global"
local skynet = require "skynet"

local virtualbase = import(service_path("item/virtual/virtualbase"))

CItem = {}
CItem.__index = CItem
inherit(CItem,virtualbase.CItem)

function CItem:Reward(oPlayer, sReason, mArgs)
    local iValue = self:GetData("Value", 1)
    if not iValue then return end

    oPlayer.m_oActiveCtrl:AddSkillPoint(iValue * self:GetAmount(), sReason, mArgs)
end

function NewItem(sid)
    local o = CItem:New(sid)
    return o
end