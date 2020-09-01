local global = require "global"
local record = require "public.record"
local res = require "base.res"
local datactrl = import(lualib_path("public.datactrl"))


function NewMonitor(...)
    return CNormalMonitor:New(...)
end

CBaseMonitor = {}
CBaseMonitor.__index = CBaseMonitor
inherit(CBaseMonitor, datactrl.CDataCtrl)

function CBaseMonitor:New()
    local o = super(CBaseMonitor).New(self)
    o.m_mRecord = {}
    return o
end

function CBaseMonitor:GetLimitInfo(...)
end

function CBaseMonitor:CheckRewardGroup(...)
end

function CBaseMonitor:ClearRecordInfo()
    self.m_mRecord = {}
end

function CBaseMonitor:TouchDayRefresh()
    local iCurDayNo = get_morningdayno(get_time())
    if self.m_iDayNo ~= iCurDayNo then
        self.m_iDayNo = iCurDayNo
        self.m_mRecord = {}
    end
end

----------------------------
CNormalMonitor = {}
CNormalMonitor.__index = CNormalMonitor
inherit(CNormalMonitor, CBaseMonitor)

function CNormalMonitor:New(sName, lUrl)
    local o = super(CNormalMonitor).New(self)
    o.m_sName = sName
    o.m_lUrl = lUrl
    return o
end

function CNormalMonitor:GetLimitInfo()
    local mInfo = table_get_depth(res["daobiao"], self.m_lUrl)
    if mInfo then
        return mInfo["rewardlimit"]
    end
end

function CNormalMonitor:CheckRewardGroup(iPid, iReward, iCnt, mArgs)
    local oPlayer = global.oWorldMgr:GetOnlinePlayerByPid(iPid)
    if oPlayer and oPlayer:Query("ignore_reward_monitor") then
        return true
    end

    local sReward = tostring(iReward)
    local mLimitInfo = self:GetLimitInfo()
    if not mLimitInfo or not mLimitInfo[sReward] then return true end

    iCnt = iCnt or 1
    local iTimes = table_get_depth(self.m_mRecord, {iPid, sReward}) or 0

    if iTimes < mLimitInfo[sReward] then
        iTimes = iTimes + iCnt
        table_set_depth(self.m_mRecord, {iPid}, sReward, iTimes)
        return true
    else
        record.error("%s get rewardidx %s in %s reach limit %d",
            iPid,
            sReward,
            self.m_sName,
            mLimitInfo[sReward]
        )
        return false
    end
end

function CNormalMonitor:CheckAddNumeric(iPid, sType, iVal)
    local mLimitInfo = self:GetLimitInfo()
    if not mLimitInfo[sType] then return true end

    local iOld = table_get_depth(self.m_mRecord, {iPid, sType}) or 0

    if iOld < mLimitInfo[sType] then
        local iNew = iOld + iVal
        table_set_depth(self.m_mRecord, {iPid}, sType, iNew)
        return true
    else
        record.error("%s get reward %s %s in %s reach limit %s",
            iPid,
            sType,
            iVal,
            self.m_sName,
            mLimitInfo[sType]
        )
        --TODO notify?
        return false
    end
end

function CNormalMonitor:NewHour5()
    self:ClearRecordInfo()
end

--------------------------------------
CStoryTaskRewardMonitor = {}
CStoryTaskRewardMonitor.__index = CStoryTaskRewardMonitor
inherit(CStoryTaskRewardMonitor, CBaseMonitor)

function CStoryTaskRewardMonitor:New()
    local o = super(CStoryTaskRewardMonitor).New(self)
    o.m_sName = "story"
    return o
end

-- 此对象不仅用于主线任务，也用于类似主线的支线与引导任务、主线章节
function CStoryTaskRewardMonitor:CheckRewardGroup(iPid, sType, xKey, iCnt, mArgs)
    local oPlayer = global.oWorldMgr:GetOnlinePlayerByPid(iPid)
    if oPlayer and oPlayer:Query("ignore_reward_monitor") then
        return true
    end

    self:TouchDayRefresh()

    local sKey = tostring(xKey)
    if table_get_depth(self.m_mRecord, {iPid, sType, sKey}) then
        record.error("task one-time reward twice, pid:%d, type:%s, key:%s", iPid, sType, sKey)
        return false
    end
    table_set_depth(self.m_mRecord, {iPid, sType}, sKey, 1)
    return true
end

function CStoryTaskRewardMonitor:ClearPlayerRecord(iPid)
    self.m_mRecord[iPid] = nil
end

--------------------------------------
CTaskRewardMonitor = {}
CTaskRewardMonitor.__index = CTaskRewardMonitor
inherit(CTaskRewardMonitor, CBaseMonitor)

function CTaskRewardMonitor:New()
    local o = super(CTaskRewardMonitor).New(self)
    o.m_iDayNo = get_morningdayno(get_time())
    return o
end

function CTaskRewardMonitor:GetLimitInfo(sType)
    if not sType then
        return nil
    end
    return table_get_depth(res["daobiao"], {"reward", sType, "rewardlimit"})
end

-- @param sReward: 默认是奖励表id转的string，也可以是特别定制的奖励标记(e.g. "total")
function CTaskRewardMonitor:CheckRewardGroup(iPid, sType, sReward, iCnt, mArgs)
    local oPlayer = global.oWorldMgr:GetOnlinePlayerByPid(iPid)
    if oPlayer and oPlayer:Query("ignore_reward_monitor") then
        return true
    end
    local sRewardId = tostring(sReward)
    local mLimitInfo = self:GetLimitInfo(sType)
    if not mLimitInfo then return true end
    local iLimit = mLimitInfo[sRewardId]
    if not iLimit then return true end

    self:TouchDayRefresh()

    local iOldRewardTimes = table_get_depth(self.m_mRecord, {iPid, sType, sRewardId}) or 0
    local iRewardTimes = iOldRewardTimes + iCnt
    if iRewardTimes > iLimit then
        record.error("%s reward overlimit, pid:%d, rewardid:%s, rewardedtimes:%d, thisaddcnt:%d", sType, iPid, sRewardId, iOldRewardTimes, iCnt)
        return false
    end
    table_set_depth(self.m_mRecord, {iPid, sType}, sRewardId, iRewardTimes)
    return true
end

function CTaskRewardMonitor:ClearRecordByType(iPid, sType)
    local mPid = self.m_mRecord[iPid]
    if not mPid then
        return
    end
    mPid[sType] = nil
end

function CTaskRewardMonitor:ClearPlayerRecord(iPid)
    self.m_mRecord[iPid] = nil
end
