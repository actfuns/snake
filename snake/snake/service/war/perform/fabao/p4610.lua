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

function CPerform:TriggerFaBaoEffect(oWarrior)
    if not oWarrior or oWarrior:IsDead() then 
        return 
    end
    local oWar  = oWarrior:GetWar()
    if not oWar then 
        return 
    end
    self:Effect_Condition_For_Attack(oWarrior)
end