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
    local oOrg = who:GetOrg()
    if not oOrg then
        who:NotifyMessage("请加入帮派后使用")
        return
    end

    local iCostAmount = iCostAmount or self:GetUseCostAmount()
    if iCostAmount > self:GetAmount() then return end
    -- 增加：3点帮贡
    -- 增加：10000点行会资金
    -- 增加经验：人物等级*50-200
    local iVal = 3 * iCostAmount
    local iCash = 10000 * iCostAmount
    local iExp = math.max(0, who:GetGrade() * 50 -200) * iCostAmount
    local oToolMgr = global.oToolMgr
    local sMsg = oToolMgr:FormatColorString("使用#item获得了#amount经验，#amount帮贡，#amount帮派资金", 
        {item = self:TipsName(), amount = {iExp, iVal, iCash}})
    local sReason = "use_item"
    who:NotifyMessage(sMsg)
    who:RemoveOneItemAmount(self, iCostAmount, sReason, {cancel_tip=true, cancel_chat=true})
    who:AddOrgOffer(iVal, sReason, {cancel_tip=1})
    oOrg:AddCash(iCash, who:GetPid())
    if iExp > 0 then
        who:RewardExp(iExp, sReason, {cancel_tip=1})
    end
    return true
end

function CItem:UseAmount(oPlayer, iTarget, iAmount, mArgs)
    return self:TrueUse(oPlayer, iTarget, iAmount, mArgs)
end
