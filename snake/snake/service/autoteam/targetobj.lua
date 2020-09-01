local global = require "global"
local res = require "base.res"
local interactive = require "base.interactive"
local playersend = require "base.playersend"

local tableop = import(lualib_path("base.tableop"))
local memobj = import(service_path("memobj"))
local teamobj = import(service_path("teamobj"))

function NewTargetMgr(...)
    return CTargetMgr:New(...)
end

function NewTarget(...)
    return CTarget:New(...)
end


CTargetMgr = {}
CTargetMgr.__index = CTargetMgr
inherit(CTargetMgr,logic_base_cls())

function CTargetMgr:New()
    local o = super(CTargetMgr).New(self)
    o:Init()
    return o
end

function CTargetMgr:Init()
    self.m_mTargetList = {}
    local lTarget = res["daobiao"]["team"]["autoteam"]
    for iTarget, _ in pairs(lTarget) do
        self.m_mTargetList[iTarget] = NewTarget(iTarget)
    end
end

function CTargetMgr:GetTarget(iTarget)
    return self.m_mTargetList[iTarget]
end

function CTargetMgr:GetTargetMember(iTarget, pid)
    local oTarget = self:GetTarget(iTarget)
    if oTarget then
        return oTarget:GetMember(pid)
    end
end

function CTargetMgr:GetTargetTeam(iTarget, iTeam)
    local oTarget = self:GetTarget(iTarget)
    if oTarget then
        return oTarget:GetTeam(iTeam)
    end
end

function CTargetMgr:GetTargetTeamList(iTarget)
    local oTarget = self:GetTarget(iTarget)
    if oTarget then
        return oTarget:GetTeamList()
    end
end

function CTargetMgr:GetTargetMemList(iTarget)
    local oTarget  = self:GetTarget(iTarget)
    if oTarget then
        return oTarget:GetMemberList()
    end
end

function CTargetMgr:AddTargetMem(iTarget, pid, mArgs)
    local oTarget = self:GetTarget(iTarget)
    if oTarget then
        oTarget:AddMember(pid, mArgs)
    end
end

function CTargetMgr:AddTargetTeam(iTarget, iTeam, mArgs)
    local oTarget = self:GetTarget(iTarget)
    if oTarget then
        oTarget:AddTeam(iTeam, mArgs)
    end
end

function CTargetMgr:RemoveTargetMember(iTarget, pid)
    local oTarget = self:GetTarget(iTarget)
    if oTarget then
        oTarget:RemoveMember(pid)
    end
end

function CTargetMgr:RemoveTargetTeam(iTarget, iTeam)
    local oTarget = self:GetTarget(iTarget)
    if oTarget then
        oTarget:RemoveTeam(iTeam)
    end
end

function CTargetMgr:UpdateTargetTeamMem(iTarget, iTeam, pid, mArgs)
    local oTarget = self:GetTarget(iTarget)
    if oTarget then
        oTarget:UpdateTeamMember(iTeam, pid, mArgs)
    end
end

function CTargetMgr:MemLeaveTargetTeam(iTarget, iTeam, pid)
    local oTarget = self:GetTarget(iTarget)
    if oTarget then
        oTarget:MemberLeaveTeam(iTeam, pid)
    end
end

function CTargetMgr:DisconnectedTargetMem(iTarget, pid)
    local oTarget = self:GetTarget(iTarget)
    if oTarget then
        oTarget:RemoveMember(pid)
    end
end

function CTargetMgr:MemberEnterTargetTeam(iTarget, iTeam, pid, mArgs)
    local oTarget = self:GetTarget(iTarget)
    if oTarget then
        oTarget:MemberEnterTeam(iTeam, pid, mArgs)
    end
end

function CTargetMgr:AddMem2TeamBlackList(iTarget, iTeam, pid, iEndTimeStamp)
    local oTargetTeam = self:GetTargetTeam(iTarget, iTeam)
    if oTargetTeam then
        oTargetTeam:AddMem2BlackList(pid, iEndTimeStamp)
    end
end

function CTargetMgr:CountTargetAutoMatch(iTarget, iPid)
    local iMemCount  = 0
    local iTeamCount = 0
    if iTarget == 0 then
        for id, oTarget in pairs(self.m_mTargetList) do
            local lTargetTeam = oTarget:GetTeamList()
            local lTargetMem = oTarget:GetMemberList()
            iTeamCount = iTeamCount + tableop.table_count(lTargetTeam)
            iMemCount = iMemCount + tableop.table_count(lTargetMem)
        end
    else
        local oTarget = self:GetTarget(iTarget)
        if oTarget then
            local lTargetTeam = oTarget:GetTeamList()
            local lTargetMem = oTarget:GetMemberList()
            iTeamCount = iTeamCount + tableop.table_count(lTargetTeam)
            iMemCount = iMemCount + tableop.table_count(lTargetMem)
        end
    end
    local mNet = {}
    mNet["auto_target"] = iTarget
    mNet["member_count"] = iMemCount
    mNet["team_count"] = iTeamCount
    playersend.Send(iPid, "GS2CCountAutoMatch", mNet)
end

function CTargetMgr:AutoMatchSuccess(iTarget, iTeam, pid)
    interactive.Send(".world", "team", "AutoMatchSuccess", {targetid = iTarget, teamid =iTeam, pid = pid})
end

function CTargetMgr:TargetTeamTimeOut(iTarget, iTeam)
    interactive.Send(".world", "team", "TeamAutoMatchTimeOut", {targetid = iTarget, teamid = iTeam})
    self:RemoveTargetTeam(iTarget, iTeam)
end

function CTargetMgr:CheckTargetMemberNotify(iTarget, pid)
    local oTargetMem = self:GetTargetMember(iTarget, pid)
    if oTargetMem then
        local lTargetMem = self:GetTargetMemList(iTarget)
        local lTargetTeam = self:GetTargetTeamList(iTarget)
        local iTargetTeamCount = tableop.table_count(lTargetTeam)
        local iTargetMemCount = tableop.table_count(lTargetMem)
        if iTargetTeamCount < 1 and iTargetMemCount  >=5 then
            interactive.Send(".world", "team", "NotifyAutoMatchMember", {targetid = iTarget, pid = pid})
        end
    end
end

function CTargetMgr:CheckTargetTeamNotify(iTarget, iTeam)
    local oTargetTeam = self:GetTargetTeam(iTarget, iTeam)
    if oTargetTeam then
        local lTargetMem = self:GetTargetMemList(iTarget)
        local lTargetTeam = self:GetTargetTeamList(iTarget)
        local iTargetTeamCount = tableop.table_count(lTargetTeam)
        local iTargetMemCount = tableop.table_count(lTargetMem)
        if iTargetTeamCount >= 5 and iTargetMemCount < 1 then
            interactive.Send(".world", "team", "NotifyAutoMatchTeam", {targetid = iTarget, teamid = iTeam})
        end
    end
end

function CTargetMgr:TargetMemberTimeOut(iTarget, pid)
    local oTargetMem = self:GetTargetMember(iTarget, pid)
    if oTargetMem then
        interactive.Send(".world", "team", "MemAutoMatchTimeOut", {targetid = iTarget, pid = pid})
        self:RemoveTargetMember(iTarget, pid)
    end
end

CTarget = {}
CTarget.__index = CTarget
inherit(CTarget, logic_base_cls())

function CTarget:New(iTarget)
    local o = super(CTarget).New(self)
    o.m_ID = iTarget
    o.m_mTeamList = {}
    o.m_mMemList = {}
    o:Schedule()
    return o
end

function CTarget:Schedule()
    local f
    f = function()
        safe_call(self.CheckMatchWithoutLeader, self)
        self:DelTimeCb("CheckMatchWithoutLeader")
        self:AddTimeCb("CheckMatchWithoutLeader", math.random(2000, 4000), f)
    end
    f()
end

function CTarget:GetTargetID()
    return self.m_ID
end

function CTarget:GetTeam(iTeam)
    return self.m_mTeamList[iTeam]
end

function CTarget:GetMember(pid)
    return self.m_mMemList[pid]
end

function CTarget:GetTeamList()
    return self.m_mTeamList
end

function CTarget:GetMemberList()
    return self.m_mMemList
end

function CTarget:AddMember(pid, mArgs)
    local oMem = self.m_mMemList[pid]
    if oMem then
        return
    end
    oMem = memobj.NewMember(pid,mArgs)
    self.m_mMemList[oMem.m_ID] = oMem
    oMem:StartAutoMatch()
end

function CTarget:RemoveMember(iMemID)
    local oTargetMem = self:GetMember(iMemID)
    if oTargetMem then
        baseobj_delay_release(oTargetMem)
    end
    self.m_mMemList[iMemID] = nil
end

function CTarget:AddTeam(iTeam, mArgs)
    local oTeam = self.m_mTeamList[iTeam]
    if oTeam then
        return
    end
    oTeam = teamobj.NewTeam(iTeam, mArgs)
    oTeam:StartAutoMatch()
    self.m_mTeamList[oTeam.m_ID] = oTeam
end

function CTarget:RemoveTeam(iTeam)
    local oTargetTeam = self:GetTeam(iTeam)
    if oTargetTeam then
        baseobj_delay_release(oTargetTeam)
    end
    self.m_mTeamList[iTeam] = nil
end

function CTarget:UpdateTeamMember(iTeam, pid, mArgs)
    local oTeam = self:GetTeam(iTeam)
    if oTeam then
        local oMem = oTeam:GetMember(pid)
        if oMem then
            oMem:Update(mArgs)
        end
    end
end

function CTarget:MemberEnterTeam(iTeam, pid, mArgs)
    local oTeam = self:GetTeam(iTeam)
    if oTeam then
        oTeam:MemberEnter(pid, mArgs)
    end
end

function CTarget:MemberLeaveTeam(iTeam, pid)
    local oTeam = self:GetTeam(iTeam)
    if oTeam then
        oTeam:Leave(pid)
    end
end

function CTarget:CheckMatchWithoutLeader()
    local lTeam = self:GetTeamList()
    if lTeam and next(lTeam) then
        return
    end
    local lPid = {}
    for iPid, oMember in pairs(self.m_mMemList) do
        table.insert(lPid, iPid)
    end
    if #lPid < 3 then return end

    table.sort(lPid, function(iPid1, iPid2)
        local oMember1 = self:GetMember(iPid1)
        local oMember2 = self:GetMember(iPid2)
        if not oMember1 then return false end
        if not oMember2 then return true end

        if oMember1.m_iCreateTime == oMember2.m_iCreateTime then
            return iPid1 < iPid2
        end
        return oMember1.m_iCreateTime < oMember2.m_iCreateTime
    end)
    self:TeamupMemberWithoutLeader(lPid)
end

function CTarget:TeamupMemberWithoutLeader(lTarget)
    local lMember = {}
    for _, iPid in ipairs(lTarget) do
        local oMember = self:GetMember(iPid)
        if oMember then
            table.insert(lMember, iPid)
            if #lMember >= 5 then
                self:TeamupSuccessWithoutLeader(lMember)
                lMember = {}
            end
        end
    end
    if #lMember >= 3 then
        self:TeamupSuccessWithoutLeader(lMember)
    end
end

function CTarget:TeamupSuccessWithoutLeader(lMember)
    if not lMember or not next(lMember) then
        return
    end
    for i, iPid in ipairs(lMember) do
        self:RemoveMember(iPid)
    end
    local mArgs = {
        target = self.m_ID, 
        member = lMember,
    }
    interactive.Send(".world", "team", "TeamupSuccessWithoutLeader", mArgs)
end

