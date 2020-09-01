local global = require "global"

function NewMember(...)
    return CMember:New(...)
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
    self.m_sName = mArgs.name
    self.m_iSchool = mArgs.school
    self.m_iGrade = mArgs.grade
    self.m_iTarget = mArgs.target
    self.m_iStartMatchTime = get_time()
    self.m_iTeamAllowed = mArgs.team_allowed or 1
    self.m_iCreateTime = get_time()
end

function CMember:GetGrade()
    return self.m_iGrade
end

function CMember:GetSchool()
    return self.m_iSchool
end

function CMember:GetName()
    return self.m_sName
end

function CMember:IsTeamAllowed()
    return self.m_iTeamAllowed == 1
end

function CMember:Update(mArgs)
    self.m_mModelInfo = mArgs.model_info or self.m_mModelInfo
    self.m_sName = mArgs.name or self.m_sName
    self.m_iSchool = mArgs.school or self.m_iSchool
    self.m_iGrade = mArgs.grade or self.m_iGrade
    self.m_iTeamAllowed = mArgs.team_allowed or self.m_iTeamAllowed
end

function CMember:StartAutoMatch()
    self:DelTimeCb("CheckNotify")
    local iTarget = self.m_iTarget
    local iMember = self.m_ID
    self:AddTimeCb("CheckNotify", 15*1000, function ()
        _CheckNotify(iTarget,iMember)
    end)
    self:DelTimeCb("MemberMatchTimeOut")
    local iDelay =  5 * 60
    self:AddTimeCb("MemberMatchTimeOut", iDelay * 1000,  function ()
        _AutoMatchTimeOut(iTarget,iMember)
    end)
end

function CMember:CheckNotify()
    local oTargetMgr = global.oTargetMgr
    oTargetMgr:CheckTargetMemberNotify(self.m_iTarget, self.m_ID)
end

function CMember:AutoMatchTimeOut()
    local oTargetMgr = global.oTargetMgr
    oTargetMgr:TargetMemberTimeOut(self.m_iTarget, self.m_ID)
end

function CMember:CancelAutoMatch()
    self:DelTimeCb("CheckNotify")
    self:DelTimeCb("MemberMatchTimeOut")
end

function CMember:GetStartTime()
    return self.m_iStartMatchTime
end

function _CheckNotify(iTarget,iMember)
    local oMember = global.oTargetMgr:GetTargetMember(iTarget,iMember)
    if not oMember then return end
    oMember:CheckNotify()
end

function _AutoMatchTimeOut(iTarget,iMember)
    local oMember = global.oTargetMgr:GetTargetMember(iTarget,iMember)
    if not oMember then return end
    oMember:AutoMatchTimeOut()
end
