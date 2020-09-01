local global = require "global"
local res = require "base.res"

local servstatebase = import(service_path("serverstate/servstatebase"))

CTeamServState = {}
CTeamServState.__index = CTeamServState
inherit(CTeamServState, servstatebase.CTeamServState)

function NewTeamServState(sId, teamid)
    local o = CTeamServState:New(sId, teamid)
    return o
end

function CTeamServState:Init(mArgs)
    -- if not mArgs then
    --     return
    -- end
end

function CTeamServState:GetName()
    return "灵犀任务"
end

function CTeamServState:ValidSave()
    return false
end

function CTeamServState:FobidApplyTeam(pid, mArgs)
    return true
end

function CTeamServState:FobidBackTeam(pid, mArgs)
    return true
end

function CTeamServState:FobidShortLeaveTeam(pid, mArgs)
    return true
end

local mFobidActions = {
    FobidBackTeam = true,
    FobidShortLeaveTeam = true,
    FobidLeaveTeam = false,
    FobidKickoutTeam = true,
    FobidApplyTeam = true,
    FobidApplyTeamPass = true,
    FobidSummonTeam = true,
    FobidTeamInvite = true,
    FobidTeamInvitePass = true,
    FobidAutoTeam = true,
    FobidAutoTeamStart = true,
}
function CTeamServState:FobidTeamAction(pid, sAction, mArgs)
    return mFobidActions[sAction]
end
