--import module
local global = require "global"
local skynet = require "skynet"
local record = require "public.record"
local interactive = require "base.interactive"

local handleteam = import(service_path("team/handleteam"))

function AutoMatchSuccess(mRecord, mData)
    local iTargetID = mData.targetid
    local pid = mData.pid
    local iTeamID = mData.teamid
    local oWorldMgr = global.oWorldMgr
    local oNotifyMgr = global.oNotifyMgr
    local oTeamMgr = global.oTeamMgr
    local oTeam = oTeamMgr:GetTeam(iTeamID)
    local oPlayer = oWorldMgr:GetOnlinePlayerByPid(pid)
    if not oTeam then
        return 
    end
    local oLeader = oTeam:GetLeaderObj()
    if not oPlayer then
        return
    end
    local oNowScene1 = oPlayer.m_oActiveCtrl:GetNowScene()
    local oNowScene2 = oLeader.m_oActiveCtrl:GetNowScene()
    if oPlayer:HasTeam() then
        --record.warning(string.format("AutoMatchSuccess repeat %s %s %s %s",iTeamID,pid,oNowScene1:MapId(),oNowScene2:MapId()))
        handleteam.PlayerCancelAutoMatch(oPlayer,true)
        return 
    end
    if 1 ~= (oPlayer.m_iTeamAllowed or 1) then
        --record.warning(string.format("AutoMatchSuccess notallowed_player %s %s %s %s",iTeamID,pid,oNowScene1:MapId(),oNowScene2:MapId()))
        handleteam.PlayerCancelAutoMatch(oPlayer,true)
        return
    end
    if 1 ~= (oLeader.m_iTeamAllowed or 1) then
        --record.warning(string.format("AutoMatchSuccess notallowed_team %s %s %s %s",iTeamID,oLeader:GetPid(),oNowScene1:MapId(),oNowScene2:MapId()))
        oTeam:CancleAutoMatch()
        return
    end
    local bFobid, sReason = global.oTeamMgr:FobidTeamAction(iTeamID, oPlayer:GetPid(), "FobidAutoTeam")
    if bFobid then
        handleteam.PlayerCancelAutoMatch(oPlayer, true)
        return
    end
    if oTeam:TeamSize() >= 5 then
        if oTeam:AutoMatchEnough() then
            oTeam:CancleAutoMatch()
        end
        return
    end
    if oTeam and oPlayer then
        if oTeam:AutoMatchEnough() then
            return
        end
        local iTeamTargetID = oTeam:GetTargetID()
        local iPlayerTargetID = oPlayer.m_oActiveCtrl:GetInfo("auto_targetid")
        if iTeamTargetID and iPlayerTargetID and iPlayerTargetID == iTeamTargetID and iTeamTargetID == iTargetID then
            oPlayer.m_oActiveCtrl:SetInfo("match_team",iTeamID)
            local oScene1 = oPlayer
            if oPlayer.m_oActiveCtrl:GetNowWar() then
                oTeam:AddShortLeave(oPlayer)
                oNotifyMgr:Notify(oPlayer:GetPid(), "你已加入队伍，战斗结束后请尽快归队")
            elseif oPlayer:IsFixed() then
                oTeam:AddShortLeave(oPlayer)
                oNotifyMgr:Notify(oPlayer:GetPid(), "你已加入队伍，请尽快归队")
            elseif oTeam:InWar() then
                oTeam:AddShortLeave(oPlayer)
                oTeamMgr:TeamBack(oPlayer)
            else
                if not oTeam:ValidTransToLeader(oPlayer) then
                    oTeam:AddShortLeave(oPlayer)
                else
                    oTeamMgr:AddTeamMember(iTeamID, pid )
                end
            end
            if oTeam:AutoMatchEnough() then
                oTeam:CancleAutoMatch()
            end
            handleteam.PlayerCancelAutoMatch(oPlayer,true)
        end
    end
end

function TeamAutoMatchTimeOut(mRecord, mData)
    local iTargetID = mData.targetid
    local iTeamID = mData.teamid
    local oTeamMgr = global.oTeamMgr
    local oTeam = oTeamMgr:GetTeam(iTeamID)
    if oTeam and oTeam:AutoMatching() then
        local iTeamTargetID = oTeam:GetTargetID()
        if iTeamTargetID and iTeamTargetID == iTargetID then
            oTeam:CancleAutoMatch()
            local oNotifyMgr = global.oNotifyMgr
            oNotifyMgr:Notify(oTeam:Leader(), "匹配超时，已停止自动匹配")
        end
    end
end

function NotifyAutoMatchTeam(mRecord, mData)
    local oWorldMgr = global.oWorldMgr
    local oNotifyMgr = global.oNotifyMgr
    local oTeamMgr = global.oTeamMgr
    local iTargetID = mData.targetid
    local iTeamID = mData.teamid
    local oTeam = oTeamMgr:GetTeam(iTeamID)
    if oTeam and oTeam:TeamSize() == 1 then
        local iLeader = oTeam:Leader()
        local oPlayer = oWorldMgr:GetOnlinePlayerByPid(iLeader)
        if oPlayer then
            local oNotifyMgr = global.oNotifyMgr
            oNotifyMgr:Notify(iLeader, "现在匹配人数较少，快去加入别人的队伍吧")
        end
    else
        interactive.Send(".autoteam", "team", "CancleTeamAutoMatch", {targetid = iTargetID, teamid = iTeamID})
    end
end

function NotifyAutoMatchMember(mRecord, mData)
    local oWorldMgr = global.oWorldMgr
    local oNotifyMgr = global.oNotifyMgr
    local iTargetID = mData.targetid
    local pid = mData.pid
    local oPlayer = oWorldMgr:GetOnlinePlayerByPid(pid)
    if oPlayer then
        local iPlayerTargetID = oPlayer.m_oActiveCtrl:GetInfo("auto_targetid")
        if iPlayerTargetID and iPlayerTargetID == iTargetID then
            local oNotifyMgr = global.oNotifyMgr
            oNotifyMgr:Notify(pid, "现在匹配人数较多，快去当队长吧")
        end
    end
end

function MemAutoMatchTimeOut(mRecord, mData)
    local oWorldMgr = global.oWorldMgr
    local oNotifyMgr = global.oNotifyMgr    
    local iTargetID = mData.targetid
    local pid = mData.pid
    local oPlayer = oWorldMgr:GetOnlinePlayerByPid(pid)
    if oPlayer then
        local iPlayerTargetID = oPlayer.m_oActiveCtrl:GetInfo("auto_targetid")
        if iPlayerTargetID and iPlayerTargetID == iTargetID then
            oNotifyMgr:Notify(pid, "匹配超时，已停止自动匹配")
            oPlayer:SetAutoMatching(0, false)
        end
    end
end

function TeamupSuccessWithoutLeader(mRecord, mData)
    local iTarget = mData.target
    local lMember = mData.member
    local lTarget = {}
    for _, iPid in ipairs(lMember) do
        local oPlayer = global.oWorldMgr:GetOnlinePlayerByPid(iPid)
        if not oPlayer then
            goto continue
        end
        if oPlayer:HasTeam() then
            goto continue
        end
        if (oPlayer.m_iTeamAllowed or 1) ~= 1 then
            goto continue
        end
        table.insert(lTarget, oPlayer)
        ::continue::
    end
    if #lTarget <= 0 then return end

    local oLeader = lTarget[math.random(#lTarget)]
    global.oTeamMgr:CreateTeam(oLeader:GetPid(), iTarget, 1)

    local oTeam = oLeader:HasTeam()
    for _, oMember in ipairs(lTarget) do
        if oMember:GetPid() ~= oLeader:GetPid() then
            local mData = {
                pid = oMember:GetPid(),
                targetid = iTarget,
                teamid = oTeam:TeamID(),
            }
            AutoMatchSuccess({}, mData)
        end
    end
end


