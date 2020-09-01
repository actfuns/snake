local global = require "global"
local res = require "base.res"
local interactive = require "base.interactive"
local record = require "public.record"
local extend = require "base.extend"
local net = require "base.net"
local gamedefines = import(lualib_path("public.gamedefines"))
local huodongbase = import(service_path("huodong.huodongbase"))
local match = import(service_path("huodong.orgwar.match"))
local uimgr = import(service_path("huodong.orgwar.uimgr"))
local handleteam = import(service_path("team.handleteam"))


STATE_NONE      = 0
STATE_REWARD    = 1
STATE_REWARDED  = 2

-----------TODO list------------
--3.内存泄露
--4.跨场景归队
--------------------------------
PropHelperFunc = {}
PropHelperFunc.pid = function(oHuodong, oPlayer)
    return oPlayer:GetPid()
end

PropHelperFunc.group_id = function(oHuodong, oPlayer)
    return oHuodong:GetGroupId(oPlayer)
end

PropHelperFunc.prepare_time = function(oHuodong, oPlayer)
    return oHuodong.m_iPrepareTime
end

PropHelperFunc.start_time = function(oHuodong, oPlayer)
    return oHuodong.m_iStartTime
end

PropHelperFunc.end_time = function(oHuodong, oPlayer)
    return oHuodong.m_iEndTime
end

PropHelperFunc.win = function(oHuodong, oPlayer)
    return oPlayer.m_oThisTemp:Query("singlewar_win", 0)
end

PropHelperFunc.win_seri_curr = function(oHuodong, oPlayer)
    return oPlayer.m_oThisTemp:Query("singlewar_seri_win_curr", 0)
end

PropHelperFunc.win_seri_max = function(oHuodong, oPlayer)
    return oPlayer.m_oThisTemp:Query("singlewar_seri_win_max", 0)
end

PropHelperFunc.war_cnt = function(oHuodong, oPlayer)
    return oPlayer.m_oThisTemp:Query("singlewar_cnt", 0)
end

PropHelperFunc.rank = function(oHuodong, oPlayer)
    return 0
end

PropHelperFunc.point = function(oHuodong, oPlayer)
    return oPlayer.m_oThisTemp:Query("singlewar_point", 0)
end

PropHelperFunc.reward_first = function(oHuodong, oPlayer)
    return oPlayer.m_oThisTemp:Query("singlewar_reward_first", 0)
end

PropHelperFunc.reward_five = function(oHuodong, oPlayer)
    return oPlayer.m_oThisTemp:Query("singlewar_reward_five", 0)
end

PropHelperFunc.is_match = function(oHuodong, oPlayer)
    return oPlayer.m_oThisTemp:Query("singlewar_matching", 0)
end


function NewHuodong(sHuodongName)
    return CHuodong:New(sHuodongName)
end

CHuodong = {}
CHuodong.__index = CHuodong
CHuodong.m_sTempName = "蜀山论道"
inherit(CHuodong, huodongbase.CHuodong)

function CHuodong:New(sHuodongName)
    local o = super(CHuodong).New(self, sHuodongName)
    return o
end

function CHuodong:Init()
    self.m_iScheduleID = 1039
    self.m_iStartTime = 0
    self.m_iEndTime = 0
    self.m_iPrepareTime = 0
    self.m_mGroupRank = {}
    self.m_lRankInfo = {}
    self.m_mGroup2Name = {}
    self.m_bRewardRank = false
    self.m_mGroup2Scene = {}

    self:InitGameTime()
    self:CheckAddTimer()
    if self:IsOpenDay() then
        self:SetHuodongState(gamedefines.ACTIVITY_STATE.STATE_READY)
    end
end

function CHuodong:NeedSave()
    return false
end

function CHuodong:MergeFrom(mFromData)
    return true
end

function CHuodong:IsOpenDay(iTime)
    return get_dayno(self.m_iStartTime) == get_dayno(iTime)
end

function CHuodong:InHuodongTime()
    local iCurrTime = get_time()
    return iCurrTime >= self.m_iStartTime and iCurrTime < self.m_iEndTime
end

function CHuodong:GetStartTime()
    return get_time_format_str(self.m_iStartTime, "%H:%M")
end

function CHuodong:ValidShow(oPlayer)
    local iCurrTime = get_time()
    return iCurrTime >= self.m_iPrepareTime and iCurrTime < self.m_iEndTime
end

function CHuodong:GetNPCMenu()
    return "参加论道"
end

function CHuodong:GetKeepTime()
    return math.max(3600, (self.m_iEndTime - get_time() + 300))
end

function CHuodong:GetGroupId(oPlayer)
    if oPlayer.m_oThisTemp:Query("match_group") then
        return oPlayer.m_oThisTemp:Query("match_group")
    end
    local oScene = oPlayer.m_oActiveCtrl:GetNowScene()
    if oScene and oScene.m_iGroup then
        return oScene.m_iGroup
    end
    return self:GetGroupByGrade(oPlayer:GetGrade())
end

function CHuodong:SetHuodongState(iState)
    if global.oHuodongMgr:QueryHuodongState(self.m_sName) == iState then
        return
    end
    local sTime = self:GetStartTime()
    global.oHuodongMgr:SetHuodongState(self.m_sName, self.m_iScheduleID, iState, sTime)
end

function CHuodong:InitGameTime(mNow)
    local mConfig = self:GetConfig()
    local iStartTime = self:AnalyseTime(mConfig.start_time)

    local iTime = mNow and mNow.time or get_time()
    local iWDay = mNow and mNow.date.wday or get_weekday()
    if table_in_list(self:GetWeekDays(), iWDay) and iTime < iStartTime then
        self.m_iStartTime = iStartTime
        self.m_iEndTime = iStartTime + mConfig.continue_time*60
        self.m_iPrepareTime = iStartTime + mConfig.tip_time_shift*60
        return
    end
end

function CHuodong:NewHour(mNow)
    if not global.oToolMgr:IsSysOpen("SINGLEWAR") then
        return
    end

    local iWeekDay = mNow.date.wday
    local iTime = mNow.time
    if table_in_list(self:GetWeekDays(), iWeekDay) then
        self:InitGameTime(mNow)
        self:CheckAddTimer(mNow)
        if self:IsOpenDay(iTime) and not self:InHuodongTime() then
            self:SetHuodongState(gamedefines.ACTIVITY_STATE.STATE_READY)
        end
    end
end

function CHuodong:GetWeekDays()
    local mConfig = self:GetConfig()
    if self.m_iTestWeekDay then
        return {self.m_iTestWeekDay}
    else
        return {mConfig.week_day}
    end
end

function CHuodong:CheckAddTimer(mNow)
    if self.m_iStartTime == 0 then return end

    local mConfig = self:GetConfig()
    local iCurrTime = mNow and mNow.time or get_time()
    local iDelta = self.m_iStartTime - iCurrTime
    if iDelta > 0 and iDelta <= 3600 then
        if self.m_iPrepareTime - iCurrTime > 1 then
            self:DelTimeCb("NotifyGameStart")
            self:AddTimeCb("NotifyGameStart", (self.m_iPrepareTime - iCurrTime)*1000, function()
                self:NotifyGameStart()
            end)
        end

        self:DelTimeCb("GameStart")
        self:AddTimeCb("GameStart", iDelta*1000, function()
            self:GameStart()
        end)
    end
end

function CHuodong:GameStart()
    record.info("game true start singlewar")

    self:DelTimeCb("GameStart")
    self:DelTimeCb("NotifyGameStart")
    self:DelTimeCb("ReleaseScene")
    self:DelTimeCb("GameOver")
    self:AddTimeCb("GameOver", (self.m_iEndTime-self.m_iStartTime)*1000, function()
        self:GameOver()
    end)

    self:SysAnnounce(1103)
    self:StartMatch()
end

function CHuodong:GameOver()
    record.info("game over singlewar")
    self:DelTimeCb("GameStart")
    self:DelTimeCb("NotifyGameStart")
    self:DelTimeCb("GameOver")
    self:DelTimeCb("ReleaseScene")
    self:SetHuodongState(gamedefines.ACTIVITY_STATE.STATE_END)

    self:ClearMatchInfo()
    self:Init()

    self:ClearSingleWarRankInfo(true)
end

function CHuodong:GameOverSysAnnounce()
    local lMsg = {"本次蜀山论道已结束",}
    local lAllGroup = self:GetGroupInfo()
    local sMsg = "恭喜#role获得#group第一名"
    for i = #lAllGroup, 1, -1 do
        if self.m_mGroup2Name[i] then
            local sGroup = lAllGroup[i].name
            local mReplace = {role=self.m_mGroup2Name[i], group=sGroup}
            local sMsg = global.oToolMgr:FormatColorString(sMsg, mReplace)
            table.insert(lMsg, sMsg)
        end
    end
    sMsg = table.concat(lMsg, ",")
    global.oChatMgr:HandleSysChat(sMsg, gamedefines.SYS_CHANNEL_TAG.RUMOUR_TAG, 1)
end

function CHuodong:GameOverNotifyMessage()
    local lPidList = table_key_list(self.m_mJoinPlayer or {})
    global.oToolMgr:ExecuteList(lPidList, 500, 500, 0, "SingleWarGameOver",
    function(iPid)
        self:GameOverNotifyMessage2(iPid)
    end,
    function()
        self:ReleaseScene()
        self.m_mJoinPlayer = {}
    end)
end

function CHuodong:GameOverNotifyMessage2(iPid)
    local oPlayer = global.oWorldMgr:GetOnlinePlayerByPid(iPid)
    if self.m_mGroupRank[iPid] then
        local iRank, iGroup = table.unpack(self.m_mGroupRank[iPid])
        local mGroup = self:GetGroupInfo()[iGroup] or {}
        if iRank > 10 then
            self:Notify(iPid, 5003)
        elseif iRank == 1 then
            self:Notify(iPid, 5001, {group=mGroup.name or ""})
        else
            self:Notify(iPid, 5002, {group=mGroup.name or "", rank=iRank})
        end
    else
        self:Notify(iPid, 5003)
    end
    if oPlayer then
        local mNet = self:PackFinalInfo(oPlayer)
        oPlayer:Send("GS2CSingleWarFinalRank", mNet)
    end
end

function CHuodong:NotifyGameStart()
    record.info("prepare game start singlewar")
    self:SysAnnounce(1102)
    self:ClearMatchInfo()
    self:SetHuodongState(gamedefines.ACTIVITY_STATE.STATE_START)
    self:CreateWarScene()
    self:ClearSingleWarRankInfo()
    self:TryStartRewardMonitor()
end

function CHuodong:ReleaseOneScene(iScene, func)
    local oScene = global.oSceneMgr:GetScene(iScene)
    if not oScene then return end

    for iNpc, _ in pairs(oScene.m_mNpc) do
        local oNpc = self:GetNpcObj(iNpc)
        if oNpc then
            self:RemoveTempNpc(oNpc)
        end
    end
    for iPid, _ in pairs(oScene.m_mPlayers) do
        local oPlayer = global.oWorldMgr:GetOnlinePlayerByPid(iPid)
        if oPlayer then
            if func then
                func(oPlayer)
            else
                self:TryTransferHome(oPlayer)
            end
        end
    end
    self.m_mGroup2Scene[oScene.m_iGroup] = nil
    self.m_mSceneList[oScene.m_iSceneIdx] = nil
    global.oSceneMgr:RemoveScene(iScene)
end

function CHuodong:ReleaseScene()
    local mConfig = self:GetConfig()
    local iKeepTime = self:GetKeepTime()
    if table_count(self.m_mSceneList) > 0 then
        for iSceneIdx, iScene in pairs(self.m_mSceneList) do
            local oScene = global.oSceneMgr:GetScene(iScene)
            if oScene then
                local iTotal = 0 
                for iNpc, _ in pairs(oScene.m_mNpc) do
                    local oNpc = self:GetNpcObj(iNpc)
                    if oNpc then
                        self:RemoveTempNpc(oNpc)
                    end
                end
           
                for iPid, _ in pairs(oScene.m_mPlayers) do
                    local oPlayer = global.oWorldMgr:GetOnlinePlayerByPid(iPid)
                    if oPlayer and oPlayer.m_oActiveCtrl:GetWarStatus() == gamedefines.WAR_STATUS.NO_WAR then
                        self:TryTransferHome(oPlayer)
                        
                        iTotal = iTotal + 1
                        if iTotal >= 100 then
                            break
                        end
                    end
                end
    
                if table_count(oScene.m_mPlayers) <= 0 then
                    self.m_mSceneList[iSceneIdx] = nil
                    global.oSceneMgr:RemoveScene(iScene)
                end
            else
                self.m_mSceneList[iSceneIdx] = nil
            end
        end

        self:DelTimeCb("ReleaseScene")
        self:AddTimeCb("ReleaseScene", 1000, function()
            self:ReleaseScene()
        end)
    else
        self:Init()
        self:TryStopRewardMonitor()
    end
end

function CHuodong:CheckUnGetReward(oPlayer)
    local mKey2Reward = {
        {"singlewar_reward_first", "reward_first"},
        {"singlewar_reward_five", "reward_five"},
    }
    local mConfig = self:GetConfig()
    local iKeepTime = self:GetKeepTime()
    local iGroup = self:GetGroupId(oPlayer)
    local lReward = {}
    for _, mInfo in ipairs(mKey2Reward) do
        local sKey, iReward = mInfo[1], mConfig[mInfo[2]][iGroup]
        if oPlayer.m_oThisTemp:Query(sKey) == STATE_REWARD then
            oPlayer.m_oThisTemp:Reset(sKey, STATE_REWARDED, iKeepTime)
            table.insert(lReward, iReward)
        end
    end
    return lReward
end

function CHuodong:BuildSingleWarRank(mGroupRank)
    for iGroup, mRank in pairs(mGroupRank) do
        for iRank, mUnit in pairs(mRank.singlewar or {}) do
            local iPid = tonumber(mUnit.pid)
            self.m_mGroupRank[iPid] = {iRank, iGroup}
            if iRank == 1 then
                self.m_mGroup2Name[iGroup] = mUnit.name
            end
        end
    end
    local lRankInfo = {}
    for iGroup, mRank in pairs(mGroupRank) do
        local mUnit = {}
        mUnit.group_id= iGroup
        mUnit.rank_info = {}
        for iRank, mInfo in pairs(mRank.singlewar or {}) do
            if iRank > 10 then
                break
            end
            mUnit.rank_info[iRank] = mInfo
        end
        table.insert(lRankInfo, mUnit)
    end
    self.m_lRankInfo = lRankInfo
end

function CHuodong:TryRewardPlayerByRank(mGroupRank)
    local mGroupReward = self:GetRankReward()
    for iGroup, mRank in pairs(mGroupRank) do
        local mAllGroup = self:GetGroupInfo()
        local mGroup = mAllGroup[iGroup]
        if not mGroup then goto continue end

        for iRank, mUnit in pairs(mRank.singlewar or {}) do
            local mReward = mGroupReward[iRank]
            if mReward then
                local iPid = tonumber(mUnit.pid)
                local mReplace = {rank = iRank, group=mGroup.name}
                self:AsyncReward(iPid, mReward.reward[iGroup], function(mReward)
                    self:TryRewardPlayerByRank2(iPid, mReward, mReplace)
                end)
                --self:Reward(iPid, mReward.reward[iGroup], {mail_replace=mReplace})
                
                if mReward.title and mReward.title > 0 then
                    local sName = global.oToolMgr:FormatString(mReward.title_name, {name=mGroup.name})
                    global.oTitleMgr:AddTitle(iPid, mReward.title, sName)
                end
            end
        end
        ::continue::
    end
end

function CHuodong:TryRewardPlayerByRank2(iPid, mReward, mReplace)
    --目前的奖励品种支持此写法
    assert(mReward.mail_id)
    local oPlayer = global.oWorldMgr:GetOnlinePlayerByPid(iPid)
    if not oPlayer then
        oPlayer = global.oWorldMgr:GetProfile(iPid)
    end
    assert(oPlayer)
    self:SendRewardContent(oPlayer, mReward, {mail_replace=mReplace})
end

function CHuodong:TrySendMailReward(oPlayer, lReward, iMailId)
    local mContent = {}
    for _, iReward in ipairs(lReward) do
        local mInfo = self:GetRewardData(iReward)
        local mTmp = self:GenRewardContent(oPlayer, mInfo)
        for sType, rVal in pairs(mTmp) do
            if sType == "summexp" then
                self:RewardSummonExp(oPlayer, rVal)
                goto continue
            end
            if not mContent[sType] then
                mContent[sType] = rVal
            else
                if type(rVal) == "number" then
                    mContent[sType] = mContent[sType] + rVal
                elseif type(rVal) == "table" then
                    for k, v in pairs(rVal) do
                        mContent[sType][k] = v
                    end
                end
            end
            ::continue::
        end
    end
    local lItem = {}
    for iItemIdx, mItems in pairs(mContent.items or {}) do
        lItem = list_combine(lItem, mItems["items"])
    end
    mContent.items = lItem

    local mData, sName = global.oMailMgr:GetMailInfo(iMailId)
    if not mData then return end
    global.oMailMgr:SendMailNew(0, sName, oPlayer:GetPid(), mData, mContent)
end

function CHuodong:StartMatch()
    global.oNotifyMgr:WorldBroadcast("GS2CSingleWarStartMatch", {})

    interactive.Request(".recommend", "singlewar", "StartMatch", {},
    function(mRecord, mData)
        self:StartMatch2(mData)
    end)
end

function CHuodong:StartMatch2(mData)
    if mData.start == false then
        local sMsg = self:GetTextData(2007)
        global.oNotifyMgr:WorldBroadcast("GS2CNotify", {cmd=sMsg})

        self:GameOver()
    else
        local lAllGroup = self:GetGroupInfo()
        for iGroup = #lAllGroup, 1, -1 do
            local mStart = mData.result[iGroup]
            local bStart, bRelease = mStart[1], mStart[3]=="release"
            if bStart then goto continue end

            local mGroup = lAllGroup[iGroup]
            local iScene = self.m_mGroup2Scene[iGroup] or 0
            local oScene = global.oSceneMgr:GetScene(iScene)
            if not oScene then goto continue end

            if bRelease then
                local sMsg = self:GetTextData(2008)
                sMsg = global.oToolMgr:FormatColorString(sMsg, {group=mGroup.name})
                oScene:BroadcastMessage("GS2CNotify", {cmd=sMsg})
                self:ReleaseOneScene(iScene)
            else
                if self.m_mGroup2Scene[iGroup] and self.m_mGroup2Scene[iGroup-1] then
                    local sMsg = self:GetTextData(2009)
                    local mReplace = {group = {mGroup.name, lAllGroup[iGroup-1].name}}
                    sMsg = global.oToolMgr:FormatColorString(sMsg, mReplace)
                    oScene:BroadcastMessage("GS2CNotify", {cmd=sMsg})
                    self:TransAllPlayer2Scene(iGroup, iGroup-1)
                end
                self:ReleaseOneScene(iScene)
            end
            ::continue::
        end

        interactive.Send(".recommend", "singlewar", "DoStartMatch", {})
    end
end

function CHuodong:TransAllPlayer2Scene(iGroup, iTargetGroup)
    local iScene = self.m_mGroup2Scene[iGroup]
    local iTargetScene = self.m_mGroup2Scene[iTargetGroup]
    if not iScene or not iTargetScene then
        return
    end
    local oScene = global.oSceneMgr:GetScene(iScene)
    local oTargetScene = global.oSceneMgr:GetScene(iTargetScene)
    if not oScene or not oTargetScene then
        return
    end
    local iMapId = oTargetScene:MapId()
    for iPid, _ in pairs(oScene.m_mPlayers) do
        local oPlayer = global.oWorldMgr:GetOnlinePlayerByPid(iPid)
        if not oPlayer then
            goto continue
        end
        if oPlayer.m_oActiveCtrl:GetWarStatus() ~= gamedefines.WAR_STATUS.NO_WAR then
            goto continue
        end
        if oPlayer:HasTeam() then
            oPlayer:HasTeam():Leave(oPlayer:GetPid())
        end
        local iX, iY = global.oSceneMgr:RandomPos2(iMapId)
        global.oSceneMgr:DoTransfer(oPlayer, iTargetScene, {x=iX, y=iY})
        ::continue::
    end
end

function CHuodong:UpdateMatchInfo(oPlayer)
    local mMatch = {
        pid = oPlayer:GetPid(),
        grade = oPlayer:GetGrade(),
        match_fight = oPlayer.m_oThisTemp:Query("match_fight") or {},
        win = oPlayer.m_oThisTemp:Query("singlewar_win", 0),
        group = self:GetGroupId(oPlayer),
    }
    interactive.Send(".recommend", "singlewar", "UpdateMatchInfo", mMatch)

    local iKeepTime = self:GetKeepTime()
    oPlayer.m_oThisTemp:Reset("singlewar_matching", 1, iKeepTime)
end

function CHuodong:ClearMatchInfo()
    interactive.Send(".recommend", "singlewar", "ClearMatchInfo", {})
end

function CHuodong:MatchResult(lMatch)
    if not self:InHuodongTime() then return end
    local mConfig = self:GetConfig()
    for _, mMatch in ipairs(lMatch or {}) do
        local iPid1, iPid2, iGroup = table.unpack(mMatch)
        local oPlayer1 = global.oWorldMgr:GetOnlinePlayerByPid(iPid1)
        local oPlayer2 = global.oWorldMgr:GetOnlinePlayerByPid(iPid2)
        local iRet1 = self:ValidStartWar(oPlayer1)
        local iRet2 = self:ValidStartWar(oPlayer2)
        if oPlayer1 then
            self:PlayerStopMatch(oPlayer1)
            if iRet1 == 1 and iRet2 == 1 then
                local mNet = {
                    role = oPlayer2:PackSimpleInfo(),
                    score = oPlayer2:GetScore(),
                }
                oPlayer1:Send("GS2CSingleWarMatchResult", mNet)
            else
                oPlayer1:Send("GS2CSingleWarMatchResult", {})
            end
        end
        if oPlayer2 then
            self:PlayerStopMatch(oPlayer2)
            if iRet1 == 1 and iRet2 == 1 then
                local mNet = {
                    role = oPlayer1:PackSimpleInfo(),
                    score = oPlayer1:GetScore(),
                }
                oPlayer2:Send("GS2CSingleWarMatchResult", mNet)
            else
                oPlayer2:Send("GS2CSingleWarMatchResult", {})
            end
        end

        if iRet1 == 1 and iRet2 == 1 then
            local sKey = iPid1..iPid2
            self:DelTimeCb(sKey)
            self:AddTimeCb(sKey, 3000, function()
                self:MatchResult2(iPid1, iPid2, iGroup)
            end)
        end
        local mLogData = {
            action = "匹配结果",
            pid = iPid1 .. "|" .. iPid2,
            status = iRet1 .. "|" .. iRet2,
        }
        record.log_db("huodong", "singlewar", {info = mLogData})
    end
end

function CHuodong:MatchResult2(iPid1, iPid2, iGroup)
    local sKey = iPid1..iPid2
    self:DelTimeCb(sKey)

    local oPlayer1 = global.oWorldMgr:GetOnlinePlayerByPid(iPid1)
    local oPlayer2 = global.oWorldMgr:GetOnlinePlayerByPid(iPid2)
    local iRet1 = self:ValidStartWar(oPlayer1)
    local iRet2 = self:ValidStartWar(oPlayer2)
    if iRet1 == 1 and iRet2 == 1 then
        local iWar = self:CreateSingleWar(oPlayer1, oPlayer2, iGroup)
        global.oWarMgr:StartWar(iWar)
    end

    local mLogData = {
        action = "开始战斗",
        pid = iPid1 .. iPid2,
        status = iRet1 .. iRet2,
    }
    record.log_db("huodong", "singlewar", {info = mLogData})
end

function CHuodong:UpdateRankInfo(oPlayer)
    local iGroup = self:GetGroupId(oPlayer)
    if not iGroup then return end

    local mRank = {
        group = iGroup,
        pid = oPlayer:GetPid(),
        grade = oPlayer:GetGrade(),
        name = oPlayer:GetName(),
        point = oPlayer.m_oThisTemp:Query("singlewar_point", 0),
        score = oPlayer:GetScore(),
        win_seri_max = oPlayer.m_oThisTemp:Query("singlewar_seri_win_max", 0),
    }
    global.oRankMgr:PushDataToRank("singlewar", mRank)
end

function CHuodong:ClearSingleWarRankInfo(bReward)
    interactive.Request(".rank", "rank", "ClearSingleWarRankInfo", {reward=bReward},
    function(mRecord, mData)
        if bReward and not self.m_bRewardRank then
            self.m_bRewardRank = true
            self:BuildSingleWarRank(mData.rank)
            self:GameOverSysAnnounce()
            self:TryRewardPlayerByRank(mData.rank)
            self:GameOverNotifyMessage()
            --self:ReleaseScene()
        end
    end)
end

function CHuodong:OtherScript(iPid, npcobj, s, mArgs)
    local oPlayer = global.oWorldMgr:GetOnlinePlayerByPid(iPid)
    if not oPlayer then return end

    if s == "$transfer_home" then
        self:TryTransferHome(oPlayer)
        return true
    else
        return super(CHuodong).OtherScript(self, iPid, npcobj, s, mArgs)
    end
end

function CHuodong:TryTransferHome(oPlayer)
    if not oPlayer then return end

    local oScene = global.oSceneMgr:SelectDurableScene(101000)
    local iX, iY = global.oSceneMgr:RandomPos2(oScene:MapId())
    global.oSceneMgr:DoTransfer(oPlayer, oScene:GetSceneId(), {x=iX,y=iY})
end

function CHuodong:JoinGame(oPlayer, oNpc)
    local iPid = oPlayer:GetPid()
    local iRet, mReplace = self:ValidJoinGame(oPlayer)
    if iRet ~= 1 then
        self:Notify(iPid, iRet, mReplace)
        return
    end

    self:EnterWarScene(oPlayer)
end

function CHuodong:ValidJoinGame(oPlayer)
    if not global.oToolMgr:IsSysOpen("SINGLEWAR", oPlayer, true) then
        return 1002
    end
    if oPlayer:HasTeam() then
        return 1004
    end
    if not self:IsPartnerLegal(oPlayer) then
        return 1005
    end
    if not self:ValidShow(oPlayer) then
        return 1009
    end
    local mConfig = self:GetConfig()
    if oPlayer.m_oThisTemp:Query("singlewar_cnt", 0) >= mConfig.max_war_cnt then
        return 2002, {name=oPlayer:GetName()}
    end
    return 1
end

function CHuodong:IsPartnerLegal(oPlayer, lPartner)
    local iSchool = oPlayer:GetSchool()
    local iTotal = gamedefines.ASSISTANT_SCHOOL[iSchool] and 1 or 0
    lPartner = lPartner or oPlayer.m_oPartnerCtrl:GetCurrLineupPos()
    for _, iPartner in ipairs(lPartner or {}) do
        local oPartner = oPlayer.m_oPartnerCtrl:GetPartner(iPartner)
        if gamedefines.ASSISTANT_SCHOOL[oPartner:GetSchool()] then
            iTotal = iTotal + 1
        end
    end
    return iTotal <= 3
end

function CHuodong:ValidAdjustPartner(oPlayer, lPartner)
    local iPid = oPlayer:GetPid()
    if not self:IsPartnerLegal(oPlayer, lPartner) then
        self:Notify(iPid, 1008)
        return false
    end
    return true
end

function CHuodong:EnterWarScene(oPlayer)
    local iScene = self:GetEnterWarScene(oPlayer)
    if not iScene then
        local lAllGroup = self:GetGroupInfo()
        local iGroup = self:GetGroupByGrade(oPlayer:GetGrade())
        local mReplace = {group = lAllGroup[iGroup].name}
        self:Notify(oPlayer:GetPid(), 2008, mReplace)
        return
    end

    local oScene = global.oSceneMgr:GetScene(iScene)

    if not oScene then return end

    if not oPlayer.m_oThisTemp:Query("match_group") and self:InHuodongTime() then
        local iGroup = self:GetGroupByGrade(oPlayer:GetGrade())
        if self.m_mGroup2Scene[iGroup] ~= iScene then
            local lAllGroup = self:GetGroupInfo()
            local mReplace = {group = {lAllGroup[iGroup].name, lAllGroup[iGroup-1].name}}
            self:Notify(oPlayer:GetPid(), 2009, mReplace)
        end
    end

    local iX, iY = global.oSceneMgr:RandomPos2(oScene:MapId())
    local mPos = {x = iX, y = iY}
    global.oSceneMgr:DoTransfer(oPlayer, iScene, mPos)
end

function CHuodong:ValidStartWar(oPlayer)
    if not oPlayer then
        return 2001
    end
    local mConfig = self:GetConfig()
    if oPlayer.m_oThisTemp:Query("singlewar_cnt", 0) >= mConfig.max_war_cnt then
        return 2002, {name=oPlayer:GetName()}
    end
    if oPlayer:HasTeam() then
        return 2003, {name=oPlayer:GetName()}
    end
    local oScene = oPlayer:GetNowScene()
    if not oScene or oScene:GetVirtualGame() ~= "singlewar" then
        return 2004, {name=oPlayer:GetName()}
    end
    if not self:IsPartnerLegal(oPlayer) then
        return 2005, {name=oPlayer:GetName()}
    end
    if oPlayer.m_oActiveCtrl:GetWarStatus() ~= gamedefines.WAR_STATUS.NO_WAR then
        return 2006, {name=oPlayer:GetName()}
    end
    return 1
end

function CHuodong:CreateSingleWar(oPlayer1, oPlayer2, iGroup)
    local mConfig = self:GetConfig()
    local iWarType = gamedefines.WAR_TYPE.PVP_TYPE
    local iSysType = gamedefines.GAME_SYS_TYPE.SYS_TYPE_SINGLEWAR
    local mWarConfig = {
        barrage_show = mConfig.barrage_show,
        barrage_send = mConfig.barrage_send,
        GamePlay = "singlewar",
        bout_out = {bout=mConfig.bout_out, result=1},
    }
    local oWar = global.oWarMgr:CreateWar(iWarType, iSysType, mWarConfig)
    local iWar = oWar:GetWarId()
    local iKeepTime = self:GetKeepTime() 
    oWar.m_iGroup = iGroup
   
    for idx, oFighter in ipairs({oPlayer1, oPlayer2}) do
        global.oWarMgr:EnterWar(oFighter, iWar, {camp_id=idx}, true, 4)
        oFighter:MarkGrow(49)
    end

    local mFighter = {[oPlayer2:GetPid()] = 1}
    oPlayer1.m_oThisTemp:Reset("match_fight", mFighter, iKeepTime)

    local mFighter = {[oPlayer1:GetPid()] = 1}
    oPlayer2.m_oThisTemp:Reset("match_fight", mFighter, iKeepTime)

    global.oWarMgr:SetCallback(iWar, function(mArgs)
        self:OnSingleWarFightEnd(iWar, mArgs)
    end)

    return iWar
end

function CHuodong:OnSingleWarFightEnd(iWar, mArgs)
    local lWinner, lLoser, lWinnerEscape, lLoserEscape = self:GetJoinSingleWarMember(mArgs)
    local iWinner = lWinner[1]
    local iLoser = lLoser[1] or lLoserEscape[1]
    assert(iWinner and iLoser)

    local oWinner = global.oWorldMgr:GetOnlinePlayerByPid(iWinner)
    local oLoser = global.oWorldMgr:GetOnlinePlayerByPid(iLoser)

    if not self:InHuodongTime() then
        self:TryTransferHome(oWinner)
        self:TryTransferHome(oLoser)
        return
    end

    local iKeepTime = self:GetKeepTime()
    local mConfig = self:GetConfig()
    local mRefresh = {pid=1, rank=1}
    if oWinner then
        oWinner.m_oThisTemp:Add("singlewar_cnt", 1, iKeepTime)
        oWinner.m_oThisTemp:Add("singlewar_win", 1, iKeepTime)
        mRefresh.war_cnt = 1
        mRefresh.win = 1

        local lSeri = oWinner.m_oThisTemp:Query("singlewar_seri", {})
        table.insert(lSeri, 1)
        oWinner.m_oThisTemp:Reset("singlewar_seri", lSeri, iKeepTime)
        self:CheckSeriWin(oWinner)
        mRefresh.win_seri_curr = 1
        mRefresh.win_seri_max = 1

        if oWinner.m_oThisTemp:Query("singlewar_reward_first", 0) <= 0 then
            oWinner.m_oThisTemp:Add("singlewar_reward_first", 1, iKeepTime)
            mRefresh.reward_first = 1
        end
        if oWinner.m_oThisTemp:Query("singlewar_cnt", 0) == 5 then
            oWinner.m_oThisTemp:Set("singlewar_reward_five", 1, iKeepTime)
            mRefresh.reward_five = 1
        end

        self:AddPoint(oWinner, 10)
        mRefresh.point = 1
        self:Reward(iWinner, mConfig.win_reward)

        if oWinner.m_oThisTemp:Query("singlewar_cnt", 0) < mConfig.max_war_cnt then
            self:UpdateMatchInfo(oWinner)
            mRefresh.is_match = 1
        end
        self:UpdateRankInfo(oWinner)
        self:RefreshSingleWarInfo(oWinner, mRefresh)
        oWinner:Send("GS2CSingleWarStartMatch", {})

        local mLogData = {
            action = "战斗胜利",
            pid = iWinner,
            seri_win = lSeri,
            point = oWinner.m_oThisTemp:Query("singlewar_point", 0),
        }
        record.log_db("huodong", "singlewar", {info = mLogData})
    end
    if oLoser then
        local bEscape = iLoser == lLoserEscape[1]
        oLoser.m_oThisTemp:Add("singlewar_cnt", 1, iKeepTime)
        mRefresh.war_cnt = 1

        local lSeri = oLoser.m_oThisTemp:Query("singlewar_seri", {})
        table.insert(lSeri, 0)
        oLoser.m_oThisTemp:Reset("singlewar_seri", lSeri, iKeepTime)
        self:CheckSeriWin(oLoser)
        mRefresh.win_seri_curr = 1
        mRefresh.win_seri_max = 1

        self:AddPoint(oLoser, 5)
        mRefresh.point = 1

        self:UpdateRankInfo(oLoser)
        if oLoser.m_oThisTemp:Query("singlewar_cnt", 0) == 5 then
            oLoser.m_oThisTemp:Set("singlewar_reward_five", 1, iKeepTime)
            mRefresh.reward_five = 1
        end

        if not bEscape then
            self:Reward(iLoser, mConfig.lose_reward)
        end
        self:RefreshSingleWarInfo(oLoser, mRefresh)

        local mLogData = {
            action = "战斗失败",
            pid = iLoser,
            seri_win = lSeri,
            point = oLoser.m_oThisTemp:Query("singlewar_point", 0),
        }
        record.log_db("huodong", "singlewar", {info = mLogData})
    end
end

function CHuodong:GetJoinSingleWarMember(mArgs)
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

function CHuodong:CheckSeriWin(oPlayer)
    local lSeri = oPlayer.m_oThisTemp:Query("singlewar_seri", {})
    local iMaxWin, iCurrWin = 0, 0
    for idx, iResult in ipairs(lSeri) do
        if iResult == 1 then
            iCurrWin = iCurrWin + 1
            iMaxWin = math.max(iMaxWin, iCurrWin)
        else
            iCurrWin = 0
        end
    end
    local iKeepTime = self:GetKeepTime()
    oPlayer.m_oThisTemp:Reset("singlewar_seri_win_curr", iCurrWin, iKeepTime)
    oPlayer.m_oThisTemp:Reset("singlewar_seri_win_max", iMaxWin, iKeepTime)

    return iMaxWin, iCurrWin
end

function CHuodong:AddPoint(oPlayer, iPoint)
    local iCnt = oPlayer.m_oThisTemp:Query("singlewar_cnt", 0)
    local iKeepTime = self:GetKeepTime()
    if iCnt <= 2 then
        oPlayer.m_oThisTemp:Add("singlewar_point", iPoint, iKeepTime)
    else
        local iCurrWinSeri = oPlayer.m_oThisTemp:Query("singlewar_seri_win_curr", 0)
        local iRatio = self:GetSeriWin2Ratio(iCurrWinSeri)
        oPlayer.m_oThisTemp:Add("singlewar_point", iPoint*iRatio//100, iKeepTime)
    end
end

function CHuodong:PlayerStartMatch(oPlayer)
    local iPid = oPlayer:GetPid()
    local iRet, mReplace = self:ValidStartWar(oPlayer)
    if iRet ~= 1 then
        self:Notify(iPid, iRet, mReplace)
        return
    end

    local iKeepTime = self:GetKeepTime()
    self:UpdateMatchInfo(oPlayer)
    self:RefreshSingleWarInfo(oPlayer, {is_match=1})
end

function CHuodong:PlayerStopMatch(oPlayer)
    local mMatch = {
        pid = oPlayer:GetPid(),
        group = self:GetGroupId(oPlayer)
    }
    interactive.Send(".recommend", "singlewar", "RemoveMatchInfo", mMatch)
    
    oPlayer.m_oThisTemp:Delete("singlewar_matching")
    self:RefreshSingleWarInfo(oPlayer, {is_match=1})
end

function CHuodong:GetRewardFirst(oPlayer)
    local iPid = oPlayer:GetPid()
    local mConfig = self:GetConfig()
    local iStatus = oPlayer.m_oThisTemp:Query("singlewar_reward_first", 0) 
    if iStatus == STATE_REWARD then
        local iGroup = self:GetGroupId(oPlayer)
        local iRewardIdx = mConfig.reward_first[iGroup]
        if not iRewardIdx then
            global.oToolMgr:DebugMsg("未配置分组奖励"..iGroup)
            return
        end
        local iNeedGrids = self:CountRewardItemProbableGrids(oPlayer, iRewardIdx)
        local iHasGrids = oPlayer.m_oItemCtrl:GetCanUseSpaceSize()
        if iHasGrids < iNeedGrids then
            self:Notify(iPid, 1010)
        else
            local iKeepTime = self:GetKeepTime()
            oPlayer.m_oThisTemp:Reset("singlewar_reward_first", STATE_REWARDED, iKeepTime)
            self:RefreshSingleWarInfo(oPlayer, {reward_first=1})
            self:Reward(iPid, iRewardIdx)

            local mLogData = {
                action = "领取首胜",
                pid = iPid,
            }
            record.log_db("huodong", "singlewar", {info = mLogData})
        end
    elseif iStatus == STATE_NONE then
        self:Notify(iPid, 1006)
    else
        self:Notify(iPid, 1007)
    end
end

function CHuodong:GetRewardFive(oPlayer)
    local iPid = oPlayer:GetPid()
    local mConfig = self:GetConfig()
    local iStatus = oPlayer.m_oThisTemp:Query("singlewar_reward_five", 0)
    if iStatus == STATE_REWARD then
        local iGroup = self:GetGroupId(oPlayer)
        local iRewardIdx = mConfig.reward_five[iGroup]
        if not iRewardIdx then
            global.oToolMgr:DebugMsg("未配置分组奖励"..iGroup)
            return
        end
        local iKeepTime = self:GetKeepTime()
        local iNeedGrids = self:CountRewardItemProbableGrids(oPlayer, iRewardIdx)
        local iHasGrids = oPlayer.m_oItemCtrl:GetCanUseSpaceSize()
        if iHasGrids < iNeedGrids then
            self:Notify(iPid, 1010)
        else
            oPlayer.m_oThisTemp:Reset("singlewar_reward_five", STATE_REWARDED, iKeepTime)
            self:RefreshSingleWarInfo(oPlayer, {reward_five=1})
            self:Reward(iPid, iRewardIdx)

            local mLogData = {
                action = "领取五战",
                pid = iPid,
            }
            record.log_db("huodong", "singlewar", {info = mLogData})
        end
    elseif iStatus == STATE_NONE then
        self:Notify(iPid, 1006)
    else
        self:Notify(iPid, 1007)
    end
end

function CHuodong:PackPlayerInfo(oPlayer, mRefresh)
    mRefresh = mRefresh or PropHelperFunc
    local mRet = {}
    for k, v in pairs(mRefresh) do
        local f = assert(PropHelperFunc[k], string.format("singlewar fail f get %s", k))
        mRet[k] = f(self, oPlayer)
    end
    return mRet
end

function CHuodong:RefreshSingleWarInfo(oPlayer, mRefresh)
    local iGroup = self:GetGroupId(oPlayer)
    local mRet = self:PackPlayerInfo(oPlayer, mRefresh)
    if mRet.rank then
        local mInfo = {
            rank_name = "singlewar",
            refresh = mRet,
            pid = oPlayer:GetPid(),
            group = iGroup,
        }
        interactive.Send(".rank", "rank", "RefreshSingleWarInfo", mInfo)
    else
        local mNet = net.Mask("SingleWarInfo", mRet)
        oPlayer:Send("GS2CSingleWarInfo", {info=mNet})
    end
end

function CHuodong:RefreshRankByGroup(oPlayer, iGroup)
    assert(iGroup > 0 and iGroup < 5)

    local mArgs = {
        pid = oPlayer:GetPid(),
        group = iGroup,
    }
    interactive.Send(".rank", "rank", "RefreshRankByGroup", mArgs)
end

function CHuodong:GetGroupByGrade(iGrade)
    for idx, mGrade in ipairs(res["daobiao"]["huodong"][self.m_sName]["grade2scene"]) do
        if iGrade <= mGrade.max_grade then
            return idx
        end
    end
end

function CHuodong:GetConfig()
    return res["daobiao"]["huodong"][self.m_sName]["config"][1]
end

function CHuodong:GetRankReward()
    return res["daobiao"]["huodong"][self.m_sName]["rankreward"]
end

function CHuodong:GetGroupInfo()
    return res["daobiao"]["huodong"][self.m_sName]["grade2scene"]
end

function CHuodong:GetSceneData(iScene)
    local mData = res["daobiao"]["huodong"][self.m_sName]
    return mData["scene"][iScene]
end

function CHuodong:GetGrade2SceneIdx(iGrade)
    for _, mGrade in ipairs(self:GetGroupInfo()) do
        if iGrade >= mGrade.min_grade and iGrade <= mGrade.max_grade then
            return mGrade.scene_idx
        end
    end
end

function CHuodong:GetSeriWin2Ratio(iSeriWin)
    for _, mInfo in ipairs(res["daobiao"]["huodong"][self.m_sName]["seriwin2ratio"]) do
        if iSeriWin >= mInfo.win_seri then
            return mInfo.ratio
        end
    end
    return 100
end

function CHuodong:AnalyseTime(sTime)
    local mCurrDate = os.date("*t", get_time())
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

function CHuodong:TestOp(iFlag, mArgs)
    local iPid = mArgs[#mArgs]
    local oMaster = global.oWorldMgr:GetOnlinePlayerByPid(iPid)
    if iFlag == 100 then
        global.oNotifyMgr:Notify(iPid, [[
        101 - 查看匹配等级
        102 - 准备开启活动
        103 - 开始活动
        104 - 结束活动
        105 - 加入匹配
        106 - 开始战斗 {target=id, group=1}
        107 - 推送数据进排行榜
        108 - 清除已匹配过的玩家
        ]])
    elseif iFlag == 101 then
        local iGrade = oMaster.m_oThisTemp:Query("match_grade") or oMaster:GetGrade()
        global.oNotifyMgr:Notify(iPid, "匹配等级"..iGrade)
    elseif iFlag == 102 then
        local iPrepareTime = get_time()
        local mConfig = self:GetConfig()
        self.m_iPrepareTime = iPrepareTime
        self.m_iStartTime = iPrepareTime - mConfig.tip_time_shift*60
        self.m_iEndTime = self.m_iStartTime + mConfig.continue_time*60
        self:NotifyGameStart()
    elseif iFlag == 103 then
        local iStartTime = get_time()
        local mConfig = self:GetConfig()
        self.m_iStartTime = iStartTime
        self.m_iEndTime = iStartTime + mConfig.continue_time*60
        self.m_iPrepareTime = iStartTime + mConfig.tip_time_shift*60
        self:GameStart()
    elseif iFlag == 104 then
        self:GameOver()
        self:DelTimeCb("TestClearInfo")
        self:AddTimeCb("TestClearInfo", 5000, function()
            for iPid, oPlayer in pairs(global.oWorldMgr:GetOnlinePlayerList()) do
                oPlayer.m_oThisTemp.m_mData = {}
                oPlayer.m_oThisTemp.m_mKeepList = {}
                oPlayer.m_oThisTemp:Dirty()
            end
        end)
    elseif iFlag == 105 then
        self:UpdateMatchInfo(oMaster)
    elseif iFlag == 106 then
        local lMatch = {{oMaster:GetPid(), mArgs.target, mArgs.group or 1}}
        self:MatchResult(lMatch)
    elseif iFlag == 107 then
        self:UpdateRankInfo(oMaster)
    elseif iFlag == 108 then
        oMaster.m_oThisTemp:Delete("match_fight")
    elseif iFlag == 501 then
        --测试匹配数据
        self:ClearMatchInfo()
        for i = 1, 100 do
            local mMatch = {
                pid = 10000 + i,
                grade = math.random(50, 100),
                match_fight = {},
                win = math.random(1, 2),
            }
            interactive.Send(".recommend", "singlewar", "UpdateMatchInfo", mMatch)
        end

        self:StartMatch()
    end
end

-----------------场景相关---------------
function CHuodong:GetEnterWarScene(oPlayer)
    local iGroup = self:GetGroupId(oPlayer)
    if not iGroup then
        local iGrade = oPlayer:GetGrade()
        iGroup = self:GetGroupByGrade(iGrade)
    end
    return self.m_mGroup2Scene[iGroup] or self.m_mGroup2Scene[iGroup-1]
end

function CHuodong:CreateWarScene()
    local lGroup = self:GetGroupInfo()
    for idx, mGroup in ipairs(lGroup) do
        local iSceneIdx = mGroup.scene_idx
        local mInfo = self:GetSceneData(iSceneIdx)
        local mData ={
            map_id = mInfo.map_id,
            team_allowed = mInfo.team_allowed,
            deny_fly = mInfo.deny_fly,
            is_durable = mInfo.is_durable==1,
            has_anlei = mInfo.has_anlei == 1,
            url = {"huodong", self.m_sName, "scene", iSceneIdx},
        }
        local oScene = global.oSceneMgr:CreateVirtualScene(mData)
        oScene.m_HDName = self.m_sName
        oScene.m_iGroup = mGroup.id
        oScene.m_iSceneIdx = iSceneIdx
   
        local iScene = oScene:GetSceneId() 
        self.m_mSceneList[iSceneIdx] = iScene
        self.m_mGroup2Scene[mGroup.id] = iScene

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
        oScene:AddTimeCb("PrepareRoomRewardExp", 2*60*1000, function()
            PrepareRoomRewardExp(iScene)
        end)

        for iNpcIdx = 1001, 1004 do
            local oNpc = self:CreateTempNpc(iNpcIdx)
            self:Npc_Enter_Scene(oNpc, iScene)
        end
    end
end

function CHuodong:OnEnterPrepareRoom(mData)
    local oPlayer, oScene = mData.player, mData.scene

    local iOldGroup = oPlayer.m_oThisTemp:Query("match_group")
    if iOldGroup ~= oScene.m_iGroup then
        if iOldGroup then
            self:PlayerStopMatch(oPlayer)
        end

        local iKeepTime = self:GetKeepTime()
        oPlayer.m_oThisTemp:Set("match_group", oScene.m_iGroup, iKeepTime)
        
        if iOldGroup or (self:ValidShow(oPlayer) and not self:InHuodongTime()) then
            self:UpdateMatchInfo(oPlayer)
        end
    end

    if not self.m_mJoinPlayer then
        self.m_mJoinPlayer = {}
    end
    self.m_mJoinPlayer[oPlayer:GetPid()] = 1
    oPlayer:SetLogoutJudgeTime(-1)
    handleteam.PlayerCancelAutoMatch(oPlayer, true)
    self:RefreshSingleWarInfo(oPlayer)

    oPlayer.m_oPartnerCtrl.ValidAdjustPartner = function(oPartnerCtrl, oPlayer, lPartner)
        return self:ValidAdjustPartner(oPlayer, lPartner)
    end
end

function CHuodong:OnLeavePrepareRoom(mData)
    local oPlayer, oScene, iNewScene = mData.player, mData.scene, mData.new_scene
    if not iNewScene or oScene:GetSceneId() ~= iNewScene then
        oPlayer:SetLogoutJudgeTime()
        self:PlayerStopMatch(oPlayer)

        oPlayer.m_oPartnerCtrl.ValidAdjustPartner = nil

        local lReward = self:CheckUnGetReward(oPlayer)
        if #lReward > 0 then
            self:TrySendMailReward(oPlayer, lReward, 2074)
        end
    end
end

function CHuodong:ValidEnterTeam(oPlayer, oLeader, iOP)
    self:Notify(oPlayer:GetPid(), 1011)
    return false
end

function CHuodong:PackFinalInfo(oPlayer)
    local iPid = oPlayer:GetPid()
    local iGroup = self:GetGroupId(oPlayer)
    local iRank
    if self.m_mGroupRank[iPid] then
        iRank, iGroup = table.unpack(self.m_mGroupRank[iPid])
    end
    local mNet = {
        group_id = iGroup,
        my_rank = iRank,
        point = oPlayer.m_oThisTemp:Query("singlewar_point", 0),
        rank_list = self.m_lRankInfo,
    }
    return mNet
end


function PrepareRoomRewardExp(iScene)
    local oScene = global.oSceneMgr:GetScene(iScene)
    if not oScene then return end

    local oHuodong = global.oHuodongMgr:GetHuodong("singlewar")
    if not oHuodong then return end

    local iCurrTime = get_time()
    if iCurrTime < oHuodong.m_iPrepareTime or iCurrTime > oHuodong.m_iEndTime then
        return
    end

    oScene:DelTimeCb("PrepareRoomRewardExp")
    oScene:AddTimeCb("PrepareRoomRewardExp", 2*60*1000, function()
        PrepareRoomRewardExp(iScene)
    end)

    for iPid, _ in pairs(oScene.m_mPlayers) do
        oHuodong:Reward(iPid, "1001")
    end
end

