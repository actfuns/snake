--import module
local global = require "global"
local skynet = require "skynet"
local res = require "base.res"
local interactive = require "base.interactive"
local record = require "public.record"
local extend = require "base.extend"
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
    self.m_iShowLimit = 20
end

function CRank:GenRankUnit(mSumData)
    local mData = mSumData.kaifu_summon
    return db_key(mData.pid), {mData.score, mData.typeid, mData.name, mData.ownername,mData.key,mData.pid,mData.basicinfo}
end

function CRank:NeedReplaceRankData(sKey, mNewData)
    return true
end

function CRank:NewHour(iDay,iHour)
    self:DoStubShowData()
    self:RemoteGetTop3Profile()
end

function CRank:MergeFrom(mFromData)
    return true
end

function CRank:GetCondition(iRank, mData)
    return {rank = iRank, pid = mData[6]}
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
        mUnit.pid = lInfo[6]
        mUnit.name = lInfo[3]
        mUnit.type = lInfo[2]
        mUnit.ownername = lInfo[4]
        mUnit.rank_shift = lInfo[8]
        table.insert(lRank, mUnit)
    end
    if #lRank>0 then
        mNet.kaifu_summon_rank = lRank
    end
    return mNet
end

function CRank:PackTop3RankData(iPid)
    local mNet = {}
    mNet.idx = self.m_iRankIndex
    mNet.my_rank = self.m_mShowRank[db_key(iPid)]

    local lSumInfo = {}
    local lPageData = self.m_mShowData[1] or {}
    local iSize = math.min(10, #lPageData)
    for i = 1 , iSize do 
        local mData = lPageData[i]
        local mSubInfo = {}
        mSubInfo.pid = mData[6]
        mSubInfo.type = mData[2]
        mSubInfo.name = mData[3]
        mSubInfo.score = mData[1]
        table.insert(lSumInfo,mSubInfo)
    end

    if #lSumInfo > 0 then
        mNet.summon_info = lSumInfo
    end
    return mNet
end

function CRank:RemoteGetTop3Profile()
end

function CRank:GetSumInfo(iRank)
    
    local iRet =  iRank % self.m_iShowPage
    if iRet == 0 then
        iRet = self.m_iShowPage
    end
    local iPage = iRank // self.m_iShowPage
    if iRank%self.m_iShowPage ~= 0  then
        iPage = iPage +1 
    end

    local lPage = self:GetShowRankData(iPage)
    if lPage[iRet] then
        local mNet = {}
        mNet.summondata = lPage[iRet][7]
        return mNet
    end
end

function CRank:GetIndex()
    return 6, 4
end

function CRank:OnUpdateName(iPid, sName)
    local iPidPos, iNamePos = self:GetIndex()

    for sKey, mData in pairs(self.m_mRankData) do
        if mData[iPidPos] == iPid then
            mData[iNamePos] = sName
        end
    end

    for iPage, mData in pairs(self.m_mShowData) do
        for idx, lInfo in ipairs(mData) do
            if lInfo[iPidPos] == iPid then
                lInfo[iNamePos] = sName
            end
        end
    end    
end

function CRank:PackRewardData()
    local mRewardPlayer = {}
    for iPage=1,5 do
        local mData = self:GetShowRankData(iPage)
        for idx, lInfo in ipairs(mData) do
            table.insert(mRewardPlayer,lInfo[6])
        end
    end
    return mRewardPlayer
end