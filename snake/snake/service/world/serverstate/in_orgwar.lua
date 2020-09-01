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
    return "帮派竞赛场景中"
end

function CTeamServState:ValidSave()
    return false
end

function CTeamServState:FobidApplyTeam(iPid, mArgs)
    local sReason = "帮派竞赛场景中，非同帮派队员不能申请入队"
    local iTeamId = self:GetTeamId()
    local oTeam = global.oTeamMgr:GetTeam(iTeamId)
    if not oTeam then return false end

    local iLeader = oTeam:Leader()
    if not iLeader then return false end

    local oLeader = global.oWorldMgr:GetOnlinePlayerByPid(iLeader)
    local oPlayer = global.oWorldMgr:GetOnlinePlayerByPid(iPid)
    if not oLeader or not oPlayer then return false end

    local oScene = oLeader.m_oActiveCtrl:GetNowScene()
    if oScene and oScene:GetVirtualGame() == "orgwar" then
        if oLeader:GetOrgID() ~= oPlayer:GetOrgID() then
            return true, sReason
        end
    end

    return false
end

function CTeamServState:FobidBackTeam(iPid, mArgs)
    local sReason = "帮派竞赛场景中，非同帮派队员不能归队"
    local iTeamId = self:GetTeamId()
    local oTeam = global.oTeamMgr:GetTeam(iTeamId)
    if not oTeam then return false end

    local iLeader = oTeam:Leader()
    if not iLeader then return false end

    local oLeader = global.oWorldMgr:GetOnlinePlayerByPid(iLeader)
    local oPlayer = global.oWorldMgr:GetOnlinePlayerByPid(iPid)
    if not oLeader or not oPlayer then return false end

    local oLeaderScene = oLeader.m_oActiveCtrl:GetNowScene()
    local oPlayerScene = oPlayer.m_oActiveCtrl:GetNowScene()

    if not oLeaderScene or not oPlayerScene then return false end

    if oLeaderScene:GetVirtualGame() == "orgwar" then
        if oLeaderScene:GetSceneId() ~= oPlayerScene:GetSceneId() then
            return true, "队长帮派竞赛中，不同场景玩家不能归队"
        else
            if oLeader:GetOrgID() ~= oPlayer:GetOrgID() then
                return true, "队长帮派竞赛中，非同帮派队员不能归队"
            end
        end
    else
        if oPlayerScene:GetVirtualGame() == "orgwar" then
            return true, "帮派竞赛场景中，非同帮派队员不能归队"
        end
    end
    return false
end

function CTeamServState:FobidShortLeaveTeam(pid, mArgs)
    return false
end

function CTeamServState:FobidApplyTeamPass(iPid, mArgs)
    local sReason = "帮派竞赛场景中，不能同意非同帮派成员入队"
    local iTeamId = self:GetTeamId()
    local oTeam = global.oTeamMgr:GetTeam(iTeamId)
    if not oTeam then return false end

    local iLeader = oTeam:Leader()
    if not iLeader then return false end

    local oLeader = global.oWorldMgr:GetOnlinePlayerByPid(iLeader)
    local oPlayer = global.oWorldMgr:GetOnlinePlayerByPid(iPid)
    if not oLeader or not oPlayer then return false end

    local oLeaderScene = oLeader.m_oActiveCtrl:GetNowScene()
    if not oLeaderScene then return false end

    if oLeaderScene:GetVirtualGame() == "orgwar" then
        if oLeader:GetOrgID() ~= oPlayer:GetOrgID() then
            return true, sReason
        end
    end
    return false
end

function CTeamServState:FobidTeamInvite(iPid, mArgs)
    local sReason = "帮派竞赛场景中，不能邀请非同帮派成员入队"
    local iTeamId = self:GetTeamId()
    local oTeam = global.oTeamMgr:GetTeam(iTeamId)
    if not oTeam then return false end

    local iLeader = oTeam:Leader()
    if not iLeader then return false end

    local oLeader = global.oWorldMgr:GetOnlinePlayerByPid(iLeader)
    local oPlayer = global.oWorldMgr:GetOnlinePlayerByPid(iPid)
    if not oLeader or not oPlayer then return false end

    local oLeaderScene = oLeader.m_oActiveCtrl:GetNowScene()
    if not oLeaderScene then return false end
   
    if oLeaderScene:GetVirtualGame() == "orgwar" then
        if oLeader:GetOrgID() ~= oPlayer:GetOrgID() then
            return true, sReason
        end
    end
    return false
end

function CTeamServState:FobidTeamInvitePass(iPid, mArgs)
    local sReason = "队长位于帮派竞赛场景中，非同帮派成员不能入队"
    local iTeamId = self:GetTeamId()
    local oTeam = global.oTeamMgr:GetTeam(iTeamId)
    if not oTeam then return false end

    local iLeader = oTeam:Leader()
    if not iLeader then return false end

    local oLeader = global.oWorldMgr:GetOnlinePlayerByPid(iLeader)
    local oPlayer = global.oWorldMgr:GetOnlinePlayerByPid(iPid)
    if not oLeader or not oPlayer then return false end

    local oLeaderScene = oLeader.m_oActiveCtrl:GetNowScene()
    if not oLeaderScene then return false end
   
    if oLeaderScene:GetVirtualGame() == "orgwar" then
        if oLeader:GetOrgID() ~= oPlayer:GetOrgID() then
            return true, sReason
        end
    end
    return false
end

function CTeamServState:FobidAutoTeam(iPid, mArgs)
    local sReason = "队长位于帮派竞赛场景中，非同帮派成员不能入队"
    local iTeamId = self:GetTeamId()
    local oTeam = global.oTeamMgr:GetTeam(iTeamId)
    if not oTeam then return false end

    local iLeader = oTeam:Leader()
    if not iLeader then return false end

    local oLeader = global.oWorldMgr:GetOnlinePlayerByPid(iLeader)
    local oPlayer = global.oWorldMgr:GetOnlinePlayerByPid(iPid)
    if not oLeader or not oPlayer then return false end

    local oLeaderScene = oLeader.m_oActiveCtrl:GetNowScene()
    if not oLeaderScene then return false end

    if oLeaderScene:GetVirtualGame() == "orgwar" then
        if oLeader:GetOrgID() ~= oPlayer:GetOrgID() then
            return true, sReason
        end
    end
    return false
end

function CTeamServState:FobidAutoTeamStart(iPid, mArgs)
    local iTeamId = self:GetTeamId()
    local oTeam = global.oTeamMgr:GetTeam(iTeamId)
    if not oTeam then return false end

    local iLeader = oTeam:Leader()
    if not iLeader then return false end

    local oLeader = global.oWorldMgr:GetOnlinePlayerByPid(iLeader)
    if not oLeader then return false end

    local oLeaderScene = oLeader.m_oActiveCtrl:GetNowScene()
    if not oLeaderScene then return false end

    if oLeaderScene:GetVirtualGame() == "orgwar" then
        return true, "帮派竞赛场景中，不能开启自动匹配"
    end
    return false
end

local mFobidActions = {
    FobidShortLeaveTeam = false,
    FobidLeaveTeam = false,
    FobidKickoutTeam = false,
    FobidSummonTeam = false,
    FobidAutoTeamStart = true,
}

function CTeamServState:FobidTeamAction(pid, sAction, mArgs)
    return mFobidActions[sAction]
end
