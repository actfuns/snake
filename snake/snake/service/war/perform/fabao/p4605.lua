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
        OnDead(iPerform, oAttack)
    end
    oPerformMgr:AddFunction("OnDead", self.m_ID, func)
end

function OnDead(iPerform,oAttack) 
    if not oAttack or not oAttack:IsDead()  then
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
    local iValue = oPerform:CalSkillFormula(oAttack,nil,100,{})
    local iSP = oAttack:GetData("presp",0)
    iSP = math.floor(iSP*iValue/100)
    oAttack:AddSP(iSP)
end