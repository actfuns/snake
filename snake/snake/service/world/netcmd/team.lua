--import module

local global = require "global"
local skynet = require "skynet"
local interactive = require "base.interactive"
local res = require "base.res"

local handleteam = import(service_path("team.handleteam"))


function C2GSCreateTeam(oPlayer,mData)
    local iTargetID = mData.auto_target
    local oTeamMgr = global.oTeamMgr
    oTeamMgr:CreateTeam(oPlayer.m_iPid, iTargetID, 1)
end

function C2GSApplyTeam(oPlayer,mData)
    local iTeamID = mData["teamid"]
    local iAutoTargetID = mData["auto_target"]
    local iAuto = mData["auto"]
    local pid = oPlayer:GetPid()

    handleteam.ApplyTeam(oPlayer, iTeamID, iAutoTargetID, iAuto)
end

function C2GSCancelApply(oPlayer, mData)
    local oWorldMgr = global.oWorldMgr
    local oNotifyMgr = global.oNotifyMgr
    local oTeamMgr = global.oTeamMgr

    local iTeamID = mData["teamid"]
    local iTargetID = mData["auto_target"]
    local iAuto = mData["auto"]

   oTeamMgr:CancelApply(oPlayer, iTeamID, iTargetID, iAuto)
end

function C2GSTeamApplyInfo(oPlayer)
    local oTeam = oPlayer:HasTeam()
    if oTeam then
        local oApplyMgr = oTeam:GetApplyMgr()
        oApplyMgr:SendApplyInfo(oPlayer,true)
    end
end

function C2GSApplyTeamPass(oPlayer,mData)
    local target = mData["pid"]
    handleteam.ApplyTeamPass(oPlayer, target)
end

function C2GSClearApply(oPlayer,mData)
    local oTeamMgr = global.oTeamMgr

    oTeamMgr:ClearApply(oPlayer)
end

function C2GSInviteTeam(oPlayer,mData)
    local iTarget = mData["target"]
    handleteam.InviteTeam(oPlayer, iTarget)
end

function C2GSTeamInviteInfo(oPlayer,mData)
    -- local pid = oPlayer:GetPid()
    -- local oTeamMgr = global.oTeamMgr
    -- local oInviteMgr = oTeamMgr:GetInviteMgr(pid)
    -- if not oInviteMgr then
    --     return
    -- end

    -- oInviteMgr:SendInviteInfo(oPlayer)
end

function C2GSInvitePass(oPlayer,mData)
    -- local oTeamMgr = global.oTeamMgr
    -- local oNotifyMgr = global.oNotifyMgr
    -- local oWorldMgr = global.oWorldMgr
    -- local oChatMgr = global.oChatMgr
    -- local oToolMgr = global.oToolMgr

    -- local iTeamID = mData["teamid"]
    -- handleteam.InvitePass(oPlayer, iTeamID)
end

function C2GSClearInvite(oPlayer)
    -- local oNotifyMgr = global.oNotifyMgr
    -- local oTeamMgr = global.oTeamMgr
    -- local iPid = oPlayer:GetPid()
    -- oTeamMgr:ClearInvite(oPlayer)
    -- oNotifyMgr:Notify(iPid,"已清空全部信息")
end

function C2GSClearTeamInvite(oPlayer,mData)
    -- local iTeamID = mData.teamid 
    -- local iPid = oPlayer:GetPid()
    -- local oTeamMgr = global.oTeamMgr
    -- local oInviteMgr = oTeamMgr:GetInviteMgr(oPlayer:GetPid())
    -- if oInviteMgr then
    --     oInviteMgr:RemoveInvite(iTeamID,iPid)
    -- end
end

function C2GSShortLeave(oPlayer,mData)
    handleteam.ShortLeave(oPlayer)
end

function C2GSLeaveTeam(oPlayer,mData)
    handleteam.LeaveTeam(oPlayer)
end

function C2GSKickOutTeam(oPlayer,mData)
    local iTarget = mData["target"]

    handleteam.KickoutTeam(oPlayer, iTarget)
end

function C2GSBackTeam(oPlayer,mData)
    local oTeamMgr = global.oTeamMgr
    handleteam.TeamBack(oPlayer)
end

function C2GSSetLeader(oPlayer,mData)
    local iTarget = mData["target"]
    local oTeamMgr = global.oTeamMgr
    oTeamMgr:SetLeader(oPlayer, iTarget)
end

function C2GSTeamSummon(oPlayer,mData)
    local target = mData.pid or 0
    handleteam.TeamSummon(oPlayer,mData.pid)
end

function C2GSApplyLeader(oPlayer)
    local oTeamMgr = global.oTeamMgr
    local pid = oPlayer:GetPid()
    local oTeam = oPlayer:HasTeam()
    if oTeam and not oTeam:IsLeader(pid) then
        handleteam.ApplyLeader(pid, oTeam)
    end
end

function C2GSTeamAutoMatch(oPlayer,mData)
    handleteam.TeamAutoMatch(oPlayer, mData)
end

function C2GSTeamCancelAutoMatch(oPlayer, mData)
    handleteam.TeamCancelAutoMatch(oPlayer)
end

function C2GSPlayerAutoMatch(oPlayer, mData)
    local iTargetID = mData["auto_target"]
    handleteam.PlayerAutoMatch(oPlayer, iTargetID)
end

function C2GSPlayerCancelAutoMatch(oPlayer, mData)
    if oPlayer.m_oActiveCtrl:GetInfo("auto_matching", false) then
        handleteam.PlayerCancelAutoMatch(oPlayer)
    end
end

function C2GSGetTargetTeamInfo(oPlayer, mData)
    local iTargetID = mData["auto_target"]
    handleteam.GetTargetTeamInfo(oPlayer, iTargetID)
end

function C2GSTeamInfo(oPlayer, mData)
    local iTeamID = mData["teamid"]

    handleteam.GetTeamInfo(oPlayer, iTeamID)
end

function C2GSSetAppointMem(oPlayer, mData)
    local iTargetPid = mData["pid"]
    local iAppoint = mData["appoint"]
    handleteam.SetAppointMem(oPlayer, iTargetPid, iAppoint)
end

function C2GSSetTeamWarCmd(oPlayer, mData)
    local extend = require "base.extend"
    local mLimit = {5,5}
    local type = mData["type"]
    if not mLimit[type] then
        return
    end
    local pos = mData["pos"]-mLimit[type]
    local sCmd = mData.cmd or ""
    local mWarCommand = oPlayer.m_oBaseCtrl:GetData("war_command",{{},{}})
    if sCmd == "" then
        if mWarCommand[type] and mWarCommand[type][pos] then
            table.remove(mWarCommand[type], pos)
            oPlayer.m_oBaseCtrl:SetData("war_command",mWarCommand)
            oPlayer:Send("GS2CRefreshDelWarCmd",{type=type,pos=mData["pos"]})
        end
    else
        if mWarCommand[type] and mWarCommand[type][pos] then
            mWarCommand[type][pos] = sCmd
            oPlayer.m_oBaseCtrl:SetData("war_command",mWarCommand)
            local mNet = {
            type = type,
            pos = pos+mLimit[type],
            cmd = sCmd,
            }
            oPlayer:Send("GS2CRefreshTeamWarCmd",mNet)
        end
    end
end

function C2GSAddTeamWarCmd(oPlayer, mData)
    local mLimit = {5,5}
    local type = mData["type"]
    if not mLimit[type] then
        return
    end
    local sCmd = mData["cmd"]
    local pid = oPlayer:GetPid()
    local mWarCommand = oPlayer.m_oBaseCtrl:GetData("war_command",{{},{}})
    if #mWarCommand[type]>=mLimit[type] then
        return
    end
    table.insert(mWarCommand[type],sCmd)
    oPlayer.m_oBaseCtrl:SetData("war_command",mWarCommand)
    local mNet={
        type = type,
        pos = #mWarCommand[type]+mLimit[type],
        cmd = sCmd,
    }
    oPlayer:Send("GS2CRefreshTeamWarCmd",mNet)
end

