local global = require "global"

local itembase = import(service_path("item/partner/partnerbase"))

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
    local oPartner = who.m_oPartnerCtrl:GetPartner(target)
    if not oPartner then
        return
    end

    -- 判断道具是否足够
    local iCostAmount = self:GetUseCostAmount()
    if iCostAmount > self:GetAmount() then
        return
    end

    -- 检查经验
--    local bRet = oPartner:PreCheckUseUpgradeProp()
--    if not bRet then
--        return
--    end
    if oPartner:NeedUpper() then return end

    -- 扣除道具
    local iExp = oPartner:GetExpPropCost(self:SID()).expadd

    local mCost = {[self:SID()]=iCostAmount}
    -- self:GS2CConsumeMsg(who)
    who:RemoveOneItemAmount(self,iCostAmount,"itemuse")

    local sReason = "UsePartnerExpProp"
    iExp = oPartner:RewardExp(iExp, sReason)
    if iExp > 0 then
       oPartner:SendNotification(1003, {partner = oPartner:GetName(), amount = iExp})
    end
    return true
end
