--import module

local global = require "global"
local skynet = require "skynet"

local gamedefines = import(lualib_path("public.gamedefines"))
local pfobj = import(service_path("perform/pfobj"))

function NewCPerform(...)
    local o = CPerform:New(...)
    return o
end

CPerform = {}
CPerform.__index = CPerform
inherit(CPerform, pfobj.CPerform)

function CPerform:New(pfid)
    local o = super(CPerform).New(self,pfid)
    return o
end

function CPerform:CalWarrior(oAction, oPerformMgr)
    local iPerform = self:Type()
    local func = function(oAttack, oVictim, oPerform)
        return MaxRange(iPerform, oAttack, oVictim, oPerform)
    end
    oPerformMgr:AddFunction("MaxRange", self.m_ID, func)
end

function MaxRange(iPerform, oAttack, oVictim, oPerform)
    if oPerform:Type() ~= iPerform then return 0 end

    if oAttack:GetAura() < 3 then return 0 end

    if oAttack:IsPlayer() and oAttack:GetData("school") == gamedefines.PLAYER_SCHOOL.XINGXIU then
        return 1
    end
end

