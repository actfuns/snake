local global = require "global"
local skynet = require "skynet"
local pfobj = import(service_path("perform/pfobj"))
local gamedefines = import(lualib_path("public.gamedefines"))

function NewCPerform(...)
    local o = CPerform:New(...)
    return o
end

--四象封印

CPerform = {}
CPerform.__index = CPerform
inherit(CPerform, pfobj.CPerform)

function CPerform:CalWarrior(oAction, oPerformMgr)
    local iPerform = self:Type()
    local func = function(oAttack, oVictim, oPerform)
        return MaxRange(iPerform, oAttack, oVictim, oPerform)
    end
    oPerformMgr:AddFunction("MaxRange", self.m_ID, func)
end

function MaxRange(iPerform, oAttack, oVictim, oUsePerform)
    local oPerform = oAttack:GetPerform(iPerform)
    if not oPerform then return 0 end

    if not oUsePerform then return 0 end

    if oUsePerform:ActionType() ~= gamedefines.WAR_ACTION_TYPE.SEAL then
        return 0
    end

    local sExtArg = oPerform:ExtArg()
    local mEnv = oPerform:SkillFormulaEnv(oAttack, oVictim)
    local mExtArg = formula_string(sExtArg, mEnv)
    
    if math.random(100) <= mExtArg.ratio then
        return mExtArg.ext_cnt
    end

    return 0
end

