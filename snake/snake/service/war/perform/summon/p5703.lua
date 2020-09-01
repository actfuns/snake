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

-- 狂暴
function CPerform:New(pfid)
    local o = super(CPerform).New(self,pfid)
    return o
end

function CPerform:CalWarrior(oAction, oPerformMgr)
    local iType = self:Type()
    local func1 = function (oAttack, oVictim, oPerform, iDamage, mArgs)
        OnAttack(iType, oAttack, oVictim, oPerform, iDamage, mArgs)
    end

    local func2 = function (oAttack, oVictim)
        OnKill(iType, oAttack, oVictim)
    end

    oPerformMgr:AddFunction("OnAttack",self.m_ID, func1)
end

function OnAttack(iPerform, oAttack, oVictim, oUsePerform, iDamage, mArgs)
    if not oVictim then return end

    if oVictim:IsDead() then
        if oAttack:Query("p5703", 0) <= 0 then
            oAttack:Set("p5703", 1)
            oAttack:GS2CTriggerPassiveSkill(iPerform) 
        end
        return 
    end
    local oPerform = oAttack:GetPerform(iPerform)
    if not oPerform then return end

    if oUsePerform and oUsePerform:AttackType() ~= gamedefines.WAR_PERFORM_TYPE.PHY then
        return
    end

    if oUsePerform and oUsePerform:IsGroupPerform() then return end
        
    if oAttack:Query("p5703", 0) <= 0 then return end

    oAttack:GS2CTriggerPassiveSkill(iPerform)
    oAttack:Set("p5703", 0) 
    local mEnv = {level=oPerform:Level()}
    local sExtArgs = oPerform:ExtArg()
    local mExtArgs = formula_string(sExtArgs, mEnv)
    local iBuff = mExtArgs["buff"]
    local iBout = mExtArgs["bout"]
    local oBuffMgr = oVictim.m_oBuffMgr
    oBuffMgr:AddBuff(iBuff, iBout, mEnv)
end


