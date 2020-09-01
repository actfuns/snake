local global = require "global"
local res = require "base.res"
local interactive = require "base.interactive"

local votebox = import(service_path("team.votebox"))
local gamedefines = import(lualib_path("public.gamedefines"))

local INVITE_NORMAL     = 0
local INVITE_OFFLINE      =1
local INVITE_FULL        = 2
local INVITE_INTEAM       = 3

function ApplyTeam(oPlayer, iTeamID, iAutoTargetID, iAuto)
    local oTeamMgr = global.oTeamMgr
    local oNotifyMgr = global.oNotifyMgr
    local iApplyTime = oTeamMgr:GetApplyTime(oPlayer:GetPid(),iTeamID)
    if iApplyTime > get_time() then
        oNotifyMgr:Notify(oPlayer:GetPid(), "申请太频繁，请稍后再试")
        return
    end

    local oTeam = global.oTeamMgr:GetTeam(iTeamID)
    if not oTeam then return end

    local iLeader = oTeam:Leader()
    if is_gs_server() and global.oEngageMgr:GetEngageByPid(iLeader) then
        oPlayer:NotifyMessage(global.oToolMgr:GetTextData(1131,{"team"}))
        return
    end
    if is_gs_server() and global.oMarryMgr:IsMarry(iLeader) then
        oPlayer:NotifyMessage(global.oToolMgr:GetTextData(1133,{"team"}))
        return
    end

    if (oPlayer.m_iTeamAllowed or 1) ~= 1 then
        oNotifyMgr:Notify(oPlayer:GetPid(), "当前场景不能组队")
        return 
    end

    local bFobid, sReason = global.oTeamMgr:FobidTeamAction(iTeamID, oPlayer:GetPid(), "FobidApplyTeam")
    if bFobid then
        if sReason then
            oPlayer:NotifyMessage(sReason)
        end
        return false
    end
    oTeamMgr:ApplyTeam(oPlayer, iTeamID, iAutoTargetID, iAuto)
end


function ApplyTeamPass(oPlayer, target)
    local iPid = oPlayer:GetPid()
    local oTeam = oPlayer:HasTeam()
    if not oTeam then
        oPlayer:NotifyMessage("你已不在队伍中，不能通过邀请")
        return
    end
    local iTeamID = oTeam:TeamID()
    local bFobid, sReason = global.oTeamMgr:FobidTeamAction(iTeamID, iPid, "FobidApplyTeamPass")
    if bFobid then
        if sReason then
            oPlayer:NotifyMessage(sReason)
        end
        return false
    end
    global.oTeamMgr:ApplyTeamPass(oPlayer, target)
end

function InviteTeam(oPlayer, iTarget)
    local oWorldMgr = global.oWorldMgr
    local oTeamMgr = global.oTeamMgr
    local oNotifyMgr = global.oNotifyMgr
    local iPid = oPlayer:GetPid()
    local oTarget = oWorldMgr:GetOnlinePlayerByPid(iTarget)

    if not oTarget then
        --oPlayer:Send("GS2CInviteeStatus",  {target = iTarget,target_status = INVITE_OFFLINE})
        oNotifyMgr:Notify(iPid,"该玩家已经下线")
        return
    end

    local oTeam = oPlayer:HasTeam()
    if not oTeam then
        oTeamMgr:CreateTeam(iPid)
    end
    oTeam = oPlayer:HasTeam()
    if not oTeam then
        oNotifyMgr:Notify(iPid,"创建队伍失败")
        return
    end
    local iTeamID = oTeam:TeamID()
    local oTargetTeam = oTarget:HasTeam()
    if oTargetTeam then
        --oPlayer:Send("GS2CInviteeStatus",  {target = iTarget,target_status = INVITE_NORMAL})
        oNotifyMgr:Notify(iPid, "该玩家已加入其它队伍")
        return
    end

    if (oPlayer.m_iTeamAllowed or 1) ~= 1 then
        oNotifyMgr:Notify(iPid, "当前场景不能邀请组队")
        return 1
    end
    -- local oInviteMgr = oTeamMgr:GetInviteMgr(iTarget)
    -- if not oInviteMgr:ValidInvite() then
    --     oPlayer:Send("GS2CInviteeStatus",  {target = iTarget,target_status = INVITE_NORMAL})
    --     oNotifyMgr:Notify(iPid,"该玩家邀请列表已满")
    --     return
    -- end
    if oTeam:TeamSize() >= oTeam:MaxTeamSize() then
         oNotifyMgr:Notify(iPid,"队伍人数已满。")       
        return
    end
    if oTarget.m_bInviteState  and (get_time()-oTarget.m_bInviteState)<3*60  then
        oNotifyMgr:Notify(iPid,global.oToolMgr:GetTextData(1126,{"team"}))
        return
    end

    local iLeader = oTeam:Leader()
    if is_gs_server() and global.oEngageMgr:GetEngageByPid(iLeader) then
        oNotifyMgr:Notify(iPid, global.oToolMgr:GetTextData(1130,{"team"}))
        return
    end

    if is_gs_server() and global.oMarryMgr:IsMarry(iLeader) then
        oPlayer:NotifyMessage(global.oToolMgr:GetTextData(1132,{"team"}))
        return
    end

    -- if oInviteMgr:HasInvite(oTeam:TeamID()) then
    --     if oInviteMgr:IsValidate(oTeam:TeamID()) then
    --         oPlayer:Send("GS2CInviteeStatus",  {target = iTarget,target_status = INVITE_NORMAL})
    --         oNotifyMgr:Notify(iPid,"已在邀请列表中，请耐心等待回复")
    --         return
    --     end
    -- end

    local bFobid, sReason = global.oTeamMgr:FobidTeamAction(iTeamID, iTarget, "FobidTeamInvite")
    if bFobid then
        if sReason then
            oPlayer:NotifyMessage(sReason)
        end
        return false
    end

    local iText = 0
    local sText
    local oLeader  = oTeam:GetLeaderObj()
    local oToolMgr = global.oToolMgr
    if oPlayer:GetPid() ~= oLeader:GetPid() then
        sText = oToolMgr:GetTextData(1207,{"team"})
        sText = oToolMgr:FormatColorString(sText["sContent"],{role={oPlayer:GetName(),oLeader:GetName()}})
    else
        sText = oToolMgr:GetTextData(1208,{"team"})
        sText = oToolMgr:FormatColorString(sText["sContent"],{role=oPlayer:GetName()})
    end
    local mData = {}
    mData["sContent"] = sText
    mData["sConfirm"] = "同意"
    mData["sCancle"] = "拒绝"
    mData["time"] = 15
    mData["default"] = 0
    mData["extend_close"] = 3
    -- oInviteMgr:AddInvitor(oTeam,oPlayer)
    -- oPlayer:Send("GS2CInviteeStatus",  {target = iTarget,target_status = INVITE_NORMAL})
    oNotifyMgr:Notify(iPid,string.format("已邀请%s加入队伍，请耐心等待回复",oTarget:GetName()))
    mData = global.oCbMgr:PackConfirmData(iTarget, mData)
    local iTeamID = oTeam:TeamID()
    local func = function(oPlayer, mData)
            _InviteTeam(oPlayer, mData,iPid)
    end
    oTarget.m_bInviteState = get_time()
    global.oCbMgr:SetCallBack(iTarget,"GS2CConfirmUI",mData,nil,func)
end

function InvitePass(oPlayer, iTarget)
    local oWorldMgr = global.oWorldMgr
    local oTeamMgr = global.oTeamMgr
    local oToolMgr = global.oToolMgr
    local oNotifyMgr = global.oNotifyMgr
    local oChatMgr = global.oChatMgr
    local iPid = oPlayer:GetPid()
    local oTeam = oPlayer:HasTeam()
    if oTeam then
        oNotifyMgr:Notify(iPid,"你已经在队伍中，不能通过邀请")
        return
    end
    local oTarget = global.oWorldMgr:GetOnlinePlayerByPid(iTarget)
    if not oTarget then
        oNotifyMgr:Notify(iPid,"队伍已经解散")
        return
    end
    
    -- local oInviteMgr = oTeamMgr:GetInviteMgr(iPid)
    -- local mData = oInviteMgr:HasInvite(iTeamID)
    -- if not mData then return end

    local oTeam = oTarget:HasTeam()
    if not oTeam then
        oNotifyMgr:Notify(iPid,"队伍已经解散")
        return
    end
    local iTeamID = oTeam:TeamID()

    if oTeam:TeamSize() >= oTeam:MaxTeamSize() then
        oNotifyMgr:Notify(iPid,"该队伍人数已满")
        return
    end

    local iLeader = oTeam:Leader()
    if is_gs_server() and (global.oEngageMgr:GetEngageByPid(iLeader) or global.oMarryMgr:IsMarry(iLeader)) then
        oNotifyMgr:Notify(iPid,"邀请已失效")
        return
    end
    if (oPlayer.m_iTeamAllowed or 1) ~= 1 then
        oNotifyMgr:Notify(iPid, "当前场景不能组队")
        return
    end

    -- if oInviteMgr:IsOutTime(iTeamID) then
    --     oNotifyMgr:Notify(iPid,"邀请已失效")
    --     return
    -- end

    local bFobid, sReason = global.oTeamMgr:FobidTeamAction(iTeamID, iPid, "FobidTeamInvitePass")
    if bFobid then
        if sReason then
            oPlayer:NotifyMessage(sReason)
        end
        return false
    end

    local oApplyMgr = oTeam:GetApplyMgr()
    if oApplyMgr and oApplyMgr:HasApply(iPid) then
        oApplyMgr:RemoveApply(iPid)
    end

    --oInviteMgr:RemoveInvite(iTeamID,iPid)
    if oTeam:IsLeader(iTarget) then
        local oState = oPlayer.m_oStateCtrl:GetState(1002)
        if oPlayer.m_oActiveCtrl:GetNowWar() then
            oTeam:AddShortLeave(oPlayer)
            oNotifyMgr:Notify(oPlayer:GetPid(), "你已加入队伍，战斗结束后请尽快归队")
        elseif oTeam:InWar() then
            oTeam:AddShortLeave(oPlayer)
            oTeamMgr:TeamBack(oPlayer)
        elseif oPlayer:IsFixed() then
            oTeam:AddShortLeave(oPlayer)
            oNotifyMgr:Notify(oPlayer:GetPid(), "你已加入队伍，请尽快归队")
        else
            if not oTeam:ValidTransToLeader(oPlayer,1) then
                oTeam:AddShortLeave(oPlayer)
            else
                oTeamMgr:AddTeamMember(iTeamID, iPid )
            end
        end
        --oInviteMgr:ClearInviteInfo() 
    else
        oTeamMgr:ApplyTeam(oPlayer,iTeamID, 0, 0,true)
        oNotifyMgr:Notify(iPid,"已接受邀请，请等待队长同意")
    end
end

function ShortLeave(oPlayer)
    local oNotifyMgr = global.oNotifyMgr
    local oToolMgr = global.oToolMgr
    local oChatMgr = global.oChatMgr
    local oTeamMgr = global.oTeamMgr
    local pid = oPlayer:GetPid()
    local oTeam = oPlayer:HasTeam()
    if not oTeam then return end
    local iTeamID = oTeam:TeamID()
    if oTeam:IsLeader(pid) then return end
    if not oTeam:IsTeamMember(pid) then return end
    local bFobid, sReason = global.oTeamMgr:FobidTeamAction(iTeamID, pid, "FobidShortLeaveTeam")
    if bFobid then
        if sReason then
            oPlayer:NotifyMessage(sReason)
        end
        return false
    end

    if oTeam:InWar() then
        local oMem = oTeam:GetMember(pid)
        local flag = oTeamMgr:GetCBFlag(gamedefines.TEAM_CB_FLAG.SHORTLEAVE,pid)
        if oTeam:HasCB(gamedefines.TEAM_CB_TYPE.LEAVE_WAR,flag) then
            oTeam:DelCB(gamedefines.TEAM_CB_TYPE.LEAVE_WAR,flag)
            oNotifyMgr:Notify(pid,"你取消了暂离队伍操作")
            oMem:SetShortLeaveButtonState(oPlayer,0)
            return
        end

        local iStatus = oTeam:GetWarStatus()
        if iStatus == gamedefines.WAR_STATUS.IN_OBSERVER then
            if oPlayer.m_oActiveCtrl:GetWarStatus() == gamedefines.WAR_STATUS.NO_WAR then
                goto true_shortleave
            end
        end

        local func
        func = function (args,oTeam)
            local pid = args.pid
            local oWorldMgr = global.oWorldMgr
            local oPlayer=oWorldMgr:GetOnlinePlayerByPid(pid)
            if not oPlayer then return end
            ShortLeave(oPlayer)
        end
        oTeam:AddCB(gamedefines.TEAM_CB_TYPE.LEAVE_WAR,flag,func,{pid=pid})
        if iStatus == gamedefines.WAR_STATUS.IN_OBSERVER then
            oNotifyMgr:Notify(pid,"观战结束后暂离队伍")
        else
            oNotifyMgr:Notify(pid,"战斗结束后暂离队伍")
        end
        oMem:SetShortLeaveButtonState(oPlayer,1)
        return
    end

    ::true_shortleave::
    oTeam:ShortLeave(pid)
    local sMsg = oToolMgr:FormatColorString("#role暂时离队", {role=oPlayer:GetName()})
    oChatMgr:HandleTeamChat(oPlayer, sMsg, true)
    oNotifyMgr:Notify(pid,"你暂离了队伍")
end

function LeaveTeam(oPlayer)
    local oNotifyMgr = global.oNotifyMgr
    local oToolMgr = global.oToolMgr
    local oChatMgr = global.oChatMgr
    local oTeamMgr = global.oTeamMgr
    local oTeam = oPlayer:HasTeam()
    if not oTeam then return end
    local iTeamID = oTeam:TeamID()
    local pid = oPlayer:GetPid()
    local bFobid, sReason = global.oTeamMgr:FobidTeamAction(iTeamID, pid, "FobidLeaveTeam")
    if bFobid then
        if sReason then
            oPlayer:NotifyMessage(sReason)
        end
        return false
    end

    if oTeam:IsTeamMember(pid) and oTeam:InWar() then
        local oMem = oTeam:GetMember(pid)
        local flag = oTeamMgr:GetCBFlag(gamedefines.TEAM_CB_FLAG.LEAVE,pid)
        if oTeam:HasCB(gamedefines.TEAM_CB_TYPE.LEAVE_WAR,flag) then
            oTeam:DelCB(gamedefines.TEAM_CB_TYPE.LEAVE_WAR,flag)
            oNotifyMgr:Notify(pid,"你已取消退出队伍操作")
            oMem:SetLeaveButtonState(oPlayer,0)
            return
        end

        local iStatus = oTeam:GetWarStatus()
        if iStatus == gamedefines.WAR_STATUS.IN_OBSERVER then
            if oPlayer.m_oActiveCtrl:GetWarStatus() == gamedefines.WAR_STATUS.NO_WAR then
                goto true_leave
            end
        end

        local func
        func = function (args,oTeam)
            local pid = args.pid
            local oWorldMgr = global.oWorldMgr
            local oPlayer=oWorldMgr:GetOnlinePlayerByPid(pid)
            if not oPlayer then return end
            LeaveTeam(oPlayer)
        end
        oTeam:AddCB(gamedefines.TEAM_CB_TYPE.LEAVE_WAR,flag,func,{pid=pid})
        if iStatus == gamedefines.WAR_STATUS.IN_OBSERVER then
            oNotifyMgr:Notify(pid,"观战结束后自动退出队伍")
        else
            oNotifyMgr:Notify(pid,"战斗结束后自动退出队伍")
        end
        oMem:SetLeaveButtonState(oPlayer,1)
        return
    end

    ::true_leave::
    oTeam:Leave(pid)
    oPlayer.m_oActiveCtrl:SetInfo("match_team", 0)
    local sMsg = oToolMgr:FormatColorString("#role退出了队伍", {role=oPlayer:GetName()})
    oChatMgr:HandleTeamChat(oPlayer, sMsg, true)
end

function KickoutTeam(oPlayer, iTarget)
    local oNotifyMgr = global.oNotifyMgr
    local oWorldMgr = global.oWorldMgr
    local oChatMgr = global.oChatMgr
    local oToolMgr = global.oToolMgr
    local oCbMgr = global.oCbMgr
    local oTeamMgr = global.oTeamMgr
    local pid = oPlayer:GetPid()
    local iTeamID = oPlayer:TeamID()
    local oTeam = oPlayer:HasTeam()
    if not oTeam then return end

    if not oTeam:IsLeader(pid) then return end
    local oTMem=oTeam:GetMember(iTarget)
    if not oTMem then
        return
    end
    local bFobid, sReason = global.oTeamMgr:FobidTeamAction(iTeamID, iTarget, "FobidKickoutTeam")
    if bFobid then
        if sReason then
            oPlayer:NotifyMessage(sReason)
        end
        return false
    end
    if oTeam:IsTeamMember(iTarget) and oTeam:InWar() then
        local flag = oTeamMgr:GetCBFlag(gamedefines.TEAM_CB_FLAG.KICKOUT,iTarget)
        local oMem = oTeam:GetMember(pid)
        if oTeam:HasCB(gamedefines.TEAM_CB_TYPE.LEAVE_WAR,flag) then
            oTeam:DelCB(gamedefines.TEAM_CB_TYPE.LEAVE_WAR,flag)
            oNotifyMgr:Notify(pid,"你取消请离队伍操作")
            oMem:RemoveKick(oPlayer,iTarget)
            return
        end

        local iStatus = oTeam:GetWarStatus()
        local oTarget = oWorldMgr:GetOnlinePlayerByPid(iTarget)

        if oTarget and iStatus == gamedefines.WAR_STATUS.IN_OBSERVER then
            if oTarget.m_oActiveCtrl:GetWarStatus() == gamedefines.WAR_STATUS.NO_WAR then
                goto true_kick
            end
        end

        local func
        func = function (args,oTeam)
            local pid = args.pid
            local target = args.target
            local oWorldMgr = global.oWorldMgr
            local oPlayer=oWorldMgr:GetOnlinePlayerByPid(pid)
            if not oPlayer then return end
            KickoutTeam(oPlayer,target)
        end
        oTeam:AddCB(gamedefines.TEAM_CB_TYPE.LEAVE_WAR,flag,func,{pid=pid,target=iTarget})
        if iStatus == gamedefines.WAR_STATUS.IN_OBSERVER then
            oNotifyMgr:Notify(pid,"观战结束后生效")
        else
            oNotifyMgr:Notify(pid,"战斗结束后生效")
        end
        oMem:AddKick(oPlayer,iTarget)
        return
    end

    ::true_kick::
    local oTargetName = oTMem:GetName()
    oTeam:Leave(iTarget,true)
    oNotifyMgr:Notify(iTarget,string.format("你被请离了%s的队伍",oPlayer:GetName()))
    oNotifyMgr:Notify(pid,string.format("你把%s请离了队伍",oTargetName))
    local oTarget = oWorldMgr:GetOnlinePlayerByPid(iTarget)
    if oTarget then
        local iTargetID = oTarget.m_oActiveCtrl:GetInfo("auto_targetid", 0)
        local iMatchTeam = oTarget.m_oActiveCtrl:GetInfo("match_team", 0)
        if iMatchTeam == iTeamID then
            local mData = {}
            mData["sContent"] = "你被队长请离了队伍，是否继续匹配"
            mData["sConfirm"] = "匹配"
            mData["sCancle"] = "取消"
            mData["time"] = 30
            mData["default"] = 1
            mData = oCbMgr:PackConfirmData(iTarget, mData)
            local func = function(oPlayer, mData)
                if mData["answer"] == 1 then
                    PlayerAutoMatch(oPlayer, iTargetID)
                end
            end
            oCbMgr:SetCallBack(iTarget,"GS2CConfirmUI",mData,nil,func)
        end
        local sMsg = oToolMgr:FormatColorString("#role被请离队伍", {role = oTarget:GetName()})
        oChatMgr:HandleTeamChat(oPlayer, sMsg, true)
        oTarget.m_oActiveCtrl:SetInfo("match_team", 0)
    end
end

function TeamSummon(oPlayer,target)
    local oNotifyMgr = global.oNotifyMgr
    local oWorldMgr = global.oWorldMgr
    local oCbMgr = global.oCbMgr
    local oTeamMgr = global.oTeamMgr
    local pid = oPlayer:GetPid()
    local oTeam = oPlayer:HasTeam()
    if not oTeam then
        oNotifyMgr:Notify(pid,"你还没有队伍")
        return
    end
    if not oTeam:IsLeader(pid) then
        oNotifyMgr:Notify(pid,"只有队长可以操作")
        return
    end
    local bFobid, sReason = global.oTeamMgr:FobidTeamAction(oTeam:TeamID(), target, "FobidSummonTeam")
    if bFobid then
        if sReason then
            oPlayer:NotifyMessage(sReason)
        end
        return false
    end
    local mShortMem={}
    if target>0 then
        mShortMem[target]=true
    elseif target==0 then
        mShortMem= oTeam:GetShortLeave()
    end

    for memid,_ in pairs(mShortMem) do
        local oTarget = oWorldMgr:GetOnlinePlayerByPid(memid)
        if not oTarget then
            goto continue
        end

        local flag = oTeamMgr:GetCBFlag("back",memid)
        if oTarget:InWar() and oTarget:HasWarEndCB(flag) then
            goto continue
        end

        if oTeam:InWar() and oTeam:HasCB(gamedefines.TEAM_CB_TYPE.LEAVE_WAR,flag) then
            goto continue
        end

        local sContent = "队长邀请你归队，是否回到队伍?"
        local mData = {
            sContent = sContent,
            sConfirm = "归队",
            sCancle = "取消",
        }
        local mData = oCbMgr:PackConfirmData(nil, mData)
        local func = function (oTarget,mData)
            if mData["answer"] == 1 then
                TeamBack(oTarget)
            end
        end
        oCbMgr:SetCallBack(oTarget:GetPid(),"GS2CConfirmUI",mData,nil,func)
        ::continue::
    end
end

function TeamBack(oPlayer)
    local iTeamID = oPlayer:TeamID()
    local bFobid, sReason = global.oTeamMgr:FobidTeamAction(iTeamID, oPlayer:GetPid(), "FobidBackTeam")
    if bFobid then
        if sReason then
            oPlayer:NotifyMessage(sReason)
        end
        return false
    end
    global.oTeamMgr:TeamBack(oPlayer)
end

function TeamAutoMatch(oPlayer, mData)
    local oNotifyMgr = global.oNotifyMgr
    local oTeamMgr = global.oTeamMgr
    local iMatch = mData.team_match
    local iMinGrade = mData.min_grade
    local iMaxGrade = mData.max_grade
    local iTargetID = mData.auto_target
    local pid = oPlayer:GetPid()

    if iMinGrade > iMaxGrade then return end

    local oTeam = oPlayer:HasTeam()
    if not oTeam then return end

    if iMatch == 1 then
        local bFobid, sReason = global.oTeamMgr:FobidTeamAction(oTeam:TeamID(), pid, "FobidAutoTeamStart")
        if bFobid then
            if sReason then
                oPlayer:NotifyMessage(sReason)
            end
            return
        end
    end

    if not oTeam:IsLeader(pid) then
        oNotifyMgr:Notify(pid,"只有队长可以操作")
        return
    end
    if iTargetID > 0 then
        local oLingxiHuodong = global.oHuodongMgr:GetHuodong("lingxi")
        if oLingxiHuodong then
            if oLingxiHuodong:IsMatching(pid) then
                -- oPlayer:NotifyMessage("您正在灵犀匹配中")
                -- return
                -- 打断灵犀匹配
                oLingxiHuodong:StopMatch(oPlayer)
            end
        end
    end
    local mDefaultTarget = oTeam:DefaultTargetInfo(iTargetID, iMatch)
    if not mDefaultTarget then
        oNotifyMgr:Notify(pid, "请先设置匹配目标")
        return
    end
    if iTargetID == 0 and iMatch == 1 then
        oNotifyMgr:Notify(pid, "请先设置匹配目标")
        return
    end
    if 1 ~= (oPlayer.m_iTeamAllowed or 1) then
        oNotifyMgr:Notify(pid, "当前场景无法组队")
        return
    end
    if oTeam.m_AutoTarget and oTeam.m_AutoTarget.auto_target~=iTargetID then
        oTeam:ClearBlackList()
    end
    oTeam:SetAutoMatchTarget({auto_target = iTargetID, min_grade = iMinGrade, max_grade = iMaxGrade, team_match = iMatch})
end

function TeamCancelAutoMatch(oPlayer)
    local oTeam = oPlayer:HasTeam()
    local pid = oPlayer:GetPid()
    local oNotifyMgr = global.oNotifyMgr
    if oTeam and oTeam:IsLeader(pid) and oTeam:AutoMatching() then
        oTeam:CancleAutoMatch()
        oNotifyMgr:Notify(pid,"已取消自动匹配")
    end
end

function PlayerAutoMatch(oPlayer, iTargetID)
    local oNotifyMgr = global.oNotifyMgr
    local pid = oPlayer:GetPid()
    if iTargetID == 0 then return end
    local oLingxiHuodong = global.oHuodongMgr:GetHuodong("lingxi")
    if oLingxiHuodong then
        if oLingxiHuodong:IsMatching(pid) then
            -- oPlayer:NotifyMessage("您正在灵犀匹配中")
            -- return
            -- 打断灵犀匹配
            oLingxiHuodong:StopMatch(oPlayer)
        end
    end
    if oPlayer:HasTeam() then
        oNotifyMgr:Notify(pid, "您已经在队伍中")
        return
    end 
    if 1 ~= (oPlayer.m_iTeamAllowed or 1) then
        oNotifyMgr:Notify(pid, "当前场景无法自动组队")
        return
    end
    local mTarget = res["daobiao"]["team"]["autoteam"][iTargetID]
    if not mTarget then return end
    if mTarget.unlock_level > oPlayer:GetGrade() then return end

    
    
    local mArgs = {
        target = iTargetID,
        model_info = oPlayer:GetModelInfo(),
        grade = oPlayer:GetGrade(),
        school = oPlayer:GetSchool(),
        name = oPlayer:GetName(),
        icon = oPlayer:GetIcon(),
        team_allowed = oPlayer.m_iTeamAllowed,
    }
    PlayerCancelAutoMatch(oPlayer,true)
    oPlayer:SetAutoMatching(iTargetID, true)
    interactive.Send(".autoteam","team","PlayerStartAutoMatch",{targetid = iTargetID, pid=pid, mem_info=mArgs})
end

function PlayerCancelAutoMatch(oPlayer,bSilent)
    local iTargetID = oPlayer.m_oActiveCtrl:GetInfo("auto_targetid")
    if not iTargetID then return end
    local pid = oPlayer:GetPid()
    local oNotifyMgr = global.oNotifyMgr
    interactive.Send(".autoteam", "team", "CanclePlayerAutoMatch", {targetid = iTargetID, pid = pid})
    oPlayer:SetAutoMatching(iTargetID, false)
    if not bSilent then
        oNotifyMgr:Notify(pid, "已取消自动匹配")
    end
end

function GetTargetTeamInfo(oPlayer, iTargetID)
    local oTeamMgr = global.oTeamMgr
    local oNotifyMgr = global.oNotifyMgr
    local mTarget = res["daobiao"]["team"]["autoteam"][iTargetID]
    oTeamMgr:GS2CTargetTeamInfoList(oPlayer:GetPid(), iTargetID)
end

function GetTeamInfo(oPlayer, iTeamID)
    local oTeamMgr = global.oTeamMgr
    local oChatMgr = global.oChatMgr
    local oNotifyMgr = global.oNotifyMgr
    local pid = oPlayer:GetPid()
    local oTeam = oTeamMgr:GetTeam(iTeamID)
    if not oTeam then
        oNotifyMgr:Notify(pid, "队伍已经解散")
        return
    end
    local iTargetID = oTeam:GetTargetID()
    local mTargetData = res["daobiao"]["team"]["autoteam"][iTargetID]
    assert(mTargetData, string.format("autoteam config err: %d %d", pid, iTargetID))
    local mTeamInfo = oTeam:PackTeamInfo()
    mTeamInfo.status = 0
    local oApplyMgr = oTeam:GetApplyMgr()
    if oApplyMgr:HasApply(pid) then
        mTeamInfo.status = 1
    elseif oTeam:TeamSize() >= mTargetData["max_count"] then
        mTeamInfo.status = 2
    end
    mTeamInfo.match_time = oTeam.m_iStartMatchTime or 0
    local mNet = {}
    mNet["teaminfo"] = mTeamInfo
    oPlayer:Send("GS2CTargetTeamInfo", mNet)
end

function SetAppointMem(oPlayer, iTargetPid, iAppoint)
    local oTeam = oPlayer:HasTeam()
    if not oTeam then return end

    local oToolMgr = global.oToolMgr
    local oNotifyMgr = global.oNotifyMgr
    local pid = oPlayer:GetPid()

    if not oTeam:IsLeader(pid) then
        return
    end
    if not oTeam:IsTeamMember(iTargetPid) then
        oNotifyMgr:Notify(pid, oToolMgr:GetTextData(1074 , {"team"}))
        return
    end
    if oTeam:IsShortLeave(iTargetPid) then
        oNotifyMgr:Notify(pid, oToolMgr:GetTextData(1074 , {"team"}))
        return
    end
    oTeam:SetAppoint(iTargetPid, iAppoint)
end

function AddTask(iPid,oTask)
    local oWorldMgr = global.oWorldMgr
    local oNotifyMgr = global.oNotifyMgr
    local oPlayer = oWorldMgr:GetOnlinePlayerByPid(iPid)
    if not oPlayer then return end
    local oTeam = oPlayer:HasTeam()
    if not oTeam then
        oNotifyMgr:Notify(iPid,"没有队伍，不能添加任务")
        return
    end
    if not oTeam:IsLeader(iPid) then return
    end
    if oTeam:GetTask(oTask.m_ID) then return end

    oTask:Config(iPid)
    oTask:SetCreateTime()
    oTask:ConfigTimeOut()
    oTask:SetTeamID(oTeam.m_ID)
    oTask:Setup()
    oTeam:AddTask(oTask)
    oTask:OnTeamAddDone()
    oTask:LogTaskWanfaInfo(oPlayer, 1)
    return oTask
end

function RemoveTask(iPid,iTask)
    local oTeam = oPlayer:HasTeam()
    if not oTeam then return end
    local oTask = oTeam:GetTask(iTask)
    if not oTask then return end
    oTeam:RemoveTask(iTask)
end

function RefreshApplyLeaderInfo(pid, oTeam, iActive)
    if oTeam:IsLeader(pid) then
        local memlist = oTeam:GetTeamMember()
        if #memlist > 0 then
            iActive = iActive or 1
            local mNet = {}
            mNet["active"] = iActive or 1
            local oWorldMgr = global.oWorldMgr
            for _, memid in ipairs(memlist) do
                local oPlayer = oWorldMgr:GetOnlinePlayerByPid(memid)
                if oPlayer then
                    oPlayer:Send("GS2CLeaderActiveStatus", mNet)
                end
            end
        end
    end
end

function ApplyLeader(pid, oTeam)
    local oWorldMgr = global.oWorldMgr
    local oNotifyMgr = global.oNotifyMgr
    local oUIMgr = global.oUIMgr
    local oToolMgr = global.oToolMgr
    local oPlayer = oWorldMgr:GetOnlinePlayerByPid(pid)
    if  not oTeam:IsTeamMember(pid) then
        oNotifyMgr:Notify(pid, "你不在队伍中")
        return 
    end
    if oTeam.m_iLeaderState == 1 then
        oNotifyMgr:Notify(pid, "队长处于活跃状态，不能申请队长")
        return
    end
    local iApplyLeaderEnd = oPlayer.m_oActiveCtrl:GetInfo("apply_leader", 0)
    if iApplyLeaderEnd > get_time() and not oPlayer.m_apply_leader then
        oNotifyMgr:Notify(pid, "申请太频繁，请稍后再试")
        return
    end
    
    local mVoteBox = oTeam.m_oVoteBox
    if mVoteBox and not mVoteBox.m_bEnd then
        local sMsg
        local oTarget = mVoteBox:GetPlayer()
        if pid == oTarget:GetPid() then
            sMsg = "你已发出申请，请等待"
        else
            sMsg = oToolMgr:FormatColorString("请等待#role申请队长结果", {role = oTarget:GetName()})
        end
        oNotifyMgr:Notify(pid, sMsg)
    else
        local lSessionidx = oTeam.m_mSessionidx or {}
        lSessionidx[pid] = nil
        for memid, sessionidx in pairs(lSessionidx) do
            local oMem = oWorldMgr:GetOnlinePlayerByPid(memid)
            if oMem then oUIMgr:GS2CCloseConfirmUI(oMem, sessionidx) end
        end
        lSessionidx = nil
        oTeam.m_mSessionidx = nil
        _ApplyLeaderStartVote(oTeam, oPlayer)
    end
end

function LeaderNotActive(oTeam)
    if oTeam:InWar() then
        return  false
    end
    local mVoteBox = oTeam.m_oVoteBox
    if mVoteBox and not mVoteBox.m_bEnd then
        return false
    end
    local oCbMgr = global.oCbMgr
    local oWorldMgr = global.oWorldMgr
    local mData = {}
    mData["sContent"] = "队长已离开，是否申请成为队长"
    mData["sConfirm"] = "申请队长"
    mData["sCancle"] = "取消"
    mData["time"] = 30
    mData["default"] = 0
    mData["replace"] = 1
    mData = oCbMgr:PackConfirmData(nil, mData)
    local memlist = oTeam:GetTeamMember()
    local func = function (oPlayer, mData)
        if mData["answer"] == 1 then
            ApplyLeader(oPlayer:GetPid(), oTeam)
        end
    end
    oTeam.m_mSessionidx = {}
    for _, memid in pairs(memlist) do
        if memid ~= oTeam:Leader() then
            local iSessionidx= oCbMgr:SetCallBack(memid,"GS2CConfirmUI",mData,nil ,func)
            oTeam.m_mSessionidx[memid] = iSessionidx
        end
    end
    return true
end

function _ApplyLeaderStartVote(oTeam, oPlayer)
    local oNotifyMgr = global.oNotifyMgr
    local oChatMgr = global.oChatMgr
    local oToolMgr = global.oToolMgr
    local pid = oPlayer:GetPid()
    local sName = oPlayer:GetName()
    local sTopic = sName .. "申请成为队长"
    local mVoteBox = votebox.NewVoteBox(sTopic, oPlayer, oTeam, false, -1,1,30)
    mVoteBox.HandleEnd=_ApplyLeaderResult
    mVoteBox.HandleAgree = _HandleAgree
    mVoteBox.HandleRefuse = _HandleRefuse
    mVoteBox.CustomConfirmData = _CustomConfirmData
    oTeam.m_oVoteBox = mVoteBox
    mVoteBox:Start()
    oChatMgr:HandleTeamChat(oPlayer, oToolMgr:FormatColorString("#role申请成为队长，全部成员同意则可申请成功", {role = sName}), true)
    oNotifyMgr:Notify(pid, "你已发出申请，请等待")
end

function _ApplyLeaderResult(oPlayer, oTeam, bResult)
    if not oTeam then return  end
    local oNotifyMgr = global.oNotifyMgr
    local oChatMgr = global.oChatMgr
    local oTeamMgr = global.oTeamMgr
    local oToolMgr = global.oToolMgr
    local pid = oPlayer:GetPid()
    local sName = oPlayer:GetName()
    if bResult then
        oTeam:SetLeader(pid)
        oNotifyMgr:Notify(pid, "你已成为队长")
        oTeamMgr:TeamNotify(oTeam, oToolMgr:FormatColorString("#role已成为队长", {role = sName}),{[pid] = true})
        oChatMgr:HandleTeamChat(oPlayer, oToolMgr:FormatColorString("#role申请队长成功", {role = sName}), true)
    else
        oChatMgr:HandleTeamChat(oPlayer, oToolMgr:FormatColorString("#role申请队长失败", {role = sName}), true)
        --oTeam:PushApplyLeaderAgain()
    end
    oPlayer.m_oActiveCtrl:SetInfo("apply_leader", get_time() + 30)
    if oTeam.m_oVoteBox then
        baseobj_delay_release(oTeam.m_oVoteBox)
        oTeam.m_oVoteBox=nil
    end
end

function _HandleAgree(oVoteBox, pid)
    local oNotifyMgr = global.oNotifyMgr
    local oChatMgr = global.oChatMgr
    local oWorldMgr = global.oWorldMgr
    local oToolMgr = global.oToolMgr
    local oTarget = oWorldMgr:GetOnlinePlayerByPid(pid)
    local oPlayer = oVoteBox:GetPlayer()
    if oTarget and oPlayer then
        local sName, sTarget = oPlayer:GetName(), oTarget:GetName()
        oChatMgr:HandleTeamChat(oPlayer, oToolMgr:FormatColorString("#role同意#role的申请队长请求", {role = {sTarget, sName}}), true)
        oNotifyMgr:Notify(oPlayer:GetPid(), oToolMgr:FormatColorString("#role同意了你的申请队长请求", {role = sTarget}))
        oNotifyMgr:Notify(oTarget:GetPid(), oToolMgr:FormatColorString("你同意了#role的申请队长", {role = sName}))
    end
end

function _HandleRefuse(oVoteBox, iTarget)
    local oNotifyMgr = global.oNotifyMgr
    local oChatMgr = global.oChatMgr
    local oWorldMgr = global.oWorldMgr
    local oToolMgr = global.oToolMgr
    local oTarget = oWorldMgr:GetOnlinePlayerByPid(iTarget)
    local oPlayer = oVoteBox:GetPlayer()
    if oTarget and oPlayer then
        local sName, sTarget = oPlayer:GetName(), oTarget:GetName()
        oChatMgr:HandleTeamChat(oPlayer, oToolMgr:FormatColorString("#role拒绝了#role的申请队长请求", {role = {sTarget, sName}}), true)
        oNotifyMgr:Notify(oPlayer:GetPid(), oToolMgr:FormatColorString("#role拒绝了你的申请队长请求", {role = sTarget}))
        oNotifyMgr:Notify(oTarget:GetPid(), oToolMgr:FormatColorString("你拒绝了#role的申请队长", {role = sName}))
    end
end

function _CustomConfirmData(sTopic)
    local mData = {}
    mData["sContent"] = sTopic
    mData["sConfirm"] = "同意"
    mData["sCancle"] = "拒绝"
    mData["time"] = 30
    mData["default"] = 1
    return mData
end

function _InviteTeam(oPlayer,mData,iTarget)
    oPlayer.m_bInviteState=nil
    if mData["answer"] == 1 then
        InvitePass(oPlayer, iTarget)
    end
end
