--import module
local skynet = require "skynet"
local global = require "global"
local res = require "base.res"
local extend = require "base.extend"

local datactrl = import(lualib_path("public.datactrl"))
local orgdefines = import(service_path("org.orgdefines"))

function NewMemberMgr(...)
    return COrgMemberMgr:New(...)
end

COrgMemberMgr = {}
COrgMemberMgr.__index = COrgMemberMgr
inherit(COrgMemberMgr, datactrl.CDataCtrl)

function COrgMemberMgr:New(orgid)
    local o = super(COrgMemberMgr).New(self, {orgid = orgid})
    o:Init()
    return o
end

function COrgMemberMgr:Release()
    for id, oMember in pairs(self.m_mMember) do
        baseobj_safe_release(oMember)
    end
    for id, oXueTu in pairs(self.m_mXueTu) do
        baseobj_safe_release(oXueTu)
    end
    self.m_mMember = {}
    self.m_mXueTu = {}
    super(COrgMemberMgr).Release(self)
end

function COrgMemberMgr:GetOrg()
    local orgid = self:GetInfo("orgid")
    local oOrgMgr = global.oOrgMgr
    return oOrgMgr:GetNormalOrg(orgid)
end

function COrgMemberMgr:Init()
    self.m_mMember = {}
    self.m_mXueTu = {}
    self.m_mPostion = {}
    self:SetData("strongest", 0)        --客卿
    self:SetData("mostpoint", 0)        --执剑使
    self.m_lElite = {}                  --精英
    self.m_mHisOffer = {}                --历史帮贡
    self:SetData("apply_leader_pid", 0)              -- 自荐帮主
    self:SetData("apply_leader_time", 0)            -- 自荐时间
    -- self.m_IAgreePid = {}                                     -- 同意玩家列表pid
end

function COrgMemberMgr:Load(mData)
    if not mData then
        return
    end
    self:SetData("leader", mData.leader)
    self:SetData("strongest", mData.strongest)
    self:SetData("mostpoint", mData.mostpoint)
    self.m_lElite = mData.elite
    self:SetData("apply_leader_pid", mData.apply_leader_pid) 
    self:SetData("apply_leader_time", mData.apply_leader_time)
    -- self.m_IAgreePid =  mData.agreepid                       
    if mData.member then
        for id, data in pairs(mData.member) do
            id = tonumber(id)
            local oMember = NewMember()
            oMember:Load(data)
            self.m_mMember[id] = oMember
            self:_AddPosition(oMember:GetPid(), oMember:GetPosition())
        end
    end
    if mData.xuetu then
        for id, data in pairs(mData.xuetu) do
            id = tonumber(id)
            local oXueTu = NewXueTu()
            oXueTu:Load(data)
            self.m_mXueTu[id] = oXueTu
        end
    end
    if mData.offer then
        for id, iOffer in pairs(mData.offer) do
            id = tonumber(id)
            self.m_mHisOffer[id] = iOffer
        end
    end
end

function COrgMemberMgr:Save()
    local mData = {}
    mData.leader = self:GetData("leader")
    -- mData.position = self.m_mPostion
    mData.strongest = self:GetData("strongest")
    mData.mostpoint = self:GetData("mostpoint")
    mData.elite = self.m_lElite
    mData.apply_leader_pid = self:GetData("apply_leader_pid")
    mData.apply_leader_time = self:GetData("apply_leader_time")
    -- mData.agreepid = self.m_IAgreePid
    local mMember = {}
    for id, oMember in pairs(self.m_mMember) do
        id = db_key(id)
        local data = oMember:Save()
        mMember[id] = data
    end
    mData.member = mMember
    local mXueTu = {}
    for id, oXueTu in pairs(self.m_mXueTu) do
        id = db_key(id)
        local data = oXueTu:Save()
        mXueTu[id] = data
    end
    mData.xuetu = mXueTu
    local mOffer = {}
    for id, iOffer in pairs(self.m_mHisOffer) do
        id = db_key(id)
        mOffer[id] = iOffer
    end
    mData.offer = mOffer
    return mData
end

function COrgMemberMgr:UnDirty()
    super(COrgMemberMgr).UnDirty(self)
    for _, oMember in pairs(self.m_mMember) do
        if oMember:IsDirty() then
            oMember:UnDirty()
        end
    end
    for _, oXueTu in pairs(self.m_mXueTu) do
        if oXueTu:IsDirty() then
            oXueTu:UnDirty()
        end
    end
end

function COrgMemberMgr:IsDirty()
    local bDirty = super(COrgMemberMgr).IsDirty(self)
    if bDirty then
        return true
    end
    for _, oMember in pairs(self.m_mMember) do
        if oMember:IsDirty() then
            return true
        end
    end
    for _, oXueTu in pairs(self.m_mXueTu) do
        if oXueTu:IsDirty() then
            return true
        end
    end
    return false
end

function COrgMemberMgr:GetXueTu(pid)
    return self.m_mXueTu[pid]
end

function COrgMemberMgr:AddXueTu(oMemInfo)
    local pid = oMemInfo:GetData("pid")
    local name = oMemInfo:GetData("name")
    local grade = oMemInfo:GetData("grade")
    local school = oMemInfo:GetData("school")
    local offer = oMemInfo:GetData("offer")
    local logout_time = oMemInfo:GetData("logout_time")
    local iTouxian = oMemInfo:GetData("touxian")

    self:Dirty()
    local oXueTu = NewXueTu()
    oXueTu:Create(pid, name, grade, school, offer, logout_time, iTouxian)
    self.m_mXueTu[pid] = oXueTu
end

function COrgMemberMgr:RemoveXueTu(pid)
    self:Dirty()
    local oXueTu = self.m_mXueTu[pid]
    self.m_mXueTu[pid] = nil
    if oXueTu then
        baseobj_delay_release(oXueTu)
    end
end

function COrgMemberMgr:GetMemIdsBylPos(lPos)
    local lMemID = {}
    for _,iPos in ipairs(lPos) do
        lMemID = list_combine(lMemID, self:GetMemIdsByPosition(iPos))
    end
    return lMemID
end

function COrgMemberMgr:GetMemIdsByHonor(iHonor)
    if iHonor == orgdefines.ORG_HONOR.MOSTPOINT then
        return {self:GetMostPoint()}
    elseif iHonor == orgdefines.ORG_HONOR.STRONGEST then
        return {self:GetStrongest()}
    elseif iHonor == orgdefines.ORG_HONOR.ELITE then
        return table_key_list(self:GetElite())
    end
end

function COrgMemberMgr:GetMemIdsByPosition(iPos)
    return self.m_mPostion[iPos] or {}
end

function COrgMemberMgr:GetMemPosMap()
    return self.m_mPostion
end

function COrgMemberMgr:GetMember(pid)
    return self.m_mMember[pid]
end

function COrgMemberMgr:GetMemberMap()
    return self.m_mMember
end

function COrgMemberMgr:GetXueTuMap()
    return self.m_mXueTu
end

function COrgMemberMgr:GetXueTuSortMap()
    local lOtherUpvote = {}
    for k, oXueTu in pairs(self.m_mXueTu) do
        table.insert(lOtherUpvote, {k, oXueTu:GetJoinTime()})
    end
    table.sort(lOtherUpvote, function(v1, v2)
        if v1[2] > v2[2] then
            return true
        else
            return false
        end
    end)
    return lOtherUpvote
end

function COrgMemberMgr:AddMember(oMemInfo)
    local pid = oMemInfo:GetData("pid")
    local name = oMemInfo:GetData("name")
    local grade = oMemInfo:GetData("grade")
    local school = oMemInfo:GetData("school")
    local offer = oMemInfo:GetData("offer")
    local logout_time = oMemInfo:GetData("logout_time")
    local iTouxian = oMemInfo:GetData("touxian")

    self:Dirty()
    local oMember = NewMember()
    oMember:Create(pid, name, grade, school, offer, logout_time, iTouxian)
    self.m_mMember[pid] = oMember
end

function COrgMemberMgr:RemoveMember(pid)
    if self:IsLeader() then
        -- 处理禅让
        return
    end
    self:Dirty()
    self:RemovePostion(pid)
    if self:IsStrongest(pid) then
        self:SetStrongest(0)
    end
    if self:GetMostPoint(pid) then
        self:SetMostPoint(pid)
    end
    if self:IsElite(pid) then
        self:DelElite()
    end
    local oMember = self.m_mMember[pid]
    self.m_mMember[pid] = nil
    if oMember then
        baseobj_delay_release(oMember)
    end
end

function COrgMemberMgr:IsLeader(pid)
    return self:GetLeader() == pid
end

function COrgMemberMgr:GetLeader()
    return self:GetData("leader")
end

function COrgMemberMgr:SetLeader(pid)
    self:SetData("leader", pid)
    self:SetPosition(pid, orgdefines.ORG_POSITION.LEADER)
end

function COrgMemberMgr:GetApplyLeader()
    return self:GetData("apply_leader_pid")
end

function COrgMemberMgr:GetApplyLeaderName()
    local oMember = self:GetMember(self:GetApplyLeader())
    if oMember then
        return oMember:GetName()
    end
    return nil
end

function COrgMemberMgr:GetApplyLeaderSchool()
    local oMember = self:GetMember(self:GetApplyLeader())
    if oMember then
        return oMember:GetSchool()
    end
    return 0
end

function COrgMemberMgr:GetApplyLeftTime()
    if not self:GetData("apply_leader_time") then
        return 0
    end
    local res = require "base.res"
    local iTime = res["daobiao"]["org"]["others"][1]["self_apply_success_time"]
    return self:GetData("apply_leader_time") + iTime - get_time()
end

function COrgMemberMgr:ApplyLeader(pid)
    self:Dirty()
    self:SetData("apply_leader_pid", pid)
    self:SetData("apply_leader_time", get_time())
end

function COrgMemberMgr:RemoveApplyLeader()
    self:Dirty()
    self:SetData("apply_leader_pid", 0)
    self:SetData("apply_leader_time", 0)
    -- self.m_IAgreePid = {}
end

-- function COrgMemberMgr:AgreeApplyLeader(pid)
--     table.insert(self.m_IAgreePid, pid)
-- end

-- function COrgMemberMgr:HasAgreeLeader(pid)
--     if not self.m_IAgreePid[pid] then
--         return false
--     end
--     return true
-- end

function COrgMemberMgr:IsDeputy(pid)
    return self:GetPosition(pid) == orgdefines.ORG_POSITION.DEPUTY
end

function COrgMemberMgr:GetMemberCnt()
    return table_count(self.m_mMember)
end

function COrgMemberMgr:GetXueTuCnt()
    return table_count(self.m_mXueTu)
end

function COrgMemberMgr:GetOnlineMembers()
    local oWorldMgr = global.oWorldMgr
    local mOnlines = {}
    for pid,obj in pairs(self.m_mMember) do
        local oPlayer = oWorldMgr:GetOnlinePlayerByPid(pid)
        if oPlayer then
            mOnlines[pid] = oPlayer
        end
    end
    return mOnlines
end

function COrgMemberMgr:GetOnlineXuetu()
    local oWorldMgr = global.oWorldMgr
    local mOnlines = {}
    for pid,obj in pairs(self.m_mXueTu) do
        local oPlayer = oWorldMgr:GetOnlinePlayerByPid(pid)
        if oPlayer then
            mOnlines[pid] = oPlayer
        end
    end
    return mOnlines
end

function COrgMemberMgr:GetOnlinePlayers()
    local lPlayer = {}
    local oWorldMgr = global.oWorldMgr
    for iPid, _ in pairs(self.m_mMember) do
        local oPlayer = oWorldMgr:GetOnlinePlayerByPid(iPid)
        if oPlayer then
            table.insert(lPlayer, iPid)
        end
    end
    for iPid, _ in pairs(self.m_mXueTu) do
        local oPlayer = oWorldMgr:GetOnlinePlayerByPid(iPid)
        if oPlayer then
            table.insert(lPlayer, iPid)
        end
    end
    return lPlayer
end

function COrgMemberMgr:GetOnlineMemberCnt()
    local cnt = 0
    local oWorldMgr = global.oWorldMgr
    for pid,obj in pairs(self.m_mMember) do
        if oWorldMgr:IsOnline(pid) then
            cnt = cnt + 1
        end
    end
    return cnt
end

function COrgMemberMgr:GetOnlineXuetuCnt()
    local cnt = 0
    for pid,obj in pairs(self.m_mXueTu) do
        local oWorldMgr = global.oWorldMgr
        if oWorldMgr:IsOnline(pid) then
            cnt = cnt + 1
        end
    end
    return cnt
end

function COrgMemberMgr:GetPidOnPos(iPos)
    return self.m_mPostion[iPos] or {}
end

function COrgMemberMgr:GetPosition(pid)
    local oMember = self:GetMember(pid)
    if oMember then
        return oMember:GetPosition()
    end
    local oXueTu = self:GetXueTu(pid)
    if oXueTu then
        return oXueTu:GetPosition()
    end
end

function COrgMemberMgr:_AddPosition(pid, iPos)
    if not self.m_mPostion[iPos] then
        self.m_mPostion[iPos] = {}
    end
    table.insert(self.m_mPostion[iPos], pid)    
end

function COrgMemberMgr:_DelPosition(pid)
    if self.m_mPostion[iPos] then
        extend.Array.remove(self.m_mPostion[iPos], pid)
    end    
end

function COrgMemberMgr:SetPosition(pid, iPos)
    self:Dirty()
    self:_AddPosition(pid, iPos)
    local oMember = self:GetMember(pid)
    if oMember then
        oMember:SetPosition(iPos)
    end
end

function COrgMemberMgr:RemovePostion(pid)
    self:Dirty()
    local oMember = self:GetMember(pid)
    if oMember then
        local iPos = oMember:GetPosition()
        oMember:SetPosition(0)
        if self.m_mPostion[iPos] then
            extend.Array.remove(self.m_mPostion[iPos], pid)
        end
    end
end

function COrgMemberMgr:GetPositionCnt(iPos)
    local tPos = self.m_mPostion[iPos]
    if not tPos then
        return 0
    end
    return #tPos
end

function COrgMemberMgr:GetHisOfferMemList()
    local lOtherUpvote = {}
    for k, v in pairs(self.m_mHisOffer) do
        table.insert(lOtherUpvote, {k,v})
    end
    table.sort(lOtherUpvote, function(v1, v2)
        if v1[2] > v2[2] then
            return true
        else
            return false
        end
    end)
    return lOtherUpvote
end

function COrgMemberMgr:IsStrongest(pid)
    return self:GetStrongest() == pid
end

function COrgMemberMgr:SetStrongest(pid)
    self:SetData("strongest", pid)
end

function COrgMemberMgr:GetStrongest()
    self:GetData("strongest")
end

function COrgMemberMgr:IsMostPoint(pid)
    return self:GetMostPoint() == pid
end

function COrgMemberMgr:SetMostPoint(pid)
    self:SetData("mostpoint", pid)
end

function COrgMemberMgr:GetMostPoint()
    self:GetData("mostpoint")
end

function COrgMemberMgr:IsElite(pid)
    return table_in_list(self.m_lElite, pid)
end

function COrgMemberMgr:GetEliteCnt()
    return table_count(self.m_lElite)
end

function COrgMemberMgr:GetElite()
    return self.m_lElite
end

function COrgMemberMgr:SetElite(pid)
    if not pid then return end
    self:Dirty()
    table.insert(self.m_lElite, pid)
end

function COrgMemberMgr:DelElite(pid)
    self:Dirty()
    extend.Array.remove(self.m_lElite, pid)
end

function COrgMemberMgr:ClearElite()
    self.m_lElite = {}
end

function COrgMemberMgr:AddMemberHuoYue(pid, iHuoYue)
    local oMember = self:GetMember(pid)
    if not oMember then
        local oXueTu = self:GetXueTu(pid)
        if oXueTu then
            oXueTu:AddHuoYue(iHuoYue)
        end
    else
        oMember:AddHuoYue(iHuoYue)
    end
end

function COrgMemberMgr:GetDayTotHuoYue()
    local iTot = 0
    for k, oMember in pairs(self.m_mMember) do
        iTot = iTot + oMember:GetDayHuoYue()
    end
    for k, oXueTu in pairs(self.m_mXueTu) do
        iTot = iTot + oXueTu:GetDayHuoYue()
    end
    return iTot
end

function COrgMemberMgr:ClearDayHuoYue()
    for k, oMember in pairs(self.m_mMember) do
        oMember:ClearDayHuoYue()
    end
    for k, oXueTu in pairs(self.m_mXueTu) do
        oXueTu:ClearDayHuoYue()
    end
end

function COrgMemberMgr:ClearWeekHuoYue()
    for k, oMember in pairs(self.m_mMember) do
        oMember:ClearWeekHuoYue()
    end
    for k, oXueTu in pairs(self.m_mXueTu) do
        oXueTu:ClearWeekHuoYue()
    end
end

function COrgMemberMgr:GetDayHuoYue(pid)
    local oMember = self:GetMember(pid)
    if not oMember then
        local oMember = self:GetXueTu(pid)
    end
    if oMember then
        return oMember:GetDayHuoYue()
    end
    return 0
end

function COrgMemberMgr:GetWeekHuoYue(pid)
    local oMember = self:GetMember(pid)
    if not oMember then
        local oMember = self:GetXueTu(pid)
    end
    if oMember then
        return oMember:GetWeekHuoYue()
    end
    return 0
end

function COrgMemberMgr:AddHisOffer(pid, iOffer)
    assert(iOffer > 0, string.format("org addoffer err: %d %d", pid, iOffer))
    self:Dirty()
    local iOld = self.m_mHisOffer[pid]
    if iOld then
        self.m_mHisOffer[pid] = iOld + iOffer
    else
        self.m_mHisOffer[pid] = iOffer
    end
end

function COrgMemberMgr:GetHisOffer(pid)
    return self.m_mHisOffer[pid] or 0
end

function COrgMemberMgr:SyncMemberData(pid, mData)
    local oMember = self:GetMember(pid)
    if not oMember then
        oMember = self:GetXueTu(pid)
    end
    if oMember then
        oMember:SyncData(mData)
    end
end

function COrgMemberMgr:PackOrgMemList()
    local mNet = {}
    for iPid,oMen in pairs(self.m_mMember) do
        local m = oMen:PackOrgMemInfo()
        m.hisoffer = self:GetHisOffer(iPid)
        m.honor = self:GetOrgHonor(iPid)
        table.insert(mNet, m)
    end
    for iPid,oXueTu in pairs(self.m_mXueTu) do
        local m = oXueTu:PackOrgMemInfo()
        m.hisoffer = self:GetHisOffer(iPid)
        m.position = self:GetOrgPosition(iPid)
        table.insert(mNet, m)
    end
    return mNet
end

function COrgMemberMgr:PackOrgMemberMap()
    local mData = {}
    for iPid,oMen in pairs(self.m_mMember) do
        local m = oMen:PackOrgMemInfo()
        m.hisoffer = self:GetHisOffer(iPid)
        m.honor = self:GetOrgHonor(iPid)
        mData[iPid] = m
    end
    for iPid,oXueTu in pairs(self.m_mXueTu) do
        local m = oXueTu:PackOrgMemInfo()
        m.hisoffer = self:GetHisOffer(iPid)
        m.position = self:GetOrgPosition(iPid)
        mData[iPid] = m
    end
    return mData
end

function COrgMemberMgr:PackMemberInfo(iPid, bLogout)
    local oMem = self:GetMember(iPid)
    if not oMem then
        oMem = self:GetXueTu(iPid)
    end
    if not oMem then return end
    local mNet = oMem:PackOrgMemInfo()
    if bLogout then
        mNet.offline = oMem:GetData("logout_time")    
    end
    mNet.hisoffer = self:GetHisOffer(iPid)
    mNet.honor = self:GetOrgHonor(iPid)
    mNet.position = self:GetOrgPosition(iPid)
    return mNet
end

function COrgMemberMgr:GetOrgPosition(pid)
    local oMem = self:GetXueTu(pid)
    if oMem then
        return oMem:GetPosition()
    end
    oMem = self:GetMember(pid)    
    if oMem then
        return oMem:GetPosition()
    end
    return 0
end

function COrgMemberMgr:GetOrgHonor(pid)
    if self:IsMostPoint(pid) then
        return orgdefines.ORG_HONOR.MOSTPOINT
    end
    if self:IsStrongest(pid) then
        return orgdefines.ORG_HONOR.STRONGEST
    end
    if self:IsElite(pid) then
        return orgdefines.ORG_HONOR.ELITE
    end
    return 0
end

function COrgMemberMgr:PackSampleMemInfo(pid)
    local mNet = {}
    local  oMem = self:GetMember(pid)
    if not oMem then
        oMem = self:GetXueTu(pid)
    end
    mNet.hisoffer = self:GetHisOffer(pid) 
    mNet.position = self:GetOrgPosition(pid)
    mNet.honor = self:GetOrgHonor(pid)
    mNet.offer = oMem:GetOffer()
    mNet.huoyue = oMem:GetDayHuoYue()
    return mNet
end

function COrgMemberMgr:ChangeXueTu2Mem(iPid)
    local oXueTu = self:GetXueTu(iPid)
    if not oXueTu then
        return
    end
    self:Dirty()
    local oMember = NewMember()
    local mData = oXueTu:Save()
    oMember:Load(mData)
    self.m_mMember[oMember:GetPid()] = oMember
    self.m_mXueTu[oMember:GetPid()] = nil
    baseobj_delay_release(oXueTu)
end

function NewMember(...)
    return CMember:New(...)
end

CMember = {}
CMember.__index = CMember
inherit(CMember, datactrl.CDataCtrl)

function CMember:New()
    local o = super(CMember).New(self)
    return o
end

function CMember:Create(pid, name, grade, school, offer, logout_time, iTouxian)
    self:SetData("pid", pid)
    self:SetData("name", name)
    self:SetData("grade", grade)
    self:SetData("school", school)
    self:SetData("offer", offer)
    self:SetData("jointime", get_time())
    self:SetData("position", 0)
    self:SetData("huoyue", 0)
    self:SetData("weekhuoyue", 0)
    self:SetData("logout_time", logout_time)
    self:SetData("chat_ban_time", 0)
    self:SetData("touxian", iTouxian or 0)
end

function CMember:Load(mData)
    if not mData then
        return
    end
    self:SetData("pid", mData.pid)
    self:SetData("name", mData.name)
    self:SetData("grade", mData.grade)
    self:SetData("school", mData.school)
    self:SetData("offer", mData.offer)
    self:SetData("jointime", mData.jointime)
    self:SetData("position", mData.position)
    self:SetData("huoyue", mData.huoyue)
    self:SetData("weekhuoyue", mData.weekhuoyue)
    self:SetData("logout_time", mData.logout_time)
    self:SetData("chat_ban_time", mData.chat_ban_time or 0)
    self:SetData("touxian", mData.touxian or 0)
end

function CMember:Save()
    local mData = {}
    mData.pid = self:GetData("pid")
    mData.name = self:GetData("name")
    mData.grade = self:GetData("grade")
    mData.school = self:GetData("school")
    mData.offer = self:GetData("offer")
    mData.jointime = self:GetData("jointime")
    mData.position = self:GetData("position")
    mData.huoyue = self:GetData("huoyue")
    mData.weekhuoyue = self:GetData("weekhuoyue")
    mData.logout_time = self:GetData("logout_time")
    mData.chat_ban_time = self:GetData("chat_ban_time")
    mData.touxian = self:GetData("touxian")
    return mData
end

function CMember:GetPid()
    return self:GetData("pid")
end

function CMember:GetName()
    return self:GetData("name")
end

function CMember:GetGrade()
    return self:GetData("grade")
end

function CMember:GetSchool()
    return self:GetData("school")
end

function CMember:GetOffer()
    return self:GetData("offer", 0)
end

function CMember:GetJoinTime()
    return self:GetData("jointime")
end

function CMember:GetTouXian()
    return self:GetData("touxian")
end

function CMember:IsChatBan()
    local iBanTime = self:GetData("chat_ban_time", 0)
    if iBanTime <= 0 then return false end

    local iTime = res["daobiao"]["org"]["others"][1]["ban_time"]
    return iBanTime + iTime > get_time()
end

function CMember:SetChatBan(iTime)
    self:SetData("chat_ban_time", iTime or get_time())
end

function CMember:GetChatBanLeftTime()
    local iBanTime = self:GetData("chat_ban_time", 0)
    if iBanTime <= 0 then return 0 end

    local iTime = res["daobiao"]["org"]["others"][1]["ban_time"]
    return iBanTime + iTime - get_time()
end

function CMember:GetPosition()
    local position = self:GetData("position")
    if not position or position == 0 then
        return orgdefines.ORG_POSITION.MEMBER
    end
    return self:GetData("position")
end

function CMember:SetPosition(iPos)
    self:SetData("position", iPos)
end

function CMember:AddHuoYue(iHuoYue)
    self:SetData("huoyue", self:GetData("huoyue", 0) + iHuoYue)
    self:SetData("weekhuoyue", self:GetData("weekhuoyue", 0) + iHuoYue)
end

function CMember:GetDayHuoYue()
    return self:GetData("huoyue", 0)
end

function CMember:ClearDayHuoYue()
    self:SetData("huoyue", 0)
end

function CMember:GetWeekHuoYue()
    return self:GetData("weekhuoyue", 0)
end

function CMember:ClearWeekHuoYue()
    self:SetData("weekhuoyue", 0)
end

function CMember:SyncData(mData)
    for k,v in pairs(mData) do
        if self:GetData(k) then
            self:SetData(k, v)
        end
    end
end

function CMember:PackOrgMemInfo()
    local mNet = {}
    mNet.pid = self:GetPid()
    mNet.name = self:GetName()
    mNet.grade = self:GetGrade()
    mNet.school = self:GetSchool()
    mNet.position = self:GetPosition()
    mNet.weekhuoyue = self:GetWeekHuoYue()
    mNet.offline = self:GetOnlineTime()
    mNet.jointime = self:GetJoinTime()
    mNet.touxian = self:GetTouXian()
    return mNet
end

function CMember:GetOnlineTime()
    local oWorldMgr = global.oWorldMgr
    if oWorldMgr:IsOnline(self:GetPid()) then
        return 0
    end
    return self:GetData("logout_time")
end

function NewXueTu(...)
    return CXueTu:New(...)
end

CXueTu = {}
CXueTu.__index = CXueTu
inherit(CXueTu, CMember)

function CXueTu:GetPosition()
    return orgdefines.ORG_POSITION.XUETU
end
