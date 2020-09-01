--import module
local global = require "global"
local skynet = require "skynet"
local interactive = require "base.interactive"
local rankbase = import(service_path("rankbase"))


function NewRankObj(...)
    return CRank:New(...)
end

CRank = {}
CRank.__index = CRank
inherit(CRank, rankbase.CRankBase)

function CRank:Init(idx, sName)
    super(CRank).Init(self, idx, sName)
    self.m_iStubShow = -1
    self.m_mRankMgr = {}
end

function CRank:PushDataToRank(mData)
    local iGroup = mData.group
    local oRank = self.m_mRankMgr[iGroup]
    if oRank then
        oRank:PushDataToRank(mData)
    else
        oRank = NewRankUnit(iGroup, "singlewar_"..iGroup)
        self.m_mRankMgr[iGroup] = oRank
        oRank:PushDataToRank(mData)
    end
end

function CRank:Save()
    local mData = {rank_list = {}}
    for iGroup, oRankUnit in pairs(self.m_mRankMgr) do
        table.insert(mData.rank_list, oRankUnit:Save())
    end
    return mData
end

function CRank:Load(m)
    if not m then return end
    local lRankList = m.rank_list or {}
    for _, mRank in ipairs(lRankList) do
        local oRank = NewRankUnit(mRank.rank_idx, mRank.rank_name)
        self.m_mRankMgr[mRank.rank_idx] = oRank
        oRank:Load(mRank)
    end
end

function CRank:MergeFrom(mFromData)
    if not mFromData then
        return false ,string.format("rank %s no merge_from_data",self.m_sRankName)
    end
    self:Dirty()
    for _, mRank in ipairs(mFromData.rank_list or {}) do
        local idx = mRank.rank_idx
        if not self.m_mRankMgr[idx] then
            local oRank = NewRankUnit(idx, mRank.rank_name)
            self.m_mRankMgr[idx] = oRank
        end
        self.m_mRankMgr[idx]:MergeFrom(mRank)
    end
    return true
end

function CRank:OnUpdateName(iPid, sName)
    for iGroup, oRank in pairs(self.m_mRankMgr) do
        oRank:OnUpdateName(iPid, sName)
    end
end

function CRank:OnLogin(iPid)
    for iGroup, oRank in pairs(self.m_mRankMgr) do
        oRank:OnLogin(iPid)
    end
end

function CRank:OnLogout(iPid)
    for iGroup, oRank in pairs(self.m_mRankMgr) do
        oRank:OnLogout(iPid)
    end
end

function CRank:GetSortListByGroup(iGroup)
    local oRank = self.m_mRankMgr[iGroup]
    if oRank then
        return oRank.m_lSortList
    end
end

function CRank:GetRankByPid(iGroup, iPid)
    local oRank = self.m_mRankMgr[iGroup]
    local sPid = db_key(iPid)
    if oRank then
        for iIdx, sKey in ipairs(oRank.m_lSortList) do
            if sKey == sPid then
                return iIdx
            end
            if iIdx >= oRank.m_iShowLimit then
                break
            end
        end
    end
end


function NewRankUnit(...)
    return CRankUnit:New(...)
end

CRankUnit = {}
CRankUnit.__index = CRankUnit
inherit(CRankUnit, rankbase.CRankBase)

function CRankUnit:Init(idx, sName)
    super(CRankUnit).Init(self, idx, sName)
    self.m_lSortDesc = {true, false, false, false}
    self.m_iShowLimit = 30
    self.m_iSaveLimit = 50
    self.m_iStubShow = -1
end

function CRankUnit:GenRankUnit(mData)
    return db_key(mData.pid), {mData.point, mData.grade, mData.score, mData.pid, mData.name, mData.win_seri_max}
end

function CRankUnit:DoStubShowData()
end

function CRankUnit:NeedReplaceRankData(sKey, mNewData)
    return true
end

function CRankUnit:Save()
    local mData = super(CRankUnit).Save(self)
    mData.rank_idx = self.m_iRankIndex
    mData.rank_name = self.m_sRankName
    return mData
end

function CRankUnit:MergeFrom(mFromData)
    for sKey, mUnit in pairs(mFromData.rank_data or {}) do
        self:InsertToOrderRank(sKey, mUnit)
    end
end

function CRankUnit:Dirty()
    local oRankMgr = global.oRankMgr
    local oRankObj = oRankMgr:GetRankObjByName("singlewar")
    if oRankObj then
        oRankObj:Dirty()
    end
end

function CRankUnit:GetIndex()
    return 4, 5
end

function CRankUnit:PackRankData(iPid, iPage)
    local mNet = {}
    local lRank = {}
    local iMyRank
    for iIdx, sKey in ipairs(self.m_lSortList) do
        if iIdx >= self.m_iShowLimit then
            break
        end
        local mUnit = {}
        local mInfo = self.m_mRankData[sKey]
        local mUnit = {
            pid = mInfo[4],
            grade = mInfo[2],
            point = mInfo[1],
            score = mInfo[3],
            name = mInfo[5],
            win_seri_max = mInfo[6],
        }
        table.insert(lRank, mUnit)

        if not iMyRank and mInfo[4] == iPid then
            iMyRank = iIdx
        end
    end
    if #lRank > 0 then
        mNet.singlewar = lRank
    end
    return mNet
end
