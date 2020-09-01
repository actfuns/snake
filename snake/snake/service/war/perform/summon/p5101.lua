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

-- 复仇
function CPerform:New(pfid)
    local o = super(CPerform).New(self, pfid)
    return o
end

function CPerform:CalWarrior(oAction, oPerformMgr)
    local iRatio = self:CalSkillFormula()
    local func = function (oVictim, oAttack, oPerform, iDamage, mArgs)
        OnAttacked(oVictim, oAttack, oPerform, iDamage, mArgs, iRatio)
    end
    oPerformMgr:AddFunction("OnAttacked",self.m_ID, func)
end

function OnAttacked(oVictim, oAttack, oPerform, iDamage, mArgs, iRatio)
    if not oVictim or oVictim:IsDead() or oAttack:HasKey("sneak") then return end
    if not oAttack:IsVisible(oVictim) then return end
    if oAttack:QueryBoutArgs("beat_back", 0) > 0 then return end

    if oPerform and oPerform:AttackType() ~= gamedefines.WAR_PERFORM_TYPE.PHY then return end

    if oPerform and oPerform:IsGroupPerform() then return end

    if mArgs and mArgs.bNotBack then return end

    -- if mArgs and mArgs.protect then return end

    -- local lWids = oVictim:QueryBoutArgs("lBeatBack", {})
    -- if table_in_list(lWids, oAttack:GetWid()) then return end
    if math.random(100) > (iRatio-oAttack:Query("res_hit_back_ratio",0)) then
        return
    end

    oVictim:GS2CTriggerPassiveSkill(5101)

    local oActionMgr = global.oActionMgr
    -- table.insert(lWids, oAttack:GetWid())
    oVictim:SetBoutArgs("lBeatBack", lWids)
    
    if oPerform and not oPerform:IsNearAction() then
        oActionMgr:WarNormalAttack(oVictim, oAttack, {bNotBack=true,hit_back=true})
    else
        oActionMgr:WarNormalAttack(oVictim, oAttack, {bNotBack=true,hit_back=true,perform_time=700})
    end
end
