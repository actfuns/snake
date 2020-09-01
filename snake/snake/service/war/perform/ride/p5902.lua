local global = require "global"
local skynet = require "skynet"
local pfobj = import(service_path("perform/pfobj"))

function NewCPerform(...)
    local o = CPerform:New(...)
    return o
end

--内力损毁

CPerform = {}
CPerform.__index = CPerform
inherit(CPerform, pfobj.CPerform)


function CPerform:SkillFormulaEnv(oAttack, oVictim)
    local mEnv = super(CPerform).SkillFormulaEnv(self, oAttack, oVictim)
    if oVictim then
        mEnv.v_grade = oVictim:GetGrade()
    end
    return mEnv
end

function CPerform:CalWarrior(oAction, oPerformMgr)
    local iPerform = self:Type()
    local func = function(oAttack, oVictim, oPerform, iDamage, mArgs)
        OnAttack(iPerform, oAttack, oVictim, oPerform, iDamage, mArgs)
    end
    oPerformMgr:AddFunction("OnAttack", self.m_ID, func)
end

function OnAttack(iPerform, oAttack, oVictim, oUsePerform, iDamage, mArgs)
    local oPerform = oAttack:GetPerform(iPerform)
    if not oPerform then return end

    if not oVictim or oVictim:IsDead() then return end

    local sExtArg = oPerform:ExtArg()
    local mEnv = oPerform:SkillFormulaEnv(oAttack, oVictim)
    local mExtArg = formula_string(sExtArg, mEnv)

    if math.random(100) <= mExtArg.ratio then
        global.oActionMgr:DoAddMp(oVictim, -mExtArg.sub_mp)
    end
end
