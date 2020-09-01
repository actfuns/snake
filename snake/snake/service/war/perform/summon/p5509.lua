--import module

local global = require "global"
local skynet = require "skynet"

local gamedefines = import(lualib_path("public.gamedefines"))
local pfobj = import(service_path("perform/summon/pfbase"))

local EXCLUDE_BUFF = {117, 213}

function NewCPerform(...)
    local o = CPerform:New(...)
    return o
end

function OnPlayerAttack(iPerform, oAttack, oVictim, oUsePerform, iDamage)
    if not oAttack or not oVictim then return end
    if oAttack:IsFriend(oVictim) then return end
    for _,iBuff in pairs(EXCLUDE_BUFF) do
        if oAttack.m_oBuffMgr:HasBuff(iBuff) then
            return
        end
    end

    -- 普通攻击
    if oUsePerform or oVictim:IsDead() then return end
    local oWar = oAttack:GetWar()
    local oSummon = oWar:GetWarrior(oAttack:Query("curr_sum"))
    if not oSummon or oSummon:IsDead() then return end

    local oPerform = oSummon:GetPerform(iPerform)
    if not oPerform then return end

    local iRatio = oPerform:CalSkillFormula()
    if math.random(100) > iRatio then return end

    local oActionMgr = global.oActionMgr
    oSummon:SetBoutArgs("p5509", 1)
    oActionMgr:WarNormalAttack(oSummon, oVictim)
    oSummon:SetBoutArgs("p5509", nil)
end

-- 协同(天赋)
CPerform = {}
CPerform.__index = CPerform
inherit(CPerform, pfobj.CPerform)

function CPerform:New(pfid)
    local o = super(CPerform).New(self, pfid)
    return o
end

function CPerform:CalWarrior(oAction, oPerformMgr)
    local oWar = oAction:GetWar()
    local oPlayer = oWar:GetWarrior(oAction:GetData("owner"))
    if not oPlayer then return end

    local iPerform = self:Type()
    local func = function (oAttack, oVictim, oUsePerform)
        return OnPlayerAttack(iPerform, oAttack, oVictim, oUsePerform)        
    end
    oPlayer:AddFunction("OnAttack", self.m_ID, func)
end

