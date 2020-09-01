--import module
local global = require "global"
local skynet = require "skynet"
local interactive = require "base.interactive"
local res = require "base.res"
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
end

function CRank:GenRankUnit(mData)
    return db_key(mData.key), {mData.score, mData.typeid, mData.name, mData.ownername,mData.key,mData.pid,mData.basicinfo}
end

function CRank:NeedReplaceRankData(sKey, mNewData)
    return true
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

function CRank:PushDataToRank(mData)
    for _, mSubData in ipairs(mData) do 
        super(CRank).PushDataToRank(self,mSubData)
    end
end

function CRank:MergeFinish()
    self:DoStubShowData()
    self:RemoveTitle()
    self:RewardTitle()
end

function CRank:GetCondition(iRank, mData)
    return {rank = iRank, pid = mData[6]}
end

function CRank:GetMyRank(iPid)
    local sPattern = string.format("%s_",iPid)
    local iScore = 0
    local iMyRank = self.m_iSaveLimit +1
    for sKey , iRank in pairs(self.m_mShowRank) do
        if string.find(sKey,sPattern) and iRank<iMyRank then 
            iMyRank =  iRank
        end
    end
    if iMyRank ~= self.m_iSaveLimit +1 then
        return  iMyRank
    end 
end

function CRank:PackShowRankData(iPid, iPage)
    local mNet = {}
    mNet.idx = self.m_iRankIndex
    mNet.page = iPage
    mNet.first_stub = self.m_iFirstStub
    mNet.my_rank = self:GetMyRank(iPid)

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
    if #lRank then
        mNet.summon_score_rank = lRank
    end
    return mNet
end

function CRank:PackTop3RankData(iPid)
    local mNet = {}
    mNet.idx = self.m_iRankIndex
    mNet.my_rank = self:GetMyRank(iPid)

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

function CRank:RemoteDone(mKeepInfo)
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
        local pid = lPageData[i][6]
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
    local sKey = db_key(iPid)
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

