local global = require "global"
local res = require "base.res"
local interactive = require "base.interactive"
local record = require "public.record"
local extend = require "base.extend"
local gamedefines = import(lualib_path("public.gamedefines"))
local huodongbase = import(service_path("huodong.huodongbase"))
local match = import(service_path("huodong.orgwar.match"))
local uimgr = import(service_path("huodong.orgwar.uimgr"))
local handleteam = import(service_path("team.handleteam"))


STATE_ID = 1005
STATUS_WIN = 1
STATUS_LOSE = 2
-----------TODO list------------
--3.内存泄露
--4.跨场景归队
--------------------------------
function NewHuodong(sHuodongName)
    return CHuodong:New(sHuodongName)
end

CHuodong = {}
CHuodong.__index = CHuodong
CHuodong.m_sTempName = "帮派竞赛"
inherit(CHuodong, huodongbase.CHuodong)

function CHuodong:New(sHuodongName)
    local o = super(CHuodong).New(self, sHuodongName)
    return o
end

function CHuodong:Init()
    self.m_iScheduleID = 1025
    self.m_iStartTime = 0
    self.m_iEndTime = 0
    self.m_iActionTime = 0
    self.m_iForbidTime = 0
    self.m_mPid2LeaveOrgTime = {}   --离帮时间
    self.m_mOrg2PrepareRoom = {}    --准备厅
    self.m_mOrg2FightScene = {}     --战斗场景
    self.m_mPid2ActionPoint = {}    --行动力
    self.m_mPid2WarScore = {}       --积分
    self.m_mOrgScore = {}           --帮派积分
    self.m_mOrg2NpcId = {}

    self.m_oMatchCtrl = match.NewMatch()
    self.m_oUIMgr = uimgr.NewUIMgr()
    self:InitGameTime()
end

function CHuodong:AfterLoad()
    global.oOrgMgr:AddEvent(self, gamedefines.EVENT.LEAVE_ORG, function(iEvent, mData)
        self:UpdatePidLeaveOrgTime(mData)
    end)

    self:InitGameTime()
end

function CHuodong:NeedSave()
    return true
end

function CHuodong:IsOpenDay()
    local iWeekDay = get_weekday(self:GetSysTime())
    local mTimeConfig = self:GetTimeConfig()
    for _, mConfig in pairs(mTimeConfig[iWeekDay] or {}) do
        if mConfig.event == "game_start1" and self:GetData("match_info_week_2") then
            return true
        end
        if mConfig.event == "game_start2" and self:GetData("match_info_week_4") then
            return true
        end
    end
    return false
end

function CHuodong:Save()
    local mData = {}

    local mMatchWeek2 = self:GetData("match_info_week_2")
    if mMatchWeek2 then
        local mInfo = {}
        mInfo.match_forward = table_to_db_key(mMatchWeek2.match_forward or {})
        mInfo.match_reverse = table_to_db_key(mMatchWeek2.match_reverse or {})
        mInfo.match_ret = list_generate(mMatchWeek2.match_ret or {}, db_key)
        mData.match_info_week_2 = mInfo
    end

    local mResult2 = self:GetData("result2")
    if mResult2 then
        mData.result2 = table_to_db_key(mResult2)
    end
    local mResult4 = self:GetData("result4")
    if mResult4 then
        mData.result4 = table_to_db_key(mResult4)
    end
   
    local mMatchWeek4 = self:GetData("match_info_week_4")
    if mMatchWeek4 then
        local mInfo = {}
        mInfo.match_forward = table_to_db_key(mMatchWeek4.match_forward or {})
        mInfo.match_reverse = table_to_db_key(mMatchWeek4.match_reverse or {})
        mInfo.match_ret = list_generate(mMatchWeek4.match_ret or {}, db_key)
        mData.match_info_week_4 = mInfo
    end

    mData.pid2leaveorgtime = table_to_db_key(self.m_mPid2LeaveOrgTime)
    return mData
end

function CHuodong:Load(m)
    if not m then return end

    local mMatchWeek2 = m.match_info_week_2
    if mMatchWeek2 then
        local mInfo = {}
        mInfo.match_forward = table_to_int_key(mMatchWeek2.match_forward or {})
        mInfo.match_reverse = table_to_int_key(mMatchWeek2.match_reverse or {})
        mInfo.match_ret = list_generate(mMatchWeek2.match_ret or {}, tonumber)
        self:SetData("match_info_week_2", mInfo)
    end

    local mResult2 = m.result2
    if mResult2 then
        self:SetData("result2", table_to_int_key(mResult2))
    end
    local mResult4 = m.result4
    if mResult4 then
        self:SetData("result4", table_to_int_key(mResult4))
    end

    local mMatchWeek4 = m.match_info_week_4
    if mMatchWeek4 then
        local mInfo = {}
        mInfo.match_forward = table_to_int_key(mMatchWeek4.match_forward or {})
        mInfo.match_reverse = table_to_int_key(mMatchWeek4.match_reverse or {})
        mInfo.match_ret = list_generate(mMatchWeek4.match_ret or {}, tonumber)
        self:SetData("match_info_week_4", mInfo)
    end

    self.m_mPid2LeaveOrgTime = table_to_int_key(m.pid2leaveorgtime or {})
end

function CHuodong:MergeFrom(mFromData)
    self:Dirty()
    for sPid, iTime in pairs(mFromData.pid2leaveorgtime or {}) do
        self.m_mPid2LeaveOrgTime[tonumber(sPid)] = iTime
    end
    local lKeyList = {"result2", "result4"}
    for _, sKey in ipairs(lKeyList) do
        if mFromData[sKey] then
            self:MergeResult(sKey, mFromData[sKey])
        end
    end

    local lKeyList = {"match_info_week_2", "match_info_week_4"}
    for _, sKey in ipairs(lKeyList) do
        if mFromData[sKey] then
            self:MergeMatchList(sKey, mFromData[sKey])
        end
    end
    return true
end

function CHuodong:MergeMatchList(sKey, mFrom)
    local mMatch = self:GetData(sKey, {})

    local mMatchForward = mMatch.match_forward or {}
    for sOrg1, iOrg2 in pairs(mFrom.match_forward or {}) do
        mMatchForward[tonumber(sOrg1)] = iOrg2
    end
    if next(mMatchForward) then
        mMatch.match_forward = mMatchForward
    end

    local mMatchReverse = mMatch.match_reverse or {}
    for sOrg1, iOrg2 in pairs(mFrom.match_reverse or {}) do
        mMatchReverse[tonumber(sOrg1)] = iOrg2
    end
    if next(mMatchReverse) then
        mMatch.match_reverse = mMatchReverse
    end

    if #(mMatch.match_ret or {}) <= 0 then
        local lRet = {}
        for _, sOrg in pairs(mFrom.match_ret or {}) do
            table.insert(lRet, tonumber(sOrg))
        end
        mMatch.match_ret = lRet
    else
        local iOrg1 = mMatch.match_ret[1]
        if sKey == "match_info_week_2" then
            --周二表不处理
            self:SetData(sKey, mMatch)
            return
        end
        if #(mFrom.match_ret or {}) > 0 then
            local iOrg2 = tonumber(mFrom.match_ret[1])
            mMatch.match_forward[iOrg1] = iOrg2
            mMatch.match_reverse[iOrg2] = iOrg1
            mMatch.match_ret = {}
        end
    end
    self:SetData(sKey, mMatch)
end

function CHuodong:MergeResult(sKey, mFrom)
    local mResult = self:GetData(sKey, {})
    for sOrg, iResult in pairs(mFrom) do
        mResult[tonumber(sOrg)] = iResult
    end
    self:SetData(sKey, mResult)
end

---------------time ctrl------------------
function CHuodong:NewHour(mNow)
    self:InitGameTime(mNow)

    --强行修正日程状态 修复性代码
    local iWeekDay = get_weekday(self:GetSysTime())
    local mTimeConfig = self:GetTimeConfig()
    if not mTimeConfig[iWeekDay] then
        self:SetHuodongState(gamedefines.ACTIVITY_STATE.STATE_HIDE)
    end
end

function CHuodong:InitGameTime(mNow)
    if not self:IsLoaded() then return end

    if not global.oToolMgr:IsSysOpen("ORGWAR") then
        return
    end

    local iWeekDay = mNow and mNow.date.wday or get_weekday(self:GetSysTime())
    local mTimeConfig = self:GetTimeConfig()
    local lConfig = mTimeConfig[iWeekDay]
    if not lConfig then return end

    for _, mConfig in ipairs(lConfig) do
        if mConfig.event == "gen_match_list1" then
            self:GenMatchList1(mConfig)
        elseif mConfig.event == "game_start1" then
            if self:GetData("match_info_week_2") then
                self:TryGameStart(mConfig)
            else
                record.info("not match_info_week_2")
                self:StartReplaceHD(iWeekDay)
            end
        elseif mConfig.event == "gen_match_list2" then
            self:GenMatchList2(mConfig)
        elseif mConfig.event == "game_start2" then
            if self:GetData("match_info_week_4") then
                self:TryGameStart(mConfig)
            else
                record.info("not match_info_week_4")
                self:StartReplaceHD(iWeekDay)
            end
        else
            record.info("orgwar event %s not config", mConfig.event)
        end
    end
end

function CHuodong:AnalyseTime(sTime)
    local mCurrDate = os.date("*t", self:GetSysTime())
    local hour,min= sTime:match('^(%d+)%:(%d+)')
    return os.time({
        year = mCurrDate.year,
        month = mCurrDate.month,
        day = mCurrDate.day,
        hour = tonumber(hour),
        min = tonumber(min),
        sec = 0,
    })
end

function CHuodong:StartReplaceHD(iWeekDay)
    local mReplace = self:GetReplaceHD()[iWeekDay]
    if not mReplace then return end

    local sHuodong = mReplace.replace_hd
    local oHuodong = global.oHuodongMgr:GetHuodong(sHuodong)
    if oHuodong then
        mReplace = formula_string(mReplace.replace_info, {})
        safe_call(oHuodong.ReplaceStart, oHuodong, mReplace)
    else
        record.info("can't start replace hd" .. sHuodong)
    end
end

---------------- process ---------------------
function CHuodong:GenMatchList1(mConfig, bForce)
    record.info("orgwar genmatchlist for week2")
    if not bForce and math.abs(self:GetSysTime() - self:AnalyseTime(mConfig.start_time)) > 5 then
        return
    end
    local mSignin = self:GetSigninConfig()
    local lOrgSign = self.m_oMatchCtrl:GenSignInList()
    if table_count(lOrgSign) < mSignin.org_num_min then
        self:SysAnnounce(1052)
        return
    end
    local mMatchInfo = self.m_oMatchCtrl:GenMatchListWeek_2(lOrgSign)
    self:SetData("match_info_week_2", mMatchInfo)
    self:Dirty()

    self:SysAnnounce(1053)

    local mMail, sName = global.oMailMgr:GetMailInfo(3015)
    for _, iOrg in pairs(lOrgSign) do
        local oOrg = global.oOrgMgr:GetNormalOrg(iOrg)
        self:OrgMailNotify(oOrg, sName, mMail)
    end
    local mLogData = {
        match_info_week_2 = mMatchInfo,
        name = "周二对战表",
    }
    record.log_db("huodong", "orgwar", {info = mLogData})
end

function CHuodong:GenMatchList2(mConfig)
    record.info("orgwar genmatchlist for week4")
    local iStartTime = self:AnalyseTime(mConfig.start_time)
    local iDeltaTime = iStartTime - self:GetSysTime()
    if iDeltaTime > 0 and iDeltaTime < 3600 then
        self:DelTimeCb("DoGenMatchList2")
        self:AddTimeCb("DoGenMatchList2", iDeltaTime*1000, function()
            self:DoGenMatchList2()
        end)
    end
end

function CHuodong:DoGenMatchList2()
    record.info("orgwar dogenmatchlist for week4")
    self:DelTimeCb("DoGenMatchList2")

    local mResult2 = self:GetData("result2")
    if not mResult2 then return end

    local mSignin = self:GetSigninConfig()
    local lWinnerList, lLoserList = {}, {}
    for iOrg, iStatus in pairs(mResult2) do
        if not global.oOrgMgr:GetNormalOrg(iOrg) then
            goto continue
        end
        if iStatus == STATUS_WIN then
            table.insert(lWinnerList, iOrg)
        else
            table.insert(lLoserList, iOrg)
        end
        ::continue::
    end

    local mMatchInfo2 = self:GetData("match_info_week_2", {})
    local lRet = mMatchInfo2.match_ret or {}

    local mLogData = {
        win_list = lWinnerList,
        lose_list = lLoserList,
        ret_list = lRet,
        name = "周四对战表数据源",
    }
    record.log_db("huodong", "orgwar", {info = mLogData})
    if #lWinnerList + #lLoserList + #lRet < mSignin.org_num_min then
        --TODO check ruler how to process
        return
    end

    local mMatchInfo = self.m_oMatchCtrl:GenMatchListWeek_4(lWinnerList, lLoserList, lRet)
    self:SetData("match_info_week_4", mMatchInfo)
    self:Dirty()

    local mMail, sName = global.oMailMgr:GetMailInfo(3016)
    for _, iOrg in ipairs(lWinnerList) do
        local oOrg = global.oOrgMgr:GetNormalOrg(iOrg)
        self:OrgMailNotify(oOrg, sName, mMail)
    end
    for _, iOrg in ipairs(lLoserList) do
        local oOrg = global.oOrgMgr:GetNormalOrg(iOrg)
        self:OrgMailNotify(oOrg, sName, mMail)
    end

    local mLogData = {
        match_info_week_4 = mMatchInfo,
        name = "周四对战表",
    }
    record.log_db("huodong", "orgwar", {info=mLogData})
end

function CHuodong:TryGameStart(mConfig)
    record.info("orgwar try game start")
    local iStartTime = self:AnalyseTime(mConfig.start_time)
    local iCurrTime = self:GetSysTime()
    local iDeltaTime = iStartTime - iCurrTime

    self.m_iStartTime = iStartTime
    self.m_iEndTime = self.m_iStartTime + mConfig.continue_time*60
    self.m_iActionTime = self.m_iStartTime + mConfig.action_time*60
    self.m_iForbidTime = self.m_iStartTime + mConfig.forbid_enter*60

    if iDeltaTime > 0 and iDeltaTime < 3600 then
        local iTipTimeShift1 = iStartTime + mConfig.tip_time_shift1*60 - iCurrTime
        self:DelTimeCb("NotifyGameStart1")
        if iTipTimeShift1 > 0 then
            self:AddTimeCb("NotifyGameStart1", iTipTimeShift1*1000, function()
                self:NotifyGameStartStep(1)
            end)
        end
        local iTipTimeShift2 = iStartTime + mConfig.tip_time_shift2*60 - iCurrTime
        self:DelTimeCb("NotifyGameStart2")
        if iTipTimeShift2 > 0 then
            self:AddTimeCb("NotifyGameStart2", iTipTimeShift2*1000, function()
                self:NotifyGameStartStep(2)
            end)
        end
        
        self:DelTimeCb("GameStart")
        self:AddTimeCb("GameStart", (iStartTime-iCurrTime)*1000, function()
            self:GameStart(mConfig)
        end)
    end
    if self:IsOpenDay() and not self.m_sEvent then
        self:SetHuodongState(gamedefines.ACTIVITY_STATE.STATE_READY)
    end
end

function CHuodong:GameStart(mConfig)
    record.info("orgwar gamestart")
    self:DelTimeCb("GameStart")
    self:DelTimeCb("GameOver")
    self:DelTimeCb("GameAction")
    self:DelTimeCb("GameNotify")
    self:DelTimeCb("NotifyGameStart1")
    self:DelTimeCb("NotifyGameStart2")

    local iContinueTime = mConfig.continue_time*60
    self.m_iStartTime = self:GetSysTime()
    self.m_iEndTime = self.m_iStartTime + iContinueTime
    self.m_iActionTime = self.m_iStartTime + mConfig.action_time*60
    self.m_iForbidTime = self.m_iStartTime + mConfig.forbid_enter*60
    self.m_sEvent = mConfig.event
    self.m_mPid2ActionPoint = {}    --行动力
    self.m_mPid2WarScore = {}       --积分
    self.m_mOrgScore = {}           --帮派积分
    self.m_mOrg2FightScene = {}

    self:AddTimeCb("GameOver", iContinueTime*1000, function()
        self:GameOver(mConfig)
    end)
    self:AddTimeCb("GameAction", (self.m_iActionTime-self.m_iStartTime)*1000, function()
        self:GameAction()
    end)
    self:AddTimeCb("GameNotify", math.max(1, (self.m_iActionTime-self.m_iStartTime-300)*1000), function()
        self:SysAnnounce(1117)
    end)

    self:SetHuodongState(gamedefines.ACTIVITY_STATE.STATE_START)
    self:NotifyGameStartStep(3)
    self:TryStartRewardMonitor()
end

function CHuodong:GameAction()
    record.info("orgwar gameaction")
    self:DelTimeCb("GameAction")

    for iOrg, iScene in pairs(self.m_mOrg2PrepareRoom) do
        local oScene = global.oSceneMgr:GetScene(iScene)
        if not oScene then goto continue end

        local iX, iY = global.oSceneMgr:RandomPos2(oScene:MapId())
        local mPlayers = table_copy(oScene.m_mPlayers)
        for iPid, _ in pairs(mPlayers) do
            local oPlayer = global.oWorldMgr:GetOnlinePlayerByPid(iPid)
            if oPlayer and (oPlayer:IsSingle() or oPlayer:IsTeamLeader()) then
                self:InitActionPoint(oPlayer)
                self:DoTransferFightScene(oPlayer)
            end
            self:Notify(iPid, 1040)
        end
        ::continue::
    end
end

function CHuodong:GameOver(mConfig)
    record.info("orgwar gameover")
    self:DelTimeCb("GameStart")
    self:DelTimeCb("GameOver")
    self:DelTimeCb("GameAction")
    self:DelTimeCb("NotifyGameStart1")
    self:DelTimeCb("NotifyGameStart2")

    self:SetHuodongState(gamedefines.ACTIVITY_STATE.STATE_END)
    self:ReleaseOrgPrepareRoom()

    for iOrg, iScene in pairs(self.m_mOrg2FightScene) do
        local oScene = global.oSceneMgr:GetScene(iScene)
        safe_call(self.GameOverByScene, self, oScene)
    end

    self:GameOverForEmpty()

    self:ReInitData()
    self:TryStopRewardMonitor()
end

function CHuodong:GameOverForEmpty()
    record.info("game over for empty")
    local mMatch
    if self.m_sEvent == "game_start1" then
        mMatch = self:GetData("match_info_week_2", {})
    elseif self.m_sEvent == "game_start2" then
        mMatch = self:GetData("match_info_week_4", {})
    end
    if not mMatch then return end

    local mResult = self:GetOrgResult()
    local mConfig = self:GetConfig()
    for iOrg1, iOrg2 in pairs(mMatch.match_forward or {}) do
        if not mResult[iOrg1] and not mResult[iOrg2] then
            local oOrg1 = global.oOrgMgr:GetNormalOrg(iOrg1)
            local oOrg2 = global.oOrgMgr:GetNormalOrg(iOrg2)
            self:OrgChannel(iOrg1, 3015)
            self:OrgChannel(iOrg2, 3015)
            self:AddOrgIdToList(iOrg1, iOrg2, 1)
            self:SysAnnounce(1057, {orgname={oOrg1:GetName(), oOrg2:GetName()}})
            oOrg1:AddCash(mConfig.lose_org_cash)
            oOrg2:AddCash(mConfig.lose_org_cash)
            self:RewardOrgPrestige(oOrg1, mConfig.lose_org_prestige)
            self:RewardOrgPrestige(oOrg2, mConfig.lose_org_prestige)
        end
    end

    for _, iOrg in pairs(mMatch.match_ret or {}) do
        local oOrg = global.oOrgMgr:GetNormalOrg(iOrg)
        if not oOrg then goto continue end

        self:OrgChannel(iOrg, 3016)
        oOrg:AddCash(mConfig.win_org_cash)
        --self:AddOrgIdToList(iOrg)
        ::continue::
    end
end

function CHuodong:ReInitData()
    self.m_iStartTime = 0
    self.m_iEndTime = 0
    self.m_iActionTime = 0
    self.m_iForbidTime = 0
    self.m_sEvent = nil

    local iWeekDay = get_weekday(self:GetSysTime())
    if iWeekDay >= 4 then
        self:SetData("match_info_week_2", nil)
        self:SetData("result2", nil)
        self:SetData("match_info_week_4", nil)
        self:SetData("result4", nil)
        self:Dirty()
    end
end

function CHuodong:CheckOrgWarWinner(oScene)
    if self.m_iForbidTime <= 0 or oScene.m_bEnd then return end
    local iCurrTime = self:GetSysTime()
    if iCurrTime > self.m_iForbidTime and iCurrTime <= self.m_iEndTime then
        local mResult = self:CountOrgMember(oScene)
        safe_call(self.GameOverByScene, self, oScene, mResult)
    end
end

function CHuodong:GameOverByScene(oScene, mCount)
    if not oScene or oScene.m_bEnd then return end
    
    oScene.m_bEnd = true

    local iScene = oScene:GetSceneId()
    local iDelay = self.m_iTestRemove or 15*60*1000
    oScene:DelTimeCb("ReleaseFightScene")
    oScene:AddTimeCb("ReleaseFightScene", iDelay, function()
        self:ReleaseFightScene(iScene)
    end)

    local iWinner, iLoser, iBalance
    local mConfig = self:GetConfig()
    local iOrg1, iOrg2 = table.unpack(oScene.m_lOrgList)
    assert(iOrg1 and iOrg2)

    self:ForceWarEnd(oScene)

    if not mCount then 
        local iOrgScore1 = self:GetOrgScoreByOrgId(iOrg1, 0)
        local iOrgScore2 = self:GetOrgScoreByOrgId(iOrg2, 0)
        if iOrgScore1 == iOrgScore2 then
            mCount = self:CountOrgMember(oScene)
        elseif iOrgScore1 > iOrgScore2 then
            iWinner, iLoser = iOrg1, iOrg2
        else
            iWinner, iLoser = iOrg2, iOrg1
        end
    end
    if not iWinner or not iLoser then
        if mCount[iOrg1] == mCount[iOrg2] then
            iBalance = 1
        elseif mCount[iOrg1] > mCount[iOrg2] then
            iWinner, iLoser = iOrg1, iOrg2
        else
            iWinner, iLoser = iOrg2, iOrg1
        end
    end

    if iBalance then
        local oOrg1 = global.oOrgMgr:GetNormalOrg(iOrg1)
        local oOrg2 = global.oOrgMgr:GetNormalOrg(iOrg2)
        self:OrgChannel(iOrg1, 3015)
        self:OrgChannel(iOrg2, 3015)
        self:SysAnnounce(1057, {orgname={oOrg1:GetName(), oOrg2:GetName()}})
        oOrg1:AddCash(mConfig.lose_org_cash)
        oOrg2:AddCash(mConfig.lose_org_cash)
        self:RewardOrgPrestige(oOrg1, mConfig.lose_org_prestige)
        self:RewardOrgPrestige(oOrg2, mConfig.lose_org_prestige)
        self:AddOrgIdToList(iOrg1, iOrg2, iBalance)
    else
        local oWinOrg = global.oOrgMgr:GetNormalOrg(iWinner)
        local oLoseOrg = global.oOrgMgr:GetNormalOrg(iLoser)
        self:OrgChannel(iWinner, 3013)
        self:OrgChannel(iLoser, 3014)
        local mReplace = {
            orgname={oWinOrg:GetName(), oLoseOrg:GetName(), oWinOrg:GetName()}
        }
        self:SysAnnounce(1056, mReplace)
        oWinOrg:AddCash(mConfig.win_org_cash)
        oLoseOrg:AddCash(mConfig.lose_org_cash)
        self:RewardOrgPrestige(oWinOrg, mConfig.win_org_prestige)
        self:RewardOrgPrestige(oLoseOrg, mConfig.lose_org_prestige)
        self:AddOrgIdToList(iWinner, iLoser)
    end

    oScene:DelTimeCb("RefreshBox")
    oScene:AddTimeCb("RefreshBox", 60*1000, function()
        self:RefreshBox(iScene, iWinner, iBalance)
    end)
end

function CHuodong:AddOrgIdToList(iWinner, iLoser, iBalance)
    local mIndex = {
        game_start1 = "result2",
        game_start2 = "result4",
    }
    local sKey = mIndex[self.m_sEvent]
    if not sKey then return end

    if iBalance == 1 then
        local mResult = self:GetData(sKey, {})
        if not mResult[iWinner] then
            mResult[iWinner] = STATUS_LOSE
        end
        if not mResult[iLoser] then
            mResult[iLoser] = STATUS_LOSE
        end
        self:SetData(sKey, mResult)
        self:Dirty()
    else
        local mResult = self:GetData(sKey, {})
        if not mResult[iWinner] then
            mResult[iWinner] = STATUS_WIN
        end
        if not mResult[iLoser] then
            mResult[iLoser] = STATUS_LOSE
        end
        self:SetData(sKey, mResult)
        self:Dirty()
    end
    local mLogData = {
        winner = iWinner,
        loser = iLoser,
        balance = iBalance,
        name = "帮派结果",
    }
    record.log_db("huodong", "orgwar", {info=mLogData})
end

function CHuodong:GetOrgResult()
    local mIndex = {
        game_start1 = "result2",
        game_start2 = "result4",
    }
    local sKey = mIndex[self.m_sEvent]
    if not sKey then return end

    return self:GetData(sKey, {})
end

function CHuodong:RefreshBox(iScene, iWinner, iBalance)
    record.info("refreshbox")
    local oScene = global.oSceneMgr:GetScene(iScene)
    if not oScene or not oScene.m_bEnd then return end

    local iNum = 0
    if iBalance then
        iNum = table_count(oScene.m_mPlayers)
    else
        local mCount = self:CountOrgMember(oScene)
        iNum = mCount[iWinner] or 0
    end

    if iNum <= 0 then return end

    local mConfig = self:GetConfig()
    local iTotal = formula_string(mConfig.gold_box_num, {num=iNum})
    for i = 1, iTotal do
        local oNpc = self:CreateTempNpc(5002)
        local iX, iY = global.oSceneMgr:RandomPos2(oScene:MapId())
        oNpc.m_mPosInfo.x = iX
        oNpc.m_mPosInfo.y = iY
        self:Npc_Enter_Scene(oNpc, iScene)
    end
    local iTotal = formula_string(mConfig.silver_box_num, {num=iNum})
    for i = 1, iTotal do
        local oNpc = self:CreateTempNpc(5003)
        local iX, iY = global.oSceneMgr:RandomPos2(oScene:MapId())
        oNpc.m_mPosInfo.x = iX
        oNpc.m_mPosInfo.y = iY
        self:Npc_Enter_Scene(oNpc, iScene)
    end
end

function CHuodong:NotifyGameStartStep(iStep)
    record.info("orgwar notify game start step "..iStep)
    self:DelTimeCb(string.format("NotifyGameStart%s", iStep))
    local mStep2Announce = {
        [1] = 3002,
        [2] = 3001,
        [3] = 3003,
    }
    local iAnnounce = mStep2Announce[iStep]
    if not iAnnounce then return end

    --TODO check all org or register org ???

    local sMsg = self:GetTextData(iAnnounce)
    local mOrgList = global.oOrgMgr:GetNormalOrgs()
    for iOrg, oOrg in pairs(mOrgList or {}) do
        global.oChatMgr:SendMsg2Org(sMsg, iOrg)
    end
end

function CHuodong:Notify(iPid, iChat, mReplace)
    local oNotifyMgr = global.oNotifyMgr
    local sMsg = self:GetTextData(iChat)
    if mReplace then
        sMsg = global.oToolMgr:FormatColorString(sMsg, mReplace)
    end
    oNotifyMgr:Notify(iPid, sMsg)
end

function CHuodong:OrgChannel(iOrg, iChat, mReplace)
    local sMsg = self:GetTextData(iChat)
    if mReplace then
        sMsg = global.oToolMgr:FormatColorString(sMsg, mReplace)
    end
    global.oChatMgr:SendMsg2Org(sMsg, iOrg)
end

function CHuodong:SysAnnounce(iChat, mReplace)
    local mInfo = res["daobiao"]["chuanwen"][iChat]
    if not mInfo then return end

    local sMsg, iHorse = mInfo.content, mInfo.horse_race
    if mReplace then
        sMsg = global.oToolMgr:FormatColorString(sMsg, mReplace)
    end
    global.oChatMgr:HandleSysChat(sMsg, gamedefines.SYS_CHANNEL_TAG.RUMOUR_TAG, iHorse)
end

function CHuodong:OrgMailNotify(oOrg, sName, mMail)
    if not oOrg then return end

    for iPid, _ in pairs(oOrg.m_oMemberMgr:GetMemberMap()) do
        global.oMailMgr:SendMail(0, sName, iPid, mMail, 0)
    end
end

function CHuodong:SetHuodongState(iState)
    if global.oHuodongMgr:QueryHuodongState(self.m_sName) == iState then
        return
    end
    local sTime = self:GetStartTime()
    global.oHuodongMgr:SetHuodongState(self.m_sName, self.m_iScheduleID, iState, sTime)
end

function CHuodong:GetStartTime()
    return get_time_format_str(self.m_iStartTime, "%H:%M")
end

function CHuodong:InHuodongTime()
    local iCurrTime = self:GetSysTime()
    return iCurrTime > self.m_iStartTime and iCurrTime < self.m_iEndTime
end

function CHuodong:GetSysTime()
    return get_time() + (self.m_iTestDeltaTime or 0)
end

function CHuodong:PackSimpleInfo(oPlayer)
    local oOrg = oPlayer:GetOrg()
    if not oOrg then return end

    local iRet, iEnemy = self:GetEnemyOrgId(oOrg:OrgID())
    if iRet <= 0 then return end

    if not iEnemy then return "轮空" end

    local oEnemy = global.oOrgMgr:GetNormalOrg(iEnemy)
    return "对战帮派: "..oEnemy:GetName()    
end

function CHuodong:GetTimeConfig()
    return res["daobiao"]["huodong"][self.m_sName]["time_ctrl"]
end

function CHuodong:GetSigninConfig()
    return res["daobiao"]["huodong"][self.m_sName]["signin"][1]
end

function CHuodong:GetConfig()
    return res["daobiao"]["huodong"][self.m_sName]["config"]
end

function CHuodong:GetSceneData(iScene)
    local mData = res["daobiao"]["huodong"][self.m_sName]
    return mData["scene"][iScene]
end

function CHuodong:GetReplaceHD()
    return res["daobiao"]["huodong"][self.m_sName]["replace_hd"]
end


---------------npc click --------------------
function CHuodong:do_look(oPlayer, npcobj)
    if not npcobj or not npcobj.m_iEvent then
        return
    end
    if npcobj.m_iEvent == 5002 or npcobj.m_iEvent == 5003 then
        local oScene = oPlayer.m_oActiveCtrl:GetNowScene()
        local iOrg = oPlayer:GetOrgID()
        if not extend.Array.member(oScene.m_lOrgList or {}, iOrg) then
            self:Notify(oPlayer:GetPid(), 2004)
            return
        end
        if not oPlayer:IsSingle() and table_count(oPlayer:GetTeamMember()) > 1 then
            local oTeam = oPlayer:HasTeam()
            oTeam:ShortLeave(oPlayer:GetPid())
        end
    end
    super(CHuodong).do_look(self, oPlayer, npcobj)
end

function CHuodong:ValidEnterPrepareRoom(oPlayer)
    if not self:InHuodongTime() then
        return 1005
    end
    local iOrg = oPlayer:GetOrgID()
    if not iOrg or iOrg <= 0 then return 1041 end

    local iRet, iEnemy = self:GetEnemyOrgId(iOrg)
    if iRet <= 0 then return 1006 end

    if iRet == 2 or iRet == 4 then
        return 1042
    end

    local oOrg = oPlayer:GetOrg()
    if self.m_oUIMgr:GetOrgStatus(oOrg, get_weekday(self:GetSysTime())) > 0 then
        return 1048
    end

    local iCurrTime = self:GetSysTime()
    if iCurrTime >= self.m_iForbidTime then
        return 1011
    end

    local lPlayer = {oPlayer:GetPid()}
    if oPlayer:IsTeamLeader() then
        lPlayer = oPlayer:GetTeamMember()
    end

    local lName = self:FilterPlayer(lPlayer, function(oPlayer)
        if oPlayer:GetOrgID() ~= iOrg then
            return oPlayer:GetName()
        end
    end)
    if lName and next(lName) then
        return 1008, {name=table.concat(lName, "、")}
    end
    local lName = self:FilterPlayer(lPlayer, function(oPlayer)
        local oOrg = oPlayer:GetOrg()
        local oMember = oOrg.m_oMemberMgr:GetMember(oPlayer:GetPid())
        if not oMember then return oPlayer:GetName() end
    end)
    if lName and next(lName) then
        return 1043, {name=table.concat(lName, "、")}
    end
    local lName = self:FilterPlayer(lPlayer, function(oTarget)
        if oTarget and not global.oToolMgr:IsSysOpen("ORGWAR", oTarget, true) then
            return oTarget:GetName()
        end
    end)
    if lName and next(lName) then
        return 1009, {name=table.concat(lName, "、")}
    end
    local mConfig = self:GetConfig()
    local lName = self:FilterPlayer(lPlayer, function(oTarget)
        local iTarget = oTarget:GetPid()
        local iLeaveTime = self:GetLeaveOrgTimeByPid(iTarget)
        if iLeaveTime and iCurrTime-iLeaveTime <= mConfig.leave_org_limit*3600 then
            return oTarget:GetName()
        end
    end)
    if lName and next(lName) then
        return 1010, {name=table.concat(lName, "、")}
    end
    local lName = self:FilterPlayer(lPlayer, function(oTarget)
        local iTarget = oTarget:GetPid()
        local iActionPoint = self:GetActionPointByPid(iTarget)
        if iActionPoint and iActionPoint <= 0 then
            return oTarget:GetName()
        end
    end)
    if lName and next(lName) then
        return 1012, {name=table.concat(lName, "、")}
    end
    local lName = self:FilterPlayer(lPlayer, function(oTarget)
        local oOrg = oTarget:GetOrg()
        local oMember = oOrg.m_oMemberMgr:GetMember(oTarget:GetPid())
        if self:GetSysTime() - oMember:GetJoinTime() < mConfig.join_time_limit*60*60 then
            return oTarget:GetName()
        end
    end)
    if lName and next(lName) then
        return 2003, {name=table.concat(lName, "、")}
    end
    return 1
end

function CHuodong:FilterPlayer(lPlayer, func)
    local lResult = {}
    for _, iPid in ipairs(lPlayer) do
        local oPlayer = global.oWorldMgr:GetOnlinePlayerByPid(iPid)
        if oPlayer then
            local rRet = func(oPlayer)
            if rRet then table.insert(lResult, rRet) end
        end
    end
    return lResult
end

function CHuodong:GetEnemyOrgId(iOrg, iCmdWeekDay)
    local iWeekDay = iCmdWeekDay or get_weekday(self:GetSysTime())
    if iWeekDay <= 2 then
        local mMatchInfo = self:GetData("match_info_week_2")
        if not mMatchInfo then return -1 end
        
        local iTarget
        iTarget = table_get_depth(mMatchInfo, {"match_forward", iOrg})
        if iTarget then
            return 1, iTarget
        end
        iTarget = table_get_depth(mMatchInfo, {"match_reverse", iOrg})
        if iTarget then
            return 1, iTarget
        end
        if table_in_list(mMatchInfo.match_ret or {}, iOrg) then
            return 2
        end
    elseif iWeekDay <= 4 then
        local mMatchInfo = self:GetData("match_info_week_4")
        if not mMatchInfo then return -1 end

        local iTarget
        iTarget = table_get_depth(mMatchInfo, {"match_forward", iOrg})
        if iTarget then
            return 3, iTarget
        end
        iTarget = table_get_depth(mMatchInfo, {"match_reverse", iOrg})
        if iTarget then
            return 3, iTarget
        end
        if table_in_list(mMatchInfo.match_ret or {}, iOrg) then
            return 4
        end
    end
    return 0
end

function CHuodong:TryEnterPrepareRoom(oPlayer, bIgnore)
    local iRet, mReplace = self:ValidEnterPrepareRoom(oPlayer)
    if iRet ~= 1 then
        self:Notify(oPlayer:GetPid(), iRet, mReplace)
        return
    end
    local iCurrTime = self:GetSysTime()
    if not bIgnore and iCurrTime>self.m_iActionTime and iCurrTime<self.m_iForbidTime then
        local mData = {
            sContent = self:GetTextData(1013),
        }
        mData = global.oCbMgr:PackConfirmData(nil, mData)
        local func = function(oPlayer, mData)
            if mData.answer == 1 then
                self:TryEnterPrepareRoom(oPlayer, true)
            end
        end
        global.oCbMgr:SetCallBack(oPlayer:GetPid(), "GS2CConfirmUI", mData, nil, func)
        return
    end

    self:InitActionPoint(oPlayer, bIgnore==true)
    self:DoEnterPrepareRoom(oPlayer)
end

function CHuodong:InitActionPoint(oPlayer, bHalf)
    local lPlayer = {}
    if oPlayer:IsSingle() then
        lPlayer = {oPlayer:GetPid()}
    else
        local oTeam = oPlayer:HasTeam()
        lPlayer = oTeam:GetTeamMember()
    end
    
    local mConfig = self:GetConfig()
    local sFormula = mConfig.action_point
    for _, iPid in ipairs(lPlayer) do
        local oTarget = global.oWorldMgr:GetOnlinePlayerByPid(iPid)
        
        if not self:GetActionPointByPid(iPid) then
            local mEnv = {lv=oTarget:GetGrade()}
            local iAdd = formula_string(sFormula, mEnv)
            self:AddActionPointByPid(iPid, iAdd, true)
        end

        if bHalf and not oTarget.m_oThisTemp:Query("half_action") then
            oTarget.m_oThisTemp:Set("half_action", 1, 3*3600)
            local iPoint = self:GetActionPointByPid(iPid)
            local iAdd = math.floor(iPoint / 2)
            self:AddActionPointByPid(iPid, -iAdd, true)
        end
    end
end

function CHuodong:DoEnterPrepareRoom(oPlayer)
    local iOrg = oPlayer:GetOrgID()
    local iScene = self:GetPrepareRoomIdByOrg(iOrg)
    if not iScene then
        local oScene = self:CreatePrepareRoom(iOrg)
        iScene = oScene:GetSceneId()
        self:SetPrepareRoomIdByOrg(iOrg, iScene)

        local oNpc = self:CreateTempNpc(5001)
        self:Npc_Enter_Scene(oNpc, iScene)
        self:SetNpcIdByOrg(iOrg, oNpc:ID())
    end
    local oScene = global.oSceneMgr:GetScene(iScene)
    if not oScene then return end

    local iX, iY = global.oSceneMgr:RandomPos2(oScene:MapId())
    local mPos = {x = iX, y = iY}
    global.oSceneMgr:DoTransfer(oPlayer, iScene, mPos)
end

function CHuodong:OtherScript(iPid, npcobj, s, mArgs)
    local oPlayer = global.oWorldMgr:GetOnlinePlayerByPid(iPid)
    if not oPlayer then return end

    if s == "$transfer_fight" then
        self:TryTransferFightScene(oPlayer, npcobj)
        return true
    elseif s == "$transfer_home" then
        self:TryTransferHome(oPlayer)
        return true
    else
        return super(CHuodong).OtherScript(self, iPid, npcobj, s, mArgs)
    end
end

function CHuodong:TryTransferFightScene(oPlayer, npcobj)
    local iRet, mReplace = self:ValidTransferFightScene(oPlayer)
    if iRet ~= 1 then
        self:Notify(oPlayer:GetPid(), iRet, mReplace)
        return
    end
    self:DoTransferFightScene(oPlayer)
end
    
function CHuodong:DoTransferFightScene(oPlayer)
    local iOrg = oPlayer:GetOrgID()
    local iRet, iEnemy = self:GetEnemyOrgId(iOrg)
    if not iEnemy then return end

    local iScene = self:GetFightSceneIdByOrg(iOrg)
    if not iScene then
        local oScene = self:CreateFightScene(iOrg, iEnemy)
        iScene = oScene:GetSceneId()
        self:SetFightSceneIdByOrg(iOrg, iScene)
        self:SetFightSceneIdByOrg(iEnemy, iScene)

        local oNpc = self:CreateTempNpc(5004)
        self:Npc_Enter_Scene(oNpc, iScene)
        
        local oNpc = self:CreateTempNpc(5005)
        self:Npc_Enter_Scene(oNpc, iScene)
    end
    local oScene = global.oSceneMgr:GetScene(iScene)
    if not oScene then return end

    local iSide = oScene.m_mSide[iOrg]
    local iX, iY = global.oSceneMgr:RandomPos2(oScene:MapId())
    if iSide == 1 then
        iX, iY = math.random(2, 8), math.random(5, 11)
    elseif iSide == 2 then
        iX, iY = math.random(26, 32), math.random(18, 24)
    end
    local mPos = {x = iX, y = iY}
    global.oSceneMgr:DoTransfer(oPlayer, iScene, mPos)
end

function CHuodong:ValidTransferFightScene(oPlayer)
    local iCurrTime = self:GetSysTime()
    if iCurrTime < self.m_iActionTime then
        return 1015
    end
    if iCurrTime > self.m_iEndTime then
        return 1016
    end
    local iRet, iEnemy = self:GetEnemyOrgId(iOrg)
    if iRet <= 0 then
        return 1006
    end
    if not iEnemy then
        return 1039
    end

    local oScene = oPlayer.m_oActiveCtrl:GetNowScene()
    local iOrg = table.unpack(oScene.m_lOrgList or {})
    if not iOrg then return 1034 end

    local iFightScene = self:GetFightSceneIdByOrg(iOrg)
    if iFightScene then
        local oFightScene = global.oSceneMgr:GetScene(iFightScene)
        if oFightScene and oFightScene.m_bEnd then
            return 1045
        end
    end

    local lPlayer = {oPlayer:GetPid()}
    if oPlayer:IsTeamLeader() then
        lPlayer = oPlayer:GetTeamMember()
    end

    local oTeam = oPlayer:HasTeam()
    local lName = self:FilterPlayer(lPlayer, function(oPlayer)
        if oPlayer:GetOrgID() ~= iOrg then
            return oPlayer:GetName()
        end
    end)
    if lName and next(lName) then
        return 1017, {name=table.concat(lName, "、")}
    end

    local lName = self:FilterPlayer(lPlayer, function(oPlayer)
        local oOrg = oPlayer:GetOrg()
        local oMember = oOrg.m_oMemberMgr:GetMember(oPlayer:GetPid())
        if not oMember then return oPlayer:GetName() end
    end)
    if lName and next(lName) then
        return 1043, {name=table.concat(lName, "、")}
    end

    local lName = self:FilterPlayer(lPlayer, function(oPlayer)
        local iTarget = oPlayer:GetPid()
        local iPoint = self:GetActionPointByPid(iTarget)
        if not iPoint or iPoint <= 0 then
            return oPlayer:GetName()
        end
    end)
    if lName and next(lName) then
        return 1012, {name=table.concat(lName, "、")}
    end

    local mConfig = self:GetConfig()
    local lName = self:FilterPlayer(lPlayer, function(oTarget)
        local oOrg = oTarget:GetOrg()
        local oMember = oOrg.m_oMemberMgr:GetMember(oTarget:GetPid())
        if self:GetSysTime() - oMember:GetJoinTime() < mConfig.join_time_limit*60*60 then
            return oTarget:GetName()
        end
    end)
    if lName and next(lName) then
        return 2003, {name=table.concat(lName, "、")}
    end

    return 1
end

function CHuodong:TryTransferHome(oPlayer, bIgnore)
    if not bIgnore and self:GetSysTime() < self.m_iActionTime then
        local mData = {
            sContent = self:GetTextData(1033),
        }
        mData = global.oCbMgr:PackConfirmData(nil, mData)
        local func = function(oPlayer, mData)
            if mData.answer == 1 then
                self:TryTransferHome(oPlayer, true)
            end
        end
        global.oCbMgr:SetCallBack(oPlayer:GetPid(), "GS2CConfirmUI", mData, nil, func)
        return
    end
    
    local oScene = global.oSceneMgr:SelectDurableScene(101000)
    local iX, iY = global.oSceneMgr:RandomPos2(oScene:MapId())
    global.oSceneMgr:DoTransfer(oPlayer, oScene:GetSceneId(), {x=iX,y=iY})
end

function CHuodong:PlayerExpEffect()
    return false
end

--------------- scene -----------------------
function CHuodong:ReleaseOrgPrepareRoom()
    for iOrg, iScene in pairs(self.m_mOrg2PrepareRoom) do
        local iNpc = self.m_mOrg2NpcId[iOrg]
        local oNpc = self:GetNpcObj(iNpc)
        if oNpc then
            self:RemoveTempNpc(oNpc)
        end
        self.m_mOrg2NpcId[iOrg] = nil
        self.m_mSceneList[iScene] = nil
        global.oSceneMgr:RemoveScene(iScene)
    end
    self.m_mOrg2PrepareRoom = {}
end

function CHuodong:ReleaseFightScene(iScene)
    local oScene = global.oSceneMgr:GetScene(iScene)
    if oScene then
        oScene:DelTimeCb("ReleaseFightScene")
        self.m_mSceneList[iScene] = nil

        local lNpc = table_copy(oScene.m_mNpc or {})
        for iNpc, _ in pairs(lNpc) do
            local oNpc = self:GetNpcObj(iNpc)
            if oNpc then
                self:RemoveTempNpc(oNpc)
            end
        end

        local iOrg1, iOrg2 = table.unpack(oScene.m_lOrgList)
        if iOrg1 then
            self:SetFightSceneIdByOrg(iOrg1, nil)
        end
        if iOrg2 then
            self:SetFightSceneIdByOrg(iOrg2, nil)
        end

        global.oSceneMgr:RemoveScene(iScene)
    end
end

function CHuodong:GetPrepareRoomIdByOrg(iOrg)
    return self.m_mOrg2PrepareRoom[iOrg]
end

function CHuodong:SetPrepareRoomIdByOrg(iOrg, iScene)
    self.m_mOrg2PrepareRoom[iOrg] = iScene
end

function CHuodong:GetFightSceneIdByOrg(iOrg)
    return self.m_mOrg2FightScene[iOrg]
end

function CHuodong:SetFightSceneIdByOrg(iOrg, iScene)
    self.m_mOrg2FightScene[iOrg] = iScene
end

function CHuodong:SetNpcIdByOrg(iOrg, iNpc)
    self.m_mOrg2NpcId[iOrg] = iNpc
end

function CHuodong:GetNpcIdByOrg(iOrg)
    return self.m_mOrg2NpcId[iOrg]
end

function CHuodong:CreatePrepareRoom(iOrg)
    local mInfo = self:GetSceneData(1001)
    local mData ={
        map_id = mInfo.map_id,
        team_allowed = mInfo.team_allowed,
        deny_fly = mInfo.deny_fly,
        is_durable = mInfo.is_durable==1,
        has_anlei = mInfo.has_anlei == 1,
        url = {"huodong", self.m_sName, "scene", 1001},
    }
    local oScene = global.oSceneMgr:CreateVirtualScene(mData)
    oScene.m_lOrgList = {iOrg}
    oScene.m_HDName = self.m_sName

    local iScene = oScene:GetSceneId()
    self.m_mSceneList[iScene] = true

    local func1 = function(iEvent, mData)
        self:OnEnterPrepareRoom(mData)
    end
    oScene:AddEvent(self, gamedefines.EVENT.PLAYER_ENTER_SCENE, func1)
    oScene:AddEvent(self, gamedefines.EVENT.PLAYER_REENTER_SCENE, func1)
    local func2 = function(iEvent, mData)
        self:OnLeavePrepareRoom(mData)
    end
    oScene:AddEvent(self, gamedefines.EVENT.PLAYER_LEAVE_SCENE, func2)
   
    oScene:DelTimeCb("PrepareRoomRewardExp")
    oScene:AddTimeCb("PrepareRoomRewardExp", 5*60*1000, function()
        PrepareRoomRewardExp(iScene)
    end)
    return oScene
end

function CHuodong:OnChangeLeader(iPid)
    local oPlayer = global.oWorldMgr:GetOnlinePlayerByPid(iPid)
    if not oPlayer then return end

    local oScene = oPlayer.m_oActiveCtrl:GetNowScene()
    if not oScene then return end

    if not oPlayer:IsTeamLeader() then return end

    local oTeam = oPlayer:HasTeam()
    if oScene:GetVirtualGame() == "orgwar" then
        oTeam:AddServStateByArgs("in_orgwar")
    else
        oTeam:RemoveServState("in_orgwar")
    end
end

function CHuodong:OnEnterPrepareRoom(mData)
    local oPlayer, oScene = mData.player, mData.scene
    
    oPlayer:SetLogoutJudgeTime(-1)
    local iPid = oPlayer:GetPid()
    local mNet = {
        action_point = self:GetActionPointByPid(iPid),
        fight_time = self.m_iActionTime,
    }
    oPlayer:Send("GS2COrgWarEnterPrepareRoom", mNet)
    oPlayer.m_oRideCtrl:SetRideFly(0)

    local oTeam = oPlayer:HasTeam()
    if oTeam then
        oTeam:AddServStateByArgs("in_orgwar")
    end
end

function CHuodong:OnLeavePrepareRoom(mData)
    local oPlayer, oScene, iNewScene = mData.player, mData.scene, mData.new_scene
    if not iNewScene or oScene:GetSceneId() ~= iNewScene then
        oPlayer:SetLogoutJudgeTime()

        if oPlayer:IsTeamLeader() then
            local oTeam = oPlayer:HasTeam()
            oTeam:RemoveServState("in_orgwar")
        end
    end
end

function CHuodong:CreateFightScene(iOrg1, iOrg2)
    local mInfo = self:GetSceneData(1002)
    local mData ={
        map_id = mInfo.map_id,
        team_allowed = mInfo.team_allowed,
        deny_fly = mInfo.deny_fly,
        is_durable = mInfo.is_durable==1,
        has_anlei = mInfo.has_anlei == 1,
        url = {"huodong", self.m_sName, "scene", 1002},
    }
    local oScene = global.oSceneMgr:CreateVirtualScene(mData)
    local iScene = oScene:GetSceneId()
    self.m_mSceneList[iScene] = true

    local func1 = function(iEvent, mData)
        self:OnEnterFightScene(mData)
    end
    oScene:AddEvent(self, gamedefines.EVENT.PLAYER_ENTER_SCENE, func1)
    oScene:AddEvent(self, gamedefines.EVENT.PLAYER_REENTER_SCENE, func1)
    local func2 = function(iEvent, mData)
        self:OnLeaveFightScene(mData)
    end
    oScene:AddEvent(self, gamedefines.EVENT.PLAYER_LEAVE_SCENE, func2)

    oScene.ValidLeave = function(oSrcScene, oPlayer, oDstScene)
        return self:ValidLeaveFightScene(oSrcScene, oPlayer, oDstScene)
    end

    oScene.m_lOrgList = {iOrg1, iOrg2}
    oScene.m_HDName = self.m_sName
    oScene.m_bFight = true
    oScene.m_mSide = {[iOrg1] = 1, [iOrg2] = 2}

    oScene:DelTimeCb("CheckOrgResult")
    oScene:AddTimeCb("CheckOrgResult", 5*60*1000, function()
        CheckOrgResult(iScene)
    end)
    oScene:DelTimeCb("CheckInFightScene")
    oScene:AddTimeCb("CheckInFightScene", 5*60*1000, function()
        CheckInFightScene(iScene)
    end)

    return oScene
end

function CHuodong:ValidLeaveFightScene(oSrcScene, oPlayer, oDstScene)
--    local iCurrTime = self:GetSysTime()
--    if self.m_iForbidTime > 0 and iCurrTime > self.m_iForbidTime and iCurrTime < self.m_iEndTime then
--        if oPlayer:IsSingle() then
--            local mData = {
--                sContent = self:GetTextData(1021),
--            }
--            mData = global.oCbMgr:PackConfirmData(nil, mData)
--            local iDst = oDstScene and oDstScene:GetSceneId() or nil
--            local iSrc = oSrcScene:GetSceneId()
--            local func = function(oPlayer, mData)
--                self:TryLeaveFightScene(oPlayer, mData, iSrc, iDst)
--            end
--            global.oCbMgr:SetCallBack(oPlayer:GetPid(), "GS2CConfirmUI", mData, nil, func)
--            return false
--        end
--    end
    
    if oSrcScene:IsDenyFly(oPlayer, oDstScene:MapId()) then
        return false
    end

    return true
end

function CHuodong:OnEnterFightScene(mData)
    local oPlayer, oScene, iFrom = mData.player, mData.scene, mData.from_scene 
    
    oPlayer:SetLogoutJudgeTime(-1)
    local iPid = oPlayer:GetPid()
    local mNet = {
        action_point = self:GetActionPointByPid(iPid),
    }
    oPlayer:Send("GS2COrgWarEnterFightScene", mNet)

    global.oTitleMgr:ChangeToOrgTitle(iPid)

    oPlayer.m_oStateCtrl:RefreshMapFlag()
    oPlayer.m_oRideCtrl:SetRideFly(0)

    local oTeam = oPlayer:HasTeam()
    if oTeam then
        oTeam:AddServStateByArgs("in_orgwar")
    end
    if oScene:GetSceneId() ~= iFrom then
        self:Notify(oPlayer:GetPid(), 1047)
    end
end

function CHuodong:OnLeaveFightScene(mData)
    local oPlayer, oScene, iNewScene = mData.player, mData.scene, mData.new_scene
    if not iNewScene or oScene:GetSceneId() ~= iNewScene then
        oPlayer:SetLogoutJudgeTime()
        oPlayer.m_oThisTemp:Delete("in_fight_scene")

        if oPlayer:IsTeamLeader() then
            local oTeam = oPlayer:HasTeam()
            oTeam:RemoveServState("in_orgwar")
        end

        local mCount = self:CountOrgMember(oScene)
        for iOrg, iTotal in pairs(mCount) do
            if iTotal <= 0 then
                self:CheckOrgWarWinner(oScene)
                return
            end
        end
    end
end

function CHuodong:TryLeaveFightScene(oPlayer, mData, iSrc, iDst)
    if mData.answer ~= 1 then return end

    local oNowScene = oPlayer.m_oActiveCtrl:GetNowScene()
    if oNowScene:GetSceneId() ~= iSrc then return end
    
    if iDst then
        if oNowScene:GetSceneId() == iDst then return end
        local oDstScene = global.oSceneMgr:GetScene(iDst)
        if oDstScene then
            local iX, iY = global.oSceneMgr:RandomPos2(oDstScene:MapId())
            global.oSceneMgr:DoTransfer(oPlayer, iDst, {x=iX,y=iY})
        end
    end
end

function CHuodong:ValidEnterTeam(oPlayer, oLeader, iOP)
    self:Notify(oPlayer:GetPid(), 1020)
    return false
end

function CHuodong:CountOrgMember(oScene)
    local iOrg1, iOrg2 = table.unpack(oScene.m_lOrgList)
    local iNum1, iNum2 = 0, 0
    for iPid, _ in pairs(oScene.m_mPlayers) do
        local oPlayer = global.oWorldMgr:GetOnlinePlayerByPid(iPid)
        if not oPlayer then goto continue end
        local iOrg = oPlayer:GetOrgID()
        if not iOrg then goto continue end

        if iOrg1 == iOrg then iNum1 = iNum1+1 end
        if iOrg2 == iOrg then iNum2 = iNum2+1 end
        ::continue::
    end

    local mResult = {
        [iOrg1] = iNum1, [iOrg2] = iNum2,
    }
    return mResult
end

function CHuodong:UpdatePidLeaveOrgTime(mData)
    local oOrg, iPid = mData.org, mData.pid
    self.m_mPid2LeaveOrgTime[iPid] = self:GetSysTime()
    self:Dirty()
end

function CHuodong:GetLeaveOrgTimeByPid(iPid)
    return self.m_mPid2LeaveOrgTime[iPid]
end

function CHuodong:GetActionPointTable()
    return self.m_mPid2ActionPoint
end

function CHuodong:GetActionPointByPid(iPid, rDefault)
    return self.m_mPid2ActionPoint[iPid] or rDefault
end

function CHuodong:AddActionPointByPid(iPid, iAdd, bCheck)
    local iPoint = self:GetActionPointByPid(iPid, 0)
    local iPoint = math.max(0, iPoint+iAdd)
    self.m_mPid2ActionPoint[iPid] = iPoint

    if bCheck == true then
        self:OnAddActionPointByPid(iPid)
    end

    local mLogData = {
        pid = iPid,
        action_add = iAdd,
        action_now = iPoint,
        name = "行动力",
    }
    record.log_db("huodong", "orgwar", {info = mLogData})
end

function CHuodong:OnAddActionPointByPid(iPid)
    local oPlayer = global.oWorldMgr:GetOnlinePlayerByPid(iPid)
    if oPlayer and self:GetActionPointByPid(iPid, 0) <= 0 then
        local oScene = global.oSceneMgr:SelectDurableScene(101000)
        local iX, iY = global.oSceneMgr:RandomPos2(oScene:MapId())
        if oPlayer:IsSingle() then
            global.oSceneMgr:DoTransfer(oPlayer, oScene:GetSceneId(), {x=iX, y=iY})
            self:Notify(iPid, 1046)
            return
        end
        local oTeam = oPlayer:HasTeam()
        if oTeam:MemberSize() <= 1 then
            global.oSceneMgr:DoTransfer(oPlayer, oScene:GetSceneId(), {x=iX, y=iY})
            self:Notify(iPid, 1046)
        else
            oTeam:ShortLeave(iPid)
            global.oSceneMgr:DoTransfer(oPlayer, oScene:GetSceneId(), {x=iX, y=iY})
            self:Notify(iPid, 1046)
        end
    else
        local iPoint = self:GetActionPointByPid(iPid, 0)
        oPlayer:Send("GS2COrgWarRefreshActionPoint", {action_point=iPoint})
    end
end

function CHuodong:GetWarScoreTable()
    return self.m_mPid2WarScore
end

function CHuodong:GetWarScoreByPid(iPid, rDefault)
    return self.m_mPid2WarScore[iPid] or rDefault
end

function CHuodong:AddWarScoreByPid(iPid, iAdd)
    local iScore = self:GetWarScoreByPid(iPid, 0)
    local iNewScore = math.max(0, iScore + iAdd)
    if iNewScore ~= iScore then
        self.m_mPid2WarScore[iPid] = iNewScore
        local oPlayer = global.oWorldMgr:GetOnlinePlayerByPid(iPid)
        if oPlayer and oPlayer:GetOrgID() then
            self:BroadcastSceneWarScore(oPlayer:GetOrgID())
        end
    end
end

function CHuodong:GetOrgScoreTable()
    return self.m_mOrgScore
end

function CHuodong:GetOrgScoreByOrgId(iOrg, rDefault)
    return self.m_mOrgScore[iOrg] or rDefault
end

function CHuodong:AddOrgScoreByOrgId(iOrg, iAdd)
    local iScore = self:GetOrgScoreByOrgId(iOrg, 0)
    local iNewScore = math.max(0, iScore + iAdd)
    if iNewScore ~= iScore then
        self.m_mOrgScore[iOrg] = iNewScore
        self:BroadcastSceneWarScore(iOrg)
    end
end

function CHuodong:BroadcastSceneWarScore(iOrg)
    local iScene = self:GetFightSceneIdByOrg(iOrg)
    if not iScene then return end
    local oScene = global.oSceneMgr:GetScene(iScene)
    if not oScene then return end

    if not oScene:IsVirtual() then return end

    local lNetOrg = {}
    for _, iOrg in ipairs(oScene.m_lOrgList or {}) do
        local mOrg = self.m_oUIMgr:PackSimpleWarScoreList(iOrg)
        table.insert(lNetOrg, mOrg)
    end
    oScene:BroadcastMessage("GS2COrgWarOpenWarScoreUI", {org_list=lNetOrg})
end

--------------- fight -----------------------
function CHuodong:ValidStartFight(oPlayer, iTarget)
    if not iTarget then return 1035 end

    local oTarget = global.oWorldMgr:GetOnlinePlayerByPid(iTarget)
    if not oTarget then return 1035 end
    
    if not oPlayer:IsSingle() and not oPlayer:IsTeamLeader() then
        return 1023
    end

    local iOrg = oPlayer:GetOrgID()
    if not iOrg then return 2004 end

    local oScene = oPlayer.m_oActiveCtrl:GetNowScene()
    if not oScene.m_bFight then return 1036 end

    if oScene.m_bEnd then return 1036 end

    local iOrg1, iOrg2 = table.unpack(oScene.m_lOrgList)
    if not iOrg1 and not iOrg2 then return 1036 end

    local iMyOrg, iEnemyOrg
    if iOrg == iOrg1 then
        iMyOrg, iEnemyOrg = iOrg1, iOrg2 
    elseif iOrg == iOrg2 then
        iMyOrg, iEnemyOrg = iOrg2, iOrg1
    else
        return 1036
    end
    
    if oTarget.m_oStateCtrl:GetState(STATE_ID) then
        return 1024
    end

    local iNoWar = gamedefines.WAR_STATUS.NO_WAR
    if oTarget.m_oActiveCtrl:GetWarStatus() ~= iNoWar then
        return 1025
    end
    if oPlayer.m_oActiveCtrl:GetWarStatus() ~= iNoWar then
        return 1025
    end

    local iTargetOrg = oTarget:GetOrgID()
    if not iTargetOrg then return 1026 end

    if iTargetOrg ~= iEnemyOrg then
        return 1038, {name=oTarget:GetName()}
    end
    
    local iTargetSize = 1
    local lTarget = {oTarget:GetPid()}
    if oTarget:IsTeamLeader() then
        lTarget = {}
        for i, iMem in pairs(oTarget:GetTeamMember()) do
            local oMem = global.oWorldMgr:GetOnlinePlayerByPid(iMem) 
            if oMem and oMem:GetOrgID() == iEnemyOrg then
                table.insert(lTarget, iMem)
            end
        end
        iTargetSize = #lTarget
    end
    local lName = self:FilterPlayer(lTarget, function(oTarget)
        if oTarget:GetOrgID() ~= iEnemyOrg then
            return oTarget:GetName()
        end
    end)
    if lName and next(lName) then
        return 1038, {name = table.concat(lName, "、")}
    end
    local lName = self:FilterPlayer(lTarget, function(oTarget)
        if oTarget.m_oStateCtrl:GetState(STATE_ID) then
            return oTarget:GetName()
        end
    end)
    if lName and next(lName) then
        return 1024
    end

    local lPlayer = {oPlayer:GetPid()}
    if oPlayer:IsTeamLeader() then
        lPlayer = {}
        for _, iMem in pairs(oPlayer:GetTeamMember()) do
            local oMem = global.oWorldMgr:GetOnlinePlayerByPid(iMem)
            if oMem and oMem:GetOrgID() == iMyOrg then
                table.insert(lPlayer, iMem)
            end
        end
    end
    local lName = self:FilterPlayer(lPlayer, function(oMember)
        if oMember:GetOrgID() ~= iMyOrg then
            return oMember:GetName()
        end
    end)
    if lName and next(lName) then
        return 1037, {name = table.concat(lName, "、")}
    end
    local mConfig = self:GetConfig()
    local iCost = formula_string(mConfig.attack_cost_point, {size=iTargetSize})
    local lName = self:FilterPlayer(lPlayer, function(oMember)
        local iPid = oMember:GetPid()
        if self:GetActionPointByPid(iPid, 0) < iCost then
            return oMember:GetName()
        end
    end)
    if lName and next(lName) then
        return 1027, {name = table.concat(lName, "、")}
    end
    return 1
end

function CHuodong:ShortLeaveDiffOrgMember(oPlayer)
    local iOrg = oPlayer:GetOrgID()
    if oPlayer:IsTeamLeader() then
        local oTeam = oPlayer:HasTeam()
        local lTarget = oPlayer:GetTeamMember()
        self:FilterPlayer(lTarget, function(oTarget)
            if oTarget:GetOrgID() ~= iOrg then
                oTeam:ShortLeave(oTarget:GetPid())
            end
        end)
    end
end

function CHuodong:AddScheduleTimes(lMyList, lEnList)
    for _, oPlayer in pairs(lMyList) do
        self:AddSchedule(oPlayer)
    end
    for _, oPlayer in pairs(lEnList) do
        self:AddSchedule(oPlayer)
    end
end

function CHuodong:C2GSOrgWarStartFight(oPlayer, iTarget)
    local oTarget = global.oWorldMgr:GetOnlinePlayerByPid(iTarget)
    if not oTarget then return end

    if not oTarget:IsSingle() then
        local oTeam = oTarget:HasTeam()
        iTarget = oTeam:Leader()
    end

    local iPid = oPlayer:GetPid()
    local iRet, mReplace = self:ValidStartFight(oPlayer, iTarget)
    if iRet ~= 1 then
        self:Notify(iPid, iRet, mReplace)
        return
    end

    oTarget = global.oWorldMgr:GetOnlinePlayerByPid(iTarget)
    self:ShortLeaveDiffOrgMember(oPlayer)
    self:ShortLeaveDiffOrgMember(oTarget)

    local lMyList = self:GetFighterList(oPlayer)
    local lEnList = self:GetFighterList(oTarget)
    local mConfig = self:GetConfig()
    local iCost = formula_string(mConfig.attack_cost_point, {size=#lEnList})
    for _, oCoster in pairs(lMyList) do
        self:AddActionPointByPid(oCoster:GetPid(), -iCost, false)
        self:Notify(oCoster:GetPid(), 1028, {name=oCoster:GetName(), action_point=iCost})
        oCoster.m_oStateCtrl:RemoveState(STATE_ID)
    end

    local iWarType = gamedefines.WAR_TYPE.PVP_TYPE
    local iSysType = gamedefines.GAME_SYS_TYPE.SYS_TYPE_ORGWAR
    local mWarConfig = {
        barrage_show = mConfig.barrage_show,
        barrage_send = mConfig.barrage_send,
        GamePlay = "orgwar",
    }
    local oWar = global.oWarMgr:CreateWar(iWarType, iSysType, mWarConfig)
    local iWar = oWar:GetWarId()
    
    for idx, oFighter in ipairs({oPlayer, oTarget}) do
        if oFighter:IsSingle() then
            global.oWarMgr:EnterWar(oFighter, iWar, {camp_id=idx}, true, 0)
        else
            global.oWarMgr:TeamEnterWar(oFighter, iWar, {camp_id=idx}, true, 0)
        end
    end

    global.oWarMgr:SetCallback(iWar, function(mArgs)
        self:OnOrgWarFightEnd(iWar, mArgs)
    end)
    global.oWarMgr:SetOtherCallback(iWar, "OnLeave", function(oPlayer)
        self:OnOrgWarEscape(iWar, oPlayer)
    end)

    global.oWarMgr:StartWar(iWar)
    self:AddScheduleTimes(lMyList, lEnList)
end

function CHuodong:OnOrgWarFightEnd(iWar, mArgs)
    local lWinner, lLoser, lWinnerEscape, lLoserEscape = self:GetJoinOrgWarMember(mArgs)
    local iWinLeader = lWinner[1]
    local iLoserLeader = lLoser[1] or lLoserEscape[1]
    assert(iWinLeader and iLoserLeader)

    local iWinSize = #lWinner + #lWinnerEscape  
    local iLoseSize = #lLoser + #lLoserEscape
    local iLoserLeaderWinSerial = 0
    local mConfig = self:GetConfig()
    local sWinFormula = mConfig.win_war_score

    for idx, lPlayer in ipairs({lWinnerEscape, lLoser, lLoserEscape}) do
        for _, iPid in ipairs(lPlayer) do
            local oPlayer = global.oWorldMgr:GetOnlinePlayerByPid(iPid)
            if not oPlayer then goto continue end

            if iPid == iLoserLeader then
                iLoserLeaderWinSerial = oPlayer.m_oThisTemp:Query("serial_win", 0)
            end
            oPlayer.m_oThisTemp:Set("serial_win", 0, 3*60*60)

            if idx == 2 then
                oPlayer.m_oStateCtrl:RemoveState(STATE_ID)
                oPlayer.m_oStateCtrl:AddState(STATE_ID, {time=15})
                self:Reward(iPid, "1003")
                self:AddWarScoreByPid(iPid, mConfig.lose_war_score)
            end
            ::continue::
        end
    end
    if #lLoser > 0 and not mArgs.force then
        local iAvgSub = math.min(mConfig.lose_sub_point/#lLoser, mConfig.lose_limit)
        for _, iPid in ipairs(lLoser) do
            self:AddActionPointByPid(iPid, -iAvgSub, true)
        end
    end

    for _, iPid in ipairs(lWinner) do
        local oPlayer = global.oWorldMgr:GetOnlinePlayerByPid(iPid)
        oPlayer.m_oStateCtrl:RemoveState(STATE_ID)
        oPlayer.m_oStateCtrl:AddState(STATE_ID, {time=15})

        local iSerial = oPlayer.m_oThisTemp:Query("serial_win", 0) + 1
        oPlayer.m_oThisTemp:Set("serial_win", iSerial, 3*60*60)

        self:Reward(iPid, "1002")
        self:RewardWinnerScore(oPlayer, iWinSize, iLoseSize, iSerial, iLoserLeaderWinSerial, sWinFormula) 
        self:AddActionPointByPid(iPid, 0, true)
    end
    
    local oWinner = global.oWorldMgr:GetOnlinePlayerByPid(iWinLeader)
    local oLoser = global.oWorldMgr:GetOnlinePlayerByPid(iLoserLeader) 
    self:RewardOrgScore(oWinner, iWinSize, iLoseSize, mConfig.win_org_score)
    self:RewardOrgScore(oLoser, iLoseSize, 0, mConfig.lose_org_score)
    self:SendWarEndOrgChannel(oWinner, oLoser, iLoserLeaderWinSerial)
    -- self:RewardOrgPrestige(oWinner, mConfig.win_org_prestige)
    -- self:RewardOrgPrestige(oLoser, mConfig.lose_org_prestige)

    local mLogData = {
        winner_list = lWinner,
        loser_list = lLoser,
        winner_escape = lWinnerEscape,
        loser_escape = lLoserEscape,
        name = "战斗结果",
    }
    record.log_db("huodong", "orgwar", {info=mLogData})
end

function CHuodong:OnOrgWarEscape(iWar, oPlayer)
    if not oPlayer then return end

    local mConfig = self:GetConfig()
    local iPid = oPlayer:GetPid()
    oPlayer.m_oStateCtrl:RemoveState(STATE_ID)
    oPlayer.m_oStateCtrl:AddState(STATE_ID, {time=15})
    self:Reward(iPid, "1003")
    self:AddWarScoreByPid(iPid, mConfig.lose_war_score)
    self:AddActionPointByPid(iPid, -mConfig.lose_limit, true)
end

function CHuodong:GetJoinOrgWarMember(mArgs)
    local iWinSide = mArgs.win_side
    local iLoseSide = 3 - iWinSide
    local lWinner = self:GetWarriorBySide(mArgs.player, iWinSide)
    local lLoser = self:GetWarriorBySide(mArgs.player, iLoseSide)
    local lWinnerEscape = self:GetWarriorBySide(mArgs.escape, iWinSide)
    local lLoserEscape = self:GetWarriorBySide(mArgs.escape, iLoseSide)
    return lWinner, lLoser, lWinnerEscape, lLoserEscape
end

function CHuodong:GetWarriorBySide(mPlayer, iSide)
    local lPlayer = {}
    for _, iPid in ipairs(mPlayer[iSide] or {}) do
        local oPlayer = global.oWorldMgr:GetOnlinePlayerByPid(iPid)
        if oPlayer:IsTeamLeader() then
            table.insert(lPlayer, 1, iPid)
        else
            table.insert(lPlayer, iPid)
        end
    end
    return lPlayer
end

function CHuodong:RewardWinnerScore(oPlayer, iFriendCnt, iEnemyCnt, iWinnerSerial, iLoserSerial, sFormula)
    local iWinnerFactor, iLoserFactor = self:GetSerialFactor(iWinnerSerial, iLoserSerial)

    local mEnv = {
        enemy_cnt = iEnemyCnt,
        friend_cnt = iFriendCnt,
        winner_factor = iWinnerFactor,
        loser_factor = iLoserFactor,
    }
    local iScore = formula_string(sFormula, mEnv)
    local iPid = oPlayer:GetPid()
    self:AddWarScoreByPid(iPid, iScore)
end

function CHuodong:RewardOrgScore(oPlayer, iFriendCnt, iEnemyCnt, sFormula)
    local iOrg = oPlayer:GetOrgID()
    if not iOrg then return end

    local mEnv = {
        friend_cnt = iFriendCnt,
        enemy_cnt = iEnemyCnt,
    }
    local iOrgScore = formula_string(sFormula, mEnv)
    self:AddOrgScoreByOrgId(iOrg, iOrgScore)
end

function CHuodong:GetFighterList(oPlayer)
    local lPlayer = {oPlayer}
    local oTeam = oPlayer:HasTeam()
    if oTeam and oPlayer:IsTeamLeader() then
        lPlayer = oTeam:FilterTeamMember(function(oMember)
            return global.oWorldMgr:GetOnlinePlayerByPid(oMember.m_ID)
        end)
    end
    return lPlayer
end

function CHuodong:GetSerialFactor(iWinnerSerial, iLoserSerial)
    local iWinnerFactor, iLoserFactor = 0, 0
    local mConfig = self:GetConfig()
    for idx, iFactor in pairs(mConfig.win_serial_factor or {}) do
        if iWinnerSerial >= idx then
            iWinnerFactor = iFactor
        else
            break
        end
    end
    for idx, iFactor in pairs(mConfig.lose_serial_factor or {}) do
        if iLoserSerial >= idx then
            iLoserFactor = iFactor
        else
            break
        end
    end

    return iWinnerFactor, iLoserFactor
end

function CHuodong:SendWarEndOrgChannel(oWinner, oLoser, iLoserWin)
    local iWinSerial = 0 
    local mConfig = self:GetConfig()
    if oWinner then
        local iOrg = oWinner:GetOrgID()
        if not iOrg then return end

        iWinSerial = oWinner.m_oThisTemp:Query("serial_win", 0)
        if iLoserWin >= 5 and oLoser then
            local mReplace = {leader={oLoser:GetName(), oWinner:GetName()}, N=iLoserWin}
            self:OrgChannel(iOrg, 3010, mReplace)
        end

        local iKey = math.min(7, iWinSerial)
        local iChat = mConfig.friend_win_announce[iKey]
        if iChat then
            local mReplace = {leader=oWinner:GetName(), N=iWinSerial}
            self:OrgChannel(iOrg, iChat, mReplace)
        end
    end

    if oLoser and oWinner then
        local iOrg = oLoser:GetOrgID()
        if not iOrg then return end

        local iKey = math.min(7, iWinSerial)
        local iChat = mConfig.enemy_win_announce[iKey]
        if iChat then
            local mReplace = {leader=oWinner:GetName(), N=iWinSerial}
            self:OrgChannel(iOrg, iChat, mReplace)
        end
    end
end

function CHuodong:ForceWarEnd(oScene)
    local mWarTable = {}
    for iPid, _ in pairs(oScene.m_mPlayers) do
        local oPlayer = global.oWorldMgr:GetOnlinePlayerByPid(iPid)
        if not oPlayer then goto continue end

        local oWar = oPlayer.m_oActiveCtrl:GetNowWar()
        if not oWar then goto continue end

        local iWarId = oWar:GetWarId()
        if mWarTable[iWarId] then goto continue end

        mWarTable[iWarId] = true
        oWar:ForceWarEnd()
        ::continue::
    end
end

function CHuodong:RewardOrgPrestige(oOrg, sFormula)
    if not oOrg or not sFormula then return end

    local iPrestige = formula_string(sFormula, {})
    local sMsg = global.oOrgMgr:GetOrgText(1170, {amount=iPrestige})
    oOrg:AddPrestige(iPrestige, "帮派竞赛", {chat_msg=sMsg})
end


--------------- protocol --------------------
function CHuodong:C2GSOrgWarTryGotoNpc(oPlayer, mData)
    local iRet, mReplace = self:ValidEnterPrepareRoom(oPlayer)
    if iRet ~= 1 then
        self:Notify(oPlayer:GetPid(), iRet, mReplace)
        return
    end
    global.oNpcMgr:FindPathToNpc(oPlayer, 5283, true)
end

function CHuodong:C2GSOrgWarOpenMatchList(oPlayer, mData)
    local iRet, mReplace = self:ValidOpenMatchList(oPlayer)
    if iRet ~= 1 then
        self:Notify(oPlayer:GetPid(), iRet, mReplace)
        oPlayer:Send("GS2COrgWarOpenMatchList", {})
        return
    end

    local iWeekDay = mData.week_day
    local iOrg = oPlayer:GetOrgID()
    local mMatchInfo = {}

    if iWeekDay == 2 then
        mMatchInfo = self:GetData("match_info_week_2", {})
    elseif iWeekDay == 4 then
        mMatchInfo = self:GetData("match_info_week_4", {})
    end

    self.m_oUIMgr:TryOpenMatchList(oPlayer, mMatchInfo, iWeekDay)
end

function CHuodong:ValidOpenMatchList(oPlayer)
    if not global.oToolMgr:IsSysOpen("ORGWAR", oPlayer, true) then
        return 2002
    end

    local oOrg = oPlayer:GetOrg()
    if not oOrg then return 2004 end

    local iPid = oPlayer:GetPid() 
    local oMember = oOrg.m_oMemberMgr:GetMember(iPid)
    if not oMember then return 1043, {name=oPlayer:GetName()}  end
    
    local mConfig = self:GetConfig()
    if self:GetSysTime() - oMember:GetJoinTime() < mConfig.join_time_limit*60*60 then
        return 2003, {name=oPlayer:GetName()}
    end
    
    local iWeekDay = get_weekday(self:GetSysTime())
    if iWeekDay >= 5 then return 2005 end

    if iWeekDay == 1 then
        local mTimeConfig = self:GetTimeConfig()
        local mConfig = mTimeConfig[iWeekDay][1]
        if self:GetSysTime() < self:AnalyseTime(mConfig.start_time) then
            return 2005
        end
    end
    if iWeekDay == 4 then
        local mTimeConfig = self:GetTimeConfig()
        local mConfig = mTimeConfig[iWeekDay][1]
        if self:GetSysTime() > self:AnalyseTime(mConfig.start_time) + mConfig.continue_time*60 then
            return 1003
        end
    end

    --TODO check is right
--    if not self:InHuodongTime() then
--        return 2001
--    end
   
    local iRet = self:GetEnemyOrgId(oOrg:OrgID())
    if iRet == -1 then return 1001 end

    if iRet == 0 then return 1004 end

    return 1
end

function CHuodong:C2GSOrgWarOpenTeamUI(oPlayer)
    local iRet, mReplace = self:ValidOpenTeamUI(oPlayer)
    if iRet ~= 1 then
        --self:Notify(oPlayer:GetPid(), iRet, mReplace)
        return
    end

    oPlayer.m_oThisTemp:Reset("teamui_timeout", 1, 3)
    self.m_oUIMgr:OpenOrgWarTeamUI(oPlayer)
end

function CHuodong:ValidOpenTeamUI(oPlayer)
    local iOrg = oPlayer:GetOrgID()
    if not iOrg then return 2004 end

    local oScene = oPlayer.m_oActiveCtrl:GetNowScene()
    if not oScene then return 1030 end

    if not table_in_list(oScene.m_lOrgList or {}, iOrg) then
        return 1031
    end

    local mConfig = self:GetConfig()
    if oPlayer.m_oThisTemp:Query("teamui_timeout") then
        return 1032
    end
    return 1
end

function CHuodong:C2GSOrgWarOpenWarScoreUI(oPlayer)
    local iRet, mReplace = self:ValidOpenWarScoreUI(oPlayer)
    if iRet ~= 1 then
        --self:Notify(oPlayer:GetPid(), iRet, mReplace)
        return
    end
    
    oPlayer.m_oThisTemp:Set("warscoreui_timeout", 1, 3)
    local oScene = oPlayer.m_oActiveCtrl:GetNowScene()
    self.m_oUIMgr:OpenOrgWarScoreUI(oPlayer, oScene)
end

function CHuodong:ValidOpenWarScoreUI(oPlayer)
    if oPlayer.m_oThisTemp:Query("warscoreui_timeout") then
        return 1032
    end

    local iOrg = oPlayer:GetOrgID()
    if not iOrg then return 2004 end

    local oScene = oPlayer.m_oActiveCtrl:GetNowScene()
    if not oScene then return 1030 end

    if not table_in_list(oScene.m_lOrgList or {}, iOrg) then
        return 1031
    end

    return 1
end

function CHuodong:TestOp(iFlag, mArgs)
    local iPid = mArgs[#mArgs]
    local oMaster = global.oWorldMgr:GetOnlinePlayerByPid(iPid)
    if iFlag == 100 then
        global.oNotifyMgr:Notify(iPid, [[
        101 - 生成周二对战表
        102 - 周二开战
        103 - 生成周四对战表
        104 - 周四开战
        105 - 9:00自动传送入场
        106 - 调时间 {day=5,hour=8,min=0}
        107 - 刷时
        108 - 活动结束 {release_fight=5} 5毫秒后移除场景
        109 - 挑战某玩家 {target}
        110 - 查看当前设置时间
        112 - 清空自己离帮时间
        113 - 清空临时变量
        304 - 添加行动力 {100}
        ]])
    elseif iFlag == 101 then
        local mTimeConfig = self:GetTimeConfig()
        self:GenMatchList1(mTimeConfig[1][1], true)
    elseif iFlag == 102 then
        local mTimeConfig = self:GetTimeConfig()[2]
        for _, mConfig in pairs(mTimeConfig) do
            if mConfig.event == "game_start1" then
                self:GameStart(mConfig)
            end
        end
    elseif iFlag == 103 then
        self:DoGenMatchList2()
    elseif iFlag == 104 then
        local mTimeConfig = self:GetTimeConfig()[4]
        self:GameStart(mTimeConfig[1])
    elseif iFlag == 105 then
        self:GameAction()
    elseif iFlag == 106 then
        local mCurrDate = os.date("*t", get_time())
        local iTestTime = os.time({
            year = mArgs.year or mCurrDate.year,
            month = mArgs.month or mCurrDate.month,
            day = mArgs.day or mCurrDate.day,
            hour = mArgs.hour or mCurrDate.hour,
            min = mArgs.min or mCurrDate.min,
            sec = mArgs.sec or 0,
        })
        self.m_iTestDeltaTime = iTestTime - get_time()
    elseif iFlag == 107 then
        local iWeekDay = get_weekday(self:GetSysTime())
        self:NewHour(get_wdaytime({wday=iWeekDay}))
    elseif iFlag == 108 then
        self.m_iTestRemove = mArgs.release_fight
        self:GameOver()
        self.m_iTestRemove = nil
    elseif iFlag == 109 then
        self:C2GSOrgWarStartFight(oMaster, mArgs[1])
    elseif iFlag == 110 then
        global.oNotifyMgr:Notify(iPid, get_time_format_str(self:GetSysTime(), "%y-%m-%d %H:%M:%S"))
    elseif iFlag == 111 then
        print(self.m_mData)
        print(self.m_mPid2ActionPoint)
    elseif iFlag == 112 then
        self.m_mPid2LeaveOrgTime[iPid] = nil
    elseif iFlag == 113 then
        oMaster.m_oThisTemp:Delete("serial_win")
        oMaster.m_oThisTemp:Delete("half_action")
        oMaster.m_oThisTemp:Delete("in_fight_scene")
    elseif iFlag == 114 then
        self:StartReplaceHD(mArgs[1])
    elseif iFlag == 301 then
        local iActionPoint = self:GetActionPointByPid(oMaster:GetPid())
        oMaster:NotifyMessage("当前行动力"..iActionPoint)
    elseif iFlag == 302 then
        local oScene = oMaster.m_oActiveCtrl:GetNowScene()
        if oScene then
            --global.oSceneMgr:RemoveScene(oScene:GetSceneId())
            --self:ReleaseFightScene(oScene:GetSceneId())
            self:GameOverByScene(oScene, mCount)
            --self:CheckOrgWarWinner(oScene)
        end
    elseif iFlag == 303 then
        --self:NotifyGameStartStep(2)
        --self.m_mPid2ActionPoint = {}    --行动力
        self:AddWarScoreByPid(iPid, 3)
    elseif iFlag == 304 then
        self:AddActionPointByPid(iPid, mArgs[1], true)
    end
end


function PrepareRoomRewardExp(iScene)
    local oScene = global.oSceneMgr:GetScene(iScene)
    if not oScene then return end

    oScene:DelTimeCb("PrepareRoomRewardExp")
    oScene:AddTimeCb("PrepareRoomRewardExp", 5*60*1000, function()
        PrepareRoomRewardExp(iScene)
    end)

    local oHuodong = global.oHuodongMgr:GetHuodong("orgwar")
    if not oHuodong then return end

    if not oHuodong:InHuodongTime() then return end

    for iPid, _ in pairs(oScene.m_mPlayers) do
        oHuodong:Reward(iPid, "1001")
    end
end

function CheckOrgResult(iScene)
    local oScene = global.oSceneMgr:GetScene(iScene)
    if not oScene then return end

    oScene:DelTimeCb("CheckOrgResult")
    oScene:AddTimeCb("CheckOrgResult", 5*60*1000, function()
        CheckOrgResult(iScene)
    end)

    if oScene.m_bEnd then return end

    local iOrg1, iOrg2 = table.unpack(oScene.m_lOrgList or {})
    if not iOrg1 or not iOrg2 then return end

    local oOrg1 = global.oOrgMgr:GetNormalOrg(iOrg1)
    if not oOrg1 then return end
    
    local oOrg2 = global.oOrgMgr:GetNormalOrg(iOrg2)
    if not oOrg2 then return end

    local oHuodong = global.oHuodongMgr:GetHuodong("orgwar") 
    local mCount = oHuodong:CountOrgMember(oScene)
    for iOrg, iTotal in pairs(mCount) do
        if iTotal <= 0 then
            oHuodong:CheckOrgWarWinner(oScene)
            return
        end
    end

    local iOrgScore1 = oHuodong:GetOrgScoreByOrgId(iOrg1, 0)
    local iOrgScore2 = oHuodong:GetOrgScoreByOrgId(iOrg2, 0)
    if iOrgScore1 == iOrgScore2 then return end

    if iOrgScore1 > iOrgScore2 then
        oHuodong:OrgChannel(iOrg1, 3011)
        oHuodong:OrgChannel(iOrg2, 3012)
    else
        oHuodong:OrgChannel(iOrg1, 3012)
        oHuodong:OrgChannel(iOrg2, 3011)
    end
end

function CheckInFightScene(iScene)
    local oScene = global.oSceneMgr:GetScene(iScene)
    if not oScene then return end

    oScene:DelTimeCb("CheckInFightScene")
    oScene:AddTimeCb("CheckInFightScene", 5*60*1000, function()
        CheckInFightScene(iScene)
    end)

    local oHuodong = global.oHuodongMgr:GetHuodong("orgwar")
    local mConfig = oHuodong:GetConfig()
    for iPid, _ in pairs(oScene.m_mPlayers) do
        local oPlayer = global.oWorldMgr:GetOnlinePlayerByPid(iPid)
        if not oPlayer then goto continue end

        local iOrg = oPlayer:GetOrgID()
        if not iOrg then goto continue end

        if not table_in_list(oScene.m_lOrgList or {}, iOrg) then
            goto continue
        end

        oHuodong:Reward(iPid, "1001")

        local iCnt = oPlayer.m_oThisTemp:Query("in_fight_scene", 0) + 1
        oPlayer.m_oThisTemp:Set("in_fight_scene", iCnt, 3*3600)

        local iScore = formula_string(mConfig.in_scene_org_score, {cnt=iCnt})
        oHuodong:AddOrgScoreByOrgId(iOrg, iScore)

        local iWarScore = formula_string(mConfig.in_scene_war_score, {cnt=iCnt})
        oHuodong:AddWarScoreByPid(iPid, iWarScore)
        ::continue::
    end
end
