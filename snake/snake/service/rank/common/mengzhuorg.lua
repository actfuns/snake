--import module
local global = require "global"
local skynet = require "skynet"
local playersend = require "base.playersend"
local extend = require "base.extend"
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
    self.m_iSaveLimit = 1100
    self.m_lSortDesc = {true, true, false, false}
end

function CRank:GenRankUnit(mData)
    return db_key(mData.orgid), {mData.point, mData.total, mData.time, mData.orgid, mData.orgname, mData.chairman}
end

function CRank:GetOrgInfo()
    return 4, 5, "orgid", "orgname", true
end

function CRank:NeedReplaceRankData(sKey, mNewData)
    return true
end

function CRank:PushDataToRank(mData)
    super(CRank).PushDataToRank(self, mData)

    if mData.point == 0 then
        local sKey, _ = self:GenRankUnit(mData)
        self.m_mRankData[sKey] = nil
        extend.Array.remove(self.m_lSortList, sKey)
    end
end

function CRank:PackShowRankData(iOrg, iPage)
    local mNet = {}
    local lNetRank, iCount = {}, 0
    for idx, sOrg in pairs(self.m_lSortList) do
        local mData = self.m_mRankData[sOrg]
        local mUnit = {}
        mUnit.point = mData[1]
        mUnit.total = mData[2]
        mUnit.org_id = mData[4]
        mUnit.org_name = mData[5]
        mUnit.chairman = mData[6]
        table.insert(lNetRank, mUnit)
        iCount = iCount + 1
        if iCount > self.m_iShowPage then
            break
        end
    end
    if #lNetRank > 0 then
        mNet.mengzhuorg = lNetRank
    end
    return mNet
end

function CRank:OnUpdateOrgName(iOrg, sName)
    local sKey = db_key(iOrg)
    if not self.m_mRankData[sKey] then return end
    self.m_mRankData[sKey][5] = sName
    self:Dirty()
end

function CRank:OnUpdateChairman(iOrg, sName)
    local sKey = db_key(iOrg)
    if not self.m_mRankData[sKey] then return end
    self.m_mRankData[sKey][6] = sName
    self:Dirty()
end

function CRank:GetRankByOrg(iOrg)
    local sOrg = db_key(iOrg)
    for idx, sKey in ipairs(self.m_lSortList) do
        if sKey == sOrg and idx <= 1000 then
            return idx
        end
    end
    return 0
end

function CRank:GS2CMengzhuOpenOrgRank(mData)
    local iOrg = mData.org_id
    local iPid = mData.pid
    local mPack = self:PackShowRankData(iOrg, 1)

    local mNet = {}
    mNet.boss_time = mData.mengzhu_cd
    mNet.plunder_time = mData.plunder_cd
    mNet.org_list = mPack.mengzhuorg
    mNet.my_rank = self:GetRankByOrg(iOrg)
    mNet.my_point = mData.point
    mNet.total = mData.total
    mNet.chairman = mData.chairman
   
    playersend.Send(iPid, "GS2CMengzhuOpenOrgRank", mNet)
end

function CRank:MergeFrom(mFromData)
    --玩法榜，不需要合并
    return true
end

