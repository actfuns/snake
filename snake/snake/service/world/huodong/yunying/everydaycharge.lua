local global = require "global"
local res = require "base.res"
local interactive = require "base.interactive"
local record = require "public.record"
local extend = require "base.extend"
local net = require "base.net"

local gamedefines = import(lualib_path("public.gamedefines"))
local huodongbase = import(service_path("huodong.huodongbase"))
local datactrl = import(lualib_path("public.datactrl"))
local orgdefines = import(service_path("org.orgdefines"))

function NewHuodong(sHuodongName)
    return CHuodong:New(sHuodongName)
end

CHuodong = {}
CHuodong.__index = CHuodong
CHuodong.m_sTempName = "每日单充"
inherit(CHuodong, huodongbase.CHuodong)

function CHuodong:New(sHuodongName)
    local o = super(CHuodong).New(self, sHuodongName)
    o.m_iHdId = 0
    o.m_iStartTime = 0
    o.m_iEndTime = 0
    o.m_sHdKey = nil
    o.m_iCurDay = 0
    o.m_iDayNo = 0
    o.m_mRewardInfo = {}                -- {pid:{key:{day:{reward:0, rewarded:0}}}
    return o
end

function CHuodong:NeedSave()
    return true
end

function CHuodong:OnLogin(oPlayer, bReEnter)
    if self:IsHuodongOpen() then
        self:GS2CGameStart(oPlayer)
        self:GS2CGameReward(oPlayer)
    end
end

function CHuodong:Save()
    local mData = {}
    mData.hdid = self.m_iHdId
    mData.starttime = self.m_iStartTime
    mData.endtime = self.m_iEndTime    
    mData.hdkey = self.m_sHdKey
    mData.curday = self.m_iCurDay
    mData.dayno = self.m_iDayNo
    mData.rewardinfo = self.m_mRewardInfo
    return mData
end

function CHuodong:Load(mData)
    if not mData then return end

    self.m_iHdId = mData.hdid or 0
    self.m_iStartTime = mData.starttime or 0
    self.m_iEndTime = mData.endtime or 0
    self.m_sHdKey = mData.hdkey
    self.m_iCurDay = mData.curday
    self.m_iDayNo = mData.dayno
    self.m_mRewardInfo = mData.rewardinfo or {}

    self:RefreshPerDay()
end

function CHuodong:MergeFrom(mFromData)
    if not mFromData or not next(mFromData) then
        return false, "huodong everydaycharge without data"
    end
    if self.m_sHdKey ~= mFromData.hdkey then return true end
    local iNowTime = get_time()
    if self:IsOpen(iNowTime) and iNowTime > mFromData.starttime and iNowTime < mFromData.endtime then
        for iPid, mReward in pairs(mFromData.rewardinfo or {}) do
            self.m_mRewardInfo[iPid] = mReward
        end
        self:Dirty()
    end
    return true
end

function CHuodong:GetFortune(iMoneyType, mArgs)
    return false
end

function CHuodong:GetEndTime()
    return self.m_iEndTime
end

function CHuodong:IsOpen(iNowTime)
    if self.m_iStartTime <= 0 or self.m_iEndTime <= 0 then return false end

    local iNowTime = iNowTime or get_time()
    if iNowTime < self.m_iStartTime then
        return false
    end
    if iNowTime > self.m_iEndTime then
        return false
    end
    return true
end

-- 5点
function CHuodong:NewDay(mNow)
    self:RefreshPerDay(mNow.time, true)
end

function CHuodong:RefreshPerDay(iNowTime, bClient)
    if self.m_iStartTime <= 0 or self.m_iEndTime <= 0 then
        return
    end
    if self.m_iCurDay <= 0 then return end

    iNowTime = iNowTime or get_time()
    local iCurDayNo = get_morningdayno(iNowTime)
    if iCurDayNo ~= self.m_iDayNo then
        self.m_iCurDay = self.m_iCurDay + 1
        self:CheckGiveReward(self.m_iCurDay - 1) 
        self.m_iDayNo = iCurDayNo
    end
    if not self:IsOpen(iNowTime) then
        -- 只是简单的更新数据
        self:GameEnd(bClient)
    end
end

--运营开启活动接口
function CHuodong:RegisterHD(mInfo, bClose)
    if bClose then
        self:TryGameEnd(true)
        record.warning(string.format("%s force close", self.m_sName)) 
    else
        self:TryGameStart(mInfo)
    end
    return true
end

function CHuodong:TryGameStart(mInfo, oPlayer)
    if self:IsOpen() then
        if oPlayer then
            local sText = self:GetTextData(1001)
            global.oNotifyMgr:Notify(oPlayer:GetPid(),sText)
        end
        record.warning(string.format("%s gamestart error huodong has in world", self.m_sName)) 
        return
    end
    self.m_iHdId = mInfo.hd_id
    self.m_sHdKey = mInfo.hd_key
    self.m_iStartTime = mInfo.start_time
    self.m_iEndTime = mInfo.end_time
    self.m_iCurDay = 1
    self.m_iDayNo = get_morningdayno(math.max(get_time(), self.m_iStartTime))
    self.m_mRewardInfo = {}
    self:Dirty()

    local mLogData = {}
    mLogData.hdkey = self.m_sHdKey
    mLogData.hdid = self.m_iHdId
    mLogData.starttime = get_time_format_str(self.m_iStartTime, "%Y-%m-%d %H:%M:%S")
    mLogData.endtime = get_time_format_str(self.m_iEndTime, "%Y-%m-%d %H:%M:%S")
    record.log_db("huodong", "everydaycharge_state", mLogData)

    self:BroadHuodong2World("GS2CEveryDayChargeStart", {endtime=self:GetEndTime(), reward_key=self.m_sHdKey})
    self:BroadHuodong2World("GS2CEveryDayChargeReward", {curday=self.m_iCurDay})
    record.info(string.format("%s GameStart %s",self.m_sName, self.m_sHdKey))
    global.oHotTopicMgr:Register(self.m_sName)
end

function CHuodong:BroadHuodong2World(sMsg, mNet)
    local mData = {
        message = sMsg,
        type = gamedefines.BROADCAST_TYPE.WORLD_TYPE,
        id = 1,
        data = mNet,
        exclude = {},
    }
    interactive.Send(".broadcast", "channel", "SendChannel", mData)
end

function CHuodong:TryGameEnd(bClient)
    self:CheckGiveReward(self.m_iCurDay)
    self:GameEnd(bClient)
end

function CHuodong:GameEnd(bClient)
    self.m_iHdId = 0
    self.m_iStartTime = 0
    self.m_iEndTime = 0
    self.m_sHdKey = nil
    self.m_iCurDay = 0
    self.m_iDayNo = 0
    self.m_mRewardInfo = {}
    self:Dirty()

    global.oHotTopicMgr:UnRegister(self.m_sName)
    if bClient then
        self:BroadHuodong2World("GS2CEveryDayChargeEnd", {}) 
    end
end

function CHuodong:CheckReward(oPlayer, sProductKey)
    if not self:IsOpen() then return end
    local mData = self:GetConfigDataByKey(sProductKey)
    if not mData then return end

    local sKey = mData["dbkey"]
    local iRewardCnt = mData["rewardcnt"]
    if iRewardCnt <= 0 then
        record.warning(string.format("%s CHuodong:CheckReward error %s %s",self.m_sName, iRewardCnt, sProductKey))
        return
    end
    
    local iPid = oPlayer:GetPid()
    local mPlayerReward = self.m_mRewardInfo[iPid]
    if not mPlayerReward then
        mPlayerReward = {}
        self.m_mRewardInfo[iPid] = mPlayerReward
    end

    local mDayReward = mPlayerReward[self.m_iCurDay]
    if not mDayReward then
        mDayReward = {}
        mPlayerReward[self.m_iCurDay] = mDayReward
    end

    local mReward = mDayReward[sKey]
    if not mReward then
        mReward = {}
        mDayReward[sKey] = mReward
    end

    local iCnt = mReward.reward or 0
    if iCnt >= iRewardCnt then return end

    mReward.reward = iCnt + 1
    self:Dirty()
    self:GS2CGameReward(oPlayer)

    local mLogData = {}
    mLogData.pid = iPid
    mLogData.hdid = self.m_iHdId
    mLogData.hdkey = self.m_sHdKey
    mLogData.reward = 0
    mLogData.day = self.m_iCurDay
    mLogData.flag = sKey
    mLogData.rewardcnt = mReward.reward
    mLogData.rewardedcnt = mReward.rewarded or 0
    mLogData.op = 1
    record.log_db("huodong", "everydaycharge_reward",mLogData)
end

function CHuodong:GetReward(oPlayer,sKey,iDay)
    local oNotifyMgr = global.oNotifyMgr
    local iPid = oPlayer:GetPid()
    if not self:IsOpen() then
        oNotifyMgr:Notify(iPid, self:GetTextData(1002))
        return
    end

    local mPlayerReward = self.m_mRewardInfo[iPid]
    if not mPlayerReward then return end
    
    local mDayReward = mPlayerReward[iDay]
    if not mDayReward then return end

    local mReward = mDayReward[sKey]
    if not mReward then return end    

    local iCanCnt = mReward.reward or 0
    local iHasCnt = mReward.rewarded or 0
    if iCanCnt <= iHasCnt then
        --oNotifyMgr:Notify(pid,self:GetTextData(1003))
        return
    end

    local sPayKey = self:GetPayKey(sKey)
    local mData = self:GetConfigDataByKey(sPayKey)
    if not mData then
        reward.warning(string.format("CHuodong:GetReward error not reward %s %s, %s", self.m_sName, sPayKey, iPid))
        return
    end

    local iReward = mData[self.m_sHdKey]
    if not iReward then
        reward.warning(string.format("CHuodong:GetReward error 222 not reward %s %s, %s", self.m_sName, self.m_sHdKey, iPid))
        return
    end
    if oPlayer.m_oItemCtrl:GetCanUseSpaceSize() < global.oToolMgr:GetItemRewardCnt(self.m_sName, iReward) then
        global.oNotifyMgr:Notify(iPid, global.oToolMgr:GetTextData(3015))
        return false

    end

    self:Dirty()
    mReward.rewarded = iHasCnt + 1

    local mLogData = {}
    mLogData.pid = iPid
    mLogData.hdid = self.m_iHdId
    mLogData.hdkey = self.m_sHdKey
    mLogData.reward = 1
    mLogData.day = iDay
    mLogData.flag = sKey
    mLogData.rewardcnt = mReward.reward
    mLogData.rewardedcnt = mReward.rewarded or 0
    mLogData.op = 2
    record.log_db("huodong", "everydaycharge_reward",mLogData)

    self:Reward(iPid, iReward)
    self:GS2CGameReward(oPlayer)
end

-- 自动发奖
function CHuodong:CheckGiveReward(iDay)
    self:Dirty()

    local sKey = string.format("%s_GiveReward", self.m_sName)
    local lPids = table_key_list(self.m_mRewardInfo)
    global.oToolMgr:ExecuteList(lPids, 100, 500, 0, sKey, function (iPid)
        self:_GiveReward(iPid, iDay)
    end)
end

function CHuodong:_GiveReward(iPid, iDay)
    local mPlayerReward = self.m_mRewardInfo[iPid]
    if not mPlayerReward then return end

    local mDayReward = mPlayerReward[iDay]
    if not mDayReward then return end

    local lItemList = {}
    local oPlayer = global.oWorldMgr:GetOnlinePlayerByPid(iPid)
    for sKey, mReward in pairs(mDayReward) do
        local iCanCnt = mReward.reward or 0
        local iHasCnt = mReward.rewarded or 0
        if iCanCnt <= iHasCnt then
            goto continue
        end

        local sPayKey = self:GetPayKey(sKey)
        local mData = self:GetConfigDataByKey(sPayKey)
        if not mData then
            goto continue
        end
        local iReward = mData[self.m_sHdKey]
        if not iReward then
            goto continue
        end

        mReward.rewarded = iCanCnt
        self:Dirty()

        local mLogData = {}
        mLogData.pid = iPid
        mLogData.hdid = self.m_iHdId
        mLogData.hdkey = self.m_sHdKey
        mLogData.reward = iCanCnt - iHasCnt
        mLogData.day = iDay
        mLogData.flag = sKey
        mLogData.rewardcnt = mReward.reward
        mLogData.rewardedcnt = mReward.rewarded or 0
        mLogData.op = 3
        record.log_db("huodong", "everydaycharge_reward",mLogData)

        for iCnt = 1, iCanCnt - iHasCnt do
            local mRewardData = self:GetRewardData(iReward)
            for _,itemreward in pairs(mRewardData.item) do
                local mRewardInfo = self:GetItemRewardData(itemreward)
                if mRewardInfo then
                    local mItemInfo = self:ChooseRewardKey(oPlayer, mRewardInfo, itemreward, {})
                    if mItemInfo then
                        local iteminfo = self:InitRewardByItemUnitOffline(iPid, itemreward, mItemInfo)
                        list_combine(lItemList, iteminfo["items"])
                    end
                end
            end
        end
        ::continue::
    end

    if #lItemList > 0 then
        local mMailReward = {}
        mMailReward["items"] = lItemList
        self:SendMail(iPid, 2035, mMailReward)
    end

    if oPlayer then
        self:GS2CGameReward(oPlayer)
    end
end

function CHuodong:InitRewardByItemUnitOffline(pid, itemidx, mItemInfo)
    local mItems = {}
    local sShape = mItemInfo["sid"]
    local iBind = mItemInfo["bind"]
    if type(sShape) ~= "string" then
        print(debug.traceback(""))
        return
    end
    local iAmount = mItemInfo["amount"]
    local oItem = global.oItemLoader:ExtCreate(sShape, {})
    oItem:SetAmount(iAmount)
    if iBind ~= 0 then
        oItem:Bind(pid)
    end
    mItems["items"] = {oItem}
    return mItems
end

function CHuodong:GS2CGameStart(oPlayer)
    local mNet = {}
    mNet.endtime = self:GetEndTime()
    mNet.reward_key=self.m_sHdKey
    oPlayer:Send("GS2CEveryDayChargeStart",mNet)
end

function CHuodong:GS2CGameEnd(oPlayer)
    oPlayer:Send("GS2CEveryDayChargeEnd",{})
end

function CHuodong:GS2CGameReward(oPlayer)
    local mNet = {}
    local iPid = oPlayer:GetPid()
    local mPlayerReward = self.m_mRewardInfo[iPid] or {}
    local RewardList = {}
    for iDay, mDayReward in pairs(mPlayerReward) do
        for sKey, mReward in pairs(mDayReward) do
            local mData = {}
            mData.flag = sKey
            mData.day = iDay
            mData.reward = mReward.reward 
            mData.rewarded = mReward.rewarded
            table.insert(RewardList, mData)
        end
    end
    mNet.rewardlist = RewardList
    mNet.curday = self.m_iCurDay
    oPlayer:Send("GS2CEveryDayChargeReward",mNet)
end

function CHuodong:IsHuodongOpen()
    return self:IsOpen()
end

function CHuodong:GetAllConfigData()
    return res["daobiao"]["huodong"][self.m_sName]["reward"]
end

function CHuodong:GetConfigDataByKey(sKey)
    return self:GetAllConfigData()[sKey]
end

function CHuodong:GetPayKey(sDbKey)
    for sPayKey,mInfo in pairs(self:GetAllConfigData()) do
        if mInfo.dbkey == sDbKey then
            return sPayKey
        end
    end
end

function CHuodong:TestOp(iFlag, mArgs)
    local oChatMgr = global.oChatMgr
    local oNotifyMgr = global.oNotifyMgr
    local oWorldMgr = global.oWorldMgr
    local pid = mArgs[#mArgs]
    local oPlayer = oWorldMgr:GetOnlinePlayerByPid(pid)

    local mCommand={
        "100 指令查看",
        "101 活动开始\nhuodongop everydaycharge 101",
        "102 活动结束\nhuodongop everydaycharge 102",
    }
    --sethdcontrol everydaycharge default 0 60
    if iFlag == 100 then
        for idx=#mCommand,1,-1 do
            oChatMgr:HandleMsgChat(oPlayer,mCommand[idx])
        end
        oNotifyMgr:Notify(pid,"请看消息频道咨询指令")
    elseif iFlag  == 101 then
        local iWeekNo = get_morningweekno(get_time())
        local iStartTime = get_time()
        local iEndTime = get_morningweekno2time(iWeekNo + 1)
        local mInfo = {
            hd_id = 0,
            hd_key = "reward_new",
            start_time = iStartTime,
            end_time = iEndTime - 1
        }
        self:TryGameStart(mInfo, oPlayer)
    elseif iFlag == 102 then
        self:TryGameEnd(true)
        oNotifyMgr:Notify(pid,"关闭成功")
    elseif iFlag == 202 then
        self:GameEnd(true)
    elseif iFlag == 201 then -- huodongop everydaycharge 201 {pay=30,day=1}
        local sKey = db_key(mArgs.pay) 
        local iDay = mArgs.day 
        self:GetReward(oPlayer,iDay,sKey)
    end
end