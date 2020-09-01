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
CHuodong.m_sTempName = "世界杯"
inherit(CHuodong, huodongbase.CHuodong)

--[[ 后台协议数据格式
data = {
    start_time = 12312321 --世界杯活动开始时间戳
    end_time = 123213 --世界杯活动结束时间戳
    out_team = {1001, 1002} --已淘汰队伍列表
    phase = --1.小组赛 2.1/8决赛 3.1/4决赛 4.半决赛 5.季军赛 6决赛
    games = {one_game, one_game, one_game} --显示的比赛
    delete_game = {id, id, id} --删除的比赛
}

one_game = {
    id = 1  --每场比赛的唯一id
    phase = 1 --阶段 1.小组赛 2.1/8决赛 3.1/4决赛 4.半决赛 5.季军赛 6决赛
    round = 1 --轮数
    start_time = 1232103123 --比赛开始的时间戳
    home_team = 1001 --主队 0表示待定
    away_team = 1002 --客队 0表示待定
    status = 1 -- 1 未开始 2 比赛中 3 已结束
    win_team = 1001 --比赛未开始或未结束时-1 比赛结束后 不是平局给获胜队伍id, 平局为0
    has_match = 1 -- 是否有平局 1 有 2 没有
}
]]

local STATUS = {
    PREPARE = 0, --注册了但还没开始
    START = 1, --活动开始
    END = 2, --活动结束
}

local REWARDTYPE = {
    SINGLE_SUC = 1, --猜中单场
    SINGLE_FAIL = 2, --未猜中单场
    SUPPORT_SUC = 3, --支持队伍获胜
}

local COSTTYPE = {
    SINGLE = 1,
    SUPPORT_CANCEL = 2,
}

local REFRESHTYPE = {
    START = 1,
    REFRESH = 2,
}

local GAMESTATUS = {
    NOSTART = 1,
    PLAYING = 2,
    END = 3,
}

function CHuodong:New(sHuodongName)
    local o = super(CHuodong).New(self, sHuodongName)
    o.m_iVersion = 0
    return o
end

function CHuodong:Init()
    self.m_iState = STATUS.END
    self.m_iStartTime = 0
    self.m_iEndTime = 0
    self.m_iFinalStartTime = 0 --决赛开始时间

    self.m_mBackendInfo = {} --后台推送过来的信息
    self.m_mAllGameInfo = {} --所有的比赛信息记录
    self.m_mDelGameInfo = {} --所有被删掉比赛记录

    self.m_mOutTeamInfo = {} --被淘汰的队伍
    self.m_mGuessTeam = {} --单场竞猜信息,根据每场比赛id,记录玩家记录
    self.m_mGuessPlayer = {} --玩家竞猜信息, 根据玩家pid记录玩家竞猜的信息
    self.m_mSupportTeam = {} --按支持球队id组织信息
    self.m_mSupportPlayer = {} --按玩家pid组织信息

    self.m_mTitleInfo = {}
end

function CHuodong:Save()
    local mData = {}
    mData.version = self.m_iVersion
    mData.state = self.m_iState
    mData.starttime = self.m_iStartTime
    mData.endtime = self.m_iEndTime
    mData.finaltime = self.m_iFinalStartTime
    mData.backendinfo = self.m_mBackendInfo
    mData.allgameinfo = self.m_mAllGameInfo
    mData.delgameinfo = self.m_mDelGameInfo
    mData.outteaminfo = self.m_mOutTeamInfo
    mData.guessteam = self.m_mGuessTeam
    mData.guessplayer = self.m_mGuessPlayer
    mData.supportteam = self.m_mSupportTeam
    mData.supportplayer = self.m_mSupportPlayer
    mData.titleinfo = self.m_mTitleInfo
    return mData
end

function CHuodong:Load(mData)
    mData = mData or {}
    self.m_iVersion = mData.version or 0
    self.m_iState = mData.state or STATUS.END
    self.m_iStartTime = mData.starttime or 0
    self.m_iEndTime = mData.endtime or 0
    self.m_iFinalStartTime = mData.finaltime or 0
    self.m_mBackendInfo = mData.backendinfo or {}
    self.m_mAllGameInfo = mData.allgameinfo or {}
    self.m_mDelGameInfo = mData.delgameinfo or {}
    self.m_mOutTeamInfo = mData.outteaminfo or {}
    self.m_mGuessTeam = mData.guessteam or {}
    self.m_mGuessPlayer = mData.guessplayer or {}
    self.m_mSupportTeam = mData.supportteam or {}
    self.m_mSupportPlayer = mData.supportplayer or {}
    self.m_mTitleInfo = mData.titleinfo or {}
end

function CHuodong:NeedSave()
    return true
end

function CHuodong:MergeFrom(mFromData)
    if not mFromData or not next(mFromData) then
        return false, "huodong worldcup without data"
    end
    self:Dirty()
    for iGameId, mData in pairs(mFromData.guessteam or {}) do
        if not self.m_mGuessTeam[iGameId] then
            self.m_mGuessTeam[iGameId] = {}
        end
        for iPid, iGuessTeam in pairs(mData) do
            self.m_mGuessTeam[iGameId][iPid] = iGuessTeam
        end
    end
    for iPid, mData in pairs(mFromData.guessplayer or {}) do
        self.m_mGuessPlayer[iPid] = mData
    end
    for iTeamId, mData in pairs(mFromData.supportteam or {}) do
        if not self.m_mSupportTeam[iTeamId] then
            self.m_mSupportTeam[iTeamId] = {num = 0, players = {}}
        end
        self.m_mSupportTeam[iTeamId].num = self.m_mSupportTeam[iTeamId].num + mData.num
        for iPid, bFlag in pairs(mData.players) do
            self.m_mSupportTeam[iTeamId].players[iPid] = bFlag
        end
    end
    for iPid, iTeamId in pairs(mFromData.supportplayer or {}) do
        self.m_mSupportPlayer[iPid] = iTeamId
    end
    for iPid, mData in pairs(mFromData.titleinfo or {}) do
        self.m_mTitleInfo[iPid] = mData
    end
    return true
end

function CHuodong:GetFortune(iMoneyType, mArgs)
    return false
end

function CHuodong:NewHour(mNow)
    local iTime = mNow and mNow.time or get_time()
    if self:GetGameState() == STATUS.PREPARE then
        if self.m_iStartTime <= iTime then
            self:GameStart()
        elseif self.m_iStartTime - iTime  < 3600 then
            self:AddGameStartCb()
        end
    elseif self:GetGameState() == STATUS.START then
        if self.m_iEndTime <= iTime then
            self:GameEnd()
        elseif self.m_iEndTime - iTime < 3600 then
            self:AddGameEndCb()
        end
    end
end

function CHuodong:AddGameStartCb()
    local iSub = self.m_iStartTime - get_time()
    self:DelTimeCb("WorldCupGameTimeStart")
    self:AddTimeCb("WorldCupGameTimeStart", iSub*1000, function()
        if self.m_iState == STATUS.PREPARE then
            self:GameStart()
        end
    end)
end

function CHuodong:AddGameEndCb()
    local iSub = self.m_iEndTime - get_time()
    self:DelTimeCb("WorldCupGameTimeEnd")
    self:AddTimeCb("WorldCupGameTimeEnd", iSub*1000, function()
        if self:GetGameState() == STATUS.START then 
            self:GameEnd() 
        end
    end)
end

function CHuodong:OnLogin(oPlayer,bReEnter)
    if self:GetGameState() == STATUS.START then
        self:JudgeLoginSingle(oPlayer, bReEnter)
        self:JudgeLoginChampion(oPlayer, bReEnter)
    end
end

function CHuodong:JudgeLoginSingle(oPlayer, bReEnter)
    local bIsOpen = global.oToolMgr:IsSysOpen("WORLDCUP_SINGLE") 
    if not bIsOpen then return end

    local iOpenGrade = global.oToolMgr:GetSysOpenPlayerGrade("WORLDCUP_SINGLE")
    if oPlayer:GetGrade() < iOpenGrade then
        self:AddUpgradeEvent(oPlayer)
        return
    end

    self:GS2CWorldCupState(oPlayer)
    self:GS2CWorldCupSingleInfo(oPlayer)
    self:GS2CWorldCupSingleGuessInfo(oPlayer)
end

function CHuodong:JudgeLoginChampion(oPlayer, bReEnter)
    local bIsOpen = global.oToolMgr:IsSysOpen("WORLDCUP_CHAMPION") 
    if not bIsOpen then return end
    
    local iOpenGrade = global.oToolMgr:GetSysOpenPlayerGrade("WORLDCUP_CHAMPION")
    if oPlayer:GetGrade() < iOpenGrade then
        self:AddUpgradeEvent(oPlayer)
        return
    end
    self:GS2CWorldCupChampionInfo(oPlayer)
end

function CHuodong:OnUpgrade(oPlayer,iFromGrade, iGrade)
    local iSingleOpenGrade = global.oToolMgr:GetSysOpenPlayerGrade("WORLDCUP_SINGLE")
    local iChampionOpenGrade = global.oToolMgr:GetSysOpenPlayerGrade("WORLDCUP_CHAMPION")
    if self:GetGameState() == STATUS.START then
        if iSingleOpenGrade == iGrade then
            self:GS2CWorldCupState(oPlayer)
            self:GS2CWorldCupSingleInfo(oPlayer)
            self:GS2CWorldCupSingleGuessInfo(oPlayer)
        end
        if iChampionOpenGrade == iGrade then
            self:GS2CWorldCupChampionInfo(oPlayer)
        end
    else
        self:DelUpgradeEvent(oPlayer)
    end
end

function CHuodong:GetGameState()
    return self.m_iState
end

function CHuodong:RegisterHD(mInfo, bClose)
    if bClose then
        self:GameEnd()
    else
        if self:GetGameState() == STATUS.END then
            self:TryGameStart(mInfo)
        else
            self:BackendUpdate(mInfo)
        end
    end
    return true
end

function CHuodong:TryGameStart(mInfo)
    self:Init()
    self.m_iStartTime = mInfo["start_time"]
    self.m_iEndTime = mInfo["end_time"]
    self.m_iState = STATUS.PREPARE
    self:Dirty()
    self.m_mBackendInfo = mInfo

    local iCurTime = get_time()
    if self.m_iStartTime <= iCurTime then         
        self:GameStart()
    elseif self.m_iStartTime - iCurTime <= 3600 then      
        self:AddGameStartCb()
    end
    --处理极端情况，活动持续时间不足1小时
    if self.m_iEndTime - iCurTime < 3600 then
        self:AddGameEndCb()
    end
end

--后台推送消息
function CHuodong:BackendUpdate(mInfo)
    self:Dirty()
    -- local mOld = self.m_mBackendInfo
    local mOld = table_deep_copy(self.m_mBackendInfo)
    self.m_mBackendInfo = mInfo
    local bOut = self:JudgeOutTeam(mOld.out_team, mInfo.out_team)
    self:JudgeDeleteGame(mOld.delete_game, mInfo.delete_game)
    local lUpdate = self:JudgeUpdateGame(mOld.games, mInfo.games)
    if next(lUpdate) then
        self:DealUpdateGame(lUpdate)
        self:DealTitle(lUpdate)
        self:RefreshRank()
    end
    -- self.m_mBackendInfo = mInfo
    self:RefreshAllPlayer(REFRESHTYPE.REFRESH, bOut)
end

function CHuodong:RefreshAllPlayer(iType, bOut)
    local func = function (iPid)
        local oPlayer = global.oWorldMgr:GetOnlinePlayerByPid(iPid)
        if not oPlayer then return end
        if iType == REFRESHTYPE.START then
            self:GS2CWorldCupState(oPlayer)
            self:GS2CWorldCupSingleInfo(oPlayer)
            self:GS2CWorldCupSingleGuessInfo(oPlayer)
            self:GS2CWorldCupChampionInfo(oPlayer)
        else
            self:GS2CWorldCupSingleInfo(oPlayer)
            if bOut then
                self:GS2CWorldCupChampionInfo(oPlayer)
            end
        end
    end
    local lAllOnlinePid = table_key_list(global.oWorldMgr:GetOnlinePlayerList())
    global.oToolMgr:ExecuteList(lAllOnlinePid, 100, 1000, 0, "WorldCupGameStart", func)
end

function CHuodong:JudgeOutTeam(lOld, lNew)
    local bOut = false
    lOld = lOld or {}
    lNew = lNew or {}
    if #lOld == #lNew then return bOut end
    local mOldTeam = table_deep_copy(self.m_mOutTeamInfo)
    self.m_mOutTeamInfo = {}
    for _, iTeamId in pairs(lNew) do
        self.m_mOutTeamInfo[iTeamId] = true
        if not mOldTeam[iTeamId] then
            bOut = true
        end
    end
    return bOut
end

function CHuodong:JudgeDeleteGame(lOld, lNew)
    lOld = lOld or {}
    lNew = lNew or {}
    if #lOld == #lNew then return end
    for _, iGameId in pairs(lNew) do
        if not self.m_mDelGameInfo[iGameId] then
            local mGameInfo = self.m_mAllGameInfo[iGameId]
            if mGameInfo then
                self:Dirty()
                self:DealDeleteGame(iGameId)
                self.m_mDelGameInfo[iGameId] = mGameInfo      
                self.m_mAllGameInfo[iGameId] = nil
            end
        end
    end
end

--被取消的比赛,退回竞猜消耗
function CHuodong:DealDeleteGame(iGameId)
    local mConfig = self:GetConfig()
    local iDelMail = mConfig.delete_game_mail
    local mGameInfo = self.m_mGuessTeam[iGameId] or {}
    for iPid, _ in pairs(mGameInfo) do
        local iCost = self:GetGameCost(COSTTYPE.SINGLE, iGameId)
        local sSid = string.format("1002(Value=%d)", iCost)
        local oItem = global.oItemLoader:ExtCreate(sSid)
        oItem:Bind(iPid)
        self:SendMail(iPid, iDelMail, {items = {oItem}}) 
        self.m_mGuessTeam[iGameId][iPid] = nil
        self.m_mGuessPlayer[iPid].all_guess[iGameId] = nil
    end
end

--判断那些赛程信息更新了结果
function CHuodong:JudgeUpdateGame(lOld, lNew)
    lOld = lOld or {}
    lNew = lNew or {}
    local lUpdate = {}
    for _, mNewGame in pairs(lNew) do
        local iGameId = mNewGame.id
        self.m_mAllGameInfo[iGameId] = table_deep_copy(mNewGame)
        if mNewGame.phase == 6 then --决赛开始时间
            self.m_iFinalStartTime = mNewGame.start_time
        end
        for _, mOldGame in pairs(lOld) do
            if mNewGame.id == mOldGame.id and
                mNewGame.status == GAMESTATUS.END and 
                mNewGame.status ~= mOldGame.status then
                table.insert(lUpdate, {
                    game_id = mNewGame.id,
                    win_team = mNewGame.win_team,
                    phase = mNewGame.phase, 
                })
            end
        end
    end
    return lUpdate
end

function CHuodong:DealUpdateGame(lUpdate)
    for _, mData in pairs(lUpdate) do
        local iGameId = mData.game_id
        local iWinTeam = mData.win_team
        local iPhase = mData.phase
        local mGuessInfo = self.m_mGuessTeam[iGameId] or {}
        for iPid, iGuessGame in pairs(mGuessInfo) do
            if iWinTeam == iGuessGame then
                self:DealGuessSuccess(iPid, iGameId, iPhase)
            else
                self:DealReward(iPid, iGameId, iPhase, REWARDTYPE.SINGLE_FAIL)
            end

            --支持队伍胜利
            local mGameInfo = self:GetGameInfo(iGameId)
            local iSupportTeam = self.m_mSupportPlayer[iPid]
            if mGameInfo and mGameInfo.win_team > 0 and mGameInfo.win_team == iSupportTeam then
                self:DealReward(iPid, iGameId, iPhase, REWARDTYPE.SUPPORT_SUC)
            end
            self:PushDataToRank(iPid)
        end
    end
end

function CHuodong:DealTitle(lUpdate)
    for _, mData in pairs(lUpdate) do
        local iGameId = mData.game_id
        local mGuessInfo = self.m_mGuessTeam[iGameId] or {}
        for iPid, iGuessGame in pairs(mGuessInfo) do
            self:DealMulTimesTitle(iPid)
        end
    end
end

--猜中单场
function CHuodong:DealGuessSuccess(iPid, iGameId, iPhase)
    self:DealReward(iPid, iGameId, iPhase, REWARDTYPE.SINGLE_SUC)
    self:Dirty()
    local mGuessInfo = self.m_mGuessPlayer[iPid]
    assert(mGuessInfo)
    mGuessInfo.guess_suc_num = mGuessInfo.guess_suc_num + 1
end

function CHuodong:DealMulTimesTitle(iPid)
    local mGuessInfo = self.m_mGuessPlayer[iPid]
    local iAllTimes = self:CalAllEndCount(iPid)
    local iGuessSucTimes = mGuessInfo.guess_suc_num
    local iGuessFailTimes = iAllTimes - iGuessSucTimes

    local mTitleInfo = self.m_mTitleInfo[iPid] or {suc = {}, fail = {}}
    local mSucConfig = self:GetSucTitleConfig()
    for iTimes, mData in pairs(mSucConfig) do
        if iGuessSucTimes >= iTimes and not mTitleInfo.suc[iTimes] then
            global.oTitleMgr:AddTitle(iPid, mData.title_id, mData.title)
            mTitleInfo.suc[iTimes] = true
        end
    end

    local mFailConfig = self:GetFailTitleConfig()
    for iTimes, mData in pairs(mFailConfig) do
        if iGuessFailTimes >= iTimes and not mTitleInfo.fail[iTimes] then
            global.oTitleMgr:AddTitle(iPid, mData.title_id, mData.title)
            mTitleInfo.fail[iTimes] = true
        end
    end
    self:Dirty()
    self.m_mTitleInfo[iPid] = mTitleInfo
end

function CHuodong:DealReward(iPid, iGameId, iPhase, iType)
    local mConfig = self:GetConfig()
    local mCostConfig = self:GetCostConfig()
    local mPhase = mCostConfig[iPhase]
    assert(mPhase)
    local mTeamConfig = self:GetTeamConfig()
    local mGameInfo = self:GetGameInfo(iGameId)
    if not mGameInfo then return end

    local iWinTeam = mGameInfo.win_team
    local sHomeTeam = self:GetTeamName(mGameInfo.home_team)
    local sAwayTeam = self:GetTeamName(mGameInfo.away_team)

    local iReward, iMailId, mFormat
    if iType == REWARDTYPE.SINGLE_SUC then
        iMailId = mConfig.single_suc_mail
        iReward = mPhase.single_suc_reward
        mFormat = {
            hometeam = sHomeTeam,
            awayteam = sAwayTeam,
        }
        local sWinTeam = "平局"
        if iWinTeam > 0 then
            sWinTeam = self:GetTeamName(iWinTeam)
        end
        mFormat.winteam = sWinTeam
    elseif iType == REWARDTYPE.SINGLE_FAIL then
        iMailId = mConfig.single_fail_mail
        iReward = mPhase.single_fail_reward
        mFormat = {
            hometeam = sHomeTeam,
            awayteam = sAwayTeam,
        }
        local sLoseTeam = "平局"
        if iWinTeam == mGameInfo.home_team then
            sLoseTeam = sAwayTeam
        elseif iWinTeam == mGameInfo.away_team then
            sLoseTeam = sHomeTeam
        end
        mFormat.loseteam = sLoseTeam
    elseif iType == REWARDTYPE.SUPPORT_SUC then
        iMailId = mConfig.support_suc_mail
        iReward = mPhase.support_suc
        mFormat = { team = self:GetTeamName(iWinTeam) }
    end

    if iMailId and iReward and mFormat then
        local lItems = self:GetRewardItem(iReward)
        local mData, sName = global.oMailMgr:GetMailInfo(iMailId)
        if iType == REWARDTYPE.SUPPORT_SUC then
            sName = global.oToolMgr:FormatColorString(sName, mFormat)
        end
        mData.context = global.oToolMgr:FormatColorString(mData.context, mFormat)
        global.oMailMgr:SendMailNew(0, sName, iPid, mData, { items = lItems })
    end    
end

function CHuodong:GetRewardItem(iReward)
    local lItems = {}
    local mReward = self:GetRewardData(iReward)

    local mItems  = mReward.item
    for _, iItemRewardIdx in ipairs(mItems) do
        local mRewardInfo = self:GetItemRewardData(iItemRewardIdx)
        if mRewardInfo then
            local mItemInfo = self:ChooseRewardKey(nil, mRewardInfo, iItemRewardIdx, {})
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

function CHuodong:GameStart()
    record.info(string.format("%s GameStart",self.m_sName))
    self:Dirty()
    self.m_iVersion = self.m_iVersion + 1
    self.m_iState = STATUS.START
    
    self:LogState()
    self:ClearRank()
    self:RefreshAllPlayer(REFRESHTYPE.START)
end

function CHuodong:GameEnd()
    record.info(string.format("%s GameEnd", self.m_sName))
    self:Dirty()
    self.m_iState = STATUS.END
    self:LogState()
    self:ClearRank()
    self:BroadcastProto("GS2CWorldCupState", { state = self:GetGameState() })
end

function CHuodong:LogState()
    local mLogData = {
        state = self:GetGameState(),
        version = self.m_iVersion,
    }
    record.log_db("huodong", "worldcup_state", mLogData)
end

--推送到排行榜
function CHuodong:PushDataToRank(iPid)
    local mGuessInfo = self.m_mGuessPlayer[iPid]
    assert(mGuessInfo)
    if mGuessInfo.all_guess_num <= 0 then return end

    local iRate = self:CalSucRate(iPid)
    local mData = {
        rank_name = "worldcup",
        rank_data = {
            pid = iPid,
            name = mGuessInfo.player_name,
            school = mGuessInfo.school,
            suc_count = mGuessInfo.guess_suc_num,
            suc_rate = iRate,
            last_time = mGuessInfo.last_time,
        }
    }
    interactive.Send(".rank", "rank", "PushDataToRank", mData)
end

function CHuodong:CalSucRate(iPid)
    local iRate = 0
    local iAllGuess = self:CalAllEndCount(iPid)
    local mGuessInfo = self.m_mGuessPlayer[iPid]
    if iAllGuess > 0 and mGuessInfo then
        iRate = math.floor(mGuessInfo.guess_suc_num/iAllGuess*100)
    end
    return iRate
end

function CHuodong:CalAllEndCount(iPid)
    local iAllGuess = 0
    local mGuessInfo = self.m_mGuessPlayer[iPid]
    if mGuessInfo then
        local mAllGuess = mGuessInfo.all_guess or {}
        for iGameId, mData in pairs(mAllGuess) do
            local mGame = self:GetGameInfo(iGameId)
            if mGame and mGame.status == GAMESTATUS.END then
                iAllGuess = iAllGuess + 1
            end
        end
    end
    return iAllGuess
end

function CHuodong:ClearRank()
    local mData = {
        cmd = "CleanRank",
        data = { idx = 225 }
    }
    interactive.Send(".rank", "rank", "Forward", mData)
end

function CHuodong:RefreshRank()
    local mData = {
        rank_name = "worldcup"
    }
    interactive.Send(".rank", "rank", "RefreshWorldCup", mData)
end

function CHuodong:IsHuodongOpen()
    return self:GetGameState() == STATUS.START
end

function CHuodong:GetGameInfo(iGameId)
    return self.m_mAllGameInfo[iGameId]
end

function CHuodong:TryInitGuessInfo(oPlayer)
    local iPid = oPlayer:GetPid()
    if self.m_mGuessPlayer[iPid] then return end

    self:Dirty()
    self.m_mGuessPlayer[iPid] = {
        all_guess_num = 0, --竞猜总次数
        guess_suc_num = 0, --竞猜猜中次数
        all_guess = {}, --竞猜所有场次记录
        last_time = get_time(), --最后一次竞猜时间
        player_name = oPlayer:GetName(),
        school = oPlayer:GetSchool(),
    }
end

function CHuodong:GetGameCost(iCostType, iGameId)
    local mConfig = self:GetCostConfig()
    local iCost = 0
    if iCostType == COSTTYPE.SINGLE then
        local mGameInfo = self:GetGameInfo(iGameId)
        local iPhase = mGameInfo.phase
        local mPhaseConfig = mConfig[iPhase]
        iCost = mPhaseConfig.single
    elseif iCostType == COSTTYPE.SUPPORT_CANCEL then
        local iPhase = self.m_mBackendInfo and self.m_mBackendInfo.phase or 1
        local mPhaseConfig = mConfig[iPhase]
        iCost = mPhaseConfig.champion_cancel
    end
    return iCost
end

function CHuodong:GiveTeamFansTitle(iPid, iTeam)
    local mConfig = self:GetConfig()
    local iTitle = mConfig.team_fans_title
    local mCountry = self:GetTeamConfig()[iTeam]
    local sCountry = mCountry.country
    local sTitle = string.format("%s队球迷", sCountry)
    global.oTitleMgr:AddTitle(iPid, iTitle, sTitle)
end

function CHuodong:RemoveTeamFansTitle(iPid)
    local mConfig = self:GetConfig()
    local iTitle = mConfig.team_fans_title
    global.oTitleMgr:RemoveOneTitle(iPid, iTitle)
end

function CHuodong:C2GSWorldCupSingle(oPlayer, iGameId, iTeamId)
    local bIsOpen = global.oToolMgr:IsSysOpen("WORLDCUP_CHAMPION", oPlayer, true) 
    if not bIsOpen then return end
    if not self:IsHuodongOpen() then return end

    local iPid = oPlayer:GetPid()
    local mGameInfo = self:GetGameInfo(iGameId)
    if not mGameInfo then return end

    if get_time() >= mGameInfo.start_time or mGameInfo.status ~= GAMESTATUS.NOSTART then
        global.oNotifyMgr:Notify(iPid, self:GetTextData(1004))
        return
    end

    local mSingleGame = self.m_mGuessTeam[iGameId] or {}
    if mSingleGame[iPid] then
        global.oNotifyMgr:Notify(iPid, self:GetTextData(1003))
        return
    end

    --队伍待定
    if mGameInfo.home_team == 0 or mGameInfo.away_team == 0 then
        global.oNotifyMgr:Notify(iPid, self:GetTextData(1002))
        return
    end

    --没有平局,但却支持了平局
    if mGameInfo.has_match == 2 and iTeamId == 0 then
        return
    end
    
    self:Dirty()
    local iCost = self:GetGameCost(COSTTYPE.SINGLE, iGameId)
    if not oPlayer:ValidSilver(iCost) then return end
    oPlayer:ResumeSilver(iCost, "世界杯单场竞猜")

    --记录球队的支持玩家
    mSingleGame[iPid] = iTeamId
    self.m_mGuessTeam[iGameId] = mSingleGame

    --记录玩家的支持球队
    self:TryInitGuessInfo(oPlayer)
    local mGuessInfo = self.m_mGuessPlayer[iPid]
    mGuessInfo.all_guess_num = mGuessInfo.all_guess_num + 1
    mGuessInfo.all_guess[iGameId] = {
        guess_team = iTeamId,
        create_time = get_time()
    }
    mGuessInfo.last_time = get_time()
    self.m_mGuessPlayer[iPid] = mGuessInfo
    -- self:PushDataToRank(iPid)
    self:GS2CWorldCupSingleGuessInfoUnit(oPlayer, iGameId)
    global.oNotifyMgr:Notify(iPid, self:GetTextData(1006))  
end

function CHuodong:C2GSWorldCupChampion(oPlayer, iType, iTeamId)
    local bIsOpen = global.oToolMgr:IsSysOpen("WORLDCUP_CHAMPION", oPlayer, true) 
    if not bIsOpen then return end
    if not self:IsHuodongOpen() then return end

    if iType == 1 then --支持
        self:SupportChampionTeam(oPlayer, iType, iTeamId)
    else
        self:CancelSupportChampionTeam(oPlayer, iType, iTeamId)
    end
end

function CHuodong:IsTeamPlaying(iTeamId)
    local bPlaying = false
    local iCurTime = get_time()
    for _, mGame in pairs(self.m_mBackendInfo.games or {}) do
        if mGame.status ~= GAMESTATUS.END and mGame.home_team == iTeamId or mGame.away_team == iTeamId then
            local iStartTime = mGame.start_time
            if iCurTime >= iStartTime then
                bPlaying = true
                break
            end
        end
    end
    return bPlaying
end

function CHuodong:SupportChampionTeam(oPlayer, iType, iTeamId)
    local sKey = "WorldCupChampion"
    local iPid = oPlayer:GetPid()

    if self.m_mSupportPlayer[iPid] then 
        global.oNotifyMgr:Notify(iPid, self:GetTextData(1008))  
        return 
    end

    local iFinalTime = self.m_iFinalStartTime
    if iFinalTime > 0 and get_time() >= iFinalTime then
        global.oNotifyMgr:Notify(iPid, self:GetTextData(1004))  
        return 
    end

    if self:IsTeamPlaying(iTeamId) then
        global.oNotifyMgr:Notify(iPid, self:GetTextData(1009))
        return
    end

    if self.m_mOutTeamInfo[iTeamId] then
        global.oNotifyMgr:Notify(iPid, self:GetTextData(1010))
        return
    end

    self:Dirty()
    local mSupport = self.m_mSupportTeam[iTeamId]
    if not mSupport then
        mSupport = {
            num = 0,
            players = {},
        }
    end
    mSupport.players[iPid] = true
    mSupport.num = mSupport.num + 1
    self.m_mSupportTeam[iTeamId] = mSupport
    self.m_mSupportPlayer[iPid] = iTeamId

    self:GiveTeamFansTitle(iPid, iTeamId)
    self:GS2CWorldCupChampionInfo(oPlayer)
    self:BroadcastTeamSupportInfo(iTeamId)
end

function CHuodong:CancelSupportChampionTeam(oPlayer, iType, iTeamId)
    local sKey = "WorldCupChampion"
    local iPid = oPlayer:GetPid()
    if not self.m_mSupportPlayer[iPid] then return end
        
    local mSupport = self.m_mSupportTeam[iTeamId]
    assert(mSupport and mSupport.num > 0)

    local iFinalTime = self.m_iFinalStartTime
    if iFinalTime > 0 and get_time() >= iFinalTime then
        global.oNotifyMgr:Notify(iPid, self:GetTextData(1011))  
        return 
    end

    local iCost = self:GetGameCost(COSTTYPE.SUPPORT_CANCEL)
    if not oPlayer:ValidGoldCoin(iCost) then return end
    oPlayer:ResumeGoldCoin(iCost, "世界杯取消球队支持")
    
    self:Dirty()
    mSupport.num = mSupport.num - 1
    mSupport.players[iPid] = nil
    self.m_mSupportPlayer[iPid] = nil

    self:RemoveTeamFansTitle(iPid)
    self:GS2CWorldCupChampionInfo(oPlayer)
    self:BroadcastTeamSupportInfo(iTeamId)
end

function CHuodong:C2GSWorldCupHistory(oPlayer)
    self:GS2CWorldCupHistory(oPlayer)
end

function CHuodong:GS2CWorldCupState(oPlayer)
    local mNet = {
        state = self:GetGameState()
    }
    oPlayer:Send("GS2CWorldCupState", mNet)
end

--赛程信息
function CHuodong:GS2CWorldCupSingleInfo(oPlayer)
    local mGameInfo = self.m_mBackendInfo.games or {}
    local mNet = {
        phase = self.m_mBackendInfo.phase or 1,
        games = mGameInfo
    }
    oPlayer:Send("GS2CWorldCupSingleInfo", mNet)
end

--玩家竞猜信息
function CHuodong:GS2CWorldCupSingleGuessInfo(oPlayer)
    local iPid = oPlayer:GetPid()
    local mData = {}
    local mGuessInfo = self.m_mGuessPlayer[iPid]
    if mGuessInfo then
        local mCurGames = self.m_mBackendInfo.games or {}
        --获取当前显示赛程自己的竞猜信息
        for _, mGameData in pairs(mCurGames) do
            local iGameId = mGameData.id
            local mGuess = mGuessInfo.all_guess[iGameId]
            if mGuess then
                table.insert(mData, {
                    id = iGameId,
                    guess_team = mGuess.guess_team,
                })
            end
        end
    end
    local mNet = {
        guess_info = mData
    }
    oPlayer:Send("GS2CWorldCupSingleGuessInfo", mNet)
end

--刷新玩家单场比赛的竞猜信息
function CHuodong:GS2CWorldCupSingleGuessInfoUnit(oPlayer, iGameId)
    local iPid = oPlayer:GetPid()
    local mSingInfo = self.m_mGuessTeam[iGameId]
    if mSingInfo and mSingInfo[iPid] then
        local mNet = {
            guess_info_unit = {
                id = iGameId,
                guess_team = mSingInfo[iPid]
            }
        }
        oPlayer:Send("GS2CWorldCupSingleGuessInfoUnit", mNet)
    end
end

--单场比赛的 竞猜历史记录
function CHuodong:GS2CWorldCupHistory(oPlayer)
    local iPid = oPlayer:GetPid()
    local mInfo = self.m_mGuessPlayer[iPid]
    local mAllGuss = mInfo and mInfo.all_guess or {}

    local mHistory = {}
    for iGameId, mData in pairs(mAllGuss) do
        local mGame = self:GetGameInfo(iGameId)
        if mGame then
            local mTmp = {
                id = mGame.id,
                home_team = mGame.home_team,
                away_team = mGame.away_team,
                win_team = mGame.win_team,
                guess_team = mData.guess_team,
                create_time = mData.create_time,
            }
            table.insert(mHistory, mTmp)
        end
    end

    local iRate = 0
    local iGuessSucNum = 0
    if mInfo and mInfo.all_guess_num > 0 then 
        iRate = self:CalSucRate(iPid)
        iGuessSucNum = mInfo.guess_suc_num
    end
    
    local mNet = {
        history = mHistory,
        suc_count = iGuessSucNum,
        suc_rate = iRate,
    }
    oPlayer:Send("GS2CWorldCupHistory", mNet)
end

function CHuodong:GS2CWorldCupChampionInfo(oPlayer)
    local lSupport = {}
    for iTeamId, mSupport in pairs(self.m_mSupportTeam) do
        table.insert(lSupport, {
            team_id = iTeamId,
            num = mSupport.num,
        })
    end

    local lOutTeam = {}
    for iTeamId, _ in pairs(self.m_mOutTeamInfo) do
        table.insert(lOutTeam, iTeamId)
    end

    local sKey = "WorldCupChampion"
    local iSupportTeam = self.m_mSupportPlayer[oPlayer:GetPid()] or 0
    local mNet = {
        support_team = iSupportTeam,
        out_team = lOutTeam,
        support_info = lSupport,
    }
    oPlayer:Send("GS2CWorldCupChampionInfo", mNet)
end

function CHuodong:BroadcastProto(sProto, mNet)
    interactive.Send(".broadcast", "channel", "SendChannel", {
        message = sProto,
        id = 1,
        type = gamedefines.BROADCAST_TYPE.WORLD_TYPE,
        data = mNet,
        exclude = {},
    })
end

function CHuodong:BroadcastTeamSupportInfo(iTeamId)
    local mNet = {
        support_info_unit = {
            team_id = iTeamId,
            num = self.m_mSupportTeam[iTeamId].num
        }
    }
    self:BroadcastProto("GS2CWorldCupChampionInfoUnit", mNet)
end

function CHuodong:GetConfig()
    local mData = res["daobiao"]["huodong"][self.m_sName]["config"][1]
    assert(mData, string.format("CHuodong %s GetConfig error ", self.m_sName))
    return mData
end

function CHuodong:GetTeamConfig()
    local mData = res["daobiao"]["huodong"][self.m_sName]["country"]
    assert(mData, string.format("CHuodong %s GetTeamConfig error", self.m_sName))
    return mData
end

function CHuodong:GetTeamName(iTeamId)
    local mData = self:GetTeamConfig()[iTeamId]
    assert(mData, string.format("CHuodong %s GetTeamName error %s ", self.m_sName, iTeamId))
    return mData.country
end

function CHuodong:GetCostConfig()
    local mData = res["daobiao"]["huodong"][self.m_sName]["phase_cost"]
    assert(mData, string.format("CHuodong %s GetCostConfig error", self.m_sName))
    return mData
end

function CHuodong:GetSucTitleConfig()
    local mData = res["daobiao"]["huodong"][self.m_sName]["suc_times_title"]
    assert(mData, string.format("CHuodong %s GetCostConfig error", self.m_sName))
    return mData
end

function CHuodong:GetFailTitleConfig()
    local mData = res["daobiao"]["huodong"][self.m_sName]["fail_times_title"]
    assert(mData, string.format("CHuodong %s GetCostConfig error", self.m_sName))
    return mData
end

function CHuodong:TestOp(iFlag, mArgs)
    local oChatMgr = global.oChatMgr
    local oNotifyMgr = global.oNotifyMgr
    local oWorldMgr = global.oWorldMgr
    local iPid = mArgs[#mArgs]
    local oPlayer = oWorldMgr:GetOnlinePlayerByPid(iPid)

    local mCommand={
        "100 指令查看",
        "101 清空数据 \nhuodongop worldcup 101",
    }
    if iFlag == 100 then
        for idx=#mCommand,1,-1 do
            oChatMgr:HandleMsgChat(oPlayer,mCommand[idx])
        end
        oNotifyMgr:Notify(iPid,"请看消息频道咨询指令")
    elseif iFlag == 101 then
        self:Dirty()
        self.m_iFinalStartTime = 0
        self.m_mBackendInfo = {}
        self.m_mAllGameInfo = {}
        self.m_mDelGameInfo = {}
        self.m_mOutTeamInfo = {}
        self.m_mGuessTeam = {}
        self.m_mGuessPlayer = {}
        self.m_mSupportTeam = {}
        self.m_mSupportPlayer = {}
        self.m_mTitleInfo = {}
    elseif iFlag == 102 then
        local iSec = mArgs.sec or 3
        self.m_iEndTime = get_time() + iSec
        self:AddGameEndCb()
        local sMsg = string.format("%d秒后关闭活动", iSec)
        oNotifyMgr:Notify(iPid, sMsg)
    elseif iFlag == 103 then
        local iFinalTime = self.m_iFinalStartTime
        local sMsg = string.format("%d", iFinalTime)
        oNotifyMgr:Notify(iPid, sMsg)
    elseif iFlag == 104 then
        self.m_iFinalStartTime = 0
        self:Dirty()
    end
end
