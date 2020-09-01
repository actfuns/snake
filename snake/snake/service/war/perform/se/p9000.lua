--import module

local global = require "global"
local skynet = require "skynet"
local res = require "base.res"
local pfobj = import(service_path("perform/se/sebase"))
local gamedefines = import(lualib_path("public.gamedefines"))

function NewCPerform(...)
    local o = CPerform:New(...)
    return o
end

--气疗术

CPerform = {}
CPerform.__index = CPerform
inherit(CPerform, pfobj.CPerform)

function CPerform:SkillFormulaEnv(oAttack,oVictim)
    local mEnv = super(CPerform).SkillFormulaEnv(self, oAttack, oVictim)
    mEnv.max_hp = oVictim:GetMaxHp()
    return mEnv
end

function CPerform:TruePerform(oAttack, oVictim, iRatio)
    if oVictim:IsDead() and oVictim:HasKey("revive_disable") then 
        return
    end
    if oVictim:IsAlive() and oVictim:HasKey("disable_cure") then
        return
    end

    local iHP = self:CalculateHp(oAttack,oVictim,iRatio)
    if iHP > 0 then
        global.oActionMgr:DoAddHp(oVictim, iHP)
    end
end

function CPerform:EndPerform(oAttack, lVictim)
    if oAttack and oAttack:IsAlive() then
        if oAttack:IsPlayer() and oAttack:GetData("school") == gamedefines.PLAYER_SCHOOL.JINSHAN then
            self:Effect_Condition_For_Attack(oAttack)
        else
            super(CPerform).EndPerform(self, oAttack, lVictim)
        end
    end
end
