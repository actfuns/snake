local global = require "global"
local itembase = import(service_path("item/other/otherbase"))
local loadsummon = import(service_path("summon.loadsummon"))

function NewItem(sid)
    local o = CItem:New(sid)
    return o
end

CItem = {}
CItem.__index = CItem
inherit(CItem,itembase.CItem)

function CItem:Use(oWho, iTarget, mArgs)
    if self:IsLocked() then
        return
    end
    local iNeedAmount = self:GetUseCostAmount()
    local iSid = self:SID()
    local iItemAmount = oWho:GetItemAmount(iSid)
    if iItemAmount < iNeedAmount then
        local sMsg = "需要#amount个#item才能兑换"
        sMsg = global.oToolMgr:FormatColorString(sMsg, {amount=iNeedAmount, item=self:TipsName()})
        global.oNotifyMgr:Notify(oWho:GetPid(), sMsg)
        return
    else
        if oWho:Query("exchange_4001", 0) > 0 then
            global.oNotifyMgr:Notify(oWho:GetPid(), "只能兑换一次")
            return
        end
        if oWho.m_oSummonCtrl:IsFull() then
            global.oNotifyMgr:Notify(oWho:GetPid(), "宠物已达最大携带上限")
            return
        end
    end
    return self:TrueUse(oWho, iTarget, mArgs)
end

function CItem:TrueUse(who,target, mArgs)
    local iCostAmount = self:GetUseCostAmount()
    local iSid = self:SID()
    who:RemoveItemAmount(iSid, iCostAmount, "兑换宠物")
    who:Set("exchange_4001", 1)
    local oSummon = loadsummon.CreateFixedPropSummon(4001, 7)
    who.m_oSummonCtrl:AddSummon(oSummon, self:Name().."兑换")
    local sMsg = global.oToolMgr:FormatColorString("获得宠物#summon", {summon=oSummon:Name()})
    global.oNotifyMgr:Notify(who:GetPid(), sMsg)
    global.oSummonMgr:SendChuanWen(who, 1069, oSummon)
    return true
end

