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
    local iDamageRatio = self:CalSkillFormula()
    local func = function (oAttack, oVictim, oPerform, iDamage, mArgs)
        OnAttackDelay(oAttack, oVictim, oPerform, iDamage, mArgs, iDamageRatio)
    end
    oPerformMgr:AddFunction("OnAttackDelay",self.m_ID, func)
end

function OnAttackDelay(oAttack, oVictim, oPerform, iDamage, mArgs, iDamageRatio)
    if not oVictim or not oVictim:IsDead() then return end
    if mArgs and mArgs.bNotBack then return end

    -- if oPerform and oPerform:AttackType() ~= gamedefines.WAR_PERFORM_TYPE.PHY then return end
    if oPerform then return end

    if mArgs and mArgs.is_critical == 1 and oAttack:HasKey("p5939") then return end 

    if oAttack:QueryBoutArgs("p5509", 0) >= 1 then return end
    if oAttack:QueryBoutArgs("iChaseCnt", 0) >= 1 then return end

    local lEnemy = oAttack:GetEnemyList()
    if #lEnemy <= 0 or iDamage <= 0 then return end

    local oEnemy
    lEnemy = extend.Random.random_size(lEnemy, #lEnemy)
    for _, o in ipairs(lEnemy) do
        if o:GetWid() ~= oVictim:GetWid() then
            oEnemy = o
            break
        end
    end
    if not oEnemy then return end

    oAttack:GS2CTriggerPassiveSkill(5108)
    local oActionMgr = global.oActionMgr
    oAttack:AddBoutArgs("iChaseCnt", 1)
    if oPerform and not oPerform:IsNearAction() then
        oActionMgr:WarNormalAttack(oAttack, oEnemy, {damage_addratio=-100 + iDamageRatio})
    else
        oActionMgr:WarNormalAttack(oAttack, oEnemy, {damage_addratio=-100 + iDamageRatio, perform_time=700})
    end
end

