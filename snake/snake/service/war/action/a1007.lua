-- 战斗信息弹幕

local global = require "global"

local util = import(lualib_path("public.util"))
local action = import(service_path("action/actionbase"))

function NewWarAction(...)
    local o = CWarAction:New(...)
    return o
end

CWarAction = {}
CWarAction.__index = CWarAction
inherit(CWarAction, action.CWarAction)

function CWarAction:New(...)
    local o = super(CWarAction).New(self, ...)
    return o
end

function CWarAction:DoAction(mInfo)
    local oWar = self:GetWar()
    if not oWar then
        return
    end
    for iCamp=1,2 do
        local lMonster = oWar:GetWarriorList(iCamp)
        for _,oWarrior in ipairs(lMonster) do
            if oWarrior:IsPlayer() then
                self:DoActionConfig(oWarrior)
            end
        end
    end
end

function CWarAction:DoActionConfig(oWarrior)
    local func = function (oWarrior, oAttack, oPerform, iDamage)
        OnReceiveDamage(oWarrior, oAttack, oPerform)
    end
    oWarrior:AddFunction("OnReceiveDamage", 1007, func)

    func = function (oWarrior, lSelect, iSkill)
        PerformFunc(oWarrior, lSelect, iSkill)
    end
    oWarrior:AddFunction("PerformFunc", 1007, func)
end

function PerformFunc(oWarrior, lSelect, iSkill)
    local oActionMgr = global.oActionMgr
    local oPerform = oWarrior:GetPerform(iSkill)
    if oPerform and oPerform:IsSE() then
        local oVictim = oActionMgr:ChoosePerformVictim(oWarrior, lSelect, iSkill)
        if not oVictim then
            return
        end
        if not oActionMgr:ValidPerform(oWarrior, oVictim, oPerform, false) then
            return
        end
        local sText = GetTextData(1010)
        sText = util.FormatColorString(sText, {role = oWarrior:GetName(), barrage_perform = oPerform:Name()})
        DoWarInfo(oWarrior, sText)
    end
end

function GetTextData(iText)
    return util.GetTextData(iText, {"bulletbarrage"})
end

function OnReceiveDamage(oWarrior, oAttack, oPerform)
    if oWarrior:IsDead() then
        local oWar = oWarrior:GetWar()
        if oAttack then
            if oAttack:IsSummon() then
                local iOwner = oAttack:GetData("owner")
                local oPlayerWarrior = oWar:GetWarrior(iOwner)
                if oPlayerWarrior then
                    local sText = GetTextData(1006)
                    sText = util.FormatColorString(sText, {role = {oPlayerWarrior:GetName(), oWarrior:GetName()}, summon = oAttack:GetName()})
                    DoWarInfo(oWarrior, sText)
                end
            elseif oAttack:IsPlayer() then
                if oPerform then
                    local sText = GetTextData(1007)
                    sText = util.FormatColorString(sText, {role = {oAttack:GetName(), oWarrior:GetName()}, barrage_perform = oPerform:Name()})
                    DoWarInfo(oWarrior, sText)
                end
            end
        end
        if oWarrior:QueryBoutArgs("rebirth") then
            local sText = GetTextData(1008)
            sText = util.FormatColorString(sText, {role = oWarrior:GetName()})
            DoWarInfo(oWarrior, sText)
        end
        if oWarrior:QueryBoutArgs("poison_die") then
            local sText = GetTextData(1009)
            sText = util.FormatColorString(sText, {role = oWarrior:GetName()})
            DoWarInfo(oWarrior, sText)
        end
    end
end


function DoWarInfo(oWarrior, sContent)
    local oWar = oWarrior:GetWar()
    if not oWar then
        return
    end
    local mCmd = {
        war_id = oWarrior:GetWarId(),
        msg = sContent,
    }
    oWar:SendAll("GS2CWarInfoBulletBarrage", mCmd)
end
