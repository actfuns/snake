--import module

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
        local iType = oWarrior:GetData("type")
        self:DoActionConfig(oWarrior,iType)
    end
end

function CWarAction:DoActionConfig(oWarrior,iType)
    local oWar = oWarrior:GetWar()
    if iType == 3001 then
        local iCamp = 1
        local mWarrior = oWar:GetWarriorList(iCamp)
        local bEscape = false
        for _,oEnemy in pairs(mWarrior) do
            if oEnemy:IsPlayer() or oEnemy:IsPartner() then
                local iSchool = oEnemy:GetData("school")
                if gamedefines.ASSISTANT_SCHOOL[iSchool] then
                    bEscape = true
                    break
                end
            end
        end
        local func = function (oWarrior)
            NewBout(oWarrior,bEscape)
        end
        oWarrior:AddFunction("OnNewBout",1001,func)

        local func1 = function (oWarrior)
            OnWarStart(oWarrior)
        end
        oWarrior:AddFunction("OnWarStart",1001,func1)
    end
end

function NewBout(oWarrior,bEscape)
    local oWar = oWarrior:GetWar()
    if not oWar then
        return
    end
    local iBout = oWar.m_iBout
    if bEscape and iBout >= 1 then
        oWarrior:SetExtData("escape_ratio",100)
        local mCmd = {
            cmd = "escape",
            data = {
                action_wid = oWarrior.m_iWid,
            }
         }
        oWar.m_mBoutCmds[oWarrior.m_iWid] = mCmd
        local func = function(oWarrior)
            OnEscape(oWarrior, "有#G金山寺#n、#G青城#n、#G瑶池#n的弟子，好害怕先走为妙。")
        end
        oWarrior:AddFunction("OnEscape", 1001, func)
    end
    if iBout >= 4 then
        oWarrior:SetExtData("escape_ratio",100)
        local mCmd = {
            cmd = "escape",
            data = {
                action_wid = oWarrior.m_iWid,
            }
         }
        oWar.m_mBoutCmds[oWarrior.m_iWid] = mCmd
    end
end

function OnEscape(oWarrior, sContent)
    local oWar = oWarrior:GetWar()
    if not oWar then return end
    local mNet = {
        war_id = oWar:GetWarId(),
        content = sContent,
        wid = oWarrior:GetWid(),
    }
    oWar:SendAll("GS2CWarriorSpeek", mNet)
end

function OnWarStart(oWarrior)
    oWarrior.m_oBuffMgr:AddBuff(190, 99, {bForce=true})
end
