--import module
local global = require "global"
local skynet = require "skynet"
local interactive = require "base.interactive"

local rankbase = import(service_path("rankbase"))
local gamedefines = import(lualib_path("public.gamedefines"))


function NewRankObj(...)
    return CRank:New(...)
end

CRank = {}
CRank.__index = CRank
inherit(CRank, rankbase.CRankBase)

function CRank:Init(idx, sName)
    super(CRank).Init(self, idx, sName)
    self.m_lSortDesc = {true, true}
    self.m_iShowLimit = 5000
    self.m_iSaveLimit = 5100
end

function CRank:AfterLoad()
    -- self:UpdateJJCTop3()
end

function CRank:GetRankKey(mData)
    if mData.type == gamedefines.JJC_TARGET_TYPE.PLAYER then
        return "p"..db_key(mData.id)
    else
        return "r"..db_key(mData.id)
    end
end

function CRank:ResetRankData(mData)
    self:Dirty()
    self.m_mRankData = {}
    self.m_lSortList = {}
    for idx, data in ipairs(mData) do
        local sKey, mRankData = self:GenRankUnit(data, idx)
        self.m_mRankData[sKey] = mRankData
        table.insert(self.m_lSortList, sKey)
    end
    self:UpdateJJCTop3()
end

function CRank:PushDataToRank(mData)
    local sDefeatKey = self:GetRankKey(mData.defeat_data)
    if not self.m_mRankData[sDefeatKey] then
        return
    end
    local iDefeatIdx = self.m_mRankData[sDefeatKey][1]

    local iIdx
    local sKey, mUnit = self:GenRankUnit(mData, iDefeatIdx)
    if self.m_mRankData[sKey] then
        iIdx = self.m_mRankData[sKey][1]
        if iIdx <= iDefeatIdx then
            return iDefeatIdx, iIdx, false
        end
        self:Dirty()
        self.m_lSortList[iDefeatIdx], self.m_lSortList[iIdx] = sKey, sDefeatKey
        self.m_mRankData[sKey] = mUnit
        self.m_mRankData[sDefeatKey][1] = iIdx
    else
        self:Dirty()
        self.m_lSortList[iDefeatIdx] = sKey
        self.m_mRankData[sKey] = mUnit
        table.insert(self.m_lSortList, sDefeatKey)
        self.m_mRankData[sDefeatKey][1] = #self.m_lSortList
    end
    if iDefeatIdx <= 3 then
        self:UpdateJJCTop3()
    end
    return iDefeatIdx, iIdx, true
end

function CRank:GenRankUnit(mData, rank)
    return self:GetRankKey(mData), {rank, mData.id, mData.type, mData.school, mData.grade, mData.name}
end

function CRank:PackShowRankData(iPid, iPage)
    local mNet = {}
    mNet.idx = self.m_iRankIndex
    mNet.page = iPage
    mNet.first_stub = self.m_iFirstStub
    mNet.my_rank = self.m_mShowRank[db_key(iPid)]

    local mData = self:GetShowRankData(iPage)
    local lUpvoteRank = {}
    for idx, lInfo in ipairs(mData) do
        local mUnit = {}
        mUnit.id = lInfo[2]
        mUnit.type = lInfo[3]
        mUnit.school = lInfo[4]
        mUnit.grade = lInfo[5]
        mUnit.name = lInfo[6]
        mUnit.rank_shift = lInfo[7]
        table.insert(lUpvoteRank, mUnit)
    end
    if #lUpvoteRank then
        mNet.upvote_rank = lUpvoteRank
    end
    return mNet
end

function CRank:GetJJCRank(pid, iType)
    iType = iType or gamedefines.JJC_TARGET_TYPE.PLAYER
    local sKey = self:GetRankKey({
        type = iType,
        id = pid,
    })
    if not self.m_mRankData[sKey] then
        return
    end
    return self.m_mRankData[sKey][1]
end

function CRank:RequestJJCTarget(pid, targets)
    local lTargets = {}
    if targets and table_count(targets) > 0 then    
        for _, m in pairs(targets) do
            local sKey = self.m_lSortList[m.rank]
            local lInfo = self.m_mRankData[sKey]
            table.insert(lTargets, {rank=m.rank, type=lInfo[3], id=lInfo[2]})
        end
    else
        local lTargetRank = self:GetTargetRank(pid)
        for _, iRank in ipairs(lTargetRank) do
            local sKey = self.m_lSortList[iRank]
            local lInfo = self.m_mRankData[sKey]
            if lInfo[1] ~= iRank then
                lInfo[1] = iRank
            end

            table.insert(lTargets, {rank=iRank, type=lInfo[3], id=lInfo[2]})
        end
    end 
    return lTargets
end

function CRank:GetTargetRank(pid)
    local lTargetRank = {}
    local iMaxRank = math.min(#self.m_lSortList, 5000)
    local iRank = self:GetJJCRank(pid) or (iMaxRank + 1)

    local iTarRank = math.random(math.min(iMaxRank-300, iRank), iMaxRank)
    if iTarRank then
        table.insert(lTargetRank, iTarRank)
    end

    local iCnt = 3
    local iNoTargetCnt = 0
    local iTmpRank = iRank
    while iCnt > 0 do
        iCnt = iCnt - 1
        local iTarget = self:GetNextTargets(iTmpRank)
        if iTarget then
            iTmpRank = iTarget
        else
            iNoTargetCnt = iNoTargetCnt + 1
            iTarget = iRank + iNoTargetCnt
        end
        table.insert(lTargetRank, iTarget)
    end
    table.sort(lTargetRank)
    return lTargetRank
end

function CRank:GetNextTargets(iRank)
    local res = require "base.res"
    local mTargetRank = res["daobiao"]["jjc"]["target_rank"]
    for idx, data in ipairs(mTargetRank) do
        local iMin, iMax = table.unpack(data["rank"])
        if not iMax then
            iMax = iMin
        end
        local sRandomIdx = data["random_idx"]
        local iRandomIdx = formula_string(sRandomIdx, {})
        if iRank >= iMin and iRank <= iMax then
            if iRank - iRandomIdx >= iMin then
                return iRank - iRandomIdx
            else
                if idx > 1 then
                    local sRandomIdx = data["random_idx"]
                    local iRandomIdx = formula_string(sRandomIdx, {})
                    return iRank - iRandomIdx
                else
                    return nil
                end
            end
        end
    end
end

function CRank:RemoteGetTop3Profile()
end

function CRank:GetJJCTop3()
    local lTop3 = {}
    for i = 1, 3 do
        local sKey = self.m_lSortList[i]
        if not sKey then
            break
        end
        local lData = self.m_mRankData[sKey]
        table.insert(lTop3, {
            type = lData[3],
            id = lData[2],
        })
    end
    return lTop3
end

function CRank:UpdateJJCTop3()
    local lTop3 = self:GetJJCTop3()
    if next(lTop3) then
        interactive.Send(".world", "rank", "UpdateJJCTop3", {data=lTop3})
    end
end

function CRank:GetTargetByRank(iRank)
    local sKey = self.m_lSortList[iRank]
    if not sKey then return end
    local lData = self.m_mRankData[sKey]
    local mRet = {}
    mRet.id = lData[2]
    mRet.type = lData[3]
    return mRet
end

function CRank:MergeFrom(mFromData)
    -- 直接重新开始
    return true
end

function CRank:GetJJCRankList()
    local mPids = {}
    for idx, sKey in ipairs(self.m_lSortList) do
        local lData = self.m_mRankData[sKey]
        local iType = lData[3]
        local iPid = lData[2]
        local iGrade = lData[5]
        if iType == gamedefines.JJC_TARGET_TYPE.PLAYER then
            mPids[iPid] = {rank=idx, grade=iGrade}
        end
    end
    return mPids
end

function CRank:GetIndex()
    return 2, 6
end
