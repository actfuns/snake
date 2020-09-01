--import module

local global = require "global"
local skynet = require "skynet"

local gamedefines = import(lualib_path("public.gamedefines"))
local pfobj = import(service_path("perform/summon/pfactive"))


function NewCPerform(...)
    local o = CPerform:New(...)
    return o
end


-- 死亡之触
CPerform = {}
CPerform.__index = CPerform
inherit(CPerform, pfobj.CPerform)

function CPerform:New(pfid)
    local o = super(CPerform).New(self,pfid)
    return o
end

function CPerform:TruePerform(oAttack, oVictim, iDamageRatio)
    super(CPerform).TruePerform(self, oAttack, oVictim, iDamageRatio)

    local mArgs = formula_string(self:ExtArg(), self:SkillFormulaEnv(oAttack, oVictim))
    if math.random(100) <= mArgs.buff_ratio then
        self:Effect_Condition_For_Victim(oVictim, oAttack)
    end
end

function CPerform:ConstantDamage(oAttack, oVictim, iRatio, mEnv)
    local iSelfAttact = oAttack:QueryAttr("mag_attack")
    local iTarDefense = oVictim:QueryAttr("mag_defense")
    mEnv = mEnv or {}
    mEnv["self_attack"] = iSelfAttact
    mEnv["tar_defense"] = iTarDefense
    local iDamage = super(CPerform).ConstantDamage(self, oAttack, oVictim, iRatio, mEnv)
    return math.max(iDamage, 1)
end
