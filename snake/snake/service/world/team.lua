--import module

local global = require "global"
local interactive = require "base.interactive"
local res = require "base.res"
local record = require "public.record"

local teamobj = import(service_path("team/teamobj"))
local meminfo = import(service_path("team/meminfo"))
local teaminfo = import(service_path("team/teaminfo"))
local handleteam = import(service_path("team/handleteam"))

local gamedefines = import(lualib_path("public.gamedefines"))

function NewTeamMgr(...)
    return CTeamMgr:New(...)
end


CTeamMgr = {}
CTeamMgr.__index = CTeamMgr
inherit(CTeamMgr,logic_base_cls())

function CTeamMgr:New()
    local o = super(CTeamMgr).New(self)
    o.m_iTeamID = 0
    o.m_mTeamList = {}
    o.m_mInviteList = {}
    o.m_mPid2TeamID = {}
    o.m_mTeamApplyTime={}
    return o
end

function CTeamMgr:DispatchId()
    self.m_iTeamID = self.m_iTeamID + 1
    return self.m_iTeamID
end

function CTeamMgr:GetTeam(iTeamID)
    return self.m_mTeamList[iTeamID]
end

function CTeamMgr:RemoveTeam(iTeamID)
    if not self.m_mTeamList[iTeamID] then
        return
    end
    local oTeam = self.m_mTeamList[iTeamID]
    self.m_mTeamList[iTeamID] = nil
    baseobj_delay_release(oTeam)
end

function CTeamMgr:AddPid2TeamID(pid,iTeamID)
    if self.m_mPid2TeamID[pid] and self.m_mPid2TeamID[pid] ~= iTeamID then
        record.warning(string.format("repeat add team %s %s %s",self.m_mPid2TeamID[pid],iTeamID,pid))
        record.warning(debug.traceback())
    end
    self.m_mPid2TeamID[pid] = iTeamID
end

function CTeamMgr:ClearPid2TeamID(pid, iTeamID)
    local tid = self.m_mPid2TeamID[pid]
    if tid == iTeamID then
        self.m_mPid2TeamID[pid] = nil
    end
end

function CTeamMgr:GetTeamByPid(pid)
    local iTeamId = self.m_mPid2TeamID[pid]
    if iTeamId then
        local oTeam = self:GetTeam(iTeamId)
        if oTeam then
            return oTeam
        end
    end
end

function CTeamMgr:GetApplyTime(pid,iTeamId)
    if self.m_mTeamApplyTime[pid] and self.m_mTeamApplyTime[pid][iTeamId] then
        return self.m_mTeamApplyTime[pid][iTeamId]
    end
    return 0
end

function CTeamMgr:SetApplyTime(pid,iTeamId,iTime)
    if not self.m_mTeamApplyTime[pid] then
        self.m_mTeamApplyTime[pid]={}
    end
    if not self.m_mTeamApplyTime[pid][iTeamId] then
        self.m_mTeamApplyTime[pid][iTeamId] = iTime
    end
end

function CTeamMgr:OnLogin(oPlayer,bReEnter)
    local pid = oPlayer:GetPid()
    local oTeam = self:GetTeamByPid(pid)
    if oTeam then
        oTeam:OnLogin(oPlayer,bReEnter)
    end
    -- local oInviteMgr = self:GetInviteMgr(oPlayer:GetPid())
    -- if oInviteMgr then
    --     oInviteMgr:SendInviteInfo(oPlayer,true)
    -- end
end

function CTeamMgr:OnLogout(oPlayer)
    local pid = oPlayer:GetPid()
    local oTeam = self:GetTeamByPid(pid)
    if oTeam then
        oTeam:OnLogout(oPlayer)
    else
        local iTargetID = oPlayer.m_oActiveCtrl:GetInfo("auto_targetid")
        if iTargetID then
            interactive.Send(".autoteam","team","OnDisconnected",{targetid = iTargetID, pid = oPlayer:GetPid()})
        end
    end
    local oInviter = self.m_mInviteList[oPlayer:GetPid()]
    if oInviter then
        baseobj_delay_release(oInviter)
    end
    self.m_mInviteList[oPlayer:GetPid()] = nil

end

--iTargetID 任务目标ID，创建默认等级目标队伍
--iMatch 0-不自动匹配，1-自动匹配
function CTeamMgr:CreateTeam(pid, iTargetID, iMatch)
    local oWorldMgr = global.oWorldMgr
    local oNotifyMgr = global.oNotifyMgr
    local oSceneMgr = global.oSceneMgr
    local oPlayer = oWorldMgr:GetOnlinePlayerByPid(pid)
    if oPlayer:HasTeam() then
        oNotifyMgr:Notify(pid,"你已经有队伍了，无法创建")
        return
    end
    local oScene = oPlayer.m_oActiveCtrl:GetNowScene()
    if oScene and not oScene:IsTeamAllowed() then
        oNotifyMgr:Notify(pid, "当前场景禁止组队")
        return
    end
    if oPlayer:IsFixed() then
        return
    end

    local mArgs = {
        model_info = oPlayer:GetModelInfo(),
        grade = oPlayer:GetGrade(),
        school = oPlayer:GetSchool(),
        name = oPlayer:GetName(),
        icon = oPlayer:GetIcon(),
        hp = oPlayer:GetHp(),
        maxhp = oPlayer:GetMaxHp(),
        mp = oPlayer:GetMp(),
        maxmp = oPlayer:GetMaxMp(),
        team_allowed = oPlayer.m_iTeamAllowed or 1,
        score = oPlayer:GetScore(),
    }
    local iTeamID = self:DispatchId()
    local oTeam = teamobj.NewTeam(pid, iTeamID)
    local oMember = meminfo.NewMember(pid,mArgs)
    oTeam:AddMember(oMember)
    self.m_mTeamList[iTeamID] = oTeam
    self.m_mPid2TeamID[pid] = iTeamID
    if iTargetID and iTargetID ~= 0 then
        local mTarget = oTeam:DefaultTargetInfo(iTargetID, iMatch)
        if mTarget then
            oTeam:SetAutoMatchTarget(mTarget)
        end
    end
    if oPlayer.m_oActiveCtrl:GetInfo("auto_matching", false) then
        handleteam.PlayerCancelAutoMatch(oPlayer)
    end
    self:ClearInvite(oPlayer)
    oTeam:OnCreate()
    oNotifyMgr:Notify(pid,"创建队伍成功")
    oNotifyMgr:SetupPubTeamChannel(oPlayer, true)
    -- 注册到聊天频道
    local mRole = {
        pid = oPlayer:GetPid(),
    }

    interactive.Send(".broadcast", "channel", "SetupChannel", {
        pid = oPlayer:GetPid(),
        channel_list = {
            {gamedefines.BROADCAST_TYPE.TEAM_TYPE, iTeamID, true},
        },
        info = mRole,
    })

    oPlayer.m_oStateCtrl:AddTeamLeader()
    oSceneMgr:CreateSceneTeam(oPlayer)
    global.oTeamMgr:TriggerEvent(gamedefines.EVENT.TEAM_CREATE, {team = self, player = oPlayer})

    local oScene = oPlayer.m_oActiveCtrl:GetNowScene()
    if oScene and oScene:GetVirtualGame() == "orgwar" then
        oTeam:AddServStateByArgs("in_orgwar")
    end
end

function CTeamMgr:AddTeamMember(iTeamID,pid)
    local oTeam = self:GetTeam(iTeamID)
    local oWorldMgr = global.oWorldMgr
    local oNotifyMgr = global.oNotifyMgr
    local oSceneMgr = global.oSceneMgr
    local oChatMgr = global.oChatMgr
    local oToolMgr = global.oToolMgr
    
    local oLeader = oTeam:GetLeaderObj()
    local oPlayer = oWorldMgr:GetOnlinePlayerByPid(pid)

    oSceneMgr:TransToLeader(oPlayer, oTeam:Leader())

    local mArgs = {
        model_info = oPlayer:GetModelInfo(),
        icon = oPlayer:GetIcon(),
        grade = oPlayer:GetGrade(),
        school = oPlayer:GetSchool(),
        name = oPlayer:GetName(),
        hp = oPlayer:GetHp(),
        maxhp = oPlayer:GetMaxHp(),
        mp = oPlayer:GetMp(),
        maxmp = oPlayer:GetMaxMp(),
        team_allowed = oPlayer.m_iTeamAllowed or 1,
        score = oPlayer:GetScore(),
    }
    if oPlayer.m_oActiveCtrl:GetInfo("auto_matching", false) then
        handleteam.PlayerCancelAutoMatch(oPlayer)
    end
    local oMember = meminfo.NewMember(pid,mArgs)
    oTeam:AddMember(oMember)
    if oTeam:AutoMatching() then
        if oTeam:TeamSize() >= oTeam:MaxTeamSize() then
            oTeam:CancleAutoMatch()
            oNotifyMgr:Notify(oTeam:Leader(), "队伍人数已满，停止自动匹配")
        else
            self:EnterAutoTeam(oTeam, oMember)
        end
    end

    interactive.Send(".broadcast", "channel", "SetupChannel", {
        pid = oPlayer:GetPid(),
        channel_list = {
            {gamedefines.BROADCAST_TYPE.TEAM_TYPE, iTeamID, true},
        },
        info = {pid = oPlayer:GetPid(),},
    })
    local sText = oToolMgr:FormatColorString("欢迎#role加入队伍",{role = oPlayer:GetName()})
    self:TeamNotify(oTeam,sText,{[pid]=true})
    sText = oToolMgr:FormatColorString("你已加入#role的队伍", {role = oLeader:GetName()})
    oNotifyMgr:Notify(pid, sText)
    sText = oToolMgr:FormatColorString("#role加入了队伍", {role = oPlayer:GetName()})
    oChatMgr:HandleTeamChat(oPlayer, sText, true)
end

function CTeamMgr:ApplyTeam(oPlayer, iTeamID, iAutoTargetID, iAuto,bInvite)
    local pid = oPlayer:GetPid()
    local oWorldMgr = global.oWorldMgr
    local oNotifyMgr = global.oNotifyMgr
    local oPlayerTeam = oPlayer:HasTeam()
    if oPlayerTeam then
        oNotifyMgr:Notify(pid,"你已经有队伍了")
        return
    end

    local oTeam = self:GetTeam(iTeamID)
    if not oTeam then
        self:_RefreshTargetTeamApplyInfo(oPlayer, iTeamID,2, iAuto)
        oNotifyMgr:Notify(pid,"该队伍已经解散")
        return
    end
    local oLeader = oWorldMgr:GetOnlinePlayerByPid(oTeam:Leader())
    if not oLeader then
        return
    end
    if oTeam:TeamSize() >= oTeam:MaxTeamSize() then
        self:_RefreshTargetTeamApplyInfo(oPlayer,iTeamID, 2, iAuto)
        oNotifyMgr:Notify(pid,"该队伍人数已满")
        return
    end

    local oApplyMgr = oTeam:GetApplyMgr()
    local oApply = oApplyMgr:HasApply(pid)
    if oApply  then
        if oApply:Validate() then
            self:_RefreshTargetTeamApplyInfo(oPlayer, iTeamID,1, iAuto)
            oNotifyMgr:Notify(pid,"已在申请列表中，请耐心等待回复")
            return
        end
    end

    if not oApplyMgr:ValidApply() then
        self:_RefreshTargetTeamApplyInfo(oPlayer, iTeamID,2, iAuto)
        oNotifyMgr:Notify(pid,"该队伍申请列表已满")
        return
    end
    if iAuto ==2 then
        local mTarget =  oTeam.m_AutoTarget
        local iGrade = oPlayer:GetGrade()
        if mTarget and ( iGrade< mTarget["min_grade"] or iGrade>mTarget["max_grade"] ) then 
            oNotifyMgr:Notify(pid,"你等级不符合队长要求")
            return
        end
    end
    if oTeam:AutoMatching() then
        if self:ValidApplyTeamPass(oLeader,pid,true) then
            self:ApplyTeamPass(oLeader,pid,true)
            return
        end
    end

    local oApplyMgr = oTeam:GetApplyMgr()
    local mArgs = {
        model_info = oPlayer:GetModelInfo(),
        icon = oPlayer:GetIcon(),
        grade = oPlayer:GetGrade(),
        school = oPlayer:GetSchool(),
        name = oPlayer:GetName(),
        orgid = oPlayer:GetOrgID(),
    }
    oApplyMgr:AddApply(pid,mArgs)
    self:_RefreshTargetTeamApplyInfo(oPlayer, iTeamID,1, iAuto)
    self:SetApplyTime(pid,iTeamID, get_time() + 10)
    if not bInvite then
        oNotifyMgr:Notify(pid,string.format("已申请加入%s的队伍，请耐心等待",oLeader:GetName()))
    end
end

function CTeamMgr:ValidApplyTeamPass(oPlayer,target,bMatch)
    local oNotifyMgr = global.oNotifyMgr
    local oWorldMgr = global.oWorldMgr
    local pid = oPlayer.m_iPid
    local oTeam = oPlayer:HasTeam()
    local iTeamID = oPlayer:TeamID()
    if not oTeam then
        return false
    end
    if not oTeam:IsLeader(pid) then
        if not bMatch then
            oNotifyMgr:Notify(pid,"只有队长才能操作")
        end
        return  false
    end
    if oTeam:TeamSize() >= oTeam:MaxTeamSize() then
        if not bMatch then
            oNotifyMgr:Notify(pid,"队伍人数已满")
        end
        return false
    end
    local oApplyMgr = oTeam:GetApplyMgr()
    local oApply = oApplyMgr:HasApply(target)
    if not bMatch and not oApply then
        oNotifyMgr:Notify(pid,"申请已失效")
        return false
    end
    if not bMatch and not oApply:Validate() then
        if not bMatch then
            oNotifyMgr:Notify(pid,"申请已失效")
            oApplyMgr:RemoveApply(target,pid)
        end
        return false
    end
    local oTarget = oWorldMgr:GetOnlinePlayerByPid(target)
    if not oTarget then
        if not bMatch then
            oNotifyMgr:Notify(pid,"玩家已经离线")
            oApplyMgr:RemoveApply(target,pid)
        end
        return false
    end
    if 1 ~= (oPlayer.m_iTeamAllowed or 1) then
        if not bMatch then
            oNotifyMgr:Notify(pid, "当前场景无法组队")
        end
        return false
    end

    local oTargetTeam = oTarget:HasTeam()
    if oTargetTeam then
        local oInviteMgr = self:GetInviteMgr(pid)
        if oInviteMgr:HasInvite(iTeamID) then
            oInviteMgr:RemoveInvite(iTeamID, pid)
        end
        oApplyMgr:RemoveApply(target,pid)
        if not bMatch then
            oNotifyMgr:Notify(pid,"该玩家已加入其它队伍")
        end
        return false
    end
    if bMatch then
        if not oTeam:AutoMatching() then
            return false
        else
            local mTarget = oTeam:PackTargetInfo()
            local iTargetGrade = oTarget:GetGrade()
            if iTargetGrade<mTarget["min_grade"] or iTargetGrade>mTarget["max_grade"] then
                return false
            end
            oTeam:CheckBlackList() 
            local iNowTime = oTeam:GetBlackListMemTime(target)
            local iLeftTime = iNowTime-get_time()
            if iLeftTime>(5*60-30) then
                return false
            end
        end
    end
    return true
end

function CTeamMgr:ApplyTeamPass(oPlayer,target,bMatch)
    if not self:ValidApplyTeamPass(oPlayer,target,bMatch) then
        return
    end
    local oTarget = global.oWorldMgr:GetOnlinePlayerByPid(target)
    local oTeam = oPlayer:HasTeam()
    local oApplyMgr = oTeam:GetApplyMgr()
    local oInviteMgr = self:GetInviteMgr(target)
    self:DoAddTeam(oTeam, oTarget)
    if oApplyMgr:HasApply(target) then
        oApplyMgr:RemoveApply(target,pid)
    end
    oInviteMgr:ClearInviteInfo()
end

function CTeamMgr:DoAddTeam(oTeam, oTarget)
    local oNotifyMgr = global.oNotifyMgr
    if oTarget:InWar() then
        oTeam:AddShortLeave(oTarget)
        oNotifyMgr:Notify(oTarget:GetPid(), "你已加入队伍，战斗结束后请尽快归队")
    elseif oTeam:InWar() then
        oTeam:AddShortLeave(oTarget)
        global.oTeamMgr:TeamBack(oTarget)
    elseif oTarget:IsFixed() then
        oTeam:AddShortLeave(oTarget)
        oNotifyMgr:Notify(oTarget:GetPid(), "你已加入队伍，请尽快归队")
    else
        if not oTeam:ValidTransToLeader(oTarget,2) then
            oTeam:AddShortLeave(oTarget)
        else
            local iTeamID = oTeam:TeamID()
            self:AddTeamMember(iTeamID, oTarget:GetPid() )
        end
    end
end

function CTeamMgr:CancelApply(oPlayer, iTeamID, iTargetID, iAuto)
    local oWorldMgr = global.oWorldMgr
    local oNotifyMgr = global.oNotifyMgr
    local pid = oPlayer:GetPid()
    local oTeam = self:GetTeam(iTeamID)
    if not oTeam then
        self:_RefreshTargetTeamApplyInfo(oPlayer, iTeamID,2, iAuto)
        oNotifyMgr:Notify(pid, "队伍已经解散")
        return
    end

    local oApplyMgr = oTeam:GetApplyMgr()
    if oApplyMgr:HasApply(pid) then
        oApplyMgr:RemoveApply(pid)
    end

    self:_RefreshTargetTeamApplyInfo(oPlayer, iTeamID,0, iAuto)

    local iLeader = oTeam:Leader()
    local oLeader= oWorldMgr:GetOnlinePlayerByPid(iLeader)
    if oLeader then
        oNotifyMgr:Notify(pid, string.format("已取消向%s队伍的申请", oLeader:GetName()))
    end
end

function CTeamMgr:_RefreshTargetTeamApplyInfo(oPlayer, iTeamID,iStatue,iAuto)
    if iAuto == 1 then
        oPlayer:Send("GS2CTargetTeamStatus", {teamid = iTeamID,status = iStatue,})
    end
end

function CTeamMgr:ClearApply(oPlayer)
    local oTeam = oPlayer:HasTeam()
    local oNotifyMgr = global.oNotifyMgr
    if not oTeam then
        return
    end

    local iPid = oPlayer:GetPid()
    if not oTeam:IsLeader(iPid) then
        oNotifyMgr:Notify(iPid,"你不是队长，不能清除申请信息")
        return
    end

    local oApplyMgr = oTeam:GetApplyMgr()
    oApplyMgr:ClearApply(iPid)
    oNotifyMgr:Notify(iPid,"已清空全部信息")
end

function CTeamMgr:SetLeader(oPlayer, iTarget)
    local oWorldMgr = global.oWorldMgr
    local oNotifyMgr = global.oNotifyMgr
    local oChatMgr = global.oChatMgr
    local oToolMgr = global.oToolMgr
    local pid = oPlayer:GetPid()
    local oTeam = oPlayer:HasTeam()
    if not oTeam then return end
    if not oTeam:IsLeader(pid) then return end
    if not oTeam:IsTeamMember(iTarget) then return end
    local oTarget = oWorldMgr:GetOnlinePlayerByPid(iTarget)
    if not oTarget then return end
    if oTeam:InWar() then
        local oMem = oTeam:GetMember(pid)
        local flag = self:GetCBFlag(gamedefines.TEAM_CB_FLAG.SETLEADER,pid)
        local mInfo = oTeam:HasCB(gamedefines.TEAM_CB_TYPE.LEAVE_WAR,flag)
        if mInfo  and mInfo["args"]["target"] == iTarget  then
            oTeam:DelCB(gamedefines.TEAM_CB_TYPE.LEAVE_WAR,flag)
            oNotifyMgr:Notify(pid,"你取消了移交队长操作")
            oMem:SetLeaderButtonState(oPlayer,0)
            return
        end
        local func
        func = function (args,oTeam)
            local pid = args.pid
            local target = args.target
            local oWorldMgr = global.oWorldMgr
            local oTeamMgr = global.oTeamMgr
            local oPlayer=oWorldMgr:GetOnlinePlayerByPid(pid)
            if not oPlayer then return end
            oTeamMgr:SetLeader(oPlayer,target)
        end
        oTeam:AddCB(gamedefines.TEAM_CB_TYPE.LEAVE_WAR,flag,func,{pid=pid,target=iTarget})
        oNotifyMgr:Notify(pid,"战斗结束后移交队长")
        oMem:SetLeaderButtonState(oPlayer,iTarget)
    else
        oTeam:SetLeader(iTarget)
        local sMsg = oToolMgr:FormatColorString("#role1成为队长", {role1 = oTarget:GetName()})
        oChatMgr:HandleTeamChat(oPlayer, sMsg, true)
        oNotifyMgr:Notify(iTarget,"你已被任命为队长")
    end
end

function CTeamMgr:ValidBackTeam(oPlayer)
    local pid = oPlayer:GetPid()
    local oNotifyMgr = global.oNotifyMgr
    local oTeam = oPlayer:HasTeam()
    if not oTeam then return false end
    if not oTeam:ValidTransToLeader(oPlayer,1) then
        return
    end
    if not oTeam:IsShortLeave(pid) then return false end
    if oPlayer:IsFixed() then
        return false
    end
    return true
end

function CTeamMgr:TeamBack(oPlayer)
    if not self:ValidBackTeam(oPlayer) then return end
    local oNotifyMgr = global.oNotifyMgr
    local pid = oPlayer:GetPid()
    local oTeam = oPlayer:HasTeam()
    local func
    func = function (args,oTeam)
        local pid = args.pid
        local oWorldMgr = global.oWorldMgr
        local oTeamMgr = global.oTeamMgr
        local oPlayer=oWorldMgr:GetOnlinePlayerByPid(pid)
        if not oPlayer then return end
        oTeamMgr:TeamBack(oPlayer)
    end
    local oMem = oTeam:GetMember(pid)
    if oPlayer:InWar() then
        local flag = self:GetCBFlag(gamedefines.TEAM_CB_FLAG.BACK,pid)
        if oPlayer:HasWarEndCB(flag) then
            oPlayer:DelWarEndCB(flag)
            oNotifyMgr:Notify(pid,"你取消了归队操作")
            oMem:SetBackButtonState(oPlayer,0)
            return
        end
        if oPlayer.m_oActiveCtrl:GetWarStatus() == gamedefines.WAR_STATUS.IN_WAR then
            oPlayer:AddWarEndCB(flag,func,{pid=pid})
            oNotifyMgr:Notify(pid, "正在战斗，战斗后自动归队")
            oMem:SetBackButtonState(oPlayer,1)
        else
            oNotifyMgr:Notify(pid, "请先退出观战")
        end
    elseif oTeam:InWar() then
        local flag = self:GetCBFlag("back",pid)
        if oTeam:HasCB(gamedefines.TEAM_CB_TYPE.LEAVE_WAR,flag) then
            oTeam:DelCB(gamedefines.TEAM_CB_TYPE.LEAVE_WAR,flag)
            oNotifyMgr:Notify(pid,"你取消归队操作")
            oMem:SetBackButtonState(oPlayer,0)
            return
        end
        local iStatus = oTeam:GetWarStatus()
        if iStatus == gamedefines.WAR_STATUS.IN_WAR then
            oTeam:AddCB(gamedefines.TEAM_CB_TYPE.LEAVE_WAR,flag,func,{pid=pid})
            oTeam:EnterWar(oPlayer)
            oNotifyMgr:Notify(pid, "队长战斗结束，自动回归队伍")
            oMem:SetBackButtonState(oPlayer,1)
        else
            local oWar = oTeam:InWar()
            local mArgs = {war_id=oWar:GetWarId(), team_id=oTeam:TeamID()}
            oTeam:BackTeam(oPlayer)
            oTeam:EnterWar(oPlayer)
            oNotifyMgr:Notify(pid,"你回到了队伍")
        end
    else
        oTeam:BackTeam(oPlayer)
        oNotifyMgr:Notify(pid,"你回到了队伍")
    end
end

function CTeamMgr:EnterAutoTeam(oTeam,oMem)
    local pid = oMem:MemberID()
    local iTeamID = oTeam:TeamID()
    local iTargetID = oTeam:GetTargetID()
    local mData = oMem:PackAutoTeamInfo()
    interactive.Send(".autoteam","team","OnEnterTeam",{targetid = iTargetID, teamid = iTeamID,pid = pid,mem_info = mData})
end

function CTeamMgr:OnLeaveTeam(iTeamID, pid)
    local oWorldMgr = global.oWorldMgr
    local oPlayer =  oWorldMgr:GetOnlinePlayerByPid(pid)
    if oPlayer then
        self:ClearInvite(oPlayer)
    end
    local oTeam = self:GetTeam(iTeamID)
    if oTeam and oTeam:AutoMatching() then
        local iTargetID = oTeam:GetTargetID()
        interactive.Send(".autoteam","team","OnLeaveTeam",{targetid = iTargetID, teamid = iTeamID, pid = pid})
        local mData = {
        targetid = iTargetID,
        teamid = iTeamID,
        pid = pid,
        timestamp = oTeam:GetBlackListMemTime(pid)
        }
        interactive.Send(".autoteam", "team", "AddMem2TeamBlackList", mData)
    end
end

function CTeamMgr:GS2CTargetTeamInfoList(pid, iTargetID)
    local oWorldMgr = global.oWorldMgr
    local oPlayer = oWorldMgr:GetOnlinePlayerByPid(pid)
    if not oPlayer then
        return
    end
    local mTarget = res["daobiao"]["team"]["autoteam"]
    local lTeam = self.m_mTeamList
    local mData = {}
    if next(lTeam) then
        for iTeamID, oTeam in pairs(lTeam) do
            if oTeam:AutoMatching() then
                local iTarget = oTeam:GetTargetID()
                local mTeamInfo = oTeam:PackTeamInfo()
                mTeamInfo.status = 0
                local oApplyMgr = oTeam:GetApplyMgr()
                if oApplyMgr:HasApply(pid) then
                    mTeamInfo.status = 1
                elseif oTeam:TeamSize() >= mTarget[iTarget]["max_count"] then
                    mTeamInfo.status = 2
                elseif not oApplyMgr:ValidApply() then
                    mTeamInfo.status = 3
                end
                mTeamInfo.match_time = oTeam.m_iStartMatchTime
                if iTargetID == 0 then
                    if oPlayer:GetGrade() >=  mTarget[iTarget]["unlock_level"] then
                        table.insert(mData, mTeamInfo)
                    end
                elseif iTarget and iTarget == iTargetID then
                    table.insert(mData, mTeamInfo)
                end
            end
        end
    end
    oPlayer:Send("GS2CTargetTeamInfoList", {
        teaminfo = mData,
        auto_target = iTargetID,
    })
    interactive.Send(".autoteam", "team", "CountAutoMatch", {pid = pid, targetid = iTargetID})
end

function CTeamMgr:UpdatePlayer(oPlayer)
    local pid = oPlayer.m_iPid
    local iTeamID = oPlayer:TeamID()
    local oTeam = oPlayer:HasTeam()
    local mArgs = {
        name = oPlayer:GetName(),
        grade = oPlayer:GetGrade(),
        school = oPlayer:GetSchool(),
        icon = oPlayer:GetIcon(),
        model_info = oPlayer:GetModelInfo(),
        team_allowed = oPlayer.m_iTeamAllowed or 1
    }
    if oTeam and oTeam:AutoMatching() then
        local iTargetID = oTeam:GetTargetID()
        interactive.Send(".autoteam","team","UpdateTeamMember",{targetid = iTargetID, teamid = iTeamID,pid = pid,mem_info=mArgs})
    end
    global.oNotifyMgr:SetupPubTeamChannel(oPlayer, true)
end

function CTeamMgr:TeamNotify(oTeam,sText,mExclude)
    local oWorldMgr = global.oWorldMgr
    local oNotifyMgr = global.oNotifyMgr
    mExclude = mExclude or {}
    local mOnline = oTeam:OnlineMember()
    for pid,_ in pairs(mOnline) do
        if not mExclude[pid] then
            local oPlayer = oWorldMgr:GetOnlinePlayerByPid(pid)
            if oPlayer then
                oNotifyMgr:Notify(pid,sText)
            end
        end
    end
end

function CTeamMgr:Notify(iPid, iText, mArgs)
    local oToolMgr = global.oToolMgr
    local oNotifyMgr = global.oNotifyMgr
    local sTip = oToolMgr:GetTextData(iText , {"team"})
    local sMsg = oToolMgr:FormatColorString(sTip, mArgs)
    oNotifyMgr:Notify(iPid, sMsg)
end

function CTeamMgr:GetInviteMgr(pid)
    local oInviteMgr = self.m_mInviteList[pid]
    if not oInviteMgr then
        oInviteMgr = teaminfo.NewInviteMgr(pid)
        self.m_mInviteList[pid] = oInviteMgr
    end
    return oInviteMgr
end

function  CTeamMgr:ClearInvite(oPlayer)
    local oInviteMgr = self:GetInviteMgr(oPlayer:GetPid())
    if oInviteMgr then
        oInviteMgr:ClearInviteInfo()
    end
end

function CTeamMgr:GetCBFlag(flag,pid)
    return string.format("%s_%s",flag,pid)
end

function CTeamMgr:FobidTeamAction(iTeamId, iPid, sAction, mArgs)
    local oTeam = self:GetTeam(iTeamId)
    if not oTeam then
        return false
    end
    local bFobid, sReason = oTeam.m_oServStateCtrl:FobidTeamAction(iPid, sAction, mArgs)
    return bFobid, sReason
end

function CTeamMgr:NewHour(mNow)
    local iHour = mNow.date.hour
    if iHour == 4 then
        self:NewHour4()
    end
end

function CTeamMgr:NewHour4()
    local sBatchKey = "team_chk_timecb"
    local lTeamIds = table_key_list(self.m_mTeamList)
    local func = function(iTeamID)
        global.oTeamMgr:CheckTimeCb(iTeamID)
    end
    global.oToolMgr:ExecuteList(lTeamIds, 50, 200, 0, sBatchKey, func)
end

function CTeamMgr:CheckTimeCb(iTeamID)
    local oTeam = self.m_mTeamList[iTeamID]
    if oTeam then
        safe_call(oTeam.CheckTimeCb, oTeam)
    end
end
