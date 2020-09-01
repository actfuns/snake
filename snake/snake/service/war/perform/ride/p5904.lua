local global = require "global"
local skynet = require "skynet"
local pfobj = import(service_path("perform/pfobj"))
local gamedefines = import(lualib_path("public.gamedefines"))

function NewCPerform(...)
    local o = CPerform:New(...)
    return o
end

--垂死一击

CPerform = {}
CPerform.__index = CPerform
inherit(CPerform, pfobj.CPerform)

function CPerform:CalWarrior(oAction, oPerformMgr)
    self.m_iBout = -99
    local iPerform = self:Type()
    local func = function(oVictim, oAttack)
        OnDead(iPerform, oVictim, oAttack)
    end
    oPerformMgr:AddFunction("OnDead", self.m_ID, func)
end

function OnDead(iPerform, oVictim, oAttack)
    if not oAttack then
        return
    end
    local oWar = oVictim:GetWar()
    if not oWar then return end
    local oPerform = oVictim:GetPerform(iPerform)
    if not oPerform then return end

    local sExtArg = oPerform:ExtArg()
    local mEnv = oPerform:SkillFormulaEnv(oAttack, oVictim)
    local mExtArg = formula_string(sExtArg, mEnv)

    if oWar:CurBout() - oPerform.m_iBout <= mExtArg.bout_freq then
        return
    end

    oPerform.m_iBout = oWar:CurBout()
    -- oWar:AddAnimationTime(1000)
    oWar:SendAll("GS2CWarGoback", {
        war_id = oAttack:GetWarId(),
        action_wid = oAttack:GetWid(),
    })

    oVictim:Set("disable_add_hp", 1)
    oVictim.m_oStatus:Set(gamedefines.WAR_WARRIOR_STATUS.ALIVE)
    oVictim:StatusChange("status")
    oVictim:SetBoutArgs("ignore_attacked", 1)    

    local mCmd = {
        war_id = oVictim:GetWarId(),
        wid = oVictim:GetWid(),
        content = mExtArg.speek,
        show_type = 0,
    }
    oWar:SendAll("GS2CWarriorSpeek", mCmd)

    local iSchool = oVictim:GetData("school", 0)
    local iUsePerform = mExtArg["pf_choose"][iSchool]
    local oUsePerform = oVictim:GetPerform(iUsePerform)
    if oUsePerform then
        local lTarget = oUsePerform:TargetList(oVictim)
        if next(lTarget) then
            local oTarget = lTarget[math.random(#lTarget)]
            local mTarget = oUsePerform:PerformTarget(oVictim, oTarget)
            local lVictim = {}
            for _,iWid in ipairs(mTarget) do
                table.insert(lVictim, oWar:GetWarrior(iWid))
            end
            oUsePerform:Perform(oVictim, lVictim)
        end
    end
    oVictim:Set("disable_add_hp", nil)
    oVictim.m_oStatus:Set(gamedefines.WAR_WARRIOR_STATUS.DEAD)
    oVictim:StatusChange("status")
end

