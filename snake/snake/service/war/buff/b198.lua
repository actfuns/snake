local global = require "global"
local skynet = require "skynet"
local extend = require "base.extend"

local buffbase = import(service_path("buff/buffbase"))
local gamedefines = import(lualib_path("public.gamedefines"))

function NewBuff(...)
    local o = CBuff:New(...)
    return o
end

CBuff = {}
CBuff.__index = CBuff
inherit(CBuff, buffbase.CBuff)

function CBuff:CalInit(oAction, oBuffMgr)
    local func = function(oAttack, oVictim, oPerform, iDamage, mArgs)
        OnAttack(oAttack, oVictim, oPerform, iDamage, mArgs)
    end
    oBuffMgr:AddFunction("OnAttack", self.m_ID, func)
end

function CBuff:OnRemove(oAction, oBuffMgr)
    oBuffMgr:RemoveFunction("OnAttack", self.m_ID)
    super(CBuff).OnRemove(self, oAction, oBuffMgr)
end

function OnAttack(oAttack, oVictim, oUsePerform, iDamage, mArgs)
    if oUsePerform and oUsePerform:IsGroupPerform() then return end
    if oUsePerform and oUsePerform:AttackType() ~= gamedefines.WAR_PERFORM_TYPE.PHY then
        return
    end

    if iDamage <= 0 then return end

    local oPerform = oAttack:GetPerform(1103)
    if not oPerform then return end

    local sExtArg = oPerform:ExtArg()
    local mEnv = oPerform:SkillFormulaEnv(oAttack, oVictim)
    local mExtArg = formula_string(sExtArg, mEnv)
    local iSubHp = mExtArg.sub_ratio * iDamage // 100
    if iSubHp <= 0 then return end

    local lEnemy = oAttack:GetEnemyList()
    table.sort(lEnemy, function(x,y) return x:GetHp() < y:GetHp() end)
    local iCnt = 0
    for _, oEnemy in ipairs(lEnemy) do
        if oEnemy:GetWid() ~= oVictim:GetWid() then
            iCnt = iCnt + 1
            global.oActionMgr:DoSubHp(oEnemy, iSubHp, oAttack, {hited_effect=1})
        end
        if iCnt >= 2 then break end
    end
end

