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
        OnAttack(oAttack, oVictim, oPerform, iDamage, mArgs, iRatio)
    end
    oAction:AddFunction("OnAttack",self.m_ID, func)
end

function OnAttack(oAttack, oVictim, oPerform, iDamage, mArgs, iRatio)
    if mArgs and mArgs.bNotBack then return end
    if oPerform or iDamage <= 0 then return end

    local iRealDamage = math.floor(iRatio * iDamage / 100)
    local lEnemy = oAttack:GetEnemyList()
    if #lEnemy <= 0 or iRealDamage <= 0 then return end

    local iCnt = 0
    local oActionMgr = global.oActionMgr
    for _,oEnemy in pairs(extend.Random.random_size(lEnemy, 3)) do
        if oEnemy:GetWid() ~= oVictim:GetWid() then
            oActionMgr:DoSubHp(oEnemy, iRealDamage, oAttack, {hited_effect=1})
            iCnt = iCnt + 1
        end
        if iCnt == 2 then break end
    end
end
