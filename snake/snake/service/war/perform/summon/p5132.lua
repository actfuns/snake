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
    local iPerform = self:Type()
    local func = function (o)
        OnEnterWar(iPerform, o)
    end
    oPerformMgr:AddFunction("OnWarStart",self.m_ID, func)
    oPerformMgr:AddFunction("OnEnterWar",self.m_ID, func)

    local func2 = function(oAttack, oVictim, oPerform)
        return OnCalDamageResultRatio(oAttack, oVictim, oPerform, iPerform)
    end
    oPerformMgr:AddFunction("OnCalDamageResultRatio", self.m_ID, func2)
end

function CPerform:GetBoutNum()
    local iBout = 2
    if self:Level() < 4 then
        iBout = math.random(2, 3)
    else
        iBout = math.random(3, 5)
    end
    return iBout
end

function OnEnterWar(iPerform, oAction)
    local oPerform = oAction:GetPerform(iPerform)
    if not oPerform then return end

    local oBuffMgr = oAction.m_oBuffMgr
    oBuffMgr:AddBuff(130, oPerform:GetBoutNum(), {})
end


function OnCalDamageResultRatio(oAttack, oVictim, oUsePerform, iPerform)
    local oPerform = oAttack:GetPerform(iPerform)
    if not oPerform then return end

    local iRatio = oPerform:CalSkillFormula()
    return -iRatio
end
