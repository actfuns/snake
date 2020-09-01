--import module

local global = require "global"
local skynet = require "skynet"

local gamedefines = import(lualib_path("public.gamedefines"))
local pfobj = import(service_path("perform/summon/pfbase"))


function NewCPerform(...)
    local o = CPerform:New(...)
    return o
end

function OnAttack(iPerform, oAttack, oVictim, oUsePerform, iDamage)
    if not oAttack or not oVictim then return end

    if oUsePerform then return end

    local oPerform = oAttack:GetPerform(iPerform)
    if not oPerform then return end
    
    oPerform:DoPerformAction(oAttack, iDamage)    
end

function OnEndPerform(iPerform, oAttack, oUsePerform, lVictim)
    if not oAttack or not oUsePerform then return end

    local oPerform = oAttack:GetPerform(iPerform)
    if not oPerform then return end

    local iDamage = oUsePerform:GetTempData("total_damage", 0)
    oPerform:DoPerformAction(oAttack, iDamage)
end

-- 报恩(天赋)
CPerform = {}
CPerform.__index = CPerform
inherit(CPerform, pfobj.CPerform)

function CPerform:New(pfid)
    local o = super(CPerform).New(self, pfid)
    return o
end

function CPerform:CalWarrior(oAction, oPerformMgr)
    local iPerform = self:Type()
    local func = function (oAttack, oVictim, oUsePerform, iDamage)
        return OnAttack(iPerform, oAttack, oVictim, oUsePerform, iDamage)        
    end
    oAction:AddFunction("OnAttack", self.m_ID, func)

    local func2 = function (oAttack, oUsePerform, lVictim)
        return OnEndPerform(iPerform, oAttack, oUsePerform, lVictim)        
    end
    oAction:AddFunction("OnEndPerform", self.m_ID, func2)
end

function CPerform:DoPerformAction(oAttack, iDamage)
    local iRatio = self:CalSkillFormula()
    if math.random(100) > iRatio then return end

    local oWar = oAttack:GetWar()
    local oPlayer = oWar:GetWarrior(oAttack:GetData("owner"))
    if not oPlayer or oPlayer:IsDead() then return end

    local sExtArgs = self:ExtArg()
    local iHpRatio = formula_string(sExtArgs, self:SkillFormulaEnv())
    local iHp = math.floor(iDamage * iHpRatio / 100)
    if iHp <= 0 then return end

    local oActionMgr = global.oActionMgr
    oActionMgr:DoAddHp(oPlayer, iHp)
end