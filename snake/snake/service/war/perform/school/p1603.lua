local global = require "global"
local skynet = require "skynet"

local gamedefines = import(lualib_path("public.gamedefines"))
local pfobj = import(service_path("perform/pfobj"))

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

--function CPerform:SelfValidCast(oAttack,oVictim)
--    if oAttack:GetHp() < oAttack:GetMaxHp() * 7 / 10 then
--        if oAttack:IsPlayer() then
--            oAttack:Notify("生命值过低，无法使用")
--        end
--        return false
--    end
--    return true
--end

function CPerform:CalWarrior(oWarrior, oPerformMgr)
    local iPerform = self:Type()
    local func = function(oAttack, oVictim, oPerform, iDamage, mArgs)
        OnAttack(iPerform, oAttack, oVictim, oPerform, iDamage, mArgs)
    end
    oPerformMgr:AddFunction("OnAttack", self.m_ID, func)
end

function OnAttack(iPerform, oAttack, oVictim, oPerform, iDamage, mArgs)
    if not oPerform or oPerform:Type() ~= iPerform then return end

    local iPos = oVictim:GetPos()
    local iNextPos = nil
    if iPos >=6 and iPos <= 10 then
        iNextPos = iPos - 5
    elseif iPos >=1 and iPos <= 3 then
        iNextPos = iPos + 10
    elseif iPos == 11 then
        iNextPos = iPos + 3
    end

    if not iNextPos then return end

    local oWar = oAttack:GetWar()
    if not oWar then return end

    local oWarrior = oWar:GetWarriorByPos(oVictim:GetCampId(), iNextPos)
    if not oWarrior then return end

    local sExtArg = oPerform:ExtArg()
    local mEnv = oPerform:SkillFormulaEnv(oAttack, oVictim)
    local mExtArg = formula_string(sExtArg, mEnv)
    local iSubHp = mExtArg.ratio * iDamage // 100

    if iSubHp > 0 then
        global.oActionMgr:DoSubHp(oWarrior, iSubHp, oAttack, {hited_effect=1})
    end
end

function CPerform:NeedBackTime()
    return false
end
