--import module

local global = require "global"
local skynet = require "skynet"
local pfobj = import(service_path("perform/fabao/fabaobase"))
local gamedefines = import(lualib_path("public.gamedefines"))

function NewCPerform(...)
    local o = CPerform:New(...)
    return o
end

CPerform = {}
CPerform.__index = CPerform
inherit(CPerform, pfobj.CPerform)

function CPerform:CalWarrior(oWarrior,oPerformMgr)
    local iPerform = self:Type()
    local func = function(oVictim, oAttack, oPerform, iDamage)
        OnReceiveDamage(iPerform, oVictim, oAttack, oPerform, iDamage)
    end
    oPerformMgr:AddFunction("OnReceiveDamage", self.m_ID, func)
end

function OnReceiveDamage(iPerform, oVictim, oAttack, oUsePerform, iDamage)
    if not oUsePerform or oUsePerform:AttackType() ~= gamedefines.WAR_PERFORM_TYPE.MAGIC then return end
    if iDamage <= 0 then return end
    if not oVictim or oVictim:IsDead() then return end

    local oPerform = oVictim:GetPerform(iPerform)
    if not oPerform then return end
        
    local iRatio = oPerform:CalSkillFormula(oVictim, nil, 100, {})    
    local oPerform4642 = oVictim:GetPerform(4642)
    if oPerform4642 then
        iRatio = iRatio + oPerform4642:GetTriggerRatio(oVictim)
    end
    if math.random(100) > iRatio then return end

    local mExtArgs = formula_string(oPerform:ExtArg(), {})
    local iRate = mExtArgs.ratio or 0
    local oPerform4643 = oVictim:GetPerform(4643)
    if oPerform4643 then
         iRate = iRate + oPerform4643:GetTriggerValue(oVictim)
    end
    local oPerform4644 = oVictim:GetPerform(4644)
    if oPerform4644 then
         iRate = iRate * oPerform4644:GetTriggerValue(oVictim)
    end

    local iAddHP = math.floor(iDamage*iRate/100)
    if iAddHP > 0 then
        global.oActionMgr:DoAddHp(oVictim, iAddHP)
        local oPerform4645 = oVictim:GetPerform(4645)
        if oPerform4645 then
            local iAddMpRatio = oPerform4645:GetTriggerValue(oVictim)
            local iAddMp =math.floor(iAddHP*iAddMpRatio/100)
            if iAddMp >0 then
                global.oActionMgr:DoAddMp(oVictim, iAddMp)
            end
        end
    end
end
