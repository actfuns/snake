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

-- 嘲讽
function CPerform:TruePerform(oAttack, oVictim, iRatio)
    if not oVictim or not oAttack or oVictim:IsDead() then return end

    self:Effect_Condition_For_Victim(oVictim, oAttack)
end
