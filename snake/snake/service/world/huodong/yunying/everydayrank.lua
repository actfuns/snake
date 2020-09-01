local global = require "global"
local res = require "base.res"
local record = require "public.record"
local extend = require "base.extend"
local interactive = require "base.interactive"
local gamedefines = import(lualib_path("public.gamedefines"))
local huodongbase = import(service_path("huodong.huodongbase"))


function NewHuodong(sHuodongName)
    return CHuodong:New(sHuodongName)
end

CHuodong = {}
CHuodong.__index = CHuodong
CHuodong.m_sTempName = "每日冲榜"
inherit(CHuodong, huodongbase.CHuodong)

function CHuodong:Init()
    super(CHuodong).Init(self)
    self.m_iRankIdx = nil
    self.m_iStartTime = 0
    self.m_iEndTime = 0
    self.m_iDayNo = 0
    self.m_mRecordRankIdx = {}
end

function CHuodong:NeedSave()
    return true
end

function CHuodong:Save()
    local mData = {}
    mData.start_time = self.m_iStartTime or 0
    mData.end_time = self.m_iEndTime or 0
    mData.rank_idx = self.m_iRankIdx
    mData.day_no = self.m_iDayNo
    mData.record_rank = self.m_mRecordRankIdx
    return mData
end

function CHuodong:Load(m)
    if not m then return end

    self.m_iStartTime = m.start_time
    self.m_iEndTime = m.end_time
    self.m_iRankIdx = m.rank_idx
    self.m_iDayNo = m.day_no
    self.m_mRecordRankIdx = m.record_rank
end

function CHuodong:MergeFrom(mFromData)
    return true
end

function CHuodong:NewHour(mNow)
    if self.m_iEndTime <= 0 then return end

    local iTime = mNow.time
    if math.abs(iTime - self.m_iEndTime) < 100 then
        self:TryGameOver()
    end
    if math.abs(iTime - self.m_iStartTime) < 100 then
        self:TryGameStart()
    end
end

function CHuodong:NewDay(mNow)
    local iTime = mNow.time
    if self.m_iDayNo ~= get_morningdayno(iTime) and self:InGameTime() then
        self:Dirty()
        self.m_iDayNo = get_morningdayno(iTime)
        self.m_iRankIdx = self:ChooseRankIdx()
        local mNet = self:PackHuodongInfo()
        global.oNotifyMgr:WorldBroadcast("GS2CEveryDayRankStart", mNet)
    end
end

function CHuodong:ChooseRankIdx()
    local mConfig = res["daobiao"]["huodong"][self.m_sName]["config"][1]
    local lRankList = {}
    for _, iRankIdx in ipairs(mConfig.random_rank) do
        if not self.m_mRecordRankIdx[iRankIdx] then
            table.insert(lRankList, iRankIdx)
        end
    end
    if #lRankList <= 0 then
        return
    end
    local iIdx = extend.Random.random_choice(lRankList)
    self.m_mRecordRankIdx[iIdx] = 1
    self:Dirty()
    return iIdx
end

function CHuodong:InGameTime()
    return get_time() >= self.m_iStartTime and get_time() <= self.m_iEndTime
end

function CHuodong:CanPushRankData(sType, iDayNo)
    if self.m_iDayNo ~= iDayNo then
        return false
    end

    local iRank
    for id, mInfo in pairs(res["daobiao"]["rank"]) do
        if sType == mInfo.name then
            iRank = id
        end
    end

    if self.m_iRankIdx == iRank then
        return true
    end

    local mConfig = res["daobiao"]["huodong"][self.m_sName]["config"][1]
    if extend.Array.member(mConfig.stable_rank, iRank) then
        return true
    end
    
    return false
end

function CHuodong:RegisterHD(mInfo, bClose)
    if bClose then
        self:TryGameOver()
    else
        local bSucc, sError = self:CheckRegisterInfo(mInfo)
        if not bSucc then
            return false, sError
        end
        self:TryGameStart(mInfo)
    end
    return true
end

function CHuodong:TryGameStart(mInfo)
    self:Dirty()
    mInfo = mInfo or {}
    self.m_iStartTime = mInfo.start_time or self.m_iStartTime
    self.m_iEndTime = mInfo.end_time or self.m_iEndTime
    self.m_iDayNo = get_morningdayno()
    self.m_iRankIdx = self:ChooseRankIdx()

    if self:InGameTime() then
        local mNet = self:PackHuodongInfo()
        global.oNotifyMgr:WorldBroadcast("GS2CEveryDayRankStart", mNet)
    end
    global.oHotTopicMgr:Register(self.m_sName)
end

function CHuodong:TryGameOver()
    self:Init()
    global.oHotTopicMgr:UnRegister(self.m_sName)
    self:Dirty()
    global.oNotifyMgr:WorldBroadcast("GS2CEveryDayRankEnd", {})
end

function CHuodong:OnLogin(oPlayer, bReEnter)
    if not self:InGameTime() then return end

    local mNet = self:PackHuodongInfo()
    oPlayer:Send("GS2CEveryDayRankStart", mNet)
end

function CHuodong:PackHuodongInfo()
    local mNet = {
        rank_idx = self.m_iRankIdx,
        start_time = self.m_iStartTime,
        end_time = self.m_iEndTime,
    }
    return mNet
end

function CHuodong:CheckRegisterInfo(mInfo)
    if not global.oToolMgr:IsSysOpen("DAY_EXPENSE") then
        return
    end
    if mInfo.hd_type ~= self.m_sName then
        return false, string.format("hdtype:%s not equial hd_name:%s", mInfo.hd_type, self.m_sName)
    end
    if (mInfo.end_time or 0) <= get_time() then
        return false, string.format("%s end_time:%s less then curr time:%s", self.m_sName, mInfo.end_time, get_time())
    end
    if mInfo.start_time > mInfo.end_time then
        return false, string.format("start_time %s greater then end_time:%s", mInfo.start_time, mInfo.end_time)
    end
    return true
end

function CHuodong:IsHuodongOpen()
    if self:InGameTime() then
        return true
    else
        return false
    end
end

function CHuodong:TestOp(iFlag, mArgs)
    local iPid = mArgs[#mArgs]
    local oMaster = global.oWorldMgr:GetOnlinePlayerByPid(iPid)
    if iFlag == 100 then
        global.oNotifyMgr:Notify(iPid, [[
        101 - 开启活动
        102 - 结束活动
        103 - 结算排行榜
        104 - 设置随机榜 {随机榜id}
        ]])
    elseif iFlag == 101 then
        local iDay = math.min((mArgs[1] or 7), 7)
        self.m_iStartTime = get_time()
        self.m_iEndTime = get_daytime({day = iDay, anchor=5}).time
        self:TryGameStart()
    elseif iFlag == 102 then
        global.oRankMgr:NewHour(get_daytime({anchor=5}))
        self:TryGameOver()
    elseif iFlag == 103 then
        self:NewDay(get_daytime({}))
        global.oRankMgr:NewHour(get_daytime({anchor=5}))
    elseif iFlag == 104 then
        self.m_iRankIdx = mArgs[1]
        local mNet = self:PackHuodongInfo()
        global.oNotifyMgr:WorldBroadcast("GS2CEveryDayRankStart", mNet)
    end
end
