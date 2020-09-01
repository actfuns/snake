local global = require "global"
local skynet = require "skynet"

local pfobj = import(service_path("perform/pfobj"))

function NewCPerform(...)
    local o = CPerform:New(...)
    return o
end

--极乐世界

CPerform = {}
CPerform.__index = CPerform
inherit(CPerform, pfobj.CPerform)

function CPerform:TargetList(oAttack)
    local lTarget = super(CPerform).TargetList(self, oAttack)
    local lResult = {}
    for _, oTarget in pairs(lTarget) do
        if not oTarget:HasKey("disable_cure") then
            table.insert(lResult, oTarget)
        end
    end
    return lResult
end

function CPerform:SortVictim(lTarget)
    table.sort(lTarget, function(x, y)
        local bSubX = x:GetHp() < x:GetMaxHp()
        local bSubY = y:GetHp() < y:GetMaxHp()
        if bSubX ~= bSubY then
            return bSubX
        end
        if x:GetHp() == y:GetHp() or (bSubX == false and bSubY == false) then
            return x:GetWid() < y:GetWid()
        else
            return x:GetHp() < y:GetHp()
        end
    end)
    return lTarget
end
