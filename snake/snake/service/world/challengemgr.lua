local global = require "global"
local extend = require "base.extend"
local res = require "base.res"
local interactive = require "base.interactive"
local net = require "base.net"
local record = require "public.record"

local gamedefines = import(lualib_path("public.gamedefines"))
local datactrl = import(lualib_path("public.datactrl"))
local robot = import(service_path("jjc.robot"))
local rewardmonitor = import(service_path("rewardmonitor"))
local analy = import(lualib_path("public.dataanaly"))


function NewChallengeMgr(...)
    return CChallengeMgr:New(...)
end

CChallengeMgr = {}
CChallengeMgr.__index = CChallengeMgr
inherit(CChallengeMgr, datactrl.CDataCtrl)

function CChallengeMgr:New()
    local o = super(CChallengeMgr).New(self)
    o.m_mChallengeRobots = {}
    o.m_oRewardMonitor = rewardmonitor.NewMonitor("challengemgr", {"jjc", "challenge_rewardlimit"})
    return o
end

function CChallengeMgr:Release()
    if self.m_oRewardMonitor then
        baseobj_safe_release(self.m_oRewardMonitor)
    end
    for pid, mChallenge in pairs(self.m_mChallengeRobots) do
        for _, oRobot in pairs(mChallenge) do
            baseobj_safe_release(oRobot)
        end
    end
    self.m_mChallengeRobots = {}
    super(CChallengeMgr).Release(self)
end

function CChallengeMgr:NewHour(mNow)
    local iHour = mNow.date.hour
    if iHour == 5 then
        if self.m_oRewardMonitor then
            self.m_oRewardMonitor:ClearRecordInfo()
        end
    end
end

function CChallengeMgr:ClearChallengeRobot(pid)
    if not self.m_mChallengeRobots[pid] then
        return
    end
    for _, oRobot in pairs(self.m_mChallengeRobots[pid]) do
        baseobj_delay_release(oRobot)
    end
    self.m_mChallengeRobots[pid] = nil
end


function CChallengeMgr:AddChallengeMatchInfo(iPid, iGrade, iScore)
    interactive.Send(".recommend", "challenge", "AddChallengeMatchInfo", {
        pid = iPid,
        grade = iGrade,
        score = iScore
    })
end

function CChallengeMgr:InitChallengeRobot(level, iScore, iGrade)
    local ratio = 1
    local mPowers = res["daobiao"]["jjc"]["challenge_power"]
    for _, data in pairs(mPowers) do
        if iScore >= data["power"][1] and iScore < data["power"][2] then
            ratio = data["level"..level]
        end
    end
    if iGrade <= 0 then
        iGrade = 1
    end
    local mRoleInfo = res["daobiao"]["roletype"]
    local lRoleType = {}
    for roletype, mInfo in ipairs(mRoleInfo) do
        if mInfo["roletype"] ~= 4 then
            table.insert(lRoleType, mInfo["roletype"])
        end
    end
    local iRoleType = extend.Random.random_choice(lRoleType)
    local iShape = mRoleInfo[iRoleType]["shape"]
    local iSchool = extend.Random.random_choice(mRoleInfo[iRoleType]["school"])

    local oJJCMgr = global.oJJCMgr
    local iPartnerGrade, lPartnerSid = oJJCMgr:InitPartnerInfo(iGrade, 0, iSchool)
    local iSummonGrade, iSummonSid = oJJCMgr:InitSummonInfo(iGrade, 0, iSchool)
    return {
        school = iSchool,
        grade = iGrade,
        name = "神秘人",
        shape = iShape,
        icon = iShape,
        partnergrade = iPartnerGrade,
        partners = lPartnerSid,
        summongrade = iSummonGrade,
        summonsid = iSummonSid,
        ratio = ratio,
        score = iScore,
    }
end

function CChallengeMgr:GetChallengeRobot(oPlayer, id)
    local pid = oPlayer:GetPid()
    local mPidRobots = self.m_mChallengeRobots[pid]
    if not mPidRobots then
        mPidRobots = {}
        self.m_mChallengeRobots[pid] = mPidRobots
    end
    local oRobot = mPidRobots[id]
    if not oRobot then
        local oRobot = robot.NewRobot(id, oPlayer:GetChallenge():GetRobotData(id))
        mPidRobots[id] = oRobot
    end
    return self.m_mChallengeRobots[pid][id]
end

function CChallengeMgr:RequestChallengeTarget(iGrade, iScore, mExclude, iGradeLimit, endfunc)
    interactive.Request(".recommend", "challenge", "GetChallengeTarget", {
        grade = iGrade,
        gradelimit = iGradeLimit,
        score = iScore,
        exclude = mExclude,
    }, function (mRecord, mData)
        if not is_release(self) then
            endfunc(mData.target)
        end
    end)
end

function CChallengeMgr:InitChallengeTarget(oPlayer, endfunc)
    local oWorldMgr = global.oWorldMgr
    local iPid = oPlayer:GetPid()
    local oChallenge = oPlayer:GetChallenge()
    local mExclude = oChallenge:GetExcludes()
    mExclude[iPid] = true
    oChallenge:ResetTarget()
    self:RequestChallengeTarget(oPlayer:GetGrade(), oPlayer:GetScore(), mExclude, oWorldMgr:GetServerGradeLimit(), function (mTargets)
        if not is_release(self) then
            self:_InitChallengeTarget2(iPid, mTargets, endfunc)
        end
    end)
end

function CChallengeMgr:_InitChallengeTarget2(iPid, mTargets, endfunc)
    local oWorldMgr = global.oWorldMgr
    local oChallenge = oWorldMgr:GetChallenge(iPid)
    if not oChallenge then
        return
    end

    local mRobotDatas = {}
    for level, infos in pairs(mTargets) do
        for _, v in ipairs(infos) do
            if v.type == gamedefines.JJC_TARGET_TYPE.ROBOT then
                mRobotDatas[v.id] = self:InitChallengeRobot(level, v.score, v.grade)
            end
        end
    end
    oChallenge:SetTargets(mTargets)
    oChallenge:SetRobots(mRobotDatas)
    self:ClearChallengeRobot(iPid)
    if endfunc then
        endfunc()
    end
end

function CChallengeMgr:PackChallengeTarget(iType, oTarget)
    local mData = {}
    mData.type = iType
    mData.id = oTarget:GetPid()
    mData.name = oTarget:GetName()
    mData.grade = oTarget:GetGrade()
    mData.score = oTarget:GetScore()
    mData.model = oTarget:GetModelInfo()
    mData.icon = oTarget:GetIcon()
    return mData
end

function CChallengeMgr:PackChallengeTargetInfos(oPlayer, iLevel, endfunc)
    local iPid = oPlayer:GetPid()
    local oChallenge = oPlayer:GetChallenge()
    local mTargets = oChallenge:GetTargets()

    local lTargetPids = {}
    if mTargets and mTargets[iLevel] then
        for _, info in ipairs(mTargets[iLevel]) do
            if info.type == gamedefines.JJC_TARGET_TYPE.PLAYER then
                table.insert(lTargetPids, info.id)
            end
        end
    end

    if next(lTargetPids) then
        local mHandle = {
            count = #lTargetPids,
            loadcnt = 0,
            loaded = false,
        }
        local oWorldMgr = global.oWorldMgr
        for _, pid in ipairs(lTargetPids) do
            oWorldMgr:LoadProfile(pid, function (oProfile)
                mHandle.loadcnt = mHandle.loadcnt + 1
                if mHandle.loadcnt >= mHandle.count then
                    mHandle.loaded = true
                    self:_PackChallengeTargetInfos2(iPid, mTargets, iLevel, endfunc)
                end
            end)
        end
    else
        self:_PackChallengeTargetInfos2(iPid, mTargets, iLevel, endfunc)
    end
end

function CChallengeMgr:_PackChallengeTargetInfos2(iPid, mTargets, iLevel, endfunc)
    local oWorldMgr = global.oWorldMgr
    local oPlayer = oWorldMgr:GetOnlinePlayerByPid(iPid)
    if not oPlayer then
        return
    end
    local mData = {}
    if mTargets and mTargets[iLevel] then
        local lTargetDatas = {}
        for _, info in ipairs(mTargets[iLevel]) do
            if info.type == gamedefines.JJC_TARGET_TYPE.PLAYER then
                local oProfile = oWorldMgr:GetProfile(info.id)
                if oProfile then
                    local mPlayerData = self:PackChallengeTarget(info.type, oProfile)
                    mPlayerData.score = info.score
                    table.insert(lTargetDatas, mPlayerData)
                end
            else
                local oRobot = self:GetChallengeRobot(oPlayer, info.id)
                if oRobot then
                    table.insert(lTargetDatas, self:PackChallengeTarget(info.type, oRobot))
                end
            end
        end
        mData[iLevel] = lTargetDatas
    end
    endfunc(oPlayer, mData)
end

function CChallengeMgr:PackChallengeLineup(oChallenge, endfunc)
    local oWorldMgr = global.oWorldMgr
    local iPid = oChallenge:GetPid()
    local lFrdIDs = oChallenge:GetPlayerLineup(true)
    if next(lFrdIDs) then
        local mHandle = {
            count = #lFrdIDs,
            loadcnt = 0,
            loaded = false,
        }
        for _, pid in ipairs(lFrdIDs) do
            oWorldMgr:LoadProfile(pid, function (oProfile)
                mHandle.loadcnt = mHandle.loadcnt + 1
                if mHandle.loadcnt >= mHandle.count then
                    mHandle.loaded = true
                    self:_PackChallengeLineup2(iPid, endfunc)
                end
            end)
        end
    else
        self:_PackChallengeLineup2(iPid, endfunc)
    end
end

function CChallengeMgr:_PackChallengeLineup2(iPid, endfunc)
    local oWorldMgr = global.oWorldMgr
    local oChallenge = oWorldMgr:GetChallenge(iPid)
    if not oChallenge then
        return
    end
    local mData = oChallenge:PacketLineupInfo()
    endfunc(iPid, mData)
end

function CChallengeMgr:GetChallengeInfo(oPlayer)
    local oToolMgr = global.oToolMgr
    if not oToolMgr:IsSysOpen("JJC_SYS", oPlayer) then
        return
    end
    
    local iPid = oPlayer:GetPid()
    local oChallenge = oPlayer:GetChallenge()
    oChallenge:CheckInitLineup(oPlayer)
    oChallenge:CheckRoFight(oPlayer)
    if not oChallenge:HasTarget() or oChallenge:GetDayNo() ~= get_dayno() then
        self:InitChallengeTarget(oPlayer, function ()
            self:_GetChallengeInfo2(iPid)
        end)
    else
        self:_GetChallengeInfo2(iPid)
    end
end

function CChallengeMgr:_GetChallengeInfo2(iPid)
    local oWorldMgr = global.oWorldMgr
    local oPlayer = oWorldMgr:GetOnlinePlayerByPid(iPid)
    if not oPlayer then
        return
    end
    local oChallenge = oPlayer:GetChallenge()

    if not oChallenge:GetDifficulty() then
        self:GetChallengeList(oPlayer)
    else
        self:GetChallengeMainInfo(oPlayer)
    end
end

function CChallengeMgr:GetChallengeList(oPlayer)
    local mNet = {}
    mNet.reward = self:GetChallengeTimes(oPlayer)
    oPlayer:Send("GS2CChallengeChooseRank", mNet)
end

function CChallengeMgr:GetChallengeMainInfo(oPlayer)
    self:PackChallengeLineup(oPlayer:GetChallenge(), function (iPid, mData)
        self:_GetChallengeMainInfo2(iPid, mData)
    end)
end

function CChallengeMgr:_GetChallengeMainInfo2(iPid, mLineupInfo)
    local oWorldMgr = global.oWorldMgr
    local oPlayer = oWorldMgr:GetOnlinePlayerByPid(iPid)
    if not oPlayer then
        return
    end

    local oChallenge = oPlayer:GetChallenge()
    local iDifficulty = oChallenge:GetDifficulty()
    self:PackChallengeTargetInfos(oPlayer, iDifficulty, function (oPlayer, mData)
        self:_GetChallengeMainInfo3(oPlayer, mData, mLineupInfo)
    end)
end

function CChallengeMgr:_GetChallengeMainInfo3(oPlayer, mTargetData, mLineupInfo)
    local oChallenge = oPlayer:GetChallenge()

    local mData = {}
    mData.difficulty = oChallenge:GetDifficulty()
    mData.lineup = mLineupInfo
    mData.targets = mTargetData[mData.difficulty]
    mData.beats = oChallenge:GetBeat()
    mData.times = self:GetChallengeRefreshTimes(oPlayer)
    mData = net.Mask("GS2CChallengeMainInfo", mData)
    oPlayer:Send("GS2CChallengeMainInfo", mData)
end

function CChallengeMgr:ChooseChallengeLevel(oPlayer, iLevel)
    local oNotifyMgr = global.oNotifyMgr
    local iTimes = self:GetChallengeTimes(oPlayer)
    if iTimes <= 0 then
        oNotifyMgr:Notify(oPlayer:GetPid(), "没有剩余次数了")
        return
    end
    self:AddChallengeTimes(oPlayer, 1)
    local mLogData = oPlayer:LogData()
    mLogData.times = iTimes
    mLogData.level = iLevel
    record.user("jjc", "challenge_info", mLogData)
    local oChallenge = oPlayer:GetChallenge()
    oChallenge:SetDifficulty(iLevel)
    self:GetChallengeMainInfo(oPlayer)
end

function CChallengeMgr:SetChallengeFormation(oPlayer, iFormation)
    local oChallenge = oPlayer:GetChallenge()
    local oFmtMgr = oPlayer:GetFormationMgr()
    if oFmtMgr:GetFmtObj(iFormation) then 
        oChallenge:SetFormation(oPlayer, iFormation)
    end

    self:PackChallengeLineup(oChallenge, function (iPid, mData)
        self:_SetChallengeLineup2(iPid, mData)
    end)
end

function CChallengeMgr:SetChallengeSummon(oPlayer, iSummId)
    local oChallenge = oPlayer:GetChallenge()
    oChallenge:SetSummon(oPlayer, iSummId, true)
    self:PackChallengeLineup(oChallenge, function (iPid, mData)
        self:_SetChallengeLineup2(iPid, mData)
    end)
end

function CChallengeMgr:SetChallengeFighter(oPlayer, lFighters)
    local oChallenge = oPlayer:GetChallenge()
    oChallenge:SetLineup(oPlayer, lFighters, true)

    self:PackChallengeLineup(oChallenge, function (iPid, mData)
        self:_SetChallengeLineup2(iPid, mData)
    end)
end

function CChallengeMgr:_SetChallengeLineup2(iPid, mLineupInfo)
    local oWorldMgr = global.oWorldMgr
    local oPlayer = oWorldMgr:GetOnlinePlayerByPid(iPid)
    if not oPlayer then
        return
    end

    local mData = {}
    mData.lineup = mLineupInfo
    mData = net.Mask("GS2CChallengeMainInfo", mData)
    oPlayer:Send("GS2CChallengeMainInfo", mData)
end

function CChallengeMgr:StartChallenge(oPlayer, iType, id)
    local iPid = oPlayer:GetPid()
    local oNotifyMgr = global.oNotifyMgr
    local oChallenge = oPlayer:GetChallenge()
    if not oChallenge:HasTarget() or oChallenge:GetDayNo() ~= get_dayno() then
        self:InitChallengeTarget(oPlayer, function ()
            local oWorldMgr = global.oWorldMgr
            local oPlayer = oWorldMgr:GetOnlinePlayerByPid(iPid)
            if oPlayer then
                self:GetChallengeInfo(oPlayer)
            end
        end)
        oNotifyMgr:Notify(oPlayer:GetPid(), "对手信息已过期")
        return
    end
    if not oChallenge:IsNowTarget(iType, id) then
        local oJJCMgr = global.oJJCMgr
        oNotifyMgr:Notify(oPlayer:GetPid(), oJJCMgr:GetTextData(1023))
        return
    end
    local oNowScene = oPlayer.m_oActiveCtrl:GetNowScene()
    if not oNowScene:ValidJJC() then
        oNotifyMgr:Notify(oPlayer:GetPid(), "此场景不能参加连续挑战")
        return
    end
    local mTarget = oChallenge:GetTargetInfo(iType, id)
    assert(mTarget, string.format("challenge target err: %s, %d %d", oChallenge:GetDifficulty(), iType, id))

    if iType == gamedefines.JJC_TARGET_TYPE.ROBOT then
        self:OnStartChallenge(oPlayer, id, function()
            self:ChallengeRobot(iPid, id)
        end)
    else
        self:OnStartChallenge(oPlayer, id, function ()
            self:ChallengePlayer(iPid, id)
        end)
    end
end

function CChallengeMgr:OnStartChallenge(oPlayer ,id, cbfunc)
    local oNotifyMgr = global.oNotifyMgr
    local iPid = oPlayer:GetPid()
    if oPlayer.m_oActiveCtrl:GetNowWar() then
        record.warning(string.format("challenge OnStartChallenge err HasWar %d %d", iPid, id))
        return
    end
    if not oPlayer:IsSingle() then
        oNotifyMgr:Notify(iPid, "请一个人挑战")
        return
    end
    local iGrade = oPlayer:GetGrade()
    local oChallenge = oPlayer:GetChallenge()
    local lFrdIDs = oChallenge:GetFightFriends()

    if #lFrdIDs > 0 then
        local mHandle = {
            count = #lFrdIDs,
            loadcnt = 0,
            check = true,
        }
        local oWorldMgr = global.oWorldMgr
        for _, iFrdID in pairs(lFrdIDs) do
            local func = function(oFrdChallenge)
                self:CheckFriendGrade(oFrdChallenge, mHandle, iGrade, iPid, id ,cbfunc)
            end
            oWorldMgr:LoadChallenge(iFrdID, func)
        end
    else
        cbfunc(iPid, id)
    end
end

function CChallengeMgr:CheckFriendGrade(oFrdChallenge, mHandle, iGrade, iPid, id, cbfunc)
    if oFrdChallenge:GetRoPlayerGrade() - iGrade > 10 then
        mHandle.check = false
        local oJJCMgr = global.oJJCMgr
        global.oNotifyMgr:Notify(iPid, oJJCMgr:GetTextData(1028))
        return
    end
    oFrdChallenge:SetAlwaysActive(true)
    mHandle.loadcnt = mHandle.loadcnt + 1
    if mHandle.loadcnt >= mHandle.count and mHandle.check then
        cbfunc(iPid ,id)
    end
end

function CChallengeMgr:ChallengeRobot(iPid, id)
    local oWorldMgr = global.oWorldMgr
    local oPlayer = oWorldMgr:GetOnlinePlayerByPid(iPid)
    if not oPlayer then
        return
    end
    if oPlayer.m_oActiveCtrl:GetNowWar() then
        record.warning(string.format("challenge ChallengeRobot err HasWar %d %d", iPid, id))
        return
    end
    local oNotifyMgr = global.oNotifyMgr
    if not oPlayer:IsSingle() then
        oNotifyMgr:Notify(iPid, "请一个人挑战")
        return
    end

    local oWarMgr = global.oWarMgr
    local oWar = oWarMgr:CreateWar(
        gamedefines.WAR_TYPE.PVE_TYPE,
        gamedefines.GAME_SYS_TYPE.SYS_TYPE_CHALLENGE, 
        {wholeai=true,GamePlay="challenge",barrage_send=self:GetBarrageSendConfig(),barrage_show=self:GetBarrageShowConfig()}
        )
    local iWarId = oWar:GetWarId()

    local oChallenge = oPlayer:GetChallenge()
    local mInfo = {camp_id=gamedefines.WAR_WARRIOR_SIDE.FRIEND}
    mInfo.summid = oChallenge:GetFightSummID()
    mInfo.partners = oChallenge:GetFightPartnerIDs()
    if not mInfo.summid then
        mInfo.nosumm = true
    end
    local mFmtInfo = oChallenge:GetFormation()
    oWar:PrepareCamp(mInfo.camp_id, {fmtinfo=mFmtInfo})
    oWar:EnterPlayer(oPlayer, mInfo)
    for _, iFrdID in pairs(oChallenge:GetFightFriends()) do
        local oFrdChallenge = oWorldMgr:GetChallenge(iFrdID)
        if oFrdChallenge then
            oWar:EnterRoPlayer(oFrdChallenge, mInfo, true)
            oFrdChallenge:SetAlwaysActive(false)
        end
    end
    oWar:EnterPartner(oPlayer, mInfo, 4)

    local oRobot = self:GetChallengeRobot(oPlayer, id)
    local mCampInfo = {camp_id=gamedefines.WAR_WARRIOR_SIDE.ENEMY}
    oWar:PrepareCamp(gamedefines.WAR_WARRIOR_SIDE.ENEMY, {fmtinfo=oRobot:GetFormation()})
    oWar:EnterRoPlayer(oRobot, mCampInfo)
    oWar:EnterRoPartnerList(oRobot, mCampInfo)

    local fCallback
    fCallback = function (mArgs)
        self:OnChallengeEnd(iPid, gamedefines.JJC_TARGET_TYPE.ROBOT, id, mArgs)
    end
    oWarMgr:SetCallback(iWarId, fCallback)
    oWarMgr:StartWar(iWarId)
    return oWar
end

function CChallengeMgr:ChallengePlayer(iPid, iTarget)
    local oWorldMgr = global.oWorldMgr
    oWorldMgr:LoadJJC(iTarget, function (oJJCCtrl)
        self:_ChallengePlayer1(iPid, oJJCCtrl)
    end)
end

function CChallengeMgr:_ChallengePlayer1(iPid, oJJCCtrl)
    assert(oJJCCtrl, string.format("challenge err: not jjcctrl %d", iPid))
    local iTarget = oJJCCtrl:GetPid()
    local oWorldMgr = global.oWorldMgr
    local oPlayer = oWorldMgr:GetOnlinePlayerByPid(iPid)
    if not oPlayer then
        return
    end
    
    if oPlayer.m_oActiveCtrl:GetNowWar() then
        record.warning(string.format("challenge _ChallengePlayer1 err HasWar %d", iPid))
        return
    end
    local oNotifyMgr = global.oNotifyMgr
    if not oPlayer:IsSingle() then
        oNotifyMgr:Notify(iPid, "请一个人挑战")
        return
    end

    local oWarMgr = global.oWarMgr
    local oWar = oWarMgr:CreateWar(
        gamedefines.WAR_TYPE.PVE_TYPE,
        gamedefines.GAME_SYS_TYPE.SYS_TYPE_CHALLENGE,
        {wholeai=true,GamePlay="challenge"})
    local iWarId = oWar:GetWarId()

    local oChallenge = oPlayer:GetChallenge()
    local mInfo = {camp_id=gamedefines.WAR_WARRIOR_SIDE.FRIEND}
    mInfo.summid = oChallenge:GetFightSummID()
    mInfo.partners = oChallenge:GetFightPartnerIDs()
    if not mInfo.summid then
        mInfo.nosumm = true
    end
    local mFmtInfo = oChallenge:GetFormation()
    oWar:PrepareCamp(mInfo.camp_id, {fmtinfo=mFmtInfo})
    oWar:EnterPlayer(oPlayer, mInfo)
    for _, iFrdID in pairs(oChallenge:GetFightFriends()) do
        local oFrdChallenge = oWorldMgr:GetChallenge(iFrdID)
        if oFrdChallenge then
            oWar:EnterRoPlayer(oFrdChallenge, mInfo, true)
            oFrdChallenge:SetAlwaysActive(false)
        end
    end
    oWar:EnterPartner(oPlayer, mInfo, 4)

    local mCampInfo = {camp_id=gamedefines.WAR_WARRIOR_SIDE.ENEMY}
    oWar:PrepareCamp(gamedefines.WAR_WARRIOR_SIDE.ENEMY, {fmtinfo=oJJCCtrl:GetFormation()})
    oWar:EnterRoPlayer(oJJCCtrl, mCampInfo)
    oWar:EnterRoPartnerList(oJJCCtrl, mCampInfo)

    local fCallback
    fCallback = function (mArgs)
        self:OnChallengeEnd(iPid, gamedefines.JJC_TARGET_TYPE.PLAYER, iTarget, mArgs)
    end
    oWarMgr:SetCallback(iWarId, fCallback)
    oWarMgr:StartWar(iWarId)
    return oWar
end

function CChallengeMgr:OnChallengeEnd(pid, iTargetType, iTarget, mArgs)
    local oWorldMgr = global.oWorldMgr
    local oPlayer = oWorldMgr:GetOnlinePlayerByPid(pid)
    if not oPlayer then
        return
    end

    local isWin, mRecReward = false, {}
    if mArgs.win_side == gamedefines.WAR_WARRIOR_SIDE.FRIEND then
        local oChallenge = oPlayer:GetChallenge()
        oChallenge:SetBeat(iTargetType, iTarget)
        self:ChallengeReward(oPlayer, mRecReward)
        if oChallenge:HasBeatAll() then
            self:ChallengeRewardBeatAll(oPlayer, mRecReward)
        end
        if oChallenge:HasBeatAll() or oChallenge:GetDayNo() ~= get_dayno() then
            self:InitChallengeTarget(oPlayer, function ()
                local oWorldMgr = global.oWorldMgr
                local oPlayer = oWorldMgr:GetOnlinePlayerByPid(pid)
                if oPlayer then
                    self:GetChallengeInfo(oPlayer)
                end
            end)
        end
        isWin = true
        self:GetChallengeMainInfo(oPlayer)
    end

    self:LogChallengeAnalyInfo(oPlayer, iTargetType, iTarget, mRecReward, isWin)
end

function CChallengeMgr:LogChallengeAnalyInfo(oPlayer, iTargetType, iTarget, mRecReward, isWin)
    if not oPlayer then return end

    local mAnalyLog = oPlayer:BaseAnalyInfo()
    mAnalyLog["category"] = 2
    mAnalyLog["turn_times"] = 1
    mAnalyLog["win_mark"] = isWin
    mAnalyLog["match_player"] = ""
    mAnalyLog["reward_detail"] = analy.table_concat(mRecReward)

    if iTargetType == gamedefines.JJC_TARGET_TYPE.ROBOT then
        local oRobot = self:GetChallengeRobot(oPlayer, iTarget)
        if not oRobot then return end

        mAnalyLog["match_player"] = "is_robot+"..oRobot:GetSchool().."+"..oRobot:GetGrade()
        analy.log_data("arena", mAnalyLog)
    else
        local oWorldMgr = global.oWorldMgr
        oWorldMgr:LoadProfile(iTarget, function (o)
            if not o then return end

            mAnalyLog["match_player"] = ""..o:GetPid().."+"..o:GetSchool().."+"..o:GetGrade()
            analy.log_data("", mAnalyLog)    
        end)
    end
end

function CChallengeMgr:InitMultiItem(iPid, iSid, iAmount)
    local lItems = {}
    local oItem = global.oItemLoader:GetItem(iSid)
    local iMax = math.max(1, oItem:GetMaxAmount())
    local iNum = math.floor(iAmount / math.max(1, oItem:GetMaxAmount()))
    local iLeft = iAmount % iMax
    for i=1,iNum do
        local oNewItem = global.oItemLoader:Create(iSid)
        oNewItem:SetAmount(iMax)
        table.insert(lItems, oNewItem)
    end
    if iLeft > 0 then
        local oNewItem = global.oItemLoader:Create(iSid)
        oNewItem:SetAmount(iLeft)
        table.insert(lItems, oNewItem)
    end
    return lItems
end

function CChallengeMgr:GetBarrageShowConfig()
    local iRet = res["daobiao"]["jjc"]["jjc_global"][1]["challenge_barrage_show"] or 0
    return iRet
end

function CChallengeMgr:GetBarrageSendConfig()
    local iRet = res["daobiao"]["jjc"]["jjc_global"][1]["challenge_barrage_send"] or 0
    return iRet
end

function CChallengeMgr:InitChallengeReward(iPid, iLevel, iBeatCnt, iGrade)
    local mInfo = res["daobiao"]["jjc"]["challenge_reward_normal"][iLevel]
    assert(mInfo, string.format("challenge InitChallengeReward err: level %d", iLevel))
    local mData = mInfo[iBeatCnt]
    assert(mData, string.format("challenge InitChallengeReward err: beatcnt %d", iBeatCnt))
    local lItems = {}
    for _, mInfo in ipairs(mData["item"]) do
        local iSID = mInfo["sid"]
        local sAmount = mInfo["amont"]
        local iAmount = formula_string(sAmount, {level=iGrade, beatcnt=iBeatCnt})
        lItems = self:InitMultiItem(iPid, iSID, iAmount)
    end
    local iPoint = formula_string(mData["point"], {level=iGrade, beatcnt=iBeatCnt})
    local iExp = formula_string(mData["exp"], {lv=iGrade})
    return lItems, iPoint, iExp
end

function CChallengeMgr:ChallengeReward(oPlayer, mRecReward)
    local oNotifyMgr = global.oNotifyMgr
    local iPid = oPlayer:GetPid()
    local oChallenge = oPlayer:GetChallenge()
    mRecReward = mRecReward or {}

    local iGrade = oPlayer:GetGrade()
    local iLevel = oChallenge:GetDifficulty()
    local iBeatCnt = #oChallenge:GetBeat()

    if self.m_oRewardMonitor then
        if not self.m_oRewardMonitor:CheckRewardGroup(iPid, iLevel, 1) then
            return
        end
    end
    
    local lItems, iPoint, iExp = self:InitChallengeReward(iPid, iLevel, iBeatCnt, iGrade)
    for _, oItem in ipairs(lItems) do
        mRecReward[oItem:SID()] = oItem:GetAmount()
        oPlayer:RewardItem(oItem, "挑战")
    end
    if iPoint > 0 then
        oPlayer.m_oActiveCtrl:AddChallengePoint(iPoint)
        mRecReward[1009] = iPoint
    end
    if iExp > 0 then
        oPlayer:RewardExp(iExp, "挑战", {bEffect = true})
        mRecReward[1005] = iExp
    end
end

function CChallengeMgr:InitChallengeBeatAllReward(iPid, iLevel, iGrade)
    local mData = res["daobiao"]["jjc"]["challenge_reward_beatall"][iLevel]
    assert(mData, string.format("challenge InitChallengeBeatAllReward err: level %d", iLevel))
    local lItems = {}
    for _, mInfo in ipairs(mData["item"]) do
        local iSID = mInfo["sid"]
        local sAmount = mInfo["amont"]
        local iAmount = formula_string(sAmount, {level=iGrade})
        lItems = self:InitMultiItem(iPid, iSID, iAmount)
    end
    local iPoint = formula_string(mData["point"], {level=iGrade})
    local iExp = formula_string(mData["exp"], {lv=iGrade})
    return lItems, iPoint, iExp
end

function CChallengeMgr:ChallengeRewardBeatAll(oPlayer, mRecReward)
    local iPid = oPlayer:GetPid()
    local oChallenge = oPlayer:GetChallenge()
    mRecReward = mRecReward or {}

    local iGrade = oPlayer:GetGrade()
    local iLevel = oChallenge:GetDifficulty()
    local lItems, iPoint, iExp = self:InitChallengeBeatAllReward(iPid, iLevel, iGrade)
    for _, oItem in ipairs(lItems) do
        mRecReward[oItem:SID()] = oItem:GetAmount()
        oPlayer:RewardItem(oItem, "挑战")
    end
    if iPoint > 0 then
        oPlayer.m_oActiveCtrl:AddChallengePoint(iPoint)
        mRecReward[1009] = iPoint
    end
    if iExp > 0 then
        oPlayer:RewardExp(iExp, "挑战", {bEffect = true})
        mRecReward[1005] = iExp
    end
end

function CChallengeMgr:GetChallengeTimes(oPlayer)
    local oJJCMgr = global.oJJCMgr
    local iTimes = oJJCMgr:GetJJCRewardTimesConfig()
    return iTimes - oPlayer.m_oTodayMorning:Query("chlg_times", 0)
end

function CChallengeMgr:AddChallengeTimes(oPlayer, iAdd)
    oPlayer.m_oTodayMorning:Add("chlg_times", iAdd)
end

function CChallengeMgr:GetChallengeRefreshTimes(oPlayer)
    local oJJCMgr = global.oJJCMgr
    local iTimes = oJJCMgr:GetJJCRefreshTimesConfig()
    return iTimes - oPlayer.m_oTodayMorning:Query("chlg_refresh_times", 0)
end

function CChallengeMgr:AddChallengeRefreshTimes(oPlayer, iAdd)
    oPlayer.m_oTodayMorning:Add("chlg_refresh_times", iAdd)
end

function CChallengeMgr:ResetChallengeTarget(oPlayer)
    local oNotifyMgr = global.oNotifyMgr
    local iTimes = self:GetChallengeRefreshTimes(oPlayer)
    if iTimes <= 0 then
        oNotifyMgr:Notify(oPlayer:GetPid(), "无剩余重置次数")
        return
    end
    local mLogData = oPlayer:LogData()
    mLogData.times = iTimes
    record.user("jjc", "challenge_reset", mLogData)
    local iPid = oPlayer:GetPid()
    self:AddChallengeRefreshTimes(oPlayer, 1)
    local oChallenge = oPlayer:GetChallenge()
    self:ClearChallengeRobot(iPid)
    self:InitChallengeTarget(oPlayer, function ()
        local oWorldMgr = global.oWorldMgr
        local oPlayer = oWorldMgr:GetOnlinePlayerByPid(iPid)
        if oPlayer then
            self:GetChallengeInfo(oPlayer)
        end
    end)
end

function CChallengeMgr:GetChallengeTargetLineup(oPlayer, iType, id)
    local iPid = oPlayer:GetPid()
    local oChallenge = oPlayer:GetChallenge()
    local mTarget = oChallenge:GetTargetInfo(iType, id)
    assert(mTarget, string.format("challenge target err: %s, %d %d", oChallenge:GetDifficulty(), iType, id))

    if iType == gamedefines.JJC_TARGET_TYPE.PLAYER then
        local oWorldMgr = global.oWorldMgr
        oWorldMgr:LoadJJC(id, function (oJJCCtrl)
            if oJJCCtrl then
                self:_GetChallengeTargetLineup2(iPid, iType, id, oJJCCtrl:PacketLineupInfo())
            end
        end)
    else
        local oRobot = self:GetChallengeRobot(oPlayer, id)
        if oRobot then
            self:_GetChallengeTargetLineup2(iPid, iType, id, oRobot:PacketLineupInfo())
        end
    end
end

function CChallengeMgr:_GetChallengeTargetLineup2(iPid, iType, id, mLineup)
    local oWorldMgr = global.oWorldMgr
    local oPlayer = oWorldMgr:GetOnlinePlayerByPid(iPid)
    if not oPlayer then
        return
    end
    local mNet = {}
    mNet.lineup = mLineup
    mNet.target = {
        type = iType,
        id = id,
    }
    oPlayer:Send("GS2CChallengeTargetLineup", mNet)
end

function CChallengeMgr:AddTrialMatchInfo(iPid, mData)
    interactive.Send(".recommend", "challenge", "AddTrialMatchInfo", {
        pid = iPid,
        data = mData,
    })
end

function CChallengeMgr:GetTrialMatchInfo(iPid, mData, callback)
    interactive.Request(".recommend", "challenge", "GetTrialMatchInfo", mData,
    function (mRecord, mData)
        if not is_release(self) then
            -- -1: 等级范围内匹配不到玩家
            callback(iPid, mData)
        end
    end)
end

