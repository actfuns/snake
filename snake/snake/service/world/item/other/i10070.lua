local global = require "global"
local skynet = require "skynet"
local record = require "public.record"

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
    o.m_iAddCnt = 1
    return o
end

function CItem:TrueUse(who, target)
    local oJJCMgr = global.oJJCMgr
    if not oJJCMgr:ValidAddFightTimes(who) then
        return
    end
    local iCostAmount = self:GetUseCostAmount()
    -- self:GS2CConsumeMsg(who)
    local iAddCnt = self.m_iAddCnt
    local oToolMgr = global.oToolMgr
    local sMsg = oToolMgr:FormatColorString(oJJCMgr:GetTextData(1025), {amount = iAddCnt})
    who:RemoveOneItemAmount(self, iCostAmount, "itemuse")
    who:GetJJC():AddFightTimes(iAddCnt)
    local oNotifyMgr = global.oNotifyMgr
    oNotifyMgr:Notify(who:GetPid(), sMsg)
    return true
end

function CItem:CanUseOnKS()
    return false
end
