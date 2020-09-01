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

function CPerform:TruePerform(oAttack, oVictim, iRatio)
    super(CPerform).TruePerform(self,oAttack, oVictim, iRatio)
    self:Effect_Condition_For_Victim(oVictim,oAttack,{})

    for _,iPerform in pairs({4612, 4613, 4615}) do
        local oPerform = oAttack:GetPerform(iPerform) 
        if oPerform then
            oPerform:TriggerFaBaoEffect(oVictim)
        end
    end
end

function CPerform:BoutEnv(oAttack, oVictim)
    local mEnv = super(CPerform).BoutEnv(self,oAttack, oVictim)
    local oPerform = oAttack:GetPerform(4614)
    local iExtraBout = 0
    if oPerform then
        iExtraBout = 1
    end
    mEnv.extra = iExtraBout
    return mEnv
end