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

function CWarAction:New(...)
    local o = super(CWarAction).New(self, ...)
    return o
end

function CWarAction:GetActionId()
    return 0
end

function CWarAction:GetSkillChange()
    return {}
end

function CWarAction:DoAction(mInfo)
    local oWar = self:GetWar()
    if not oWar then
        return
    end
    local iCamp = gamedefines.WAR_WARRIOR_SIDE.ENEMY
    local lMonster = oWar:GetWarriorList(iCamp)
    local mSkillChange = self:GetSkillChange()
    for _, oWarrior in ipairs(lMonster) do
        local iTypeSid = oWarrior:GetTypeSid()
        local iChangePerform = mSkillChange[iTypeSid]
        if iChangePerform then
            oWarrior:AddFunction("ChangeCmd", self:GetActionId(), function (oWarrior, mCmd)
                return OnChangeCmd1(oWarrior, mCmd, iChangePerform)
            end)
        end
    end
end

function OnChangeCmd1(oWarrior, mCmd, iPerform)
    if oWarrior:IsDead() then return end
    local oWar = oWarrior:GetWar()
    if not oWar then return end
    if oWar:CurBout() ~= 1 then
        return
    end
    if mCmd.cmd == "skill" and mCmd.data.skill_id == iPerform then
        return
    end
    local oPerform = oWarrior:GetPerform(iPerform)
    if not oPerform then
        return
    end
    local iTarget = oPerform:ChooseAITarget(oWarrior)
    local cmd = {}
    cmd.cmd = "skill"
    cmd.data = {
        skill_id = iPerform,
        action_wlist = {oWarrior:GetWid()},
        select_wlist = {iTarget},
    }
    return cmd
end
