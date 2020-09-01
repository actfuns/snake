--import module

local global = require "global"
local skynet = require "skynet"
local pfobj = import(service_path("perform/pfobj"))

function NewCPerform(...)
    local o = CPerform:New(...)
    return o
end

--珍宝密藏

CPerform = {}
CPerform.__index = CPerform
inherit(CPerform, pfobj.CPerform)

function CPerform:CalWarrior(oAction, oPerformMgr)
    local iPerform = self:Type()
    local func = function(oVictim, oAttack, oPerform, iDamage)
        OnImmuneDamage(iPerform, oVictim, oAttack, oPerform, iDamage)
    end
    oPerformMgr:AddFunction("OnImmuneDamage", self.m_ID, func)
end

function OnImmuneDamage(iPerform, oVictim, oAttack, oUsePerform, iDamage)
    if not oVictim or oVictim:IsDead() then return end
    if iDamage <= 0 then return end

    local oPerform = oAttack:GetPerform(iPerform)
    if not oPerform then return end

    local sExtArg = oPerform:ExtArg()
    local mEnv = {level=oPerform:Level()}
    local mExtArg = formula_string(sExtArg, mEnv)
    local iRandom = math.random(100)

    if iRandom <= mExtArg.ratio_add_hp then
        oVictim:SetBoutArgs("immune_damage", 1)
        global.oActionMgr:DoAddHp(oVictim, iDamage)
    elseif iRandom <= mExtArg.ratio_double_damage then
        oVictim:AddBoutArgs("immune_damage_ratio", 100)
    end
end

