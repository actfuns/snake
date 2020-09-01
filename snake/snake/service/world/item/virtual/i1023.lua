local global = require "global"
local skynet = require "skynet"

local virtualbase = import(service_path("item/virtual/virtualbase"))

CItem = {}
CItem.__index = CItem
inherit(CItem,virtualbase.CItem)

function CItem:Reward(oPlayer, sReason, mArgs)
    local oToolMgr = global.oToolMgr
    if not oToolMgr:IsSysOpen("RIDE_UPGRADE", oPlayer, true) then return end

    local iValue = self:GetData("Value")
    if not iValue then
        return
    end
    oPlayer.m_oRideCtrl:AddExp(iValue, sReason)
end

function NewItem(sid)
    local o = CItem:New(sid)
    return o
end
