local global = require "global"
local skynet = require "skynet"

local itembase = import(service_path("item/other/otherbase"))

function NewItem(sid)
    local o = CItem:New(sid)
    return o
end

CItem = {}
CItem.__index = CItem
inherit(CItem, itembase.CItem)

function CItem:New(sid)
    local o = super(CItem).New(self,sid)
    return o
end

function CItem:TrueUse(oPlayer, iTarget)
    if not global.oHuodongMgr:CallHuodongFunc("lingxi", "CanUseFlowerItem", oPlayer) then
        return
    end
    local iCostAmount = self:GetUseCostAmount()
    -- self:GS2CConsumeMsg(oPlayer)
    oPlayer:RemoveOneItemAmount(self, iCostAmount, "itemuse")
    return global.oHuodongMgr:CallHuodongFunc("lingxi", "UseFlowerItem", oPlayer)
end

function CItem:CanUseOnKS()
    return false
end

