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

function CPerform:SkillFormulaEnv(oAttack, oVictim)
    local mEnv = super(CPerform).SkillFormulaEnv(self, oAttack, oVictim)
    mEnv.max_hp = oVictim and oVictim:GetMaxHp() or 0
    return mEnv
end

function CPerform:GetAddVictimBuffRatio()
    local sExtArg = self:ExtArg()
    local mEnv = self:SkillFormulaEnv()
    local mExtArg = formula_string(sExtArg, mEnv)
    
    return mExtArg.ratio or 60
end

