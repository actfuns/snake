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

function CItem:TrueUse(who, target)
    local oNotify = global.oNotifyMgr
    local sKey = string.format("Use%d", self.m_SID)
    local iTotal = who.m_oWeekMorning:Query(sKey, 0)
    if iTotal >= 14 then
        local sMsg = global.oToolMgr:GetTextData(1045, {"itemtext"})
        oNotify:Notify(who.m_iPid, sMsg)
        return
    end
    local iCost = self:GetUseCostAmount()
    local iPoint, iPointLimit = who.m_oBaseCtrl:GetDoublePoint()
    if iPointLimit+60*iCost > 840 then
        local sMsg = global.oToolMgr:GetTextData(1043, {"itemtext"})
        oNotify:Notify(who.m_iPid, sMsg)
        return
    end

    -- self:GS2CConsumeMsg(who)
    who:RemoveOneItemAmount(self,iCost,"itemuse")
    who.m_oWeekMorning:Add(sKey, 1)
    who.m_oBaseCtrl:AddDoublePointLimit(60*iCost)
    local sMsg = global.oToolMgr:GetTextData(1044, {"itemtext"})
    local mReplace = {amount = 14 - who.m_oWeekMorning:Query(sKey, 0)}
    sMsg = global.oToolMgr:FormatColorString(sMsg, mReplace)
    oNotify:Notify(who.m_iPid, sMsg)
    who.m_oBaseCtrl:RefreshDoublePoint()
    return true
end
