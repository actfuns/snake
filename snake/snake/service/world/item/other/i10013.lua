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
    local iCost = iCostAmount or self:GetUseCostAmount()
    if iCost > self:GetAmount() then return end

    local mEnv = {SLV=who:GetServerGrade(), grade=who:GetGrade()}
    local iVal = self:CalItemFormula(who, mEnv) * iCost
    local iPoint, iPointLimit = who.m_oBaseCtrl:GetDoublePoint()
    if iPointLimit + iVal > 840 then
        who:NotifyMessage(global.oToolMgr:GetTextData(1043, {"itemtext"}))
        return
    end

    who:RemoveOneItemAmount(self, iCost, "itemuse")
    who.m_oBaseCtrl:AddDoublePointLimit(iVal)
    local sMsg = global.oToolMgr:FormatColorString("使用#item获得了#amount双倍点", {item = self:TipsName(), amount = iVal})
    who:NotifyMessage(sMsg)
    who.m_oBaseCtrl:RefreshDoublePoint()
    return true
end
