local global = require "global"
local skynet = require "skynet"

local gamedefines = import(lualib_path("public.gamedefines"))
local pfobj = import(service_path("perform/pfobj"))

function NewCPerform(...)
    local o = CPerform:New(...)
    return o
end

CPerform = {}
CPerform.__index = CPerform
inherit(CPerform, pfobj.CPerform)

function CPerform:New(pfid)
    local o = super(CPerform).New(self,pfid)
    return o
end

function CPerform:CalWarrior(oWarrior, oPerformMgr)
    local iPerform = self:Type()
    local func = function(oAttack, oVictim, oPerform, iDamage, mArgs)
        OnAttack(iPerform, oAttack, oVictim, oPerform, iDamage, mArgs)
    end
    oPerformMgr:AddFunction("OnAttack", self.m_ID, func)
end

function CPerform:Perform(oAttack,lVictim)
    local oVictim = lVictim[1]
    local iCnt = 0
    local oWar = oAttack:GetWar()

    while oVictim and oVictim:IsAlive() do
        if not oAttack or oAttack:IsDead() then
            break
        end
        if iCnt >= 3 then break end

        iCnt = iCnt + 1
        local iMagicId = iCnt > 1 and 2 or 1

        oAttack:SendAll("GS2CWarSkill", {
            war_id = oAttack:GetWarId(),
            action_wlist = {oAttack:GetWid(),},
            select_wlist = {oVictim:GetWid()},
            skill_id = self:Type(),
            magic_id = iMagicId,
        })
        local mTime = self:PerformMagicTime(oAttack, iMagicId)
        oWar:AddAnimationTime(mTime[3])
        local iAttackedTime = oVictim:GetAttackedTime()
        oWar:AddAnimationTime(iAttackedTime)
        
        self:SetData("PerformAttackTotal", 1)
        self:SetData("PerformAttackCnt", 1)
        global.oActionMgr:TryDoPhyAttack(oAttack, oVictim, self, 100)
        self:SetData("PerformAttackCnt", nil)
        self:SetData("PerformAttackTotal", nil)

        if oVictim:IsAlive() then break end

        local lEnemy = oAttack:GetEnemyList()
        oVictim = lEnemy[1]
    end
    if oAttack and not oAttack:IsDead() then
        oWar:AddAnimationTime(600)
        oAttack:SendAll("GS2CWarGoback", {
            war_id = oAttack:GetWarId(),
            action_wid = oAttack:GetWid(),
        })
    end 
    self:EndPerform(oAttack, {oVictim})
end

function CPerform:DamageRatioEnv(oAttack, oVictim)
    local mEnv = {}
    mEnv["hp"] = oVictim:GetHp()
    mEnv["max_hp"] = oVictim:GetMaxHp()
    return mEnv
end

function OnAttack(iPerform, oAttack, oVictim, oUsePerform, iDamage, mArgs)
    if iDamage <= 0 then return end
   
    if not oUsePerform or oUsePerform:Type() ~= iPerform then return end

    local sExtArg = oUsePerform:ExtArg()
    local mEnv = oUsePerform:SkillFormulaEnv(oAttack, oVictim)
    local mExtArg = formula_string(sExtArg, mEnv)

    local iAddHp = math.floor(iDamage * mExtArg.ratio / 100)
    if iAddHp > 0 then
        global.oActionMgr:DoAddHp(oAttack, iAddHp)
    end
end


