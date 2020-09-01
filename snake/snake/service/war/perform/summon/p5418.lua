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

-- 高级定心
function CPerform:New(pfid)
    local o = super(CPerform).New(self,pfid)
    return o
end

function CPerform:CalWarrior(oAction, oPerformMgr)
    local iType = self:Type()
    local func = function(oAct, oBuff)
        return OnBeforeAddBuff(iType, oAct, oBuff)
    end
    oPerformMgr:AddFunction("OnBeforeAddBuff", self.m_ID, func)
end

function OnBeforeAddBuff(iType, oAction, oBuff)
    if not oBuff then return end

    if not oAction or oAction:IsDead() then return end

    local oPerform = oAction:GetPerform(iType)
    if not oPerform then return end

    if oBuff:Type() ~= gamedefines.BUFF_TYPE.CLASS_ABNORMAL then return end
    if oBuff:BuffType() == "封印" then return end

    local iRatio = oPerform:CalSkillFormula()
    if math.random(100) <= iRatio then 
        oAction:GS2CTriggerPassiveSkill(5418)
        return true
    end
    return false
end
