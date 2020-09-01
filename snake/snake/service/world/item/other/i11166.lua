local global = require "global"
local skynet = require "skynet"

local itembase = import(service_path("item/other/otherbase"))

function NewItem(sid)
    local o = CItem:New(sid)
    return o
end

CItem = {}
CItem.__index = CItem
inherit(CItem, itembase.CItem)

function CItem:New(sid)
    local o = super(CItem).New(self,sid)
    return o
end

function CItem:TrueUse(who, target)
    local iCostAmount = self:GetUseCostAmount()
    -- self:GS2CConsumeMsg(who)
    local iVal = 300
    local oToolMgr = global.oToolMgr
    local sMsg = oToolMgr:FormatColorString("使用#item获得了#skpoint技能点", {item = self:TipsName(), skpoint = iVal})
    who:RemoveOneItemAmount(self, iCostAmount, "itemuse")
    who.m_oActiveCtrl:AddSkillPoint(iVal * iCostAmount, "use item gain")
    who:NotifyMessage(sMsg)
    return true
end
