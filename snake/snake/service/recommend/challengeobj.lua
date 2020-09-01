--import module

local global = require "global"
local interactive = require "base.interactive"
local res = require "base.res"
local extend = require "base.extend"
local record = require "public.record"

local datactrl = import(lualib_path("public.datactrl"))
local gamedefines = import(lualib_path("public.gamedefines"))
local gamedb = import(lualib_path("public.gamedb"))

function NewChallengeObj(...)
    local o = CChallengeObj:New(...)
    return o
end

CChallengeObj = {}
CChallengeObj.__index = CChallengeObj
CChallengeObj.DB_KEY = "chlgmatch"
inherit(CChallengeObj, datactrl.CDataCtrl)

function CChallengeObj:New()
    local o = super(CChallengeObj).New(self)
    o.m_mMatchData = {}     -- scorelv : {grade : {pid1, pid2}}
    o.m_mPlayerInfos = {}
    return o
end

function CChallengeObj:LoadDb()
    if is_ks_server() then return end
    
    local mInfo = {
        module = "globaldb",
        cmd = "LoadGlobal",
        cond = {name = self.DB_KEY},
    }
    gamedb.LoadDb("challenge", "common", "DbOperate", mInfo, function (mRecord, mData)
        if not self:IsLoaded() then
            self:Load(mData.data)
            self:OnLoaded()
        end
    end)
end

function CChallengeObj:SaveDb()
    if not self:IsLoaded() then return end
    if self:IsDirty() then
        local mInfo = {
            module = "globaldb",
            cmd = "SaveGlobal",
            cond = {name = self.DB_KEY},
            data = {data = self:Save()},
        }
        gamedb.SaveDb("challenge", "common", "DbOperate", mInfo)
        self:UnDirty()
    end
end

function CChallengeObj:ConfigSaveFunc()
    self:ApplySave(function ()
        local obj = global.oChallengeObj
        if obj then
            obj:_CheckSaveDb()
        else
            record.warning("challenge save err: no obj")
        end
    end)
end

function CChallengeObj:_CheckSaveDb()
    assert(not is_release(self), "challenge save fail: has release")
    assert(self:IsLoaded(), "challenge save fail: is loading")
    self:SaveDb()
end

function CChallengeObj:OnCloseGS()
    self:DoSave()
end

function CChallengeObj:Load(mData)
    mData = mData or {}
    if mData.player then
        self.m_mPlayerInfos = mData.player
    end
end

function CChallengeObj:Save()
    local mData = {}
    mData.player = self.m_mPlayerInfos
    return mData
end

function CChallengeObj:MergeFrom(mFromData)
    if mFromData and mFromData.player then
        table_combine(self.m_mPlayerInfos, mFromData.player)
        self:AfterLoad()
    end
    return true
end

function CChallengeObj:AfterLoad()
    self.m_mMatchData = {}
    for sPid, data in pairs(self.m_mPlayerInfos) do
        local pid = tonumber(sPid)
        local iGrade, iScore = table.unpack(data)
        local sScoreLv = tostring(self:GetScoreLevel(iScore))
        local sGrade = tostring(iGrade)
        if not self.m_mMatchData[sScoreLv] then
            self.m_mMatchData[sScoreLv] = {}
        end
        if not self.m_mMatchData[sScoreLv][sGrade] then
            self.m_mMatchData[sScoreLv][sGrade] = {}
        end
        table.insert(self.m_mMatchData[sScoreLv][sGrade], pid)
    end
end

function CChallengeObj:ValidAddChallengeMatch(iGrade, iScore)
    iGrade = math.min(#res["daobiao"]["promote"]["biaozhun"],iGrade)
    iGrade = math.max(iGrade,1)

    local iTmpScore = res["daobiao"]["promote"]["biaozhun"][iGrade]["score"]
    iTmpScore = math.max(1, iTmpScore - 1000)
    if iScore > iTmpScore then
        return true
    end
    return false
end

function CChallengeObj:GetScoreLevel(score)
    return math.floor(score / 500) + 1
end

function CChallengeObj:RemoveChallengeMatchInfo(pid)
    local sPid = tostring(pid)
    if self.m_mPlayerInfos[sPid] then
        self:Dirty()
        local iGrade, iScore = table.unpack(self.m_mPlayerInfos[sPid])
        local sGrade = tostring(iGrade)
        local iScoreLv = self:GetScoreLevel(iScore)
        local sScoreLv = tostring(iScoreLv)
        local lPids = self.m_mMatchData[sScoreLv][sGrade]
        extend.Array.remove(lPids, pid)
        if not next(lPids) then
            self.m_mMatchData[sScoreLv][sGrade] = nil
            if not next(self.m_mMatchData[sScoreLv]) then
                self.m_mMatchData[sScoreLv] = nil
            end
        end
        self.m_mPlayerInfos[sPid] = nil
    end
end

function CChallengeObj:AddChallengeMatchInfo(pid, iGrade, iScore)
    if not self:ValidAddChallengeMatch(iGrade, iScore) then
        self:RemoveChallengeMatchInfo(pid)
        return
    end
    local sGrade, sScore = tostring(iGrade), tostring(iScore)
    local sPid = tostring(pid)
    if self.m_mPlayerInfos[sPid] then
        local grade, score = table.unpack(self.m_mPlayerInfos[sPid])
        local sOldGrade, sOldScore = tostring(grade), tostring(score)
        if sOldGrade == sGrade and sOldScore == sScore then
            return
        end
        self:RemoveChallengeMatchInfo(pid)
    end
    self:Dirty()
    self.m_mPlayerInfos[sPid] = {iGrade, iScore}
    local iScoreLv = self:GetScoreLevel(iScore)
    local sScoreLv = tostring(iScoreLv)
    local mScoreLv = self.m_mMatchData[sScoreLv]
    if not mScoreLv then
        mScoreLv = {}
        self.m_mMatchData[sScoreLv] = mScoreLv
    end
    local lMatchPids = mScoreLv[sGrade]
    if not lMatchPids then
        lMatchPids = {}
        self.m_mMatchData[sScoreLv][sGrade] = lMatchPids
    end
    table.insert(lMatchPids, pid)
    if table_count(lMatchPids) > 50 then
        local iRmPid = table.remove(lMatchPids, 1)
        self.m_mPlayerInfos[tostring(iRmPid)] = nil
    end
end

function CChallengeObj:GetChallengeTarget(iGrade, iScore, mExclude, iGradeLimit)
    local mChallengeGroup = res["daobiao"]["jjc"]["challenge_group"]
    local mAllTarget = {}
    local iRobotID = 0
    
    for _, level in pairs(gamedefines.JJC_MATCH_GROUP) do
        local fMinRatio, fMaxRatio = table.unpack(mChallengeGroup[level]["power_ratio"])
        local fScoreMin, fScoreMax = iScore * fMinRatio, iScore * fMaxRatio
        local mTarget = {}

        -- 添加符合条件的目标玩家
        local iScoreLvMin = self:GetScoreLevel(fScoreMin)
        local iScoreLvMax = self:GetScoreLevel(fScoreMax)
        local iGradeMin = math.max(1, iGrade - 5)
        local iGradeMax = math.min(iGrade + 5, iGradeLimit)
        for iScoreLv = iScoreLvMin, iScoreLvMax do
            local sScoreLv = tostring(iScoreLv)
            local mMatchData = self.m_mMatchData[sScoreLv] or {}
            for sGrade, lPids in pairs(mMatchData) do
                local iMatchGrade = tonumber(sGrade)
                if iMatchGrade >= iGradeMin and iMatchGrade <= iGradeMax then
                    for _, pid in ipairs(lPids) do
                        if not mExclude[pid] then
                            local _, iMatchScore = table.unpack(self.m_mPlayerInfos[tostring(pid)])
                            mTarget = self:InsertChallengeTarget(mTarget, pid, gamedefines.JJC_TARGET_TYPE.PLAYER, iMatchScore, iMatchGrade)
                            if #mTarget >= 5 then goto matchdone end
                        end
                    end
                end
            end
        end
        ::matchdone::
        -- 添加机器人
        local iNeedCnt = 5 - table_count(mTarget)
        if iNeedCnt > 0 then
            for i=1, iNeedCnt do
                iRobotID = iRobotID + 1
                local iMatchScore = math.random(math.floor(fScoreMin), math.floor(fScoreMax))
                mTarget = self:InsertChallengeTarget(mTarget, iRobotID, gamedefines.JJC_TARGET_TYPE.ROBOT, iMatchScore, math.max(1, iGrade))
            end
        end
        mAllTarget[level] = mTarget
    end
    return mAllTarget
end

function CChallengeObj:InsertChallengeTarget(mTarget, iTarget, iType, iScore, iGrade)
    local idx = 1
    for j, data in ipairs(mTarget) do
        if data.score < iScore then
            idx = j + 1
        end
    end
    table.insert(mTarget, idx, {
        id = iTarget,
        type = iType,
        score = iScore,
        grade = iGrade,
    })
    return mTarget
end
