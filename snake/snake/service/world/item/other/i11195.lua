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

function CItem:TrueUse(oPlayer, target, iCostAmount, mArgs)
    local iExp = math.floor(self:CalItemFormula(oPlayer) * iCostAmount)
    oPlayer:RemoveOneItemAmount(self, iCostAmount, "itemuse")
    oPlayer:RewardExp(iExp, "经验宝箱")
    return true
end

function CItem:FormulaItemEnv(oPlayer, mEnv)
    local iServerGrade = oPlayer:GetServerGrade()
    return {
        SLV = iServerGrade,
        LV = oPlayer:GetGrade(),
    }
end

function NewItem(sid)
    local o = CItem:New(sid)
    return o
end
