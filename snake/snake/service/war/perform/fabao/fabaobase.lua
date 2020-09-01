--import module

local global = require "global"
local skynet = require "skynet"
local pfobj = import(service_path("perform/pfobj"))

function NewCPerform(...)
    local o = CPerform:New(...)
    return o
end

CPerform = {}
CPerform.__index = CPerform
inherit(CPerform, pfobj.CPerform)

--AI检查能否使用招式
function CPerform:ValidCast(oAttack,oVictim)
    local iNeedZhenQi = self:GetZhenQi()
    local iCurZhenQi = oAttack:GetData("zhenqi",0)
    if iNeedZhenQi>0 and iCurZhenQi<iNeedZhenQi then
        oAttack:Notify("真气不足", 1<<2)
        return false
    end
    return super(CPerform).ValidCast(self,oAttack,oVictim)
end

function CPerform:GetZhenQi(oAttack,oVictim)
    local mInfo = self:GetPerformData()
    local sFormula = mInfo["zhengqi_formula"]
    if not sFormula or sFormula == "" then
        return 0
    end
    local mEnv = self:SkillFormulaEnv(oAttack,oVictim)
    local iResult = math.floor(formula_string(sFormula,mEnv))
    return iResult
end

function CPerform:TruePerform(oAttack, oVictim, iRatio)
    local iNeedZhenQi = self:GetZhenQi()
    local iCurZhenQi = oAttack:GetData("zhenqi",0)
    iCurZhenQi = math.max(0,iCurZhenQi-iNeedZhenQi)
    oAttack:SetData("zhenqi",iCurZhenQi)
    oAttack:StatusChange("zhenqi")
end

function CPerform:TriggerFaBaoEffect(oWarrior)
end
