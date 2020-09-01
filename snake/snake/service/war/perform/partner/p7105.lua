--import module

local global = require "global"
local skynet = require "skynet"
local pfobj = import(service_path("perform/pfobj"))
local gamedefines = import(lualib_path("public.gamedefines"))

function NewCPerform(...)
    local o = CPerform:New(...)
    return o
end

--法力冰封

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
    if not oVictim or oVictim:IsDead() then return end

    if not iDamage or iDamage <= 0 then return end

    local oPerform = oAttack:GetPerform(iPerform)

    if not oPerform or not oUsePerform  then return end

    if not oUsePerform:IsGroupPerform() then return end

    if oUsePerform:AttackType() ~= gamedefines.WAR_PERFORM_TYPE.MAGIC then
        return  
    end

    local mEnv = {
        level = oPerform:Level(),
    }
    local sExtArgs = oPerform:ExtArg()
    local mArgs = formula_string(sExtArgs, mEnv)
    local iSubMp = math.min(mArgs.mp_sub, oVictim:GetMp()) 

    global.oActionMgr:DoAddMp(oVictim, -iSubMp)
end

