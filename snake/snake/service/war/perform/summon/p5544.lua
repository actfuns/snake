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

-- 流沙
function CPerform:New(pfid)
    local o = super(CPerform).New(self, pfid)
    return o
end

function CPerform:CalWarrior(oAction, oPerformMgr)
    local iType = self:Type()
    local func = function (oAttack, oVictim, oPerform, iDamage, mArgs)
        OnAttack(iType, oAttack, oVictim, oPerform, iDamage, mArgs)
    end
    oPerformMgr:AddFunction("OnAttack",self.m_ID, func)
end

function OnAttack(iPerform, oAttack, oVictim, oUsePerform, iDamage, mArgs)
    if not oAttack or not oVictim or oVictim:IsDead() then return end

    if not oUsePerform or oUsePerform:AttackType() ~= gamedefines.WAR_PERFORM_TYPE.MAGIC then
        return
    end

    local oPerform = oAttack:GetPerform(iPerform)
    if not oPerform then return end

    local iRatio = oPerform:CalSkillFormula()
    if math.random(100) > iRatio then return end

    local mEnv = {level=oPerform:Level()}
    local sExtArgs = oPerform:ExtArg()
    local mExtArgs = formula_string(sExtArgs, mEnv)
    local iBuff = mExtArgs["buff"]
    local iBout = mExtArgs["bout"]
    local oBuffMgr = oVictim.m_oBuffMgr
    oBuffMgr:AddBuff(iBuff, iBout, mEnv)
end

