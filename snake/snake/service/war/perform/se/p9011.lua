--import module

local global = require "global"
local skynet = require "skynet"
local pfobj = import(service_path("perform/se/p9000"))

function NewCPerform(...)
    local o = CPerform:New(...)
    return o
end

--慈航普渡

CPerform = {}
CPerform.__index = CPerform
inherit(CPerform, pfobj.CPerform)

function CPerform:SkillFormulaEnv(oAttack, oVictim)
    local mEnv = super(CPerform).SkillFormulaEnv(self, oAttack, oVictim)
    mEnv.max_hp = oVictim:GetMaxHp()
    return mEnv
end

function CPerform:ValidCast(oAttack,oVictim)
    return oVictim
end

function CPerform:EndPerform(oAttack, lVictim)
    super(CPerform).EndPerform(self, oAttack, lVictim)

    oAttack:SetData("mp", 1)
    oAttack:StatusChange("mp")

    local iHp = oAttack:GetHp()
    local iSubHp = iHp - math.floor(iHp * 0.1)
    if iSubHp then
        oAttack:SubHp(iSubHp, nil, false)
    end

    local iMaxHp = oAttack:GetMaxHp()
    local iCurMaxHp = math.max(1, math.floor(iMaxHp * 0.1))
    oAttack:SetData("max_hp", iCurMaxHp)
    oAttack:StatusChange("max_hp")
end
