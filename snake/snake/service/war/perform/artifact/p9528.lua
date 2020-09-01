--import module

local global = require "global"
local skynet = require "skynet"

local gamedefines = import(lualib_path("public.gamedefines"))
local pfobj = import(service_path("perform.pfobj"))

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

function CPerform:CalWarrior(oAction, oPerformMgr)
    local oBuffMgr = oAction.m_oBuffMgr
    oBuffMgr:SetAttr("ignore_stealth", 1)

    local iPerform = self:Type()
    local func = function(oAttack, oVictim, oPerform)
        return OnCalDamageResultRatio(iPerform, oAttack, oVictim, oPerform)
    end
    oPerformMgr:AddFunction("OnCalDamageResultRatio", self.m_ID, func)
end

function OnCalDamageResultRatio(iPerform, oAttack, oVictim, oPerform)
    if not oVictim or oVictim:IsDead() then
        return 0
    end
    if not oAttack or oAttack:IsDead() then
        return 0
    end
    if not oVictim:HasKey("stealth") then
        return 0
    end

    local oPerform = oAttack:GetPerform(iPerform)
    if not oPerform then return 0 end

    local sExtArg = oPerform:ExtArg()
    local mEnv = oPerform:SkillFormulaEnv(oAttack, oVictim)
    local mExtArg = formula_string(sExtArg, mEnv)
    return -mExtArg.ratio or 0
end
