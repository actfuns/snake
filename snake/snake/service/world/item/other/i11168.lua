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

    local oWorldMgr = global.oWorldMgr
    local mEnv = {SLV=who:GetServerGrade(), grade=who:GetGrade()}
    local iVal = self:CalItemFormula(who, mEnv)
    assert(iVal > 0, string.format("item use error 11168"))
    who:RemoveOneItemAmount(self, iCostAmount, "itemuse", {cancel_tip=true, cancel_chat=true})
    who:RewardExp(iVal, "人物经验书", {bEffect = false, cancel_tip=true, cancel_chat=true})

    local oToolMgr = global.oToolMgr
    local sMsg = oToolMgr:FormatColorString("使用#item获得了#amount经验", {item = self:TipsName(), amount = iVal})
    local oNotifyMgr = global.oNotifyMgr
    oNotifyMgr:Notify(who.m_iPid, sMsg)
    return true
end
