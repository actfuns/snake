--import module

local global = require "global"
local skynet = require "skynet"

local gamedefines = import(lualib_path("public.gamedefines"))
local pfobj = import(service_path("perform/summon/pfbase"))


function NewCPerform(...)
    local o = CPerform:New(...)
    return o
end

CPerform = {}
CPerform.__index = CPerform
inherit(CPerform, pfobj.CPerform)

-- 气势
function CPerform:New(pfid)
    local o = super(CPerform).New(self, pfid)
    return o
end

function CPerform:CalWarrior(oAction, oPerformMgr)
    local iPerform = self:Type()
    local func = function (o)
        OnEnterWar(iPerform, o)
    end
    oPerformMgr:AddFunction("OnWarStart",self.m_ID, func)
    oPerformMgr:AddFunction("OnEnterWar",self.m_ID, func)
end

function OnEnterWar(iPerform, oAction)
    local oPerform = oAction:GetPerform(iPerform)
    if not oPerform then return end

    local mEnv = {level=oPerform:Level()}
    local sExtArgs = oPerform:ExtArg()
    local mExtArgs = formula_string(sExtArgs, mEnv)
    local iBuff = mExtArgs["buff"]
    local iBout = mExtArgs["bout"]
    local oBuffMgr = oAction.m_oBuffMgr
    oBuffMgr:AddBuff(iBuff, iBout, mEnv)
end

