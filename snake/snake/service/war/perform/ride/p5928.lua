local global = require "global"
local skynet = require "skynet"
local pfobj = import(service_path("perform/pfobj"))

function NewCPerform(...)
    local o = CPerform:New(...)
    return o
end

--止痛药

CPerform = {}
CPerform.__index = CPerform
inherit(CPerform, pfobj.CPerform)

function CPerform:CalWarrior(oAction, oPerformMgr)
    local iPerform = self:Type()
    local func = function(oAction, oVictim, iWarItem, mArgs)
        DoActionEnd(iPerform, oAction, oVictim, iWarItem, mArgs)
    end
    oPerformMgr:AddFunction("DoActionEnd", self.m_ID, func)
end

function DoActionEnd(iPerform, oAction, oVictim, iWarItem, mArgs)
    local oPerform = oAction:GetPerform(iPerform)
    if not oPerform then return end

    if iWarItem ~= 1005 then return end

    local sExtArg = oPerform:ExtArg()
    local mEnv = oPerform:SkillFormulaEnv(oAction)
    local mExtArg = formula_string(sExtArg, mEnv)
   
    if math.random(100) <= mExtArg.ratio then
        oPerform:Effect_Condition_For_Victim(oVictim, oAction)
    end
end

