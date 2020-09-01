local global = require "global"
local res = require "base.res"
local interactive = require "base.interactive"
local record = require "public.record"
local extend = require "base.extend"
local gamedefines = import(lualib_path("public.gamedefines"))
local huodongbase = import(service_path("huodong.huodongbase"))

-----------TODO list------------
--1.内存泄露
--------------------------------

function NewHuodong(sHuodongName)
    return CHuodong:New(sHuodongName)
end

CHuodong = {}
CHuodong.__index = CHuodong
CHuodong.m_sTempName = "二十八星宿"
inherit(CHuodong, huodongbase.CHuodong)


function CHuodong:Init()
    self.m_iScheduleID = 1029
    --self.m_iStartTime = self:GetNextStartTime()
    self:TryStartRewardMonitor()
    --self:SetHuodongState(gamedefines.ACTIVITY_STATE.STATE_READY)
end

function CHuodong:NewDay(mNow)
    self:TryStopRewardMonitor()
end

function CHuodong:NewHour(mNow)
    if not global.oToolMgr:IsSysOpen("XINGXIU") then
        return
    end
    --self.m_iStartTime = mNow.time
    --self:SetHuodongState(gamedefines.ACTIVITY_STATE.STATE_START)
    self:RefreshMonster()

    local mConfig = self:GetConfig()
    self:DelTimeCb("RemoveMonster")
    self:AddTimeCb("RemoveMonster", mConfig.timeout*60*1000, function()
        self:RemoveMonster()
    end)
end

function CHuodong:RefreshMonster()
    local mConfig = self:GetConfig()
    local lMapPool = mConfig.map_pool
    local iNum = mConfig.map_num
    local lMapList = extend.Random.random_size(lMapPool, iNum)
    local lNpcList = table_key_list(self:GetNpcList())
    local mMapName = {}

    local iCount = 0
    for _, iNpcIdx in ipairs(lNpcList) do
        if math.floor(iNpcIdx / 1000) == 2 then
            goto continue
        end
        local iMap = extend.Random.random_choice(lMapList)
        local lScene = global.oSceneMgr:GetSceneListByMap(iMap)
        local oScene = extend.Random.random_choice(lScene)
        mMapName[oScene:GetName()] = 1
        self:InsertXingxiu(iNpcIdx, oScene)

        iCount = iCount + 1
        if iCount >= mConfig.npc_num then
            break
        end
        ::continue::
    end

    local iRet = mConfig.npc_num - iCount
    if iRet > 0 then
        for i = 1, iRet do
            local iMap = extend.Random.random_choice(lMapList)
            local lScene = global.oSceneMgr:GetSceneListByMap(iMap)
            local oScene = extend.Random.random_choice(lScene)
            mMapName[oScene:GetName()] = 1
            local iNpcIdx = extend.Random.random_choice(lNpcList)
            if math.random(100) <= 20 then
                iNpcIdx = math.floor(iNpcIdx % 10 + 2000)
            else
                iNpcIdx = math.floor(iNpcIdx % 10 + 1000)
            end
            self:InsertXingxiu(iNpcIdx, oScene)
        end
    end

    local lMapName = table_key_list(mMapName)
    self:SysAnnounce(1075, {submitscene=table.concat(lMapName, "、")})
end

function CHuodong:InsertXingxiu(iNpcIdx, oScene)
    local iX, iY = global.oSceneMgr:RandomPos2(oScene:MapId())
    local oNpc = self:CreateTempNpc(iNpcIdx)
    oNpc.m_mPosInfo.x = iX
    oNpc.m_mPosInfo.y = iY
    self:Npc_Enter_Scene(oNpc, oScene:GetSceneId())
end

function CHuodong:RemoveMonster()
    self:DelTimeCb("RemoveMonster")
    --self.m_iStartTime = self:GetNextStartTime()
    --self:SetHuodongState(gamedefines.ACTIVITY_STATE.STATE_END)

    local lRemove = {}
    for iNpc, oNpc in pairs(self.m_mNpcList) do
        if not oNpc:InWar() then
            table.insert(lRemove, oNpc)
        else
            oNpc.m_iNeedRemove = 1
        end
    end
    for _, oNpc in ipairs(lRemove) do
        self:RemoveTempNpc(oNpc)
    end
end

function CHuodong:WarFightEnd(oWar, iPid, oNpc, mArgs)
    if oNpc then
        oNpc:SetEvent(1001)
    end
    local iWinSide = mArgs.win_side
    if iWinSide == 1 or (oNpc and oNpc.m_iNeedRemove) then 
        self:RemoveTempNpc(oNpc)
    end
    super(CHuodong).WarFightEnd(self, oWar, iPid, oNpc, mArgs)
end

function CHuodong:OnWarWin(oWar, iPid, oNpc, mArgs)
    local oWorldMgr = global.oWorldMgr
    local oPlayer = oWorldMgr:GetOnlinePlayerByPid(iPid)
    if not oPlayer then return end

    local iWarIdx = oWar.m_iIdx
    local iReward = 1001
    mArgs.npc = oNpc:Name()
    if iWarIdx//1000 == 2 then
        iReward = 1002
    end

    local lPlayers = self:GetFighterList(oPlayer, mArgs)
    for _, iTarget in ipairs(lPlayers) do
        local oTarget = oWorldMgr:GetOnlinePlayerByPid(iTarget)
        if oTarget and not oTarget.m_oScheduleCtrl:IsFullTimes(self.m_iScheduleID) then
            self:Reward(iTarget, iReward, mArgs)
            self:AddSchedule(oTarget)
            oTarget:MarkGrow(42)
            if oTarget.m_oScheduleCtrl:IsFullTimes(self.m_iScheduleID) then
                local iCnt = oTarget.m_oScheduleCtrl:GetDoneTimes(self.m_iScheduleID)
                self:Notify(iTarget, 1010, {count = iCnt})
            end
        end
    end

    local oMentoring = global.oMentoring
    safe_call(oMentoring.AddTaskCnt, oMentoring, oPlayer, 3, 1, "师徒星宿")
end

function CHuodong:SayText(pid,npcobj,sText,func,iTime,sCmd)
    if npcobj then
        local mReplace = {monster=npcobj:Name()}
        sText = global.oToolMgr:FormatString(sText, mReplace)
    end
    super(CHuodong).SayText(self, pid, npcobj, sText, func, iTime, sCmd)
end

function CHuodong:OtherScript(iPid, oNpc, s, mArgs)
    if s == "$fight" then
        self:TryStartFight(iPid, oNpc, mArgs)
        return true
    elseif s == "$observer" then
        self:StartObserver(iPid, oNpc)
        return true
    end
    return super(CHuodong).OtherScript(self, iPid, oNpc, s, mArgs)
end

function CHuodong:TryStartFight(iPid, oNpc, mArgs)
    local oPlayer = global.oWorldMgr:GetOnlinePlayerByPid(iPid)
    if not global.oToolMgr:IsSysOpen("XINGXIU", oPlayer) then
        return
    end

    mArgs = mArgs or {}
    local iRet, mReplace = self:ValidStartFight(iPid, oNpc, mArgs)
    if iRet ~= 1 then
        self:Notify(iPid, iRet, mReplace)
        return
    end

    local iNpc = oNpc:ID()
    if oPlayer:GetTeamSize() < 5 and not mArgs.ignore_max_size then
        local func = function(oPlayer, mData)
            local oNpc = self:GetNpcObj(iNpc)
            if mData.answer ~= 1 or not oNpc then
                return
            end
            mArgs.ignore_max_size = true
            self:TryStartFight(iPid, oNpc, mArgs)
        end
        local mData = self:GetTextData(1006)
        local mReplace = {npc = oNpc:Name()}
        mData.sContent = global.oToolMgr:FormatColorString(mData.sContent, mReplace)
        global.oCbMgr:SetCallBack(iPid, "GS2CConfirmUI", mData, nil, func)
        return
    end

    local iFight = self:GetFightByIdx(oNpc:Type())
    self:SingleFight(iPid, oNpc, iFight)
    oNpc:SetEvent(1002)
   
    local oTeam = oPlayer:HasTeam() 
    local iSchedule = self.m_iScheduleID
    local lName = oTeam:FilterTeamMember(function(oMember)
        local oTarget = global.oWorldMgr:GetOnlinePlayerByPid(oMember.m_ID)
        if oTarget and oTarget.m_oScheduleCtrl:IsFullTimes(iSchedule) then
            self:Notify(oTarget:GetPid(), 1009)
        end
    end)
end

function CHuodong:ValidStartFight(iPid, oNpc, mArgs)
    local oPlayer = global.oWorldMgr:GetOnlinePlayerByPid(iPid)
    if not oPlayer:IsTeamLeader() then
        return 1002
    end
    if oPlayer:GetTeamSize() < 3 then
        return 1003
    end
    local oTeam = oPlayer:HasTeam()
    local lName = oTeam:FilterTeamMember(function(oMember)
        local oTarget = global.oWorldMgr:GetOnlinePlayerByPid(oMember.m_ID)
        local iOpenLevel = global.oToolMgr:GetSysOpenPlayerGrade("XINGXIU")
        if oTarget:GetGrade() < iOpenLevel then
            return oTarget:GetName()
        end
    end)
    if next(lName) then
        return 1004, {name=table.concat(lName, "、")}
    end

    if oNpc and oNpc:InWar() then
        return 1007
    end

    return 1
end

function CHuodong:StartObserver(iPid, oNpc)
    if not oNpc or not oNpc:InWar() then
        return
    end
    local oPlayer = global.oWorldMgr:GetOnlinePlayerByPid(iPid)
    if not oPlayer then return end

    if oPlayer:HasTeam() and not oPlayer:IsTeamLeader() and not oPlayer:IsSingle() then
        global.oNotifyMgr:Notify(oPlayer:GetPid(), "请暂离队伍后再进行观战")
        return
    end
    if oPlayer.m_oActiveCtrl:GetNowWar() then
        global.oNotifyMgr:Notify(oPlayer:GetPid(), "请结束战斗后再进行观战")
        return
    end

    local oWar = oNpc:InWar()
    local mArgs = {npc_id = oNpc:ID()}
    if oPlayer:IsSingle() then
        global.oWarMgr:ObserverEnterWar(oPlayer, oWar:GetWarId(), mArgs)
    else
        global.oWarMgr:TeamObserverEnterWar(oPlayer, oWar:GetWarId(), mArgs)
    end
end

function CHuodong:PackMonster(oMonster)
    local mRet = super(CHuodong).PackMonster(self, oMonster)
    mRet.all_monster = oMonster.m_mAllMonster
    return mRet
end

function CHuodong:OnMonsterCreate(oWar, oMonster, mData, npcobj)
    local mResult = {}
    local mConfig = self:GetConfig()
    local mAllMonster = res["daobiao"]["fight"][self.m_sName]["monster"]
    local lMonsterList = mConfig["monster_list1"]
    if math.floor(oWar.m_iIdx / 1000) == 2 then     --变异
        lMonsterList = mConfig["monster_list2"]
    end

    if not extend.Array.member(lMonsterList, oMonster:Type()) then
        for _, iMonster in pairs(lMonsterList) do
            local oMonster = self:CreateMonster(oWar, iMonster, npcobj)
            mResult[iMonster] = oMonster:PackAttr()
        end
        oMonster.m_mAllMonster = mResult
    end
    super(CHuodong).OnMonsterCreate(self, oWar, oMonster, mData, npcobj)
end

function CHuodong:SetHuodongState(iState)
    local sTime = self:GetStartTime()
    global.oHuodongMgr:SetHuodongState(self.m_sName, self.m_iScheduleID, iState, sTime)
end

function CHuodong:GetStartTime()
    return get_time_format_str(self.m_iStartTime, "%H:%M")
end

function CHuodong:GetNextStartTime()
    local iCurTime = get_time()
    local iTime = iCurTime + 1 * 3600
    local date = os.date("*t",iTime)
    iTime = os.time({year=date.year,month=date.month,day=date.day,hour=date.hour,min=0,sec=0})
    return iTime
end

function CHuodong:GetConfig()
    return res["daobiao"]["huodong"][self.m_sName]["config"][1]
end

function CHuodong:GetNpcList()
    return res["daobiao"]["huodong"][self.m_sName]["npc"]
end

function CHuodong:GetFightByIdx(iNpcIdx)
    return res["daobiao"]["huodong"][self.m_sName]["fight_config"][iNpcIdx]
end

function CHuodong:GetNpcInWarText(npcobj)
    local sText = self:GetTextData(1008)
    sText = global.oToolMgr:FormatColorString(sText, {name = npcobj:Name()})
    return sText
end

function CHuodong:TestOp(iFlag, mArgs)
    local iPid = mArgs[#mArgs]
    local oMaster = global.oWorldMgr:GetOnlinePlayerByPid(iPid)
    if iFlag == 100 then
        global.oNotifyMgr:Notify(iPid, [[
        101 - 刷怪
        102 - 清怪
        103 - 清空奖励限制
        104 - 刷时 
        ]])
    elseif iFlag == 101 then
        self:RefreshMonster()
    elseif iFlag == 102 then
        self:RemoveMonster()
    elseif iFlag == 103 then
        self:NewDay(get_daytime({}))
    elseif iFlag == 104 then
        self:NewHour(get_hourtime({hour=0}))
    end
end
