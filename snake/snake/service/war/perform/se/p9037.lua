--import module

local global = require "global"
local skynet = require "skynet"
local pfobj = import(service_path("perform/se/sebase"))

function NewCPerform(...)
    local o = CPerform:New(...)
    return o
end

--破碎无双

CPerform = {}
CPerform.__index = CPerform
inherit(CPerform, pfobj.CPerform)

function CPerform:CalWarrior(oWarrior, oPerformMgr)
    local iPerform = self:Type()
    local func = function(oAttack, oVictim, oPerform, iDamage, mArgs)
        OnAttack(iPerform, oAttack, oVictim, oPerform, iDamage, mArgs)
    end
    oPerformMgr:AddFunction("OnAttack", self.m_ID, func)
end

function CPerform:TruePerform(oAttack, oVictim, iRatio)
    local mArgs = {perform=self:Type(), ignore=true, perform_time=700}
    global.oActionMgr:DoNormalAttack(oAttack, oVictim, mArgs)
end

function OnAttack(iPerform, oAttack, oVictim, oUsePerform, iDamage, mArgs)
    if not oAttack or oAttack:IsDead() then return end
    if not oVictim or oVictim:IsDead() then return end
    if oUsePerform then return end
    if mArgs.perform ~= iPerform then return end
    if iDamage <= 0 then return end

    local oPerform = oAttack:GetPerform(iPerform)
    if not oPerform then return end

    local sExtArg = oPerform:ExtArg()
    local mEnv = {hp=iDamage}
    local mExtArg = formula_string(sExtArg, mEnv)
    local iSubMp = mExtArg.sub_mp
    if iSubMp <= 0 then return end

    oVictim:SubMp(iSubMp)
end
