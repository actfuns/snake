--import module

local global = require "global"
local skynet = require "skynet"
local extend = require "base.extend"

local gamedefines = import(lualib_path("public.gamedefines"))
local pfobj = import(service_path("perform/summon/pfbase"))


function NewCPerform(...)
    local o = CPerform:New(...)
    return o
end

CPerform = {}
CPerform.__index = CPerform
inherit(CPerform, pfobj.CPerform)

function CPerform:New(pfid)
    local o = super(CPerform).New(self, pfid)
    return o
end

function CPerform:CalWarrior(oAction, oPerformMgr)
    local iRatio = self:CalSkillFormula()
    local func = function (oAttack, oVictim, oPerform, iDamage, mArgs)
        OnAttackDelay(oAttack, oVictim, oPerform, iDamage, mArgs, iRatio)
    end
    oPerformMgr:AddFunction("OnAttackDelay",self.m_ID, func)
end

function OnAttackDelay(oAttack, oVictim, oPerform, iDamage, mArgs, iRatio)
    if not oPerform or iDamage <= 0 then return end
    if not oAttack or oAttack:IsDead() then return end

    if not oPerform or oPerform:AttackType() ~= gamedefines.WAR_PERFORM_TYPE.MAGIC then return end

    if oAttack:QueryBoutArgs("iChaseCnt", 0) >= 1 then return end

    if math.random(100) > iRatio then return end

    if oPerform:GetData("PerformAttackCnt", 0) < oPerform:GetData("PerformAttackTotal", 0) then
        return
    end

    local oActionMgr = global.oActionMgr
    if not oVictim or oVictim:IsDead() then
        local lEnemy = oAttack:GetEnemyList()
        if #lEnemy <= 0 then return end

        local iRan = math.random(#lEnemy)
        oVictim = lEnemy[iRan]
    end

    oAttack:GS2CTriggerPassiveSkill(5110)

    local mTarget = oPerform:PerformTarget(oAttack, oVictim)
    local lVictim = {}
    local oWar = oAttack:GetWar()
    for _,iWid in ipairs(mTarget) do
        table.insert(lVictim, oWar:GetWarrior(iWid))
    end

    oAttack:Add("damage_addratio", -50)
    oAttack:AddBoutArgs("iChaseCnt", 1)
    oPerform:Perform(oAttack, lVictim)
    oAttack:Add("damage_addratio", 50)
end
