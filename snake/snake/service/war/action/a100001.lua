local global = require "global"
local action = import(service_path("action/actionbase"))
local gamedefines = import(lualib_path("public.gamedefines"))

function NewWarAction(...)
    local o = CWarAction:New(...)
    return o
end

CWarAction = {}
CWarAction.__index = CWarAction
inherit(CWarAction, action.CWarAction)


function CWarAction:DoAction(mInfo)
    local oWar = self:GetWar()
    if not oWar then
        return
    end

    local lMonster = oWar:GetWarriorList(2)
    for _, oWarrior in ipairs(lMonster) do
        self:DoActionConfig(oWarrior)
    end
    local lPlayer = oWar:GetWarriorList(1)
    for _, oWarrior in ipairs(lPlayer) do
        self:DoActionConfig1(oWarrior)
    end
end

function CWarAction:DoActionConfig1(oWarrior)
    local func = function(oAttack, oVictim, oPerform)
        return CalActionHit(oAttack, oVictim, oPerform)
    end
    oWarrior:AddFunction("CalActionHit", 100001, func)
end

function CalActionHit(oAttack, oVictim, oPerform)
    if not oVictim or not oVictim.m_oBuffMgr:HasBuff(123) then
        return 0
    end

    if not oPerform then return 100 end

    if oPerform:AttackType() == gamedefines.WAR_PERFORM_TYPE.PHY then
        return oAttack:QueryAttr("phy_hit_ratio") 
    else
        return oAttack:QueryAttr("mag_hit_ratio") 
    end
end

function CWarAction:DoActionConfig(oWarrior)
    local iType = oWarrior:GetData("type")
    if iType == 10010 or iType == 10020 then
        local func = function(oAction)
            OnWarStart(oAction)
        end
        oWarrior:AddFunction("OnWarStart", 100001, func)

        local func = function(oAction, mCmd)
            return {cmd="defense", data={action_wid=oAction:GetWid()}}
        end
        oWarrior:AddFunction("ChangeCmd", 100001, func)

        -- oWarrior:Add("phy_hit_res_ratio", 10000)
        -- oWarrior:Add("mag_hit_res_ratio", 10000)
        oWarrior:Add("keep_in_war", 1)

        local mArgs = {bForce=true, action_wid=oWarrior:GetWid()}
        oWarrior.m_oBuffMgr:AddBuff(191, 99, mArgs)
        oWarrior.m_oBuffMgr:AddBuff(188, 99, mArgs)

        local func = function(oAction)
            OnBoutEndCommon(oAction)
        end
        oWarrior:AddFunction("OnBoutEnd", 100001, func)
    end
end

function OnWarStart(oAction)
    local oWar = oAction:GetWar()
    if not oWar then return end

    global.oActionMgr:WarSkill(oAction, {oAction}, 4221)
    oWar:AddAnimationTime(-2200)
end 

function OnBoutEndCommon(oAction)
    --移除自己外的所有怪物
    local oWar = oAction:GetWar()
    if not oWar then return end

    local lMonster = oWar:GetWarriorList(2)
    local lSelect = list_generate(lMonster, function(o)
        if o:GetWid() ~= oAction:GetWid() then
            return o:GetWid()
        end
    end)

    oAction:SendAll("GS2CWarEscape", {
        war_id = oAction:GetWarId(),
        action_wid = lSelect,
        success = true,
    })
    oWar:AddAnimationTime(1 * 1000)

    for _, iWid in ipairs(lSelect) do
        local oWarrior = oWar:GetWarrior(iWid)
        oWar:Leave(oWarrior)
    end
    
    global.oActionMgr:WarSkill(oAction, {oAction}, 4221)
end

function OnEscapeCommon(oAction)
    local oWar = oAction:GetWar()
    if not oWar then return end
end

function NotifyAll(oWar, sMsg)
    local lWarrior = oWar:GetPlayerWarriorList()
    for _, oWarrior in pairs(lWarrior) do
        oWarrior:Notify(sMsg)
    end
end
