local global = require "global"
local skynet = require "skynet"

local itembase = import(service_path("item/other/otherbase"))

function NewItem(sid)
    local o = CItem:New(sid)
    return o
end

CItem = {}
CItem.__index = CItem
inherit(CItem,itembase.CItem)


-- 九命猫元神 直接获得坐骑
function CItem:New(sid)
    local o = super(CItem).New(self,sid)
    return o
end

function CItem:TrueUse(who,target)
    local iCostAmount = self:GetUseCostAmount()
    -- self:GS2CConsumeMsg(who)
    
    who:RemoveOneItemAmount(self,iCostAmount,"itemuse")
    
    local oRideMgr = global.oRideMgr
    local oRide = oRideMgr:CreateNewRide(1001)
    who.m_oRideCtrl:AddRide(oRide)
    return true
end
