local global = require "global"
local extend = require "base.extend"
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
end

function CWarAction:DoActionConfig(oWarrior)
    local func = function(oAction)
        OnWarStart(oAction)
    end
    oWarrior:AddFunction("OnWarStart", 100008, func)
    oWarrior:AddFunction("OnBoutEnd", 100008, func)
    local func1 = function(oAction)
        OnNewBout(oAction)
    end
    oWarrior:AddFunction("OnNewBout", 100008, func1)
end

function OnWarStart(oAction)
    local oWar = oAction:GetWar()
    if not oWar then return end

    local lMonster = oWar:GetWarriorList(2)
    local iHas = 0
    local mAllMonsterInfo = oAction:GetData("all_monster", {})
    for _, oWarrior in ipairs(lMonster) do
        if mAllMonsterInfo[oWarrior:GetTypeSid()] then
            iHas = iHas + 1
        end
    end
    local iSize = math.min(2, math.max(0, 4 - iHas))
    if iSize <= 0 then return end

    global.oActionMgr:WarSkill(oAction, {oAction}, 4282)
    oWar:AddAnimationTime(-1500)
end

function OnNewBout(oAction)
    local oWar = oAction:GetWar()
    if not oWar then return end
    
    local oBuff = oAction.m_oBuffMgr:HasBuff(225)
    if not oBuff then return end

    local iNum = 0
    local lMonster = oWar:GetWarriorList(2)
    for _, oMonster in ipairs(lMonster) do
        if math.floor(oMonster:GetTypeSid() % 10) == 4 then
            iNum = iNum + 1
        end
    end
    if iNum <= 0 then
        oAction.m_oBuffMgr:RemoveBuff(oBuff)
    end
end
