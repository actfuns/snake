local global = require "global"
local skynet = require "skynet"

local itembase = import(service_path("item/other/otherbase"))


MAX_USE_NUM = 20

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
    if who.m_oTodayMorning:Query("use_exp_book", 0) + iCostAmount > MAX_USE_NUM then
        who:NotifyMessage("江湖心得使用次数已达上限")          
        return
    end
    if who:GetGrade() < 30 then
        who:NotifyMessage("30级才能使用")          
        return
    end

    who.m_oTodayMorning:Add("use_exp_book", iCostAmount)
    who:RemoveOneItemAmount(self,iCostAmount,"itemuse")
    
    local oWorldMgr = global.oWorldMgr
    local oChatMgr = global.oChatMgr
    local oToolMgr = global.oToolMgr
    local sFormula = "10000+2*SLV^2+2*LV^2+LV*50"
    local mEnv = {SLV=who:GetServerGrade(), LV=who:GetGrade()}
    local iExp = math.floor(formula_string(sFormula, mEnv))
    iExp = iExp * iCostAmount

    local iCnt = math.max(0, MAX_USE_NUM - who.m_oTodayMorning:Query("use_exp_book", 0))
    local mResult = who:RewardExp(iExp,"人物经验书", {bEffect = false, cancel_tip=true, cancel_chat=true})
    local iRealExp = mResult.exp
    local sMsg = oToolMgr:FormatColorString("你获得了#exp经验,今天剩余可使用次数:#count", {exp = iRealExp, count=iCnt})
    who:NotifyMessage(sMsg)
    oChatMgr:HandleMsgChat(who, sMsg)
    return true
end

function CItem:GetTureUseAmount(oPlayer, iAmount)
    iAmount = iAmount or self:GetUseCostAmount()
    local iCanUse = math.max(MAX_USE_NUM - oPlayer.m_oTodayMorning:Query("use_exp_book", 0), 1)
    return math.min(iCanUse, iAmount)
end

function CItem:UseAmount(oPlayer, iTarget, iAmount, mArgs)
    iAmount = self:GetTureUseAmount(oPlayer, iAmount)
    return self:TrueUse(oPlayer, iTarget, iAmount, mArgs)
end

function NewItem(sid)
    local o = CItem:New(sid)
    return o
end
