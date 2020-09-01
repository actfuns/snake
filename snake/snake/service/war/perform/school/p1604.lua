local global = require "global"
local skynet = require "skynet"

local gamedefines = import(lualib_path("public.gamedefines"))
local pfobj = import(service_path("perform/pfobj"))

function NewCPerform(...)
    local o = CPerform:New(...)
    return o
end

CPerform = {}
CPerform.__index = CPerform
inherit(CPerform, pfobj.CPerform)

function CPerform:New(pfid)
    local o = super(CPerform).New(self,pfid)
    return o
end

function CPerform:CalWarrior(oWarrior, oPerformMgr)
    local iPerform = self:Type()
    local func = function(oAttack, oVictim, oPerform, iDamage, mArgs)
        OnAttack(iPerform, oAttack, oVictim, oPerform, iDamage, mArgs)
    end
    oPerformMgr:AddFunction("OnAttack", self.m_ID, func)
end

function OnAttack(iPerform, oAttack, oVictim, oUsePerform, iDamage, mArgs)
    if iDamage <= 0 then return end
   
    if not oUsePerform or oUsePerform:Type() ~= iPerform then return end

    local sExtArg = oUsePerform:ExtArg()
    local mEnv = oUsePerform:SkillFormulaEnv(oAttack, oVictim)
    local mExtArg = formula_string(sExtArg, mEnv)

    local iSubHp = math.floor(iDamage * mExtArg.ratio / 100)
    if iSubHp > 0 then
        global.oActionMgr:DoSubHp(oAttack, iSubHp, oAttack)
    end
end
