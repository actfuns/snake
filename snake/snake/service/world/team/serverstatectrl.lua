-- 队伍的服务端状态管理器
local loadservstate = import(service_path("serverstate/loadservstate"))

function NewTeamServStateCtrl(...)
    return CTeamServStateCtrl:New(...)
end

CTeamServStateCtrl = {}
CTeamServStateCtrl.__index = CTeamServStateCtrl
inherit(CTeamServStateCtrl, logic_base_cls())

function CTeamServStateCtrl:New(teamid)
    local o = super(CTeamServStateCtrl).New(self)
    o.m_iTeamId = teamid
    o.m_mServStates = {}
    return o
end

function CTeamServStateCtrl:Release()
    for sStateId, oTeamServState in pairs(self.m_mServStates) do
        baseobj_safe_release(oTeamServState)
    end
    self.m_mServStates = nil
    super(CTeamServStateCtrl).Release(self)
end

function CTeamServStateCtrl:AddServStateByArgs(sStateId, mArgs)
    if self:GetServState(sStateId) then
        return
    end
    local oTeamServState = loadservstate.CreateTeamServState(sStateId, self.m_iTeamId, mArgs)
    if not oTeamServState then
        return
    end
    self:AddServState(oTeamServState)
    return oTeamServState
end

function CTeamServStateCtrl:GetServState(sStateId)
    return self.m_mServStates[sStateId]
end

function CTeamServStateCtrl:AddServState(oServState)
    local sStateId = oServState:ID()
    self.m_mServStates[sStateId] = oServState
end

function CTeamServStateCtrl:RemoveServState(sStateId)
    self.m_mServStates[sStateId] = nil
end

function CTeamServStateCtrl:Foreach(sAction, sReasonPatt, pid, mArgs)
    for sStateId, oTeamServState in pairs(self.m_mServStates) do
        local fFunc = oTeamServState[sAction]
        local bFobid, sReason
        if fFunc then
            bFobid, sReason = fFunc(oTeamServState, pid, mArgs)
        else
            bFobid, sReason = oTeamServState:FobidTeamAction(pid, sAction, mArgs)
        end
        if bFobid then
            if not sReason and sReasonPatt then
                sReason = string.format(sReasonPatt, oTeamServState:GetName())
            end
            return true, sReason
        end
    end
end

local mFobidReasons = {
    FobidBackTeam = "%s中，无法归队",
    FobidShortLeaveTeam = "%s中，无法暂离",
    FobidLeaveTeam = "%s中，无法离队",
    FobidKickoutTeam = "%s中，无法请离",
    FobidApplyTeam = "对方%s中，无法申请",
    FobidApplyTeamPass = "%s中，无法通过申请",
    FobidSummonTeam = "对方%s中，无法召回",
    FobidTeamInvite = "%s中，无法邀请",
    FobidTeamInvitePass = "对方%s中，无法加入",
    -- FobidAutoTeam = "对方%s中，无法加入",
    FobidAutoTeamStart = "%s中，无法自动组队",
}

function CTeamServStateCtrl:FobidTeamAction(pid, sAction, mArgs)
    local sReasonPatt = mFobidReasons[sAction]
    return self:Foreach(sAction, sReasonPatt, pid, mArgs)
end

-- function CTeamServStateCtrl:FobidBackTeam(pid, mArgs)
--     local sReasonPatt = "%s中，无法归队"
--     return self:Foreach("FobidBackTeam", sReasonPatt, pid, mArgs)
-- end

-- function CTeamServStateCtrl:FobidShortLeaveTeam(pid, mArgs)
--     local sReasonPatt = "%s中，无法暂离"
--     return self:Foreach("FobidShortLeaveTeam", sReasonPatt, pid, mArgs)
-- end
