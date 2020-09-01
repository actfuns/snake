--import module

local global = require "global"
local skynet = require "skynet"

local gamedefines = import(lualib_path("public.gamedefines"))
local pfobj = import(service_path("perform/pfobj"))

--反射
function NewCPerform(...)
    local o = CPerform:New(...)
    return o
end

CPerform = {}
CPerform.__index = CPerform
inherit(CPerform, pfobj.CPerform)

function CPerform:CalWarrior(oWarrior,oPerformMgr)
    --print("4273",oWarrior:GetName())
    local iPerform = self:Type()
    local func = function (oVictim, oAttack, oPerform, iDamage)
        OnImmuneDamage(oVictim, oAttack, oPerform, iDamage,iPerform)
    end
    oWarrior:AddFunction("OnImmuneDamage", self.m_ID, func)
end

function OnImmuneDamage(oVictim, oAttack, oPerform, iDamage,iPerform)
    --print("OnImmuneDamage-4273-1",iDamage,iPerform)
    if iDamage<=0 then 
        return 
    end
    local oTruePerform = oVictim:GetPerform(iPerform)
    if not oTruePerform then
        return
    end
    --print("OnImmuneDamage-4273")
    oVictim:SetBoutArgs("immune_damage", 1)
    oVictim:GS2CTriggerPassiveSkill(iPerform)
    
    oVictim:SendAll("GS2CWarDamage", {
        war_id = oAttack:GetWarId(),
        wid = oAttack:GetWid(),
        type = 0,
        damage = -iDamage,
    })
    oAttack:ReceiveDamage(oVictim,oTruePerform,iDamage)
    DoSpeek(oVictim,"因果循环，今生偿还",1)
end

function DoSpeek(oWarrior, sContent,iFlag)
    if oWarrior:IsDead() then
        return
    end
    local oWar = oWarrior:GetWar()
    if not oWar then
        return
    end
    local mCmd = {
        war_id = oWarrior:GetWarId(),
        wid = oWarrior:GetWid(),
        content = sContent,
        flag = iFlag,
    }
    oWar:SendAll("GS2CWarriorSpeek", mCmd)
end