local global = require "global"
local extend = require "base.extend"
local res = require "base.res"
local interactive = require "base.interactive"
local record = require "public.record"
local playersend = require "base.playersend"

local gamedefines = import(lualib_path("public.gamedefines"))
local taskdefines = import(service_path("task/taskdefines"))
local teaminfo = import(service_path("team/teaminfo"))
local meminfo = import(service_path("team/meminfo"))
local handleteam = import(service_path("team/handleteam"))
local fubenprogress = import(service_path("fuben/progress"))
local servstatectrl = import(service_path("team/serverstatectrl"))
local jyfubensure = import(service_path("team/jyfubensure"))

function NewTeam(...)
    return CTeam:New(...)
end

CTeam = {}
CTeam.__index = CTeam
inherit(CTeam,logic_base_cls())

local APPLY_LEADER = 3*60
local PUSH_LEADER = 12*60

function CTeam:New(pid, teamid)
    local o = super(CTeam).New(self)
    o.m_ID = teamid
    o.m_iLeader = pid
    o.m_lMember = {}
    o.m_mShortLeave = {}
    o.m_mOffline = {}
    o.m_mTask = {}
    o.m_mBlackList = {}
    o.m_lFmtList = {}
    o.m_lFightApply = {}
    o.m_oApplyMgr = teaminfo.NewApplyInfoMgr(teamid)
    o.m_iAppoint = pid
    o.m_oFubenSure = fubenprogress.NewTeamSure(teamid)
    o.m_oJYFubenSure = jyfubensure.NewJYFubenSure(teamid)
    o.m_iFubenId = 0

    o.m_iLeaderActive = get_time()
    o.m_iLeaderState = 1
    o.m_bWarConfirm = false
    o.m_mConfirmPid = {}

    o.m_LeaveWarCB={}
    o.m_oServStateCtrl = servstatectrl.NewTeamServStateCtrl(teamid)

    o:Init()
    return o
end

function CTeam:Init()
    self:UpdateLeaderActive()
end

function CTeam:TeamID()
    return self.m_ID
end

function CTeam:Leader()
    return self.m_iLeader
end

function CTeam:IsLeader(pid)
    if self.m_iLeader == pid then return true end return false
end

function CTeam:GetLeaderObj()
    local oWorldMgr = global.oWorldMgr
    return oWorldMgr:GetOnlinePlayerByPid(self:Leader())
end

function CTeam:OnCreate()
    local oLeader = self:GetLeaderObj()
    if oLeader then
        oLeader:TriggerEvent(gamedefines.EVENT.TEAM_CREATE,{team=self,pid=self.m_iLeader})
    end
end

function CTeam:UpdateLeaderActive()
    self:DelTimeCb("CheckLeaderActive")
    self:DelTimeCb("PushApplyLeader")
    if self.m_iLeaderState == 0 then
        handleteam.RefreshApplyLeaderInfo(self.m_iLeader,self,1)
    end
    self.m_iLeaderActive = get_time()
    self.m_iLeaderState = 1
    local iTeamID  = self:TeamID()
    self:AddTimeCb("CheckLeaderActive",(APPLY_LEADER+1)*1000,function ( )
        _CheckLeaderActive(iTeamID)
    end)

    self:AddTimeCb("PushApplyLeader",(PUSH_LEADER+1)*1000,function ( )
        _PushApplyLeader(iTeamID)
    end)

end

function CTeam:LeaderActive()
    if get_time()<self.m_iLeaderActive + APPLY_LEADER then
        return 1
    end
    return 0
end

function CTeam:CheckLeaderActive()
    self:DelTimeCb("CheckLeaderActive")
    if self:LeaderActive() == 0 and not self:InWar() then
        self.m_iLeaderState = 0
        handleteam.RefreshApplyLeaderInfo(self.m_iLeader,self,self:LeaderActive())
    end
end

function CTeam:PushApplyLeader()
    self:DelTimeCb("PushApplyLeader")
    self:AddTimeCb("PushApplyLeader",(PUSH_LEADER+1)*1000,function ( )
        _PushApplyLeader(iTeamID)
    end)
    if get_time()>self.m_iLeaderActive + PUSH_LEADER and not self:InWar() then
        if not handleteam.LeaderNotActive(self) then
        end
    end
end

function CTeam:InWar()
    local oLeader = self:GetLeaderObj()
    if not oLeader then return end
    return oLeader.m_oActiveCtrl:GetNowWar()
end

function CTeam:GetWarStatus()
    local oLeader = self:GetLeaderObj()
    return oLeader.m_oActiveCtrl:GetWarStatus()
end

function CTeam:EnterWar(oPlayer)
    local oWar = self:InWar()
    if not oWar then return end

    local iStatus = self:GetWarStatus()
    local mArgs = {war_id=oWar:GetWarId(),camp_id=oWar:GetCamp(self.m_iLeader)}
    oWar:EnterObserver(oPlayer,mArgs)
    local oNotifyMgr = global.oNotifyMgr
    if iStatus == gamedefines.WAR_STATUS.IN_WAR then
        oNotifyMgr:Notify(oPlayer:GetPid(), "队伍正在战斗中，进入观战")
    else
        oNotifyMgr:Notify(oPlayer:GetPid(), "队伍正在观战，进入观战")
    end
end

function CTeam:WarEnd()
    self:ExecWarEndCB()
    self:OnWarEnd()
    self:UpdateLeaderActive()
end

function CTeam:OnWarEnd()
    local oWorldMgr = global.oWorldMgr
    for pid , _ in pairs(self:OnlineMember()) do
        local oPlayer = oWorldMgr:GetOnlinePlayerByPid(pid)
        local oMem = self:GetMember(pid)
        if oMem then
            oMem:ResetButton()
        end
        if oPlayer and oMem then
            oPlayer:Send("GS2CButtonState",oMem:PackButton())
        end
    end
end

function CTeam:ExecWarEndCB()
    local mCB = {
    gamedefines.TEAM_CB_FLAG.LEAVE,
    gamedefines.TEAM_CB_FLAG.KICKOUT,
    gamedefines.TEAM_CB_FLAG.SHORTLEAVE,
    gamedefines.TEAM_CB_FLAG.SETLEADER,
    gamedefines.TEAM_CB_FLAG.BACK,
    }
    for _ , mType in ipairs(mCB) do
        if self.m_LeaveWarCB[mType] then
            for flag,funccode in pairs(self.m_LeaveWarCB[mType]) do
                local func = funccode.func
                local args = funccode.args
                if func and args then
                    safe_call(func,args,self)
                else
                    record.warning(string.format("ExecWarEndCB %s",flag))
                end
            end
        end
    end
    self.m_LeaveWarCB = {}
end

function CTeam:GetCBLevel(flag)
    if string.find(flag,gamedefines.TEAM_CB_FLAG.SHORTLEAVE) then
        return gamedefines.TEAM_CB_FLAG.SHORTLEAVE
    elseif string.find(flag,gamedefines.TEAM_CB_FLAG.SETLEADER) then
        return gamedefines.TEAM_CB_FLAG.SETLEADER
    elseif string.find(flag,gamedefines.TEAM_CB_FLAG.KICKOUT) then
        return gamedefines.TEAM_CB_FLAG.KICKOUT
    elseif string.find(flag,gamedefines.TEAM_CB_FLAG.BACK) then
        return gamedefines.TEAM_CB_FLAG.BACK
    elseif string.find(flag,gamedefines.TEAM_CB_FLAG.LEAVE) then
        return gamedefines.TEAM_CB_FLAG.LEAVE
    end
end

function CTeam:AddCB(type,flag,func,args)
    args = args or {}
    if type == gamedefines.TEAM_CB_TYPE.LEAVE_WAR then
        local sLevel = self:GetCBLevel(flag)
        if sLevel then
            if not self.m_LeaveWarCB[sLevel] then
                self.m_LeaveWarCB[sLevel] = {}
            end
            self.m_LeaveWarCB[sLevel][flag]={func=func,args=args}
        end
    end
end

function CTeam:HasCB(type,flag)
    if type == gamedefines.TEAM_CB_TYPE.LEAVE_WAR then
        local sLevel = self:GetCBLevel(flag)
        if self.m_LeaveWarCB[sLevel] then
            return self.m_LeaveWarCB[sLevel][flag]
        end
    end
end

function CTeam:DelCB(type,flag)
    if type == gamedefines.TEAM_CB_TYPE.LEAVE_WAR then
        local sLevel = self:GetCBLevel(flag)
        if self.m_LeaveWarCB[sLevel] then
            self.m_LeaveWarCB[sLevel][flag]=nil
        end
    end
end

function CTeam:ClearMemWarCB(pid)
    local sPID = tostring(pid)
    local mCB = {
    gamedefines.TEAM_CB_FLAG.LEAVE,
    gamedefines.TEAM_CB_FLAG.KICKOUT,
    gamedefines.TEAM_CB_FLAG.SHORTLEAVE,
    gamedefines.TEAM_CB_FLAG.SETLEADER,
    gamedefines.TEAM_CB_FLAG.BACK,
    }
    local mDel = {}
    for _ , mType in ipairs(mCB) do
        if self.m_LeaveWarCB[mType] then
            for flag,funccode in pairs(self.m_LeaveWarCB[mType]) do
                if string.find(flag,sPID) then
                    mDel[mType] = mDel[mType] or {}
                    mDel[mType][flag] = true
                end
            end
        end
    end
    for mType,mFlag in pairs(mDel) do
        for flag,_ in pairs(mFlag) do
            if self.m_LeaveWarCB[mType] and self.m_LeaveWarCB[mType][flag] then
                self.m_LeaveWarCB[mType][flag] = nil
            end
        end
    end
end

function CTeam:IsTeamMember(pid)
    for _,oMem in ipairs(self.m_lMember) do
        if oMem.m_ID == pid then return true end
    end
    return false
end

function CTeam:IsShortLeave(pid)
    if self.m_mShortLeave[pid] then return true end return false
end

function CTeam:GetShortLeave()
    return self.m_mShortLeave
end

function CTeam:OnlineMember()
    local mMem = {}
    for _,oMem in ipairs(self.m_lMember) do mMem[oMem.m_ID] = 1 end
    for pid,oMem in pairs(self.m_mShortLeave) do mMem[pid] = 1 end
    return mMem
end

function CTeam:AllMember()
    local mMem = {}
    for _,oMem in ipairs(self.m_lMember) do mMem[oMem.m_ID] = 1 end
    for pid,oMem in pairs(self.m_mShortLeave) do mMem[pid] = 1 end
    for pid,oMem in pairs(self.m_mOffline) do mMem[pid] = 1 end
    return mMem
end

function CTeam:GetTeamMember()
    local lMem = {}
    for _,oMem in ipairs(self.m_lMember) do table.insert(lMem, oMem.m_ID) end
    return lMem
end

function CTeam:GetTeamShort()
    local mShort = {}
    for _,oMem in pairs(self.m_mShortLeave) do table.insert(mShort,oMem.m_ID) end
    return mShort
end

function CTeam:FilterTeamMember(func)
    local lMember = {}
    for _, oMem in ipairs(self.m_lMember) do
        local rRet = func(oMem)
        if rRet then table.insert(lMember, rRet) end
    end
    return lMember
end

function CTeam:GetMember(pid)
    if not pid then
        return self.m_lMember
    end
    for _,oMem in ipairs(self.m_lMember) do
        if oMem.m_ID == pid then return oMem end
    end
    local oMem = self.m_mShortLeave[pid]
    if oMem then return oMem end
    local oMem = self.m_mOffline[pid]
    return oMem
end

function CTeam:GetMemberPid()
    local lPlist = {}
    for _,oMem in ipairs(self.m_lMember) do
        table.insert(lPlist,oMem.m_ID)
    end
    return lPlist
end

function CTeam:MemberSize()
    if self.m_TestSize then
        return self.m_TestSize
    end
    return table_count(self.m_lMember)
end

function CTeam:OnlineMemberSize()
    return self:MemberSize() + table_count(self.m_mShortLeave)
end

function CTeam:TeamSize()
    return self:OnlineMemberSize() + table_count(self.m_mOffline)
end

function CTeam:MaxTeamSize()
    local iMaxSize = 5
    local iMinSize = 1
    local iTargetID = self:GetTargetID()
    if iTargetID then
        local mTargetData = res["daobiao"]["team"]["autoteam"][iTargetID]
        assert(mTargetData, string.format("team target err:%d", iTargetID))
        assert(mTargetData.max_count<=iMaxSize,string.format("team size err >%d", iMaxSize))
        assert(mTargetData.max_count>=iMinSize,string.format("team size err <%d", iMinSize))
        return mTargetData.max_count
    end
    return iMaxSize
end

function CTeam:GetLeaderGrade()
    local oLeader = self:GetLeaderObj()
    if oLeader then return oLeader:GetGrade() end
end

function CTeam:GetTeamAveGrade()
    local oWorldMgr = global.oWorldMgr
    local iGrade = 0
    local iCnt = 0
    for _,oMem in ipairs(self.m_lMember) do
        local oPlayer = oWorldMgr:GetOnlinePlayerByPid(oMem.m_ID)
        if oPlayer then
            iGrade = iGrade + oPlayer:GetGrade()
            iCnt = iCnt + 1
        end
    end
    return math.floor(iGrade/iCnt)
end

function CTeam:GetTeamMaxGrade()
    local oWorldMgr = global.oWorldMgr
    local iGrade = 0
    for _,oMem in ipairs(self.m_lMember) do
        local oPlayer = oWorldMgr:GetOnlinePlayerByPid(oMem.m_ID)
        if oPlayer and iGrade<oPlayer:GetGrade() then iGrade = oPlayer:GetGrade() end
    end
    return iGrade
end

function CTeam:GetTeamMinGrade()
    local oWorldMgr = global.oWorldMgr
    local oLeader = self:GetLeaderObj()
    local iGrade = oLeader:GetGrade()
    for _,oMem in ipairs(self.m_lMember) do
        local oPlayer = oWorldMgr:GetOnlinePlayerByPid(oMem.m_ID)
        if oPlayer and iGrade > oPlayer:GetGrade() then iGrade = oPlayer:GetGrade() end
    end
    return iGrade
end

function CTeam:OnLogin(oPlayer,bReEnter)
    local pid = oPlayer:GetPid()
    local lRefresh = {[pid] = 1}

    if self:IsTeamMember(pid) or self:IsShortLeave(pid) then
        local oMem=self:GetMember(pid)
        self:GS2CAddTeam(pid)
        oPlayer:Send("GS2CButtonState",oMem:PackButton())
    elseif self.m_mOffline[pid] then
        local oTeamMgr = global.oTeamMgr
        local oChatMgr = global.oChatMgr
        local oToolMgr = global.oToolMgr
        local oMem = self.m_mOffline[pid]
        baseobj_delay_release(oMem)
        self.m_mOffline[pid] = nil
        self:AddShortLeave(oPlayer)
        local sMsg = oToolMgr:FormatColorString("#role上线了", {role = oPlayer:GetName()})
        oChatMgr:HandleTeamChat(oPlayer, sMsg, true)
    else
        record.warning(string.format("team login error %s %s",self.m_ID,pid))
        return
    end
    for _, taskid in pairs(table_key_list(self.m_mTask)) do
        local oTask = self.m_mTask[taskid]
        oTask:OnLogin(oPlayer, bReEnter)
    end

    local mRole = {pid = pid}
    interactive.Send(".broadcast", "channel", "SetupChannel", {
        pid = pid,
        channel_list = {{gamedefines.BROADCAST_TYPE.TEAM_TYPE, self.m_ID, true},},
        info = mRole})
    self.m_oFubenSure:OnLogin(oPlayer)
    self.m_oJYFubenSure:OnLogin(oPlayer)
    self.m_oApplyMgr:SendApplyInfo(oPlayer)
    self:BroadCastTeamPartners(nil, lRefresh)
    self:BroadCastLeaderFmt(lRefresh)
    self:BroadCastTeamAllPos(lRefresh)
    self:RefreshTeamAppoint(pid)
end

function CTeam:OnLogout(oPlayer)
    local oMem
    local pid = oPlayer:GetPid()

    for iPos,oTeamMem in ipairs(self.m_lMember) do
        if oTeamMem.m_ID == pid then
            table.remove(self.m_lMember,iPos)
            oMem = oTeamMem
            break
        end
    end
    if self.m_mShortLeave[pid] then
        oMem = self.m_mShortLeave[pid]
        self.m_mShortLeave[pid]=nil
    end
    if not oMem then
        record.warning(string.format("team logout error %s %s",self.m_ID,pid))
        return
    end
    oMem:SetStatus(gamedefines.TEAM_MEMBER_STATUS.OFFLINE)
    self.m_mOffline[pid] = oMem
    self:TriggerEvent(gamedefines.EVENT.TEAM_OFFLINE, {team = self, pid = pid})
    self:OnLeave(pid,"disconnect")
    for _, iTaskid in pairs(table_key_list(self.m_mTask)) do
        -- 为了让此遍历中可以删除任务，必须遍历另一个table
        local oTask = self.m_mTask[iTaskid]
        if oTask then
            oTask:LeaveTeam(pid, 3)
        end
    end
end

function CTeam:SetLeader(pid)
    local srcpos
    for iPos,oMem in ipairs(self.m_lMember) do
        if oMem.m_ID == pid then
            srcpos = iPos
            break
        end
    end
    assert(srcpos,string.format("error srcpos %s %s",pid,self.m_iLeader))
    local iOLeder = self.m_iLeader
    self.m_iLeader = pid
    self.m_iAppoint = self.m_iLeader
    local oTempMem = self.m_lMember[1]
    self.m_lMember[1] = self:GetMember(pid)
    self.m_lMember[srcpos] = oTempMem
    self:ClearFmtPosInfo()
    self:ClearBlackList()
    for pid,_ in pairs(self:OnlineMember()) do
        self:RefreshTeamStatus(pid)
    end
    self:CheckTargetChange()
    local oLeader=self:GetLeaderObj()
    self:SyncSceneTeam(oLeader)
    self:UpdateLeaderActive()
    self:BroadCast(self:OnlineMember(), "GS2CRefreshTeamAppoint", {
        pid = self.m_iAppoint
        })
    handleteam.RefreshApplyLeaderInfo(self.m_iLeader, self, self:LeaderActive())
    self:OnMemberChange(gamedefines.TEAM_CB_FLAG.SETLEADER, pid)

    local oOLeader = global.oWorldMgr:GetOnlinePlayerByPid(iOLeder)
    local oNLeader = global.oWorldMgr:GetOnlinePlayerByPid(self.m_iLeader)
    if oOLeader then
        oOLeader.m_oStateCtrl:RemoveTeamLeader()
    end
    if oNLeader then
        oNLeader.m_oStateCtrl:AddTeamLeader()
    end
end

function CTeam:AddMember(oMem)
    local pid = oMem.m_ID
    local oWorldMgr = global.oWorldMgr
    local oPlayer = oWorldMgr:GetOnlinePlayerByPid(pid)
    local oTeamMgr = global.oTeamMgr
    oTeamMgr:AddPid2TeamID(pid,self.m_ID)
    local sType = nil
    if self.m_mShortLeave[pid] then
        sType = gamedefines.TEAM_CB_FLAG.BACK
    end
    self.m_mShortLeave[pid] = nil
    self.m_mOffline[pid] = nil
    table.insert(self.m_lMember,oMem)
    self:GS2CAddTeam(pid)
    if oPlayer then
        self:RefreshTeamAppoint(pid)
    end
    for _,oTask in pairs(self.m_mTask) do
        oTask:EnterTeam(pid,1)
    end
    self.m_oFubenSure:OnEnterTeam(pid,1)
    self.m_oJYFubenSure:OnEnterTeam(pid,1)
    local oFuben = self:GetFuben()
    if oFuben then
        oFuben:OnEnterTeam(pid,1)
    end
    for memid,_ in pairs(self:OnlineMember()) do
        if memid ~= pid then
            self:GS2CAddTeamMember(oMem,memid)
            self:RefreshTeamStatus(memid)
        end
    end
    if pid ~= self.m_iLeader then
        self:SyncSceneTeam(oPlayer)
    end
    self.m_oApplyMgr:SendApplyInfo(oPlayer)
    handleteam.PlayerCancelAutoMatch(oPlayer,true)
    self:OnMemberChange(sType, oPlayer:GetPid())
    global.oNotifyMgr:SetupPubTeamChannel(oPlayer, true)
    global.oTeamMgr:TriggerEvent(gamedefines.EVENT.TEAM_ADD_MEMBER, {team = self, player = oPlayer})
    self:TriggerEvent(gamedefines.EVENT.TEAM_ADD_MEMBER, {team = self, pid = pid})
end

function CTeam:Release()
    local oFuben = self:GetFuben()
    if oFuben then
        global.oFubenMgr:DelFuben(oFuben.m_ID)
     end
    local oFubenSure = self.m_oFubenSure
    baseobj_safe_release(oFubenSure)
    self.m_oFubenSure = nil
    local oJYFubenSure = self.m_oJYFubenSure
    baseobj_safe_release(oJYFubenSure)
    self.m_oJYFubenSure = nil
    local oApplyMgr = self.m_oApplyMgr
    baseobj_safe_release(oApplyMgr)
    self.m_oApplyMgr = nil
    baseobj_safe_release(self.m_oServStateCtrl)
    self.m_oServStateCtrl = nil
    super(CTeam).Release(self)
end

function CTeam:ReleaseTeam()--解散队伍
    if self.m_bRelease then
        return
    end
    self.m_bRelease = true
    local oTeamMgr = global.oTeamMgr
    local oSceneMgr = global.oSceneMgr
    local oLeader = self:GetLeaderObj()
    oSceneMgr:RemoveSceneTeam(oLeader,self.m_ID)
    for _,oMem in ipairs(self.m_lMember) do self:Leave(oMem.m_ID,false) end
    for pid, oMem in pairs(self.m_mShortLeave) do self:Leave(pid,false) end
    for pid,oMem in pairs(self.m_mOffline) do self:Leave(pid,false) end

    if self:AutoMatching() then
        interactive.Send(".autoteam", "team", "TeamCancle", {targetid = self:GetTargetID(), teamid = self.m_ID})
    end
    self.m_lMember = {}
    self.m_mShortLeave = {}
    self.m_mOffline = {}
    self.m_mTask = {}
    self.m_lFmtList = {}
    oTeamMgr:RemoveTeam(self:TeamID())
end

function CTeam:Leave(pid,bPlease)
    local oTeamMgr = global.oTeamMgr
    local oWorldMgr = global.oWorldMgr
    local oChatMgr = global.oChatMgr
    local oToolMgr = global.oToolMgr
    local oPlayer = oWorldMgr:GetOnlinePlayerByPid(pid)
    if oPlayer and not bPlease then
        local sMsg = oToolMgr:FormatColorString("#role离开了队伍", {role = oPlayer:GetName()})
        oChatMgr:HandleTeamChat(oPlayer, sMsg, true)
    end

    local oMem
    for iPos,oTempMem in ipairs(self.m_lMember) do
        if oTempMem.m_ID == pid then
            oMem = oTempMem
            table.remove(self.m_lMember,iPos)
            break
        end
    end
    if self.m_mShortLeave[pid] then
        oMem = self.m_mShortLeave[pid]
    end
    if self.m_mOffline[pid] then
        oMem = self.m_mOffline[pid]
    end
    self.m_mShortLeave[pid] = nil
    self.m_mOffline[pid] = nil
    if oMem then
        baseobj_delay_release(oMem)
    end
    self:AddMem2BlackList(pid)
    oTeamMgr:OnLeaveTeam(self:TeamID(), pid)
    self:GS2CDelTeam(pid)

    oTeamMgr:ClearPid2TeamID(pid, self.m_ID)

    for _, iTaskid in pairs(table_key_list(self.m_mTask)) do
        local oTask = self.m_mTask[iTaskid]
        if oTask then
            oTask:LeaveTeam(pid, bPlease and 4 or 1)
        end
    end
    if self.m_oVoteBox then self.m_oVoteBox:OnLeaveTeam(pid, 1) end

    interactive.Send(".broadcast", "channel", "SetupChannel", {
        pid = pid,
        channel_list = {{gamedefines.BROADCAST_TYPE.TEAM_TYPE, self.m_ID, false},},
        info = {pid = pid}})

    self:ClearMemWarCB(pid)
    global.oNotifyMgr:SetupPubTeamChannel(oPlayer, true)
    global.oTeamMgr:TriggerEvent(gamedefines.EVENT.TEAM_LEAVE, {team = self, pid = pid,flag = 1})
    self:TriggerEvent(gamedefines.EVENT.TEAM_LEAVE, {team = self, pid = pid})
    self:OnLeave(pid,"leave")
end

function CTeam:OnLeave(pid,sTeamOp)
    local oWorldMgr = global.oWorldMgr
    local oNotifyMgr = global.oNotifyMgr
    local oChatMgr = global.oChatMgr
    local oToolMgr = global.oToolMgr
    local iPreLeader = self.m_iLeader
    local oSceneMgr = global.oSceneMgr
    local oPreLeader = oWorldMgr:GetOnlinePlayerByPid(pid)
    if oPreLeader then
        oPreLeader.m_oStateCtrl:RemoveTeamLeader()
    end

    if table_count(self.m_lMember) >= 1 then
        local oMem = self.m_lMember[1]
        local bChange = self.m_iLeader ~= oMem.m_ID
        self.m_iLeader = oMem.m_ID
        if bChange then
            self:OnChangeLeader(oMem.m_ID)
        end
    elseif table_count(self.m_mShortLeave) >= 1 then
        for pid,_ in pairs(self.m_mShortLeave) do
            oSceneMgr:RemoveSceneTeam(oPreLeader,self.m_ID)
            self.m_iLeader = pid
            local oLeader = self:GetLeaderObj()
            local oMem = self.m_mShortLeave[pid]
            self.m_mShortLeave[pid] = nil
            oMem:SetStatus(gamedefines.TEAM_MEMBER_STATUS.MEMBER)
            table.insert(self.m_lMember,1,oMem)
            oSceneMgr:CreateSceneTeam(oLeader,self.m_ID)
            self:OnChangeLeader(pid)
            break
        end
    else
        local oLeader = self:GetLeaderObj()
        if oLeader then
            oSceneMgr:RemoveSceneTeam(oLeader,self.m_ID)     
        end
        self:OnMemberChange(sTeamOp, pid)
        self:ReleaseNotify(pid)
        self:ReleaseTeam()
        return
    end

    self:ClearFmtPosInfo()
    for pid,_ in pairs(self:OnlineMember()) do
        self:RefreshTeamStatus(pid)
    end
    local oLeader = self:GetLeaderObj()
    if not oLeader then
        record.warning(string.format("team onleave error %s",self.m_iLeader))
    end
    if iPreLeader ~= self.m_iLeader then
        self:UpdateLeaderActive()
        handleteam.RefreshApplyLeaderInfo(self.m_iLeader, self, self:LeaderActive())
        self:CheckTargetChange()
        self:ClearBlackList()
        oNotifyMgr:Notify(self:Leader(), "你已被任命为队长")
        if oLeader then
            oChatMgr:HandleTeamChat(oLeader, oToolMgr:FormatColorString("#G#role#n已成为队长", {role = oLeader:GetName()}), true)
        end
    end
    if oLeader then
        self:SyncSceneTeam(oLeader)
    end
    if pid == self.m_iAppoint then
        self:SetAppoint(0,0)
    end
    self:OnMemberChange(sTeamOp, pid)

    if is_gs_server() then
        global.oEngageMgr:OnLeaveTeam(pid)
    end
end

function CTeam:AddShortLeave(oPlayer)
    local oTeamMgr = global.oTeamMgr
    local pid = oPlayer:GetPid()
    local oLeader = self:GetLeaderObj()
    oTeamMgr:AddPid2TeamID(pid,self.m_ID)
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
    handleteam.PlayerCancelAutoMatch(oPlayer,true)
    local oMem = meminfo.NewMember(pid,mArgs)
    self.m_mShortLeave[pid]  = oMem
    oMem:SetStatus(gamedefines.TEAM_MEMBER_STATUS.SHORTLEAVE)
    self:GS2CAddTeam(pid)
    for memid,_ in pairs(self:OnlineMember()) do
        if memid ~= pid then
            self:GS2CAddTeamMember(oMem,memid)
            self:RefreshTeamStatus(memid)
        end
    end

    interactive.Send(".broadcast", "channel", "SetupChannel", {
        pid = oPlayer:GetPid(),
        channel_list = {
            {gamedefines.BROADCAST_TYPE.TEAM_TYPE, self.m_ID, true},
        },
        info = {pid = oPlayer:GetPid(),},
    })
    global.oNotifyMgr:SetupPubTeamChannel(oPlayer, true)

    oMem:UpdateLeaderActiveStatus(self:LeaderActive())
    self:SyncSceneTeam(oLeader)
    self:RefreshTeamAppoint(pid)


    local oChatMgr = global.oChatMgr
    local oToolMgr = global.oToolMgr
    local sText = oToolMgr:FormatColorString("欢迎#role加入队伍",{role = oPlayer:GetName()})
    self:TeamNotify(sText,{[pid]=true})
    sText = oToolMgr:FormatColorString("#role加入了队伍", {role = oPlayer:GetName()})
    oChatMgr:HandleTeamChat(oPlayer, sText, true)

    if self:AutoMatching() then
        if self:TeamSize() >= self:MaxTeamSize() then
            self:CancleAutoMatch()
            global.oNotifyMgr:Notify(self:Leader(), "队伍人数已满，停止自动匹配")
        else
            oTeamMgr:EnterAutoTeam(self, oMem)
        end
    end
    local oFuben = self:GetFuben()
    if oFuben then
        oFuben:OnEnterTeam(pid,3)
    end
    global.oTeamMgr:TriggerEvent(gamedefines.EVENT.TEAM_ADD_SHORT_LEAVE, {team = self, player = oPlayer})
    self:TriggerEvent(gamedefines.EVENT.TEAM_ADD_SHORT_LEAVE, {team = self, pid = pid})
end

function CTeam:ShortLeave(pid)
    local oMem
    for iPos,oTeamMem in ipairs(self.m_lMember) do
        if oTeamMem.m_ID == pid then
            oMem = oTeamMem
            table.remove(self.m_lMember,iPos)
            break
        end
    end
    if not oMem then return end
    global.oTeamMgr:AddPid2TeamID(pid,self.m_ID)
    self.m_mShortLeave[pid]  = oMem
    oMem:SetStatus(gamedefines.TEAM_MEMBER_STATUS.SHORTLEAVE)
    for _, iTaskid in pairs(table_key_list(self.m_mTask)) do
        local oTask = self.m_mTask[iTaskid]
        if oTask then
            oTask:LeaveTeam(pid, 2)
        end
    end
    if self.m_oVoteBox then self.m_oVoteBox:OnLeaveTeam(pid, 2) end
    self.m_oFubenSure:OnLeaveTeam(pid,2)
    self.m_oJYFubenSure:OnLeaveTeam(pid,2)
    local oFuben = self:GetFuben()
    if oFuben then
        oFuben:OnLeaveTeam(pid,2)
    end
    global.oTeamMgr:TriggerEvent(gamedefines.EVENT.TEAM_SHORTLEAVE, {team = self, pid = pid,flag = 2})
    self:TriggerEvent(gamedefines.EVENT.TEAM_SHORTLEAVE, {team = self, pid = pid})
    self:OnLeave(pid,"shortleave")
end

function CTeam:ValidTransToLeader(oPlayer,iOP)
    local oLeader = self:GetLeaderObj()
    local oHuodongMgr = global.oHuodongMgr
    local oNowScene1 = oPlayer.m_oActiveCtrl:GetNowScene()
    local oNowScene2 = oLeader.m_oActiveCtrl:GetNowScene()
    if oNowScene1:GetSceneId() ~= oNowScene2:GetSceneId() then
        if oNowScene1:ValidLeave(oPlayer,oNowScene2) and oNowScene2:ValidEnter(oPlayer) then
            if oNowScene2.m_HDName then
                local oHD = oHuodongMgr:GetHuodong(oNowScene2.m_HDName)
                if oHD.ValidEnterTeam and  not oHD:ValidEnterTeam(oPlayer,oLeader,iOP) then
                    return false
                end
            elseif oNowScene2.fubenname then
                local oFuben = oLeader:IsInFuBen()
                if oFuben and oFuben.ValidEnterTeam and  not oFuben:ValidEnterTeam(oPlayer,oLeader,iOP) then
                    return false
                end
            end
            return true
        else
            return false
        end
    else
        return true
    end
end

function CTeam:BackTeam(oPlayer)
    local pid = oPlayer:GetPid()
    local oToolMgr = global.oToolMgr
    local oNotifyMgr = global.oNotifyMgr
    local oChatMgr = global.oChatMgr
    local oSceneMgr = global.oSceneMgr
    local oLeader = self:GetLeaderObj()
    local oWorldMgr = global.oWorldMgr
    local oMem = self.m_mShortLeave[pid]
    oSceneMgr:TransToLeader(oPlayer,self.m_iLeader)
    self.m_mShortLeave[pid] = nil
    oMem:SetStatus(gamedefines.TEAM_MEMBER_STATUS.MEMBER)
    table.insert(self.m_lMember,oMem)
     for _,oTask in pairs(self.m_mTask) do
        oTask:EnterTeam(pid,2)
    end
    self.m_oFubenSure:OnEnterTeam(pid,2)
    self.m_oJYFubenSure:OnEnterTeam(pid,2)
    for memid,_ in pairs(self:OnlineMember()) do self:RefreshTeamStatus(memid) end
    oMem:UpdateLeaderActiveStatus(self:LeaderActive())
    self:SyncSceneTeam(oLeader)
    oNotifyMgr:Notify(iPid, "你回到了队伍")
    local sMsg = oToolMgr:FormatColorString("#role回到队伍", {role = oPlayer:GetName()})
    oChatMgr:HandleTeamChat(oPlayer, sMsg, true)
    self:TriggerEvent(gamedefines.EVENT.TEAM_BACKTEAM, {team = self, pid = pid})
end

function CTeam:AddMem2BlackList(pid)
    self.m_mBlackList[pid] = get_time() + (5 * 60)
end

function CTeam:CheckBlackList()
    local iNow = get_time()
    for pid, iTime in pairs(self.m_mBlackList) do
        if iTime <= iNow then self.m_mBlackList[pid] = nil end
    end
end

function CTeam:GetBlackListMemTime(pid)
    return self.m_mBlackList[pid] or get_time()
end

function CTeam:ClearBlackList()
    self.m_mBlackList = {}
end

function CTeam:CheckTimeCb()
    self:CheckTaskTimeCb()
end

function CTeam:CheckTaskTimeCb()
    for _, taskid in pairs(table_key_list(self.m_mTask)) do
        local oTask = self.m_mTask[taskid]
        if oTask then
            oTask:CheckTimeCb()
        end
    end
end

function CTeam:AddTask(oTask)
    self.m_mTask[oTask.m_ID] = oTask
    for _,oMem in ipairs(self.m_lMember) do
        oTask:AddPlayer(oMem.m_ID)
    end
end

function CTeam:TaskList()
    return self.m_mTask
end

function CTeam:GetTask(iTask)
    return self.m_mTask[iTask]
end

function CTeam:GetTaskByType(iType)
    for _,oTask in pairs(self.m_mTask) do
        if oTask:Type() == iType then return oTask end
    end
end

function CTeam:DetachTask(iTask)
    self.m_mTask[iTask] = nil
end

function CTeam:RemoveTask(iTask)
    local oTask = self:GetTask(iTask)
    if oTask then
        self.m_mTask[iTask] = nil
        oTask:FullRemove()
    end
end

function CTeam:HasTaskType(iType)
    for _,oTask in pairs(self.m_mTask) do
        if oTask:TaskType() == iType then
            return oTask
        end
    end
end

function CTeam:HasTaskKind(iKind)
    for _,oTask in pairs(self.m_mTask) do
        if oTask:Type() == iKind then
            return oTask
        end
    end
end

function CTeam:MissionDone(oTask, npcobj, mArgs)
    local iLeader = self:Leader()
    global.oTaskMgr:DealMissionDone(oTask, iLeader, npcobj, mArgs)
    -- 使用todo滞后Release操作（防队伍其他处理）
    -- global.oTaskMgr:AppendTodo(oTask, taskdefines.TASK_ACTION.RELEASE)
end

function CTeam:NextTask(oFromTask, iTaskid, npcobj, mArgs)
    if oFromTask then
        self:MissionDone(oFromTask, npcobj, mArgs)
    end
    local oTask = global.oTaskLoader:CreateTask(iTaskid)
    if not oTask then
        return
    end
    handleteam.AddTask(self:Leader(), oTask)
end

function CTeam:GetApplyMgr()
    return self.m_oApplyMgr
end

function CTeam:ResetAutoTeam()
    self.m_AutoTarget = nil
end

function CTeam:AutoMatching()
    local mTarget = self.m_AutoTarget
    if mTarget and mTarget.team_match == 1 then
        return true
    else
        return false
    end
end

function CTeam:AutoMatchEnough()
    local iTargetID = self:GetTargetID()
    if iTargetID then
        local res = require "base.res"
        local mTarget = res["daobiao"]["team"]["autoteam"][iTargetID]
        if mTarget then
            if self:TeamSize() >= mTarget.max_count then return true end
        end
    end
    return false
end

function CTeam:CancleAutoMatch()
    local mTarget = extend.Table.deep_clone(self:PackTargetInfo())
    mTarget.team_match = 0
    self:SetAutoMatchTarget(mTarget)

    self:OnCancelAutoMatch()
end

function CTeam:SetAutoMatchTarget(mData)
    if self:AutoMatching() then
        interactive.Send(".autoteam","team","CancleTeamAutoMatch", {targetid = self:GetTargetID(),teamid = self.m_ID})
    end
    self.m_AutoTarget = mData
    if mData.team_match == 1 then
        local oNotifyMgr = global.oNotifyMgr
        interactive.Send(".autoteam","team","TeamStartAutoMatch", {
            targetid = mData.auto_target,
            teamid = self.m_ID,
            team_info = self:PackAutoTeamInfo()
        })
        self.m_iStartMatchTime = get_time()
        oNotifyMgr:Notify(self:Leader(), "已开始自动匹配，请稍候")
    end

    local mNet = {}
    mNet["target_info"] = self:PackTargetInfo()
    self:BroadCast(self:OnlineMember(),"GS2CTargetInfo",mNet)
end

function CTeam:GetTargetID()
    local mTarget = self:PackTargetInfo()
    if mTarget then return mTarget["auto_target"] end
    return 0
end

function CTeam:PackTargetInfo()
    if not self.m_AutoTarget then return self:DefaultTargetInfo(0) end
    return self.m_AutoTarget
end

function CTeam:DefaultTargetInfo(iTargetID, iMatch)
    local oWorldMgr = global.oWorldMgr
    local iTargetID = iTargetID or 0
    local res = require "base.res"
    local mData = res["daobiao"]["team"]["autoteam"][iTargetID]
    local oLeader = self:GetLeaderObj()
    if mData then
        local iServerGrade = oLeader and oLeader:GetServerGrade() or oWorldMgr:GetServerGrade()
        local iType = mData.target_type
        local mTarget = {}
        mTarget["auto_target"] = iTargetID
        mTarget["team_match"] = iMatch or 0
        if iType == 0 then
            local iGrade = self:GetLeaderGrade()
            mTarget["min_grade"] = math.max(iGrade - 5, mData.unlock_level)
            mTarget["max_grade"] = math.min(iGrade + 5, iServerGrade + 8)
        else
            mTarget["min_grade"] = mData.unlock_level
            mTarget["max_grade"] = iServerGrade + 8
        end
        return mTarget
    end
end

function CTeam:LeaderInTargetLevel()
    local mTarget = self.m_AutoTarget
    if mTarget then
        local mDefaultTarget = self:DefaultTargetInfo(mTarget.auto_target)
        if (mDefaultTarget.min_grade <= mTarget.min_grade) and (mDefaultTarget.max_grade >= mTarget.max_grade) then
            return true
        end
    end
    return false
end

function CTeam:CheckTargetChange()
    local oLeader = self:GetLeaderObj()
    local mTarget = self:PackTargetInfo()

    if self:AutoMatching() then self:CancleAutoMatch() end

    if oLeader and mTarget then
        local iGrade = oLeader:GetGrade()
        if iGrade < mTarget.min_grade or iGrade > mTarget.max_grade then
            self:SetAutoMatchTarget(self:DefaultTargetInfo() , false)
        end
    end
end

function CTeam:SetFmtPosInfo(lPosList)
    self.m_lFmtList = lPosList or {}
end

function CTeam:ClearFmtPosInfo()
    self.m_lFmtList = {}
    self:BroadCastTeamPartners()
    self:BroadCastLeaderFmt()
    self:BroadCastTeamAllPos()
end

function CTeam:FixFmtPosList()
    local lRemove = {}
    local lMember = self:GetTeamMember()
    for idx, iMember in ipairs(self.m_lFmtList) do
        if not table_in_list(lMember, iMember) then
            table.insert(lRemove, idx)
        end
    end
    for i = #lRemove, 1, -1 do
        table.remove(self.m_lFmtList, lRemove[i])
    end
    for idx, iMember in ipairs(lMember) do
        if not table_in_list(self.m_lFmtList, iMember) then
            table.insert(self.m_lFmtList, iMember)
        end
    end
end

function CTeam:GetFmtPosList()
    self:FixFmtPosList()
    return self.m_lFmtList
end

--------------打包-----------------
function CTeam:PackTeamInfo(bExt)
    local mNet = {}
    mNet["teamid"] = self.m_ID
    mNet["leader"] = self.m_iLeader
    local mMem = {}
    for _,oMem in ipairs(self.m_lMember) do
        table.insert(mMem,oMem:PackInfo())
    end
    for _,oMem in pairs(self.m_mShortLeave) do
        table.insert(mMem,oMem:PackInfo())
    end
    for _,oMem in pairs(self.m_mOffline) do
        local mData = oMem:PackInfo()
        table.insert(mMem,mData)
    end
    mNet["target_info"] = self:PackTargetInfo()
    mNet["member"] = mMem

    if bExt then
        local oLeader = self:GetLeaderObj()
        if oLeader then
            local oFormation = oLeader:GetFormationMgr()
            mNet["fmt_id"] = oFormation:GetCurrFmt()
            mNet["fmt_grade"] = oFormation:GetGrade(mNet.fmt_id)
            mNet["partner_list"] = oLeader.m_oPartnerCtrl:PackTeamPartners()
        end
    end
    return mNet
end

function CTeam:PackAutoTeamInfo()
    local mMem = {}
    for _,oMem in ipairs(self.m_lMember) do
        table.insert(mMem,oMem:PackAutoTeamInfo())
    end
    for _,oMem in pairs(self.m_mShortLeave) do
        table.insert(mMem,oMem:PackAutoTeamInfo())
    end
    for _,oMem in pairs(self.m_mOffline) do
        table.insert(mMem,oMem:PackAutoTeamInfo())
    end
    self:CheckBlackList()
    local mArgs = {
        leader = self.m_iLeader,
        target_info = self.m_AutoTarget or {},
        mem = mMem,
        black_list = self.m_mBlackList,
    }
    return mArgs
end

------------------------------协议---------------------------
function CTeam:GS2CAddTeam(pid)
    local mNet = self:PackTeamInfo(true)
    local oWorldMgr = global.oWorldMgr
    local oPlayer = oWorldMgr:GetOnlinePlayerByPid(pid)
    if oPlayer then
        oPlayer:Send("GS2CAddTeam",mNet)
    end
end

function CTeam:GS2CDelTeam(pid)
    local mNet = {}
    local oWorldMgr = global.oWorldMgr
    local oPlayer = oWorldMgr:GetOnlinePlayerByPid(pid)
    if oPlayer then
        oPlayer:Send("GS2CDelTeam",mNet)
    end
end

function CTeam:BroadCast(plist,sMessage,mData, mExclude)
    local mExclude = mExclude or {}
    for pid,_ in pairs(plist) do
        if not mExclude[pid] then
            local oWorldMgr = global.oWorldMgr
            local oPlayer = oWorldMgr:GetOnlinePlayerByPid(pid)
            if oPlayer then oPlayer:Send(sMessage,mData) end
        end
    end
end

function CTeam:SyncSceneTeam(oPlayer)
    if self.m_bRelease == true then
        return
    end
    if oPlayer then
        local oSceneMgr = global.oSceneMgr
        oSceneMgr:SyncSceneTeam(oPlayer)
    end
end

function CTeam:RefreshTeamStatus(pid)
    local oWorldMgr = global.oWorldMgr
    local oPlayer = oWorldMgr:GetOnlinePlayerByPid(pid)
    if oPlayer then
        local mNet = {}
        local mStatus = {}
        for _,oMem in ipairs(self.m_lMember) do
            table.insert(mStatus,{pid=oMem.m_ID,status=1})
        end
        for _,oMem in pairs(self.m_mShortLeave) do
            table.insert(mStatus,{pid=oMem.m_ID,status=2})
        end
        for _,oMem in pairs(self.m_mOffline) do
            table.insert(mStatus,{pid=oMem.m_ID,status=3})
        end
        mNet["team_status"] = mStatus
        oPlayer:Send("GS2CRefreshTeamStatus",mNet)
    end
end

function CTeam:GS2CAddTeamMember(oMem,target)
    local mNet = {}
    local oWorldMgr = global.oWorldMgr
    local oTarget = oWorldMgr:GetOnlinePlayerByPid(target)
    mNet["mem_info"] = oMem:PackInfo()
    if oTarget then oTarget:Send("GS2CAddTeamMember",mNet) end
end

function CTeam:BroadCastTeamAllPos(lTarget)
    local oLeader = self:GetLeaderObj()
    if oLeader then
        local lOnline = lTarget or self:OnlineMember()
        local mNet = {}
        mNet.player_list = self:GetFmtPosList()
        mNet.partner_list = oLeader.m_oPartnerCtrl:GetCurrLineupPos()
        self:BroadCast(lOnline, "GS2CGetTeamAllPos", mNet)
    end
end

function CTeam:BroadCastTeamPartners(lPartner, lTarget)
    local oLeader = self:GetLeaderObj()
    if oLeader then
        local lOnline = lTarget or self:OnlineMember()
        local mNet = {}
        mNet.partner_list = oLeader.m_oPartnerCtrl:PackTeamPartners(lPartner)
        self:BroadCast(lOnline, "GS2CTeamPartners", mNet)
    end
end

function CTeam:BroadCastLeaderFmt(lTarget)
    local oLeader = self:GetLeaderObj()
    if oLeader then
        local oFormation = oLeader:GetFormationMgr()
        local mNet = {}
        mNet.fmt_id = oFormation:GetCurrFmt()
        mNet.fmt_grade = oFormation:GetGrade(mNet.fmt_id)
        local lOnline = lTarget or self:OnlineMember()
        self:BroadCast(lOnline, "GS2CTeamLeaderFmt", mNet)
    end
end

function CTeam:TeamNotify(sMsg,mExclude)
    mExclude = mExclude or {}
    local oNotify = global.oNotifyMgr
    local lMember = self:GetTeamMember()
    for _, iPid in pairs(lMember) do
        if not mExclude[iPid] then
            oNotify:Notify(iPid, sMsg)
        end
    end
end

function CTeam:SetFuben(iFubenId)
    self.m_iFubenId = iFubenId
end

function CTeam:GetFuben()
    local oFubenMgr = global.oFubenMgr
    return oFubenMgr:GetFuben(self.m_iFubenId)
end


function CTeam:SetAppoint(pid, iAppoint)
    local oWorldMgr = global.oWorldMgr
    local oChatMgr = global.oChatMgr
    local oToolMgr = global.oToolMgr
    local oLeader = self:GetLeaderObj()
    if iAppoint == 0 then
        self.m_iAppoint = self:Leader()
    else
        local oPlayer = oWorldMgr:GetOnlinePlayerByPid(pid)
        local sMsg = ""
        if self.m_iAppoint == self:Leader() then
            sMsg = oToolMgr:FormatColorString("#role被委任为战斗指挥", {role = oPlayer:GetName()})
        else
            if self.m_iAppoint == pid then
                sMsg = oToolMgr:FormatColorString("#role已经是战斗指挥", {role = oPlayer:GetName()})
                oChatMgr:HandleTeamChat(oLeader,sMsg,true)
                self:TeamNotify(sMsg)
                return
            end
            sMsg = oToolMgr:FormatColorString("#role被委任为新的战斗指挥", {role = oPlayer:GetName()})
        end
        self.m_iAppoint = pid
        oChatMgr:HandleTeamChat(oLeader,sMsg,true)
        self:TeamNotify(sMsg)
    end
    local memlist = self:OnlineMember()
    self:BroadCast(memlist, "GS2CRefreshTeamAppoint", {
        pid = self.m_iAppoint
        })
    if self:InWar() then
        local oWar = self:InWar()
        local mData = {}
        local mNet = {}
        mData.appoint = self.m_iAppoint
        mNet.data = mData
        mNet.type = 2
        oWar:Forward("C2GSWarCommand", oLeader:GetPid(), mNet)
    end
end

function CTeam:RefreshTeamAppoint(pid)
    local oWorldMgr = global.oWorldMgr
    local oPlayer = oWorldMgr:GetOnlinePlayerByPid(pid)
    if oPlayer then
        oPlayer:Send("GS2CRefreshTeamAppoint", {
            pid = self.m_iAppoint
            })
    end
end

function CTeam:GetScore(mExclude)
    local iScore = 0
    local lScore = {}
    local oWorldMgr = global.oWorldMgr
    for _,oMem in ipairs(self.m_lMember) do
        local oTarget = oWorldMgr:GetOnlinePlayerByPid(oMem.m_ID)
        if oTarget then
            table.insert(lScore,oTarget:GetScore(mExclude))
        end
    end
    table.sort(lScore,function (iScore1,iScore2)
        return iScore1>iScore2
    end)
    local iRadio  = 0
    for index,iValue in ipairs(lScore) do
        if index == 1 then
            iScore = iScore +iValue*50
            iRadio = iRadio + 50
        elseif index == 2 then
            iScore = iScore +iValue*20
            iRadio = iRadio + 20
        else
            iScore = iScore +iValue*10
            iRadio = iRadio + 10
        end
    end
    return math.floor(iScore/iRadio)
end

function CTeam:GetScoreDebug(mExclude)
    local sMsg = ""
    local sSum = ""
    local iScore = 0
    local lScore = {}
    local oWorldMgr = global.oWorldMgr
    for _,oMem in ipairs(self.m_lMember) do
        local oTarget = oWorldMgr:GetOnlinePlayerByPid(oMem.m_ID)
        if oTarget then
            table.insert(lScore,{oTarget:GetScore(mExclude),oTarget:GetName()})
        end
    end
    table.sort(lScore,function (iScore1,iScore2)
        return iScore1[1]>iScore2[1]
    end)
    local iRadio  = 0
    for index,mInfo in ipairs(lScore) do
        local iValue = mInfo[1]
        local sName = mInfo[2]
        if index == 1 then
            iScore = iScore +iValue*50
            sSum = sSum .. string.format("%s=%s(%s*50)\n",sName,iValue*50,iValue)
            iRadio = iRadio + 50
        elseif index == 2 then
            iScore = iScore +iValue*20
            sSum = sSum .. string.format("%s=%s(%s*20)\n",sName,iValue*20,iValue)
            iRadio = iRadio + 20
        else
            iScore = iScore +iValue*10
            sSum = sSum .. string.format("%s=%s(%s*10)\n",sName,iValue*10,iValue)
            iRadio = iRadio + 10
        end
    end
    local iResult = math.floor(iScore/iRadio)
    sMsg = sMsg .. string.format("%s\n%s=%s/%s",sSum,iResult,iScore,iRadio)
    return sMsg
end

function CTeam:ReleaseNotify(pid)
    if self.m_bReleaseNotify then
        return
    end

    self.m_bReleaseNotify = true
    local mNet = {}
    mNet.cmd = "队伍解散"
    mNet.type = gamedefines.CHANNEL_TYPE.TEAM_TYPE
    mNet.role_info = {pid = 0}
    --mNet = playersend.PackData("GS2CChat",mNet)

    local oWorldMgr = global.oWorldMgr
    local oPlayer = oWorldMgr:GetOnlinePlayerByPid(pid)
    if oPlayer then
        oPlayer:Send("GS2CChat",mNet)
    end
    for _,oMem in ipairs(self.m_lMember) do
        local oPlayer = oWorldMgr:GetOnlinePlayerByPid(oMem.m_ID)
        if oPlayer then
            oPlayer:Send("GS2CChat",mNet)
        end
    end
    for pid ,_ in pairs(self.m_mShortLeave) do
        local oPlayer = oWorldMgr:GetOnlinePlayerByPid(pid)
        if oPlayer then
            oPlayer:Send("GS2CChat",mNet)
        end
    end
end

function CTeam:GetConfirmObj()
    local oConfirmMgr = global.oConfirmMgr
    return oConfirmMgr:GetConfrimObjByTeamId(self:TeamID())
end

function CTeam:OnMemberChange(sType, iPid)
    if not sType or sType == gamedefines.TEAM_CB_FLAG.SETLEADER then
        self:ClearWarConfirm()
        local oHuodong = global.oHuodongMgr:GetHuodong("orgwar")
        if oHuodong then
            oHuodong:OnChangeLeader(iPid)
        end
        self.m_iClickGhost = nil
        self:OnChangeLeader(iPid)
    elseif sType == gamedefines.TEAM_CB_FLAG.BACK then
        if not self.m_mConfirmPid[iPid] then
            self.m_bWarConfirm = false
            self.m_mConfirmPid[iPid] = nil
        end
    elseif sType == gamedefines.TEAM_CB_FLAG.LEAVE then
        self.m_oFubenSure:OnLeaveTeam(iPid,1,oMem)
        self.m_oJYFubenSure:OnLeaveTeam(iPid,1,oMem)
        local oFuben = self:GetFuben()
        if oFuben then
            oFuben:OnLeaveTeam(iPid,1)
        end
    end
    local oConfirm = self:GetConfirmObj()
    if oConfirm then
        oConfirm:OnMemberChange(self)
    end
end

function CTeam:OnChangeLeader(iPid)
    for iTask, oTask in pairs(self.m_mTask) do
        safe_call(oTask.OnChangeLeader, oTask, iPid)
    end
end

function CTeam:ClearWarConfirm()
    self.m_bWarConfirm = false
    self.m_mConfirmPid = {}
end

function CTeam:SetWarConfirm(bConfirm)
    self.m_bWarConfirm = bConfirm
end

function CTeam:IsWarConfirm()
    return self.m_bWarConfirm
end

function CTeam:SetPlayerConfirm(iPid)
    self.m_mConfirmPid[iPid] = true
end

function CTeam:GetWarConfirmPid()
    local lConfirmPid = {}
    if self:IsWarConfirm() then return lConfirmPid end

    local oWorldMgr = global.oWorldMgr
    local oLeader = self:GetLeaderObj()
    local oFriend = oLeader:GetFriend()

    local mMem = self:GetTeamMember()
    for _, iPid in pairs(mMem) do
        local oMem = oWorldMgr:GetOnlinePlayerByPid(iPid)
        if oMem and not self:IsLeader(iPid) and not oFriend:HasFriend(iPid) then
            table.insert(lConfirmPid, iPid)
        end
    end
    return lConfirmPid
end

function CTeam:AddServStateByArgs(sStateId, mArgs)
    return self.m_oServStateCtrl:AddServStateByArgs(sStateId, mArgs)
end

function CTeam:RemoveServState(sStateId)
    self.m_oServStateCtrl:RemoveServState(sStateId)
end

function CTeam:OnLeaveObserver(oPlayer)
    local pid = oPlayer:GetPid()
    local oMem = self:GetMember(pid)
    if not oMem then
        return
    end
    local flag = global.oTeamMgr:GetCBFlag("back",pid)
    if self:HasCB(gamedefines.TEAM_CB_TYPE.LEAVE_WAR,flag) then
        self:DelCB(gamedefines.TEAM_CB_TYPE.LEAVE_WAR,flag)
        oMem:SetBackButtonState(oPlayer,0)
        return
    end
end

function CTeam:OnCancelAutoMatch()
    global.oGhostHandler:OnCancelAutoMatch(self)
end

function _CheckLeaderActive(iTeamID)
    local oTeamMgr = global.oTeamMgr
    local oTeam = oTeamMgr:GetTeam(iTeamID)
    if not oTeam then return end
    oTeam:CheckLeaderActive()
end

function _PushApplyLeader(iTeamID)
    local oTeamMgr = global.oTeamMgr
    local oTeam = oTeamMgr:GetTeam(iTeamID)
    if not oTeam then return end
    oTeam:PushApplyLeader()
end

