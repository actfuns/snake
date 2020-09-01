--import module

local global = require "global"
local skynet = require "skynet"

local gamedefines = import(lualib_path("public.gamedefines"))
local pfobj = import(service_path("perform/summon/pfbase"))


function NewCPerform(...)
    local o = CPerform:New(...)
    return o
end

function OnComboAttack(iPerform, oAttack, oVictim, oUsePerform)
    if not oAttack then return end

    local oPerform = oAttack:GetPerform(iPerform)
    if not oPerform then return end

    local iRatio = oPerform:CalSkillFormula()
    if math.random(100) > iRatio then return end

    local lEnemyList = oAttack:GetEnemyList()
    if #lEnemyList <= 0 then return end

    local iRan = math.random(#lEnemyList)
    local oTarget = lEnemyList[iRan]
    if oVictim and oTarget:GetWid() == oVictim:GetWid() then
        oTarget = nil
        for _, o in pairs(lEnemyList) do
            if o:GetWid() ~= oVictim:GetWid() then
                oTarget = o
                break
            end
        end
    end

    if not oTarget then return end

    local sExtArgs = oPerform:ExtArg()
    local iDamageRatio = formula_string(sExtArgs, oPerform:SkillFormulaEnv()) - 100
    local oActionMgr = global.oActionMgr
    oActionMgr:WarNormalAttack(oAttack, oTarget, {damage_addratio=iDamageRatio,perform_time=700})
end


-- 连击强化(天赋) 连击(5107)
CPerform = {}
CPerform.__index = CPerform
inherit(CPerform, pfobj.CPerform)

function CPerform:New(pfid)
    local o = super(CPerform).New(self, pfid)
    return o
end

function CPerform:CalWarrior(oAction, oPerformMgr)
    local iPerform = self:Type()
    local func = function (oAttack, oVictim, oUsePerform)
        OnComboAttack(iPerform, oAttack, oVictim, oUsePerform)        
    end
    oAction:AddFunction("OnComboAttack", self.m_ID, func)
end

