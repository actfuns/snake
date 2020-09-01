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
    mEnv.hp = oVictim and oVictim:GetHp() or 0
    return mEnv
end

function CPerform:GetAddVictimBuffRatio(oAttack)
    local sExtArg = self:ExtArg()
    local mEnv = self:SkillFormulaEnv()
    local mExtArg = formula_string(sExtArg, mEnv)
    
    if oAttack and oAttack:IsPlayer() and oAttack:GetData("school") == gamedefines.PLAYER_SCHOOL.YAOCHI then
        return mExtArg.ratio + oAttack:GetAura() * global.oActionMgr:GetWarConfig("aura_yaochi")
    else
        return mExtArg.ratio
    end
end

