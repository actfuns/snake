--import module

local global = require "global"
local skynet = require "skynet"

local gamedefines = import(lualib_path("public.gamedefines"))
local pfobj = import(service_path("perform/summon/pfbase"))


function NewCPerform(...)
    local o = CPerform:New(...)
    return o
end

function OnKill(iPerform, oAttack, oVictim)
    if not oVictim then return end

    local oPerform = oAttack:GetPerform(iPerform)
    if not oPerform then return end

    if oAttack:QueryBoutArgs("killEnemy", 0) > 1 then
        return
    end
    local iHp = oPerform:CalHp(oAttack, oVictim)
    local oActionMgr = global.oActionMgr
    oActionMgr:DoAddHp(oAttack, iHp)
end


-- 肉食(天赋)
CPerform = {}
CPerform.__index = CPerform
inherit(CPerform, pfobj.CPerform)

function CPerform:New(pfid)
    local o = super(CPerform).New(self, pfid)
    return o
end

function CPerform:CalWarrior(oAction, oPerformMgr)
    local iPerform = self:Type()
    local func = function (oAttack, oVictim)
        return OnKill(iPerform, oAttack, oVictim)        
    end
    oAction:AddFunction("OnKill", self.m_ID, func)
end

function CPerform:CalHp(oAttack, oVictim)
    local iRatio = self:CalSkillFormula()
    local iHp = oAttack:GetMaxHp() * iRatio / 100
    return math.floor(iHp)
end
