local global = require "global"
local skynet = require "skynet"
local interactive =  require "base.interactive"

local itembase = import(service_path("item/itembase"))
local loadsummon = import(service_path("summon.loadsummon"))

CItem = {}
CItem.__index = CItem
inherit(CItem,itembase.CItem)
CItem.m_ItemType = "summon"

function NewItem(sid)
    local o = CItem:New(sid)
    return o
end

function CItem:GetSummonID()
    local iSummon = self:GetItemData()["summonid"]
    return iSummon
end

function CItem:TrueUse(oWho, iTarget)
    local iSummon = self:GetSummonID()
    if oWho.m_oSummonCtrl:IsFull() then
        oWho:NotifyMessage("携带的宠物数量已经达到上限了")
        return
    end

    local oSummon = loadsummon.GetSummon(iSummon)
    local iMinLv = oSummon:CarryGrade() - 10
    if iMinLv > oWho:GetGrade() then
        oWho:NotifyMessage(string.format("#G%s#n级才能使用%s", iMinLv, self:TipsName()))
        return         
    end

    oWho:RemoveOneItemAmount(self, 1, "itemuse")
    local oNewSummon = loadsummon.CreateSummon(iSummon, 0)
    oWho.m_oSummonCtrl:AddSummon(oNewSummon, "使用物品")
    oWho:NotifyMessage(string.format("获得一只#G%s#n宝宝", oNewSummon:Name()))
end
