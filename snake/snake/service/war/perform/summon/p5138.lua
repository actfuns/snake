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

-- 勇敢
function CPerform:New(pfid)
    local o = super(CPerform).New(self, pfid)
    return o
end

function CPerform:CalWarrior(oAction, oPerformMgr)
    local iType = self:Type()
    local func = function (oAttack, oVictim, oPerform)
        return OnCalDamagedResultRatio(iType, oAttack, oVictim, oPerform)
    end

    oAction:Set("not_auto_escape", true)
    oPerformMgr:AddFunction("OnCalDamagedResultRatio",self.m_ID, func)
end

function OnCalDamagedResultRatio(iPerform, oAttack, oVictim, oUsePerform)
    if not oAttack or not oVictim or oVictim:IsDead() then return 0 end

    if not oAttack.m_oBuffMgr:HasBuff(227) and not oAttack.m_oBuffMgr:HasBuff(228) then
        return 0
    end

    local oPerform = oVictim:GetPerform(iPerform)
    if not oPerform then return end

    local iRatio = oPerform:CalSkillFormula()
    return -iRatio
end

