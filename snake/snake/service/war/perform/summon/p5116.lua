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

function CPerform:New(pfid)
    local o = super(CPerform).New(self, pfid)
    return o
end

function CPerform:CalWarrior(oAction, oPerformMgr)
    oAction:Set("ghost", self:Level())
    oAction:Set("revive_disable", 1)
    oAction:Set("disable_suck_blood", 1)

    if self:Level() <= 3 then
        oAction:Set("disable_cure", 1)
        oPerformMgr:AddAttrAddValue("res_benefit_buff_ratio", self.m_ID, 100)
    end
    oPerformMgr:AddAttrAddValue("res_abnormal_buff_ratio", self.m_ID, 100)

    local iPerform = self:Type()
    local func = function (oVictim, oAttack)
        OnDead(iPerform, oVictim, oAttack)
    end
    oAction:AddFunction("OnDead", self.m_ID, func)
end

function CPerform:ReviveBoutNum()
    if self:Level() < 5 then return 5 end

    return 5
end

function OnDead(iPerform, oAction, oAttack)
    if oAttack and oAttack:HasKey("kick_ghost") then return end

    local oPerform = oAction:GetPerform(iPerform)
    if not oPerform then return end

    if oAttack and oAttack:Query("kick_ghost_out_ratio") then
        if math.random(100) <= oAttack:Query("kick_ghost_out_ratio") then
            if not oAction:IsPlayerLike() and not oAction:IsPartnerLike() then
                oAction:OnKickOut()
                local oWar = oAction:GetWar()
                if oWar then
                    oWar:KickOutWarrior(oAction)
                end
            end
            return
        end
    end

    local oWar = oAction:GetWar()
    local iExtBout = 0
    if oAction:GetData("owner") then
        local oOwner = oWar:GetWarrior(oAction:GetData("owner"))
        if oOwner then
            iExtBout = iExtBout + oOwner:Query("summon_ghost_bout", 0)
        end
    end
    oAction:GS2CTriggerPassiveSkill(5116)
    oAction:Set("keep_in_war", 1)
    local iReviveBout = oWar.m_iBout + oPerform:ReviveBoutNum() + oAction:Query("ghost_bout", 0) + iExtBout
    oAction:Set("revive_bout", iReviveBout)
    local mArgs = {bForce=true, action_wid=oAction:GetWid(), level=oPerform:Level()}
    oAction.m_oBuffMgr:AddBuff(192, iReviveBout-oWar.m_iBout, mArgs)
    local func = function (o)
        OnBoutEnd(iPerform, o)
    end
    oAction:AddFunction("OnBoutEnd", iPerform, func)
end

function OnBoutEnd(iPerform, oAction)
    if not oAction:IsDead() then return end
    local oPerform = oAction:GetPerform(iPerform)
    if not oPerform then return end

    local oWar = oAction:GetWar()
    if oAction:Query("revive_bout", 0) > oWar.m_iBout then return end

    oAction:Set("revive_disable", nil)
    if oAction:HasKey("revive_disable") then
        oAction:Set("revive_disable", 1)
        return
    end
    oAction:RemoveFunction("OnBoutEnd", iPerform)
    oAction:Set("revive_bout", nil)

    local iHP = math.floor(oAction:GetMaxHp() * oPerform:CalSkillFormula() / 100)
    if iHP <= 0 then return end

    oAction:GS2CTriggerPassiveSkill(5116)
    local oActionMgr = global.oActionMgr
    oActionMgr:DoAddHp(oAction, iHP)
    oAction:Set("revive_disable", 1)
end

