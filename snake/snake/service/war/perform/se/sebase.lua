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
    o.m_bNoDisable = true
    return o
end

function CPerform:IsSE()
    return true
end

function CPerform:SelfValidCast(oAttack, oVictim)
    local lBuffList = {117, 147}
    for _, iBuff in ipairs(lBuffList) do
        if oAttack.m_oBuffMgr:HasBuff(iBuff) then
            return false
        end
    end
    return super(CPerform).SelfValidCast(self, oAttack, oVictim)
end
