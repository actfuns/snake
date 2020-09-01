--import module

local global = require "global"
local skynet = require "skynet"
local res = require "base.res"
local pfobj = import(service_path("perform/pfobj"))
local gamedefines = import(lualib_path("public.gamedefines"))

function NewCPerform(...)
    local o = CPerform:New(...)
    return o
end

--速度光环

CPerform = {}
CPerform.__index = CPerform
inherit(CPerform, pfobj.CPerform)

function CPerform:CalWarrior(oAction, oPerformMgr)
    local sExtArg = self:ExtArg()
    local mEnv = self:SkillFormulaEnv(oAction)
    local mExtArg = formula_string(sExtArg, mEnv)

    local oWar = oAction:GetWar()
    if not oWar then return end

    local oCamp = oWar:GetCampObj(oAction:GetCampId())
    if oCamp then
        oCamp.m_iSpeedRatio = (oCamp.m_iSpeedRatio or 0) + mExtArg.speed_ratio
        oAction:Add("leader_speed_ratio", mExtArg.speed_ratio)
    end

    local iPerform = self:Type()
    local func = function(oAction)
        OnLeave(iPerform, oAction)
    end
    oPerformMgr:AddFunction("OnLeave", iPerform, func)
end

function OnLeave(iPerform, oAction)
    local oPerform = oAction:GetPerform(iPerform)
    if not oPerform then return end

    local oWar = oAction:GetWar()
    if not oWar then return end

    local oCamp = oWar:GetCampObj(oAction:GetCampId())
    local iSpeedRatio = oAction:Query("leader_speed_ratio")
    if iSpeedRatio then
        oAction:Add("leader_speed_ratio", -iSpeedRatio)
        if oCamp and oCamp.m_iSpeedRatio then
            oCamp.m_iSpeedRatio = oCamp.m_iSpeedRatio - iSpeedRatio
        end
    end
end

