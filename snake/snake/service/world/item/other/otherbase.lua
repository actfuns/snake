local global = require "global"
local skynet = require "skynet"
local interactive =  require "base.interactive"

local itembase = import(service_path("item/itembase"))

CItem = {}
CItem.__index = CItem
inherit(CItem,itembase.CItem)
CItem.m_ItemType = "other"

function NewItem(sid)
    local o = CItem:New(sid)
    return o
end

function CItem:CalItemFormula(oPlayer, mEnv)
    local sFormula = self:GetItemData()["item_formula"]
    if not sFormula or sFormula == "" then
        return 0
    end

    local mItemEnv = self:FormulaItemEnv(oPlayer, mEnv)
    return math.floor(formula_string(sFormula, mItemEnv))
end

function CItem:FormulaItemEnv(oPlayer, mEnv)
    return mEnv or {}
end

function CItem:Use(oWho, iTarget, mArgs)
    local iMinGrade = self:GetItemData()["minGrade"]
    if oWho:GetGrade() < self:GetItemData()["minGrade"] then
        local sMsg = global.oToolMgr:GetSystemText({"itemtext"}, 1033, {level=iMinGrade})
        oWho:NotifyMessage(sMsg)
        return
    end
    super(CItem).Use(self, oWho, iTarget, mArgs)
end

