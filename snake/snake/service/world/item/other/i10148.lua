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

function CItem:TrueUse(who, iTarget, iCostAmount, mArgs)
    local iCostAmount = iCostAmount or self:GetUseCostAmount()
    if iCostAmount > self:GetAmount() then return end

    local iCnt = who.m_oTodayMorning:Query("use_marry_xt", 0)
    if iCnt >= 10 then
        who:NotifyMessage("你今天已经吃了10颗喜糖啦，小心蛀牙哦！")
        return
    end
    -- if who.m_oStateCtrl:GetBaoShiCount() >= who.m_oStateCtrl:GetBaoShiMaxCount() then
    --     who:NotifyMessage("饱食度已达上限，不能继续使用")
    --     return
    -- end

    who.m_oTodayMorning:Add("use_marry_xt", iCostAmount)
    local iVal = 20 * iCostAmount
    who:RemoveOneItemAmount(self,iCostAmount,"itemuse")
    who.m_oStateCtrl:AddBaoShiCount(iVal, "使用物品")

    local iSliver = 9999 * iCostAmount
    who:RewardSilver(iSliver, "使用物品")

    local oState = who.m_oStateCtrl:GetState(1010)
    local mStateArgs = {time=60*60}
    if oState then
        oState:Config(who, mStateArgs)
        oState:Refresh(who:GetPid())
    else
        who.m_oStateCtrl:AddState(1010, mStateArgs)
    end
    return true
end
    
