local global = require "global"
local skynet = require "skynet"

local gamedefines = import(lualib_path("public.gamedefines"))
local pfobj = import(service_path("perform/pfobj"))

function NewCPerform(...)
    local o = CPerform:New(...)
    return o
end

--风云雷动

CPerform = {}
CPerform.__index = CPerform
inherit(CPerform, pfobj.CPerform)

function CPerform:CalWarrior(oAction, oPerformMgr)
    local iPerform = self:Type()
    local func = function(oAttack, oVictim, oPerform)
        return OnCalDamageRatio(oAttack, oVictim, oPerform, iPerform)
    end
    oPerformMgr:AddFunction("OnCalDamageRatio", self.m_ID, func)
end

function OnCalDamageRatio(oAttack, oVictim, oPerform, iPerform)
    if oPerform:Type() ~= iPerform then
        return 0
    end
    if not oVictim.m_oBuffMgr:HasBuff(144) then
        return 0
    end

    local sExtArg = oPerform:ExtArg()
    local mEnv = {level = oPerform:Level()}
    local mExtArg = formula_string(sExtArg, mEnv)
    return mExtArg.ratio or 0
end

