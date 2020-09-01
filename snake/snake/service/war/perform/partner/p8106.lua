--import module

local global = require "global"
local skynet = require "skynet"
local pfobj = import(service_path("perform/pfobj"))
local gamedefines = import(lualib_path("public.gamedefines"))

function NewCPerform(...)
    local o = CPerform:New(...)
    return o
end

--渴血

CPerform = {}
CPerform.__index = CPerform
inherit(CPerform, pfobj.CPerform)

function CPerform:CalWarrior(oAction, oPerformMgr)
    oAction:Set("ignore_stealth", 1)

    local iPerform = self:Type()
    local func =function(oAttack, oVictim, oPerform)
        return OnCalDamageResultRatio(iPerform, oAttack, oVictim, oPerform)
    end
    oPerformMgr:AddFunction("OnCalDamageResultRatio", self.m_ID, func)
end

function OnCalDamageResultRatio(iPerform, oAttack, oVictim, oUsePerform)
    local oPerform = oAttack:GetPerform(iPerform)
    if not oPerform then return 0 end

    if not oVictim then return 0 end

    if not oVictim:HasKey("stealth") then return 0 end

    local sExtArg = oPerform:ExtArg()
    local mEnv = oPerform:SkillFormulaEnv(oAttack, oVictim)
    local mExtArg = formula_string(sExtArg, mEnv)

    return mExtArg.ratio or 0
end

