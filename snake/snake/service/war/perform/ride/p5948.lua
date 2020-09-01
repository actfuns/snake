local global = require "global"
local skynet = require "skynet"
local pfobj = import(service_path("perform/pfobj"))
local gamedefines = import(lualib_path("public.gamedefines"))

function NewCPerform(...)
    local o = CPerform:New(...)
    return o
end

--击退

CPerform = {}
CPerform.__index = CPerform
inherit(CPerform, pfobj.CPerform)

function CPerform:CalWarrior(oAction, oPerformMgr)
    local iPerform = self:Type()
    local func = function(oAttack, oVictim, oPerform, iDamage, mArgs)
        OnAttack(iPerform, oAttack, oVictim, oPerform, iDamage, mArgs)
    end
    oPerformMgr:AddFunction("OnAttack", self.m_ID, func)
end

function OnAttack(iPerform, oAttack, oVictim, oUsePerform, iDamage, mArgs)
    if not oAttack or not oVictim then return end

    local oPerform = oAttack:GetPerform(iPerform)
    if not oPerform then return end
    
    local oWar = oAttack:GetWar()
    if not oWar then return end

    if oVictim:IsPlayerLike() or (oVictim:IsNpc() and oVictim:IsBoss()) then
        return
    end

    local sExtArg = oPerform:ExtArg()
    local mEnv = oPerform:SkillFormulaEnv(oAttack, oVictim)
    local mExtArg = formula_string(sExtArg, mEnv)

    if math.random(100) <= mExtArg.ratio and oVictim:GetGrade() <= mExtArg.grade_limit then
        oVictim:OnKickOut()
        oWar:KickOutWarrior(oVictim)
    end
end
