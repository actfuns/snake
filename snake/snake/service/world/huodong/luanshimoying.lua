local global = require "global"
local res = require "base.res"
local record = require "public.record"
local extend = require "base.extend"
local gamedefines = import(lualib_path("public.gamedefines"))
local huodongbase = import(service_path("huodong.huodongbase"))

function NewHuodong(sHuodongName)
    return CHuodong:New(sHuodongName)
end

CHuodong = {}
CHuodong.__index = CHuodong
CHuodong.m_sTempName = "乱世魔影"
inherit(CHuodong, huodongbase.CHuodong)

local STATE = {
    OPEN = 1,
    CLOSE = 2, 
}

local BOSSTYPE = {
    NONE = 0,
    ONEBOSS = 1,
    TWOBOSS = 2,
    FOURBOSS = 3,
}

function CHuodong:New(sHuodongName)
    local o = super(CHuodong).New(self, sHuodongName)
    return o
end

function CHuodong:Init()
    self.m_iBossNpcId = nil
    self.m_iLastBossStar = 0
    self.m_iLastRefreshTime = 0
    self.m_bDelayRefresh = false
    self.m_bDelayDisappearBigBoss = false
    self.m_bLastAllDone = false --标记boss是否全被击杀
    self.m_mBoss = {}
    self.m_mBox = {}
    self.m_mTmpStar = {}
    self.m_iLastBossNpcId = nil
    self.m_iLastResetTime = 0
end

function CHuodong:Load(mData)
    mData = mData or {}
    self:Dirty()
    self.m_iBossNpcId = mData.boss
    self.m_iLastBossStar = mData.last_boss_star or 0
    self.m_iLastRefreshTime = mData.last_refresh_time or 0
    self.m_bLastAllDone = mData.last_all_done == 1 or false
    self.m_iLastResetTime = mData.last_reset_time or 0
end

function CHuodong:Save()
    local mData = {
        boss = self.m_iBossNpcId,
        last_boss_star = self.m_iLastBossStar,
        last_refresh_time = self.m_iLastRefreshTime,
        last_all_done = self.m_bLastAllDone and 1 or 0,
        last_reset_time = self.m_iLastResetTime,
    }
    return mData
end

function CHuodong:AfterLoad()
    local bOpen = global.oToolMgr:IsSysOpen("LUANSHIMOYING")
    if not bOpen then return end

    self:CheckState()
    self:CheckOpenClose()

    if self:IsOpen() then
        local iDayNo = get_morningdayno(self.m_iLastRefreshTime)
        local iTodayNo = get_morningdayno(get_time())
        local iResetDay = get_morningdayno(self.m_iLastResetTime)
        local bResetNewDay = iResetDay ~= iTodayNo
        if bResetNewDay then
            self:ResetStar()
            self:Dirty()
        end
        
        --关服前有大boss,起服后要刷出大boss
        if self.m_iBossNpcId then
            local bNewDay = iDayNo ~= iTodayNo
            self:RefreshBigBoss(bNewDay, true)
        else
            local iNowTime = get_time()
            self:AddRefreshBigBossCb(iNowTime)
        end
    end
end

function CHuodong:NeedSave()
    return true
end

function CHuodong:MergeFrom(mFromData)
    return true
end

function CHuodong:GetFortune(iMoneyType, mArgs)
    return false
end

function CHuodong:NewHour(mNow)
    local bOpen = global.oToolMgr:IsSysOpen("LUANSHIMOYING")
    if not bOpen then return end

    self:CheckOpenClose(mNow)
end

function CHuodong:NewDay(iDay)
    self:ResetStar()
    self.m_iLastResetTime = get_time()
    self:Dirty()
end

function CHuodong:ResetStar()
    if self.m_iLastBossStar then
        self.m_iLastBossStar = self.m_iLastBossStar - 2
        if self.m_iLastBossStar < 3 then
            self.m_iLastBossStar = 3
        end
    end
end

function CHuodong:IsOpen()
    return self.m_iState == STATE.OPEN
end

function CHuodong:CheckState()
    local iTime = get_time()
    local iStartTime = self:GetTodayStartTime()
    local iEndTime = self:GetTodayEndTime()
    self.m_iState = STATE.OPEN
    if iTime < iStartTime or iTime > iEndTime then
        self.m_iState = STATE.CLOSE
    end
end

function CHuodong:CheckOpenClose(mNow)
    local iTime = mNow and mNow.time or get_time()
    if self:IsOpen() then
        local iEndTime = self:GetTodayEndTime(mNow)
        local iSubTime = iEndTime - iTime
        if iSubTime >= 0 and iSubTime < 3600 then
            self:AddEndCb(iEndTime)
        end
    else
        local iStartTime = self:GetTodayStartTime(mNow)
        local iSubTime = iStartTime - iTime
        if iSubTime >= 0 and iSubTime < 3600 then      
            self:AddStartCb(iStartTime)
        end
    end
end

function CHuodong:AddStartCb(iStartTime)
    self:DelTimeCb("GameTimeStart")
    self:AddTimeCb("GameTimeStart", (iStartTime - get_time()) * 1000, function()
        if not self:IsOpen() then
            self:StartToday()
        end
    end)
end

function CHuodong:AddEndCb(iEndTime)
    self:DelTimeCb("GameTimeEnd")
    self:AddTimeCb("GameTimeEnd", (iEndTime - get_time()) * 1000, function()
        if self:IsOpen() then 
            self:EndToday() 
        end
    end)
end

function CHuodong:AddRefreshBigBossCb(iCurTime)
    local mConfig = self:GetConfig()
    local iNextTime = self:GetNextRefreshTime(iCurTime)
    if not iNextTime then 
        return
    end

    local iSubTime = iNextTime - iCurTime
    if iSubTime <= 0 then return end

    self:DelTimeCb("GameRefreshBigBoss")
    self:AddTimeCb("GameRefreshBigBoss", iSubTime * 1000, function()
        self.m_bDelayDisappearBigBoss = false
        if self:IsOpen() then 
            self:RefreshBigBoss() 
        end
    end)
end

function CHuodong:AddBigBossDisappearCb()
    local mConfig = self:GetConfig()
    local iTime = mConfig.boss_disappear_time * 60
    
    self:DelTimeCb("GameBigBossDisappear")
    self:AddTimeCb("GameBigBossDisappear", iTime * 1000, function()
        if self:IsOpen() then 
            self:TryDisappearBigBoss()
        end
    end)
end

function CHuodong:AddBoxDisappearCb()
    local mConfig = self:GetConfig()
    local iTime = mConfig.box_exist_time
    self:DelTimeCb("GameBoxDisappear")
    self:AddTimeCb("GameBoxDisappear", iTime * 1000, function()
        self.m_iBossNpcId = nil
        self:ClearBox()
    end)
end

function CHuodong:GetTodayStartTime(mNow)
    local iTime = mNow and mNow.time or get_time()
    local mConfig = self:GetConfig()
    local sStartTime = mConfig.start_time
    return self:GetTimeStamp(iTime, sStartTime)
end

function CHuodong:GetTodayEndTime(mNow)
    local iTime = mNow and mNow.time or get_time()
    local mConfig = self:GetConfig()
    local sEndTime = mConfig.end_time
    return self:GetTimeStamp(iTime, sEndTime)
end

--获取下一个刷新时间戳
function CHuodong:GetNextRefreshTime(iNowTime)
    local mNow = {time = iNowTime}
    local mConfig = self:GetConfig()
    local iInterval = mConfig.interval_time * 3600
    local iTodayStart = self:GetTodayStartTime(mNow)
    local iTodayEnd = self:GetTodayEndTime(mNow)
    
    if iNowTime < iTodayStart or iNowTime > iTodayEnd then
        return
    end

    local iLastTime = iTodayStart
    for i=1,1000 do
        local iNextTime = iLastTime + iInterval
        if iNowTime >= iLastTime and iNowTime < iNextTime then
            return iNextTime
        end
        iLastTime = iLastTime + iInterval
        if iLastTime > iTodayEnd then
            return
        end
    end
end

function CHuodong:GetTimeStamp(iTime, sConfigTime)
    iTime = iTime or get_time()
    local sToday = os.date("%Y-%m-%d", iTime)
    local sCurTime = string.format("%s %s", sToday, sConfigTime)
    return get_str2timestamp(sCurTime)
end

function CHuodong:StartToday()
    self.m_iState = STATE.OPEN
    self.m_bDelayRefresh = false
    self.m_bDelayDisappearBigBoss = false
    self:RefreshBigBoss(true)
end

function CHuodong:EndToday()
    self.m_iState = STATE.CLOSE
    self.m_iBossNpcId = nil
    self:DelTimeCb("GameRefreshBigBoss")
    self:DelTimeCb("GameBigBossDisappear")
    self:TryClearBoss() --清除不在战斗中的，战斗中的战斗后清除
    self:SetHuodongState(gamedefines.ACTIVITY_STATE.STATE_HIDE)
end

function CHuodong:IsBigBossExist()
    local mBossType = self.m_mBoss[BOSSTYPE.ONEBOSS]
    if mBossType and mBossType[1] then
        return true
    end
    return false
end

function CHuodong:RefreshBigBoss(bNewDay, bStartUp)
    --大boss还在不刷新
    if self:IsBigBossExist() then 
        self:AddRefreshBigBossCb(get_time())
        self:AddBigBossDisappearCb()
        return
    end 

    --刷新时如果有处于战斗中的，战斗结束后刷新
    if not self:IsBossInWar() then
        self:TryClearBoss()
        self.m_mBoss = {}
        self.m_iLastRefreshTime = get_time()
        self.m_bDelayRefresh = false
        self:BinaryBoss(nil, bNewDay, bStartUp) --刷新大boss
        self:AddRefreshBigBossCb(self.m_iLastRefreshTime) --三小时刷新一次
        self:AddBigBossDisappearCb() --半小时候检查大boss是否还没打完
        self.m_bLastAllDone = false
        self:Dirty()

        --传闻
        local oBoss = self.m_mBoss[BOSSTYPE.ONEBOSS][1]
        assert(oBoss, "CHuodong luanshimoying no big boss")
        local iScene = oBoss:GetScene()
        local sSceneName = global.oSceneMgr:GetScene(iScene):GetName()
        local mPos = oBoss.m_mPosInfo
        local iPosX = math.floor(mPos.x)
        local iPosY = math.floor(mPos.y)
        local mFormat = {npc_name=oBoss:Name(), map = sSceneName, x = iPosX, y = iPosY}
        self:SysAnnounce(1098, mFormat)
        self:SetHuodongState(gamedefines.ACTIVITY_STATE.STATE_START)
    else
        self.m_bDelayRefresh = true
    end
end

function CHuodong:BinaryBoss(oParent, bNewDay, bStartUp)
    local iBossType = oParent and oParent.boss_type or BOSSTYPE.NONE
    local iNextType = iBossType + 1
    self.m_mBoss[iNextType] = self.m_mBoss[iNextType] or {}
    local iNum = iBossType == BOSSTYPE.NONE and 1 or 2
    for i=1, iNum do
        local oBoss = self:InsertBossToScene(oParent, iNextType, bNewDay, bStartUp)
        if oBoss then
            table.insert(self.m_mBoss[iNextType], oBoss)
        end
    end

    if oParent and iNum == 2 then
        self:DelTimeCb("GameBigBossDisappear")

        local iScene = oParent:GetScene()
        self:SayCurrentChannel(iScene, 2007)
        self:SysAnnounce(1100, {npc_name=oParent:Name()})
    end
end

function CHuodong:InsertBossToScene(oParent, iBossType, bNewDay, bStartUp)
    local iNpcId = self:GetBossNpcId(oParent, bStartUp)
    local iStar = self:GetBossStar(oParent, iBossType, bNewDay)
    local iMap = self:GetBossMap(oParent)
    local iScene = self:GetBossSceneId(oParent, iMap)
    if iBossType == BOSSTYPE.ONEBOSS then
        self.m_iBossNpcId = iNpcId
        self.m_iLastBossNpcId = iNpcId
        self:Dirty()
    end

    local iNewX, iNewY = global.oSceneMgr:RandomPos2(iMap)
    local oBoss = self:CreateTempNpc(iNpcId)
    oBoss.m_mPosInfo.x = iNewX
    oBoss.m_mPosInfo.y = iNewY
    oBoss.boss_type = iBossType
    oBoss.boss_star = iStar
    oBoss.m_sTitle = self:ChangeNpcShowTitle(iNpcId, iStar)
    oBoss.m_sShowName = self:ChangeNpcShowName(iStar, oBoss.m_sName)
    self:Npc_Enter_Scene(oBoss, iScene)

    self:LogBoss(iBossType, iNpcId, iStar, iScene)
    return oBoss
end

function CHuodong:ChangeNpcShowTitle(iNpcId, iStar, sName)
    local mData = self:GetTempNpcData(iNpcId)
    local sTitle = mData["title"] or ""
    sTitle = sTitle .. string.format("(%s#w4)", iStar)
    return sTitle
end

function CHuodong:ChangeNpcShowName(iStar, sName)
    sName = sName .. string.format("(%s#w4)",iStar)
    return sName
end

function CHuodong:SayText(pid,npcobj,sText,func)
    local sName =  npcobj.m_sName
    npcobj.m_sName = npcobj.m_sShowName
    super(CHuodong).SayText(self, pid,npcobj,sText,func)
    npcobj.m_sName = sName
end

function CHuodong:GetBossNpcId(oParent, bStartUp)
    if oParent then return oParent:NpcID() end --要分身时，和父boss的一样的npc
    if bStartUp and self.m_iBossNpcId then return self.m_iBossNpcId end --如果是重启，上次有boss没打完就是上次的boss
    local mBossConfig = self:GetBossConfig()
    local mNpc = {}
    local mAllNpc = {}
    for iNpcId, mConfig in pairs(mBossConfig) do
        if not (self.m_iLastBossNpcId and self.m_iLastBossNpcId == iNpcId) then
            mNpc[iNpcId] = mConfig.ratio
        end
        mAllNpc[iNpcId] = mConfig.ratio
    end
    local iNpcId = table_choose_key(mNpc)

    --保底,正确规则不走这里,因为新刷出来的时候要和原来的要不一样
    --但是,策划可能改表只开发了一个...
    if not iNpcId then
        iNpcId = table_choose_key(mAllNpc)
    end
    assert(iNpcId, "CHuodong luanshimoying GetBossNpcId error")

    return iNpcId
end

function CHuodong:GetBossMap(oParent)
    if oParent then return oParent:MapId() end
    local mConfig = self:GetConfig()
    local lMapPool = mConfig.map_pool
    local iMap = extend.Random.random_choice(lMapPool)
    return iMap
end

function CHuodong:GetBossSceneId(oParent, iMap)
    if oParent then return oParent:GetScene() end
    local lScene = global.oSceneMgr:GetSceneListByMap(iMap)
    local oScene = extend.Random.random_choice(lScene)
    return oScene:GetSceneId()
end

function CHuodong:GetBossStar(oParent, iBossType, bNewDay)
    local iStar = 0
    --如果刷新的是大boss
    if iBossType == BOSSTYPE.ONEBOSS then
        if bNewDay then --是新的一天，大boss星级是昨天最后大boss等级-2
            iStar = self.m_iLastBossStar
        else
            if self.m_bLastAllDone then
                iStar = self.m_iLastBossStar + 1
            else
                if self.m_iBossNpcId then
                    iStar = self.m_iLastBossStar
                else
                    iStar = self.m_iLastBossStar - 1
                end
            end
        end
    else
        --分身，比原boss的星级-1
        if oParent then
            iStar = oParent.boss_star - 1
        end
    end

    if iBossType == BOSSTYPE.ONEBOSS then
        local mConfig = self:GetConfig()
        local iMinStar = mConfig.min_star
        local iMaxStar = mConfig.max_star
        if iStar < iMinStar then iStar = iMinStar end
        if iStar > iMaxStar then iStar = iMaxStar end
        self.m_iLastBossStar = iStar
        self:Dirty()
    end
    assert(iStar>=1 and iStar<=10)
    return iStar
end

function CHuodong:TryDisappearBigBoss()
    local mTypeBoss = self.m_mBoss[BOSSTYPE.ONEBOSS] or {}
    if table_count(mTypeBoss) > 0 then
        local oBigBoss = mTypeBoss[1]
        if not oBigBoss then return end
        
        if oBigBoss:InWar() then
            self.m_bDelayDisappearBigBoss = true
        else
            self.m_bDelayDisappearBigBoss = false
            self:RemoveTempNpc(oBigBoss)
            self.m_iBossNpcId = nil
            self.m_mBoss[BOSSTYPE.ONEBOSS] = {}
            self:SysAnnounce(1099, {npc_name=oBigBoss:Name()})
            self:SetHuodongState(gamedefines.ACTIVITY_STATE.STATE_HIDE)
        end
    end
end

function CHuodong:IsBossInWar()
    for _, mTypeBoss in pairs(self.m_mBoss) do
        for _, oBoss in pairs(mTypeBoss) do
            if oBoss:InWar() then
                return true
            end
        end
    end
    return false
end

function CHuodong:TryClearBoss()
    for _, mTypeBoss in pairs(self.m_mBoss) do
        local lIdx = {}
        for iIndex, oBoss in pairs(mTypeBoss) do
            if not oBoss:InWar() then
                table.insert(lIdx, iIndex)
            end
        end

        for iIndex=#lIdx, 1, -1 do
            local oBoss = table.remove(mTypeBoss, iIndex)
            if oBoss then
                self:RemoveTempNpc(oBoss)
            end
        end
    end
end

function CHuodong:RemoveBoss(oBoss)
    if not oBoss then return end
    local iBossType = oBoss.boss_type
    local iIndex
    for iIdx, oBossNpc in pairs(self.m_mBoss[iBossType]) do
        if oBoss:ID() == oBossNpc:ID() then 
            iIndex = iIdx 
            break
        end
    end
    if not iIndex then return end
    
    local iMap = oBoss:MapId()
    table.remove(self.m_mBoss[iBossType], iIndex)
    self:RemoveTempNpc(oBoss)
end

function CHuodong:FindPathToBoss(oPlayer)
    local bOpen = global.oToolMgr:IsSysOpen("LUANSHIMOYING")
    if not bOpen then return end

    local iPid = oPlayer:GetPid()

    local iMaxStar = 0
    local oBossTarget 
    for _, mBossType in pairs(self.m_mBoss) do
        for _, oBoss in pairs(mBossType) do
            local iStar = oBoss.boss_star
            if iStar > iMaxStar then
                oBossTarget = oBoss
                iMaxStar = iStar
                break
            end
        end
    end

    if oBossTarget and not global.oNpcMgr:GotoNpcAutoPath(oPlayer, oBossTarget) then
        self:OpenHDSchedule(oPlayer:GetPid())
    end
end

function CHuodong:FindPathToBox(oPlayer)
    local iPid = oPlayer:GetPid()
    
    local oBoxTarget
    for iBoxIdx, oBox in pairs(self.m_mBox) do
        oBoxTarget = oBox
        break
    end

    if oBoxTarget then
        global.oNpcMgr:GotoNpcAutoPath(oPlayer, oBoxTarget)
    end
end

function CHuodong:RefreshBox(iScene)
    self:ClearBox()
    local iNum = self:GetBoxNum(iScene)
    for idx=1, iNum do
        local oBox = self:InsertBoxToScene(iScene)
        oBox.box_idx = idx
        oBox.boss_star = self.m_iLastBossStar
        self.m_mBox[idx] = oBox
    end
    self:LogBox(iScene, self.m_iLastBossStar, iNum)
    self:AddBoxDisappearCb()
end

function CHuodong:ClearBox()
    for iBoxIdx, oBox in pairs(self.m_mBox) do
        self:RemoveTempNpc(oBox)
    end
    self.m_mBox = {}
end

function CHuodong:GetBoxNum(iScene)
    local mConfig = self:GetConfig()
    local sNum = mConfig.box_num
    local iMinNum = mConfig.min_box
    local iMaxNum = mConfig.max_box
    local iOnlineCnt = global.oWorldMgr:GetOnlinePlayerCnt()

    local oScene = global.oSceneMgr:GetScene(iScene)
    local lPlayerIds = oScene:GetAllPlayerIds()
    local iSceneNum = #lPlayerIds
    local iNum =  math.floor(formula_string(sNum, { scene_num = iSceneNum }))
    if iNum < iMinNum then return iMinNum end
    if iNum > iMaxNum then return iMaxNum end
    return iNum
end

function CHuodong:InsertBoxToScene(iScene)
    local mConfig = self:GetConfig()
    local iNpc = mConfig.box_npc
    local oScene = global.oSceneMgr:GetScene(iScene)
    local iX, iY = global.oSceneMgr:RandomPos2(oScene:MapId())
    local oNpc = self:CreateTempNpc(iNpc)
    oNpc.m_mPosInfo.x = iX
    oNpc.m_mPosInfo.y = iY
    self:Npc_Enter_Scene(oNpc, oScene:GetSceneId())
    return oNpc
end

function CHuodong:OtherScript(iPid, oNpc, s, mArgs)
    local sCmd = string.match(s,"^([$%a]+)")
    if not sCmd then return end

    local sArgs = string.sub(s, #sCmd+1, -1)
    if sCmd == "$clickbox" then
        self:ClickBox(iPid, oNpc)
    end
end

function CHuodong:ClickBox(iPid, oBox)
    local oPlayer = global.oWorldMgr:GetOnlinePlayerByPid(iPid)
    if not oPlayer then return end

    --检查间隔时间
    local mConfig = self:GetConfig()
    local iLimitTime = mConfig.box_limit_time
    local iTime = get_time()
    local iLastTime = oPlayer.m_oTodayMorning:Query("luanshimoying_box_time", 0)
    local iSubTime = iTime - iLastTime
    if iSubTime < iLimitTime then
        local sMsg = self:GetTextData(2004)
        sMsg = global.oToolMgr:FormatColorString(sMsg, {amount = iLimitTime-iSubTime})
        global.oNotifyMgr:Notify(iPid, sMsg)
        return
    end
    oPlayer.m_oTodayMorning:Set("luanshimoying_box_time", iTime)

    if not oBox then return end
    local iBoxIdx = oBox.box_idx
    if self.m_mBox[iBoxIdx] then
        self:RemoveTempNpc(oBox)
        self.m_mBox[iBoxIdx] = nil
    end

    local mConfig = self:GetConfig()
    local iBoxReward = mConfig.box_reward
    self:Reward(iPid, iBoxReward)
end

function CHuodong:PackWarriorsAttr(oWar, mMonsterData, oNpc)
    local mWarriors = {}
    for _, iGroup in pairs(mMonsterData) do
        local mData = res["daobiao"]["fight"][self.m_sName]["group"]
        local mGroup = self:GetFightMonsterGroup(iGroup)
        local iMonsterIdx = extend.Random.random_choice(mGroup["monster"])
        local oMonster = self:CreateMonster(oWar, iMonsterIdx, oNpc)
        assert(oMonster,string.format("%s %s",self.m_sName, iMonsterIdx))
        table.insert(mWarriors, self:PackMonster(oMonster))
    end
    return mWarriors
end

function CHuodong:OnWarWin(oWar, pid, oBoss, mArgs)
    super(CHuodong).OnWarWin(self, oWar, pid, oBoss, mArgs)

    local iBossType = oBoss.boss_type
    if self:IsOpen() and iBossType < BOSSTYPE.FOURBOSS then
        self:BinaryBoss(oBoss)
    end

    local iMap = oBoss:MapId()
    local iScene = oBoss:GetScene()
    local iNpcId = oBoss:NpcID()
    local iStar = oBoss.boss_star
    local sName = oBoss:Name()
    self:RemoveBoss(oBoss)
    self:GiveBossScore(pid, iNpcId, iStar, sName)
    self.m_iBossNpcId  = nil

    local bIsFour = iBossType == BOSSTYPE.FOURBOSS
    if self:IsOpen() and bIsFour and self:IsKillAllBoss() then
        self:RefreshBox(iScene)
        self.m_bLastAllDone = true
        self:Dirty()
        self:SysAnnounce(1101, {npc_name=sName})
        self:SetHuodongState(gamedefines.ACTIVITY_STATE.STATE_HIDE)
    end
end

function CHuodong:IsKillAllBoss()
    for _, mTypeBoss in pairs(self.m_mBoss) do
        for _, oBoss in pairs(mTypeBoss) do
            return false
        end
    end
    return true
end

function CHuodong:GiveBossScore(iPid, iNpcId, iStar, sBossName)
    local oPlayer = global.oWorldMgr:GetOnlinePlayerByPid(iPid)
    if not oPlayer then return end

    local oTeam = oPlayer:HasTeam()
    if not oTeam then return end 

    local mConfig = self:GetConfig()
    local mScoreConfig = self:GetScoreConfig()
    assert(mScoreConfig and mScoreConfig[iStar], "CHuodong luanshimoying score config error")
    local iScore = mScoreConfig[iStar].score

    local lMember = oTeam:GetTeamMember()
    for _,iMemPid in pairs(lMember or {}) do
        local oMem = oTeam:GetMember(iMemPid)
        if oMem then
            local iPid = oMem.m_ID
            self:GiveOne(iPid, iNpcId, iStar, iScore, sBossName)
        end
    end

    for iPid, _ in pairs(oTeam:GetShortLeave()) do
        self:GiveOne(iPid, iNpcId, iStar, iScore, sBossName)
    end
end

function CHuodong:GiveOne(iPid, iNpcId, iStar, iScore, sBossName)
    local oPlayer = global.oWorldMgr:GetOnlinePlayerByPid(iPid)
    if oPlayer then
        self.m_mTmpStar[iPid] = iStar
        local iRewardId = self:GetRewardIdByStar(iNpcId, iStar)
        self:Reward(iPid, iRewardId, {is_boss = true, npc = sBossName})

        local iWeekScore = oPlayer.m_oThisWeek:Query("luanshimoying_weekscore", 0)
        local iNewWeekScore = iWeekScore + iScore
        oPlayer.m_oThisWeek:Set("luanshimoying_weekscore", iNewWeekScore)
        self:PushDataToRank(oPlayer, iNewWeekScore)
        local sMsg = self:GetTextData(2005)
        sMsg = global.oToolMgr:FormatColorString(sMsg, {amount=iScore})
        global.oNotifyMgr:Notify(iPid, sMsg)
    end
end

function CHuodong:GetRewardIdByStar(iNpcId, iStar)
    local iId = math.floor(iStar/3) + 1
    local mConfig = self:GetBossConfig()
    local mNpcConfig = mConfig[iNpcId]
    local iRewardId = mNpcConfig["reward_"..iId]
    return iRewardId
end

function CHuodong:SendRewardContent(oPlayer, mRewardContent, mArgs)
    if mArgs and mArgs.is_boss then
        local bItemReward = self:CheckItemReward(oPlayer)
        if mRewardContent["items"] then
            if bItemReward then
                oPlayer.m_oTodayMorning:Add("luanshimoying_item_cnt", 1)
            else
                mRewardContent["items"] = nil --有物品奖励，但超限制了，剔除
            end
        end
    end
    super(CHuodong).SendRewardContent(self, oPlayer, mRewardContent, mArgs)
end

function CHuodong:CheckItemReward(oPlayer)
    local oDay = oPlayer.m_oTodayMorning
    local iItemCnt = oDay:Query("luanshimoying_item_cnt", 0)
    local mConfig = self:GetConfig()
    local iLimitItem = mConfig.limit_item
    if iItemCnt >= iLimitItem then
        return false
    end
    return true
end

function CHuodong:PushDataToRank(oPlayer, iWeekScore)
    if iWeekScore <= 0 then return end
    local mData = {
        pid = oPlayer:GetPid(),
        name = oPlayer:GetName(),
        time = get_time(),
        score = iWeekScore,
        grade = oPlayer:GetGrade(),
    }
    global.oRankMgr:PushDataToRank("luanshimoying_score", mData)
end

function CHuodong:OnWarFail(oWar, pid, npcobj, mArgs)
    super(CHuodong).OnWarFail(self, oWar, pid, npcobj, mArgs)
    local oPlayer = global.oWorldMgr:GetOnlinePlayerByPid(pid)
    if not oPlayer then return end
    local iScene = npcobj:GetScene()
    self:SayCurrentChannel(iScene, 2008, {role=oPlayer:GetName()})

    if not self:IsOpen() then
        self:RemoveBoss(npcobj) --如果战斗失败后，当天活动已结束，需要删除boss
    else
        if self.m_bDelayDisappearBigBoss then
            self:TryDisappearBigBoss()
        end
    end
end

function CHuodong:WarFightEnd(oWar, pid, npcobj, mArgs)
    super(CHuodong).WarFightEnd(self, oWar, pid, npcobj, mArgs)

    if self.m_bDelayRefresh then
        self:RefreshBigBoss()
    end
end

function CHuodong:do_look(oPlayer, oNpc)
    if not oNpc.boss_type then
        super(CHuodong).do_look(self, oPlayer, oNpc)
        return
    end

    local sExtText = oNpc:InWar() and "Q我要观战" or "Q我要挑战"
    local iPid = oPlayer:GetPid()
    local func = function (oPlayer,mData)
        self:Respond(iPid, oNpc, mData["answer"])
    end
    local iNpcId = oNpc:NpcID()
    local sText = self:GetTextData(iNpcId)
    sText = sText .. sExtText
    self:SayText(iPid, oNpc, sText, func)
end

function CHuodong:Respond(iPid, oBoss, iAnswer)
    if iAnswer ~= 1 then return end
    
    local oPlayer = global.oWorldMgr:GetOnlinePlayerByPid(iPid)
    if not oPlayer then return end

    local oWar = oBoss:InWar()
    if oWar then
        local iWarId = oWar:GetWarId()
        local mArgs = {camp_flag = 1, npc_id = oBoss:NpcID()}
        if oPlayer:IsSingle() then
            global.oWarMgr:ObserverEnterWar(oPlayer, iWarId, mArgs)
        else
            global.oWarMgr:TeamObserverEnterWar(oPlayer, iWarId, mArgs)
        end
    else
        self:FightBoss(iPid, oBoss)
    end
end

function CHuodong:FightBoss(iPid, oBoss)
    if not oBoss then return end
    if not self:ValidBossFight(iPid) then return end

    local iNpcId = oBoss:NpcID()
    local iStar = oBoss.boss_star
    local iFight = (iNpcId % 1000) * 1000 + iStar
    self:SingleFight(iPid, oBoss, iFight)

    --成长
    local oPlayer = global.oWorldMgr:GetOnlinePlayerByPid(iPid)
    local oTeam = oPlayer:HasTeam()
    local lMember = oTeam:GetTeamMember()
    for _, iMemPid in pairs(lMember or {}) do
        local oMem = oTeam:GetMember(iMemPid)
        if oMem then
            local oTarget = global.oWorldMgr:GetOnlinePlayerByPid(oMem.m_ID)
            if oTarget then
                oTarget:MarkGrow(55)
            end
        end
    end
end

function CHuodong:ValidBossFight(iPid)
    local oPlayer = global.oWorldMgr:GetOnlinePlayerByPid(iPid)
    if not oPlayer then 
        return false
    end

    local oTeam = oPlayer:HasTeam()
    if not oTeam or oTeam:TeamSize() < 5 then
        self:TeamNotify(iPid, 2001)
        return false
    end

    if oTeam:MemberSize() < oTeam:TeamSize() then
        local lName = {}
        for _,oMem in pairs(oTeam.m_mShortLeave) do
            table.insert(lName, oMem.m_sName)
        end
        for _,oMem in pairs(oTeam.m_mOffline) do
            table.insert(lName, oMem.m_sName)
        end
        self:TeamNotify(iPid, 2009, {role = table.concat(lName, ",")})
        return false
    end

    local iOpenLevel = global.oToolMgr:GetSysOpenPlayerGrade("LUANSHIMOYING")
    local lName = oTeam:FilterTeamMember(function(oMember)
        local iMem = oMember.m_ID
        local oTarget = global.oWorldMgr:GetOnlinePlayerByPid(iMem)
        if oTarget and not global.oToolMgr:IsSysOpen("LUANSHIMOYING", oTarget, true) then
            return oTarget:GetName()
        end
    end)
    if next(lName) then
        self:TeamNotify(iPid, 2002, {role=table.concat(lName, "、")})
        return false
    end

    return true
end

function CHuodong:TeamNotify(iPid, iChat, mReplace)
    local oPlayer = global.oWorldMgr:GetOnlinePlayerByPid(iPid)
    if not oPlayer then return end

    local sMsg = self:GetTextData(iChat)
    if mReplace then
        sMsg = global.oToolMgr:FormatColorString(sMsg, mReplace)
    end
    if oPlayer:IsTeamLeader() then
        local oTeam = oPlayer:HasTeam()
        oTeam:TeamNotify(sMsg)
    else
        global.oNotifyMgr:Notify(oPlayer:GetPid(), sMsg)
    end
end

function CHuodong:SayCurrentChannel(iScene, iChat, mReplace)
    local oSceneMgr = global.oSceneMgr
    local oScene = oSceneMgr:GetScene(iScene)
    if oScene then
        local sMsg = self:GetTextData(iChat)
        if mReplace then
            sMsg = global.oToolMgr:FormatColorString(sMsg, mReplace)
        end
        global.oChatMgr:SendMsg2Scene(nil, oScene, sMsg, gamedefines.CHANNEL_TYPE.CURRENT_TYPE)
    end
end

function CHuodong:GetRewardEnv(oAwardee)
    local mEnv = super(CHuodong).GetRewardEnv(self, oAwardee)
    mEnv.star = 1
    if oAwardee.GetPid then
        local iPid = oAwardee:GetPid()
        mEnv.star = self.m_mTmpStar[iPid] or 1
    end
    return mEnv
end

function CHuodong:MonsterCreateExt(oWar, iMonsterIdx, oBoss)
    local result = {}
    if oBoss then
        local iStar = oBoss.boss_star or 1
        result = {
            env = { star = iStar }
        }
    end
    return result
end

function CHuodong:SetHuodongState(iState)
    local mConfig = self:GetConfig()
    local sStartTime = mConfig.start_time
    global.oHuodongMgr:SetHuodongState(self.m_sName, 1038, iState, sStartTime)
end

function CHuodong:LogBoss(iBossType, iNpcId, iStar, iScene)
    local mInfo = {
        boss_type = iBossType,
        npc_id = iNpcId,
        star = iStar,
        scene = iScene,
    }
    record.log_db("huodong", "luanshimoying_boss", mInfo)
end

function CHuodong:LogBox(iScene, iStar, iNum)
    local mInfo = {
        scene = iScene,
        star = iStar,
        num = iNum,
    }
    record.log_db("huodong", "luanshimoying_box", mInfo)
end

function CHuodong:GetConfig()
    local mData = res["daobiao"]["huodong"][self.m_sName]["config"][1]
    assert(mData, "luanshimoying not find config")
    return mData
end

function CHuodong:GetBossConfig()
    local mData = res["daobiao"]["huodong"][self.m_sName]["boss_config"]
    assert(mData, "luanshimoying not find boss_config")
    return mData
end

function CHuodong:GetScoreConfig()
    local mData = res["daobiao"]["huodong"][self.m_sName]["score_config"]
    assert(mData, "luanshimoying not find score_config")
    return mData
end

function CHuodong:GetFightMonsterGroup(iGroup)
    local mData = res["daobiao"]["fight"][self.m_sName]["group"][iGroup]
    assert(mData, string.format("luanshimoying not find fight group : %d", iGroup))
    return mData
end

function CHuodong:TestOp(iFlag, mArgs)
    local oChatMgr = global.oChatMgr
    local iPid = mArgs[#mArgs]
    local oPlayer = global.oWorldMgr:GetOnlinePlayerByPid(iPid)
    if iFlag == 100 then
        local sMsg = [[
        101 - 刷新大BOSS huodongop luanshimoying 101
        102 - 设置n秒后大BOSS消失 huodongop luanshimoying 102 {sec=10}
        103 - 显示所有boss坐标 huodongop luanshimoying 103
        104 - 寻路到boss huodongop luanshimoying 104
        105 - 寻路到宝箱 huodongop luanshimoying 105
        106 - 强制开启 huodongop luanshimoying 106
        107 - 强制关闭 huodongop luanshimoying 107
        109 - 当前场景刷宝箱 huodongop luanshimoying 109
        ]]
        oChatMgr:HandleMsgChat(oPlayer, sMsg)
        global.oNotifyMgr:Notify(iPid, "请查看消息窗口")
    elseif iFlag == 101 then
        self:DelTimeCb("GameRefreshBigBoss")
        if not self:IsOpen() then
            self:DelTimeCb("GameTimeStart")
            self:StartToday()
        else
            self:RefreshBigBoss()
        end
    elseif iFlag == 102 then
        local mConfig = self:GetConfig()
        local iTime = mArgs.sec or 10
        self:DelTimeCb("GameBigBossDisappear")
        self:AddTimeCb("GameBigBossDisappear", iTime * 1000, function()
            if self:IsOpen() then 
                self:TryDisappearBigBoss()
            end
        end)
        local sMsg = string.format("%s秒后大BOSS消失", iTime)
        global.oNotifyMgr:Notify(iPid, sMsg)
    elseif iFlag == 103 then
        oChatMgr:HandleMsgChat(oPlayer, "-------------------------------")
        for _, mTypeBoss in pairs(self.m_mBoss) do
            for _, oBoss in pairs(mTypeBoss) do
                local pos = oBoss.m_mPosInfo
                local iScene = oBoss:GetScene()
                local sSceneName = global.oSceneMgr:GetScene(iScene):GetName()
                local msg = string.format("map = %s,  x = %s, y = %s", sSceneName, pos.x, pos.y)
                oChatMgr:HandleMsgChat(oPlayer, msg)
            end
        end
        global.oNotifyMgr:Notify(iPid, "请查看消息窗口")
    elseif iFlag == 104 then
        self:FindPathToBoss(oPlayer)
    elseif iFlag == 105 then
        self:FindPathToBox(oPlayer)
    elseif iFlag == 106 then
        if not self:IsOpen() then
            self:DelTimeCb("GameTimeStart")
            self:StartToday()
        end
    elseif iFlag == 107 then
        if self:IsOpen() then
            self:DelTimeCb("GameTimeEnd")
            self:EndToday()
        end
    elseif iFlag == 109 then
        local oScene = oPlayer.m_oActiveCtrl:GetNowScene()
        local iScene = oScene:GetSceneId()
        self:RefreshBox(iScene)
    end
end
