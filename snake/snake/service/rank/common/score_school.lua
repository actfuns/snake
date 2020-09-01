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

function CRank:NewHour()
end

function CRank:NewDay()
    self:DoStubShowData()
    self:RemoteGetTop3Profile()
end

function CRank:PushDataToRank(mData)
    local iSchool = mData.school
    local oRank = self.m_mRankMgr[iSchool]
    if oRank then
        oRank:PushDataToRank(mData)
    else
        oRank = NewRankUnit(iSchool, "score_"..iSchool)
        self.m_mRankMgr[iSchool] = oRank
        oRank:PushDataToRank(mData)
    end
end

function CRank:Save()
    local mData = {rank_list = {}}
    for iSchool, oRankUnit in pairs(self.m_mRankMgr) do
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
    for iSchool, oRank in pairs(self.m_mRankMgr) do
        oRank:OnUpdateName(iPid, sName)
    end
end

function CRank:OnLogin(iPid)
    for iSchool, oRank in pairs(self.m_mRankMgr) do
        oRank:OnLogin(iPid)
    end
end

function CRank:OnLogout(iPid)
    for iSchool, oRank in pairs(self.m_mRankMgr) do
        oRank:OnLogout(iPid)
    end
end

function CRank:GetSortListBySchool(iSchool)
    local oRank = self.m_mRankMgr[iSchool]
    return oRank and oRank.m_lSortList or {}
end




function NewRankUnit(...)
    return CRankUnit:New(...)
end

CRankUnit = {}
CRankUnit.__index = CRankUnit
inherit(CRankUnit, rankbase.CRankBase)

function CRankUnit:Init(idx, sName)
    super(CRankUnit).Init(self, idx, sName)
    self.m_lSortDesc = {true, false, false}
    self.m_iShowLimit = 100
    self.m_iSaveLimit = 110
    self.m_iStubShow = -1
end

function CRankUnit:GenRankUnit(mData)
    return db_key(mData.pid), {mData.score, mData.grade, mData.pid, mData.name}
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
    local oRankObj = oRankMgr:GetRankObjByName("score_school")
    if oRankObj then
        oRankObj:Dirty()
    end
end

function CRank:GetIndex()
    return 3, 4
end
