--import module
local skynet = require "skynet"
local global = require "global"
local extend = require "base.extend"

local datactrl = import(lualib_path("public.datactrl"))
local orgmeminfo = import(service_path("org.orgmeminfo"))
local orgdefines = import(service_path("org.orgdefines"))

function NewApplyMgr(...)
    return COrgApplyMgr:New(...)
end

COrgApplyMgr = {}
COrgApplyMgr.__index = COrgApplyMgr
inherit(COrgApplyMgr, datactrl.CDataCtrl)

function COrgApplyMgr:New(orgid)
    local o = super(COrgApplyMgr).New(self, {orgid = orgid})
    o:Init()
    return o
end

function COrgApplyMgr:Init()
    self.m_mApplyInfo = {}
    self.m_lSortApplyPid = {}
end

function COrgApplyMgr:Release()
    for _, oMem in pairs(self.m_mApplyInfo) do
        baseobj_safe_release(oMem)
    end
    self.m_mApplyInfo = {}
    super(COrgApplyMgr).Release(self)
end

function COrgApplyMgr:GetOrg()
    local orgid = self:GetInfo("orgid")
    local oOrgMgr = global.oOrgMgr
    return oOrgMgr:GetNormalOrg(orgid)
end

function COrgApplyMgr:Load(mData)
    mData = mData or {}
    if mData.apply then
        local mApplyInfo = {}
        for pid, data in pairs(mData.apply) do
            pid = tonumber(pid)
            local oMem = orgmeminfo.NewMemberInfo()
            oMem:Load(data)
            mApplyInfo[pid] = oMem
        end
        self.m_mApplyInfo = mApplyInfo
    end
end

function COrgApplyMgr:Save()
    local mData = {}
    local mApplyInfo = {}
    for pid, meminfo in pairs(self.m_mApplyInfo) do
        pid = db_key(pid)
        mApplyInfo[pid] = meminfo:Save()
    end
    mData.apply = mApplyInfo
    return mData
end

function COrgApplyMgr:AfterLoad()
    self:SortApply()

    for iPid, oMem in pairs(self.m_mApplyInfo) do
        global.oOrgMgr:AddPlayerApply(iPid, self:GetInfo("orgid"))
    end
end

function COrgApplyMgr:AddApply(oPlayer, iType)
    self:Dirty()
    local iPid = oPlayer:GetPid()
    local mArgs = {
        pid = iPid,
        name = oPlayer:GetName(),
        grade = oPlayer:GetGrade(),
        school = oPlayer:GetSchool(),
        offer = oPlayer:GetOffer(),
        apply_type = iType,
        touxian = oPlayer.m_oTouxianCtrl:GetTouxianID()
    }
    local oMember = orgmeminfo.NewMemberInfo()
    oMember:CreateNew(mArgs)
    -- oMember:Create(pid, name, grade, school, offer)
    if self:GetApplyCnt() >= orgdefines.APPLY_MAX_NUM then
        local iRmPid = self.m_lSortApplyPid[1]
        self:RemoveApply(iRmPid)
    end
    if self.m_mApplyInfo[iPid] then
        extend.Array.remove(self.m_lSortApplyPid, iPid)
    end

    self.m_mApplyInfo[iPid] = oMember
    table.insert(self.m_lSortApplyPid, iPid)
end

function COrgApplyMgr:RemoveApply(pid)
    self:Dirty()
    local oApply = self.m_mApplyInfo[pid]
    if oApply then
        baseobj_delay_release(oApply)
    end
    self.m_mApplyInfo[pid] = nil
    extend.Array.remove(self.m_lSortApplyPid, pid)
end

function COrgApplyMgr:GetApplyInfo(pid)
    return self.m_mApplyInfo[pid]
end

function COrgApplyMgr:GetApplyCnt()
    return table_count(self.m_mApplyInfo)
end

function COrgApplyMgr:GetApplyListInfo()
    return self.m_mApplyInfo
end

function COrgApplyMgr:PackApplyInfo()
    local mNet = {}
    if #self.m_lSortApplyPid <= 0 then return end

    for i = #self.m_lSortApplyPid, 1, -1 do
        local iPid = self.m_lSortApplyPid[i]
        local oMem = self.m_mApplyInfo[iPid]
        if oMem then
            table.insert(mNet, oMem:PackOrgApplyInfo())    
        end
    end
    return mNet
end

function COrgApplyMgr:SyncApplyData(iPid, mData)
    local oMem = self:GetApplyInfo(iPid)
    if oMem then
        oMem:SyncData(mData)
        self:Dirty()
    end
end

function COrgApplyMgr:SortApply()
    local lSortApply = {} 
    for iPid, oMem in pairs(self.m_mApplyInfo) do
        table.insert(lSortApply, {iPid, oMem:GetCreateTime()})
    end
    table.sort(lSortApply, function(v1, v2)
        if v1[2] == v2[2] then return false end

        return v1[2] < v2[2]
    end)
    self.m_lSortApplyPid = {}
    for _, m in pairs(lSortApply) do
        table.insert(self.m_lSortApplyPid, m[1])
    end
end

function COrgApplyMgr:CheckApplyExpire()
    local lPid = {}
    for _, iPid in pairs(self.m_lSortApplyPid) do
        local oMem = self:GetApplyInfo(iPid)
        if oMem and oMem:VaildApplyTime() then
            break
        end
        table.insert(lPid, iPid)
    end

    local oOrg = self:GetOrg()
    for _,iPid in pairs(lPid) do
        oOrg:RemoveApply(iPid)
    end
    return #lPid > 0
end

function COrgApplyMgr:ClearApplyInfo()
    local oOrg = self:GetOrg()
    local lPid = table_key_list(self.m_mApplyInfo)
    for _, iPid in pairs(lPid) do
        oOrg:RemoveApply(iPid)
    end
end

