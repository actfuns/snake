--import module

local global = require "global"
local skynet = require "skynet"
local pfobj = import(service_path("perform/se/sebase"))

function NewCPerform(...)
    local o = CPerform:New(...)
    return o
end

--残月

CPerform = {}
CPerform.__index = CPerform
inherit(CPerform, pfobj.CPerform)

function CPerform:SelfValidCast(oAttack, oVictim)
    if oVictim:IsNpcLike() then
        if oAttack and oAttack:IsPlayer() then
            oAttack:Notify("此技能对NPC无效")
        end
        return false
    end
    
    return super(CPerform).SelfValidCast(self, oAttack, oVictim)
end

function CPerform:SkillFormulaEnv(oAttack,oVictim)
    local mEnv = super(CPerform).SkillFormulaEnv(self, oAttack, oVictim)
    mEnv.mp = oVictim:GetMp()
    return mEnv
end

function CPerform:TruePerform(oAttack, oVictim, iRatio)
    local iMp = self:CalSkillFormula(oAttack, oVictim, 100)
    if iMp <= 0 then return end

    global.oActionMgr:DoAddMp(oVictim, -iMp)

    local sExtArg = self:ExtArg()
    local mEnv = {grade=oAttack:GetGrade()}
    local mExtArg = formula_string(sExtArg, mEnv)
    local iAddMp = math.min(iMp, mExtArg.limit)
    global.oActionMgr:DoAddMp(oAttack, iAddMp)
end
