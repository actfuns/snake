local global = require "global"
local skynet = require "skynet"
local pfobj = import(service_path("perform/pfobj"))
local gamedefines = import(lualib_path("public.gamedefines"))

function NewCPerform(...)
    local o = CPerform:New(...)
    return o
end

--摩诃无量

CPerform = {}
CPerform.__index = CPerform
inherit(CPerform, pfobj.CPerform)

function CPerform:CalWarrior(oAction, oPerformMgr)
    local iPerform = self:Type()
    local func = function(oAttack, oVictim, oPerform)
        return AddCureRatio(iPerform, oAttack, oVictim, oPerform)
    end
    oPerformMgr:AddFunction("AddCureRatio", self.m_ID, func)
end

function AddCureRatio(iPerform, oAttack, oVictim, oUsePerform)
    local oPerform = oAttack:GetPerform(iPerform)
    if not oPerform then return 0 end

    local oWar = oAttack:GetWar()
    if not oWar then return 0 end

    local iSumWid = oAttack:Query("curr_sum")
    if iSumWid and oWar:GetWarrior(iSumWid) then
        return 0
    end

    local sExtArg = oPerform:ExtArg()
    local mEnv = oPerform:SkillFormulaEnv(oAttack)
    local mExtArg = formula_string(sExtArg, mEnv)

    return mExtArg.cure_ratio or 0
end

