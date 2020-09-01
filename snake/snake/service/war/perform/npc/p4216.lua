
--import module

local global = require "global"
local skynet = require "skynet"

local gamedefines = import(lualib_path("public.gamedefines"))
local pfobj = import(service_path("perform/pfobj"))


function NewCPerform(...)
    local o = CPerform:New(...)
    return o
end

--魔气缠身

CPerform = {}
CPerform.__index = CPerform
inherit(CPerform, pfobj.CPerform)

function CPerform:CalWarrior(oAction, oPerformMgr)
    local iPerform = self:Type()
    local func = function(oAttack)
        OnWarStart(iPerform, oAttack)
    end
    oPerformMgr:AddFunction("OnWarStart", self.m_ID, func)
end

function OnWarStart(iPerform, oAttack)
    local oPerform = oAttack:GetPerform(iPerform)
    if not oPerform then return end
    oPerform:Effect_Condition_For_Attack(oAttack,{floor = 5})
end
