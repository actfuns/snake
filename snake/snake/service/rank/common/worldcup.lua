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
    self.m_lSortDesc = {true, true}
end

function CRank:NewHour(iDay,iHour)
end

function CRank:GenRankUnit(mData)
    return db_key(mData.pid), { 
        mData.suc_count, 
        mData.suc_rate, 
        mData.last_time, 
        mData.pid, 
        mData.name, 
        mData.school,
    }
end

function CRank:NeedReplaceRankData(sKey, mNewData)
    return true
end

function CRank:MergeFrom(mFromData)
    if not mFromData then
        return false ,string.format("rank %s no merge_from_data",self.m_sRankName)
    end
    self:Dirty()
    for sKey,mUnit in pairs(mFromData.rank_data) do
        self:InsertToOrderRank(sKey,mUnit)
    end
    self:MergeTitleRecord(mFromData)
    return true
end

function CRank:MergeFinish()
    self:DoStubShowData()
    self:RemoteGetTop3Profile()
    self:RemoveTitle()
    self:RewardTitle()
end

function CRank:GetCondition(iRank, mData)
    return {rank = iRank, pid = mData[4]}
end

function CRank:GetIndex()
    return 4, 5
end

function CRank:PackShowRankData(iPid, iPage, mArgs)
    local mNet = {}
    mNet.idx = self.m_iRankIndex
    mNet.page = iPage
    mNet.first_stub = self.m_iFirstStub
    mNet.my_rank = self.m_mShowRank[db_key(iPid)]

    local mData = self:GetShowRankData(iPage)
    local lRank = {}

    for idx, lInfo in ipairs(mData) do
        local mUnit = {}
        mUnit.suc_count = lInfo[1]
        mUnit.suc_rate = lInfo[2]
        mUnit.pid = lInfo[4]
        mUnit.school = lInfo[6]
        mUnit.name = lInfo[5]
        mUnit.rank_shift = lInfo[7]
        table.insert(lRank, mUnit)
    end
    if #lRank > 0 then
        mNet.worldcup_rank = lRank
    end
    return mNet
end

function CRank:PackRewardData()
    local mRewardPlayer = {}
    local mData = self:GetShowRankData(1)
    for idx, lInfo in ipairs(mData) do
        table.insert(mRewardPlayer,lInfo[4])
    end
    return mRewardPlayer
end

function CRank:GetRewardTitle(iRank)
    local mRes = res["daobiao"]["rankreward"][self.m_iRankIndex]
    if not mRes then
        return 
    end
    if not mRes["title_list"][iRank] then
        return 
    end
    return mRes["title_list"][iRank] 
end

function CRank:RewardTitle()
    local mLogData={}
    local lPageData = self.m_mShowData[1] or {}
    local iSize = math.min(3, #lPageData)
    if iSize <= 0 then 
        mLogData.rank = self.m_iRankIndex
        mLogData.sTitle = "无"
        record.log_db("rank", "reward_title",mLogData)
        return 
    end

    local lRecordPlist = {}
    local lRewardTitle = {}
    for i = 1, iSize do
        local iTitle = self:GetRewardTitle(i)
        local pid = lPageData[i][4]
        if iTitle and pid then
            table.insert(lRewardTitle,{pid = pid,title = iTitle})
            table.insert(lRecordPlist,{pid = pid,title = iTitle})
        end
    end
    self:RecordTitlePlayer(lRecordPlist)
    mLogData.rank = self.m_iRankIndex
    mLogData.sTitle = extend.Table.serialize(lRewardTitle)
    record.log_db("rank", "reward_title",mLogData)
    interactive.Send(".world", "rank", "RankReward", lRewardTitle)
end