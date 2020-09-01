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
    self.m_iShowLimit = 10
    self.m_iShowPage = 10
end

function CRank:GenRankUnit(mData)
    return db_key(mData.orgid), {mData.prestige , mData.orgid, mData.name, mData.orgname,mData.orglv}
end

function CRank:GetOrgInfo()
    return 2, 4, "orgid", "orgname", true
end

function CRank:NeedReplaceRankData(sKey, mNewData)
    return true
end

function CRank:NewHour(iDay,iHour)
    self:DoStubShowData()
end

function CRank:NewDay(iDay)
end

function CRank:MergeFrom(mFromData)
    return true
end

function CRank:PackShowRankData(iPid, iPage, mArgs)
    local mNet = {}
    mNet.idx = self.m_iRankIndex
    mNet.page = iPage
    mNet.first_stub = self.m_iFirstStub

    mArgs = mArgs or {}
    local iOrg = mArgs.orgid or 0
    mNet.my_rank = self.m_mShowRank[db_key(iOrg)]
    local mData = self:GetShowRankData(iPage)
    local lKaiFuOrgRank = {}
    for idx, lInfo in ipairs(mData) do
        local mUnit = {}
        mUnit.prestige = lInfo[1]
        mUnit.orgid = lInfo[2]
        mUnit.name = lInfo[3]
        mUnit.orgname = lInfo[4]
        mUnit.orglv = lInfo[5]
        mUnit.rank_shift = lInfo[6]
        table.insert(lKaiFuOrgRank, mUnit)
    end
    if #lKaiFuOrgRank>0 then
        mNet.kaifu_org_rank = lKaiFuOrgRank
    end
    return mNet
end

function CRank:PackRewardData()
    local mRewardOrg = {}
    for iPage=1,5 do
        local mData = self:GetShowRankData(iPage)
        for idx, lInfo in ipairs(mData) do
            table.insert(mRewardOrg,lInfo[2])
        end
    end
    return mRewardOrg
end