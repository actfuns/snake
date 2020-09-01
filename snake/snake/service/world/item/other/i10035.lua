local global = require "global"
local skynet = require "skynet"

local itembase = import(service_path("item/other/otherbase"))


CItem = {}
CItem.__index = CItem
inherit(CItem,itembase.CItem)

function CItem:New(sid)
    local o = super(CItem).New(self,sid)
    return o
end

function CItem:TrueUse(who,target)
    if not global.oToolMgr:IsSysOpen("SUMMON_SYS", who) then return end

    local oSummon = who.m_oSummonCtrl:GetFightSummon()
    if not oSummon then
        who:NotifyMessage("没有参战宠物")
        return
    end

    local oSummonMgr = global.oSummonMgr
    local iMaxUse = oSummonMgr:GetMaxUseGrow()
    local iUseCnt = oSummon:GetData("cnt_usegrow", 0)
    if iUseCnt >= iMaxUse then
        who:NotifyMessage("已达最大使用次数")        
        return
    end

    local iCostAmount = 1
    if iCostAmount > self:GetAmount() then return end
    local iGrow = oSummonMgr:CalGrow()
    who:RemoveOneItemAmount(self,iCostAmount,"itemuse")    
    oSummon:SetData("cnt_usegrow", iUseCnt + 1)
    oSummonMgr:AddSummonGrow(oSummon, iGrow)
    -- 成长增加了0.001，火龙还可使用3次龙魂秘宝
    local sCount = string.format("%.3f", iGrow/1000)
    local sMsg = "成长增加了#count，#summon还可使用#amount次#item"
    sMsg = global.oToolMgr:FormatColorString(sMsg, {count=sCount, summon=oSummon:Name(), item=self:TipsName(), amount=(iMaxUse-iUseCnt-1)}) 
    who:NotifyMessage(sMsg)
    global.oChatMgr:HandleMsgChat(who, sMsg)
    return true
end

function NewItem(sid)
    local o = CItem:New(sid)
    return o
end
