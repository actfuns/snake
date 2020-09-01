--import module

local global = require "global"
local skynet = require "skynet"
local pfobj = import(service_path("perform/pfobj"))
local gamedefines = import(lualib_path("public.gamedefines"))

function NewCPerform(...)
    local o = CPerform:New(...)
    return o
end

--敏巧

CPerform = {}
CPerform.__index = CPerform
inherit(CPerform, pfobj.CPerform)

function CPerform:CalWarrior(oAction, oPerformMgr)
    local mEnv = {
        level = self:Level(),
    }
    local sExtArgs = self:ExtArg()
    local mArgs = formula_string(sExtArgs, mEnv)
    for sKey, iVal in pairs(mArgs) do
        oAction.m_oPerformMgr:SetAttrBaseRatio(sKey, self.m_ID, iVal)
    end
end


