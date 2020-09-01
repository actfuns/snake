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

function CPerform:New(pfid)
    local o = super(CPerform).New(self, pfid)
    return o
end

function CPerform:CalWarrior(oAction, oPerformMgr)
    oAction:Set("curr_dead_num", oAction:GetCampDeadNum())
    local iRatio = self:CalSkillFormula()
    local func = function (oAttack, oVictim, oPerform)
        return CalPhyAttack(oAttack, oVictim, oPerform, iRatio)
    end
    oAction:AddFunction("CalPhyAttack", self.m_ID, func)
end

function CalPhyAttack(oAttack, oVictim, oPerform, iRatio)
    local iDeadNum = math.max(0, oAttack:GetCampDeadNum() - oAttack:Query("curr_dead_num", 0), 0)
    if iDeadNum > 0 then
        oAttack:GS2CTriggerPassiveSkill(5134)
    end
    return math.max(0, math.floor(oAttack:QueryAttr("phy_attack") * iRatio / 100 * math.min(5, iDeadNum)))
end
