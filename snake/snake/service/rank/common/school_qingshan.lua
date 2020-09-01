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
    self.m_lSortDesc = {true, false, false}
    self.m_iShowLimit = 100
    self.m_iSaveLimit = 110
    self.m_iStubShow = -1
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
    self:RemoveTitle()
    self:RewardTitle()
end

function CRank:GenRankUnit(mData)
    return db_key(mData.pid), {mData.score, mData.time, mData.pid, mData.name, mData.orgname}
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
    return {rank = iRank, pid = mData[3]}
end

function CRank:GetIndex()
    return 3, 4
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
        local pid = lPageData[i][3]
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
        mUnit.score = lInfo[1]
        mUnit.pid = lInfo[3]
        mUnit.name = lInfo[4]
        mUnit.orgname = lInfo[5]
        mUnit.rank_shift = lInfo[6]
        table.insert(lRank, mUnit)
    end
    if #lRank then
        mNet.score_school_rank = lRank
    end
    return mNet
end

function CRank:PackTop3RankData(iPid, mArgs)
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
