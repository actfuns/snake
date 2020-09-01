--import module

local global = require "global"
local skynet = require "skynet"

local gamedefines = import(lualib_path("public.gamedefines"))
local pfobj = import(service_path("perform/pfobj"))


function NewCPerform(...)
    local o = CPerform:New(...)
    return o
end

--命运之光

CPerform = {}
CPerform.__index = CPerform
inherit(CPerform, pfobj.CPerform)

function CPerform:PerformTarget(oAttack,oVictim)
    local mTarget = {}
    for _,oWarrior in pairs(oAttack:GetFriendList(true)) do
        if oWarrior:IsDead() and oWarrior:GetPerform(3014) then
            table.insert(mTarget,oWarrior.m_iWid)
        end
    end
    self:SetData("PerformTarget",mTarget)
    return mTarget
end

function CPerform:SkillFormulaEnv(oAttack,oVictim)
    local mRet = super(CPerform).SkillFormulaEnv(self, oAttack, oVictim)
    if oVictim then
        mRet.max_hp = oVictim:GetMaxHp()
    end
    return mRet
end
