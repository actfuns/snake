--import module

local global = require "global"
local skynet = require "skynet"
local pfobj = import(service_path("perform/se/sebase"))

function NewCPerform(...)
    local o = CPerform:New(...)
    return o
end

--凝神归元

CPerform = {}
CPerform.__index = CPerform
inherit(CPerform, pfobj.CPerform)

function CPerform:SkillFormulaEnv(oAttack, oVictim)
    local mEnv = super(CPerform).SkillFormulaEnv(self, oAttack, oVictim)
    mEnv.max_mp = oVictim:GetMaxMp()
    mEnv.grade = oVictim:GetGrade()
    return mEnv
end

function CPerform:TargetList(oAttack)
    local lTarget = oAttack:GetFriendList(true)
    local lResult = {}
    for _, oTarget in pairs(lTarget) do
        if oTarget:IsDead() then
            goto continue
        end
        if oTarget:GetMp() >= oTarget:GetMaxMp() then
            goto continue
        end
        table.insert(lResult, oTarget)
        ::continue::
    end
    return lResult
end

function CPerform:TruePerform(oAttack, oVictim, iRatio)
    if not oVictim or oVictim:IsDead() then return end

    local iAddMp = self:CalSkillFormula(oAttack, oVictim, 100)
    global.oActionMgr:DoAddMp(oVictim, iAddMp)
end
