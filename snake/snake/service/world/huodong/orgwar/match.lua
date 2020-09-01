local global = require "global"
local res = require "base.res"


function NewMatch(...)
    return CMatch:New(...)
end

CMatch = {}
CMatch.__index = CMatch
inherit(CMatch, logic_base_cls())

function CMatch:New(...)
    local o = super(CMatch).New(self, ...)
    return o
end

function CMatch:GenSignInList()
    local mOrgList = global.oOrgMgr:GetNormalOrgs()
    local lOrgList = {}
    for iOrg, oOrg in pairs(mOrgList or {}) do
        if self:CheckOrgSignIn(oOrg) == 1 then
            table.insert(lOrgList, iOrg)
        end
    end
    return lOrgList
end

function CMatch:CheckOrgSignIn(oOrg)
    local mConfig = self:GetSignInConfig()
    if oOrg:GetBoom() < mConfig.boom then
        return 0
    end
    if oOrg:GetLevel() < mConfig.org_lv then
        return 0
    end
    return 1
end

function CMatch:GenMatchListWeek_2(lOrgIdList)
    local lSortList = self:GenSortList(lOrgIdList)
    local mMatchForward, mMatchReverse, lRetList = self:DoMatch(lSortList)
    local mResult = {
        match_forward = mMatchForward,
        match_reverse = mMatchReverse,
        match_ret = lRetList,
    }
    return mResult
end

function CMatch:GenMatchListWeek_4(lWinList, lLoseList, lAppendWin)
    local lWinSortList = self:GenSortList(lWinList)
    if lAppendWin then list_combine(lWinSortList, lAppendWin) end
    local mWinMatchForward, mWinMatchReverse, lWinRetList = self:DoMatch(lWinSortList)

    local lLoseSortList = self:GenSortList(lLoseList)
    list_combine(lWinRetList, lLoseSortList)
    local mLoseMatchForward, mLoseMatchReverse, lLoseRetList = self:DoMatch(lWinRetList)

--    local mResult = {
--        win_match_forward = mWinMatchForward,
--        win_match_reverse = mWinMatchReverse,
--        lose_match_forward = mLoseMatchForward,
--        lose_match_reverse = mLoseMatchReverse,
--        match_ret = lLoseRetList,
--    }
    local mMatchForward, mMatchReverse = {}, {}
    for _, mOrgList in ipairs({mWinMatchForward, mLoseMatchForward}) do
        for iOrg1, iOrg2 in pairs(mOrgList) do
            mMatchForward[iOrg1] = iOrg2
            mMatchReverse[iOrg2] = iOrg1
        end
    end

    local mResult = {
        match_forward = mMatchForward,
        match_reverse = mMatchReverse,
        match_ret = lLoseRetList,
    }
    return mResult
end

function CMatch:GenSortList(lOrgIdList)
    local lSortList = {}
    local mOrgList = {}
    for _, iOrg in ipairs(lOrgIdList) do
        local oOrg = global.oOrgMgr:GetNormalOrg(iOrg)
        if not oOrg then goto continue end
        table.insert(lSortList, iOrg)
        mOrgList[iOrg] = {oOrg.m_oBaseMgr:GetWeekHuoYue(), oOrg:ShowID()}
        ::continue::
    end

    table.sort(lSortList, function(x,y)
        if mOrgList[x][1] == mOrgList[y][1] then
            return mOrgList[x][2] > mOrgList[y][2]
        end
        return mOrgList[x][1] > mOrgList[y][1]
    end)
    return lSortList
end

function CMatch:DoMatch(lOrgList)
    local mMatchForward = {}
    local mMatchReverse = {}
    local lRetOrg = {}
    local iLen = #lOrgList
    while iLen > 0 do
        if iLen <= 1 then
            table.insert(lRetOrg, table.remove(lOrgList, 1))
        else
            local iRange = math.min(6, iLen)
            local iRan = math.random(2, iRange)
            local iTarget = table.remove(lOrgList, iRan)
            local iOrg = table.remove(lOrgList, 1)
            mMatchForward[iOrg] = iTarget
            mMatchReverse[iTarget] = iOrg
        end
        iLen = #lOrgList
    end
    return mMatchForward, mMatchReverse, lRetOrg
end

function CMatch:GetSignInConfig()
    return res["daobiao"]["huodong"]["orgwar"]["signin"][1]
end

