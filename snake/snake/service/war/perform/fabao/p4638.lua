--import module

local global = require "global"
local skynet = require "skynet"
local pfobj = import(service_path("perform/fabao/fabaobase"))
local pfload = import(service_path("perform/pfload"))
local gamedefines = import(lualib_path("public.gamedefines"))

function NewCPerform(...)
    local o = CPerform:New(...)
    return o
end

CPerform = {}
CPerform.__index = CPerform
inherit(CPerform, pfobj.CPerform)

function CPerform:CalWarrior(oAction, oPerformMgr)
    local iPerform = self:Type()
    local func1 = function(oAttack, iValue, oPerform)
        return CheckResumeMp(iPerform, oAttack, iValue, oPerform)
    end
    oPerformMgr:AddFunction("CheckResumeMp", self.m_ID, func1)
end

function CheckResumeMp(iPerform, oAttack, iValue, oUsePerform)
    local iTrueValue = 0
    local oPerform = oAttack:GetPerform(iPerform)
    if not oPerform then
        return iTrueValue
    end
    if oUsePerform:ActionType() ~= gamedefines.WAR_ACTION_TYPE.CURE then
        return iTrueValue
    end
    local iRatio = oPerform:CalSkillFormula(oAttack,nil,100,{})
    iTrueValue = math.floor(iValue*iRatio/100)
    return -iTrueValue
end
