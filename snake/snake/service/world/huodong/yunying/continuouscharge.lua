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
CHuodong.m_sTempName = "连续充值"
inherit(CHuodong, huodongbase.CHuodong)

local NEW_MODE = 1 --新服模式
local OLD_MODE = 2 --老服模式

local GAME_START = 1
local GAME_NOSTART = 0
local GAME_READY_OPEN = 2

local STATE = {
    CHARGE = 1, --充值
    REWARD = 2, --可领取
    REWARDED = 3, --已领取
    OUTDATED = 4, --过时的
}

local TOTALSTATE = {
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
    self.m_iMode = 0
    self.m_iState = GAME_NOSTART
    self.m_mRewardInfo = {}
    self.m_mRewardRecord = {}
    self.m_mTotalRewardRecord = {}
    self.m_iTestDay = nil
end

function CHuodong:Save()
    local mData = {}
    mData.version = self.m_iVersion
    mData.state = self.m_iState
    mData.starttime = self.m_iStartTime
    mData.endtime = self.m_iEndTime
    mData.mode = self.m_iMode
    local mRewardInfo = {}
    for pid, mReward in pairs(self.m_mRewardInfo) do
        mRewardInfo[db_key(pid)]  = mReward
    end
    mData.rewardinfo = mRewardInfo
    return mData
end

function CHuodong:Load(mData)
    mData = mData or {}
    self.m_iVersion = mData.version or 0
    self.m_iState = mData.state or 0
    self.m_iStartTime = mData.starttime or 0
    self.m_iEndTime = mData.endtime or 0
    self.m_iMode = mData.mode or 0
    local mRewardInfo = {}
    for sPid, mReward in pairs(mData.rewardinfo or {}) do
        mRewardInfo[tonumber(sPid)]  = mReward
    end
    self.m_mRewardInfo = mRewardInfo
end

function CHuodong:AfterLoad()
    self:CheckState()
end

function CHuodong:NeedSave()
    return true
end

function CHuodong:MergeFrom(mFromData)
    if not mFromData or not next(mFromData) then
        return  false, "huodong continuouscharge without data"
    end
    if self.m_iMode ~= mFromData.mode then return true end
    if self.m_iState == GAME_START and mFromData.state == GAME_START then
        for sPid, mReward in pairs(mFromData.rewardinfo or {}) do
            self.m_mRewardInfo[tonumber[sPid]] = mReward
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
end

function CHuodong:CheckState(mNow)
    local iTime = mNow and mNow.time or get_time()
    if self:GetGameState() == GAME_READY_OPEN then
        if self.m_iStartTime <= iTime then
            self:GameStart()
        elseif self.m_iStartTime - iTime  < 3600 then
            self:AddGameStartCb()
        end
    elseif self:GetGameState() == GAME_START then
        if iTime < self.m_iStartTime then
            self.m_iState = GAME_NOSTART
            return
        end

        if self.m_iEndTime <= iTime then
            self:GameEnd()
        elseif self.m_iEndTime - iTime < 3600 then
            self:AddGameEndCb()
        end

        if self:GetGameState() == GAME_START and mNow and mNow.date.hour == 5 then
            self:RefreshAllPlayer()
        end
    end
end

function CHuodong:AddGameStartCb()
    self:DelTimeCb("GameTimeStart")
    self:AddTimeCb("GameTimeStart", (self.m_iStartTime - get_time()) * 1000, function()
        if self:GetGameState() == GAME_READY_OPEN then
            self:GameStart()
        end
    end)
end

function CHuodong:AddGameEndCb()
    self:DelTimeCb("GameTimeEnd")
    self:AddTimeCb("GameTimeEnd", (self.m_iEndTime - get_time())*1000, function()
        if self:GetGameState() == GAME_START then 
            self:GameEnd() 
        end
    end)
end

function CHuodong:OnLogin(oPlayer,bReEnter)
    if self:GetGameState() == GAME_START then
        self:UpdateState(oPlayer:GetPid())
        self:GS2CGameStart(oPlayer)
        self:GS2CGameReward(oPlayer)
    end
end

function CHuodong:GetGameState(bNewDay)
    return self.m_iState
end

function CHuodong:GetEndTime()
    return self.m_iEndTime
end

function CHuodong:RegisterHD(mInfo, bClose)
    if bClose then
        self:GameEnd()
        record.warning(string.format("%s force gameend", self.m_sName)) 
    else
        local bIsOpen = global.oToolMgr:IsSysOpen("CONTINUOUS_CHARGE") 
        if not bIsOpen then
            return false, string.format("%s huodong config is close", self.m_sName)
        end

        if self:GetGameState() == GAME_START then
            return false, string.format("%s huodong is started", self.m_sName)
        end

        local sHDKey = mInfo.hd_key
        local iMode = 0
        if sHDKey == "new" then
            iMode = 1
        elseif sHDKey == "old" then
            iMode = 2
        end
           
        if iMode == 0 then
            return false, string.format("%s TryGameStart mode error", self.m_sName)
        end

        self:TryGameStart(mInfo, iMode)
    end
    return true
end

--运营开启活动接口
function CHuodong:TryGameStart(mInfo, iMode)
    self:Init()
    self:AdjustHDTime(mInfo)
    self.m_iStartTime = mInfo.start_time
    self.m_iEndTime = mInfo.end_time
    self.m_iState = GAME_READY_OPEN
    self.m_iMode = iMode

    self:Dirty()
    if self.m_iStartTime <= get_time() then         
        self:GameStart()
    elseif self.m_iStartTime - get_time() < 3600 then      
        self:AddGameStartCb()
    end
end

function CHuodong:AdjustHDTime(mInfo)
    local iLimitDay = self:GetGameDay()
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

function CHuodong:GameStart()
    record.info(string.format("%s GameStart",self.m_sName))
    self:Dirty()
    self.m_iVersion = self.m_iVersion + 1
    self.m_iState = GAME_START
    self:LogState()
    self:RefreshAllPlayer()
    global.oHotTopicMgr:Register(self.m_sName)
end

function CHuodong:RefreshAllPlayer()
    local func = function(pid)
        local oPlayer = global.oWorldMgr:GetOnlinePlayerByPid(pid)
        if not oPlayer then return end
        self:UpdateState(oPlayer:GetPid())
        self:GS2CGameStart(oPlayer)
        self:GS2CGameReward(oPlayer)
    end
    local lAllOnlinePid = table_key_list(global.oWorldMgr:GetOnlinePlayerList())
    global.oToolMgr:ExecuteList(lAllOnlinePid, 100, 1000, 0, "ContinuousChargeRefresh", func)
end

function CHuodong:UpdateState(iPid)
    self:Dirty()
    if not self.m_mRewardInfo[iPid] then
        self.m_mRewardInfo[iPid] = {
            state = {},
            totalstate = {},
            charge = {},
            choice = {},
            totalchoice = {}
        }
    end
    self:UpdateRewardState(iPid)
    self:UpdateTotalState(iPid)
end

function CHuodong:UpdateRewardState(iPid)
    local oPlayer = global.oWorldMgr:GetOnlinePlayerByPid(iPid)
    if not oPlayer then return end

    local iCurDay = self:GetCurDay()
    local mConfig = self:GetRewardConfig()
    assert(mConfig and mConfig[iCurDay], string.format("%s huodong error, day %d", self.m_sName, iCurDay))
    local iNeedGoldCoin = mConfig[iCurDay].glodcoin
    local iTodayGoldCoin = oPlayer.m_oTodayMorning:Query(gamedefines.TODAY_PAY_GOLDCOIN, 0)

    local mState = self.m_mRewardInfo[iPid].state
    if not mState[iCurDay] then
        mState[iCurDay] = STATE.CHARGE
    end

    --today
    if iTodayGoldCoin >= iNeedGoldCoin and mState[iCurDay] == STATE.CHARGE then
        mState[iCurDay] = STATE.REWARD
    end

    --before
    for iDay, _ in pairs(mConfig) do
        if iDay < iCurDay and (not mState[iDay] or mState[iDay] == STATE.CHARGE ) then
            mState[iDay] = STATE.OUTDATED
        end
    end
end

function CHuodong:UpdateTotalState(iPid)
    local oPlayer = global.oWorldMgr:GetOnlinePlayerByPid(iPid)
    if not oPlayer then return end

    local iCurDay = self:GetCurDay()
    local mConfig = self:GetTotalRewardConfig()
    local mRewardConfig = self:GetRewardConfig()

    local mCharge = self.m_mRewardInfo[iPid].charge
    local mState = self.m_mRewardInfo[iPid].totalstate

    local iTodayGoldCoin = oPlayer.m_oTodayMorning:Query(gamedefines.TODAY_PAY_GOLDCOIN, 0)
    mCharge[iCurDay] = iTodayGoldCoin
    
    local iGoldCoin = 0
    local iChargeDay = 0
    for iDay, iCharge in pairs(mCharge) do
        iGoldCoin = iGoldCoin + iCharge
        if iCharge >= mRewardConfig[iDay].glodcoin then
            iChargeDay = iChargeDay + 1
        end
    end

    for iTotalDay, mInfo in pairs(mConfig) do
        if not mState[iTotalDay] and iChargeDay >= iTotalDay and iGoldCoin >= mInfo.glodcoin then
            mState[iTotalDay] = TOTALSTATE.REWARD
        end
    end
end

function CHuodong:GetGameDay()
    local iGameDay = res["daobiao"]["huodong"][self.m_sName]["config"][1]["gameday"]
    return  iGameDay or 7
end

function CHuodong:GameEnd()
    record.info(string.format("%s GameEnd", self.m_sName))
    global.oHotTopicMgr:UnRegister(self.m_sName)
    self:Dirty()
    self:DealEndMail()
    self:LogState()
    self:Init()
    self:GS2CGameEnd()
end

function CHuodong:DealEndMail()
    local mConfig = self:GetConfig()
    local iRewardMailId = mConfig.reward_mail_id
    local iTotalMailId = mConfig.total_mail_id

    for iPid, mInfo in pairs(self.m_mRewardInfo) do
        local lItemList = {}
        local mState = mInfo.state or {}
        local mTotalState = mInfo.totalstate or {}

        for iDay, iState in pairs(mState) do
            if iState == STATE.REWARD then
                local lSlots = self.m_mRewardInfo[iPid].choice[iDay] or {}
                local lRewardIndex = self:GetRewardIndex(iDay, lSlots, false)
                for _, iRewardIdx in ipairs(lRewardIndex) do
                    local lItems = self:GetScoreRewardItemByIdx(iPid, iRewardIdx)
                    list_combine(lItemList, lItems)
                end
            end
        end

        if #lItemList > 0 then
            self:SendMail(iPid, iRewardMailId, { items = lItemList })
        end

        lItemList = {}
        for iDay, iState in pairs(mTotalState) do
            if iState == TOTALSTATE.REWARD then
                local lSlots = self.m_mRewardInfo[iPid].totalchoice[iDay] or {}
                local lRewardIndex = self:GetRewardIndex(iDay, lSlots, true)
                for _, iRewardIdx in ipairs(lRewardIndex) do
                    local lItems = self:GetScoreRewardItemByIdx(iPid, iRewardIdx)
                    list_combine(lItemList, lItems)
                end
            end
        end

        if #lItemList > 0 then
            self:SendMail(iPid, iTotalMailId, { items = lItemList })
        end
    end
end

function CHuodong:GetScoreRewardItemByIdx(iPid, iRewardIdx)
    local lItems = {}
    local mReward = self:GetRewardData(iRewardIdx)
    local mItems  = mReward.item
    for _, iItemRewardIdx in ipairs(mItems) do
        local mRewardInfo = self:GetItemRewardData(iItemRewardIdx)
        if mRewardInfo then
            local mItemInfo = self:ChooseRewardKey(oPlayer, mRewardInfo, iItemRewardIdx, {})
            if mItemInfo then
                local iteminfo = self:InitRewardByItemUnitOffline(iPid,iItemRewardIdx,mItemInfo)
                list_combine(lItems, iteminfo["items"])
            end
        end
    end
    return lItems
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

function CHuodong:GetCurDay()
    if self.m_iTestDay then
        return self.m_iTestDay
    end
    return get_morningdayno() - get_morningdayno(self.m_iStartTime) + 1
end

--充值时调用
function CHuodong:CheckReward(oPlayer, sProductKey)
    local oNotifyMgr = global.oNotifyMgr
    local iPid = oPlayer:GetPid()
    if self:GetGameState() ~= GAME_START then return end
    -- local bIsOpen = global.oToolMgr:IsSysOpen("CONTINUOUS_CHARGE", oPlayer, true) 
    -- if not bIsOpen then return end

    if sProductKey then
        local mPayData = res["daobiao"]["pay"][sProductKey]
        if mPayData["func"] ~= "pay_for_gold" then
            return
        end
    end
    self:UpdateState(iPid)
    self:GS2CGameReward(oPlayer)
end

function CHuodong:GS2CGameStart(oPlayer)
    local mNet = {
        starttime = self.m_iStartTime,
        endtime = self:GetEndTime(),
        mode = self.m_iMode,
    }
    oPlayer:Send("GS2CContinuousChargeStart",mNet)
end

function CHuodong:GS2CGameEnd()
    interactive.Send(".broadcast", "channel", "SendChannel", {
        message = "GS2CContinuousChargeEnd",
        id = 1,
        type = gamedefines.BROADCAST_TYPE.WORLD_TYPE,
        data = {},
        exclude = {},
    })
end

function CHuodong:GS2CGameReward(oPlayer)
    local mNet = {
        curday = self:GetCurDay(),
        curgoldcoin = oPlayer.m_oTodayMorning:Query(gamedefines.TODAY_PAY_GOLDCOIN, 0),
        totalcoldcoin = self:GetTotalGoldCoin(oPlayer),
        states = self:GetRewardState(oPlayer, false),
        totalstates = self:GetRewardState(oPlayer, true),
        choice = self:GetChoice(oPlayer, false),
        totalchoice = self:GetChoice(oPlayer, true)
    }
    oPlayer:Send("GS2CContinuousChargeReward", mNet)
end

function CHuodong:GetTotalGoldCoin(oPlayer)
    local iGoldCoin = 0
    local iPid = oPlayer:GetPid()
    if self.m_mRewardInfo[iPid] then
        local mCharge = self.m_mRewardInfo[iPid].charge or {}
        for _, iCharge in pairs(mCharge) do
            iGoldCoin = iGoldCoin + iCharge
        end
    end
    return iGoldCoin
end

function CHuodong:GetRewardState(oPlayer, bIsTotal)
    local lState = {}
    local iPid = oPlayer:GetPid()
    if self.m_mRewardInfo[iPid] then
        local mState = self.m_mRewardInfo[iPid].state or {}
        if bIsTotal then
            mState = self.m_mRewardInfo[iPid].totalstate or {}
        end
        for iDay, iState in pairs(mState) do
            table.insert(lState, {day = iDay, state = iState})
        end
    end
    return lState
end

function CHuodong:GetChoice(oPlayer, bIsTotal)
    local lChoice = {}
    local iPid = oPlayer:GetPid()
    if self.m_mRewardInfo[iPid] then
        local mChoice = self.m_mRewardInfo[iPid].choice or {}
        if bIsTotal then
            mChoice = self.m_mRewardInfo[iPid].totalchoice or {}
        end
        for iDay, mInfo in pairs(mChoice) do
            for iSlot, iIndx in pairs (mInfo or {}) do
                local mTmp = {
                    day = iDay,
                    slot = iSlot,
                    index = iIndx
                }
                table.insert(lChoice, mTmp)
            end
        end
    end
    return lChoice
end

function CHuodong:C2GSContinuousChargeSetChoice(oPlayer, mData)
    if self:GetGameState() ~= GAME_START then return end

    local iPid = oPlayer:GetPid()
    local mChoice = self.m_mRewardInfo[iPid].choice
    if mData.type == 2 then
        mChoice = self.m_mRewardInfo[iPid].totalchoice
    end
    if not mChoice[mData.day]  then
        mChoice[mData.day] = {}
    end
    mChoice[mData.day][mData.slot] = mData.index
    self:GS2CGameReward(oPlayer)
end

function CHuodong:C2GSContinuousChargeReward(oPlayer, iDay)
    if self:GetGameState() ~= GAME_START then return end

    local iPid = oPlayer:GetPid()
    local iSize = oPlayer.m_oItemCtrl:GetCanUseSpaceSize()
    local iCount = self:GetRewardCount(iDay, false)
    if iSize < iCount then
        global.oNotifyMgr:Notify(iPid, self:GetTextData(1004))
        return
    end

    local lSlots = self.m_mRewardInfo[iPid].choice[iDay] or {}
    local mPlayerInfo = self.m_mRewardInfo[iPid]
    if mPlayerInfo and mPlayerInfo.state and mPlayerInfo.state[iDay] == STATE.REWARD then
        self:Dirty()
        self.m_mRewardInfo[iPid].state[iDay] = STATE.REWARDED
        self:DoReward(oPlayer, iDay, lSlots)
        self:GS2CGameReward(oPlayer)
    end
end

function CHuodong:C2GSContinuousChargeTotalReward(oPlayer, iDay)
    if self:GetGameState() ~= GAME_START then return end

    local iPid = oPlayer:GetPid()
    local iSize = oPlayer.m_oItemCtrl:GetCanUseSpaceSize()
    local iCount = self:GetRewardCount(iDay, true)
    if iSize < iCount then
        global.oNotifyMgr:Notify(iPid, self:GetTextData(1004))
        return
    end

    local lSlots = self.m_mRewardInfo[iPid].totalchoice[iDay] or {}
    local mPlayerInfo = self.m_mRewardInfo[iPid]
    if mPlayerInfo and mPlayerInfo.totalstate and mPlayerInfo.totalstate[iDay] == TOTALSTATE.REWARD then
        self:Dirty()
        self.m_mRewardInfo[iPid].totalstate[iDay] = TOTALSTATE.REWARDED
        self:DoTotalReward(oPlayer, iDay, lSlots)
        self:GS2CGameReward(oPlayer)
    end
end

function CHuodong:DoReward(oPlayer, iDay, lSlots)
    local iPid = oPlayer:GetPid()
    self.m_mRewardRecord[iPid] = {}
    local lRewardIndex = self:GetRewardIndex(iDay, lSlots, false)
    for _, iRewardIdx in ipairs(lRewardIndex) do
        self:Reward(iPid, iRewardIdx, {is_total = false})
    end
    self:LogReward(oPlayer, iDay, false)
end

function CHuodong:DoTotalReward(oPlayer, iDay, lSlots)
    local iPid = oPlayer:GetPid()
    self.m_mTotalRewardRecord[iPid] = {}
    local lRewardIndex = self:GetRewardIndex(iDay, lSlots, true)
    for _, iRewardIdx in ipairs(lRewardIndex) do
        self:Reward(iPid, iRewardIdx, {is_total = true})
    end
    self:LogReward(oPlayer, iDay, true)
end

function CHuodong:GetRewardCount(iDay, bIsTotal)
    local iCount = 0
    local mData = bIsTotal and self:GetTotalRewardConfig() or self:GetRewardConfig()
    local mReward = mData[iDay] or {}
    for i=1, 5 do 
        local sSlot = string.format("slot%d", i)
        if mReward[sSlot] and #mReward[sSlot] > 0 then
            iCount = iCount + 1
        end
    end
    return iCount
end

function CHuodong:RewardItems(oPlayer, mAllItems, mArgs)
    if mArgs then
        for _, mData in pairs(mAllItems) do
            local iPid = oPlayer:GetPid()
            local mInfo = mData["info"]
            for _, oItem in ipairs(mData["items"]) do
                local mReward = { id=oItem:SID(), amount=oItem:GetAmount() }
                if mArgs.is_total then
                    table.insert(self.m_mTotalRewardRecord[iPid], mReward)
                else
                    table.insert(self.m_mRewardRecord[iPid], mReward)
                end
            end
        end
    end
    super(CHuodong).RewardItems(self,oPlayer, mAllItems, mArgs)
end

function CHuodong:GetRewardIndex(iDay, lSlots, bIsTotal)
    local lRewardIndex = {}
    local mData = bIsTotal and self:GetTotalRewardConfig() or self:GetRewardConfig()
    local mDayData = mData[iDay] or {}

    local mTmp = {}
    for iSlot, iIndex in pairs(lSlots) do
        local sName = string.format("slot%s", iSlot)
        if mDayData[sName] and #mDayData[sName] >= iIndex then
            local iRewardIdx = mDayData[sName][iIndex]
            table.insert(lRewardIndex, iRewardIdx)
            mTmp[sName] = true
        end
    end

    for sSlot, lSlotReward in pairs(mDayData) do
        if string.find(sSlot,"slot") and not mTmp[sSlot] and #lSlotReward > 0 then
            table.insert(lRewardIndex, lSlotReward[1])
        end
    end
    return lRewardIndex
end

function CHuodong:LogState()
    local mLogData = {
        state = self:GetGameState(),
        version = self.m_iVersion,
        mode = self.m_iMode
    }
    record.log_db("huodong", "continuouscharge_state", mLogData)
end

function CHuodong:LogReward(oPlayer, iDay, bIsTotal)
    local iPid = oPlayer:GetPid()
    local lReward = bIsTotal and self.m_mTotalRewardRecord[iPid] or self.m_mRewardRecord[iPid]
    assert(lReward, string.format("%s huodong reward is empty", self.m_sName))
    local sReward = extend.Table.serialize(lReward)
    local mLogData = {
        pid = iPid,
        version = self.m_iVersion,
        mode = self.m_iMode,
        day = iDay,
        reward = sReward,
    }
    local sStr = bIsTotal and "continuouscharge_totalreward" or "continuouscharge_reward"
    record.log_db("huodong", sStr, mLogData)
end

function CHuodong:GetConfig()
    return res["daobiao"]["huodong"][self.m_sName]["config"][1]
end

function CHuodong:GetRewardConfig()
    if self.m_iMode == NEW_MODE then
        return res["daobiao"]["huodong"][self.m_sName]["new_reward"]
    elseif self.m_iMode == OLD_MODE then
        return res["daobiao"]["huodong"][self.m_sName]["old_reward"]
    end
end

function CHuodong:GetTotalRewardConfig()
    if self.m_iMode == NEW_MODE then
        return res["daobiao"]["huodong"][self.m_sName]["new_total_reward"]
    elseif self.m_iMode == OLD_MODE then
        return res["daobiao"]["huodong"][self.m_sName]["old_total_reward"]
    end
end

function CHuodong:IsHuodongOpen()
    if self:GetGameState() == GAME_START then
        return true
    else
        return false
    end
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
        "101 活动开始（1:新 2:老）\nhuodongop continuouscharge 101  {mode=1}",
        "102 活动结束\nhuodongop continuouscharge 102",
        "103 调整到第几天\nhuodongop continuouscharge 103 {day = 2}",
        "104 调整时间到活动结束前Ｎ秒\nhuodongop continuouscharge 10４ {sec = 10}",
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
        local iDay = mArgs.day or 1
        if iDay < 1 or iDay > 7 then
            oNotifyMgr:Notify(pid,"失败，设置的天数超过了活动天数")
            return 
        end
        self.m_iTestDay = iDay
        if self:GetGameState() == GAME_START then
            oPlayer.m_oTodayMorning:Delete(gamedefines.TODAY_PAY_GOLDCOIN, 0)
            self:UpdateState(oPlayer:GetPid())
            self:GS2CGameStart(oPlayer)
            self:GS2CGameReward(oPlayer)
        end
    elseif iFlag == 104 then
        local iSec = mArgs.sec or 30
        if self:GetGameState() == GAME_START then
            local iEndTime = self:GetEndTime()
            local iNewEndTime = get_time() + iSec
            self.m_iEndTime = iNewEndTime
            self:GS2CGameStart(oPlayer)
            self:GS2CGameReward(oPlayer)
            self:NewHour()
            oNotifyMgr:Notify(pid, iSec .. "秒后活动结束")
        else
            oNotifyMgr:Notify(pid,"失败，活动没开")
        end
    end
end