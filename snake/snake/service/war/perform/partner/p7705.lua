--import module

local global = require "global"
local skynet = require "skynet"
local pfobj = import(service_path("perform/pfobj"))
local gamedefines = import(lualib_path("public.gamedefines"))

function NewCPerform(...)
    local o = CPerform:New(...)
    return o
end

--多事

CPerform = {}
CPerform.__index = CPerform
inherit(CPerform, pfobj.CPerform)

function CPerform:CalWarrior(oAction, oPerformMgr)
    local iPerform = self:Type()
    local func = function(oAttack, oVictim, oPerform)
        return MaxRange(iPerform, oAttack, oVictim, oPerform)
    end
    oPerformMgr:AddFunction("MaxRange", self.m_ID, func)
end

function MaxRange(iPerform, oAttack, oVictim, oUsePerform)
    local oPerform = oAttack:GetPerform(iPerform)
    if not oPerform or not oUsePerform then return 0 end
    
    if oUsePerform:Type() ~= 7702 then return 0 end

    local sExtArg = oPerform:ExtArg()
    local mEnv = {level = oPerform:Level()}
    local mExtArg = formula_string(sExtArg, mEnv)
    if math.random(100) <= mExtArg.ratio then
        return mExtArg.range or 0
    end
    return 0
end
