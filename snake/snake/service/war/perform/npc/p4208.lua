local global = require "global"
local skynet = require "skynet"

local gamedefines = import(lualib_path("public.gamedefines"))
local pfobj = import(service_path("perform/pfobj"))

function NewCPerform(...)
    local o = CPerform:New(...)
    return o
end

--狂暴

CPerform = {}
CPerform.__index = CPerform
inherit(CPerform, pfobj.CPerform)

function CPerform:CalWarrior(oAction, oPerformMgr)
    local func1 = function(oAttack, oVictim, oPerform)
        return CalMagAttack(oAttack, oVictim, oPerform)
    end
    oPerformMgr:AddFunction("CalMagAttack", self.m_ID, func1)

    local func2 = function(oAttack, oVictim, oPerform)
        return CalPhyAttack(oAttack, oVictim, oPerform)
    end
    oPerformMgr:AddFunction("CalPhyAttack", self.m_ID, func2)
end

function CalMagAttack(oAttack, oVictim, oPerform)
    return math.floor(oAttack:GetBaseAttr("mag_attack") * 0.5)
end

function CalPhyAttack(oAttack, oVictim, oPerform)
    return math.floor(oAttack:GetBaseAttr("phy_attack") * 0.5)
end
