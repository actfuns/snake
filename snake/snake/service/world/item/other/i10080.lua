local global = require "global"
local skynet = require "skynet"
local interactive = require "base.interactive"
local itembase = import(service_path("item/other/otherbase"))

CItem = {}
CItem.__index = CItem
inherit(CItem,itembase.CItem)

function NewItem(iSid)
    local o = CItem:New(iSid)
    return o
end

function CItem:TrueUse(oPlayer, iTarget)
    local iCostAmount = self:GetUseCostAmount()
    local iTitle = self:CalItemFormula(oPlayer)
    oPlayer:RemoveOneItemAmount(self,iCostAmount,"itemuse")
    oPlayer:AddTitle(iTitle)
end

function CItem:CanUseOnKS()
    return false
end
