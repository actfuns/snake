--import module

local global = require "global"
local skynet = require "skynet"
local pfobj = import(service_path("perform/se/sebase"))

function NewCPerform(...)
    local o = CPerform:New(...)
    return o
end

--吸血

CPerform = {}
CPerform.__index = CPerform
inherit(CPerform, pfobj.CPerform)

function CPerform:SelfValidCast(oAttack, oVictim)
    if oVictim:IsNpc() and oVictim:IsBoss() then
        if oAttack and oAttack:IsPlayer() then
            oAttack:Notify("此技能对NPC无效")
        end
        return false
    end
    
    return super(CPerform).SelfValidCast(self, oAttack, oVictim)
end

function CPerform:SkillFormulaEnv(oAttack,oVictim)
    local mEnv = super(CPerform).SkillFormulaEnv(self, oAttack, oVictim)
    mEnv.hp = oVictim:GetHp()
    return mEnv
end

function CPerform:TruePerform(oAttack, oVictim, iRatio)
    local iHp = self:CalSkillFormula(oAttack, oVictim, 100)
    if iHp <= 0 then return end

    global.oActionMgr:DoSubHp(oVictim, iHp, oAttack)

    local sExtArg = self:ExtArg()
    local mEnv = {grade=oAttack:GetGrade()}
    local mExtArg = formula_string(sExtArg, mEnv)
    local iAddHp = math.min(iHp, mExtArg.limit)
    global.oActionMgr:DoAddHp(oAttack, iAddHp)
end
