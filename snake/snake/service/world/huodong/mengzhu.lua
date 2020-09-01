local global = require "global"
local res = require "base.res"
local interactive = require "base.interactive"
local record = require "public.record"
local gamedefines = import(lualib_path("public.gamedefines"))
local huodongbase = import(service_path("huodong.huodongbase"))
local analy = import(lualib_path("public.dataanaly"))

function NewHuodong(sHuodongName)
    return CHuodong:New(sHuodongName)
end

CHuodong = {}
CHuodong.__index = CHuodong
CHuodong.m_sTempName = "帮派秘境"
--CHuodong.m_sTempName = "武林盟主"
inherit(CHuodong, huodongbase.CHuodong)

function CHuodong:New(sHuodongName)
    local o = super(CHuodong).New(self, sHuodongName)
    o.m_iScheduleID = 1019
    o.m_iStartTime = 0
    o.m_iEndTime = 0
    o.m_lEvent = {}
    o.m_mOrgPoint ={}
    o.m_mPlayerPoint = {}
    o.m_mOrgStat = {}
    o.m_sBossKey = self.m_sName.."boss"
    o.m_sPlunderKey = self.m_sName.."plunder"
    o.m_iTestInGame = 0
    o.m_iRankLimit = 1000
    o.m_mRecordReward = {}
    return o
end

function CHuodong:NeedSave()
    return true
end

function CHuodong:Save()
    local mData = {}
    mData.event_list = self.m_lEvent
    
    mData.org_point = {}
    for iOrg, iPoint in pairs(self.m_mOrgPoint) do
        mData.org_point[tostring(iOrg)] = iPoint
    end
    
    mData.player_point = {}
    for iPid, iPoint in pairs(self.m_mPlayerPoint) do
        mData.player_point[tostring(iPid)] = iPoint
    end
    
    mData.org_stat = {}
    for iOrg, mInfo in pairs(self.m_mOrgStat) do
        local mRet = {}
        for iPid, val in pairs(mInfo) do
            mRet[tostring(iPid)] = val
        end
        mData.org_stat[tostring(iOrg)] = mRet
    end

    return mData
end

function CHuodong:Load(mData)
    if not mData then return end

    self.m_lEvent = mData.event_list or {}
    self.m_mOrgPoint = table_to_int_key(mData.org_point or {})
    self.m_mPlayerPoint = table_to_int_key(mData.player_point or {})
    for sOrg, mInfo in pairs(mData.org_stat or {}) do
        self.m_mOrgStat[tonumber(sOrg)] = table_to_int_key(mInfo)
    end
end

function CHuodong:MergeFrom(mFrom)
    --游戏持续15分钟，结束后情况数据，不需要合服
    return true
end

function CHuodong:Init()
    self:DelTimeCb("NotifyGameStart")
    self:DelTimeCb("GameStart")
    self:DelTimeCb("GameOver")
    self.m_iTestInGame = 0

    self:InitGameStartTime()
    self:CheckAddTimer()
    if self:IsOpenDay() then
        self:SetHuodongState(gamedefines.ACTIVITY_STATE.STATE_READY)
    end
end

function CHuodong:NewDay(mNow)
    if self.m_iTestInGame == 0 then
        self:InitGameStartTime(mNow)
        self:CheckAddTimer(mNow)
    end
end

function CHuodong:InitGameStartTime(mNow)
    local mConfig = self:GetConfig()
    local lStartTime = split_string(mConfig.start_time, "|", function(sTime)
        return self:AnalyseTime(sTime)
    end)

    local iTime = mNow and mNow.time or get_time()
    for _, iSetTime in ipairs(lStartTime) do
        if iTime < iSetTime then
            self.m_iStartTime = iSetTime
            self.m_iEndTime = iSetTime + mConfig.continue_time*60
            return
        end
    end
    self.m_iStartTime = 0
    self.m_iEndTime = 0
end

function CHuodong:CheckAddTimer(mNow)
    local iTime = mNow and mNow.time or get_time()
    local mConfig = self:GetConfig()
    local iDelta = self.m_iStartTime - iTime
    if iDelta > 0 and iDelta <= 3600 then
        local iPrepare = self.m_iStartTime + mConfig.tip_time_shift*60
        iPrepare = math.max(iPrepare, iTime)
        if (iPrepare - iTime) < 1 then
            self:NotifyGameStartStep()
        else
            self:DelTimeCb("NotifyGameStart")
            self:AddTimeCb("NotifyGameStart", (iPrepare-iTime)*1000, function()
                self:NotifyGameStartStep()
            end)
        end
    end
end

function CHuodong:NewHour(mNow)
    self:CheckAddTimer(mNow)
end

function CHuodong:NotifyGameStartStep(oPlayer)
    --if is_production_env() then return end
    record.info("prepare game start mengzhu")

    self:DelTimeCb("GameStart")
    local iDelay = math.max(1, self.m_iStartTime-get_time())
    self:AddTimeCb("GameStart", iDelay*1000, function()
        self:GameStart()
    end)

    local mNet = {ret_time = self.m_iStartTime - get_time()}
    global.oNotifyMgr:WorldBroadcast("GS2CMengzhuGameStart", mNet)

    self:SetHuodongState(gamedefines.ACTIVITY_STATE.STATE_READY)
    interactive.Send(".rank", "rank", "ClearMengzhuRank", {})
end

function CHuodong:GameStart()
    record.info("game true start mengzhu")
    self:DelTimeCb("GameOver")
    self:AddTimeCb("GameOver", (self.m_iEndTime-self.m_iStartTime)*1000, function()
        self:GameOver()
    end)
    self:SetHuodongState(gamedefines.ACTIVITY_STATE.STATE_START)
    self:TryStartRewardMonitor()
end

function CHuodong:GameOver()
    record.info("game over mengzhu")
    self:SetHuodongState(gamedefines.ACTIVITY_STATE.STATE_END)
    safe_call(self.GameOverReward, self)

    self:Init()
    self.m_lEvent = {}
    self.m_mPlayerPoint = {}
    self.m_mOrgPoint ={}
    self:TryStopRewardMonitor()
    self:Dirty()
end

function CHuodong:RecordRewardByPid(iPid, iReward, sType, iRank)
    if not self.m_mRecordReward[iPid] then
        self.m_mRecordReward[iPid] = {}
    end
    self.m_mRecordReward[iPid][sType] = {iReward, iRank}
end

function CHuodong:LogAnlayInfo(oPlayer)
    if not oPlayer then return end

    if self.m_mPlayerPoint[oPlayer:GetPid()] then return end

    local mAnalyLog = oPlayer:BaseAnalyInfo()
    mAnalyLog["turn_times"] = 0
    mAnalyLog["operation"] = 1
    mAnalyLog["activity_type"] = "org_mj"
    analy.log_data("TimelimitActivity", mAnalyLog)
end

function CHuodong:GameOverReward()
    self:GameOverReward1()

    interactive.Request(".rank", "rank", "MengzhuGetRankList", {},
    function(mRecord, mData)
        safe_call(self.GameOverReward2, self, mData)
        self.m_mOrgStat = {}
    end)
end

function CHuodong:GameOverReward1()
    local lOrgList = global.oOrgMgr:GetNormalOrgs()
    for iOrg, oOrg in pairs(lOrgList) do
        local iCnt = self:GetOrgCount(iOrg)
        if iCnt <= 0 then goto continue end

        local iReward = self:GetRewardIdxByRank("org_count_reward", iCnt)
        if iReward then
            self:RewardOrgReward(iOrg, iReward, "org_count_reward")
        end

        local iOrgCash = iCnt * 100
        oOrg.m_oBaseMgr:AddCash(iOrgCash)
        local sMsg = self:GetTextData(1018)
        local mReplace = {total=iCnt, cash=iOrgCash}
        sMsg = global.oToolMgr:FormatColorString(sMsg, mReplace)
        global.oNotifyMgr:SendOrgChat(sMsg, iOrg, {pid=0})
        ::continue::
    end
end

function CHuodong:GameOverReward2(mData)
    self:SysAnnounce(1059)

    local lOrgRank = mData.mengzhuorg
    for idx, sOrg in pairs(lOrgRank) do
        local iRank = self.m_iTestOrgRank or idx
        local iOrg = tonumber(sOrg)
        local oOrg = global.oOrgMgr:GetNormalOrg(iOrg)
        if oOrg then
            local iReward = self:GetRewardIdxByRank("org_rank_reward", iRank)
            if iReward then
                self:RewardOrgReward(iOrg, iReward, "org_rank_reward", iRank)
            end
            if iRank ==1 then
                global.oRedPacketMgr:AddRPBuff(oOrg:GetLeaderID(),2005)
            elseif iRank == 2 then
                global.oRedPacketMgr:AddRPBuff(oOrg:GetLeaderID(),2006)
            elseif iRank == 3 then
                global.oRedPacketMgr:AddRPBuff(oOrg:GetLeaderID(),2007)
            end
            local sPrestige = self:GetOrgPrestigeByRank(iRank)
            local iPrestige = formula_string(sPrestige, {})
            self:RewardOrgPrestige(iOrg, iPrestige)
        end
        if idx >= self.m_iRankLimit then break end
    end
    local lPlayerRank = mData.mengzhuplayer
    for idx, sPid in pairs(lPlayerRank) do
        local iRank = self.m_iTestPlayerRank or idx
        local iPid = tonumber(sPid)
        local iReward = self:GetRewardIdxByRank("player_rank_reward", iRank)
        if iReward then
            self:RecordRewardByPid(iPid, iReward, "player_rank_reward", iRank)
        end
        if idx >= self.m_iRankLimit then break end
    end

    local mInfo = {
        pid_list = table_to_int_key(lPlayerRank or {}),
        reason = "player_rank_reward",
    }
    record.log_db("huodong", "mengzhu", {pid=0, info=mInfo})

    local mRecordReward = self.m_mRecordReward
    self.m_mRecordReward = {}

    self:TrySendMailReward(mRecordReward)
end

function CHuodong:TrySendMailReward(mRecordReward)
    local lPidList = table_key_list(mRecordReward)
    local func = function(iPid)
        local mRewardInfo = mRecordReward[iPid]
        self:TrySendMailRewardUnit(iPid, mRewardInfo)
    end
    global.oToolMgr:ExecuteList(lPidList, 100, 500, 0, "MengzhuMail", func)
end
   
function CHuodong:TrySendMailRewardUnit(iPid, mRewardInfo)
    if not mRewardInfo then return end

    local iExtReward = self:GetRewardIdxByRank("player_rank_reward", 9999)
    local sRankLimit = string.format("在%s名之外", self.m_iRankLimit)
    local lRewardOrder = {"org_rank_reward", "player_rank_reward", "org_count_reward"}
    local lRankList, lRewardList = {}, {}

    for _, sType in ipairs(lRewardOrder) do
        local mReward = mRewardInfo[sType]
        if sType == "org_rank_reward" then
            if not mReward then
                table.insert(lRankList, sRankLimit)
            else
                table.insert(lRewardList, mReward[1])
                table.insert(lRankList, mReward[2])
            end
        elseif sType == "player_rank_reward" then
            mReward = mReward or {iExtReward, sRankLimit}
            if type(mReward[2]) == "number" and mReward[2] > self.m_iRankLimit then
                mReward[2] = sRankLimit
            end
            table.insert(lRewardList, mReward[1])
            table.insert(lRankList, mReward[2])
        else
            if mReward then
                table.insert(lRewardList, mReward[1])
            end
        end
    end
    safe_call(self.DoSendMailReward, self, iPid, lRankList, lRewardList)
end

function CHuodong:DoSendMailReward(iPid, lRankList, lRewardList)
    local oPlayer = global.oWorldMgr:GetOnlinePlayerByPid(iPid)
    if not oPlayer then return end

    local mContent = {}
    for _, iReward in ipairs(lRewardList) do
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

    local mData, sName = global.oMailMgr:GetMailInfo(2023)
    if not mData then return end
    local mReplace = {rank_idx = lRankList}
    mData.context = global.oToolMgr:FormatColorString(mData.context, mReplace)
    global.oMailMgr:SendMailNew(0, sName, iPid, mData, mContent)
end

function CHuodong:RewardOrgReward(iOrg, iReward, sReason, iRank)
    for iPid, _ in pairs(self.m_mOrgStat[iOrg] or {}) do
        self:RecordRewardByPid(iPid, iReward, sReason, iRank)
    end

    if self.m_mOrgStat[iOrg] then
        local mInfo = {
            reward_idx = iReward,
            pid_list = table_key_list(self.m_mOrgStat[iOrg]),
            org_id = iOrg,
            reason = sReason,
        }
        record.log_db("huodong", "mengzhu", {pid=0, info=mInfo})
    end
end

function CHuodong:OnLogin(oPlayer, bReEnter)
    if self:InPreStartTime() then
        if not oPlayer.m_oActiveCtrl:GetNowWar() then
            local iRetTime = self.m_iStartTime - get_time()
            oPlayer:Send("GS2CMengzhuGameStart", {ret_time=iRetTime})
        end
    end
end

function CHuodong:InPreStartTime()
    local mConfig = self:GetConfig()
    local iPreStartTime = self.m_iStartTime + mConfig.tip_time_shift*60
    local iTime = get_time()
    return iTime > iPreStartTime and iTime < self.m_iStartTime
end

function CHuodong:InHuodongTime()
    local iTime = get_time()
    return iTime >= self.m_iStartTime and iTime <= self.m_iEndTime
end

function CHuodong:IsOpenDay(iTime)
    return get_dayno(self.m_iStartTime) == get_dayno(iTime)
end

function CHuodong:GetStartTime()
    return get_time_format_str(self.m_iStartTime, "%H:%M")
end

function CHuodong:ValidJoin(oPlayer)
    local mConfig = self:GetConfig()
    if oPlayer:GetGrade() < mConfig.grade then
        return 1005
    end
    if oPlayer:HasTeam() and not oPlayer:IsTeamShortLeave() then
        return 1001
    end
    if oPlayer.m_oActiveCtrl:GetNowWar() then
        return 1002
    end
    if oPlayer:GetOrgID() <= 0  then
        return 1004
    end
    if oPlayer:IsInFuBen() then
        return 1003
    end
    if not self:InHuodongTime() then
        return 1007
    end
    local oNowScene = oPlayer.m_oActiveCtrl:GetNowScene()
    if not oNowScene or (oNowScene:MapId() ~= 501000 and oNowScene:MapId() ~= 101000) then
        return 1019
    end
    return 1
end

function CHuodong:ValidFightBoss(oPlayer)
    local iRet = self:ValidJoin(oPlayer)
    if iRet ~= 1 then
        return iRet
    end
    if oPlayer.m_oThisTemp:Query(self.m_sBossKey, 0) > get_time() then
        return 1006
    end
    return 1
end

function CHuodong:OpenMengzhuMainUI(oPlayer)
    local oNowScene = oPlayer.m_oActiveCtrl:GetNowScene()
    if not oNowScene or (oNowScene:MapId() ~= 501000 and oNowScene:MapId() ~= 101000) then
        local mNet = {
            sContent = self:GetTextData(1020),
            sConfirm = "是",
            sCancle = "否",
        }
        mNet = global.oCbMgr:PackConfirmData(nil, mNet)
        local func = function(oPlayer, mData)
            self:TransScene(oPlayer, mData)
        end
        global.oCbMgr:SetCallBack(oPlayer:GetPid(), "GS2CConfirmUI", mNet, nil, func)
        return
    end

    local iRet = self:ValidJoin(oPlayer)
    local iState = iRet
    local iTime = get_time()
    if iRet==1007 and iTime >= self.m_iStartTime-60 and iTime < self.m_iEndTime then
        iState = 1
    end
    oPlayer:Send("GS2CMengzhuMainUI", {state=iState})
end

function CHuodong:TransScene(oPlayer, mData)
    local iAnswer = mData["answer"]
    if iAnswer ~= 1 then return end

    local iPid = oPlayer:GetPid()
    local iStatus = oPlayer.m_oActiveCtrl:GetWarStatus()
    if iStatus ~= gamedefines.WAR_STATUS.NO_WAR then
        self:Notify(oPlayer:GetPid(), 1021)
        self:OpenHDSchedule(iPid)
        return
    end
    if not oPlayer:IsSingle() and not oPlayer:IsTeamLeader() then
        self:Notify(oPlayer:GetPid(), 1022)
        self:OpenHDSchedule(iPid)
        return
    end
    if oPlayer:IsFixed() then
        self:OpenHDSchedule(iPid)
        return
    end

    local iX, iY = global.oSceneMgr:RandomPos2(101000)
    if not global.oSceneMgr:ChangeMap(oPlayer, 101000, {x=iX, y=iY}) then
        self:OpenHDSchedule(iPid)
    end
    self:OpenMengzhuMainUI(oPlayer)
end

function CHuodong:FightBoss(oPlayer)
    local iRet = self:ValidFightBoss(oPlayer)
    if iRet ~= 1 then
        self:Notify(oPlayer:GetPid(), iRet)
        return
    end
    self:DoScript2(oPlayer:GetPid(), nil, "F1001")
end

function CHuodong:CreateWar(iPid, oNpc, iFight)
    local oWar = super(CHuodong).CreateWar(self, iPid, oNpc, iFight)
    oWar.m_iStep = self:GetHuodongStep()
    return oWar
end

function CHuodong:InitWarInfo(mData)
    local mWarInfo = super(CHuodong).InitWarInfo(self, mData)
    mWarInfo.bout_out = {bout=10, result=2}
    return mWarInfo
end
    
function CHuodong:OnMonsterCreate(oWar, oMonster, mData, oNpc)
    if oMonster:Type() == 10001 and self:InHuodongTime() then
        local mConfig = self:GetConfig()
        local iRatio = (self.m_iEndTime-get_time())/(self.m_iEndTime-self.m_iStartTime)
        oMonster.m_iMaxHp = math.floor(oMonster.m_iHp / iRatio)
    end
end

function CHuodong:WarFightEnd(oWar, iPid, npcobj, mArgs)
    super(CHuodong).WarFightEnd(self, oWar, iPid, npcobj, mArgs)

    if oWar.m_iIdx == 1001 then
        if not self:InHuodongTime() then return end

        local oWorldMgr = global.oWorldMgr
        local oPlayer = oWorldMgr:GetOnlinePlayerByPid(iPid)
        oPlayer.m_oScheduleCtrl:Add(self.m_iScheduleID)
        oPlayer:MarkGrow(16)
        local iNextTime = get_time() + 180
        oPlayer.m_oThisTemp:Set(self.m_sBossKey, iNextTime, 180)
        safe_call(self.LogAnlayInfo, self, oPlayer)

        local iAdd = self:CalculateBossScore(oPlayer, mArgs, oWar.m_iStep)
        if iAdd > 0 then
            self:TryAddMengzhuPoint(iPid, iAdd)
            local mReplace = {name=oPlayer:GetName(), point=iAdd}
            self:AddEvent(1010, mReplace)
        end

        local mNet = {
            point = iAdd,
            bout = table_get_depth(mArgs, {"bout_cnt"}) or 0,
            damage = table_get_depth(mArgs, {"damage_info", "npc_damaged_info", 10001}) or 0,
        }
        oPlayer:Send("GS2CMengzhuBossResult", mNet)
    end
end

function CHuodong:OnWarFail(oWar, pid, npcobj, mArgs)
    if oWar.m_iIdx == 1001 then
        mArgs.silent = true
    end
    super(CHuodong).OnWarFail(self, oWar, pid, npcobj, mArgs)
end

function CHuodong:ValidStartPlunder(oPlayer, iTarget)
    local iPid = oPlayer:GetPid()
    local oWorldMgr = global.oWorldMgr

    local oWanfaCtrl = oWorldMgr:GetWanfaCtrl(iPid)
    assert(oWanfaCtrl, "wanfactrl been unload")

    local iRet = self:ValidJoin(oPlayer)
    if iRet ~= 1 then
        self:Notify(iPid, iRet)
        return
    end
    if oPlayer.m_oThisTemp:Query(self.m_sPlunderKey, 0) > get_time() then
        self:Notify(iPid, 1006)
        return
    end

    local lPartner = oPlayer.m_oPartnerCtrl:GetCurrLineupPos() or {}
    if #lPartner < 2 then
        self:Notify(iPid, 1024)
        return
    end

    oWorldMgr:LoadWanfaCtrl(iTarget, function(oWanfaCtrl)
        local oPlayer = oWorldMgr:GetOnlinePlayerByPid(iPid)
        self:ValidStartPlunder1(oPlayer, oWanfaCtrl)
    end)
end

function CHuodong:ValidStartPlunder1(oPlayer, oTargetWanfaCtrl)
    if oTargetWanfaCtrl:InMengzhuWar() then
        self:Notify(oPlayer:GetPid(), 1009)
        return
    end
    if oTargetWanfaCtrl:InMengzhuProtectTime() then
        self:Notify(oPlayer:GetPid(), 1008)
        local mNet = {
            target = oTargetWanfaCtrl:GetPid(),
            timeout = oTargetWanfaCtrl:GetMengzhuProtectTime(),
        }
        oPlayer:Send("GS2CMengzhuPlunderNotify", mNet)
        return
    end

    self:StartPlunder(oPlayer, oTargetWanfaCtrl)
end

function CHuodong:StartPlunder(oPlayer, oTargetWanfaCtrl)
    local oWorldMgr = global.oWorldMgr
    local iTarget = oTargetWanfaCtrl:GetPid()
    local oTarget = oWorldMgr:GetOnlinePlayerByPid(iTarget)
    if oTarget then
        oTargetWanfaCtrl:SyncData(oTarget)
    end
    self:StartPlunder2(oPlayer, oTargetWanfaCtrl)
end

function CHuodong:StartPlunder2(oPlayer, oTargetWanfaCtrl)
    local oWarMgr = global.oWarMgr
    local oWarData = oTargetWanfaCtrl:GetWarData()
    local oWar = oWarMgr:CreateWar(
        gamedefines.WAR_TYPE.PVP_TYPE,
        gamedefines.GAME_SYS_TYPE.SYS_TYPE_MENGZHU,
        {
            auto_start = gamedefines.WAR_AUTO_TYPE.FORBID_AUTO,
        }
    )
    local iWarId = oWar:GetWarId()
    oWarMgr:EnterWar(oPlayer, iWarId, {camp_id=gamedefines.WAR_WARRIOR_SIDE.FRIEND}, true, 2)
    oWar:PrepareCamp(gamedefines.WAR_WARRIOR_SIDE.ENEMY, {fmt_id=1, grade=1})
    oWar:EnterRoPlayer(oWarData, {camp_id=gamedefines.WAR_WARRIOR_SIDE.ENEMY})
    oWar:EnterRoPartnerList(oWarData, {camp_id=gamedefines.WAR_WARRIOR_SIDE.ENEMY}, 2)

    local iTarget = oWarData:GetPid()
    local iPid = oPlayer:GetPid()
    oWarMgr:SetCallback(iWarId, function(mArgs)
        self:PlunderEnd(iPid, iTarget, mArgs)
    end)

    oTargetWanfaCtrl:SetMengzhuWar(iWarId)
    --local oWanfaCtrl = global.oWorldMgr:GetWanfaCtrl(iPid)
    --oWanfaCtrl:SetMengzhuWar(iWarId)
    oWarMgr:StartWar(iWarId)
end

function CHuodong:PlunderEnd(iPid, iTarget, mArgs)
    if not self:InHuodongTime() then return end

    local oWorldMgr = global.oWorldMgr
    oWorldMgr:LoadWanfaCtrl(iPid, function(oWanfaCtrl)
        if not oWanfaCtrl then return end

        oWorldMgr:LoadWanfaCtrl(iTarget, function(oTargetWanfaCtrl)
            if not oTargetWanfaCtrl then return end
            
            self:PlunderEnd1(iPid, iTarget, mArgs)
        end)
    end)
end

function CHuodong:PlunderEnd1(iPid, iTarget, mArgs)
    local oWorldMgr = global.oWorldMgr
    local oPlayer = oWorldMgr:GetOnlinePlayerByPid(iPid)
    local oWanfaCtrl = oWorldMgr:GetWanfaCtrl(iPid)
    local oTargetWanfaCtrl = oWorldMgr:GetWanfaCtrl(iTarget)
    assert(oPlayer and oWanfaCtrl and oTargetWanfaCtrl)

    local iNextTime = get_time() + 180
    oPlayer.m_oThisTemp:Reset(self.m_sPlunderKey, iNextTime, 180)
    oPlayer.m_oScheduleCtrl:Add(self.m_iScheduleID)
    safe_call(self.LogAnlayInfo, self, oPlayer)

    oWanfaCtrl:SetMengzhuWar(nil)
    oTargetWanfaCtrl:SetMengzhuWar(nil)
    if mArgs.win_side == gamedefines.WAR_WARRIOR_SIDE.FRIEND then
        oTargetWanfaCtrl:SetMengzhuProtectTime(60)
    end

    local iAdd = self:CalculatePlunderScore(oWanfaCtrl, oTargetWanfaCtrl, mArgs)
    if iAdd then
        local sTarget = oTargetWanfaCtrl.m_oWarDataCtrl.m_oRoFight:GetName()
        local mReplace = {name={oPlayer:GetName(), sTarget}, point=iAdd}
        self:AddEvent(1011, mReplace)
    end
    self:SendWarResult(oPlayer, oTargetWanfaCtrl, mArgs, iAdd)
end

function CHuodong:SendWarResult(oPlayer, oTarget, mArgs, iAdd)
    if not oPlayer then return end
  
    local iSide = 2 
    local oRoFight = oTarget.m_oWarDataCtrl.m_oRoFight 
    local mNet = {}
    mNet.win_side = (iAdd and iAdd > 0) and 1 or 0 -- mArgs.win_side
    mNet.name = oRoFight:GetName()
    mNet.score = oRoFight:GetScore()
    mNet.grade = oRoFight:GetGrade()
    mNet.school = oRoFight:GetSchool()
    mNet.point = iAdd
    mNet.partner = {}
    if #mArgs.roplayer[iSide] > 0 then
        mNet.player = {sid=oRoFight:GetIcon(), die=0}
    else
        mNet.player = {sid=oRoFight:GetIcon(), die=1}
    end
    for sKey, mInfo in pairs(mArgs.ropartner[iSide][oTarget:GetPid()] or {}) do
        for _, sid in ipairs(mInfo) do
            table.insert(mNet.partner, {sid=sid, die=("die"==sKey) and 1 or 0})
        end
    end
    oPlayer:Send("GS2CMengzhuPlunderResult", mNet)
end

function CHuodong:CalculateBossScore(oPlayer, mArgs, iStep)
    local iFactor = self:GetRewardFactor(iStep)
    if iFactor and iFactor <= 0 then return 0 end

    local mDamageInfo = mArgs.damage_info or {}
    local mDamageDetail = mDamageInfo.npc_damaged_info
    local iTotal = 0
    for iType, iDamage in pairs(mDamageDetail) do
        if iType == 10001 then
            iTotal = iTotal + iDamage
        end
    end
    local mConfig = self:GetConfig()
    local sMax = mConfig.step_config[iStep].max_point
    local iMax = formula_string(sMax, {lv=oPlayer:GetGrade()})
    return math.min(math.ceil(iTotal*0.01*iFactor), math.floor(iMax))
end

function CHuodong:CalculatePlunderScore(oWanfaCtrl, oTargetWanfaCtrl, mArgs)
    local iEnemy = 2
    --local mData = {}
    local iRatio = 0
    local mAllPartner = mArgs.ropartner or {}
    local mDiePartner = mAllPartner[iEnemy] or {}
    for iOwner, mInfo in pairs(mDiePartner) do
        for _, iPartner in pairs(mInfo.die or {}) do
            --table.insert(mData, 8)
            iRatio = iRatio + 8
        end
    end

    local mDieInfo = mArgs.rodie or {}
    for _, iDie in ipairs(mDieInfo[iEnemy] or {}) do
        --table.insert(mData, 14)
        iRatio = iRatio + 14
    end

    --if #mData <= 0 then return end
    if iRatio <= 0 then return end

    local iPoint = self:GetPlayerPoint(oTargetWanfaCtrl:GetPid()) 
    local iAdd = math.ceil(iPoint*iRatio/100)
--    for _, iRatio in ipairs(mData) do
--        iAdd = iAdd + math.ceil(iPoint*iRatio/100)
--    end

    iAdd = math.max(1, iAdd)
    self:TryAddMengzhuPoint(oWanfaCtrl:GetPid(), iAdd)
    self:TryAddMengzhuPoint(oTargetWanfaCtrl:GetPid(), -iAdd)
    return iAdd
end

function CHuodong:TryAddMengzhuPoint(iPid, iAdd)
    local oWorldMgr = global.oWorldMgr
    local oPlayer = oWorldMgr:GetOnlinePlayerByPid(iPid)
    if oPlayer then
        self:TryAddMengzhuPoint1(oPlayer, iAdd)
    else
        oWorldMgr:LoadProfile(iPid, function(oProfile)
            self:TryAddMengzhuPoint1(oProfile, iAdd)
        end)
    end
end

function CHuodong:TryAddMengzhuPoint1(oProfile, iAdd)
    local iPid = oProfile:GetPid()
    self:AddPlayerPoint(iPid, iAdd)
    global.oRankMgr:PushDataToMengzhuPlayer(oProfile)

    local oOrg = oProfile:GetOrg()
    if not oOrg then return end

    if iAdd > 0 then
        self:AddOrgStat(oOrg:OrgID(), iPid, 1)
    end
    self:TransScoreToOrg(oOrg, iPid, iAdd)
end

function CHuodong:TransScoreToOrg(oOrg, iPid, iTotal)
    if not oOrg then return end

    local iAdd = 0
    if iTotal > 0 then
        iAdd = math.ceil(iTotal * 10 /100)
    else
        iAdd = math.floor(iTotal * 10 /100)
    end
    if iAdd == 0 then return end

    self:AddOrgPoint(oOrg:OrgID(), iAdd)

    global.oRankMgr:PushDataToMengzhuOrg(oOrg)
end

function CHuodong:GetHuodongStep()
    local mConfig = self:GetConfig()
    local iTime = get_time()
    local iStartTime = self.m_iStartTime
    for idx, mInfo in pairs(mConfig.step_config) do
        if iTime > iStartTime and iTime <= iStartTime + mInfo.time*60 then
            return mInfo.step
        end
        iStartTime = iStartTime + mInfo.time*60
    end
end

function CHuodong:GetRewardFactor(iStep)
    iStep = iStep or self:GetHuodongStep()
    if not iStep then return 0 end

    local mConfig = self:GetConfig()
    return table_get_depth(mConfig, {"step_config", iStep, "ratio"})
end

function CHuodong:AddEvent(iEvent, mReplace)
    local sEvent = self:GetTextData(iEvent)
    sEvent = global.oToolMgr:FormatColorString(sEvent, mReplace)

    if #self.m_lEvent >= 5 then
        table.remove(self.m_lEvent, 1)
    end
    table.insert(self.m_lEvent, sEvent)
end

function CHuodong:RefreshEvent(oPlayer)
    local lEventList = {}
    for _, sEvent in ipairs(self.m_lEvent) do
        table.insert(lEventList, sEvent)
    end
    oPlayer:Send("GS2CMengzhuEventList", {event_list=lEventList})
end

function CHuodong:OpenPlayerRank(oPlayer)
    local oWorldMgr = global.oWorldMgr
    local iPid = oPlayer:GetPid()
    oWorldMgr:LoadWanfaCtrl(iPid, function(oWanfaCtrl)
        if oWanfaCtrl then
            self:OpenPlayerRank1(oWanfaCtrl)
        end
    end)
    self:RefreshEvent(oPlayer)
end

function CHuodong:OpenPlayerRank1(oWanfaCtrl)
    local iPid = oWanfaCtrl:GetPid()
    local oPlayer = global.oWorldMgr:GetOnlinePlayerByPid(iPid)
    if not oPlayer then return end

    local mArgs = {
        mengzhu_cd = oPlayer.m_oThisTemp:Query(self.m_sBossKey, 0),
        plunder_cd = oPlayer.m_oThisTemp:Query(self.m_sPlunderKey, 0),
        pid = iPid,
        point = self:GetPlayerPoint(iPid),
        game_start_time = self.m_iStartTime,
    }
    interactive.Send(".rank", "rank", "GS2CMengzhuOpenPlayerRank", mArgs)
end

function CHuodong:OpenOrgRank(oPlayer)
    local oOrg = oPlayer:GetOrg()
    if not oOrg then return end

    self:RefreshEvent(oPlayer)
    local mArgs = {
        org_id = oOrg:OrgID(),
        pid = oPlayer:GetPid(),
        point = self:GetOrgPoint(oOrg:OrgID()),
        total = self:GetOrgCount(oOrg:OrgID()),
        chairman = oOrg:GetLeaderName(),
        mengzhu_cd = oPlayer.m_oThisTemp:Query(self.m_sBossKey, 0),
        plunder_cd = oPlayer.m_oThisTemp:Query(self.m_sPlunderKey, 0)
    }
    interactive.Send(".rank", "rank", "GS2CMengzhuOpenOrgRank", mArgs)
end

function CHuodong:OpenPlunder(oPlayer)
    --TODO 师徒， 夫妻
    local oOrg = oPlayer:GetOrg()
    if not oOrg then return end

    local iPid = oPlayer:GetPid()
    local oFriend = oPlayer:GetFriend()
    local mFriends = oFriend:GetFriends()
    local mArgs = {
        friend_list = oFriend:GetFriends(),
        org_id = oOrg:OrgID(),
        pid = iPid,
    }
    interactive.Request(".rank", "rank", "MengzhuGetPlunderList", mArgs,
    function(mRecord, mData)
        self:OpenPlunder1(iPid, mData)
    end)
end

function CHuodong:OpenPlunder1(iOwner, mData)
    local oPlayer = global.oWorldMgr:GetOnlinePlayerByPid(iOwner)
    if not oPlayer then return end
    
    local lPidList = mData.player_list
    if #lPidList > 0 then
        local lObjList = {}
        for _, iPid in ipairs(lPidList) do
            local oTarget = global.oWorldMgr:GetOnlinePlayerByPid(iPid)
            if oTarget then
                local oWanfaCtrl = global.oWorldMgr:GetWanfaCtrl(iPid)
                table.insert(lObjList, {oTarget, oWanfaCtrl})
                if #lObjList >= #lPidList then
                    self:OpenPlunder2(iOwner, lObjList)
                end
            else
                self:LoadProfileAndWanfaCtrl(iPid, function(iPid)
                    local oProfile = global.oWorldMgr:GetProfile(iPid)
                    local oWanfaCtrl = global.oWorldMgr:GetWanfaCtrl(iPid)
                    table.insert(lObjList, {oProfile, oWanfaCtrl})
                    if #lObjList >= #lPidList then
                        self:OpenPlunder2(iOwner, lObjList)
                    end
                end)
            end
        end
    else
        oPlayer:Send("GS2CMengzhuOpenPlunder", {player_list={}})
    end
end

function CHuodong:OpenPlunder2(iPid, lObjList)
    local oPlayer = global.oWorldMgr:GetOnlinePlayerByPid(iPid)
    if not oPlayer then return end

    local lPlayerList = {}
    for _, lInfo in ipairs(lObjList) do
        local oProfile = lInfo[1]
        local oWanfaCtrl = lInfo[2]
        local mUnit = {}
        mUnit.protect_time = oWanfaCtrl:GetMengzhuProtectTime()
        mUnit.score = oProfile:GetScore()
        mUnit.role = oProfile:PackSimpleInfo()
        mUnit.tx_info = oProfile:PackTouxianInfo()
        mUnit.grade = oProfile:GetGrade()
        mUnit.org_name = oProfile:GetOrgName()
        table.insert(lPlayerList, mUnit)
    end
    oPlayer:Send("GS2CMengzhuOpenPlunder", {player_list=lPlayerList})
end

function CHuodong:LoadProfileAndWanfaCtrl(iPid, callback)
    local oWorldMgr = global.oWorldMgr
    oWorldMgr:LoadProfile(iPid, function(oProfile)
        if not oProfile then return end
        oWorldMgr:LoadWanfaCtrl(iPid, function(oWanfaCtrl)
            if not oWanfaCtrl then return end
            callback(iPid)
        end)
    end)
end

function CHuodong:OnAddOrg(oOrg, iPid)
--    if not self:InHuodongTime() then return end
--
--    local mStat = self:GetOrgStat(oOrg:OrgID())
--    if mStat[iPid] then return end
--    
--    local iTotal = self:GetPlayerPoint(iPid)
--    if iTotal <= 0 then return end
--
--    self:AddOrgStat(oOrg:OrgID(), iPid, 1)
--    self:TransScoreToOrg(oOrg, iPid, iTotal)
end

function CHuodong:OnLeaveOrg(oOrg, iPid)
    if not self:InHuodongTime() then return end

    local mStat = self:GetOrgStat(oOrg:OrgID())
    if not mStat[iPid] then return end
    
    self:AddOrgStat(oOrg:OrgID(), iPid, nil)
    local iTotal = self:GetPlayerPoint(iPid)
    self:TransScoreToOrg(oOrg, iPid, -iTotal)
end

function CHuodong:SetHuodongState(iState)
    local sTime = self:GetStartTime()
    global.oHuodongMgr:SetHuodongState(self.m_sName, self.m_iScheduleID, iState, sTime)
end

function CHuodong:GetRewardIdxByRank(sKey, iRank)
    local mRewardStep = res["daobiao"]["huodong"][self.m_sName][sKey]
    for idx, mInfo in ipairs(mRewardStep) do
        if iRank >= mInfo["range"]["start"] and iRank <= mInfo["range"]["end"] then
            return mInfo.reward_id
        end
    end
end

function CHuodong:GetOrgPrestigeByRank(iRank)
    local mRewardStep = res["daobiao"]["huodong"][self.m_sName]["org_rank_reward"]
    for idx, mInfo in ipairs(mRewardStep) do
        if iRank >= mInfo["range"]["start"] and iRank <= mInfo["range"]["end"] then
            return mInfo.org_prestige
        end
    end
    return "0"
end

function CHuodong:GetConfig()
    return res["daobiao"]["huodong"][self.m_sName]["condition"][1]
end

function CHuodong:AnalyseTime(sTime)
    local mCurrDate = os.date("*t", get_time())
    local year,month,day,hour,min= sTime:match('^(%d+)%-(%d+)%-(%d+) (%d+)%:(%d+)')
    return os.time({
        year = year == "0" and mCurrDate.year or tonumber(year),
        month = month == "0" and mCurrDate.month or tonumber(month),
        day = (day == "0") and mCurrDate.day or tonumber(day),
        hour = tonumber(hour),
        min = tonumber(min),
        sec = 0,
    })
end

function CHuodong:Notify(iPid, iChat, mReplace)
    local oNotifyMgr = global.oNotifyMgr
    local sMsg = self:GetTextData(iChat)
    if mReplace then
        sMsg = global.oToolMgr:FormatColorString(sMsg, mReplace)
    end
    oNotifyMgr:Notify(iPid, sMsg)
end

function CHuodong:AddPlayerPoint(iPid, iAdd)
    if not self.m_mPlayerPoint[iPid] then
        self.m_mPlayerPoint[iPid] = 0
    end
    self.m_mPlayerPoint[iPid] = math.max(0, self.m_mPlayerPoint[iPid] + iAdd)
    self:Dirty()
end

function CHuodong:GetPlayerPoint(iPid)
    return self.m_mPlayerPoint[iPid] or 0
end

function CHuodong:AddOrgPoint(iOrg, iAdd)
    if not self.m_mOrgPoint[iOrg] then
        self.m_mOrgPoint[iOrg] = 0
    end
    self.m_mOrgPoint[iOrg] = math.max(0, self.m_mOrgPoint[iOrg] + iAdd)
    self:Dirty()
end

function CHuodong:GetOrgPoint(iOrg)
    return self.m_mOrgPoint[iOrg] or 0
end

function CHuodong:AddOrgStat(iOrg, iPid, iVal)
    if not self.m_mOrgStat[iOrg] then
        self.m_mOrgStat[iOrg] = {}
    end
    self.m_mOrgStat[iOrg][iPid] = iVal
    self:Dirty()
end

function CHuodong:GetOrgCount(iOrg)
    if self.m_iTestOrgCount then
        return self.m_iTestOrgCount
    end
    return table_count(self.m_mOrgStat[iOrg] or {})
end

function CHuodong:GetOrgStat(iOrg)
    return self.m_mOrgStat[iOrg] or {}
end

function CHuodong:RewardOrgPrestige(iOrg, iPrestige)
    local oOrg = global.oOrgMgr:GetNormalOrg(iOrg)
    if not oOrg or iPrestige <= 0 then return end

    local sMsg = global.oOrgMgr:GetOrgText(1168, {amount=iPrestige})
    oOrg:AddPrestige(iPrestige, "帮派封魔", {chat_msg=sMsg})
end

function CHuodong:TestOp(iFlag, mArgs)
    local iPid = mArgs[#mArgs]
    local oMaster = global.oWorldMgr:GetOnlinePlayerByPid(iPid)
    if iFlag == 100 then
        global.oNotifyMgr:Notify(iPid, [[
        101 - 开始新一轮活动
        102 - 波旬战斗
        104 - 增加积分 huodongop mengzhu 104 {1000}
        109 - 本次活动结束
        111 - 设置当前活动所有帮派排名,0为清空 huodongop mengzhu 111 {2}
        112 - 设置当前活动所有玩家排名,0为清空 huodongop mengzhu 112 {2}
        113 - 设置当前活动所有帮派玩家参与数,0为清空 huodongop mengzhu 113 {100}
        ]])
    elseif iFlag == 101 then
        local mConfig = self:GetConfig()
        self.m_iStartTime = get_time() - mConfig.tip_time_shift*60
        self.m_iEndTime = self.m_iStartTime + mConfig.continue_time*60
        self.m_iTestInGame = 1
        self:NotifyGameStartStep()
    elseif iFlag == 102 then
        self:FightBoss(oMaster)
    elseif iFlag == 103 then
        local iTarget = mArgs[1]
        self:ValidStartPlunder(oMaster, iTarget)
    elseif iFlag == 104 then
        self:AddPlayerPoint(oMaster:GetPid(), mArgs[1])
        global.oRankMgr:PushDataToMengzhuPlayer(oMaster:GetProfile())
        self:TransScoreToOrg(oMaster:GetOrg(), iPid, mArgs[1])
        global.oNotifyMgr:Notify(iPid, "积分："..self:GetPlayerPoint(iPid))
    elseif iFlag == 105 then
        self:OpenOrgRank(oMaster)
    elseif iFlag == 106 then
        self:OpenPlayerRank(oMaster)
    elseif iFlag == 107 then
        self:OpenPlunder(oMaster)
    elseif iFlag == 108 then
        self:OpenMengzhuMainUI(oMaster)
    elseif iFlag == 109 then
        self:GameOver()
    elseif iFlag == 110 then
        self:DoScript(iPid, nil, {"R1001"}, {})
    elseif iFlag == 111 then
        if mArgs[1] <= 0 then
            self.m_iTestOrgRank = nil
        else
            self.m_iTestOrgRank = tonumber(mArgs[1])
        end
    elseif iFlag == 112 then
        if mArgs[1] <= 0 then
            self.m_iTestPlayerRank = nil
        else
            self.m_iTestPlayerRank = tonumber(mArgs[1])
        end
    elseif iFlag == 113 then
        if mArgs[1] <= 0 then
            self.m_iTestOrgCount = nil
        else
            self.m_iTestOrgCount = tonumber(mArgs[1])
        end
    end
end
