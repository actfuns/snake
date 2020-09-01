local global = require "global"
local res = require "base.res"
local record = require "public.record"
local interactive = require "base.interactive"
local gamedefines = import(lualib_path("public.gamedefines"))
local huodongbase = import(service_path("huodong.huodongbase"))
local analy = import(lualib_path("public.dataanaly"))

function NewHuodong(sHuodongName)
    return CHuodong:New(sHuodongName)
end

CHuodong = {}
CHuodong.__index = CHuodong
CHuodong.m_sTempName = "六道百科"
inherit(CHuodong, huodongbase.CHuodong)


local GAME_NONE = 0
local GAME_START = 1
local GAME_END = 2

local TYPE_QUESTION_NORMAL = 1
local TYPE_QUESTION_LINK = 3 

function CHuodong:New(sHuodongName)
    local o = super(CHuodong).New(self, sHuodongName)
    o.m_iScheduleID = 1021
    o.m_iState = GAME_NONE
    o.m_iStartTime = 0
    o.m_iEndTime = 0
    o.m_iTopRank = 100
    o.m_iRankInterval = 10
    o.m_mCurRank = {}   -- pid1, pid2 ...
    o.m_mCurData = {}   -- pid:{name="name","score":iScore,"time":iTime}
    o.m_mAward = {}
    return o
end

function CHuodong:Init()
    self:InitParam()
    self:InitGameStartTime()
    self:RefreshSchedule()
end

function CHuodong:InitParam()
    self:DelTimeCb("GameStart")
    self:DelTimeCb("RefreshCurRank")
    self:DelTimeCb("GameOver_bk")
    self.m_iState = GAME_NONE
    self.m_mCurRank = {}
    self.m_mCurData = {}
    self.m_mAward = {}
end

function CHuodong:InitGameStartTime(mNow)
    if self:IsGameStart() then return end

    local mConfig = self:GetConfig()
    local mTime = mConfig.huodong_time or {}
    local iNowTime = mNow and mNow.time or get_time()
    
    for _, sTime in ipairs(mTime) do
        local iStartTime, iEndTime = self:AnalyseTime(sTime)
        self.m_iStartTime = iStartTime
        self.m_iEndTime = iEndTime
        if iNowTime < iStartTime then
            self:CheckAddTimer(mNow)
            return
        end
    end
end

function CHuodong:CheckAddTimer(mNow)
    local iNowTime = mNow and mNow.time or get_time()
    local iDelta = self.m_iStartTime - iNowTime
    if iDelta > 0 and iDelta <= 3600 then
        self:DelTimeCb("GameStart")
        self:AddTimeCb("GameStart", iDelta * 1000, function ()
            self:GameStart()
        end)
    end
end

function CHuodong:AnalyseTime(sTime)
    local mDate = os.date("*t", get_time())
    local hs,ms,he,me = sTime:match("^(%d+)%:(%d+)%-(%d+)%:(%d+)")
    hs,ms,he,me = tonumber(hs),tonumber(ms),tonumber(he),tonumber(me)
    local iStartTime = os.time({year=mDate.year,month=mDate.month,day=mDate.day,hour=hs,min=ms,sec=0})
    local iEndTime = os.time({year=mDate.year,month=mDate.month,day=mDate.day,hour=he,min=me,sec=0})
    return iStartTime,iEndTime
end

function CHuodong:NewDay(mNow)
    self:InitGameStartTime(mNow)
    self:RefreshSchedule(mNow)
end

function CHuodong:IsOpenDay(iTime)
    if global.oToolMgr:IsSysOpen("HFDM") then
        -- 画舫灯谜外放时改为周日不开
        if 7 == get_weekday(iTime) then
            return false
        end
    end
    return true
end

function CHuodong:SetHuodongState(iState)
    local sTime = self:GetStartTime()
    global.oHuodongMgr:SetHuodongState(self.m_sName, self.m_iScheduleID, iState, sTime)
end

function CHuodong:RefreshSchedule(mNow)
    local iNowTime = mNow and mNow.time or get_time()
    if iNowTime < self.m_iStartTime then
        self:SetHuodongState(gamedefines.ACTIVITY_STATE.STATE_READY)
    end
end

function CHuodong:GetStartTime()
    return get_time_format_str(self.m_iStartTime, "%H:%M")
end

function CHuodong:GetHuodongTime()
    local iNowTime = get_time()
    local iDelta = self.m_iEndTime - iNowTime
    return iDelta > 0 and iDelta or 0
end

function CHuodong:NewHour(mNow)
    self:InitGameStartTime(mNow)
end

function CHuodong:GameStart()
    self:DelTimeCb("GameStart")
    self:DelTimeCb("RefreshCurRank")
    self:DelTimeCb("GameOver_bk")
    record.info("baike GameStart")
    self.m_iState = GAME_START
    self.m_mCurRank = {}
    self.m_mCurData = {}
    self.m_mAward = {}

    self:AddTimeCb("GameOver_bk", (self.m_iEndTime-self.m_iStartTime)*1000, function()
        self:GameOver()
    end)
    self:AddTimeCb("RefreshCurRank", self.m_iRankInterval * 1000, function()
        self:RefreshCurRank()
    end)
    self:SetHuodongState(gamedefines.ACTIVITY_STATE.STATE_START)
    self:TryStartRewardMonitor()
end

function CHuodong:GameOver()
    self:DelTimeCb("GameOver_bk")
    record.info("baike GameOver")
    self.m_iState = GAME_END
    self:SetHuodongState(gamedefines.ACTIVITY_STATE.STATE_END)

    self:RefreshCurRank()
    self:SendCurRankReward()
    self:SendGameAward()
    self:InitGameStartTime()
    self:RefreshSchedule()

    if not global.oToolMgr:IsSysOpen("HFDM") then
        -- 周总榜奖励结算（需要改到画舫灯谜活动后执行）
        if get_weekday() == 7 then
            self:ToDealWeekRank()
        end
    end
    self:TryStopRewardMonitor() 
end

function CHuodong:IsGameStart()
    return self.m_iState == GAME_START
end

function CHuodong:GetConfig()
    return res["daobiao"]["huodong"][self.m_sName]["condition"][1]
end

function CHuodong:OpenUI(oPlayer)
    if not global.oToolMgr:IsSysOpen("BAIKE", oPlayer) then
        return
    end
    if not self:IsGameStart() then
        return
    end
    if self:ValidHuodongFinish(oPlayer) then
        return
    end
    local iQuestion = oPlayer.m_oThisTemp:Query("baike_question", 0)
    if iQuestion == 0 then
        iQuestion = self:GetQuestion(oPlayer)
    end
    local iQuTime = oPlayer.m_oThisTemp:Query("baike_qtime", 0)
    self:SendQuestionInfo(oPlayer, iQuestion, iQuTime)
    -- 当前排行数据
    local mNet = self:PackCurRankData()
    oPlayer:Send("GS2CBaikeCurRank", mNet)
    self:GS2CCurRankScore(oPlayer)
end

function CHuodong:ValidHuodongFinish(oPlayer)
    local iAmount = self:GetConfig()["question"] or 15
    if oPlayer.m_oThisTemp:Query("baike_ring", 0) >= iAmount then
        oPlayer:Send("GS2CBaikeFinish", {})
        return true
    end
    return false
end

function CHuodong:GetNextQuestion(oPlayer)
    local iQuestion = self:GetQuestion(oPlayer)
    if not iQuestion then
        return
    end
    self:SendQuestionInfo(oPlayer, iQuestion)
end

function CHuodong:GetQuestion(oPlayer)
    if not self:IsGameStart() then return end
    if self:ValidHuodongFinish(oPlayer) then return end

    local iQuestion = self:RandQuestion(oPlayer)
    local iTime = self:GetHuodongTime()
    oPlayer.m_oThisTemp:Set("baike_question", iQuestion, iTime)
    oPlayer.m_oThisTemp:Set("baike_qtime", get_time(), iTime)
    local mExclude = oPlayer.m_oThisTemp:Query("baike_exclude", {})
    table.insert(mExclude, iQuestion)
    oPlayer.m_oThisTemp:Set("baike_exclude", mExclude, iTime)
    return iQuestion
end

function CHuodong:RandQuestion(oPlayer)
    local mQuestion = res["daobiao"]["huodong"][self.m_sName]["question"]
    local iRing = oPlayer.m_oThisTemp:Query("baike_ring", 0)
    local mExclude = oPlayer.m_oThisTemp:Query("baike_exclude", {})
    iRing = iRing + 1
    local bNormal = true
    local iAllNormal = self:GetConfig()["all_normal"]
    if iAllNormal ~= 1 and iRing % 5 == 1 then
        bNormal = false
    end
    local lQuestion = {}
    for k, v in pairs(mQuestion) do
        if not table_in_list(mExclude, k) then
            if bNormal and v.type == TYPE_QUESTION_NORMAL then
                table.insert(lQuestion, k)
            elseif not bNormal and v.type ~= TYPE_QUESTION_NORMAL then
                table.insert(lQuestion, k)
            end
        end
    end
    assert(table_count(lQuestion), string.format("not valid question"))
    local iQuestion = lQuestion[math.random(table_count(lQuestion))]
    return iQuestion
end

function CHuodong:SendQuestionInfo(oPlayer, iQuestion, iQuTime)
    local mInfo = res["daobiao"]["huodong"][self.m_sName]["question"][iQuestion]
    local mNet = {}
    mNet.id = iQuestion
    mNet.type = mInfo.type
    mNet.content = mInfo.question
    local mChoices = {}
    for i=1,4 do
        local sTextKey = "choose_text_"..i
        local sIconKey = "choose_icon_"..i
        if mInfo[sTextKey] ~= "" or mInfo[sIconKey] ~= 0 then
            table.insert(mChoices, {
                text = mInfo[sTextKey],
                icon = mInfo[sIconKey],
            })
        end
    end
    mNet.choices = mChoices
    local iRing = oPlayer.m_oThisTemp:Query("baike_ring", 0)
    mNet.ring = iRing + 1
    mNet.answer_cnt = table_count(mInfo["answer"])
    if iQuTime and iQuTime > 0 then
        mNet.answer_time = math.max(get_time() - iQuTime, 0)
    end
    oPlayer:Send("GS2CBaikeQuestion", mNet)
end

function CHuodong:GetQuestionAnswer(iQuestion)
    local mInfo = res["daobiao"]["huodong"][self.m_sName]["question"][iQuestion]
    local iType = mInfo.type
    local mAnswer = mInfo.answer
    local mResult = {}
    if iType == TYPE_QUESTION_LINK then
        for _, sAnswer in ipairs(mAnswer) do
            local l1, l2 = sAnswer:match("^(%d+)%-(%d+)")
            table.insert(mResult, {link1 = tonumber(l1), link2 = tonumber(l2)})
        end
    else
        for _, sAnswer in ipairs(mAnswer) do
            table.insert(mResult, tonumber(sAnswer))
        end
    end
    return mResult
end

function CHuodong:IsQuestionValid(oPlayer, iQuestion)
    local iNowQuestion = oPlayer.m_oThisTemp:Query("baike_question", 0)
    if iNowQuestion ~= iQuestion then
        record.warning(string.format("baike %s answer %s now %s", oPlayer:GetPid(), iQuestion, iNowQuestion))
        return false
    end
    return true
end

function CHuodong:OnAnswerQuestion(oPlayer, bResult, iCostTime)
    local iTime = self:GetHuodongTime()
    local iRing = oPlayer.m_oThisTemp:Query("baike_ring", 0)
    local iQuestion = oPlayer.m_oThisTemp:Query("baike_question", 0)
    iRing = iRing + 1
    oPlayer.m_oThisTemp:Set("baike_ring", iRing, iTime)
    oPlayer.m_oThisTemp:Delete("baike_question")

    oPlayer.m_oScheduleCtrl:Add(self.m_iScheduleID)
    self:RewardAnswer(oPlayer, bResult)
    self:RewardScore(oPlayer, bResult, iCostTime)
    local iScore = self:GetScore(bResult, iCostTime)
    safe_call(self.LogAnalyInfo, self, oPlayer, iQuestion, bResult, iCostTime, iScore)
    oPlayer:MarkGrow(14)
end

function CHuodong:ChooseAnswer(oPlayer, mData)
    local iQuestion = mData.id
    local mAnswer = mData.answer
    local iCostTime = mData.cost_time
    if not self:IsGameStart() then
        return
    end
    if not self:IsQuestionValid(oPlayer, iQuestion) then
        return
    end
    local mResult = self:GetQuestionAnswer(iQuestion)
    local bResult = true
    if table_count(mAnswer) == table_count(mResult) then
        for i = 1, #mResult do
            if mResult[i] ~= mAnswer[i] then
                bResult = false
                break
            end
        end
    else
        bResult = false
    end
    if oPlayer:Query("testman", 0) == 99 then
        bResult = true
    end
    if bResult then
        oPlayer:Send("GS2CBaikeChooseResult", {result = 1})
    else
        oPlayer:Send("GS2CBaikeChooseResult", {result = 0, right_answer = mResult})
    end
    self:OnAnswerQuestion(oPlayer, bResult, iCostTime)
end

function CHuodong:LinkAnswer(oPlayer, mData)
    local iQuestion = mData.id
    local mAnswer = mData.answer
    local iCostTime = mData.cost_time
    if not self:IsGameStart() then
        return
    end
    if not self:IsQuestionValid(oPlayer, iQuestion) then
        return
    end
    local mResult = self:GetQuestionAnswer(iQuestion)
    local bResult = true
    if table_count(mAnswer) == table_count(mResult) then
        for i = 1, table_count(mResult) do
            local a1, a2 = mAnswer[i].link1, mAnswer[i].link2
            local r1, r2 = mResult[i].link1, mResult[i].link2
            if not ((a1 == r1 and a2 == r2) or (a1 == r2 and a2 == r1)) then
                bResult = false
                break
            end
        end
    else
        bResult = false
    end
    if oPlayer:Query("testman", 0) == 99 then
        bResult = true
    end
    if bResult then
        oPlayer:Send("GS2CBaikeLinkResult", {result = 1})
    else
        oPlayer:Send("GS2CBaikeLinkResult", {result = 0, right_answer = mResult})
    end
    self:OnAnswerQuestion(oPlayer, bResult, iCostTime)
end

function CHuodong:RewardAnswer(oPlayer, bResult)
    local mConfig = self:GetConfig()
    local iReward
    if bResult then
        iReward = mConfig["reward_right"]
    else
        iReward = mConfig["reward_wrong"]
    end
    self:Reward(oPlayer:GetPid(), iReward)
end

function CHuodong:RewardScore(oPlayer, bResult, iCostTime)
    assert(iCostTime > 0, string.format("baike RewardScore costtime %s", iCostTime))
    local iScore = self:GetScore(bResult, iCostTime)
    if iScore <= 0 then return end
    local pid = oPlayer:GetPid()
    self.m_mAward[pid] = true
    local iTotalScore = oPlayer.m_oThisTemp:Query("baike_score", 0)
    local iWeekScore = oPlayer.m_oThisWeek:Query("baike_weekscore", 0)
    iTotalScore = iTotalScore + iScore
    iWeekScore = iWeekScore + iScore
    local iTime = self:GetHuodongTime()
    oPlayer.m_oThisTemp:Set("baike_score", iTotalScore, iTime)
    oPlayer.m_oThisWeek:Set("baike_weekscore", iWeekScore)
    self:PushDataToBaikeRank(oPlayer, iWeekScore)
    self:GS2CCurRankScore(oPlayer)
    if #self.m_mCurRank >= self.m_iTopRank then
        if self.m_mCurData[self.m_mCurRank[#self.m_mCurRank]]["score"] >= iTotalScore then
            return
        end
    end
    if iTotalScore <= 0 then return end
    self.m_mCurData[pid] = {
        pid   = pid,
        name  = oPlayer:GetName(),
        score = iTotalScore,
        time  = get_time(),
    }
end

function CHuodong:PushDataToBaikeRank(oPlayer, iWeekScore)
    if iWeekScore <= 0 then return end
    local mData = {}
    mData.pid = oPlayer:GetPid()
    mData.name = oPlayer:GetName()
    mData.time = get_time()
    mData.score = iWeekScore
    global.oRankMgr:PushDataToRank("baike", mData)
end

function CHuodong:SortRank()
    local lSortList = {}
    for pid, mData in pairs(self.m_mCurData) do
        table.insert(lSortList, {pid = pid, rank = mData})
    end
    
    table.sort(lSortList, function(mInfo1, mInfo2)
        if mInfo1["rank"]["score"] > mInfo2["rank"]["score"] then
            return true
        elseif mInfo1["rank"]["score"] < mInfo2["rank"]["score"] then
            return false
        else
            return mInfo1["rank"]["time"] < mInfo2["rank"]["time"]
        end
    end)

    local lRank = {}
    for _, mInfo in ipairs(lSortList) do
        if #lRank <= self.m_iTopRank then
            table.insert(lRank, mInfo.pid)
        else
            self.m_mCurData[mInfo.pid] = nil
        end
    end
    self.m_mCurRank = lRank
end

function CHuodong:GetScore(bResult, iCostTime)
    if not bResult then
        return 0
    end
    local mScore = res["daobiao"]["huodong"][self.m_sName]["score"]
    if iCostTime > table_count(mScore) then
        return mScore[table_count(mScore)]["score"]
    else
        return mScore[iCostTime]["score"]
    end
end

function CHuodong:RefreshCurRank()
    self:DelTimeCb("RefreshCurRank")
    self:SortRank()
    local mNet = self:PackCurRankData()
    global.oInterfaceMgr:RefreshBaikeCurRank(mNet)
    if self:IsGameStart() then
        self:AddTimeCb("RefreshCurRank", self.m_iRankInterval * 1000, function()
            self:RefreshCurRank()
        end)
    end
end

function CHuodong:PackCurRankData()
    local lRank = self.m_mCurRank
    local mConfig = self:GetConfig()
    local iShowLimit = mConfig["rank_show_limit"] or self.m_iTopRank
    local lShowRank = {}
    for _, pid in ipairs(lRank) do
        local mInfo = self.m_mCurData[pid]
        if mInfo then
            table.insert(lShowRank, {pid = pid, name = mInfo.name, score = mInfo.score})
        end
        if table_count(lShowRank) >= iShowLimit then
            break
        end
    end
    local mNet = {}
    mNet.unit = lShowRank
    return mNet
end

function CHuodong:GS2CCurRankScore(oPlayer)
    oPlayer:Send("GS2CBaikeCurRankScore", {
        score = oPlayer.m_oThisTemp:Query("baike_score", 0),
    })
end

function CHuodong:GetWeekRankData(oPlayer)
    local mNet = {}
    local iPid = oPlayer:GetPid()
    interactive.Request(".rank", "rank", "GetBaikeWeekRank", {}, function (mRecord, mData)
        self:GS2CBaikeWeekRank(iPid, mData)
    end)
end
    
function CHuodong:GS2CBaikeWeekRank(iPid, mData)
    local oPlayer = global.oWorldMgr:GetOnlinePlayerByPid(iPid)
    if not oPlayer then return end
    local mNet = {}
    mNet.unit = mData.net
    mNet.score = oPlayer.m_oThisWeek:Query("baike_weekscore", 0)
    oPlayer:Send("GS2CBaikeWeekRank", mNet)
end

function CHuodong:SendCurRankReward()
    local oNotifyMgr = global.oNotifyMgr
    for iRank, pid in ipairs(self.m_mCurRank) do
        local iReward = self:GetCurRankReward(iRank)
        if iReward then
            local sReward = tostring(iReward)
            local oPlayer = global.oWorldMgr:GetOnlinePlayerByPid(pid)
            if oPlayer then
                local sMsg = self:GetTextData(1001)
                sMsg = global.oToolMgr:FormatColorString(sMsg, {rank = iRank})
                oNotifyMgr:Notify(pid, sMsg)
                self:Reward(pid, sReward)
            else
                self:AsyncReward(pid, sReward, function(mReward)
                    self:RewardRank(pid, 2025, iRank, mReward)   
                end)
            end
        end
        self.m_mAward[pid] = nil
    end
end

function CHuodong:SendGameAward()
    -- self:_SendGameAward(self.m_mAward)
    local mPids = self.m_mAward
    self:AddTimeCb("gameaward", 500, function ()
        self:_SendGameAward(mPids)
    end)
end

function CHuodong:_SendGameAward(mPids)
    self:DelTimeCb("gameaward")
    if not next(mPids) then
        return
    end
    local iCnt = 1
    local iRank = self.m_iTopRank + 1
    local iReward = self:GetCurRankReward(iRank)
    if not iReward then return end
    local sReward = tostring(iReward)
    local lSend = {}
    local oWorldMgr = global.oWorldMgr

    for pid, _ in pairs(mPids) do
        local oPlayer = oWorldMgr:GetOnlinePlayerByPid(pid)
        if oPlayer then
            local sMsg = self:GetTextData(1003)
            global.oNotifyMgr:Notify(pid, sMsg)
            self:Reward(pid, sReward)
        else
            self:AsyncReward(pid, sReward, function(mReward)
                self:RewardRank(pid, 2027, iRank, mReward)   
            end)
        end
        table.insert(lSend, pid)
        iCnt = iCnt + 1
        if iCnt > 100 then
            break
        end
    end
    for _, pid in pairs(lSend) do
        mPids[pid] = nil
    end
    self:AddTimeCb("gameaward", 1 * 1000, function ()
        self:_SendGameAward(mPids)
    end)
end

function CHuodong:RewardRank(pid, iMailID, iRank, mReward)
    local oMailMgr = global.oMailMgr
    local mData, sName = oMailMgr:GetMailInfo(iMailID)
    mData.context = global.oToolMgr:FormatColorString(mData.context, {rank = iRank})
    oMailMgr:SendMailNew(0, sName, pid, mData, mReward)
end

function CHuodong:GetCurRankReward(iRank)
    local iReward
    local mReward = res["daobiao"]["huodong"][self.m_sName]["currank_reward"]
    for idx, mInfo in ipairs(mReward) do
        local iBegin, iEnd = table.unpack(mInfo["rank_list"])
        if iRank >= iBegin and iRank <= iEnd then
            iReward = mInfo["reward"]
            break
        end
    end
    return iReward
end

function CHuodong:GetWeekRankReward(iRank)
    local iReward, iTitle = 0, 0
    local mReward = res["daobiao"]["huodong"][self.m_sName]["weekrank_reward"]
    for idx, mInfo in ipairs(mReward) do
        local iBegin, iEnd = table.unpack(mInfo["rank_list"])
        if not iEnd then
            iEnd = iBegin
        end
        if iRank >= iBegin and iRank <= iEnd then
            iReward = mInfo["reward"]
            iTitle = mInfo["title"]
            break
        end
    end
    return iReward, iTitle
end

function CHuodong:ToDealWeekRank()
    -- 周日最后一次活动获得称谓及参与华山论道资格
    if get_time() > self.m_iStartTime then
        self:DealWeekRank()
    end
end

function CHuodong:DealWeekRank()
    interactive.Send(".rank", "rank", "UpdateBaikeWeekRank", {})
    interactive.Request(".rank", "rank", "GetBaikeWeekRank", {}, function (mRecord, mData)
        self:_DealWeekRank2(mData)
    end)
end

function CHuodong:_DealWeekRank2(mData)
    local mNet = mData.net
    for iRank, mInfo in ipairs(mNet) do
        local pid = mInfo["pid"]
        local iReward, iTitle = self:GetWeekRankReward(iRank)
        local sReward = tostring(iReward)
        self:AsyncReward(pid, sReward, function(mReward)
            self:RewardRank(pid, 2026, iRank, mReward)   
        end)

        if iTitle and iTitle ~= 0 then
            global.oTitleMgr:AddTitle(pid, iTitle)
        end

        -- TODO: 前30名获得华山论道资格
    end
end

function CHuodong:LogAnalyInfo(oPlayer, iQuestion, bResult, iCostTime, iScore)
    local mLog = oPlayer:BaseAnalyInfo()
    mLog["question_id"] = iQuestion
    mLog["result"] = bResult
    mLog["cost_time"] = iCostTime
    mLog["score"] = iScore
    analy.log_data("BaiKe", mLog)
end

----------- TestOP ------------
function CHuodong:TestOp(iFlag, mArgs)
    local oChatMgr = global.oChatMgr
    local iPid = mArgs[#mArgs]
    local oMaster = global.oWorldMgr:GetOnlinePlayerByPid(iPid)

    local mCommand = {
        "101.活动开启\nhuodongop baike 101",
        "102.活动结束\nhuodongop baike 102",
        "103.清楚活动相关数据\nhuodongop baike 103",
    }
    if iFlag == 100 then
        for idx=#mCommand, 1, -1 do
            oChatMgr:HandleMsgChat(oMaster, mCommand[idx])
        end
    elseif iFlag == 101 then
        self.m_iEndTime = get_time() + 30 * 60
        self.m_iStartTime = get_time()
        self:GameStart()
    elseif iFlag == 102 then
        self:GameOver()
    elseif iFlag == 103 then    -- 重新开始答题
        oMaster.m_oThisTemp:Delete("baike_question")
        oMaster.m_oThisTemp:Delete("baike_ring")
        oMaster.m_oThisTemp:Delete("baike_exclude")
        oMaster.m_oThisTemp:Delete("baike_qtime")
    elseif iFlag == 201 then
        self:InitGameStartTime()
    elseif iFlag == 202 then
        self:SendCurRankReward()
    elseif iFlag == 203 then
        self:ToDealWeekRank()
    elseif iFlag == 204 then
        self:DealWeekRank()
    end
    
end

