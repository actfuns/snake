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

-- 定心
function CPerform:New(pfid)
    local o = super(CPerform).New(self,pfid)
    return o
end

function CPerform:CalWarrior(oAction, oPerformMgr)
    local iType = self:Type()
    local func = function(oAttack)
        OnBoutEnd(iType, oAttack)
    end
    oPerformMgr:AddFunction("OnBoutEnd", self.m_ID, func)
end

function OnBoutEnd(iType, oAttack)
    if not oAttack or oAttack:IsDead() then return end

    local oPerform = oAttack:GetPerform(iType)
    if not oPerform then return end

    if not oAttack.m_oBuffMgr:HasClassBuff(gamedefines.BUFF_TYPE.CLASS_ABNORMAL) then
        return
    end

    local iRatio = oPerform:CalSkillFormula()
    if math.random(100) <= iRatio then 
        local iLimit = oAttack.m_oBuffMgr:RemoveClassBuff(gamedefines.BUFF_TYPE.CLASS_ABNORMAL, "封印", 99)
        if iLimit < 99 then
            oAttack:GS2CTriggerPassiveSkill(5118)
        end
    end
end



