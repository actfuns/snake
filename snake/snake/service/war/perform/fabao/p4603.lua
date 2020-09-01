--import module

local global = require "global"
local skynet = require "skynet"
local pfobj = import(service_path("perform/fabao/fabaobase"))

function NewCPerform(...)
    local o = CPerform:New(...)
    return o
end

CPerform = {}
CPerform.__index = CPerform
inherit(CPerform, pfobj.CPerform)

function CPerform:CalWarrior(oWarrior,oPerformMgr)
    local iPerform = self:Type()
    local func = function(oAttack)
        OnBoutEnd(iPerform, oAttack)
    end
    oPerformMgr:AddFunction("OnBoutEnd", self.m_ID, func)
end

function OnBoutEnd(iPerform,oAttack) 
    if not oAttack or oAttack:IsDead() then 
        return 
    end
    local oWar  = oAttack:GetWar()
    if not oWar then 
        return 
    end
    local oPerform = oAttack:GetPerform(iPerform)
    if not oPerform then
        return
    end
    if not oAttack.m_oBuffMgr:HasBuff(234) then
        return 
    end
    local iValue = oPerform:CalSkillFormula(oAttack,nil,100,{})
    oAttack:AddSP(iValue)
end