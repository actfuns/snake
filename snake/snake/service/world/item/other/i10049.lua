local global = require "global"
local skynet = require "skynet"

local itembase = import(service_path("item/other/pelletbase"))

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
    local oNotifyMgr = global.oNotifyMgr
    if who.m_oStateCtrl:GetBaoShiCount() >= who.m_oStateCtrl:GetBaoShiMaxCount() then
        oNotifyMgr:Notify(who:GetPid(), "饱食度已达上限，不能继续使用")
        return
    end

    local iVal = self:CalItemFormula(who)
    local iCostAmount = self:GetUseCostAmount()
    who:RemoveOneItemAmount(self,iCostAmount,"itemuse")
    who.m_oStateCtrl:AddBaoShiCount(iVal, "使用物品")

    local iCnt = who.m_oStateCtrl:GetBaoShiCount()
    local sMsg = global.oToolMgr:GetSystemText({"itemtext"}, 1037, {item = self:TipsName(), amount = iCnt})
    oNotifyMgr:Notify(who:GetPid(), sMsg)
    return true
end

function CItem:FormulaItemEnv(oPlayer, mEnv)
    local m = {quality=self:Quality(), grade=oPlayer:GetGrade()}
    return m
end
