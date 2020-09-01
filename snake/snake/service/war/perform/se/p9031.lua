--import module

local global = require "global"
local skynet = require "skynet"
local pfobj = import(service_path("perform/se/sebase"))

function NewCPerform(...)
    local o = CPerform:New(...)
    return o
end

--烽火连城

CPerform = {}
CPerform.__index = CPerform
inherit(CPerform, pfobj.CPerform)

function CPerform:Perform(oAttack, lVictim)
    if #lVictim <= 0 then return end

    local oVictim = lVictim[1]
    local oActionMgr = global.oActionMgr
    oActionMgr:PerformMagAttack(oAttack, oVictim, self, 100, 2)
    self:EndPerform(oAttack, lVictim)
end

function CPerform:DamageRatio(oAttack, oVictim)
    local mInfo = self:GetPerformData()
    local mDamageRatio = mInfo["damageRatio"]
    local iAttackCnt = self:GetData("PerformAttackCnt",0)
    local sFormula = "100"

    for idx, mData in ipairs(mDamageRatio) do
        if iAttackCnt < idx then
            sFormula = mData["ratio"]
            break
        end
    end

    local iRatio = tonumber(sFormula)
    if not iRatio then
        local mEnv = self:DamageRatioEnv(oAttack,oVictim)
        iRatio = formula_string(sFormula, mEnv) 
    end
    return iRatio
end

