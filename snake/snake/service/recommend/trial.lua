local global = require "global"
local res = require "base.res"
local extend = require "base.extend"
local record = require "public.record"
local interactive = require "base.interactive"

local datactrl = import(lualib_path("public.datactrl"))
local gamedefines = import(lualib_path("public.gamedefines"))
local gamedb = import(lualib_path("public.gamedb"))


function NewTrialMatch(...)
    local o = CTrialMatch:New(...)
    return o
end

CTrialMatch = {}
CTrialMatch.__index = CTrialMatch
CTrialMatch.DB_KEY = "trialmatch"
inherit(CTrialMatch, datactrl.CDataCtrl)

function CTrialMatch:New()
    local o = super(CTrialMatch).New(self)
    o.m_mPlayerInfos = {}
    o.m_mGrade2Pid = {}
    o.m_mScore2Pid = {}
    return o
end

function CTrialMatch:LoadDb()
    if is_ks_server() then return end

    local mInfo = {
        module = "globaldb",
        cmd = "LoadGlobal",
        cond = {name = self.DB_KEY},
    }
    gamedb.LoadDb("trial", "common", "DbOperate", mInfo,
    function (mRecord, mData)
        if not self:IsLoaded() then
             self:Load(mData.data)
             self:OnLoaded()
        end
    end)
end

function CTrialMatch:SaveDb()
    if not self:IsLoaded() then return end
    if self:IsDirty() then
        local mInfo = {
            module = "globaldb",
            cmd = "SaveGlobal",
            cond = {name = self.DB_KEY},
            data = {data = self:Save()},
        }
        gamedb.SaveDb("trial", "common", "DbOperate", mInfo)
        self:UnDirty()
    end
end

function CTrialMatch:ConfigSaveFunc()
    self:ApplySave(function()
        local obj = global.oTrialMatchMgr
        if obj then
            obj:_CheckSaveDb()
        else
            record.warning(self.DB_KEY .. "save err: not obj")
        end
    end)
end

function CTrialMatch:_CheckSaveDb()
    assert(not is_release(self), "challenge save fail: has release")
    assert(self:IsLoaded(), "challenge save fail: is loading")
    self:SaveDb()
end

function CTrialMatch:OnCloseGS()
    self:DoSave()
end

function CTrialMatch:AfterLoad()
    for sPid, mInfo in pairs(self.m_mPlayerInfos) do
        self:UpdateIndex(sPid, mInfo)
    end
end

function CTrialMatch:Save()
    local mData = {}
    mData.player = self.m_mPlayerInfos
    return mData
end

function CTrialMatch:Load(m)
    if not m then return end
    self.m_mPlayerInfos = m.player or {}
end

function CTrialMatch:MergeFrom(mFromData)
    if not mFromData or not next(mFromData) then
        return false, "trial recommend not data"
    end
    for sPid, mInfo in pairs(mFromData.player or {}) do
        self:AddTrialMatchInfo(sPid, mInfo)
    end
    return true
end

function CTrialMatch:AddTrialMatchInfo(sPid, mInfo)
    local mOld = self.m_mPlayerInfos[sPid]
    if mOld then
        self:RemoveIndex(sPid, mOld)
    end
    self.m_mPlayerInfos[sPid] = mInfo
    self:Dirty()
    self:UpdateIndex(sPid, mInfo)
end

function CTrialMatch:UpdateIndex(sPid, mInfo)
    local iGrade = mInfo.grade
    local mGrade = self.m_mGrade2Pid[iGrade] or {}
    mGrade[sPid] = true
    self.m_mGrade2Pid[iGrade] = mGrade

    local iScore = mInfo.score
    local mScore = self.m_mScore2Pid[iScore] or {}
    mScore[sPid] = true
    self.m_mScore2Pid[iScore] = mScore
end

function CTrialMatch:RemoveIndex(sPid, mInfo)
    local iGrade = mInfo.grade
    if self.m_mGrade2Pid[iGrade] then
        self.m_mGrade2Pid[iGrade][sPid] = nil
    end
    local iScore = mInfo.score
    if self.m_mScore2Pid[iScore] then
        self.m_mScore2Pid[iScore][sPid] = nil
    end
end

function CTrialMatch:GetTrialMatchInfo(mInfo)
    local iSchool = mInfo.school
    local iScore = mInfo.score
    local iGrade = mInfo.grade
    local mExclude = mInfo.exclude or {}
    local mPidGrade = self:GetTrialMatchGradePids(iGrade, mExclude)
    if not next(mPidGrade) then
        record.info("trial cant't match pids grade:"..iGrade)
        return -1
    end

    local lResult = {}
    local lSortResult = {}
    local mPartition= self:PartiveByScore(mPidGrade, iScore)
    local mTrialRule = self:GetTrialMatchRule()
    local mExclude = {}
    for idx, mRule in pairs(mTrialRule) do
        local sPid = self:FilterTrialPlayerNew(mPartition, mRule, mInfo, mExclude)
        if sPid then
            -- table.insert(lResult, tonumber(sPid))
            mExclude[sPid] = true
            local mInfo = self.m_mPlayerInfos[sPid]
            local tmp = {
                sid = tonumber(sPid),
                score = mInfo.score
            }
            table.insert(lSortResult, tmp)
        end
    end
    table.sort(lSortResult, function (a, b)
        return a.score < b.score
    end)
    for _, mInfo in pairs(lSortResult) do
        table.insert(lResult, mInfo.sid)
    end
    return 0, lResult
end

function CTrialMatch:GetTrialMatchGradePids(iGrade, mFilter)
    local mConfig = self:GetTrialMatchConfig()
    local mMatchRule = self:GetTrialMatchRule()
    local iMinGrade = math.max(1, iGrade - mConfig.grade_range)
    local iMaxGrade = math.max(1, iGrade + mConfig.grade_range)
    local mPidTable, iCnt, iTotal = {}, 0, table_count(mMatchRule)

    while table_count(mPidTable) < iTotal and iCnt < 10 do
        for i = iMinGrade, iMaxGrade do
            local mInfo = self.m_mGrade2Pid[i] or {}
            local iCount = 0
            for sPid, _ in pairs(mInfo) do
                mPidTable[sPid] = true
                iCount = iCount + 1
                if iCount > 50 then
                    break
                end
            end
            --table_combine(mPidTable, mInfo)
        end
        for sPid, _ in pairs(mFilter) do
            mPidTable[sPid] = nil
        end
        iMinGrade = math.max(1, iMinGrade - mConfig.grade_float)
        iMaxGrade = math.max(1, iMaxGrade + mConfig.grade_float)
        iCnt = iCnt + 1
    end
   
    return mPidTable
end

function CTrialMatch:PartiveByScore(mPidGrade, iScore)
    local mPartition = {}
    for sPid, _ in pairs(mPidGrade) do
        local mInfo = self.m_mPlayerInfos[sPid]
        local iDiv = math.floor(mInfo.score / iScore * 10)
        local mResult = mPartition[iDiv] or {}
        mResult[sPid] = 1
        mPartition[iDiv] = mResult
    end
    return mPartition
end

function CTrialMatch:FilterTrialPlayer(mPartition, mRule, mInfo)
    local iKey = math.floor(mRule.min_ratio * 10)
    local iCnt, sPid = 0, nil
    local bIgnore = mInfo.school == gamedefines.PLAYER_SCHOOL.JINSHAN
    
    while not sPid and iCnt < 20 do
        local mTmp1 = mPartition[iKey-iCnt*1] or {}
        local mTmp2 = mPartition[iKey+iCnt*1] or {}
        local mResult, mIgnore = {}, {}
        for _, mTable in pairs({mTmp1, mTmp2}) do
            for sKey, iVal in pairs(mTable) do
                local mData = self.m_mPlayerInfos[sKey]
                if bIgnore and mData.school == gamedefines.PLAYER_SCHOOL.JINSHAN then
                    mIgnore[sKey] = iVal
                else
                    mResult[sKey] = iVal
                end
            end
        end
        if next(mResult) then
            sPid = table_choose_key(mResult)
        end
        if next(mIgnore) and not sPid then
            sPid = table_choose_key(mIgnore)
        end
        if sPid then
            mTmp1[sPid] = nil
            mTmp2[sPid] = nil
            break
        end
        iCnt = iCnt + 1
    end
    return sPid
end

function CTrialMatch:FilterTrialPlayerNew(mPartition, mRule, mInfo, mExclude)
    local iMin = math.floor(mRule.min_ratio * 10)
    local iMax = math.floor(mRule.max_ratio * 10)

    local iCnt, sPid = 0, nil
    local bIgnore = mInfo.school == gamedefines.PLAYER_SCHOOL.JINSHAN
    
    while not sPid and iCnt < 20 do
        local iTmpMin = iMin - iCnt * 1
        local iTmpMax = iMax + iCnt * 1
        local mResult, mIgnore = {}, {}
        for iDiv=iTmpMin,iTmpMax do
            local mTmp = mPartition[iDiv] or {}
            for sKey, iVal in pairs(mTmp) do
                if not mExclude[sKey] then
                    local mData = self.m_mPlayerInfos[sKey]
                    if bIgnore and mData.school == gamedefines.PLAYER_SCHOOL.JINSHAN then
                        mIgnore[sKey] = iVal
                    else
                        mResult[sKey] = iVal
                    end
                end
            end
        end

        if next(mResult) then
            sPid = table_choose_key(mResult)
        end
        if next(mIgnore) and not sPid then
            sPid = table_choose_key(mIgnore)
        end

        if sPid then
            break
        end
        iCnt = iCnt + 1
    end
    return sPid
end

function CTrialMatch:TableChoosePlayer(mPidTable, mInfo)
    local iSum, mFilter1, mFilter2 = 0, {}, {}
    local iSchool = gamedefines.PLAYER_SCHOOL.JINSHAN
    for sPid, iVal in pairs(mPidTable) do
        local mData = self.m_mPlayerInfos[sPid]
        if mInfo.school == iSchool and mData.school == iSchool then
            mFilter1[sPid] = iVal
        else
            mFilter2[sPid] = iVal
        end
    end
end

function CTrialMatch:GetTrialMatchRule()
    return res["daobiao"]["huodong"]["trial"]["match_rule"]
end

function CTrialMatch:GetTrialMatchConfig()
    return res["daobiao"]["huodong"]["trial"]["config"][1]
end
