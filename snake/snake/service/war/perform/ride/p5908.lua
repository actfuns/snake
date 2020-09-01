local global = require "global"
local skynet = require "skynet"
local pfobj = import(service_path("perform/pfobj"))

function NewCPerform(...)
    local o = CPerform:New(...)
    return o
end

--坚盾术

CPerform = {}
CPerform.__index = CPerform
inherit(CPerform, pfobj.CPerform)

function CPerform:CalWarrior(oAction, oPerformMgr)
    local iPerform = self:Type()
    local func = function(oVictim)
        return GetDefenseFactor(iPerform, oVictim)
    end
    oPerformMgr:AddFunction("GetDefenseFactor", self.m_ID, func)
end

function GetDefenseFactor(iPerform, oVictim)
    if not oVictim then return 0 end
    local oPerform = oVictim:GetPerform(iPerform)
    if not oPerform then return 0 end

    local sExtArg = oPerform:ExtArg()
    local mExtArg = formula_string(sExtArg, {})
    if oVictim:GetPerform(9205) then
        return mExtArg.defense_factor // 2
    else
        return mExtArg.defense_factor
    end
end
