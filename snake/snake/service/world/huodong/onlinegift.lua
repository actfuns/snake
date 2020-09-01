local global = require "global"
local res = require "base.res"
local record = require "public.record"
local gamedefines = import(lualib_path("public.gamedefines"))
local huodongbase = import(service_path("huodong.huodongbase"))

function NewHuodong(sHuodongName)
    return CHuodong:New(sHuodongName)
end

local STATE_REWARD = 1 --可领取
local STATE_REWARDED = 2 --已领取

local ONE_MIN_SEC = 60

CHuodong = {}
CHuodong.__index = CHuodong
CHuodong.m_sTempName = "在线豪礼"
inherit(CHuodong, huodongbase.CHuodong)

function CHuodong:New(sHuodongName)
    local o = super(CHuodong).New(self, sHuodongName)
    o.m_mInfo = {}
    o.m_iStartTime = 0
    o.m_iEndTime = 0
    o.m_lCD = {}
    return o
end

function CHuodong:Init()
    local mConfig = self:GetConfig()
    self.m_iStartTime = get_str2timestamp(mConfig.start_time) or 0
    self.m_iEndTime = get_str2timestamp(mConfig.end_time) or 0
    self.m_lCD = self:GetCDTime() or {}

    local iNowTime = get_time()
    self.m_bIsOpen = iNowTime >= self.m_iStartTime and iNowTime <= self.m_iEndTime
end

function CHuodong:OnLogin(oPlayer, bReEnter)
    if not self:IsOnlineGiftOpen(oPlayer) then
        return
    end

    local iPid = oPlayer:GetPid()
    if not self.m_mInfo[iPid] then
        self.m_mInfo[iPid] = {
            status_list = {},
            online_time = 0,
            login_time = get_time()
        }
    end

    if not bReEnter then
        self.m_mInfo[iPid].login_time = get_time()
    end

    self:Dirty()
    self:GS2COnlineGift(oPlayer)

    if #self.m_mInfo[iPid].status_list < #self.m_lCD then
        self:AddPlayerTimeCb(oPlayer, true)
    end  
end

function CHuodong:OnLogout(oPlayer)
    local iPid = oPlayer:GetPid()
    if not self.m_mInfo[iPid] then
        return
    end
    self:SetOnceOnlineTime(iPid)    
    oPlayer:DelTimeCb("OnlineGiftCB")
end

function CHuodong:Load(mData)
    mData = mData or {}
    self:Dirty()
    local iCurMorningDayNo = get_morningdayno(get_time())
    if iCurMorningDayNo ~= mData.dayno then
        self.m_mInfo = {}
        return
    end
    self.m_mInfo = table_to_int_key(mData.info or {})
end

function CHuodong:Save()
    for iPid, _ in pairs(self.m_mInfo) do
        self:SetOnceOnlineTime(iPid)
    end
    local mData = {
        info = table_to_db_key(self.m_mInfo),
        dayno = get_morningdayno(get_time())
    }
    return mData
end

function CHuodong:SetOnceOnlineTime(iPid)
    local oPlayer = global.oWorldMgr:GetOnlinePlayerByPid(iPid)    
    if oPlayer and self.m_mInfo[iPid].login_time then
        self:Dirty()
        local iCurTime = get_time()
        local iOneceOnlineTime = iCurTime - self.m_mInfo[iPid].login_time
        self.m_mInfo[iPid].online_time = self.m_mInfo[iPid].online_time + iOneceOnlineTime
        self.m_mInfo[iPid].login_time = iCurTime
    end
end

function CHuodong:NeedSave()
    return true
end

function CHuodong:MergeFrom(mFromData)
    if not mFromData or not next(mFromData) then
        return false, "huodong onlinegift without data"
    end
    self:Dirty()
    local iCurMorningDayNo = get_morningdayno(get_time())
    if iCurMorningDayNo ~= mFromData.dayno then
        return true
    end
    local mInfo = table_to_int_key(mFromData.info or {})
    for iPid, mData in pairs(mInfo) do
        self.m_mInfo[iPid] = mData
    end
    return true
end

function CHuodong:GetFortune(iMoneyType, mArgs)
    return false
end

function CHuodong:NewHour(mNow)
    local iTime = mNow and mNow.time or get_time()
    if not self.m_bIsOpen and iTime >= self.m_iStartTime then
        self:RefreshAllOnlinePlayer()
        self:Dirty()
        self.m_bIsOpen = true
    end
end

function CHuodong:NewDay(mNow)
    self:RefreshAllOnlinePlayer()
    self:Dirty()
end

function CHuodong:RefreshAllOnlinePlayer()
    self.m_mInfo = {}

    local func = function (iPid)
        local oPlayer = global.oWorldMgr:GetOnlinePlayerByPid(iPid)
        if not oPlayer then return end
        oPlayer:DelTimeCb("OnlineGiftCB")  
        if self:IsOnlineGiftOpen(oPlayer) then
            self.m_mInfo[iPid] = {
                status_list = {},
                login_time = get_time(),
                online_time = 0,
            }
            self:GS2COnlineGift(oPlayer)
            self:AddPlayerTimeCb(oPlayer)    
        end
    end
    local lAllOnlinePid = table_key_list(global.oWorldMgr:GetOnlinePlayerList())
    global.oToolMgr:ExecuteList(lAllOnlinePid,100,1000,0,"OnlineGiftRefresh",func)
end

function CHuodong:AddPlayerTimeCb(oPlayer, bIsLogin)
    if oPlayer:GetTimeCb("OnlineGiftCB") then
        return
    end
    local iPid = oPlayer:GetPid()
    local iSz = #self.m_mInfo[iPid].status_list
    local iCheckTag = iSz + 1
    if not self.m_lCD[iCheckTag] then return end

    local time = self.m_lCD[1]
    if iCheckTag > 1 then
        time = self.m_lCD[iCheckTag] - self.m_lCD[iCheckTag-1]
    end
    time = time * ONE_MIN_SEC * 1000
    if bIsLogin and self.m_mInfo[iPid].online_time > 0 then
        local iSubTime = (self.m_lCD[iCheckTag] * ONE_MIN_SEC - self.m_mInfo[iPid].online_time) * 1000
        if iSubTime > 0 then
            time = iSubTime
        end
    end
    oPlayer:DelTimeCb("OnlineGiftCB")
    oPlayer:AddTimeCb("OnlineGiftCB", time, function()
        self:NotifyChange(iPid)
    end)
end

function CHuodong:NotifyChange(iPid)
    local oPlayer = global.oWorldMgr:GetOnlinePlayerByPid(iPid)
    if not oPlayer then return end

    --活动结束
    local iCurTime = get_time()
    if iCurTime >= self.m_iEndTime then
        return
    end

    if not self.m_mInfo or not self.m_mInfo[iPid] then
        return
    end

    local iIndex = #self.m_mInfo[iPid].status_list + 1
    local iTag = self.m_lCD[iIndex]
    if not iTag then return end
    local mData = {
        key = iTag,
        status = STATE_REWARD
    }
    table.insert(self.m_mInfo[iPid].status_list, mData)
    self:Dirty()
    self:AddPlayerTimeCb(oPlayer)
    self:GS2COnlineGiftUnit(oPlayer, mData)
end

function CHuodong:IsOnlineGiftOpen(oPlayer)
    local bOpenLv = global.oToolMgr:IsSysOpen("ONLINE_GIFT", oPlayer, true)
    local iNowTime = get_time()
    return bOpenLv and iNowTime >= self.m_iStartTime and iNowTime <= self.m_iEndTime
end

function CHuodong:GetConfig()
    return res["daobiao"]["huodong"][self.m_sName]["condition"][1]
end

function CHuodong:GetOnlineGiftConfig()
    return res["daobiao"]["huodong"][self.m_sName]["online_gift"]
end

function CHuodong:GetCDTime()
    local mConfig = self:GetOnlineGiftConfig()
    local lCD = table_key_list(mConfig)
    table.sort(lCD)
    return lCD
end

function CHuodong:GS2COnlineGift(oPlayer)
    local iPid = oPlayer:GetPid()
    local mData = self.m_mInfo[iPid] or { status_list = {}, login_time = get_time(), online_time = 0 }
    local mSendData = {
        statuslist = mData.status_list,
        start_time = self.m_iStartTime,
        end_time = self.m_iEndTime,
        --在线时间是一天中在线时间的累加，中间可能退出，这里的时间戳后退在线时长。
        login_time = mData.login_time - mData.online_time,
    }
    oPlayer:Send("GS2COnlineGift", mSendData)
end

function CHuodong:GS2COnlineGiftUnit(oPlayer, mData)
    oPlayer:Send("GS2COnlineGiftUnit", { unit = mData })
end

function CHuodong:C2GSOnlineGift(oPlayer, iKey)
    local iPid = oPlayer:GetPid()

    if not self:IsOnlineGiftOpen(oPlayer) then
        global.oNotifyMgr:Notify(iPid, self:GetTextData(1001))
        return
    end

    if not self.m_mInfo[iPid] or not self.m_mInfo[iPid].status_list then
        return
    end
    
    local mSendData = nil
    for _, mData in ipairs(self.m_mInfo[iPid].status_list) do
        if mData.key == iKey and mData.status == STATE_REWARD then
            mData.status = STATE_REWARDED
            mSendData = mData
            break
        end
    end

    if mSendData then
        self:Dirty()
        local mConfig = self:GetOnlineGiftConfig(mSendData.key)
        if not mConfig[mSendData.key] then return end
        local iRewardId = mConfig[mSendData.key].reward
        self:Reward(iPid, iRewardId)
        self:GS2COnlineGiftUnit(oPlayer, mSendData)
        local mInfo = {
            pid = iPid,
            key = iKey,
            reward = iRewardId,
        }
        record.log_db("huodong", "onlinegift_reward", mInfo)
    end
end

function CHuodong:TestOp(iFlag, mArgs)
    local iPid = mArgs[#mArgs]
    local oMaster = global.oWorldMgr:GetOnlinePlayerByPid(iPid)
    if iFlag == 100 then
        global.oNotifyMgr:Notify(iPid, [[
        101 - 5点刷天 huodongop onlinegift 101
        102 - 关闭活动 huodongop onlinegift 102
        103 - 开启活动 huodongop onlinegift 103
        104 - 触发存盘 huodongop onlinegift 104
        ]])
    elseif iFlag == 101 then
        self:NewDay(get_daytime({}))
        global.oNotifyMgr:Notify(iPid, "刷新成功")
    elseif iFlag == 102 then
        local iCurTime = get_time() - 1
        self.m_iEndTime = iCurTime
        for pid, _ in pairs(self.m_mInfo) do
            local oPlayer = global.oWorldMgr:GetOnlinePlayerByPid(pid)
            if oPlayer then
                oPlayer:DelTimeCb("OnlineGiftCB")
                self:GS2COnlineGift(oPlayer)
            end
        end
        self.m_mInfo = {}
        global.oNotifyMgr:Notify(iPid, "关闭在线豪礼")
    elseif iFlag == 103 then
        local iNowTime = get_time()
        if iNowTime >= self.m_iStartTime and iNowTime <= self.m_iEndTime then
            global.oNotifyMgr:Notify(iPid, "在线豪礼已开启")
            return
        end
        self.m_bIsOpen = false
        self:Init()
        self:NewDay(get_daytime({}))
        global.oNotifyMgr:Notify(iPid, "开启在线豪礼")
    elseif iFlag == 104 then
        self:Save()
        global.oNotifyMgr:Notify(iPid, "存盘成功")
    end
end
