--import module

local global = require "global"
local skynet = require "skynet"

local gamedefines = import(lualib_path("public.gamedefines"))
local pfobj = import(service_path("perform/summon/pfbase"))

function NewCPerform(...)
    local o = CPerform:New(...)
    return o
end

CPerform = {}
CPerform.__index = CPerform
inherit(CPerform, pfobj.CPerform)

-- 石化
function CPerform:New(pfid)
    local o = super(CPerform).New(self,pfid)
    return o
end

function CPerform:CalWarrior(oAction, oPerformMgr)
    local iType = self:Type()
    local func1 = function(oVictim, oAttack, oPerform, iDamage, mArgs)
        OnAttacked(iType, oVictim, oAttack, oPerform, iDamage, mArgs)
    end

    local func2 = function(oAct)
        OnBoutStart(iType, oAct)
    end

    oPerformMgr:AddFunction("OnAttacked", self.m_ID, func1)
    oPerformMgr:AddFunction("OnBoutStart", self.m_ID, func2)
end

function CPerform:GetExtArgs()
    local mEnv = {level=self:Level()}
    local mExtArgs = formula_string(self:ExtArg(), mEnv)
    return mExtArgs
end

function OnAttacked(iPerform, oVictim, oAttack, oUsePerform, iDamage, mArgs)
    if not oVictim and oVictim:IsDead() then return end

    local oPerform = oVictim:GetPerform(iPerform)
    if not oPerform then return end

    if oVictim:Query("p5705_damaged", 0) > 0 then return end

    local mExtArgs = oPerform:GetExtArgs()
    local iCnt = mExtArgs["damage_cnt"]
    if not iCnt then return end

    if oUsePerform and oUsePerform:AttackType() == gamedefines.WAR_PERFORM_TYPE.MAGIC then
        oVictim:AddBoutArgs("p5705_mag", 1)
        if oVictim:QueryBoutArgs("p5705_mag") >= iCnt then
            oVictim:GS2CTriggerPassiveSkill(iPerform)
            oVictim:Set("p5705_damaged", 1)
        end
    else
        oVictim:AddBoutArgs("p5705_phy", 1)
        if oVictim:QueryBoutArgs("p5705_phy") >= iCnt then
            oVictim:GS2CTriggerPassiveSkill(iPerform)
            oVictim:Set("p5705_damaged", 1)
        end
    end
end

function OnBoutStart(iPerform, oAction)
    if not oAction or oAction:IsDead() then return end

    local oPerform = oAction:GetPerform(iPerform)
    if not oPerform then return end

    if oAction:Query("p5705_damaged", 0) > 0 then
        oAction:Set("p5705_damaged", nil)
        local mExtArgs = oPerform:GetExtArgs()
        local iRatio = mExtArgs["damaged_ratio"]
        oAction:AddBoutArgs("damaged_ratio", iRatio)
    end
end


