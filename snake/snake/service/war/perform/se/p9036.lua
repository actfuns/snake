--import module

local global = require "global"
local skynet = require "skynet"
local pfobj = import(service_path("perform/se/sebase"))
local gamedefines = import(lualib_path("public.gamedefines"))

function NewCPerform(...)
    local o = CPerform:New(...)
    return o
end

--乾坤斩

CPerform = {}
CPerform.__index = CPerform
inherit(CPerform, pfobj.CPerform)

function CPerform:SkillFormulaEnv(oAttack, oVictim)
    local mEnv = super(CPerform).SkillFormulaEnv(self, oAttack, oVictim)
    mEnv.grade = oVictim:GetGrade()
    return mEnv
end

function CPerform:TruePerform(oAttack, oVictim, iRatio)
--    local bHit = global.oActionMgr:CalActionHit(oAttack, oVictim, self, 1)
--    if not bHit then
--        oAttack:SendAll("GS2CWarDamage", {
--            war_id = oVictim:GetWarId(),
--            wid = oVictim:GetWid(),
--            type = gamedefines.WAR_RECV_DAMAGE_FLAG.MISS,
--            damage = 0,
--        })
--        return
--    end

    local iHp = self:CalSkillFormula(oAttack, oVictim, 100)
    if iHp <= 0 then return end

    global.oActionMgr:DoSubHp(oVictim, iHp, oAttack)
end
