local global = require "global"
local skynet = require "skynet"

local itembase = import(service_path("item/other/pelletbase"))

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

function CItem:CalSummonLife(oPlayer, oSummon)
    local mEnv = {quality=self:Quality(), carrylv=oSummon:CarryGrade()}
    return self:CalItemFormula(oPlayer, mEnv)
end

function CItem:CanUse2SummonLife()
    return true
end

