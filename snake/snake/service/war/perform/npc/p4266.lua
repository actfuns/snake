--import module

local global = require "global"
local skynet = require "skynet"

local gamedefines = import(lualib_path("public.gamedefines"))
local pfobj = import(service_path("perform/pfobj"))


function NewCPerform(...)
    local o = CPerform:New(...)
    return o
end

--伤害转移

CPerform = {}
CPerform.__index = CPerform
inherit(CPerform, pfobj.CPerform)

function CPerform:CalWarrior(oAttack,oPerformMgr)
    local iPerform = self:Type()

    local func = function (oVictim, oAttack, oPerform, iDamage)
        OnImmuneDamage(oVictim, oAttack, oPerform, iDamage,iPerform)
    end
    oAttack:AddFunction("OnImmuneDamage", self.m_ID, func)
    local func1 = function(oAttack)
        OnWarStart(iPerform, oAttack)
    end
    oPerformMgr:AddFunction("OnWarStart", iPerform, func1)
    oAttack.m_oBuffMgr:AddBuff(211,99,{})
end

function OnImmuneDamage(oVictim, oAttack, oPerform, iDamage,iPerform)
    if iDamage<=0 then 
        return 
    end
    local oPassivePerform = oVictim:GetPerform(iPerform)
    if not oPassivePerform then
        return
    end
    local mFriend = oVictim:GetFriendList()
    local lRevDamWarrior = {}
    for _,oWarrior in  pairs(mFriend) do
        local iType = oWarrior:GetData("type")
        if iType == 10024 or iType == 10025 or iType == 10026 then
            table.insert(lRevDamWarrior,oWarrior)
        end
    end
    if next(lRevDamWarrior) then
        local iRevDamage = math.floor(iDamage/#lRevDamWarrior)
        oVictim:GS2CTriggerPassiveSkill(oPassivePerform:Type())
        for _,oWarrior in pairs(lRevDamWarrior) do
            global.oActionMgr:DoSubHp(oWarrior,iRevDamage,oAttack)
        end
        oVictim:SetBoutArgs("immune_damage", 1)
    end
end

function OnWarStart(iPerform, oAttack)
    local oPerform = oAttack:GetPerform(iPerform)
    if not oPerform then return end
    oAttack.m_oBuffMgr:AddBuff(211,99,{})
    local oWar  = oAttack:GetWar()
    local mCmd = {
        war_id = oAttack:GetWarId(),
        wid = oAttack:GetWid(),
        content = "剑气护体，万邪不侵",
    }
    oWar:SendAll("GS2CWarriorSpeek", mCmd)
end