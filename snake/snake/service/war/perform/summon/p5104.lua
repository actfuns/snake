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

-- 暗杀
function CPerform:New(pfid)
    local o = super(CPerform).New(self, pfid)
    return o
end

function CPerform:CalWarrior(oAction, oPerformMgr)
    oAction:Set("sneak", 1)
    
    local iRatio = self:CalSkillFormula()
    local func = function (oAttack, oVictim, oPerform)
        return OnCalDamageResultRatio(oAttack, oVictim, oPerform, iRatio)
    end
    oAction:AddFunction("OnCalDamageResultRatio", self.m_ID, func)
end

function OnCalDamageResultRatio(oAttack, oVictim, oPerform, iRatio)
    if oPerform and oPerform:AttackType() == gamedefines.WAR_PERFORM_TYPE.MAGIC then return 0 end

    return iRatio
end
