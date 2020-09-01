local global = require "global"
local res = require "base.res"
local record = require "public.record"
local extend = require "base.extend"

local gamedefines = import(lualib_path("public.gamedefines"))
local huodongbase = import(service_path("huodong.huodongbase"))


function NewHuodong(sHuodongName)
    return CHuodong:New(sHuodongName)
end

-- 牌面的状态
local STATE_DRAW = 0    -- 未翻开
local STATE_DRAWED = 1 -- 已经翻开

-- 活动开启的状态
local GAME_CLOSE = 0
local GAME_OPEN = 1
local GAME_READY_OPEN = 2

CHuodong = {}
CHuodong.__index = CHuodong
CHuodong.m_sTempName = "疯狂翻牌"
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
    mData.hd_state = self.m_iState
    mData.start_time = self.m_iStartTime
    mData.end_time = self.m_iEndTime
    local mSaveInfo = {}
    for pid, mPlayerCardInfo in pairs(self.m_mRewardInfo) do
        mSaveInfo[db_key(pid)] = mPlayerCardInfo
    end
    mData.cardinfo = mSaveInfo
    return mData
end

function CHuodong:Load(mData)
    mData = mData or {}
    self.m_iHDID = mData.hd_id or 0
    self.m_sHD2RewardKey = mData.hd_key or ""
    self.m_iState = mData.hd_state
    self.m_iStartTime = mData.start_time
    self.m_iEndTime = mData.end_time
    local mSaveInfo = {}
    for sPid, mPlayerCardInfo in pairs(mData.cardinfo or {}) do
        mSaveInfo[tonumber(sPid)] = mPlayerCardInfo
    end
    self.m_mRewardInfo = mSaveInfo
end

function CHuodong:MergeFrom(mFromData)
    if not mFromData or not next(mFromData) then
        return false, "huodong drawcard without data"
    end

    self:Dirty()
    if self.m_iState ~= mFromData.hd_state
        or self.m_iStartTime ~= mFromData.start_time 
        or self.m_iEndTime ~= mFromData.end_time then
        return true
    end
    for sPid, mData in pairs(mFromData.cardinfo or {}) do
        self.m_mRewardInfo[tonumber(sPid)] = mData
    end
    return true
end

function CHuodong:CheckRegisterInfo(mInfo)
    if not global.oToolMgr:IsSysOpen("DRAWCARD", nil, true) then
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
    return true
end

function CHuodong:RegisterHD(mInfo,bClose)
    if bClose then
        self:TryGameClose()
    else
        local bSucc, sError = self:CheckRegisterInfo(mInfo)
        if not bSucc then
            return false, sError
        end
        self:TryGameOpen(mInfo)
    end
    return true
end

function CHuodong:TryGameClose()
    self:GameEnd()
end

function CHuodong:TryGameOpen(mInfo)
    if mInfo["hd_id"] ~= self.m_iHDID then
        self.m_iHDID = mInfo["hd_id"]
        self.m_sHD2RewardKey = mInfo["hd_key"]
        self.m_mRewardInfo = {}
    end
    self.m_iStartTime = mInfo["start_time"]
    self.m_iEndTime = mInfo["end_time"]
    self.m_iState = GAME_READY_OPEN
    self:Dirty()

    local iNowTime = get_time()
    if self.m_iStartTime <= iNowTime then
        self:GameStart()
    elseif self.m_iStartTime - iNowTime <= 3600 then
        self:DelTimeCb("GameTimeStart")
        self:AddTimeCb("GameTimeStart", (self.m_iStartTime - iNowTime) * 1000, function()
            self:DelTimeCb("GameTimeStart")
            if self.m_iState ~= GAME_READY_OPEN then return end
            self:GameStart()
        end)
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

function CHuodong:OnUpgrade(oPlayer, iFromGrade, iGrade)
    if self.m_iState == GAME_OPEN then
        local iOpenGrade = global.oToolMgr:GetSysOpenPlayerGrade("DRAWCARD")
        if iFromGrade < iOpenGrade and iGrade >= iOpenGrade then
            self:GS2CDrawCardState(oPlayer)
            self:GS2CDrawCardTimes(oPlayer)
            self:GS2CDrawCardGetList(oPlayer)
            self:DelUpgradeEvent(oPlayer)
        end
    end
end

function CHuodong:OnLogin(oPlayer, bReEnter)
    local oToolMgr = global.oToolMgr
    local iOpenGrade = oToolMgr:GetSysOpenPlayerGrade("DRAWCARD")
    if oToolMgr:IsSysOpen("DRAWCARD", nil , true) then
        if  oPlayer:GetGrade() < iOpenGrade then
            self:AddUpgradeEvent(oPlayer)
            return
        end
    end
    if not oToolMgr:IsSysOpen("DRAWCARD", oPlayer, true) then return end
    if self.m_iState == GAME_OPEN then
        self:GS2CDrawCardState(oPlayer)
        self:GS2CDrawCardTimes(oPlayer)
        self:GS2CDrawCardGetList(oPlayer)
    end
end

function CHuodong:GameStart()
    local oWorldMgr = global.oWorldMgr
    local oToolMgr = global.oToolMgr
    self.m_iState = GAME_OPEN
    self:Dirty()
    local mLogData = {}
    mLogData.state = self.m_iState
    mLogData.hd_id = self.m_iHDID
    mLogData.reward_key = self.m_sHD2RewardKey
    record.log_db("huodong","drawcard_state", { info = mLogData })
    local lPlayerPid = {}
    for _, oPlayer in pairs(oWorldMgr:GetOnlinePlayerList()) do
        if oToolMgr:IsSysOpen("DRAWCARD", oPlayer, true) then
            table.insert(lPlayerPid, oPlayer:GetPid())
        end
    end
    local FunOpen = function(pid)
        local oPlayer = oWorldMgr:GetOnlinePlayerByPid(pid)
        if oPlayer then
            self:GS2CDrawCardState(oPlayer)
            self:GS2CDrawCardTimes(oPlayer)
            self:GS2CDrawCardGetList(oPlayer)
        end
    end
    global.oToolMgr:ExecuteList(lPlayerPid, 500, 500, 0 ,"DrawCardGameStart", FunOpen)
    global.oHotTopicMgr:Register(self.m_sName)
    record.info("huodong yunying drawcard start %d, %s",self.m_iHDID, self.m_sHD2RewardKey)
end

function CHuodong:GameEnd()
    local oWorldMgr = global.oWorldMgr
    local oToolMgr = global.oToolMgr
    self.m_iState = GAME_CLOSE
    self.m_mRewardInfo = {}
    global.oHotTopicMgr:UnRegister(self.m_sName)
    self:Dirty()
    local mLogData = {}
    mLogData.state = self.m_iState
    mLogData.hd_id = self.m_iHDID
    mLogData.reward_key = self.m_sHD2RewardKey
    record.log_db("huodong","drawcard_state", {info = mLogData}) 
    local FunClose = function(pid)
        local oPlayer = oWorldMgr:GetOnlinePlayerByPid(pid)
        if oPlayer then
            self:GS2CDrawCardState(oPlayer)
        end
    end
    local lPlayerPid = {}
    for _, oPlayer in pairs(oWorldMgr:GetOnlinePlayerList()) do
        if oToolMgr:IsSysOpen("DRAWCARD", oPlayer, true) then
            table.insert(lPlayerPid, oPlayer:GetPid())
        end
    end
    global.oToolMgr:ExecuteList(lPlayerPid, 500, 500, 0, "DrawCardGameEnd", FunClose)
    record.info("huodong yunying drawcard end %d, %s",self.m_iHDID, self.m_sHD2RewardKey)
end

function CHuodong:ValidHuodong(oPlayer)
    if not global.oToolMgr:IsSysOpen("DRAWCARD", oPlayer, true) then
        return false
    end
    if self.m_iState ~= GAME_OPEN then
        return false
    end
    return true
end

-- 刷新在线玩家数据
function CHuodong:NewDay(mNow)
    if self.m_iState == GAME_OPEN then
        local funSend = function(pid)
            local oPlayer = global.oWorldMgr:GetOnlinePlayerByPid(pid)
            if oPlayer then
                self:LoginNewDay(oPlayer)
                self:GS2CDrawCardTimes(oPlayer)
                self:GS2CDrawCardGetList(oPlayer)
            end
        end
        local lOnlinePlayer = global.oWorldMgr:GetOnlinePlayerList()
        local lPlayerPid = {}
        for _, oPlayer in pairs(lOnlinePlayer) do
            table.insert(lPlayerPid, oPlayer:GetPid())
        end
        global.oToolMgr:ExecuteList(lPlayerPid, 500, 500,0 ,"DrawGardGameNewDay", funSend)
    end
end

function CHuodong:LoginNewDay(oPlayer)
    local pid = oPlayer:GetPid()
    local mPlayerCardInfo = self.m_mRewardInfo[pid]
    local mConfig = self:GetConfig()
    if mPlayerCardInfo then
        if  mPlayerCardInfo.day_no >= get_morningdayno() then
            return
        else
            self:Dirty()
            if mPlayerCardInfo.times < mConfig.reset_times then
                mPlayerCardInfo.times = mConfig.reset_times
            end
            mPlayerCardInfo.curcards = {}
            mPlayerCardInfo.curcard_count = 0
            mPlayerCardInfo.purchased_times = 0
            mPlayerCardInfo.day_no = get_morningdayno()
        end
    else
        mPlayerCardInfo = {}
        mPlayerCardInfo.times = mConfig.reset_times
        mPlayerCardInfo.purchased_times = 0
        mPlayerCardInfo.curcards = {}
        mPlayerCardInfo.curcard_count = 0
        mPlayerCardInfo.day_no = get_morningdayno()
        
        self.m_mRewardInfo[pid] = mPlayerCardInfo
    end
end

function CHuodong:GetPlayerCardInfo(oPlayer)
    self:LoginNewDay(oPlayer)
    local pid = oPlayer:GetPid()
    return self.m_mRewardInfo[pid]
end

-- 清空牌面
function CHuodong:ClearCard(oPlayer)
    local pid = oPlayer:GetPid()
    local mPlayerCardInfo = self:GetPlayerCardInfo(oPlayer)
    mPlayerCardInfo.curcards = {}
    mPlayerCardInfo.curcard_count = 0
end

-- 一组新的牌面
function CHuodong:ResetCard(oPlayer)
    local pid = oPlayer:GetPid()
    local mPlayerCardInfo = self:GetPlayerCardInfo(oPlayer)
    if mPlayerCardInfo.times <= 0 then
        local sMsg = self:GetTextData(1012)
        global.oNotifyMgr:Notify(pid, sMsg)
        return
    end
    local mConfig = self:GetConfig()
    local lReward = self:GetRewardConfig("common")
    -- 有且只有一个稀有物品
    lReward = extend.Random.random_size(lReward, mConfig.card_count - 1)
    local lUncommonReward = self:GetRewardConfig("uncommon")
    local mRatio = {}
    for index, mUncommon in ipairs(lUncommonReward) do
        mRatio[index] = mUncommon.uncommon_ratio
    end
    local iChoosKey = extend.Random.choosekey(mRatio)
    local mUncommon = {
        id = #lReward + 1, 
        reward_id = lUncommonReward[iChoosKey].reward_id,
    }
    lReward[#lReward + 1] = mUncommon
    lReward = extend.Random.random_size(lReward, #lReward)
    mPlayerCardInfo.times = mPlayerCardInfo.times - 1
    mPlayerCardInfo.curcards = {}
    for id, mReward in ipairs(lReward) do
        local mOneCard = {
            card_info = lReward[id].reward_id,
            card_state = STATE_DRAW,
            card_id = id,
        }
        table.insert(mPlayerCardInfo.curcards, mOneCard)
    end
    mPlayerCardInfo.curcard_count = mConfig.card_count
    self:Dirty()
end

function CHuodong:C2GSDrawCardOpenView(oPlayer)
    if not self:ValidHuodong(oPlayer) then
        return 
    end
    self:GS2CDrawCardGetList(oPlayer)
    self:GS2CDrawCardState(oPlayer)
    self:GS2CDrawCardTimes(oPlayer)
end

function CHuodong:C2GSDrawCardBuyTimes(oPlayer)
    if not self:ValidHuodong(oPlayer) then
        return 
    end
    local pid = oPlayer:GetPid()
    local mPlayerCardInfo = self:GetPlayerCardInfo(oPlayer)
    local mConfig = self:GetConfig()
    if mPlayerCardInfo.purchased_times >= mConfig.times_limit then
        local sMsg = self:GetTextData(1011)
        global.oNotifyMgr:Notify(pid,sMsg)
        return
    end
    local iCost = self:GetPurchasedTimeCost(mPlayerCardInfo.purchased_times + 1)
    if not oPlayer:ValidTrueGoldCoin(iCost) then
        return
    end
    oPlayer:ResumeTrueGoldCoin(iCost, "疯狂翻牌购买重置次数")
    mPlayerCardInfo.times = mPlayerCardInfo.times + 1
    mPlayerCardInfo.purchased_times = mPlayerCardInfo.purchased_times + 1
    self:GS2CDrawCardTimes(oPlayer)
    self:Dirty()
end

function CHuodong:GS2CDrawCardState(oPlayer)
    local mNet = {
        state = self.m_iState,
        end_time = self.m_iEndTime,
    }
    oPlayer:Send("GS2CDrawCardState", mNet)
end

function CHuodong:GS2CDrawCardTimes(oPlayer)
    local pid = oPlayer:GetPid()
    local mPlayerCardInfo = self:GetPlayerCardInfo(oPlayer)
    local mNet = {
        times = mPlayerCardInfo.times,
        purchased_times = mPlayerCardInfo.purchased_times,
    }
    oPlayer:Send("GS2CDrawCardTimes", mNet)
end

function CHuodong:GS2CDrawCardGetList(oPlayer)
    local pid = oPlayer:GetPid()
    local mPlayerCardInfo = self:GetPlayerCardInfo(oPlayer)
    local mNet = {
        card_list = mPlayerCardInfo.curcards,
        card_count = mPlayerCardInfo.curcard_count,
    }
    oPlayer:Send("GS2CDrawCardGetList", mNet)
end

function CHuodong:C2GSDrawCardStart(oPlayer)
    if not self:ValidHuodong(oPlayer) then
        return
    end
    self:ResetCard(oPlayer)
    self:GS2CDrawCardGetList(oPlayer)
    self:GS2CDrawCardTimes(oPlayer)
end

function CHuodong:C2GSDrawCardReset(oPlayer)
    if not self:ValidHuodong(oPlayer) then
        return 
    end
    self:ClearCard(oPlayer)
    self:GS2CDrawCardGetList(oPlayer)
end

function CHuodong:C2GSDrawCardOpenOne(oPlayer, card_id)
    if not self:ValidHuodong(oPlayer) then
        return 
    end
    local pid = oPlayer:GetPid()
    local mPlayerCardInfo = self:GetPlayerCardInfo(oPlayer)
    local mCurCard = mPlayerCardInfo.curcards[card_id]
    if not mCurCard then return end
    local mConfig = self:GetConfig()

    if mPlayerCardInfo.curcard_count <= 0 then
        global.oNotifyMgr:Notify(pid, self:GetTextData(1010))
        return
    end

    local iCost = 0
    if mPlayerCardInfo.curcard_count ~= mConfig.card_count then
        iCost = mConfig.draw_cost
        if not oPlayer:ValidTrueGoldCoin(iCost) then
            self:GS2CDrawCardGetList(oPlayer, {success = false})
            return
        end
    end

    if mCurCard.card_state == STATE_DRAW then
        local lDrawedCards = {}
        table.insert(lDrawedCards, mCurCard)
        local lItemIdx = self:RewardId2ItemIdx(mCurCard.card_info)
        local mItemList = {}
        local lChuanwenId = {}
        for _, iItemIdx in pairs(lItemIdx) do
            local mItemUnit = self:InitRewardItem(oPlayer, iItemIdx, {})
            if mItemUnit["info"]["sys"] > 0 then
                table.insert(lChuanwenId, {sys = mItemUnit["info"]["sys"], sid = mItemUnit["info"]["sid"]})
            end
            list_combine(mItemList, mItemUnit["items"])
        end
        -- 如果配错
        if #mItemList ~= 1 then return end
        if not oPlayer:ValidGiveitemlist(mItemList, {cancel_tip = true}) then
            global.oNotifyMgr:Notify(pid, self:GetTextData(1001))
            self:GS2CDrawCardDrawResult(oPlayer, {success = false})
            return
        end
        if iCost > 0 then
            oPlayer:ResumeTrueGoldCoin(iCost, "疯狂翻牌翻牌")
        end
        mCurCard.card_state = STATE_DRAWED
        mPlayerCardInfo.curcard_count = mPlayerCardInfo.curcard_count - 1
        self:Dirty()
        local mLogData = {}
        mLogData.reward = extend.Table.serialize(lItemIdx)
        record.log_db("huodong","drawcard_rewarded",{ pid = pid, info = mLogData})
        if next(lChuanwenId) then
            self:SendChuanwen(oPlayer, lChuanwenId)
        end
        oPlayer:GiveItemobj(mItemList, self.m_sName, {})
        local mResult = {
            success = true,
            drawed_list = lDrawedCards,
            card_count = mPlayerCardInfo.curcard_count,
        }
        self:GS2CDrawCardDrawResult(oPlayer, mResult)
    else
        global.oNotifyMgr:Notify(pid, self:GetTextData(1008))
        self:GS2CDrawCardGetList(oPlayer, { success = false})
        return
    end
end

function CHuodong:GS2CDrawCardDrawResult(oPlayer, mResult)
    local mNet = {
    }
    if mResult.success then
        mNet.success = 1
        mNet.card_list = mResult.drawed_list
        mNet.card_count = mResult.card_count
    else
        mNet.success = 0
        mNet.card_list = nil
        mNet.card_count = nil
    end
    oPlayer:Send("GS2CDrawCardDrawResult", mNet)
end

function  CHuodong:C2GSDrawCardOpenList(oPlayer)
    if not self:ValidHuodong(oPlayer) then
        return 
    end
    local pid = oPlayer:GetPid()
    local mPlayerCardInfo = self:GetPlayerCardInfo(oPlayer)
    local mConfig = self:GetConfig()

    if mPlayerCardInfo.curcard_count <= 0 then
        global.oNotifyMgr:Notify(pid, self:GetTextData(1010))
        return
    end

    local iCostCardCount = mPlayerCardInfo.curcard_count
    if iCostCardCount == mConfig.card_count then
        iCostCardCount = iCostCardCount - 1
    end
    local iTotalCost = iCostCardCount * mConfig.draw_cost
    if not oPlayer:ValidTrueGoldCoin(iTotalCost) then
        self:GS2CDrawCardDrawResult(oPlayer, {success = false})
        return
    end

    local lItemIdx = {}
    for _, mCard in pairs(mPlayerCardInfo.curcards) do
        if mCard.card_state == STATE_DRAW then
            list_combine(lItemIdx, self:RewardId2ItemIdx(mCard.card_info))
        end
    end

    local mItemList = {}
    local mItemUnit
    local lChuanwenId = {}
    for _, iItemIdx in pairs(lItemIdx) do
        mItemUnit = self:InitRewardItem(oPlayer, iItemIdx, {})
        if mItemUnit["info"]["sys"] > 0 then
            table.insert(lChuanwenId, {sys = mItemUnit["info"]["sys"], sid = mItemUnit["info"]["sid"]})
        end
        list_combine(mItemList, mItemUnit["items"])
    end
    if next(mItemList) then
        local pid = oPlayer:GetPid()
        if not oPlayer:ValidGiveitemlist(mItemList, {cancel_tip = true}) then
            global.oNotifyMgr:Notify(pid, self:GetTextData(1001))
            self:GS2CDrawCardDrawResult(oPlayer, {success = false})
            return
        end

        local lDrawedCards = {}
        for _, mCard in pairs(mPlayerCardInfo.curcards) do
            if mCard.card_state == STATE_DRAW then
                mCard.card_state = STATE_DRAWED
                table.insert(lDrawedCards, mCard)
            end
        end

        oPlayer:ResumeTrueGoldCoin(iTotalCost, "疯狂翻牌一键翻牌")
        mPlayerCardInfo.curcard_count = 0
        local mResult = {
            success = true,
            drawed_list = lDrawedCards,
            card_count = mPlayerCardInfo,
        }
        self:GS2CDrawCardDrawResult(oPlayer, mResult)
        local mLogData = {}
        mLogData.reward = extend.Table.serialize(lItemIdx)
        record.log_db("huodong","drawcard_rewarded",{ pid = pid, info = mLogData})
        if next(lChuanwenId) then
            self:SendChuanwen(oPlayer, lChuanwenId)
        end
        oPlayer:GiveItemobj(mItemList, self.m_sName, {})
        self:Dirty()
    else
        global.oNotifyMgr:Notify(pid, self:GetTextData(1010))
        self:GS2CDrawCardGetList(oPlayer, { success = false})
        return
    end
end

function CHuodong:GetPurchasedTimeCost(iTime)
    local mTimeCost = res["daobiao"]["huodong"][self.m_sName]["times_cost"]
    for _ , mCostInfo in pairs(mTimeCost) do
        if  iTime >= mCostInfo["times_interval"][1] and iTime <= mCostInfo["times_interval"][2] then
            return mCostInfo["goldcoin"]
        end
    end
end

function CHuodong:GetConfig()
    local sRewardKey = self.m_sHD2RewardKey
    return res["daobiao"]["huodong"][self.m_sName]["config"][sRewardKey]
end

function CHuodong:GetRewardConfig(sUncommon)
    local sRewardKey = self.m_sHD2RewardKey
    if sRewardKey then
        return res["daobiao"]["huodong"][self.m_sName][sRewardKey][sUncommon]
    else
        return nil
    end
end

-- config内配置的是id 不是 idx 则对应去转一层
function CHuodong:RewardId2ItemIdx(iRewardId)
    local mReward = res["daobiao"]["reward"]["drawcard"]["reward"]
    return mReward[iRewardId].item
end

function CHuodong:GetTimesCostConfig()
    return res["daobiao"]["huodong"][self.m_sName][times_cost]
end

function CHuodong:IsHuodongOpen()
    if self.m_iState == GAME_OPEN then
        return true
    else
        return false
    end
end

function CHuodong:SendChuanwen(oPlayer, lChuanwenId)
    local oToolMgr = global.oToolMgr
    local oChatMgr = global.oChatMgr
    local sRole = oPlayer:GetName()
    for _, mInfo in ipairs(lChuanwenId) do
        local mChuanwen = res["daobiao"]["chuanwen"][mInfo.sys]
        local sMsg = oToolMgr:FormatColorString(mChuanwen.content, {role = sRole, sid = mInfo.sid})
        oChatMgr:HandleSysChat(sMsg, gamedefines.SYS_CHANNEL_TAG.RUMOUR_TAG, mChuanwen.horse_race)
    end
end

function CHuodong:TestOp(iFlag, mArgs)
    local pid = mArgs[#mArgs]
    local oMaster = global.oWorldMgr:GetOnlinePlayerByPid(pid)
    if iFlag == 100 then
        global.oChatMgr:HandleMsgChat(oMaster, [[
100 - huodongop drawcard
101 - 增加已购买次数  101 {val = 20} 默认增加 10次
102 - 购买一次 
103 - 开启一张牌
104 - 开启所有的牌
105 - 开始或重置牌面
106 - 开启活动
107 - 关闭活动
108 - 查询活动消息
110 - 查看活动时间
            ]])
    elseif iFlag == 101 then
        local iValue = mArgs.val or 10
        local mPlayerCardInfo = self:GetPlayerCardInfo(oMaster)
        mPlayerCardInfo.purchased_times = mPlayerCardInfo.purchased_times + iValue
    elseif iFlag == 102 then
        self:C2GSDrawCardBuyTimes(oMaster)
    elseif iFlag == 103 then
        local card_id = mArgs.card_id or 1
        self:C2GSDrawCardOpenOne(oMaster, card_id)
    elseif iFlag == 104 then
        self:C2GSDrawCardOpenList(oMaster)
    elseif iFlag == 105 then
        self:C2GSDrawCardReset(oMaster)
    elseif iFlag == 106 then
        local iStartTime = get_time()
        if not self.m_iHDID then
            self.m_iHDID = 0
        end
        local mInfo = {
            hd_id = self.m_iHDID + 1,
            hd_type = "drawcard",
            hd_key = "reward",
            start_time = iStartTime + 5,
            end_time = iStartTime +  7 * 24 * 3600,
        }
        local bClose = false
        self:RegisterHD(mInfo, bClose)
    elseif iFlag == 107 then
        local bClose = true
        self:RegisterHD(mInfo, bClose)
    elseif iFlag == 108 then
        local sMsg = "活动ID" .. self.m_iHDID .. "活动状态" .. self.m_iState
        global.oChatMgr:HandleMsgChat(oMaster, sMsg)
    elseif iFlag == 110 then
        local sMsg = os.date("%x %X",self.m_iStartTime) .. " --> " .. os.date("%x %X",self.m_iEndTime)
        global.oChatMgr:HandleMsgChat(oMaster, sMsg)
    end
end