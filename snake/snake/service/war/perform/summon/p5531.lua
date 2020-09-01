--import module

local global = require "global"
local skynet = require "skynet"

local gamedefines = import(lualib_path("public.gamedefines"))
local pfobj = import(service_path("perform/summon/pfbase"))


function NewCPerform(...)
    local o = CPerform:New(...)
    return o
end

function OnImmuneDamage(iPerform, oVictim, oAttack, oUsePerform, iDamage)
    if not oAttack or not oVictim then return end

    local oPerform = oVictim:GetPerform(iPerform)
    if not oPerform then return end

    local iRatio = oPerform:CalSkillFormula()
    if math.random(100) > iRatio then return end

    local lEnemy = oVictim:GetEnemyList()
    if #lEnemy <= 0 then return end

    local sExtArgs = oPerform:ExtArg()
    local mArgs = formula_string(sExtArgs, oPerform:SkillFormulaEnv())

    local iHp = math.floor(iDamage * mArgs["res_damage"] / 100)
    local oEnemy = lEnemy[math.random(#lEnemy)]
    local oActionMgr = global.oActionMgr
    oActionMgr:DoSubHp(oEnemy, iHp, oVictim, {hited_effect=1})
    oVictim:AddBoutArgs("immune_damage_ratio", mArgs["rec_damage"] - 100)
end

-- 反伤(天赋)
CPerform = {}
CPerform.__index = CPerform
inherit(CPerform, pfobj.CPerform)

function CPerform:New(pfid)
    local o = super(CPerform).New(self, pfid)
    return o
end

function CPerform:CalWarrior(oAction, oPerformMgr)
    local iPerform = self:Type()
    local func = function (oVictim, oAttack, oUsePerform, iDamage)
        return OnImmuneDamage(iPerform, oVictim, oAttack, oUsePerform, iDamage)        
    end
    oAction:AddFunction("OnImmuneDamage", self.m_ID, func)
end

