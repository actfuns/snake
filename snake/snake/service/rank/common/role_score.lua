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
    self.m_lSortDesc = {true, false}
end

function CRank:NewHour(iDay,iHour)
    if iHour == 0 then
        return 
    end
    if not self:ValidRefresh(iDay,iHour) then
        return
    end
    self:DoStubShowData()
    self:RemoteGetTop3Profile()
end

function CRank:NewDay()
    self:DoStubShowData()
    self:RemoteGetTop3Profile()
end

function CRank:MergeFrom(mFromData)
    if not mFromData then
        return false ,string.format("rank %s no merge_from_data",self.m_sRankName)
    end
    self:Dirty()
    for sKey,mUnit in pairs(mFromData.rank_data) do
        self:InsertToOrderRank(sKey,mUnit)
    end
    return true
end

function CRank:MergeFinish()
    self:DoStubShowData()
    self:RemoteGetTop3Profile()
end

function CRank:GenRankUnit(mData)
    return db_key(mData.pid), {mData.score, mData.pid, mData.name, mData.school,mData.touxian}
end

function CRank:NeedReplaceRankData(sKey, mNewData)
    return true
end

function CRank:GetCondition(iRank, mData)
    return {rank = iRank, pid = mData[2]}
end

function CRank:PackShowRankData(iPid, iPage)
    local mNet = {}
    mNet.idx = self.m_iRankIndex
    mNet.page = iPage
    mNet.first_stub = self.m_iFirstStub
    mNet.my_rank = self.m_mShowRank[db_key(iPid)]

    local mData = self:GetShowRankData(iPage)
    local lRank = {}
    for idx, lInfo in ipairs(mData) do
        local mUnit = {}
        mUnit.score = lInfo[1]
        mUnit.pid = lInfo[2]
        mUnit.name = lInfo[3]
        mUnit.school = lInfo[4]
        mUnit.touxian = lInfo[5]
        mUnit.rank_shift = lInfo[6]
        table.insert(lRank, mUnit)
    end
    if #lRank then
        mNet.role_score_rank = lRank
    end
    return mNet
end

function CRank:PackTop3RankData(iPid)
    local mNet = {}
    mNet.idx = self.m_iRankIndex
    mNet.my_rank = self.m_mShowRank[db_key(iPid)]

    local lRoleInfo = {}
    for iRank, mInfo in pairs(self.m_mTop3Data) do
        local mRoleInfo = {}
        mRoleInfo.pid = mInfo.pid
        mRoleInfo.name = mInfo.name
        mRoleInfo.upvote = mInfo.upvote
        mRoleInfo.school = mInfo.school
        mRoleInfo.value = mInfo.value
        mRoleInfo.model_info = mInfo.model
        if mRoleInfo.model_info and mRoleInfo.model_info.horse then
            mRoleInfo.model_info.horse = nil
        end
        table.insert(lRoleInfo, mRoleInfo)
    end

    if #lRoleInfo > 0 then
        mNet.role_info = lRoleInfo
    end
    return mNet
end

function CRank:RemoteGetTop3Profile()
    local lPageData = self.m_mShowData[1] or {}
    local iSize = math.min(10, #lPageData)
    if iSize <= 0 then return end
   
    local mKeepInfo = {} 
    for i = 1, iSize do
        local mCondition = self:GetCondition(i, lPageData[i])
        if not mCondition then
            record.warning(string.format("RemoteGetTop3Profile error %s ",self.m_sRankName))
            return 
        end
        interactive.Request(".world", "rank", "GetProfile", mCondition,
        function(mRecord, mData)
            mKeepInfo[mData.rank] = mData
            if table_count(mKeepInfo) >= iSize then
                self:RemoteDone(mKeepInfo)
            end
        end)
    end
end

function CRank:GetIndex()
    return 2, 3
end
