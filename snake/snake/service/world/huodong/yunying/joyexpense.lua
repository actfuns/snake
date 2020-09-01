local global = require "global"
local res = require "base.res"
local record = require "public.record"
local extend = require "base.extend"

local gamedefines = import(lualib_path("public.gamedefines"))
local huodongbase = import(service_path("huodong.huodongbase"))

function NewHuodong(sHuodongName)
    return CHuodong:New(sHuodongName)
end

-- 商城消费奖励的领取状态
local STATE_UNREACH = 0     --未达到
local STATE_REWARD = 1      --可领取
local STATE_REWARDED = 2    --已经领取
-- 活动的开启状态
local GAME_CLOSE = 0
local GAME_OPEN = 1
local GAME_READY_OPEN = 2


CHuodong = {}
CHuodong.__index = CHuodong
CHuodong.m_sTempName = "欢乐返利"
inherit(CHuodong, huodongbase.CHuodong)

function CHuodong:New(sHuodongName)
    local o = super(CHuodong).New(self, sHuodongName)
    o:Init()
    return o
end

function CHuodong:Init()
    self.m_mRewardInfo = {}
    self.m_iHDID = 0
    self.m_sHD2RewardKey = ""
    self.m_iStartTime = 0
    self.m_iEndTime = 0
    self.m_iState = 0
end

function CHuodong:NeedSave()
    return true
end

function CHuodong:Save()
    local mData = {}
    mData.hd_id = self.m_iHDID
    mData.hd_key = self.m_sHD2RewardKey
    mData.start_time = self.m_iStartTime
    mData.end_time = self.m_iEndTime
    mData.state = self.m_iState
    local mSaveInfo = {}
    for pid, mPlayerRewardInfo in pairs(self.m_mRewardInfo) do 
        mSaveInfo[db_key(pid)] = mPlayerRewardInfo
    end
    mData.reward_info = mSaveInfo
    return mData
end

function CHuodong:Load(mData)
    mData = mData or {}
    self.m_iHDID = mData.hd_id
    self.m_sHD2RewardKey = mData.hd_key
    self.m_iStartTime = mData.start_time
    self.m_iEndTime = mData.end_time
    self.m_iState = mData.state
    mData.reward_info = mData.reward_info or {}
    for sPid, mPlayerRewardInfo in pairs(mData.reward_info) do
        self.m_mRewardInfo[tonumber(sPid)] = mPlayerRewardInfo
    end
end

function CHuodong:MergeFrom(mFromData)
    if not mFromData or not next(mFromData) then
        return false, "huodong joyexpense without data"
    end
    if self.m_iState == GAME_OPEN and mFromData.state == GAME_OPEN then
        for sPid, mPlayerRewardInfo in pairs(mFromData.reward_info or {}) do
            self.m_mRewardInfo[tonumber(sPid)] = mPlayerRewardInfo
        end
        self:Dirty()
    end
    return true
end

function CHuodong:RegisterHD(mInfo,bClose)
    if bClose then
        self:TryGameClose()
    else
        local bSucc, sError = self:CheckRegisterInfo(mInfo)
        if not bSucc then
            return false,sError
        end
        self:TryGameOpen(mInfo)
    end
    return true
end

function CHuodong:CheckRegisterInfo(mInfo)
    if not global.oToolMgr:IsSysOpen("REBATEJOY", nil, true) then
        return false, "system closed"
    end
    if mInfo["hd_type"] ~= self.m_sName then
        return false, "no hd_type" .. mInfo["hd_type"]
    end
    local sHDkey = mInfo["hd_key"]
    if not sHDkey then
        return false, "no hd_key" .. mInfo["hd_key"]
    end
    local mConfig = res["daobiao"]["huodong"][self.m_sName]["config"][sHDkey]
    if not mConfig then
        return false, "no hd config"
    end
    if not mInfo["end_time"] or mInfo["end_time"] <= get_time() then
        return false, "end time error"
    end
    if not mInfo["start_time"] or mInfo["start_time"] >= mInfo["end_time"] then
        return false, "start time error"
    end

    local mOpenDate = os.date("*t", mInfo["start_time"])
    local mCloseDate = os.date("*t",mInfo["end_time"])
    if mCloseDate.hour > 5 then
        mInfo["end_time"] = mInfo["end_time"] + 24 * 3600
    elseif mCloseDate.hour == 5  then
        if mCloseDate.min > 0 or mCloseDate.sec > 0 then
            mInfo["end_time"] = mInfo["end_time"] + 24 * 3600
        end
    end
    mCloseDate = os.date("*t",mInfo["end_time"])
    mCloseDate.hour = 5
    mCloseDate.min = 0
    mCloseDate.sec = 0
    mInfo["end_time"] = os.time(mCloseDate)
    return true
end

function CHuodong:TryGameClose()
    self:GameEnd()
end

function CHuodong:TryGameOpen(mInfo)
    if mInfo["hd_id"] ~= self.m_iHDID then
        -- 可以先尝试关闭活动
        self.m_iHDID = mInfo["hd_id"]
        self.m_sHD2RewardKey = mInfo["hd_key"]
        self.m_mRewardInfo = {}
    end

    self.m_iStartTime = mInfo["start_time"]
    self.m_iEndTime = mInfo["end_time"]
    self.m_iState = GAME_READY_OPEN
    self:Dirty()

    local mNow = get_timetbl()
    if self.m_iStartTime <= mNow.time then
        self:GameStart()
    elseif self.m_iStartTime - mNow.time <= 3600 then
        self:DelTimeCb("GameTimeStart")
        self:AddTimeCb("GameTimeStart", (self.m_iStartTime - mNow.time) * 1000, function()
            self:DelTimeCb("GameTimeStart")
            if self.m_iState ~= GAME_READY_OPEN then return end
            self:GameStart()
        end)
    end
end

function CHuodong:GameStart()
    self.m_iState = GAME_OPEN
    self:Dirty()
    local mLogData = {}
    mLogData.state = self.m_iState
    mLogData.hd_id = self.m_iHDID
    mLogData.reward_group_key = self.m_sHD2RewardKey
    record.log_db("huodong","joyexpense_state",{info =  mLogData})

    local lAllOnlinePid = {}
    for _, oPlayer  in pairs(global.oWorldMgr:GetOnlinePlayerList()) do
        if global.oToolMgr:IsSysOpen("REBATEJOY", oPlayer, true) then
            table.insert(lAllOnlinePid, oPlayer:GetPid())
        end
    end
    global.oToolMgr:ExecuteList(lAllOnlinePid,500, 500, 0, "JoyexpenseGameStart", function(pid)
        local oPlayer = global.oWorldMgr:GetOnlinePlayerByPid(pid)
        if not oPlayer then return end
        self:GS2CJoyExpenseState(oPlayer)
        end)
    global.oHotTopicMgr:Register(self.m_sName)
    record.info("huodong yunying joyexpense game start %d, %s",self.m_iHDID, self.m_sHD2RewardKey)
end

function CHuodong:GameEnd()
    self.m_iState = GAME_CLOSE
    self:CheckSendMailReward()
    self:Dirty()
    local mLogData = {}
    mLogData.state = self.m_iState
    mLogData.hd_id = self.m_iHDID
    mLogData.reward_group_key = self.m_sHD2RewardKey
    record.log_db("huodong", "joyexpense_state", {info = mLogData})
    local lAllOnlinePid = {}
    for _, oPlayer in pairs(global.oWorldMgr:GetOnlinePlayerList()) do
        if global.oToolMgr:IsSysOpen("REBATEJOY", oPlayer, true) then
            table.insert(lAllOnlinePid, oPlayer:GetPid())
        end
    end
    global.oToolMgr:ExecuteList(lAllOnlinePid, 500,500, 0, "JoyexpenseGameEnd", function(pid)
        local oPlayer = global.oWorldMgr:GetOnlinePlayerByPid(pid)
        if not oPlayer then return end
        self:GS2CJoyExpenseState(oPlayer)
        end)
    global.oHotTopicMgr:UnRegister(self.m_sName)
    record.info("huodong yunying joyexpense game end %d, %s", self.m_iHDID, self.m_sHD2RewardKey)
end

function CHuodong:GetGameState()
    return self.m_iState
end

function CHuodong:OnUpgrade(oPlayer, iFromGrade, iGrade)
    if self.m_iState == GAME_OPEN then
        local iOpenGrade = global.oToolMgr:GetSysOpenPlayerGrade("REBATEJOY")
        if iFromGrade < iOpenGrade and iGrade >= iOpenGrade then
            self:GS2CJoyExpenseState(oPlayer)
            self:GS2CJoyExpenseRewardState(oPlayer)
            self:GS2CJoyExpenseGoldCoin(oPlayer)
            self:DelUpgradeEvent(oPlayer)
        end
    end
end


function CHuodong:OnLogin(oPlayer, bReEnter)
    local oToolMgr = global.oToolMgr
    local iOpenGrade = oToolMgr:GetSysOpenPlayerGrade("REBATEJOY")
    if oToolMgr:IsSysOpen("REBATEJOY", nil, true) then
        if oPlayer:GetGrade() < iOpenGrade then
            self:AddUpgradeEvent(oPlayer)
            return
        end
    end

    if not oToolMgr:IsSysOpen("REBATEJOY", nil, true) then return end
    if self.m_iState == GAME_OPEN then
        self:GS2CJoyExpenseState(oPlayer)
        self:GS2CJoyExpenseRewardState(oPlayer)
        self:GS2CJoyExpenseGoldCoin(oPlayer)
    end
end

function CHuodong:GS2CJoyExpenseState(oPlayer)
    local mNet = {}
    mNet.state = self:GetGameState()
    mNet.end_time = self.m_iEndTime
    mNet.mode_id = self:GetRewardMode()
    oPlayer:Send("GS2CJoyExpenseState",mNet)
end

function CHuodong:GS2CJoyExpenseRewardState(oPlayer)
    local mNet = {}
    mNet.reward_list = {}
    local mPlayerReward = self:GetPlayerRewardInfo(oPlayer)
    for id, mExpenseReward in pairs(mPlayerReward) do
        table.insert(mNet.reward_list, { expense_id = id, reward_state = mExpenseReward.state })
    end
    oPlayer:Send("GS2CJoyExpenseRewardState",mNet)
end

function CHuodong:GS2CJoyExpenseGoldCoin(oPlayer)
    local mNet = {}
    mNet.goldcoin = self:QueryJoExpenseGoldCoin(oPlayer)
    oPlayer:Send("GS2CJoyExpenseGoldCoin", mNet)
end

function CHuodong:C2GSJoyExpenseGetReward(oPlayer, iExpenseKey)
    self:GetReward(oPlayer, iExpenseKey)
end

function CHuodong:C2GSJoyExpenseBuyGood(oPlayer, iShop, iGood, iMoneyType, iAmount)
    if iShop ~= self:GetShopID() then
        return
    end
    -- 目前都是元宝
    if iMoneyType ~= gamedefines.MONEY_TYPE.TRUE_GOLDCOIN then
        return
    end
    local oShop = global.oShopMgr:GetShop(iShop)
    if not oShop then return end
    local iCost = oShop:GetBuyCost(iGood, iAmount, iMoneyType)
    if iCost <= 0 then return end
    local bSucc = oShop:DoBuy(oPlayer, iGood, iAmount, iMoneyType)
    if not bSucc then return end
    self:AddJoyExpenseGoldcoin(oPlayer, iCost)
end

function CHuodong:QueryJoExpenseGoldCoin(oPlayer)
    return oPlayer.m_oTodayMorning:Query("joyexpenseshop_goldcoin",0)
end

function CHuodong:AddJoyExpenseGoldcoin(oPlayer, iCost)
    if iCost <=0 then return end
    local iToDayGoldCoinExpense = self:QueryJoExpenseGoldCoin(oPlayer)
    iToDayGoldCoinExpense = iToDayGoldCoinExpense + iCost
    oPlayer.m_oTodayMorning:Set("joyexpenseshop_goldcoin", iToDayGoldCoinExpense)
    self:GS2CJoyExpenseGoldCoin(oPlayer)
    self:CheckReward(oPlayer)
end

function CHuodong:CheckReward(oPlayer)
    if self.m_iState ~= GAME_OPEN then
        return
    end
    local mRewardConfig = self:GetRewardConfig()
    if not mRewardConfig then return end
    local pid = oPlayer:GetPid()
    local iToDayGoldCoinExpense = self:QueryJoExpenseGoldCoin(oPlayer)
    local bIsHasReward = false
    for  _, mData in ipairs(mRewardConfig) do
        local iPlayerExpense = mData.expense
        local iExpenseKey = mData.id
        if iToDayGoldCoinExpense >= iPlayerExpense then
            local mPlayerReward = self:GetPlayerRewardInfo(oPlayer)
            if not mPlayerReward[iExpenseKey] then
                mPlayerReward[iExpenseKey] = {}
                mPlayerReward[iExpenseKey].state = STATE_REWARD
                self:Dirty()
                bIsHasReward = true
                local mLogData = {}
                mLogData.pid = pid
                mLogData.hd_id = self.m_iHDID
                mLogData.reward_group_key = self.m_sHD2RewardKey
                mLogData.expense = iPlayerExpense
                record.log_db("huodong","joyexpense_reward",{pid = pid , info = mLogData})
            end
        end
    end
    if bIsHasReward then
        self:GS2CJoyExpenseRewardState(oPlayer)
    end
end

function CHuodong:GetPlayerRewardInfo(oPlayer)
    local pid = oPlayer:GetPid()
    if not self.m_mRewardInfo[pid] then
        self.m_mRewardInfo[pid] = {}
    end
    return self.m_mRewardInfo[pid]
end

function CHuodong:ValidReward(oPlayer, iExpenseKey)
    if not global.oToolMgr:IsSysOpen('REBATEJOY', oPlayer, true) then return false end
    if self:GetGameState() ~= GAME_OPEN then return false end
    local mRewardConfig = self:GetRewardConfig()
    if not mRewardConfig or not mRewardConfig[iExpenseKey] then return false end
    local mPlayerReward = self:GetPlayerRewardInfo(oPlayer)
    local mExpenseReward = mPlayerReward[iExpenseKey]
    if not mExpenseReward or mExpenseReward.state ~= STATE_REWARD then return false end
    return true
end

function CHuodong:GetReward(oPlayer, iExpenseKey)
    if not self:ValidReward(oPlayer, iExpenseKey) then return end
    local mRewardConfig = self:GetRewardConfig()
    local mPlayerReward = self:GetPlayerRewardInfo(oPlayer)
    local iRewardId = mRewardConfig[iExpenseKey].reward_id
    local mItemIdxList = self:RewardId2ItemIdx(iRewardId)
    local mItemList = {}
    for _, iItemIdx in pairs(mItemIdxList) do
        local mItemUnit = self:InitRewardItem(oPlayer, iItemIdx, {})
        list_combine(mItemList, mItemUnit["items"])
    end
    if next(mItemList) then
        if not oPlayer:ValidGiveitemlist(mItemList) then return end
        local mLogData = {}
        mLogData.pid = oPlayer:GetPid()
        mLogData.reward_group_key = self.m_sHD2RewardKey
        mLogData.expense = iExpenseKey
        mLogData.reward = extend.Table.serialize(mItemIdxList)
        record.log_db("huodong", "joyexpense_rewarded",{ pid = oPlayer:GetPid(), info = mLogData })
        oPlayer:GiveItemobj(mItemList, self.m_sName)
        mPlayerReward[iExpenseKey] .state = STATE_REWARDED
        ------------------------设置返利奖励-------------------
        local iMultiple = mRewardConfig[iExpenseKey].multiple
        local iMailId = self:GetConfig().rplgoldcoin_mail
        local oHuodongCharge = global.oHuodongMgr:GetHuodong("charge")
        if oHuodongCharge then
            oHuodongCharge:InsertRplGoldCoinGift(oPlayer, iMultiple, iMailId)
        end
        self:Dirty()
        self:GS2CJoyExpenseRewardState(oPlayer)
    end
end

local function _InnerSendMail(mInfo)
    local oHuodong = global.oHuodongMgr:GetHuodong("joyexpense")
    local mPlayerReward = mInfo.reward
    local pid = mInfo.pid
    local mItemList = {}
    local mRewardConfig = oHuodong:GetRewardConfig()
    for iExpenseKey, mExpenseReward in pairs(mPlayerReward) do
        if mExpenseReward.state == STATE_REWARD then
        local mItemIdxList = oHuodong:RewardId2ItemIdx(mRewardConfig[iExpenseKey].reward_id)
        for _, iItemIdx in pairs(mItemIdxList) do
            local mRewardInfo = oHuodong:GetItemRewardData(iItemIdx)
            if not mRewardInfo then
                goto continue
            end
            local mItemInfo = oHuodong:ChooseRewardKey(oPlayer, mRewardInfo, iItemIdx, {})
            if not mItemInfo then
                goto continue
            end
            local mItemUnit = oHuodong:InitRewardByItemUnitOffline(pid, iItemIdx, mItemInfo)
            list_combine(mItemList, mItemUnit["items"])
            ::continue::
        end
        local mLogData = {}
        mLogData.pid = pid
        mLogData.hd_id = oHuodong.m_iHDID
        mLogData.reward_group_key = oHuodong.m_sHD2RewardKey
        mLogData.expense = iExpenseKey
        mLogData.reward = extend.Table.serialize(mItemIdxList)
        record.log_db("huodong","joyexpense_rewarded", { pid = pid ,info = mLogData})
        end
    end
    if next(mItemList) then
        local mMailReward = {}
        mMailReward["items"] = mItemList
        local iMailId = oHuodong:GetConfig().reward_mail
        oHuodong:SendMail(pid, iMailId, mMailReward)
    end
end

function CHuodong:CheckSendMailReward()
    local lRewardInfo = {}
    local lPlayerPid = {}
    for pid, mPlayerReward in pairs(self.m_mRewardInfo) do
        local mInfo = {
            pid = pid,
            reward = mPlayerReward
        }
        table.insert(lRewardInfo, mInfo)
        table.insert(lPlayerPid, pid)
    end
    self.m_mRewardInfo = {}
    self:Dirty()
    global.oToolMgr:ExecuteList(lPlayerPid, 500, 500, 0, "JoyExpenseRewarded", function(pid)
            local oPlayer = global.oWorldMgr:GetOnlinePlayerByPid(pid)
            if oPlayer then
                oPlayer.m_oTodayMorning:Set("joyexpenseshop_goldcoin", 0)
                self:GS2CJoyExpenseGoldCoin(oPlayer)
                self:GS2CJoyExpenseRewardState(oPlayer)
            end
        end)
    global.oToolMgr:ExecuteList(lRewardInfo, 400, 1000, 0, "JoyExpenseSendMail", _InnerSendMail)
end

function CHuodong:InitRewardByItemUnitOffline(pid, iItemidx, mItemInfo)
    local mItems = {}
    local sShape = mItemInfo["sid"]
    local iBind = mItemInfo["bind"]
    if type(sShape) ~= "string" then
        print(debug.traceback("joyexpense reward item"))
        return
    end
    local iAmount = mItemInfo["amount"]
    local oItem = global.oItemLoader:ExtCreate(sShape)
    oItem:SetAmount(iAmount)
    if iBind ~= 0 then
        oItem:Bind(pid)
    end
    mItems["items"] = {oItem}
    return mItems
end

function CHuodong:NewDay(mNow)
    if self.m_iState == GAME_OPEN then
        self:CheckSendMailReward()
    end
end

function CHuodong:NewHour(mNow)
    local iTime = mNow and mNow.time or get_time()
    if self.m_iState == GAME_READY_OPEN then
        if self.m_iStartTime <= iTime then
            self:GameStart()
        elseif self.m_iStartTime - iTime <= 3600 then
            self:DelTimeCb("GameTimeStart")
            self:AddTimeCb("GameTimeStart", (self.m_iStartTime - iTime) * 1000, function()
                self:DelTimeCb("GameTimeStart")
                if self.m_iState ~= GAME_READY_OPEN then return end
                self:GameStart()
            end)
        end
    elseif self.m_iState == GAME_OPEN then
        if self.m_iEndTime <= iTime then
            self:GameEnd()
        elseif self.m_iEndTime - iTime <= 3600 then
            self:DelTimeCb("GameTimeEnd")
            self:AddTimeCb("GameTimeEnd", (self.m_iEndTime - iTime) * 1000, function()
                self:DelTimeCb("GameTimeEnd")
                if self.m_iState ~= GAME_OPEN then return end
                self:GameEnd()
            end)
        end
    end
end

function CHuodong:GetRewardConfig()
    return res["daobiao"]["huodong"]["joyexpense"]["reward"][self.m_sHD2RewardKey]
end

function CHuodong:GetConfig()
    return res["daobiao"]["huodong"]["joyexpense"]["config"][self.m_sHD2RewardKey]
end

function CHuodong:GetShopID()
    local mConfig = self:GetConfig()
    if not mConfig then return end
    return mConfig.shop_id
end

function CHuodong:GetRewardMode()
    local mConfig = self:GetConfig()
    if not mConfig then return end
    return mConfig.mode_id
end

function CHuodong:RewardId2ItemIdx(iRewardId)
    local mReward = res["daobiao"]["reward"]["joyexpense"]["reward"]
    return mReward[iRewardId].item
end

function CHuodong:IsHuodongOpen()
    return self:GetGameState() == GAME_OPEN
end

function CHuodong:TestOp(iFlag, mArgs)
    local netcmd = import(service_path("netcmd.huodong"))
    local pid = mArgs[#mArgs]
    local oMaster = global.oWorldMgr:GetOnlinePlayerByPid(pid)
    if iFlag == 100 then
        global.oChatMgr:HandleMsgChat(oMaster, [[
100 - huodongop joyexpense 100
101 - 查询今日商城消费
102 - 增加消费 102 {val = 200}
103 - 清空消费 （可配合107使用）
104 - 开启活动 104  默认old or 104 {key = old } or 104 {key = new}
105 - 关闭活动
106 - 领取奖励 106 {id = } 奖励id 1-->
107 - 清空奖励
108 - 邮件领取奖励
109 - 购买物品 109 {good = } 从商店列表内获取（1001-->）
110 - 查询活动
        ]])
    elseif iFlag == 101 then
        local iToDayExpense = self:QueryJoExpenseGoldCoin(oMaster)
        local sMsg = global.oToolMgr:FormatString("当前返利商城消费#expense",{expense = iToDayExpense})
        oMaster:NotifyMessage(sMsg)
    elseif iFlag == 102 then
        local iVal = mArgs.val or 0
        self:AddJoyExpenseGoldcoin(oMaster, iVal)
    elseif iFlag == 103 then
        oMaster.m_oTodayMorning:Set("joyexpenseshop_goldcoin", 0)
        self:GS2CJoyExpenseGoldCoin(oMaster)
    elseif iFlag == 104 then
        local iStartTime = get_time()
        if not self.m_iHDID then
            self.m_iHDID = 0
        end
        local mInfo = {
            hd_id = self.m_iHDID + 1,
            hd_type = "joyexpense",
            hd_key = "reward_old",
            start_time = iStartTime + 30,
            end_time = iStartTime + 2 * 24 * 3600
        }
        if mArgs.key then
            mInfo.hd_key = "reward_" .. mArgs.key
        end
        local bClose = false
        self:RegisterHD(mInfo, bClose)
    elseif iFlag == 105 then
        local mInfo = {
            hd_type = "joyexpense",
        }
        local bClose = true
        self:RegisterHD(mInfo, bClose)
    elseif iFlag == 106 then
        netcmd.C2GSJoyExpenseGetReward(oMaster, {expense_id = mArgs.id})
    elseif iFlag == 107 then
        if self.m_mRewardInfo[pid] then
            self.m_mRewardInfo[pid] = nil
            self:GS2CJoyExpenseRewardState(oMaster)
        end
    elseif iFlag == 108 then
        self:CheckSendMailReward()
    elseif iFlag == 109 then
        netcmd.C2GSJoyExpenseBuyGood(oMaster, {shop = self:GetShopID(), goodid = mArgs.good, moneytype = gamedefines.MONEY_TYPE.TRUE_GOLDCOIN, amount = 1})
    elseif iFlag == 110 then
        local sMsg = "欢乐返利id:" .. self.m_iHDID .. "状态:" .. self.m_iState .."\ntime" .. os.date("%x %X", self.m_iStartTime) .. "-->" .. os.date("%x %X", self.m_iEndTime) 
        global.oChatMgr:HandleMsgChat(oMaster, sMsg)
    end
end
