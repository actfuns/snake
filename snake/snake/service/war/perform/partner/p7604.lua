--import module

local global = require "global"
local skynet = require "skynet"
local pfobj = import(service_path("perform/pfobj"))

function NewCPerform(...)
    local o = CPerform:New(...)
    return o
end

--枷锁

CPerform = {}
CPerform.__index = CPerform
inherit(CPerform, pfobj.CPerform)

function CPerform:CalWarrior(oAction, oPerformMgr)
    local iPerform = self:Type()
    local func = function(oAttack, oVictim, oPerform)
        return OnSealRatio(iPerform, oAttack, oVictim, oPerform)
    end
    oPerformMgr:AddFunction("OnSealRatio", self.m_ID, func)
end

function OnSealRatio(iPerform, oAttack, oVictim, oUsePerform)
    --封印
    local oPerform = oAttack:GetPerform(iPerform)
    
    if not oPerform or not oUsePerform or oUsePerform:ActionType() ~= 2 then return 0 end

    local sExtArgs = oPerform:ExtArg()
    local mEnv = {level = oPerform:Level()}
    local mExtArgs = formula_string(sExtArgs, mEnv)

    return mExtArgs.hit_ratio
end
