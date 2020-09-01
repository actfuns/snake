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
    
    local iVal = self:CalItemFormula(who, {grade = who:GetGrade()})
    iVal = iVal * iCostAmount
    assert(iVal > 0, string.format("item use error 11167"))
    local oToolMgr = global.oToolMgr
    local sMsg = oToolMgr:FormatColorString("使用#item获得了#amount招式经验", {item = self:TipsName(), amount = iVal})
    who:RemoveOneItemAmount(self, iCostAmount, "itemuse", {cancel_tip=true, cancel_chat=true})
    who.m_oActiveCtrl:AddSkillPoint(iVal, "使用物品", {cancel_tip=true, cancel_chat=true})
    who:NotifyMessage(sMsg)
    return true
end

function CItem:UseAmount(oPlayer, iTarget, iAmount, mArgs)
    return self:TrueUse(oPlayer, iTarget, iAmount, mArgs)
end



