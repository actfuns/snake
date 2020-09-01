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

function CPerform:BoutEnv(oAttack, oVictim)
    local mEnv = super(CPerform).BoutEnv(self,oAttack, oVictim)
    local oPerform = oAttack:GetPerform(4614)
    local iExtraBout = 0
    if oPerform then
        iExtraBout = 1
    end
    mEnv.extra = iExtraBout
    return mEnv
end

function CPerform:TriggerFaBaoEffect(oWarrior)
    if not oWarrior or oWarrior:IsDead() then 
        return 
    end
    local oWar  = oWarrior:GetWar()
    if not oWar then 
        return 
    end
    local iValue = self:CalSkillFormula(oWarrior,nil,100,{})
    -- print("TriggerFaBaoEffect",self.m_ID,iValue)
    oWarrior:AddSP(iValue)
end