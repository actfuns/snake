--import module

local global = require "global"
local skynet = require "skynet"
local pfobj = import(service_path("perform/se/sebase"))

function NewCPerform(...)
    local o = CPerform:New(...)
    return o
end

--指挥

CPerform = {}
CPerform.__index = CPerform
inherit(CPerform, pfobj.CPerform)

function CPerform:CalWarrior(oAction, oPerformMgr)
    local iPerform = self:Type()
    local func = function(oAction, oSummon)
        OnAddSummon(iPerform, oAction, oSummon)
    end
    oPerformMgr:AddFunction("OnAddSummon", self.m_ID, func)
end

function CPerform:BoutEnv(oAttack, oVictim)
    local mEnv = super(CPerform).BoutEnv(self, oAttack, oVictim)
    local oWar = oAttack:GetWar()
    mEnv.cur_bout = oWar and oWar:CurBout() or 0
    return mEnv
end

function OnAddSummon(iPerform, oAction, oSummon)
    local oPerform = oAction:GetPerform(iPerform)
    if not oPerform then return end

    local oWar = oAction:GetWar()
    if not oWar then return end

    if oSummon:HasKey("ghost") then return end

    local sExtArg = oPerform:ExtArg()
    local mEnv = oPerform:SkillFormulaEnv(oAction)
    local mExtArg = formula_string(sExtArg, mEnv)
    local iCurBout = oWar:CurBout()
    if iCurBout >= mExtArg.bout_limit then return end

    oPerform:Effect_Condition_For_Victim(oSummon, oAction)
end

