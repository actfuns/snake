--import module

local global = require "global"
local skynet = require "skynet"
local pfobj = import(service_path("perform/fabao/fabaobase"))

function NewCPerform(...)
    local o = CPerform:New(...)
    return o
end

CPerform = {}
CPerform.__index = CPerform
inherit(CPerform, pfobj.CPerform)

function CPerform:BoutEnv(oAttack, oVictim)
    local mEnv = super(CPerform).BoutEnv(self,oAttack, oVictim)
    local oPerform = oAttack:GetPerform(4604)
    local iExtraBout = 0
    if oPerform then
        iExtraBout = 1
    end
    mEnv.extra = iExtraBout
    return mEnv
end

function CPerform:TruePerform(oAttack, oVictim, iRatio)
    super(CPerform).TruePerform(self,oAttack, oVictim, iRatio)
    local oPerform = oAttack:GetPerform(4602) 
    if oPerform then
        oPerform:TriggerFaBaoEffect(oAttack)
    end
end
