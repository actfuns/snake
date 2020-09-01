local global = require "global"
local res = require "base.res"
local interactive = require "base.interactive"
local record = require "public.record"
local extend = require "base.extend"
local net = require "base.net"

local gamedefines = import(lualib_path("public.gamedefines"))
local huodongbase = import(service_path("huodong.huodongbase"))
local datactrl = import(lualib_path("public.datactrl"))

function NewHuodong(sHuodongName)
    return CHuodong:New(sHuodongName)
end

CHuodong = {}
CHuodong.__index = CHuodong
CHuodong.m_sTempName = "道具投资"
inherit(CHuodong, huodongbase.CHuodong)

local MODE = {
    NEW = 1,
    OLD = 2,
}

local GAMESTATE = {
    READY_OPEN = 0, --已注册,准备开始
    INVEST_START = 1, --投资开始
    INVEST_END = 2, -- 投资结束,依然可领奖
    END = 3,  --结束
}

local ITEMSTATE = {
    REWARD = 1, --可领取
    REWARDED = 2, --已领取
}

function CHuodong:New(sHuodongName)
    local o = super(CHuodong).New(self, sHuodongName)
    o.m_iVersion = 0
    return o
end

function CHuodong:Init()
    self.m_iStartTime = 0
    self.m_iEndTime = 0
    self.m_iRewardEndTime = 0
    self.m_iMode = 0
    self.m_iState = GAMESTATE.END
    self.m_mRewardInfo = {}
end

function CHuodong:Save()
    local mData = {}
    mData.version = self.m_iVersion
    mData.state = self.m_iState
    mData.starttime = self.m_iStartTime
    mData.endtime = self.m_iEndTime
    mData.rewardendtime = self.m_iRewardEndTime
    mData.mode = self.m_iMode
    mData.rewardinfo = self.m_mRewardInfo
    return mData
end

function CHuodong:Load(mData)
    self:Dirty()
    mData = mData or {}
    self.m_iVersion = mData.version or 0
    self.m_iState = mData.state or GAMESTATE.END
    self.m_iStartTime = mData.starttime or 0
    self.m_iEndTime = mData.endtime or 0
    self.m_iRewardEndTime = mData.rewardendtime or 0
    self.m_iMode = mData.mode or 0
    self.m_mRewardInfo = mData.rewardinfo or {}
end

function CHuodong:AfterLoad()
    self:CheckState()
    self:TryRewardEnd()
end

function CHuodong:NeedSave()
    return true
end

function CHuodong:MergeFrom(mFromData)
    if not mFromData or not next(mFromData) then
        return false, "huodong iteminvest without data"
    end
    if self.m_iState ~= GAMESTATE.END and mFromData.state ~= GAMESTATE.END then
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

function CHuodong:NewHour(mNow)
    self:CheckState(mNow)
    self:TryRewardEnd(mNow)
end

function CHuodong:NewDay(mNow)
    self:TryRewardEnd(mNow)
    self:UpdateState(mNow)
end

function CHuodong:UpdateState(mNow)
    if not self:IsCanInvestReward() then return end
    local iTime = mNow and mNow.time or get_time()

    self:Dirty()
    for iPid, mInfo in pairs(self.m_mRewardInfo) do
        for iInvestId, mInvestInfo in pairs(mInfo) do
            local iInvestTime = mInvestInfo.invest_time
            local iInvestDay = self:GetInvestDay(iTime, iInvestTime)
            if iInvestDay <= 10 then
                for iDay=1,iInvestDay do
                    if not mInvestInfo.day_info[iDay] then
                        mInvestInfo.day_info[iDay] = ITEMSTATE.REWARD
                    end
                end
            end
        end

        --投资过,刷天在线玩家
        local oPlayer = global.oWorldMgr:GetOnlinePlayerByPid(iPid)
        if oPlayer then
            self:GS2CItemInvest(oPlayer)
        end
    end
end

function CHuodong:CheckState(mNow)
    local iTime = mNow and mNow.time or get_time()
    if self:GetGameState() == GAMESTATE.READY_OPEN then
        if self.m_iStartTime <= iTime then
            self:GameStart()
        elseif self.m_iStartTime - iTime  < 3600 then
            self:AddGameStartCb()
        end
    elseif self:GetGameState() == GAMESTATE.INVEST_START then
        if iTime < self.m_iStartTime then
            self:Dirty()
            self.m_iState = GAMESTATE.END
            return
        end

        if self.m_iEndTime <= iTime then
            self:GameEnd()
        elseif self.m_iEndTime - iTime < 3600 then
            self:AddGameEndCb()
        end
    end
end

function CHuodong:AddGameStartCb()
    self:DelTimeCb("GameItemInvestStart")
    self:AddTimeCb("GameItemInvestStart", (self.m_iStartTime - get_time()) * 1000, function()
        if self:GetGameState() == GAMESTATE.READY_OPEN then
            self:GameStart()
        end
    end)
end

function CHuodong:AddGameEndCb()
    self:DelTimeCb("GameItemInvestEnd")
    self:AddTimeCb("GameItemInvestEnd", (self.m_iEndTime - get_time())*1000, function()
        if self:GetGameState() == GAMESTATE.INVEST_START then 
            self:GameEnd() 
        end
    end)
end

function CHuodong:OnLogin(oPlayer,bReEnter)
    local iState = self:GetGameState()
    if self:IsCanInvestReward() then
        self:GS2CItemInvestState(oPlayer)
        self:GS2CItemInvest(oPlayer)
    end
end

function CHuodong:GetGameState()
    return self.m_iState
end

function CHuodong:RegisterHD(mInfo, bClose)
    if bClose then
        self:GameRewadEnd()
        record.warning(string.format("%s force gameend", self.m_sName)) 
    else
        local bIsOpen = global.oToolMgr:IsSysOpen("ITEMINVEST") 
        if not bIsOpen then
            return false, string.format("%s huodong config is close", self.m_sName)
        end

        if self:IsCanInvestReward() then
            return false, string.format("%s huodong is started", self.m_sName)
        end

        local sHDKey = mInfo.hd_key
        local iMode = 0
        if sHDKey == "new" then
            iMode = MODE.NEW
        elseif sHDKey == "old" then
            iMode = MODE.OLD
        end
        
        if iMode == 0 then
            return false, string.format("%s TryGameStart mode error", self.m_sName)
        end
        self:TryGameStart(mInfo, iMode)
    end
    return true
end

function CHuodong:TryGameStart(mInfo, iMode)
    self:Init()
    self:AdjustHDTime(mInfo)
    self.m_iStartTime = mInfo.start_time
    self.m_iEndTime = mInfo.end_time
    self.m_iRewardEndTime = mInfo.end_time + 10*24*3600
    self.m_iState = GAMESTATE.READY_OPEN
    self.m_iMode = iMode
    self:Dirty()

    --尝试开启
    self:CheckState()
end

function CHuodong:AdjustHDTime(mInfo)
    local mConfig = self:GetConfig()
    local iLimitDay = mConfig.gameday
    mInfo.start_time = mInfo.start_time or get_time()
    assert(iLimitDay>0, string.format("%s huodong need gameday error", self.m_sName))
    local iAdjustEndTime = self:CalEndTime(mInfo.start_time, iLimitDay)
    mInfo.end_time = iAdjustEndTime
end

function CHuodong:CalEndTime(iStartTime, iDay)
    local iTime = iStartTime + iDay * 24*60*60
    local date = os.date("*t",iTime)
    if date.hour>=5 then
        iTime = os.time({year=date.year, month=date.month, day=date.day, hour=5, min=0, sec=0})
    else
        iTime = iTime - 5*60*60
        date = os.date("*t",iTime)
        iTime = os.time({year=date.year, month=date.month, day=date.day, hour=5, min=0, sec=0})
    end
    return iTime
end

function CHuodong:GameStart(iMode,iGameDay)
    record.info(string.format("%s GameStart",self.m_sName))
    self:Dirty()
    self.m_iVersion = self.m_iVersion + 1
    self.m_iState = GAMESTATE.INVEST_START
    self:LogState()
    self:BroadcastState()
    global.oHotTopicMgr:Register(self.m_sName)
end

function CHuodong:TryRewardEnd(mNow)
    if self:GetGameState() == GAMESTATE.END then return end
    local iTime = mNow and mNow.time or get_time()
    if self.m_iRewardEndTime > 0 and iTime >= self.m_iRewardEndTime then
        self:GameRewadEnd()
    end
end

function CHuodong:GameEnd()
    record.info(string.format("%s GameEnd", self.m_sName))
    self:Dirty()
    self.m_iState = GAMESTATE.INVEST_END
    self:LogState()
    self:BroadcastState()
    global.oHotTopicMgr:UnRegister(self.m_sName)
end

function CHuodong:GameRewadEnd()
    record.info(string.format("%s GameRewardEnd", self.m_sName))
    self:Dirty()
    self.m_iState = GAMESTATE.END
    self:LogState()
    self:DealEndMail()
    self:BroadcastState()
    self:Init()
    global.oHotTopicMgr:UnRegister(self.m_sName)
end

function CHuodong:DealEndMail()
    local mConfig = self:GetConfig()
    local iMailId = mConfig.reward_mail_id

    local mItemConfig = self:GetItemConfig()
    for iPid, mInfo in pairs(self.m_mRewardInfo) do
        local lItemList = {}
        for iInvestId, mInvestInfo in pairs(mInfo) do
            local iAllNum = 0
            for iDay, iState in pairs(mInvestInfo.day_info or {}) do
                if iState == ITEMSTATE.REWARD then
                    local sDay = string.format("day%d", iDay)
                    local iNum = mItemConfig[iInvestId][sDay]
                    iAllNum = iAllNum + iNum
                end
            end

            if iAllNum > 0 then
                local iItem = self:InitRewardByItem(iPid, iInvestId, iAllNum)
                table.insert(lItemList, iItem)
            end
        end

        if #lItemList > 0 then
            self:SendMail(iPid, iMailId, { items = lItemList })
        end
    end
end

function CHuodong:InitRewardByItem(iPid, iInvestId, iAmount)
    local mItemConfig = self:GetItemConfig()
    local mInvestItem = mItemConfig[iInvestId]
    local iItem = mInvestItem.item
    local iBind = mInvestItem.bind
    local oItem = global.oItemLoader:ExtCreate(iItem, {})
    oItem:SetAmount(iAmount)
    if iBind == 1 then
        oItem:Bind(iPid)
    end
    return oItem
end

function CHuodong:C2GSItemInvest(oPlayer, iInvestId)
    if self:GetGameState() ~= GAMESTATE.INVEST_START then return end

    local mItemConfig = self:GetItemConfig()
    if not mItemConfig[iInvestId] then return end

    local iCost = mItemConfig[iInvestId].price
    local iItem = mItemConfig[iInvestId].item

    self:Dirty()
    local iPid = oPlayer:GetPid()
    if not self.m_mRewardInfo[iPid] then
        self.m_mRewardInfo[iPid] = {}
    end
    local mInfo = self.m_mRewardInfo[iPid]
    local mInvestInfo = mInfo[iInvestId]
    if not mInvestInfo then
        if not oPlayer:ValidTrueGoldCoin(iCost) then return end
        oPlayer:ResumeTrueGoldCoin(iCost, "道具投资")
        self:LogInvest(iPid, iInvestId, iItem, iCost)
        mInvestInfo = {
            invest_time = get_time(),
            day_info = {[1] = ITEMSTATE.REWARD}
        }
        self.m_mRewardInfo[iPid][iInvestId] = mInvestInfo
        self:GS2CItemInvestUnit(oPlayer, iInvestId)
    end
end

function CHuodong:C2GSItemInvestReward(oPlayer, iInvestId)
    if not self:IsCanInvestReward() then return end

    local iPid = oPlayer:GetPid()
    local mInfo = self.m_mRewardInfo[iPid]
    if not mInfo then return end
    
    local mInvestInfo = mInfo[iInvestId]
    if not mInvestInfo then return end

    self:Dirty()

    if not self:CheckBag(oPlayer, iInvestId) then
        global.oNotifyMgr:Notify(iPid, "背包空间不足，请先整理背包")
        return
    end

    for iDay, iState in pairs(mInvestInfo.day_info or {}) do
        if iState == ITEMSTATE.REWARD then
            self:InvestReward(oPlayer, iInvestId, iDay)
            mInvestInfo.day_info[iDay] = ITEMSTATE.REWARDED
        end
    end
    self:GS2CItemInvestUnit(oPlayer, iInvestId)
end

function CHuodong:C2GSItemInvestDayReward(oPlayer, iInvestId, iDay)
    if not self:IsCanInvestReward() then return end

    local iPid = oPlayer:GetPid()
    local mInfo = self.m_mRewardInfo[iPid]
    if not mInfo then return end
    
    local mInvestInfo = mInfo[iInvestId]
    if not mInvestInfo then return end

    self:Dirty()

    if mInvestInfo.day_info and mInvestInfo.day_info[iDay] == ITEMSTATE.REWARD then
        if not self:CheckBag(oPlayer, iInvestId, iDay) then
            global.oNotifyMgr:Notify(iPid, "背包空间不足，请先整理背包")
            return
        end

        self:InvestReward(oPlayer, iInvestId, iDay)
        mInvestInfo.day_info[iDay] = ITEMSTATE.REWARDED
        self:GS2CItemInvestUnit(oPlayer, iInvestId)
    end
end

function CHuodong:InvestReward(oPlayer, iInvestId, iDay)
    local mItem = self:GetItemConfig()
    local mInvestItem = mItem[iInvestId]
    assert(iDay>=1 and iDay<=10, string.format("%s huodong InvestReward investid = %d, day = %d", self.m_sName, iInvestId, iDay))
    local iItem = mInvestItem.item
    local iNum = mInvestItem[string.format("day%d", iDay)]
    local iBind = mInvestItem.bind
    local mArgs = {}
    if iBind == 1 then
        mArgs.bind = 1
    end
    oPlayer:RewardItems(iItem, iNum, "道具投资", mArgs)
    self:LogInvestReward(oPlayer:GetPid(), iInvestId, iItem, iNum, iDay)
end

function CHuodong:CheckBag(oPlayer, iInvestId, iDay)
    local iPid = oPlayer:GetPid()
    local mItem = self:GetItemConfig()
    local mInvestItem = mItem[iInvestId]
    local iItem = mInvestItem.item

    local iRewardNum = 0
    if iDay then
        local iNum = mInvestItem[string.format("day%d", iDay)]
        iRewardNum = iRewardNum + iNum
    else
        for iDay, iState in pairs(self.m_mRewardInfo[iPid][iInvestId].day_info or {}) do
            if iState == ITEMSTATE.REWARD then
                local iNum = mInvestItem[string.format("day%d", iDay)]
                iRewardNum = iRewardNum + iNum
            end
        end
    end

    local iMaxOverlay = self:GetMaxOverlay(iItem)
    local iNeedBagSpace = math.ceil(iRewardNum / iMaxOverlay)
    local iSize = oPlayer.m_oItemCtrl:GetCanUseSpaceSize()
    return iNeedBagSpace <= iSize
end

function CHuodong:GetMaxOverlay(iItem)
    local mData = res["daobiao"]["item"]
    local mItemData = mData[iItem]
    assert(mItemData,string.format("CHuodong %s GetMaxOverlay error",self.m_sName))
    return mItemData.maxOverlay
end

function CHuodong:BroadcastState()
    local mData = {
        state = self.m_iState,
        invest_endtime = self.m_iEndTime,
        reward_endtime = self.m_iRewardEndTime,
        mode = self.m_iMode,
    }
    interactive.Send(".broadcast", "channel", "SendChannel", {
        message = "GS2CItemInvestState",
        id = 1,
        type = gamedefines.BROADCAST_TYPE.WORLD_TYPE,
        data = mData,
        exclude = {},
    })
end

function CHuodong:GS2CItemInvestState(oPlayer)
    local mData = {
        state = self.m_iState,
        invest_endtime = self.m_iEndTime,
        reward_endtime = self.m_iRewardEndTime,
        mode = self.m_iMode,
    }
    oPlayer:Send("GS2CItemInvestState", mData)
end

function CHuodong:GS2CItemInvest(oPlayer)
    local iPid = oPlayer:GetPid()
    local mInfo = self.m_mRewardInfo[iPid] or {}
    local mData = {}
    for iInvestId, mInvestInfo in pairs(mInfo) do
        local mDayInfo = {}
        for iDay, iStatus in pairs(mInvestInfo.day_info or {}) do
            table.insert(mDayInfo, {day = iDay, status = iStatus})
        end
        local mTmp = {
            invest_id = iInvestId,
            day_info = mDayInfo
        }
        table.insert(mData, mTmp)
    end
    oPlayer:Send("GS2CItemInvest", {info = mData})
end

function CHuodong:GS2CItemInvestUnit(oPlayer, iInvestId)
    local iPid = oPlayer:GetPid()
    local mInfo = self.m_mRewardInfo[iPid]
    local mInvestInfo = mInfo[iInvestId]
    local mDayInfo = {}
    for iDay, iStatus in pairs(mInvestInfo.day_info or {}) do
        table.insert(mDayInfo, {day = iDay, status = iStatus})
    end
    local mData = {
        invest_id = iInvestId,
        day_info = mDayInfo,
    }
    oPlayer:Send("GS2CItemInvestUnit", mData)
end

function CHuodong:GetInvestDay(iCurTime, iInvestTime)
    local iDay = get_morningdayno(iCurTime) - get_morningdayno(iInvestTime) + 1
    assert(iDay>0, string.format("%s huodong GetInvestDay error", self.m_sName))
    return iDay
end

function CHuodong:LogState()
    local mLogData = {
        state = self:GetGameState(),
        version = self.m_iVersion,
        mode = self.m_iMode
    }
    record.log_db("huodong", "iteminvest_state", mLogData)
end

function CHuodong:LogInvest(iPid, iInvestId, iInvestItem, iInvestMoney)
    local mLogData = {
        pid = iPid, 
        invest_id = iInvestId,
        invest_item = iInvestItem,
        invest_money = iInvestMoney,
    }
    record.log_db("huodong", "iteminvest", mLogData)
end

function CHuodong:LogInvestReward(iPid, iInvestId, iInvestItem, iNum, iDay)
    local mLogData = {
        pid = iPid,
        invest_id = iInvestId,
        invest_item = iInvestItem,
        item_num = iNum,
        day = iDay,
    }
    record.log_db("huodong", "iteminvest_reward", mLogData)
end

function CHuodong:GetConfig()
    local mConfig = res["daobiao"]["huodong"][self.m_sName]["config"][1]
    assert(mConfig, string.format("%s huodong GetConfig error", self.m_sName))
    return mConfig
end

function CHuodong:GetItemConfig()
    local mConfig
    if self.m_iMode == MODE.NEW then
        mConfig = res["daobiao"]["huodong"][self.m_sName]["new_reward"]
    elseif self.m_iMode == MODE.OLD then
        mConfig = res["daobiao"]["huodong"][self.m_sName]["old_reward"]
    end
    assert(mConfig, string.format("%s huodong GetItemConfig error", self.m_sName))
    return mConfig
end

function CHuodong:IsHuodongOpen()
    return self:GetGameState() == GAMESTATE.INVEST_START
end

function CHuodong:IsCanInvestReward()
    return self:GetGameState() == GAMESTATE.INVEST_START or self:GetGameState() == GAMESTATE.INVEST_END
end

function CHuodong:TestOp(iFlag, mArgs)
    local oChatMgr = global.oChatMgr
    local oNotifyMgr = global.oNotifyMgr
    local oWorldMgr = global.oWorldMgr
    local pid = mArgs[#mArgs]
    local oPlayer = oWorldMgr:GetOnlinePlayerByPid(pid)
    self.m_iTestDay = nil
    local mCommand={
        "100 指令查看",
        "101 活动开始（1:新 2:老）\nhuodongop iteminvest 101  {mode=1}",
        "102 活动结束\nhuodongop iteminvest 102",
        "103 模拟投资\nhuodongop iteminvest 103 {id = 1}",
        "104 模拟领奖\nhuodongop iteminvest 104 {id = 1}",
        "105 模拟刷天 1表示当天\nhuodongop iteminvest 105 {day = 1}",
        "106 投资结束 \nhuodongop iteminvest 106",
    }
    if iFlag == 100 then
        for idx=#mCommand,1,-1 do
            oChatMgr:HandleMsgChat(oPlayer,mCommand[idx])
        end
        oNotifyMgr:Notify(pid,"请看消息频道咨询指令")
    elseif iFlag  == 101 then
        local iMode = mArgs.mode or 1
        local mInfo = {
            start_time = get_time(),
            hd_key = iMode == 1 and "new" or "old",
        }
        self:RegisterHD(mInfo, false)
        oNotifyMgr:Notify(pid,"开启成功")
    elseif iFlag == 102 then
        self:RegisterHD(nil, true)
        oNotifyMgr:Notify(pid,"关闭成功")
    elseif iFlag == 103 then
        local iInvestId = mArgs.id or 1
        self:C2GSItemInvest(oPlayer, iInvestId)
    elseif iFlag == 104 then
        local iInvestId = mArgs.id or 1
        self:C2GSItemInvestReward(oPlayer, iInvestId)
    elseif iFlag == 105 then
        local iDay = mArgs.day or 1
        iDay = iDay - 1
        local iTime = get_time() + iDay * 24 * 3600
        self:NewDay({time = iTime})
    elseif iFlag == 106 then
        if self:GetGameState() == GAMESTATE.INVEST_START then
            local iTime = get_time()
            self:Dirty()
            self.m_iEndTime = iTime
            self.m_iRewardEndTime = iTime + 10 * 24 * 3600
            self:DelTimeCb("GameItemInvestEnd")
            self:GameEnd()
            oNotifyMgr:Notify(pid,"投资结束")
        else
            oNotifyMgr:Notify(pid,"投资没开启,不可操作")
        end
    end
end