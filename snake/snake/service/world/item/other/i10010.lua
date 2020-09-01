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

function CItem:TrueUse(who,target)
    local iCostAmount = self:GetUseCostAmount()
    -- self:GS2CConsumeMsg(who)
    if who:GetEnergy() >= who:GetMaxEnergy() then
        -- local sText = global.oToolMgr:GetTextData(3011)
        -- who:NotifyMessage(sText)
        return
    end

    local iVal = self:CalEnergy(who) * iCostAmount
    assert(iVal > 0, string.format("item use error 10010"))

    local oToolMgr = global.oToolMgr
    who:RemoveOneItemAmount(self,iCostAmount,"itemuse")
    local iOldEnergy = who:GetEnergy()
    who:AddEnergy(iVal, "使用物品", {cancel_tip=true, cancel_chat=true})
    local iShowVal = who:GetEnergy() - iOldEnergy
    local sMsg = oToolMgr:FormatColorString("使用#item获得了#amount活力", {item = self:TipsName(), amount = iShowVal})
    who:NotifyMessage(sMsg)
    return true
end

function CItem:CalEnergy(oPlayer)
    local mEnv = {SLV=oPlayer:GetServerGrade(), grade=oPlayer:GetGrade()}
    local iVal = self:CalItemFormula(oPlayer, mEnv)
    return iVal
end