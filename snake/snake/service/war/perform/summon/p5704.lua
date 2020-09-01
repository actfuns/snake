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

-- 好战
function CPerform:New(pfid)
    local o = super(CPerform).New(self,pfid)
    return o
end

function CPerform:CalWarrior(oAction, oPerformMgr)
    local iPerform = self:Type()
    local func1 = function (o)
        OnEnterWar(iPerform, o)
    end

    local func2 = function (o)
        OnBoutEnd(iPerform, o)
    end

    oPerformMgr:AddFunction("OnWarStart",self.m_ID, func1)
    oPerformMgr:AddFunction("OnEnterWar",self.m_ID, func1)
    oPerformMgr:AddFunction("OnBoutEnd",self.m_ID, func2)
end

function OnEnterWar(iPerform, oAction)
    local oPerform = oAction:GetPerform(iPerform)
    if not oPerform then return end

    local oWar = oAction:GetWar()
    local mEnv = {level=oPerform:Level()}
    local mExtArgs = formula_string(oPerform:ExtArg(), mEnv)
    local iRatio = mExtArgs["hp_percent"]
    local iBout = mExtArgs["bout"]
    local iHp = math.floor(oAction:GetMaxHp() * iRatio / 100)
    if iHp <= 0 then return end

    oAction:GS2CTriggerPassiveSkill(iPerform)
    oAction.m_oStatusBuffMgr:AddStatus(iPerform, {})
    oAction:Set("p5704_bout", iBout + oWar:CurBout() - 1)
    oAction:Set("p5704_hp", iHp)
    oAction:SetData("max_hp", iHp + oAction:GetMaxHp())
    oAction:SetData("hp", iHp + oAction:GetHp())
    oAction:StatusChange("hp", "max_hp") 
end

function OnBoutEnd(iPerform, oAction)
    local oPerform = oAction:GetPerform(iPerform)
    if not oPerform then return end

    local iBout = oAction:Query("p5704_bout", 0)
    if iBout <= 0 then return end

    local oWar = oAction:GetWar()
    if oWar:CurBout() < iBout then return end

    oAction:GS2CTriggerPassiveSkill(iPerform)
    oAction.m_oStatusBuffMgr:RemoveStatus(iPerform)
    local iHp = oAction:Query("p5704_hp", 0)
    oAction:Set("p5704_hp", nil)
    oAction:Set("p5704_bout", nil)
    oAction:SetData("max_hp", oAction:GetMaxHp()-iHp)
    oAction:SubHp(iHp)
    oAction:StatusChange("max_hp")
end

