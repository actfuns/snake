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
    local o = super(CPerform).New(self, pfid)
    return o
end

function CPerform:TurePerform(oAttack, oVictim, iDamageRatio)
    local iAttackCnt = self:GetData("PerformAttackCnt", 1)
    if iAttackCnt == 1 then
        super(CPerform).TurePerform(self, oAttack, oVictim, 100)
    else
        super(CPerform).TurePerform(self, oAttack, oVictim, iDamageRatio)    
    end
end