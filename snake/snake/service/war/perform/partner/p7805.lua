--import module

local global = require "global"
local skynet = require "skynet"
local pfobj = import(service_path("perform/pfobj"))

function NewCPerform(...)
    local o = CPerform:New(...)
    return o
end

--法力无边

CPerform = {}
CPerform.__index = CPerform
inherit(CPerform, pfobj.CPerform)

function CPerform:CalWarrior(oAction, oPerformMgr)
    local iPerform = self:Type()
    local func = function(oAttack, oVictim, oPerform, iHp)
        return AddExtCurePower(iPerform, oAttack, oVictim, oPerform, iHp)
    end
    oPerformMgr:AddFunction("AddExtCurePower", self.m_ID, func)
end

function AddExtCurePower(iPerform, oAttack, oVictim, oUsePerform, iHp)
    if not oVictim or oVictim:IsDead() then return 0 end

    local oPerform = oAttack:GetPerform(iPerform)
    if not oPerform then return 0 end

    if not oUsePerform or oUsePerform:Type() ~= 7802 then return 0 end

    local sExtArg = oPerform:ExtArg()
    local mEnv = oPerform:SkillFormulaEnv(oAction)
    local mExtArg = formula_string(sExtArg, mEnv)

    return iHp * mExtArg.ratio // 100
end

