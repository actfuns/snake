--import module

local global = require "global"
local skynet = require "skynet"

local gamedefines = import(lualib_path("public.gamedefines"))
local pfobj = import(service_path("perform/summon/pfbase"))


function NewCPerform(...)
    local o = CPerform:New(...)
    return o
end

CPerform = {}
CPerform.__index = CPerform
inherit(CPerform, pfobj.CPerform)

-- 连击
function CPerform:New(pfid)
    local o = super(CPerform).New(self, pfid)
    return o
end

function CPerform:CalWarrior(oAction, oPerformMgr)
    local iRatio = self:CalSkillFormula()
    local iDamageRatio = self:CalDamageRatio()
    local func = function (oAttack, oVictim, oPerform, iDamage, mArgs)
        OnAttackDelay(oAttack, oVictim, oPerform, iDamage, mArgs, iRatio, iDamageRatio)
    end
    oPerformMgr:AddFunction("OnAttackDelay",self.m_ID, func)

    oAction:Add("phy_damage_addratio", -iDamageRatio)
end

function CPerform:CalDamageRatio(oAttack)
    local sExtArgs = self:ExtArg()
    return formula_string(sExtArgs, self:SkillFormulaEnv())
end

function OnAttackDelay(oAttack, oVictim, oPerform, iDamage, mArgs, iRatio, iDamageRatio)
    if not oVictim or oVictim:IsDead() then return end
    if not oAttack or oAttack:IsDead() then return end
    if oPerform then return end
    if mArgs and mArgs.bNotBack then return end

    if mArgs and mArgs.is_critical == 1 and oAttack:HasKey("p5939") then return end 
    
    if oAttack:QueryBoutArgs("p5509", 0) >= 1 then return end
    if oAttack:QueryBoutArgs("iChaseCnt", 0) >= 1 then return end
    if oAttack:QueryBoutArgs("iComboCnt", 0) >= 1 then return end

    if math.random(100) > iRatio then return end

    oAttack:GS2CTriggerPassiveSkill(5107)
    oAttack:AddBoutArgs("iComboCnt", 1)
    local oActionMgr = global.oActionMgr
    oActionMgr:WarNormalAttack(oAttack, oVictim, {perform_time=700})
    
    -- 连击后执行
    local mFunc = oAttack:GetFunction("OnComboAttack")
    for _,fCallback in pairs(mFunc) do
        safe_call(fCallback, oAttack, oVictim, oPerform)
    end
end


