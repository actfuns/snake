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
    self:Effect_Condition_For_Victim(oVictim,oAttack,{grade=oVictim:GetGrade()})

    local bRefresh = false
    for _,iPerform in pairs({4622,4623,4624,4625}) do
        local oPerform  = oAttack:GetPerform(iPerform)
        if oPerform then
            bRefresh = true
            oPerform:TriggerFaBaoEffect(oVictim)
        end
    end
    local oBuff = oVictim.m_oBuffMgr:HasBuff(237)
    if bRefresh and oBuff then 
        oBuff:Refresh(oVictim)
    end
end

