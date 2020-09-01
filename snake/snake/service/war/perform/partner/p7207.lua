--import module

local global = require "global"
local skynet = require "skynet"
local pfobj = import(service_path("perform/pfobj"))

function NewCPerform(...)
    local o = CPerform:New(...)
    return o
end

--法强

CPerform = {}
CPerform.__index = CPerform
inherit(CPerform, pfobj.CPerform)

function CPerform:CalWarrior(oAction, oPerformMgr)
    if not oAction:IsPartnerLike() then return end

    local oWar = oAction:GetWar()
    if not oWar then return end

    local iOwner = oAction:GetOwner()
    if not iOwner then return end

    local oWarrior = oWar:GetPlayerWarrior(iOwner)
    if not oWarrior then return end

    local mEnv = {
        level = self:Level(),
    }
    local sExtArgs = self:ExtArg()
    local mArgs = formula_string(sExtArgs, mEnv)
    for sKey, iVal in pairs(mArgs) do
        oWarrior:Add(sKey, iVal)
    end
end
