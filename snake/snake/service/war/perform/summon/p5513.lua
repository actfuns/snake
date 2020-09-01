--import module

local global = require "global"
local skynet = require "skynet"

local gamedefines = import(lualib_path("public.gamedefines"))
local pfobj = import(service_path("perform/summon/pfbase"))


function NewCPerform(...)
    local o = CPerform:New(...)
    return o
end

function OnCalDamage(iPerform, oAttack, oVictim, oUsePerform)
    if not oAttack or not oVictim then return 0 end
    if oUsePerform and oUsePerform:IsGroupPerform() then return 0 end
    local oPerform = oAttack:GetPerform(iPerform)
    if not oPerform then return 0 end

    local iRatio = oPerform:CalSkillFormula()
    if math.random(100) > iRatio then return 0 end
    local iAttSpeed = oAttack:QueryAttr("speed") or 0
    local iDefSpeed = oVictim:QueryAttr("speed") or 0
    local sExtArgs = oPerform:ExtArg()
    local mEnv = {att_speed = iAttSpeed,
                  def_speed = iDefSpeed,
                  grade = oAttack:GetGrade()}
    local mArgs = formula_string(sExtArgs, mEnv)

    local iDamage = math.max(mArgs["damage"], mArgs["min_damage"])
    return iDamage
end


-- 突击(天赋)
CPerform = {}
CPerform.__index = CPerform
inherit(CPerform, pfobj.CPerform)

function CPerform:New(pfid)
    local o = super(CPerform).New(self, pfid)
    return o
end

function CPerform:CalWarrior(oAction, oPerformMgr)
    local iPerform = self:Type()
    local func = function (oAttack, oVictim, oUsePerform)
        return OnCalDamage(iPerform, oAttack, oVictim, oUsePerform)        
    end
    oAction:AddFunction("OnCalDamage", self.m_ID, func)
end

