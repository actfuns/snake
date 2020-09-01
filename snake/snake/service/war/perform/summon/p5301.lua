--import module

local global = require "global"
local skynet = require "skynet"

local gamedefines = import(lualib_path("public.gamedefines"))
local pfobj = import(service_path("perform/summon/pfactive"))


function NewCPerform(...)
    local o = CPerform:New(...)
    return o
end


CPerform = {}
CPerform.__index = CPerform
inherit(CPerform, pfobj.CPerform)

function CPerform:New(pfid)
    local o = super(CPerform).New(self,pfid)
    return o
end

function CPerform:CalWarrior(oAction, oPerformMgr)
    local iRatio = self:CalSubHpRatio()
    local func = function (oAttack, oVictim, oPerform, iDamage, mArgs)
        OnAttack(oAttack, oVictim, oPerform, iDamage, mArgs, iRatio)
    end
    oPerformMgr:AddFunction("OnAttack",self.m_ID, func)
end

function CPerform:SelfValidCast(oAttack, oVictim)
    if oAttack:GetHp() < oAttack:GetMaxHp() * 0.3 then
        if oAttack:IsSummon() then
            oAttack:Notify("宠物气血不足30%，无法释放背水一战")
        end
        return false
    end
    return true
end

function CPerform:TruePerform(oAttack, oVictim, iDamageRatio)
    oAttack:Add("damage_addratio", self:CalSkillFormula(oAttack, oVictim, 100))
    super(CPerform).TruePerform(self, oAttack, oVictim, iDamageRatio)
    oAttack:Add("damage_addratio", -self:CalSkillFormula(oAttack, oVictim, 100))
end

function CPerform:CalSubHpRatio()
    local sExtArgs = self:ExtArg()
    return formula_string(sExtArgs, self:SkillFormulaEnv())
end

function OnAttack(oAttack, oVictim, oPerform, iDamage, mArgs, iRatio)
    if not oPerform or oPerform:Type() ~= 5301 then return end

    if iDamage <= 0 then  return end
    local iHp = math.floor(iDamage * iRatio / 100)

    local oActionMgr = global.oActionMgr
    oActionMgr:DoSubHp(oAttack, iHp, oVictim)
end

