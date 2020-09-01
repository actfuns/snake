--import module

local global = require "global"
local skynet = require "skynet"
local pfobj = import(service_path("perform/pfobj"))

function NewCPerform(...)
    local o = CPerform:New(...)
    return o
end

--重生之力

CPerform = {}
CPerform.__index = CPerform
inherit(CPerform, pfobj.CPerform)

function CPerform:CalWarrior(oAction, oPerformMgr)
    local iPerform = self:Type()
    local func = function(oAttack, oVictim, oPerform, iHp)
        return OnDoCureAction(iPerform, oAttack, oVictim, oPerform, iHp)
    end
    oPerformMgr:AddFunction("OnDoCureAction", self.m_ID, func)
end

function OnDoCureAction(iPerform, oAttack, oVictim, oUsePerform, iHp)
    if iHp <= 0 or not oUsePerform then return end
    
    if oUsePerform:Type() ~= 7803 then return end

    local oPerform = oAttack:GetPerform(iPerform)
    if not oPerform then return end

    local sExtArg = oPerform:ExtArg()
    local mExtArg = formula_string(sExtArg, {})
    local iRatio = mExtArg.ratio

    oVictim:SetBoutArgs("do_cure_wid", oAttack:GetWid())

    local func = function(oVictim, oAttack, oPerform, iDamage)
        OnImmuneDamage(iRatio, oVictim, oAttack, oPerform, iDamage)
    end
    oVictim:AddFunction("OnImmuneDamage", iPerform, func)
end

function OnImmuneDamage(iRatio, oVictim, oAttack, oPerform, iDamage)
    if iDamage <= 0 then return end

    local iProtect = oVictim:QueryBoutArgs("do_cure_wid")
    if not iProtect then return end

    local oWar = oVictim:GetWar()
    if not oWar then return end

    local oProtect = oWar:GetWarrior(iProtect)
    if not oProtect or oProtect:IsDead() then return end

    oVictim:AddBoutArgs("immune_damage_ratio", -iRatio)
    local iSubHp = math.floor(iDamage*iRatio/100)
    global.oActionMgr:DoSubHp(oProtect, iSubHp, oAttack, {hited_effect=1})
end
