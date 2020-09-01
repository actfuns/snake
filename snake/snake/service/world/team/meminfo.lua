local global = require "global"
local net = require "base.net"
local extend = require "base.extend"

local gamedefines = import(lualib_path("public.gamedefines"))

function NewMember(...)
    return CMember:New(...)
end

StatusHelperFunc = {}

function StatusHelperFunc.hp(o)
    return o:GetHp()
end

function StatusHelperFunc.mp(o)
    return o:GetMp()
end

function StatusHelperFunc.max_hp(o)
    return o:GetMaxHp()
end

function StatusHelperFunc.max_mp(o)
    return o:GetMaxMp()
end

function StatusHelperFunc.model_info(o)
    return o:GetModelInfo()
end

function StatusHelperFunc.icon(o)
    return o:GetIcon()
end

function StatusHelperFunc.name(o)
    return o:GetName()
end

function StatusHelperFunc.grade(o)
    return o:GetGrade()
end

function StatusHelperFunc.school(o)
    return o:GetSchool()
end

function StatusHelperFunc.status(o)
    return o:Status()
end

function StatusHelperFunc.orgid(o)
    return o:GetOrgId()
end

function StatusHelperFunc.score(o)
    return o:GetScore()
end

CMember = {}
CMember.__index = CMember
inherit(CMember,logic_base_cls())

function CMember:New(pid,mArgs)
    local o = super(CMember).New(self)
    o.m_ID = pid
    o:Init(mArgs)
    return o
end

function CMember:Init(mArgs)
    self.m_mModelInfo = mArgs.model_info
    self.m_sName = mArgs.name or ""
    self.m_iSchool = mArgs.school or 1
    self.m_iIcon = mArgs.icon or 0
    self.m_iGrade = mArgs.grade or 0
    self.m_iHp = mArgs.hp or 0
    self.m_iMaxHp = mArgs.maxhp or 0
    self.m_iMp = mArgs.mp or 0
    self.m_iMaxMp = mArgs.maxmp or 0
    self.m_iStatus = 1
    self.m_iOnlineStatus = 1
    self.m_iOrgId = 0
    self.m_iScore = mArgs.score or 0
    self.m_iTeamAllowed = mArgs.team_allowed or 1

    self.m_lKickButtonStatue = {}
    self.m_iLeaveButtonStatue = 0
    self.m_iShortLeaveButtonStatue = 0
    self.m_iBackTeamButtonStatue = 0
end

function CMember:MemberID()
    return self.m_ID
end

function CMember:Update(mArgs)
    local mKey = {}
    for key,_ in pairs(mArgs) do
        if StatusHelperFunc[key] then
            mKey[key] = 1
        end
    end

    if table_count(mKey) <= 0 then
        return
    end
    self.m_mModelInfo = mArgs.model_info or self.m_mModelInfo
    self.m_sName = mArgs.name or self.m_sName
    self.m_iIcon = mArgs.icon or self.m_iIcon
    self.m_iSchool = mArgs.school or self.m_iSchool
    self.m_iGrade = mArgs.grade or self.m_iGrade
    self.m_iHp = mArgs.hp or self.m_iHp
    self.m_iMaxHp = mArgs.maxhp or self.m_iMaxHp
    self.m_iMp = mArgs.mp or self.m_iMp
    self.m_iMaxMp = mArgs.maxmp or self.m_iMaxMp
    self.m_iOrgId = mArgs.orgid or self.m_iOrgId
    self.m_iScore = mArgs.score or self.m_iScore
    self:StatusChange(mKey)
end

function CMember:SetStatus(iStatus)
    self.m_iStatus = iStatus
end

function CMember:Status()
    return self.m_iStatus
end

function CMember:SetOrg(iorgid)
    self.m_iOrgId = iorgid
end

function CMember:PackInfo()
    return {
        pid = self.m_ID,
        status_info = self:GetSimpleStatus(),
    }
end

function CMember:PackAutoTeamInfo()
    local mArgs = {
        pid = self.m_ID,
        grade = self.m_iGrade,
        school = self.m_iSchool,
        icon = self.m_iIcon,
        name = self.m_sName,
        model_info = self.m_mModelInfo,
        team_allowed = self.m_iTeamAllowed or 1,
    }
    return mArgs
end

function CMember:GetHp()
    return self.m_iHp
end

function CMember:GetMp()
    return self.m_iMp
end

function CMember:GetMaxHp()
    return self.m_iMaxHp
end

function CMember:GetMaxMp()
    return self.m_iMaxMp
end

function CMember:GetName()
    return self.m_sName
end

function CMember:GetGrade()
    return self.m_iGrade
end

function CMember:GetIcon()
    return self.m_iIcon
end

function CMember:GetModelInfo()
    return self.m_mModelInfo
end

function CMember:GetSchool()
    return self.m_iSchool
end

function  CMember:GetOrgId()
    local oWorldMgr = global.oWorldMgr
    local oMem  = oWorldMgr:GetOnlinePlayerByPid(self:MemberID())
    if not oMem then
        return self.m_iOrgId
    end
    self.m_iOrgId = oMem:GetOrgID()
    return self.m_iOrgId
end

function CMember:GetScore()
    local oWorldMgr = global.oWorldMgr
    local oMem  = oWorldMgr:GetOnlinePlayerByPid(self:MemberID())
    if not oMem then
        return self.m_iScore
    end
    self.m_iScore = oMem:GetScore()
    return self.m_iScore
end

function CMember:SetShortLeaveButtonState(oPlayer,iValue)
    local oTeam = oPlayer:HasTeam()
    self.m_iShortLeaveButtonStatue = iValue
    if self.m_iShortLeaveButtonStatue == 1  and self.m_iLeaveButtonStatue == 1  and not oTeam:IsLeader(oPlayer:GetPid()) then
        local oTeamMgr = global.oTeamMgr
        local flag = oTeamMgr:GetCBFlag(gamedefines.TEAM_CB_FLAG.LEAVE,oPlayer:GetPid())
        oTeam:DelCB(gamedefines.TEAM_CB_TYPE.LEAVE_WAR,flag)
        self.m_iLeaveButtonStatue = 0
    end
    oPlayer:Send("GS2CButtonState",self:PackButton())
end

function CMember:SetBackButtonState(oPlayer,iValue)
    self.m_iBackTeamButtonStatue = iValue
    oPlayer:Send("GS2CButtonState",self:PackButton())
end

function CMember:SetLeaveButtonState(oPlayer,iValue)
    local oTeam = oPlayer:HasTeam()
    self.m_iLeaveButtonStatue = iValue
    if self.m_iShortLeaveButtonStatue == 1  and self.m_iLeaveButtonStatue == 1  and not oTeam:IsLeader(oPlayer:GetPid()) then
        local oTeamMgr = global.oTeamMgr
        local flag = oTeamMgr:GetCBFlag(gamedefines.TEAM_CB_FLAG.SHORTLEAVE,oPlayer:GetPid())
        oTeam:DelCB(gamedefines.TEAM_CB_TYPE.LEAVE_WAR,flag)
        self.m_iShortLeaveButtonStatue = 0
    end

    oPlayer:Send("GS2CButtonState",self:PackButton())
end

function CMember:SetLeaderButtonState(oPlayer,iValue)
    self.m_iSetLeaderButtonStatue = iValue
    oPlayer:Send("GS2CButtonState",self:PackButton())
end

function CMember:AddKick(oPlayer,iTarget)
    table.insert(self.m_lKickButtonStatue,iTarget)
    oPlayer:Send("GS2CButtonState",self:PackButton())
end

function CMember:RemoveKick(oPlayer,iTarget)
    extend.Array.remove(self.m_lKickButtonStatue,iTarget)
    oPlayer:Send("GS2CButtonState",self:PackButton())
end

function CMember:PackButton()
    local mNet = {}
    mNet.leave = self.m_iLeaveButtonStatue
    mNet.kick = self.m_lKickButtonStatue
    mNet.shortleave = self.m_iShortLeaveButtonStatue
    mNet.back = self.m_iBackTeamButtonStatue
    mNet.setleader = self.m_iSetLeaderButtonStatue
    return mNet
end

function CMember:ResetButton()
    self.m_lKickButtonStatue = {}
    self.m_iLeaveButtonStatue = 0
    self.m_iShortLeaveButtonStatue = 0
    self.m_iBackTeamButtonStatue = 0
    self.m_iSetLeaderButtonStatue = 0
end

function CMember:GetSimpleStatus(m)
    local mRet = {}
    if not m then
        m = StatusHelperFunc
    end
    for k, _ in pairs(m) do
        local f = assert(StatusHelperFunc[k], string.format("GetSimpleStatus fail f get %s", k))
        mRet[k] = f(self)
    end
    return net.Mask("base.MemStatusInfo", mRet)
end

function CMember:StatusChange(m)
    local mStatus = self:GetSimpleStatus(m)
    self:SendAll("GS2CRefreshMemberInfo", {
        pid = self.m_ID,
        status_info = mStatus,
    })
end

function CMember:SendAll(sMessage,mNet)
    local oWorldMgr = global.oWorldMgr
    local oPlayer = oWorldMgr:GetOnlinePlayerByPid(self.m_ID)
    local oTeam = oPlayer:HasTeam()
    if not oTeam then
        return
    end
    local mMem = oTeam:OnlineMember()
    for pid,_ in pairs(mMem) do
        local oPlayer = oWorldMgr:GetOnlinePlayerByPid(pid)
        if oPlayer then
            oPlayer:Send(sMessage,mNet)
        end
    end
end

function CMember:UpdateLeaderActiveStatus(iActive)
    local oWorldMgr = global.oWorldMgr
    local oPlayer = oWorldMgr:GetOnlinePlayerByPid(self:MemberID())
    if oPlayer then
        local mNet = {}
        mNet["active"] = iActive or 1
        oPlayer:Send("GS2CLeaderActiveStatus", mNet)
    end
end
