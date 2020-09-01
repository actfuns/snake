--import module

local global = require "global"
local skynet = require "skynet"
local pfobj = import(service_path("perform/fabao/fabaobase"))
local gamedefines = import(lualib_path("public.gamedefines"))

function NewCPerform(...)
    local o = CPerform:New(...)
    return o
end

CPerform = {}
CPerform.__index = CPerform
inherit(CPerform, pfobj.CPerform)

function CPerform:TriggerFaBaoEffect(oVictim)
    if not oVictim or oVictim:IsDead() then return end

    local oBuff = oVictim.m_oBuffMgr:HasBuff(237)
    if not oBuff then return end

    local iValue = self:CalSkillFormula(nil,nil,100,{grade=oVictim:GetGrade()})
    oVictim.m_oBuffMgr:AddFunction("OnCalDamage", self.m_ID, function (oAtt, oVic, oPerform)
        return OnCalDamage(iValue, oAtt, oVic, oPerform) or 0
    end)
end

function OnCalDamage(iValue, oAttack, oVictim, oUsePerform)
    if not oAttack or iValue <= 0 then return end

    if oUsePerform and oUsePerform:AttackType() == gamedefines.WAR_PERFORM_TYPE.MAGIC then
        return 0
    end

    return iValue
end
