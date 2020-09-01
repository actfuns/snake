--import module

local global = require "global"
local skynet = require "skynet"
local pfobj = import(service_path("perform/pfobj"))

function NewCPerform(...)
    local o = CPerform:New(...)
    return o
end

--慈悲为怀

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
    if not oUsePerform then return 0 end

    if oUsePerform:Type() ~= 7702 then return 0 end

    local oPerform = oAttack:GetPerform(iPerform)
    if not oPerform then return 0 end

    local sExtArg = oPerform:ExtArg()
    local mEnv = oPerform:SkillFormulaEnv(oAttack, oVictim)
    local mExtArg = formula_string(sExtArg, mEnv)

    return math.floor(iHp * mExtArg.ratio / 100)
end
