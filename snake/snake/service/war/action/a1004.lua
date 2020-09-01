local global = require "global"

local action = import(service_path("action/actionbase"))
local gamedefines = import(lualib_path("public.gamedefines"))
local loadaction = import(service_path("action.loadaction"))

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
    local iCamp = 2
    local lMonster = oWar:GetWarriorList(iCamp)
    for _,oWarrior in ipairs(lMonster) do
        local iSchool = oWarrior:GetData("mirror_school")
        if iSchool then
            self:DoActionConfig(oWarrior, iSchool, mInfo)
        end
    end
end

function CWarAction:DoActionConfig(oWarrior, iSchool, mInfo)
    local oWar = oWarrior:GetWar()
    local iCamp = 1
    local mWarrior = oWar:GetWarriorList(iCamp)
    local bEscape = false
    for _,oEnemy in pairs(mWarrior) do
        if oEnemy:IsPlayer() then
            if oEnemy:GetSchool() == iSchool then
                bEscape = true
                break
            end
        end
    end
    if not bEscape then
        return
    end
    local func = function (oWarrior)
        NewBout(oWarrior, mInfo)
    end
    oWarrior:AddFunction("OnNewBout", 1004, func)
end

function NewBout(oWarrior, mInfo)
    local oWar = oWarrior:GetWar()
    if not oWar then
        return
    end
    oWarrior:SetBoutArgs("speed", 10000) -- 提高速度, 第一个出手
    oWarrior:SetExtData("escape_ratio", 100)
    local mCmd = {
        cmd = "escape",
        data = {
            action_wid = oWarrior.m_iWid,
        }
     }
    oWar.m_mBoutCmds[oWarrior.m_iWid] = mCmd

    local mSpeekData = mInfo.custom_speek or {}
    for idx, mAction in pairs(mSpeekData) do
        local sContent = mAction.content
        local mSpeek = {
            war_id = oWarrior:GetWarId(),
            wid = oWarrior:GetWid(),
            content = sContent,
        }
        oWar:SendAll("GS2CWarriorSpeek", mSpeek)
    end
end

