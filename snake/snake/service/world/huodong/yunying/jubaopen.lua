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
CHuodong.m_sTempName = "聚宝盆"
inherit(CHuodong, huodongbase.CHuodong)

local GAME_NOSTART = 0
local GAME_START = 1
local GAME_READY_OPEN = 2

local STATE_REWARD = 1  -- 可领取
local STATE_REWARDED = 2 -- 已领取

local ONE_DAY_SEC = 1*24*60*60

function CHuodong:New(sHuodongName)
    local o = super(CHuodong).New(self, sHuodongName)
    o.m_iVersion = 0
    o.m_iShowTime = 0
    return o
end

function CHuodong:Init()
    self.m_iState = GAME_NOSTART
    self.m_iStartTime = 0
    self.m_iEndTime = 0
    self.m_mRewardInfo = {}
    self.m_mRecord = {}
end

function CHuodong:Save()
    local mData = {}
    mData.version = self.m_iVersion
    mData.state = self.m_iState
    mData.showtime = self.m_iShowTime
    mData.starttime = self.m_iStartTime
    mData.endtime = self.m_iEndTime
    local mRewardInfo = {}
    for iPid, mReward in pairs(self.m_mRewardInfo) do
        mRewardInfo[db_key(iPid)]  = mReward
    end
    mData.rewardinfo = mRewardInfo
    mData.record = table_to_db_key(self.m_mRecord)
    return mData
end

function CHuodong:Load(mData)
    mData = mData or {}
    self.m_iVersion = mData.version or 0
    self.m_iState = mData.state or 0
    self.m_iShowTime = mData.showtime or 0
    self.m_iStartTime = mData.starttime or 0
    self.m_iEndTime = mData.endtime or 0
    local mRewardInfo = {}
    for sPid, mReward in pairs(mData.rewardinfo or {}) do
        mRewardInfo[tonumber(sPid)]  = mReward
    end
    self.m_mRewardInfo = mRewardInfo
    self.m_mRecord = table_to_int_key(mData.record or {})
end

function CHuodong:NeedSave()
    return true
end

function CHuodong:MergeFrom(mFromData)
    if not mFromData or not next(mFromData) then
        return false, "huodong jubaopen without data"
    end
    if self.m_iState == GAME_START and mFromData.state == GAME_START then
        for sPid, mReward in pairs(mFromData.rewardinfo or {}) do
            self.m_mRewardInfo[tonumber(sPid)] = mReward
        end
        self:Dirty()
    end
    return true
end

function CHuodong:GetFortune(iMoneyType, mArgs)
    return false
end

function CHuodong:NewHour(mNow)
    local iTime = mNow and mNow.time or get_time()
    if self:GetGameState() == GAME_READY_OPEN then
        if self.m_iStartTime <= iTime then
            self:GameStart()
        elseif self.m_iStartTime - iTime  <= 3600 then
            self:AddGameStartCb()
        end
    elseif self:GetGameState() == GAME_START then
        if self.m_iEndTime <= iTime then
            self:TryGameEnd()
        elseif self.m_iEndTime - iTime <= 3600 then
            self:AddGameEndCb()
        end
    end
end

function CHuodong:OnLogin(oPlayer,bReEnter)
    local oToolMgr = global.oToolMgr
    local iOpenGrade = oToolMgr:GetSysOpenPlayerGrade("JUBAOPEN")
    if oToolMgr:IsSysOpen("JUBAOPEN", nil , true) then
        if oPlayer:GetGrade() < iOpenGrade then
            self:AddUpgradeEvent(oPlayer)
            return
        end
    end
    local bIsOpen = oToolMgr:IsSysOpen("JUBAOPEN", oPlayer, true) 
    if not bIsOpen then return end

    if self:GetGameState() == GAME_START then
        self:GS2CGameStart(oPlayer)
        self:GS2CGameReward(oPlayer)
        self:GS2CJuBaoPenRecord(oPlayer)
    else
        if self:IsShowRank() then
            self:GS2CGameStart(oPlayer)
        end
    end
end

function CHuodong:OnUpgrade(oPlayer,iFromGrade, iGrade)
    local iLimitGrade =  res["daobiao"]["open"]["JUBAOPEN"]["p_level"]
    if self:GetGameState() == GAME_START and iLimitGrade <= iGrade and iFromGrade < iLimitGrade then
        self:GS2CGameStart(oPlayer)
        self:GS2CGameReward(oPlayer)
        self:GS2CJuBaoPenRecord(oPlayer)
        self:DelUpgradeEvent(oPlayer)
    end
end

function CHuodong:GetGameState()
    return self.m_iState
end

function CHuodong:GetEndTime()
    return self.m_iEndTime
end

function CHuodong:RegisterHD(mInfo, bClose)
    if bClose then
        self.m_iShowTime = get_time() + ONE_DAY_SEC
        self:GameEnd()
        record.warning(string.format("%s force gameend", self.m_sName)) 
    else
        local bIsOpen = global.oToolMgr:IsSysOpen("JUBAOPEN")
        if not bIsOpen then
            return false, string.format("%s huodong config is close", self.m_sName)
        end

        local iStartTime = mInfo.start_time
        local iEndTime = mInfo.end_time

        if not iStartTime or not iEndTime then
            return false, string.format("%s huodong start_time or end_time is nil", self.m_sName)
        end

        if iEndTime <= iStartTime then
            return false, string.format("%s huodong end_time less than or equal start_time", self.m_sName)
        end

        self:TryGameStart(mInfo)
    end
    return true
end

--运营开启活动接口
function CHuodong:TryGameStart(mInfo)
    if self:GetGameState() == GAME_START then
        return
    end

    self:Init()
    self.m_iStartTime = mInfo["start_time"]
    self.m_iEndTime = mInfo["end_time"]
    self.m_iState = GAME_READY_OPEN
    self:Dirty()

    if self.m_iStartTime <= get_time() then         
        self:GameStart()
    elseif self.m_iStartTime - get_time() <= 3600 then      
        self:AddGameStartCb()
    end

    --处理极端情况，活动持续时间不足1小时
    if self.m_iEndTime - get_time() < 3600 then
        self:AddGameEndCb()
    end
end

function CHuodong:AddGameStartCb()
    self:DelTimeCb("GameTimeStart")
    self:AddTimeCb("GameTimeStart", (self.m_iStartTime - get_time()) * 1000, function()
        if self.m_iState == GAME_READY_OPEN then
            self:GameStart()
        end
    end)
end

function CHuodong:AddGameEndCb()
    self:DelTimeCb("GameTimeEnd")
    self:AddTimeCb("GameTimeEnd", (self.m_iEndTime - get_time())*1000, function()
        if self:GetGameState() == GAME_START then 
            self:TryGameEnd() 
        end
    end)
end

function CHuodong:GameStart()
    record.info(string.format("%s GameStart",self.m_sName))
    self:Dirty()
    self.m_iVersion = self.m_iVersion + 1
    self.m_iState = GAME_START
    self.m_iShowTime = self:GetEndTime() + ONE_DAY_SEC
    
    --活动开始时清榜
    interactive.Send(".rank", "rank", "ClearJuBaoOpen", {rankname = "jubaopen_score"})
    self:LogState()
    self:RefreshAllPlayer()
    global.oHotTopicMgr:Register(self.m_sName)
end

function CHuodong:RefreshAllPlayer()
    local func = function (pid)
        local oPlayer = global.oWorldMgr:GetOnlinePlayerByPid(pid)
        if not oPlayer then return end
        self:GS2CGameStart(oPlayer)
        self:GS2CGameReward(oPlayer)
        self:GS2CJuBaoPenRecord(oPlayer)
    end
    local lAllOnlinePid = table_key_list(global.oWorldMgr:GetOnlinePlayerList())
    global.oToolMgr:ExecuteList(lAllOnlinePid, 100, 1000, 0, "JuBaoPenGameStart", func)
end

function CHuodong:TryGameEnd()    
    self:GameEnd()
end

function CHuodong:GameEnd()
    record.info(string.format("%s GameEnd", self.m_sName))
    interactive.Send(".rank", "rank", "RefreshJuBaoOpen", {rankname = "jubaopen_score"})
    global.oHotTopicMgr:UnRegister(self.m_sName)
    self:Dirty()
    self:DealEndRewardMail()
    self:DealEndRankMail()
    self:Init()
    self:LogState()
    self:GS2CGameEnd()
end

function CHuodong:DealEndRewardMail()
    local mConfig = self:GetConfig()
    local iMailID = mConfig.score_mail_id
    local mConfigScore = self:GetConfigScoreReward()
    for iPid, _ in pairs(self.m_mRewardInfo) do
        local mScoreState = self.m_mRewardInfo[iPid].score_state
        local lItemList = {}
        for iScore, iState in pairs(mScoreState) do
            if iState == STATE_REWARD then
                local iRewardIdx = mConfigScore[iScore].reward_idx
                local lItems = self:GetScoreRewardItemByIdx(iPid, iRewardIdx)
                list_combine(lItemList, lItems)
            end
        end
        if #lItemList > 0 then
            self:SendMail(iPid, iMailID, { items = lItemList })
        end
    end
end

function CHuodong:DealEndRankMail()
    local mData = {
        rankname = "jubaopen_score"
    }
    interactive.Request(".rank", "rank", "GetJuBaoPenData", mData,
    function(mRecord, mData)
        OnRemoteQueryRank(mData)
    end)
end

function OnRemoteQueryRank(mData)
    local oHD = global.oHuodongMgr:GetHuodong("jubaopen")
    if oHD then
        oHD:DealEndRankReward(mData)
    end
end

function CHuodong:DealEndRankReward(mData)
    record.info(string.format("%s deal gameend rank mail", self.m_sName))
    local mRewardData = mData.rewarddata or {}
    if #mRewardData <= 0 then return end

    local mConfig = self:GetConfig()
    local iMailID = mConfig.rank_mail_id
    for iRank, iPid in ipairs(mRewardData) do
        if iRank > 10 then break end
        local lItemList = self:GetRankRewardItems(iPid, iRank)
        if #lItemList > 0 then
            local mData, sName = global.oMailMgr:GetMailInfo(iMailID)
            local mReplace = {rank = iRank}
            mData.context = global.oToolMgr:FormatColorString(mData.context, mReplace)
            global.oMailMgr:SendMailNew(0, sName, iPid, mData, {items = lItemList})
        end
    end
end

function CHuodong:GetRankRewardItems(iPid, iRank)
    local mConfig = self:GetConfigRankReward()
    local iRewardIdx
    for _, mInfo in pairs(mConfig) do
        if table_in_list(mInfo["rank"], iRank) then
            iRewardIdx = mInfo["reward_idx"]
            break
        end
    end

    local lItemList = {}
    if iRewardIdx then
        lItemList = self:GetScoreRewardItemByIdx(iPid, iRewardIdx)
    end
    return lItemList
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

function CHuodong:LogState()
    local mLogData = {
        state = self:GetGameState(),
        version = self.m_iVersion,
    }
    record.log_db("huodong", "jubaopen_state", mLogData)
end

function CHuodong:LogReward(oPlayer, iTimes, iCost)
    local iPid = oPlayer:GetPid()
    local lReward = self.m_mRewardInfo[iPid].ten_reward
    local sReward = extend.Table.serialize(lReward)
    local mLogData = {
        pid = iPid,
        version = self.m_iVersion,
        reward = sReward,
        times = iTimes,
        cost = iCost,
        op = STATE_REWARD,
    }
    record.log_db("huodong", "jubaopen_reward", mLogData)
end

function CHuodong:GetConfig()
    return res["daobiao"]["huodong"][self.m_sName]["config"][1]
end

function CHuodong:GetConfigRankReward()
    return res["daobiao"]["huodong"][self.m_sName]["rank_reward"]
end

function CHuodong:GetConfigScoreReward()
    return res["daobiao"]["huodong"][self.m_sName]["score_reward"]
end

function CHuodong:C2GSJuBaoPen(oPlayer, iTimes)
    if self:GetGameState() == GAME_NOSTART then
        return
    end

    local iPid = oPlayer:GetPid()
    local iSize = oPlayer.m_oItemCtrl:GetCanUseSpaceSize()
    if iSize < iTimes then
        global.oNotifyMgr:Notify(iPid, self:GetTextData(1003))
        return
    end

    local bCost, iCost = self:JuBaoPenCost(oPlayer, iTimes)
    if not bCost then
        return 
    end
    
    self:DoJuBaoPenReward(oPlayer, iTimes, iCost)
end

function CHuodong:DoJuBaoPenReward(oPlayer, iTimes, iCost)
    local iPid = oPlayer:GetPid()
    local mConfig = self:GetConfig()
    local iRewardIdx = mConfig.reward

    local mConfig = self:GetConfig()
    local iFreeCDTime = mConfig.free_cd_time
    local iMaxTimes = mConfig.max_times
    if iCost == 0 then
        oPlayer.m_oTodayMorning:Add("jubaopen_free_count", -1)
        if oPlayer.m_oTodayMorning:Query("jubaopen_free_count", 0) > 0 then
            local iCDEndTime = get_time() + iFreeCDTime * 60
            oPlayer.m_oTodayMorning:Set("jubaopen_free_cd_endtime", iCDEndTime)
        else
            oPlayer.m_oTodayMorning:Delete("jubaopen_free_cd_endtime")
        end
    else
        oPlayer:ResumeTrueGoldCoin(iCost, "聚宝盆")
    end

    local mArgs = {
        is_lottery = true,
        cancel_tip = true,
        cancel_quick = true,
        refresh = 1,
    }

    self.m_mRewardInfo[iPid].ten_reward = {}
    self.m_mRewardInfo[iPid].special_reward = {}
    self.m_mRewardInfo[iPid].ext_reward = {}
    for i=1, iTimes do
        self:Reward(iPid, iRewardIdx, mArgs)
    end
    self:Dirty()
    self:AddScore(oPlayer, iTimes)
    self:CheckTenExtReward(oPlayer, iTimes)
    self:CheckSpecialReward(oPlayer, iTimes)
    self:GS2CGameReward(oPlayer)
    self:GS2CJuBaoPen(oPlayer, iTimes)
    self:LogReward(oPlayer, iTimes, iCost)
end

function CHuodong:JuBaoPenCost(oPlayer, iTimes)
    local mConfig = self:GetConfig()
    local iOnceGoldCoin = mConfig.once_goldcoin
    local iMaxGoldCoin = mConfig.max_goldcoin
    local iMaxTimes = mConfig.max_times

    local iCost
    if iTimes == 1 then
        local iFreeCount = oPlayer.m_oTodayMorning:Query("jubaopen_free_count", 0)
        local iFreeCDEndTime = oPlayer.m_oTodayMorning:Query("jubaopen_free_cd_endtime")
        if iFreeCount > 0 and (not iFreeCDEndTime or iFreeCDEndTime < get_time())  then
            return true, 0
        else
            if  oPlayer:ValidTrueGoldCoin(iOnceGoldCoin) then
                iCost = iOnceGoldCoin
            end
        end
    elseif iTimes == iMaxTimes then
        if oPlayer:ValidTrueGoldCoin(iMaxGoldCoin) then
            iCost = iMaxGoldCoin
        end
    end
    if iCost then
        return true, iCost
    end
end

function CHuodong:RewardItems(oPlayer, mAllItems, mArgs)
    if mArgs and (mArgs.is_lottery or mArgs.is_ext) then
        for _, mData in pairs(mAllItems) do
            local iPid = oPlayer:GetPid()
            local mInfo = mData["info"]
            for _, oItem in ipairs(mData["items"]) do
                local iSid = oItem:SID()
                local iItemCnt = oItem:GetAmount()
                local mTmp = { id = iSid, amount = iItemCnt }
                if mArgs.is_lottery then
                    table.insert(self.m_mRewardInfo[iPid].ten_reward, mTmp)
                    if mInfo and mInfo.is_special == 1 then
                        table.insert(self.m_mRewardInfo[iPid].special_reward, mTmp)
                    end
                elseif mArgs.is_ext then
                    table.insert(self.m_mRewardInfo[iPid].ext_reward, mTmp)
                end
            end
        end
    end
    super(CHuodong).RewardItems(self,oPlayer, mAllItems, mArgs)
end

function CHuodong:AddScore(oPlayer, iTimes)
    local iPid = oPlayer:GetPid()
    local mConfig = self:GetConfig()
    local iOnceRewardScore = mConfig.once_reward_score
    local iCurScore = self.m_mRewardInfo[iPid].score
    iCurScore = iCurScore + iTimes * iOnceRewardScore
    self.m_mRewardInfo[iPid].score = iCurScore

    local mConfigScore = self:GetConfigScoreReward()
    local lScore = table_key_list(mConfigScore)
    for _, iScore in pairs(lScore) do
        local iState = self.m_mRewardInfo[iPid].score_state[iScore]
        if iCurScore >= iScore and not iState then
            self.m_mRewardInfo[iPid].score_state[iScore] = STATE_REWARD
        end 
    end

    local iMinRankScore = mConfig.min_rank_score
    if self.m_mRewardInfo[iPid].score >= iMinRankScore then
        self:PushToJuBaoPenRank(oPlayer)
    end
end

function CHuodong:CheckTenExtReward(oPlayer, iTimes)
    local iPid = oPlayer:GetPid()
    if iTimes == 1 then
        self.m_mRewardInfo[iPid].ten_ext_times = self.m_mRewardInfo[iPid].ten_ext_times - 1
    end

    local bIsReward = false
    if self.m_mRewardInfo[iPid].ten_ext_times == 0 then
        self.m_mRewardInfo[iPid].ten_ext_times = 10
        bIsReward = true
    end

    local mConfig = self:GetConfig()
    local iMaxTimes = mConfig.max_times

    if bIsReward or iTimes == iMaxTimes then
        local mConfig = self:GetConfig()
        local iExtRewardIdx = mConfig.ten_extra_reward
        local mArgs = {
            is_ext = true, 
            cancel_tip = true,
            refresh = 1
        }
        self:Reward(iPid, iExtRewardIdx, mArgs)
    end
end

function CHuodong:CheckSpecialReward(oPlayer, iTimes)
    local iPid = oPlayer:GetPid()
    local lSpecialReward = self.m_mRewardInfo[iPid].special_reward
    if #lSpecialReward <= 0 then return end
    for _, mData in ipairs(lSpecialReward) do
        local mTmp = {
            rolename = oPlayer:GetName(),
            itemid = mData.id,
            num = mData.amount,
        }
        if #self.m_mRecord >= 30 then
            table.remove(self.m_mRecord, 1)
        end
        table.insert(self.m_mRecord, mTmp)
    end
    self:GS2CJuBaoPenRecord(oPlayer)
end

--推送到排行榜
function CHuodong:PushToJuBaoPenRank(oPlayer)
    local iPid = oPlayer:GetPid()
    local iCurScore = self.m_mRewardInfo[iPid].score or 0
    local mData = {
        rank_name = "jubaopen_score",
        rank_data = {
            pid = iPid,
            name = oPlayer:GetName(),
            score = iCurScore,
            goldcoin = oPlayer:GetProfile():TrueGoldCoin()
        }
    }
    interactive.Send(".rank", "rank", "PushDataToRank", mData)
end

function CHuodong:C2GSJuBaoPenScoreReward(oPlayer, iScore)
    local iPid = oPlayer:GetPid()
    local mScoreState = self.m_mRewardInfo[iPid].score_state
    if iScore and mScoreState[iScore] and mScoreState[iScore] == STATE_REWARD then

        local mConfigScore = self:GetConfigScoreReward()
        local iRewardIdx = mConfigScore[iScore].reward_idx

        local iSize = oPlayer.m_oItemCtrl:GetCanUseSpaceSize()
        local iNeedSize = global.oToolMgr:GetItemRewardCnt(self.m_sName, iRewardIdx)
        if iSize < iNeedSize then
            global.oNotifyMgr:Notify(iPid, self:GetTextData(1003))
            return
        end
        self:Dirty()
        self.m_mRewardInfo[iPid].score_state[iScore] = STATE_REWARDED
        self:Reward(iPid, iRewardIdx)
        self:GS2CGameReward(oPlayer)
    end
end

function CHuodong:C2GSOpenJuBaoPenView(oPlayer)
    if self:GetGameState() == GAME_START then
        self:GS2CGameStart(oPlayer)
        self:GS2CGameReward(oPlayer)
        self:GS2CJuBaoPenRecord(oPlayer)
    end
end

function CHuodong:GS2CGameReward(oPlayer)
    local iPid = oPlayer:GetPid()
    self:CheckPlayerInfo(oPlayer)
    self:CheckTodayInfo(oPlayer)
    local mReward = self.m_mRewardInfo[iPid]
    local mNet = {
        score = mReward.score or 0,
        free_count = oPlayer.m_oTodayMorning:Query("jubaopen_free_count", 0),
        free_endtime = oPlayer.m_oTodayMorning:Query("jubaopen_free_cd_endtime"),
        score_reward = self:GetScoreRewardState(iPid),
        ten_ext_times = mReward.ten_ext_times,
    }
    oPlayer:Send("GS2CJuBaoPenInfo", mNet)
end

function CHuodong:CheckPlayerInfo(oPlayer)
    local iPid = oPlayer:GetPid()
    if self.m_mRewardInfo[iPid] then return end
    self:Dirty()
    oPlayer.m_oTodayMorning:Delete("jubaopen_free_count")
    oPlayer.m_oTodayMorning:Delete("jubaopen_free_cd_endtime")
    self.m_mRewardInfo[iPid] = {
        score = 0,
        score_state = {},
        ten_ext_times = 10,
        record = {},
        ten_reward = {},
        special_reward = {},
        ext_reward = {},
    }
end

function CHuodong:CheckTodayInfo(oPlayer)
    if not oPlayer.m_oTodayMorning:Query("jubaopen_free_count") then
        local mConfig = self:GetConfig()
        local iFreeCount  = mConfig.free_count
        oPlayer.m_oTodayMorning:Set("jubaopen_free_count", iFreeCount)
    end

    local iFreeCDEndTime = oPlayer.m_oTodayMorning:Query("jubaopen_free_cd_endtime")
    if iFreeCDEndTime and iFreeCDEndTime < get_time() then
        oPlayer.m_oTodayMorning:Delete("jubaopen_free_cd_endtime")
    end 
end

function CHuodong:GetScoreRewardState(iPid)
    local mReward = self.m_mRewardInfo[iPid]
    local lScoreReward = {}
    for iScore, iState in pairs (mReward.score_state or {}) do
        table.insert(lScoreReward, { score = iScore, state = iState })
    end
    table.sort(lScoreReward, function (a, b)
        return a.score < b.score
    end)
    return lScoreReward
end

function CHuodong:GS2CJuBaoPen(oPlayer, iTimes)
    local iPid = oPlayer:GetPid()
    local mNet = {
        times = iTimes,
        rewards = self.m_mRewardInfo[iPid].ten_reward,
        extrewards = self.m_mRewardInfo[iPid].ext_reward
    }
    oPlayer:Send("GS2CJuBaoPen", mNet)
end

function CHuodong:GS2CJuBaoPenRecord(oPlayer)
    if #self.m_mRecord <= 0 then return end
    local mNet = {
        records = self.m_mRecord
    }
    oPlayer:Send("GS2CJuBaoPenRecord", mNet)
end

function CHuodong:GS2CGameStart(oPlayer)
    local mNet = {
        showrank = self:IsShowRank() and 1 or 2,
        endtime = self:GetEndTime()
    }
    oPlayer:Send("GS2CJuBaoPenStart", mNet)
end

function CHuodong:GS2CGameEnd(oPlayer)
    interactive.Send(".broadcast", "channel", "SendChannel", {
        message = "GS2CJuBaoPenEnd",
        id = 1,
        type = gamedefines.BROADCAST_TYPE.WORLD_TYPE,
        data = {
            showrank = self:IsShowRank() and 1 or 2,
        },
        exclude = {},
    })
end

function CHuodong:IsShowRank()
    if not self.m_iShowTime then
        return false
    end

    local iCurTime = get_time()
    local iSubTime = self.m_iShowTime - iCurTime
    if iSubTime > 0 and iSubTime <= ONE_DAY_SEC then
        return true
    end
    return false
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

    local mCommand={
        "100 指令查看",
        "101 活动开始 \nhuodongop jubaopen 101 {min = 60}",
        "102 正常结束，有榜 \nhuodongop jubaopen 102",
        "103 非正常结束，没榜 \nhuodongop jubaopen 103",
        "104 设置倒计时为n秒 \nhuodongop jubaopen 104 {sec=30}",
    }
    if iFlag == 100 then
        for idx=#mCommand,1,-1 do
            oChatMgr:HandleMsgChat(oPlayer,mCommand[idx])
        end
        oNotifyMgr:Notify(pid,"请看消息频道咨询指令")
    elseif iFlag == 101 then
        local iMin = mArgs.min or 60
        local mInfo = {
            start_time = get_time(),
            end_time = get_time() + iMin*60
        }
        self:RegisterHD(mInfo, false)
    elseif iFlag == 102 then
        self:RegisterHD(nil, true)
        oNotifyMgr:Notify(pid,"正常结束，有榜")
    elseif iFlag == 103 then
        self:RegisterHD(nil, true)
        self.m_iShowTime = get_time() - 60
        self:GS2CGameEnd()
        oNotifyMgr:Notify(pid,"非正常结束，没榜")
    elseif iFlag == 104 then
        local iSec = mArgs.sec or 30
        local iFreeCDEndTime = oPlayer.m_oTodayMorning:Query("jubaopen_free_cd_endtime")
        if iFreeCDEndTime then
            local iSubTime = iFreeCDEndTime - get_time()
            if iSubTime > 0 and iSubTime < 8*60*60 then
                oPlayer.m_oTodayMorning:Set("jubaopen_free_cd_endtime", get_time() + math.floor(iSec))
                self:GS2CGameReward(oPlayer)
            end
            oNotifyMgr:Notify(pid, string.format("重新设置倒计时为%s秒", math.floor(iSec)))
        end
    elseif iFlag == 105 then
        local iSec = mArgs.sec or 10
        if self:GetGameState() == GAME_START then
            local iEndTime = self:GetEndTime()
            local iNewEndTime = get_time() + iSec
            self.m_iShowTime = iNewEndTime + ONE_DAY_SEC
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