local global = require "global"
local skynet = require "skynet"

local gamedefines = import(lualib_path("public.gamedefines"))
local pfobj = import(service_path("perform/pfobj"))

function NewCPerform(...)
    local o = CPerform:New(...)
    return o
end

--清心

CPerform = {}
CPerform.__index = CPerform
inherit(CPerform, pfobj.CPerform)

function CPerform:CalWarrior(oAction, oPerformMgr)
    local func = function(oWarrior)
        OnNewBout(oWarrior)
    end
    oPerformMgr:AddFunction("OnNewBout", self.m_ID, func)
end

function OnNewBout(oWarrior)
    if not oWarrior then return end

    oWarrior.m_oBuffMgr:RemoveClassBuffInclude(gamedefines.BUFF_TYPE.CLASS_ABNORMAL, {["封印"]=1})
end
