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

function CPerform:DamageRatioEnv(oAttack,oVictim)
    local mEnv = super(CPerform).DamageRatioEnv(self, oAttack, oVictim)
    mEnv.victim_mp = oVictim and oVictim:GetMp() or 0
    mEnv.victim_max_mp = oVictim and oVictim:GetMaxMp() or 0
    return mEnv
end
