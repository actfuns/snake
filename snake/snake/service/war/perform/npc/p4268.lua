--import module

local global = require "global"
local skynet = require "skynet"

local gamedefines = import(lualib_path("public.gamedefines"))
local pfobj = import(service_path("perform/pfobj"))


function NewCPerform(...)
    local o = CPerform:New(...)
    return o
end

--懦弱

CPerform = {}
CPerform.__index = CPerform
inherit(CPerform, pfobj.CPerform)

function CPerform:Perform(oAttack,lVictim)
    super(CPerform).Perform(self,oAttack,lVictim)
    local oWar  = oAttack:GetWar()
    local mCmd = {
        war_id = oAttack:GetWarId(),
        wid = oAttack:GetWid(),
        content = "懦弱的人是发挥不出自己的潜力的",
    }
    oWar:SendAll("GS2CWarriorSpeek", mCmd)
end

function CPerform:TruePerform(oAttack,oVictim,iRatio)
    self:Effect_Condition_For_Victim(oVictim,oAttack,{})
end

function CPerform:NeedVictimTime()
    return false
end
