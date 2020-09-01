local global = require "global"
local res = require "base.res"
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
    local iType = oWarrior:GetData("type")
    if iType == 10010 then       --神偷兔
        local func = function(oAction, mCmd)
            return OnChangeCmd(oAction, mCmd)
        end
        oWarrior:AddFunction("ChangeCmd", 100002, func)
    end
end


function OnChangeCmd(oAction, mCmd)
    local mConfig = res["daobiao"]["huodong"]["guessgame"]["config"][1]

    local oWar = oAction:GetWar()
    if oWar and oWar:CurBout() >= mConfig.bout_out then
        oAction:SetExtData("escape_ratio", 10000)
        return {cmd="escape", data={action_wid=oAction:GetWid()}}
    end
    if math.random(100) <= mConfig.escape_ratio and oWar:CurBout() ~= 1 or not CanSteal(oAction) then
        return {cmd="escape", data={action_wid=oAction:GetWid()}}
    elseif mCmd.data.skill_id == 3013 then
        local mPlayer = oWar:GetPlayerWarriorList()
        if next(mPlayer) then
            mCmd.data.select_wlist = {mPlayer[1]:GetWid()}
            return mCmd
        end
    end
end

function CanSteal(oAction)
    local lEnemy = oAction:GetEnemyList()
    for _, oEnemy in pairs(lEnemy) do
        if oEnemy:GetData("silver", 0) > 0 then
            return true
        end
    end
    return false
end
