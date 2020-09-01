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

function CItem:New(sid)
    local o = super(CItem).New(self,sid)
    return o
end

function CItem:TrueUse(who, target, iCostAmount, mArgs)
    local iCostAmount = iCostAmount or self:GetUseCostAmount()
    if iCostAmount > self:GetAmount() then return end

    -- 物品兑换
    local iSid = 10197
    local iCnt = iCostAmount * 5
    if not who:ValidGive({[iSid] = iCnt}) then
        who:NotifyMessage(global.oItemHandler:GetTextData(1015)) 
        return 
    end

    who:RemoveOneItemAmount(self, iCostAmount, "itemuse")
    who:RewardItems(iSid, iCnt, "use_11100")
    return true
end

function CItem:UseAmount(oPlayer, iTarget, iAmount, mArgs)
    return self:TrueUse(oPlayer, iTarget, iAmount, mArgs)
end
    
