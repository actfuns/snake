local global = require "global"
local res = require "base.res"
local extend = require "base.extend"
local record = require "public.record"
local interactive = require "base.interactive"

function NewSingleWarMatch(...)
    local o = CSingleWarMatch:New(...)
    return o
end

CSingleWarMatch = {}
CSingleWarMatch.__index = CSingleWarMatch
inherit(CSingleWarMatch, logic_base_cls())

function CSingleWarMatch:New()
    local o = super(CSingleWarMatch).New(self)
    o.m_mGroup2MatchInfo = {}
    o.m_mGroup2Priority = {}
    return o
end

function CSingleWarMatch:UpdateMatchInfo(mMatch)
    local iGroup = mMatch.group
    if not iGroup then return end

    if not self.m_mGroup2MatchInfo[iGroup] then
        self.m_mGroup2MatchInfo[iGroup] = {}
    end

    local mGroup = self.m_mGroup2MatchInfo[iGroup]
    mGroup[mMatch.pid] = mMatch
end

function CSingleWarMatch:RemoveMatchInfo(mMatch)
    local iGroup = mMatch.group
    if not iGroup then return end

    if not self.m_mGroup2MatchInfo[iGroup] then
        return
    end

    local mGroup = self.m_mGroup2MatchInfo[iGroup]
    mGroup[mMatch.pid] = nil
end

function CSingleWarMatch:ClearMatchInfo()
    self:DelTimeCb("Match")
    self.m_mGroup2MatchInfo = {}
end

function CSingleWarMatch:GetMinMatchNum()
    return 10
end

function CSingleWarMatch:CheckGroupStart()
    local iLimit = self:GetMinMatchNum()
    local mGroup = {}
    for _, iGroup in ipairs({4, 3, 2, 1}) do
        local iTotal = 0
        for iPid, mInfo in pairs(self.m_mGroup2MatchInfo[iGroup] or {}) do
            iTotal = iTotal + 1
            if iTotal >= iLimit then
                mGroup[iGroup] = {true, iTotal}
                goto continue
            end
        end
        if mGroup[iGroup+1] and mGroup[iGroup+1][1] == false then
            if iTotal + mGroup[iGroup+1][2] >= iLimit then
                mGroup[iGroup] = {true, iTotal+mGroup[iGroup+1][2]}
            else
                mGroup[iGroup] = {false, iTotal}
                mGroup[iGroup+1][3] = "release"
            end
        else
            if iTotal >= iLimit then
                mGroup[iGroup] = {true, iTotal}
            else
                mGroup[iGroup] = {false, iTotal}
            end
        end
        ::continue::
    end
    return mGroup
end

function CSingleWarMatch:StartMatch()
    local bRet, lResult = safe_call(self.DoMatch, self)
    if lResult and next(lResult) then
        interactive.Send(".world", "huodong", "SingleWarMatchResult", {match_list=lResult})
    end

    self:DelTimeCb("Match")
    self:AddTimeCb("Match", 7*1000, function()
        self:StartMatch()
    end) 
end

function CSingleWarMatch:DoMatch()
    local lGroup = {4, 3, 2, 1}
    local lResult = {}
    local iLimit = self:GetMinMatchNum()
    for _, iGroup in ipairs(lGroup) do
        local mGroup = self.m_mGroup2MatchInfo[iGroup] or {}
        local mKeyInfo = {}
        local mPid2Key = {}
        local lPidList = table_key_list(self.m_mGroup2Priority[iGroup] or {})
        self.m_mGroup2Priority[iGroup] = {}
        for iPid, mUnit in pairs(mGroup) do
            local iGrade = mUnit.grade
            local iWin = mUnit.win
            local iKey = self:EncodeKey(iWin, iGrade)
            mKeyInfo[iKey] = mKeyInfo[iKey] or {}
            mKeyInfo[iKey][iPid] = 1
            mPid2Key[iPid] = iKey
            table.insert(lPidList, iPid)
        end
        for _, iPid in ipairs(lPidList) do
            local iMatch1
            local iKey = mPid2Key[iPid]
            local iMark = table_get_depth(mKeyInfo, {iKey, iPid})
            if iMark == 1 then
                iMatch1 = iPid
                local lKeyList = self:MatchKeyList(iKey)
                for _, iKeyY in ipairs(lKeyList) do
                    for iPid2, iMark in pairs(mKeyInfo[iKeyY] or {}) do
                        local mInfo = mGroup[iPid2]
                        if iMark ~= 1 then
                            goto continue
                        end
                        if iPid2 == iMatch1 then
                            goto continue
                        end
                        if mInfo.match_fight and mInfo.match_fight[iPid] then
                            goto continue
                        end
                        mKeyInfo[iKeyY][iPid2] = 2
                        mKeyInfo[iKey][iMatch1] = 2
                        table.insert(lResult, {iMatch1, iPid2, iGroup})
                        goto continueout
                        ::continue::
                    end
                end
                ::continueout::
            end
            if #lResult > 100 then
                break
            end
        end
        --剩余没匹配上的玩家
        if #lResult <= 100 then
            local lRet = {}
            for iKey, mPid in pairs(mKeyInfo) do
                for iPid, iMark in pairs(mPid) do
                    if iMark == 1 then
                        table.insert(lRet, iPid)
                    end
                end
            end
            if #lRet > 1 then
                for i = 1, #lRet, 2 do
                    local iPid1, iPid2 = lRet[i], lRet[i+1]
                    if iPid1 and iPid2 then
                        table.insert(lResult, {iPid1, iPid2, iGroup})
                    end
                end
            end
        end

        for _, mResult in ipairs(lResult) do
            local iMatch1, iMatch2, iGroup = table.unpack(mResult)
            mGroup[iMatch1] = nil
            mGroup[iMatch2] = nil
        end

        self.m_mGroup2MatchInfo[iGroup] = mGroup
        self.m_mGroup2Priority[iGroup] = table_copy(mGroup)
    end
    return lResult
end

function CSingleWarMatch:EncodeKey(iWin, iGrade)
    return iWin * 10000 + iGrade
end

function CSingleWarMatch:DecodeKey(iKey)
    return iKey//10000, iKey%10000
end

function CSingleWarMatch:MatchKeyList(iKey)
    local iWin, iGrade = self:DecodeKey(iKey)
    local lKeyList = {iKey}
    local mRecord = {}
    for _, mInfo in ipairs({{1, 3}, {2, 5}, {3, 7}}) do
        local iWinDelta, iGradeDelta = table.unpack(mInfo)
        for j = 0, iGradeDelta do
            for i = 0, iWinDelta do
                local iMatchWin = math.max(0, iWin-i)
                local iMatchGrade = math.max(0, iGrade-j)
                local iKeepKey = self:EncodeKey(iMatchWin, iMatchGrade)
                if not mRecord[iKeepKey] then
                    mRecord[iKeepKey] = 1
                    table.insert(lKeyList, iKeepKey)
                end
                local iMatchWin = math.max(0, iWin+i)
                local iMatchGrade = math.max(0, iGrade+j)
                local iKeepKey = self:EncodeKey(iMatchWin, iMatchGrade)
                if not mRecord[iKeepKey] then
                    mRecord[iKeepKey] = 1
                    table.insert(lKeyList, iKeepKey)
                end
            end
        end
    end
    return lKeyList
end

function CSingleWarMatch:GetGroupByGrade(iGrade)
    for idx, mGrade in ipairs(res["daobiao"]["huodong"]["singlewar"]["grade2scene"]) do
        if iGrade <= mGrade.max_grade then
            return idx
        end
    end
end
