--import module

local global = require "global"
local skynet = require "skynet"
local pfobj = import(service_path("perform/se/p9000"))

function NewCPerform(...)
    local o = CPerform:New(...)
    return o
end

--四海升平

CPerform = {}
CPerform.__index = CPerform
inherit(CPerform, pfobj.CPerform)

function CPerform:SkillFormulaEnv(oAttack, oVictim)
    local mEnv = super(CPerform).SkillFormulaEnv(self, oAttack, oVictim)
    mEnv.max_hp = oVictim:GetMaxHp()
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
        if oTarget:GetHp() >= oTarget:GetMaxHp() then
            goto continue
        end
        table.insert(lResult, oTarget)
        ::continue::
    end
    return lResult
end

