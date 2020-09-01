--import module

local global = require "global"
local skynet = require "skynet"

local aibase = import(service_path("ai/aibase"))

function NewAI(...)
    local o = CAI:New(...)
    return o
end

CAI = {}
CAI.__index = CAI
inherit(CAI, aibase.CAI)

function CAI:New(iAI)
    local o = super(CAI).New(self,iAI)
    return o
end

function CAI:Command(oAction)
    local oWar = oAction:GetWar()
    if not oWar then
        return
    end
    local iWid = oAction:GetWid()
    local iTarget
    local iAutoPf = oAction:GetAutoPerform()
    if iAutoPf and not table_in_list({101,102}, iAutoPf) and not oAction:GetPerform(iAutoPf) then
        iAutoPf = nil
    end
    if not iAutoPf then
        iAutoPf = oAction:GetDefaultPerform()
        oAction:SetAutoPerform(iAutoPf)
    end
    if not table_in_list({101,102}, iAutoPf) then
        local oPerform = oAction:GetPerform(iAutoPf)
        if not oPerform or not oPerform:IsActive() then
            iAutoPf = 101
        end
        if not oPerform:AICheckValidPerform(oAction) then
            iAutoPf = 101
        else
            iTarget = oPerform:ChooseAITarget(oAction)
            if not iTarget then
                iAutoPf = 101
            end
        end
    end

    if iAutoPf == 101 then
        oAction:AISetNormalAttack()
        return
    elseif iAutoPf == 102 then
        local mCmd = {
            cmd = "defense",
        }
        oWar:AddBoutCmd(iWid,mCmd)
        return
    else
        local mCmd = {
            cmd = "skill",
            data = {
                action_wlist = {oAction:GetWid()},
                select_wlist = {iTarget},
                skill_id = iAutoPf,
            }
        }
        oWar:AddBoutCmd(iWid,mCmd)
    end
end
