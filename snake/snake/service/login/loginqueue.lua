-- 排队系统

local global = require "global"

local gamedefines = import(lualib_path("public.gamedefines"))

function NewLoginQueueMgr()
    local o = CLoginQueueMgr:New()
    return o
end


ONLINE_PLAYER_LIMIT = 8000
TIME_KEEP_NUMBER = 3 * 60

CLoginQueueMgr = {}
CLoginQueueMgr.__index = CLoginQueueMgr
inherit(CLoginQueueMgr, logic_base_cls())

function CLoginQueueMgr:New()
    local o = super(CLoginQueueMgr).New(self)
    o.m_iCallNumber = 0     -- 当前叫号
    o.m_iLastNumber = 0     -- 最后取号
    o.m_mQueueList = {}     -- iNumber:pid
    o.m_mQueuePlayers = {}  -- pid:iNumber
    o.m_mDisconnect = {}    -- 断线保号列表
    o.m_mCallList = {}      -- 叫到号列表
    o.m_lQuickList = {}     -- 快速通道

    o.m_mOnlinePlayers = {}
    o.m_iOnlineCnt = 0
    o.m_mPlayerHandles = {}

    o.m_iLastSecCnt = 0
    o.m_iPerSecondCnt = 0
    return o
end

function CLoginQueueMgr:Init()
    self:Schedule()
end

function CLoginQueueMgr:Schedule()
    local f
    f = function ()
        self:DelTimeCb("_CheckTimeOut")
        self:AddTimeCb("_CheckTimeOut", 60 * 1000, f)
        self:_CheckTimeOut()
    end
    f()
end

function CLoginQueueMgr:_CheckTimeOut()
    local lKickList = {}
    local iNowTime = get_time()
    for pid, iTime in pairs(self.m_mDisconnect) do
        if iNowTime - iTime > TIME_KEEP_NUMBER then
            table.insert(lKickList, pid)
        end
    end
    for _, pid in ipairs(lKickList) do
        local iNumber = self.m_mQueuePlayers[pid]
        self.m_mDisconnect[pid] = nil
        self.m_mQueuePlayers[pid] = nil
        self.m_mQueueList[iNumber] = nil
    end

    local lCallTimeOut = {}
    for pid, iTime in pairs(self.m_mCallList) do
        if iNowTime - iTime > TIME_KEEP_NUMBER then
            table.insert(lCallTimeOut, pid)
        end
    end
    for _, pid in ipairs(lCallTimeOut) do
        self.m_mCallList[pid] = nil
        if self.m_mPlayerHandles[pid] then
            self.m_mPlayerHandles[pid] = nil
        end
    end
    for i = 1, #lCallTimeOut do
        self:CallNumber()
    end

    local iDiffCnt = self:GetOnlinePlayerLimit() - self:GetOnlineTotCnt()
    if iDiffCnt > 0 then
        for i = 1, iDiffCnt do
            self:CallNumber()
        end
    end

    self.m_iLastSecCnt = self.m_iPerSecondCnt
    self.m_iPerSecondCnt = 0
end

function CLoginQueueMgr:SetOnlinePlayerLimit(iLimit)
    local iOldLimit = self:GetOnlinePlayerLimit()
    self.m_iOnlineLimit = iLimit
    for i = 1, iLimit - iOldLimit do
        self:CallNumber()
    end
end

function CLoginQueueMgr:GetOnlinePlayerLimit()
    return self.m_iOnlineLimit or gamedefines.QUEUE_CNT
end

function CLoginQueueMgr:GetNumber()
    self.m_iLastNumber = self.m_iLastNumber + 1
    return self.m_iLastNumber
end

function CLoginQueueMgr:GetOnlineTotCnt()
    return self.m_iOnlineCnt + table_count(self.m_mCallList)
end


function CLoginQueueMgr:NeedQueue(pid)
    if self.m_mOnlinePlayers[pid] then
        return false
    elseif self.m_mCallList[pid] then
        return false
    elseif table_in_list(self.m_lQuickList, pid) then
        return false
    else
        local iOnlineLimit = self:GetOnlinePlayerLimit()
        if self:GetOnlineTotCnt() < iOnlineLimit and not next(self.m_mQueueList) then
            return false
        end
    end
    return true
end

function CLoginQueueMgr:ValidLogin(pid, iHandle)
    if self.m_mDisconnect[pid] then
        self.m_mDisconnect[pid] = nil
    end
    if self:NeedQueue(pid) then
        self:PendingQueue(pid, iHandle)
        return false
    else
        self:OnLogin(pid)
        return true
    end
end

function CLoginQueueMgr:OnLogin(pid)
    if not self.m_mOnlinePlayers[pid] then
        self.m_mOnlinePlayers[pid] = true
        self.m_iOnlineCnt = self.m_iOnlineCnt + 1
        self.m_iPerSecondCnt = self.m_iPerSecondCnt + 1
    end
    if self.m_mCallList[pid] then
        self.m_mCallList[pid] = nil
    end
    if self.m_mPlayerHandles[pid] then
        self.m_mPlayerHandles[pid] = nil
    end
end

function CLoginQueueMgr:OnLogout(pid)
    if self.m_mOnlinePlayers[pid] then
        self.m_iOnlineCnt = self.m_iOnlineCnt - 1
        self.m_mOnlinePlayers[pid] = nil
    end
    if self.m_iOnlineCnt < 0 then
        self.m_iOnlineCnt = 0
    end
    self:CallNumber()
end

-- -- 暂不调用，断线也继续排号
-- function CLoginQueueMgr:OnDisconnect(pid)
--     self.m_mDisconnect[pid] = get_time()
-- end

function CLoginQueueMgr:QuitQueue(pid)
    local iNumber = self.m_mQueuePlayers[pid]
    self.m_mDisconnect[pid] = nil
    self.m_mQueuePlayers[pid] = nil
    self.m_mQueueList[iNumber] = nil
    self.m_mPlayerHandles[pid] = nil
end


function CLoginQueueMgr:PendingQueue(pid, iHandle)
    if self.m_mQueuePlayers[pid] then
        self.m_mPlayerHandles[pid] = iHandle
        self:GS2CLoginPendingUI(pid)
        return
    end
    local iNumber = self:GetNumber()
    self.m_mQueueList[iNumber] = pid
    self.m_mQueuePlayers[pid] = iNumber
    self.m_mPlayerHandles[pid] = iHandle
    self:GS2CLoginPendingUI(pid)
end


function CLoginQueueMgr:CallNumber()
    if self.m_iCallNumber >= self.m_iLastNumber then
        return
    end
    local iCallNum = self.m_iCallNumber
    local iNowTime = get_time()
    for iNumber = iCallNum + 1, self.m_iLastNumber do
        local iPid = self.m_mQueueList[iNumber]
        if iPid then
            self.m_iCallNumber = iNumber

            self.m_mQueueList[iNumber] = nil
            self.m_mQueuePlayers[iPid] = nil
            self.m_mCallList[iPid] = iNowTime
            self:GS2CLoginPendingEnd(iPid)
            break
        end
    end
end

function CLoginQueueMgr:GetWaitInfo(pid)
    local iNumber = self.m_mQueuePlayers[pid]
    if not iNumber then
        return nil
    end

    local iCntBefore = iNumber - self.m_iCallNumber
    local iTime = math.floor(iCntBefore / math.max(self.m_iLastSecCnt, 1) * 60)
    return {
        cnt = iCntBefore,
        time = iTime
    }
end

function CLoginQueueMgr:GetConnection(pid)
    local oGateMgr = global.oGateMgr
    local iHandle = self.m_mPlayerHandles[pid]
    if not iHandle then
        return nil
    end
    return oGateMgr:GetConnection(iHandle)
end

function CLoginQueueMgr:Send(pid, sMessage , mData)
    local oConnection = self:GetConnection(pid)
    if oConnection then
        oConnection:Send(sMessage, mData)
    end
end

function CLoginQueueMgr:GS2CLoginPendingUI(pid)
    local mData = self:GetWaitInfo(pid)
    if not mData then
        return
    end
    self:Send(pid, "GS2CLoginPendingUI", mData)
end

function CLoginQueueMgr:GS2CLoginPendingEnd(pid)
    self:Send(pid, "GS2CLoginPendingEnd", {})
end
