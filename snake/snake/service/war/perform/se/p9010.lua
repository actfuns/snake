--import module

local global = require "global"
local skynet = require "skynet"
local pfobj = import(service_path("perform/se/p9000"))

function NewCPerform(...)
    local o = CPerform:New(...)
    return o
end

--起死回生

CPerform = {}
CPerform.__index = CPerform
inherit(CPerform, pfobj.CPerform)

function CPerform:SkillFormulaEnv(oAttack, oVictim)
    local mEnv = super(CPerform).SkillFormulaEnv(self, oAttack, oVictim)
    mEnv.max_hp = oVictim:GetMaxHp()
    return mEnv
end

function CPerform:SelfValidCast(oAttack,oVictim)
    local oWar = oAttack:GetWar()
    if not oWar then return end

    if oVictim and oVictim:IsDead() then
        return true
    end
    oAttack:Notify(string.format("无法使用%s", self:Name()))
    return false
end
