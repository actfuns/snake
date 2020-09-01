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
    self.m_iSaveLimit = 100
    self.m_lSortDesc = {true, true}
end

function CRank:GenRankUnit(mData)
    return db_key(mData.pid), {mData.point, mData.grade, mData.name, mData.school,mData.pid,mData.model}
end

function CRank:NewHour()
end

function CRank:NewDay()
end

function CRank:MergeFrom(mFromData)
    return true
end

function CRank:PushDataToRank(mData)
    self.m_mRankData = {}
    self.m_lSortList = {}
    for _, mSubData in ipairs(mData) do 
        super(CRank).PushDataToRank(self,mSubData)
    end
    self:DoStubShowData()
end

function CRank:PackTop3RankData(iPid)
    local mNet = {}
    mNet.idx = self.m_iRankIndex
    mNet.my_rank = self:GetMyRank(iPid)

    local lRoleInfo = {}
    for idx, sKey in ipairs(self.m_lSortList) do
        local mData = self.m_mRankData[sKey]
        local mRoleInfo = {}
        mRoleInfo.pid = mData[5]
        mRoleInfo.name = mData[3]
        mRoleInfo.school = mData[4]
        mRoleInfo.value = mData[1]
        mRoleInfo.model_info = table_copy(mData[6] or {})
        mRoleInfo.model_info.horse = nil
        table.insert(lRoleInfo, mRoleInfo)
    end

    if #lRoleInfo > 0 then
        mNet.role_info = lRoleInfo
    end
    return mNet
end

function CRank:GetMyRank(iPid)
    local sCurKey = db_key(iPid)
    local iRankIndex = self.m_mShowRank[sCurKey]
    if not  iRankIndex then
        return nil
    end
    local mMyData = self.m_mRankData[sCurKey]
    if not mMyData then
        return nil
    end
    
    local iRankValue = mMyData[1]
    local iCurRank = 0
    local iCurValue = 0
    for idx, sKey in ipairs(self.m_lSortList) do
        local mData = self.m_mRankData[sKey]
        if not mData then
            goto continue
        end
        if mData[1] ~= iCurValue then
            iCurRank = iCurRank +1
            iCurValue = mData[1]
        end
        if sKey == sCurKey then
            return iCurRank
        end
        ::continue::
    end
    return nil
end

function CRank:PackShowRankData(iPid, iPage)
    local mNet = {}
    mNet.idx = self.m_iRankIndex
    mNet.page = iPage
    mNet.first_stub = self.m_iFirstStub
    mNet.my_rank = self:GetMyRank(iPid)
    local mMyData = self.m_mRankData[db_key(iPid)]
    if  mMyData then
        mNet.my_rank_value =mMyData[1]
    end

    local mData = self:GetShowRankData(iPage)
    local lRank = {}
    for idx, lInfo in ipairs(mData) do
        local mUnit = {}
        mUnit.point = lInfo[1]
        mUnit.grade = lInfo[2]
        mUnit.name = lInfo[3]
        mUnit.school = lInfo[4]
        mUnit.pid = lInfo[5]
        mUnit.rank_shift = lInfo[7]
        table.insert(lRank, mUnit)
    end
    if #lRank then
        mNet.biwu_rank = lRank
    end
    return mNet
end
