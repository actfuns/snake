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
    self.m_lSortDesc = {false, true, true, true, false}
end

function CRank:GenRankUnit(mData)
    return db_key(mData.pid), {mData.usetime, mData.right, mData.firststage, mData.grade, mData.pid, mData.name}
end

function CRank:MergeFrom(mFromData)
    return true
end


function CRank:NewDay(iDay)
    if iDay == 7 then
        self:ClearRankData()
        self:RemoveTitle()
        self:RemoteGetTop3Profile()
    end
end

function CRank:PackShowRankData(iPid, iPage)
    local mNet = {}
    mNet.idx = self.m_iRankIndex
    mNet.page = iPage
    mNet.first_stub = self.m_iFirstStub
    mNet.my_rank = self.m_mShowRank[db_key(iPid)]
    local mMyData = self.m_mRankData[db_key(iPid)]
    if mMyData then
        mNet.my_rank_value = mMyData[1]
    end

    local mData = self:GetShowRankData(iPage)
    local lTimeRank = {}
    for idx ,lInfo in ipairs(mData) do
        local mUnit = {}
        mUnit.usetime = lInfo[1]
        mUnit.pid = lInfo[5]
        mUnit.name = lInfo[6]
        mUnit.rank_shift = lInfo[7]
        table.insert(lTimeRank, mUnit)
    end
    if #lTimeRank > 0 then
        mNet[self.m_sRankName] = lTimeRank
    end
    return mNet
end

function CRank:RewardTitle()
    local mLogData = {}
    local lPageData = self.m_mShowData[1] or {}
    local iSize = math.min(3, #lPageData)
    if iSize <= 0 then
        mLogData.rank = self.m_iRankIndex
        mLogData.sTitle = "无"
        record.log_db("rank", "reward_title", mLogData)
        return
    end

    local lRecordPlist = {}
    local lRewardTitle = {}
    for i = 1, iSize do
        local iTitle = self:GetRewardTitle(i)
        local pid = lPageData[i][5]
        if iTitle and pid then
            table.insert(lRewardTitle, {pid = pid, title = iTitle})
            table.insert(lRecordPlist, {pid = pid, title = iTitle})
        end
    end
    self:RecordTitlePlayer(lRecordPlist)
    mLogData.rank = self.m_iRankIndex
    mLogData.sTitle = extend.Table.serialize(lRewardTitle)
    record.log_db("rank", "reward_title", mLogData)
    interactive.Send(".world", "rank", "RankReward", lRewardTitle)
end

function CRank:GetCondition(iRank, mData)
    return {rank = iRank, pid = mData[5]}
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
    if iSize <= 0 then
        self:Dirty()
        self.m_mTop3Data = {}
    end

    local mKeepInfo = {}
    for i = 1, iSize do
        local mCondition = self:GetCondition(i, lPageData[i])
        if not mCondition then
            record.warning(string.format("RemoteGetTop3Profile error %s",self.m_sRankName))
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

function CRank:ClearRankData()
    self:Dirty()
    self.m_mRankData = {}
    self.m_lSortList = {}
    self.m_mShowData = {}
    self:DoStubShowData()
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

function CRank:PackImperialexamData()
    self:DoStubShowData()
    self:RemoteGetTop3Profile()
    self:RewardTitle()
    local mRankData = {}
    for iPage = 1, 5 do
        local mData = self:GetShowRankData(iPage)
        for idx, lInfo in ipairs(mData) do
            table.insert(mRankData, {pid = lInfo[5], name = lInfo[6]})
        end
    end
    return mRankData
end