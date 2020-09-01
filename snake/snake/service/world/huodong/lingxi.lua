local global = require "global"
local extend = require "base.extend"
local res = require "base.res"
local record = require "public.record"
local gamedefines = import(lualib_path("public.gamedefines"))
local taskdefines = import(service_path("task.taskdefines"))
local loadschedule = import(service_path("schedule.loadschedule"))
local handleteam = import(service_path("team.handleteam"))
local huodongbase = import(service_path("huodong.huodongbase"))

-- local LINGXI_TASK_ID = 62031
local MAX_MATCH_PER_TICK = 100

local CHECK_TYPE = {
    ACC_TASK = 1,
    USE_FLOWER = 2.
}

local ERR = {
    NO_TEAM = 1,
    NOT_LEADER = 2,
    NOT_TWO = 3,
    NOT_ALL_TOGETHER = 4,
    MEMBNER_NOT_ONLINE = 5,
    HOMOSEXUAL = 6,
    HAS_THE_TASK = 7,
    NOT_FRIEND = 8,
    SCHEDULE_FULL = 9,
    MEMBER_GRADE_FAIL = 10,
}

local mErr2MsgNo = {
    [ERR.NO_TEAM] = {1001, 1011},
    [ERR.NOT_LEADER] = {1002, 1012},
    [ERR.NOT_TWO] = {1003, 1013},
    [ERR.NOT_ALL_TOGETHER] = {1004, 1014},
    [ERR.MEMBNER_NOT_ONLINE] = {1005, 1015},
    [ERR.HOMOSEXUAL] = {1006, 1016},
    [ERR.HAS_THE_TASK] = {1007,},
    [ERR.NOT_FRIEND] = {1008, 1018},
    [ERR.SCHEDULE_FULL] = {1009,},
    [ERR.MEMBER_GRADE_FAIL] = {1019,},
}

function NewHuodong(sHuodongName)
    return CHuodong:New(sHuodongName)
end

function GetHuodongConfig(sKey)
    return table_get_depth(res, {"daobiao", "huodong", "lingxi", "global_config", sKey})
end

function GetText(iText)
    local xMsg = global.oToolMgr:GetTextData(iText, {"huodong", "lingxi"})
    return xMsg
end

function GetTextFormated(iText, mReplace)
    local sMsg = GetText(iText)
    return global.oToolMgr:FormatColorString(sMsg, mReplace)
end

------------------------------
CHuodong = {}
CHuodong.__index = CHuodong
CHuodong.m_sTempName = "灵犀"
inherit(CHuodong, huodongbase.CHuodong)

function CHuodong:New(sHuodongName)
    local o = super(CHuodong).New(self, sHuodongName)
    o.m_iScheduleID = 1022
    o.m_iStartTime = 0
    o.m_iEndTime = 0
    o.m_mFlowerRewarding = {}
    o.m_mMatchTeamPool = {} -- 组队匹配池
    return o
end

function CHuodong:Init()
    super(CHuodong).Init(self)
    self:RegisterEvents()
end

function CHuodong:TestOp(sCmd, mArgs)
    local oNotifyMgr = global.oNotifyMgr
    local pid = table.remove(mArgs)
    local oWorldMgr = global.oWorldMgr
    local oPlayer = oWorldMgr:GetOnlinePlayerByPid(pid)
    if sCmd == "pate" then
        self:Paticipate(oPlayer)
    elseif sCmd == "sche" then
        local iAddCnt = mArgs.add
        if iAddCnt then
            local iDoneCnt = oPlayer.m_oWeekMorning:Query("lingxi_donecnt", 0)
            oPlayer.m_oWeekMorning:Set("lingxi_donecnt", iDoneCnt + iAddCnt)
            oPlayer.m_oScheduleCtrl:RefreshMaxTimes(self.m_iScheduleID)
            -- for i = 1, iAddCnt do
            --     oPlayer.m_oScheduleCtrl:AddByName("lingxi")
            -- end
        end
        if mArgs.get then
            local iScheduleId = loadschedule.GetScheduleIdByName("lingxi")
            local iDoneTimes = oPlayer.m_oScheduleCtrl:GetDoneTimes(iScheduleId)
            oPlayer:NotifyMessage("完成次数：" .. iDoneTimes)
        end
        if mArgs.full then
            local iScheduleId = loadschedule.GetScheduleIdByName("lingxi")
            local bRet = oPlayer.m_oScheduleCtrl:IsFullTimes(iScheduleId)
            oPlayer:NotifyMessage(string.format("是否满次数：%s", bRet))
        end
    elseif sCmd == "qte" then
        local sQteName = mArgs.type
        local oTask = global.oTaskMgr:GetUserTask(oPlayer, 62031)
        local mMemberPids = {[pid] = 1}
        if not oTask then
            local oTeam = oPlayer:HasTeam()
            if not oTeam then
                global.oTeamMgr:CreateTeam(oPlayer:GetPid())
            end
            local oTeam = oPlayer:HasTeam()
            if oTeam and not oTeam:IsLeader(oPlayer:GetPid()) then
                oPlayer:NotifyMessage("队长才能执行")
                return
            end
            if oTeam:TeamSize() ~= 2 then
                oPlayer:NotifyMessage("队伍要正好2人")
                return
            end
            for iMemId, _ in pairs(oTeam.m_mShortLeave) do
                mMemberPids[iMemId] = 1
                oTeam:BackTeam(global.oWorldMgr:GetOnlinePlayerByPid(iMemId))
            end
            self:DoGiveTaskToTeam(oPlayer)
        end
        oTask = global.oTaskMgr:GetUserTask(oPlayer, 62031)
        if not oTask then
            return
        end
        local oTeam = oTask:GetTeamObj()
        local mMems = oTeam:AllMember()
        local mItemInfo = oTask.m_mSeedInfo
        local oFlower = self.m_oFlowerNpc
        if not mItemInfo and not oFlower then
            oPlayer:NotifyMessage("没有指定地点")
            return
        end
        local iMap, iX, iY
        if mItemInfo then
            iMap, iX, iY = mItemInfo.map_id, mItemInfo.pos_x, mItemInfo.pos_y
        else
            iMap, iX, iY = oFlower:MapId(), oFlower:GetPos().x, oFlower:GetPos().y
        end
        local oScene = global.oSceneMgr:SelectDurableScene(iMap)
        local mPos = {x = iX, y = iY}
        global.oSceneMgr:DoTransfer(oPlayer, oScene:GetSceneId(), mPos)
        oTask.m_tmp_lingxi_qte_name = sQteName
        if mItemInfo then
            oTask:OnUseSeedEnd(oPlayer, iX, iY)
            for iMem, _ in pairs(mMemberPids) do
                oTask:OnCloseToFlower(global.oWorldMgr:GetOnlinePlayerByPid(iMem))
            end
        end
    elseif sCmd == "phasego" then
        local oTask = global.oTaskMgr:GetUserTask(oPlayer, 62031)
        if not oTask then
            oPlayer:NotifyMessage("没任务")
            return
        end
        local iPhase = oTask:GetData("phase", 0)
        if mArgs.show then
            oPlayer:NotifyMessage("当前阶段：" .. iPhase)
            return
        end
        if iPhase == 1 then
            oTask:OnCloseToGrowPos(oPlayer)
        elseif iPhase == 2 then
            oTask:OnCloseToGrowPos(oPlayer)
        elseif iPhase == 4 then
            oTask:OnCloseToFlower(oPlayer)
            if mArgs.done then
                oTask:GrowDone(true)
            end
        end
    end
end

function CHuodong:Paticipate(oPlayer)
    -- 寻路去策划配置npc坐标
    local iNpctype = GetHuodongConfig("start_npctype")
    local oGlobalNpc = global.oNpcMgr:GetGlobalNpc(iNpctype)
    if not oGlobalNpc then
        return
    end
    local iNpcid = oGlobalNpc:ID()
    local iMapId = oGlobalNpc:MapId()
    local iX = oGlobalNpc.m_mPosInfo["x"]
    local iY = oGlobalNpc.m_mPosInfo["y"]
    global.oSceneMgr:SceneAutoFindPath(oPlayer:GetPid(), iMapId, iX, iY, iNpcid, 1)
end

-- TODO 事件注册调整，提高精准注册
function CHuodong:RegisterEvents()
    global.oTeamMgr:AddEvent(self, gamedefines.EVENT.TEAM_CREATE, function(iEvType, mData)
        local oHuodong = global.oHuodongMgr:GetHuodong("lingxi")
        oHuodong:OnEvTeamCreate(iEvType, mData)
    end)
    global.oTeamMgr:AddEvent(self, gamedefines.EVENT.TEAM_ADD_MEMBER, function(iEvType, mData)
        local oHuodong = global.oHuodongMgr:GetHuodong("lingxi")
        oHuodong:OnEvTeamEnter(iEvType, mData)
    end)
    global.oTeamMgr:AddEvent(self, gamedefines.EVENT.TEAM_ADD_SHORT_LEAVE, function(iEvType, mData)
        local oHuodong = global.oHuodongMgr:GetHuodong("lingxi")
        oHuodong:OnEvTeamEnter(iEvType, mData)
    end)
end

function CHuodong:StopMatch(oPlayer)
    self:RemoveFromMatchTeamPool(oPlayer)
end

function CHuodong:RemoveFromMatchTeamPool(oPlayer)
    local iPid = oPlayer:GetPid()
    if not self.m_mMatchTeamPool[iPid] then
        return
    end
    self.m_mMatchTeamPool[iPid] = nil
    oPlayer:Send("GS2CLingxiMatchEnd", {succ = 0})
end

function CHuodong:IsMatching(iPid)
    return self.m_mMatchTeamPool[iPid]
end

function CHuodong:OnEvTeamCreate(iEvType, mData)
    local oPlayer = mData.player
    self:RemoveFromMatchTeamPool(oPlayer)
end

function CHuodong:OnEvTeamEnter(iEvType, mData)
    local oPlayer = mData.player
    self:RemoveFromMatchTeamPool(oPlayer)
end

function CHuodong:QuickTeamup(oPlayer)
    -- 维护一个快捷组队池，筛选加入的角色性别，随机匹配异性组队
    -- 监听离线与组队事件踢出组队池
    if not global.oToolMgr:IsSysOpen("LINGXI", oPlayer) then
        return
    end
    local oTeam = oPlayer:HasTeam()
    if oTeam then
        oPlayer:NotifyMessage(GetText(1101))
        return
    end
    -- if oTeam and oTeam:AutoMatching() then
    --     oPlayer:NotifyMessage("你正在其他玩法匹配中")
    --     return
    -- end
    local bAutoMatching = oPlayer.m_oActiveCtrl:GetInfo("auto_matching", false)
    if bAutoMatching then
        -- oPlayer:NotifyMessage("你正在其他玩法匹配中")
        -- return
        -- 打断组队匹配
        handleteam.TeamCancelAutoMatch(oPlayer)
    end
    local iPid = oPlayer:GetPid()
    if self.m_mMatchTeamPool[iPid] then
        oPlayer:NotifyMessage(GetText(1102))
        return
    end
    self:InjectMatchTeamPool(oPlayer)
end

function CHuodong:ReSyncMatching(oPlayer)
    local iPid = oPlayer:GetPid()
    local mInfo = self.m_mMatchTeamPool[iPid]
    if mInfo then
        local iRestSec = mInfo.timeout - get_time()
        if iRestSec > 0 then
            oPlayer:Send("GS2CLingxiMatching", {rest_sec = iRestSec})
        else
            self:RemoveFromMatchTeamPool(oPlayer)
        end
    end
end

function CHuodong:InjectMatchTeamPool(oPlayer, bAutoGoOn)
    local iPid = oPlayer:GetPid()
    if not next(self.m_mMatchTeamPool) then
        self:SetQuickTeamupTick()
    end
    local iRestSec = GetHuodongConfig("teamup_timeout")
    self.m_mMatchTeamPool[iPid] = {
        timeout = get_time() + iRestSec,
        auto_go_on = bAutoGoOn,
    }
    oPlayer:Send("GS2CLingxiMatching", {rest_sec = iRestSec})
    oPlayer:NotifyMessage(global.oToolMgr:FormatColorString(GetText(1114), {time = iRestSec}))
end

function CHuodong:SetQuickTeamupTick()
    self:DelTimeCb("quick_teamup")
    self:AddTimeCb("quick_teamup", 3 * 1000, function()
        _TickQuickTeamup()
    end)
end

function _TickQuickTeamup()
    local oHuodong = global.oHuodongMgr:GetHuodong("lingxi")
    oHuodong:TickQuickTeamup()
end

function CHuodong:TickQuickTeamup()
    local lMales = {}
    local lFemales = {}
    local lDels = {}
    local mAutoGoOn = {}
    local mBackInfo = {}
    local iNow = get_time()
    for iPid, mInfo in pairs(self.m_mMatchTeamPool) do
        local iTimeout = mInfo.timeout
        local oPlayer = global.oWorldMgr:GetOnlinePlayerByPid(iPid)
        if oPlayer then
            if iTimeout <= iNow then
                table.insert(lDels, iPid)
                oPlayer:Send("GS2CLingxiMatchEnd", {succ = 0})
                oPlayer:NotifyMessage(GetText(1115))
            else
                if oPlayer:GetSex() == gamedefines.SEX_TYPE.SEX_MALE then
                    table.insert(lMales, iPid)
                else
                    table.insert(lFemales, iPid)
                end
                mBackInfo[iPid] = mInfo
            end
        else
            table.insert(lDels, iPid)
        end
    end
    for _, iPid in ipairs(lDels) do
        self.m_mMatchTeamPool[iPid] = nil
    end
    -- local lMales = extend.Table.randomfiltermap(self.m_mMatchTeamPool, 100, function(pid)
    --     local oPlayer = global.oWorldMgr:GetOnlinePlayerByPid(pid)
    --     if oPlayer then
    --         return oPlayer:GetSex() == gamedefines.SEX_TYPE.SEX_MALE
    --     end
    -- end)
    -- local lFemales = extend.Table.randomfiltermap(self.m_mMatchTeamPool, 100, function(pid)
    --     local oPlayer = global.oWorldMgr:GetOnlinePlayerByPid(pid)
    --     if oPlayer then
    --         return oPlayer:GetSex() == gamedefines.SEX_TYPE.SEX_FEMALE
    --     end
    -- end)
    local iMaxMatch = math.min(#lMales, #lFemales)
    iMaxMatch = math.min(iMaxMatch, MAX_MATCH_PER_TICK)
    for idx = 1, iMaxMatch do
        local iMalePid = lMales[idx]
        local iFemalePid = lFemales[idx]
        local iLeader, iMember
        if math.random(2) <= 1 then
            iLeader, iMember = iMalePid, iFemalePid
        else
            iLeader, iMember = iFemalePid, iMalePid
        end
        local oLeader = global.oWorldMgr:GetOnlinePlayerByPid(iLeader)
        local oMember = global.oWorldMgr:GetOnlinePlayerByPid(iMember)
        global.oTeamMgr:CreateTeam(iLeader)
        local oTeam = oLeader:HasTeam()
        if oTeam then
            global.oTeamMgr:DoAddTeam(oTeam, oMember)
            local mLeaderMatchInfo = mBackInfo[iLeader]
            if mLeaderMatchInfo and mLeaderMatchInfo.auto_go_on then
                mAutoGoOn[iLeader] = 1
            end
            self.m_mMatchTeamPool[iLeader] = nil
            self.m_mMatchTeamPool[iMember] = nil
            oLeader:Send("GS2CLingxiMatchEnd", {succ = 1})
            oMember:Send("GS2CLingxiMatchEnd", {succ = 1})
            local sMsg = GetText(1116)
            oLeader:NotifyMessage(sMsg)
            oMember:NotifyMessage(sMsg)
        end
    end
    if next(self.m_mMatchTeamPool) then
        self:SetQuickTeamupTick()
    end
    for iLeader, _ in pairs(mAutoGoOn) do
        local oLeader = global.oWorldMgr:GetOnlinePlayerByPid(iLeader)
        self:GiveTask(oLeader)
    end
end

-- return: bSucc, iErr
function CHuodong:ValidGiveTask(oPlayer)
    return self:ValidCouple(oPlayer, CHECK_TYPE.ACC_TASK)
end

function CHuodong:ValidCouple(oPlayer, iCheckType)
    local oTeam = oPlayer:HasTeam()
    if not oTeam then
        return false, ERR.NO_TEAM
    end
    local mAllMembers = oTeam:AllMember()
    if table_count(mAllMembers) ~= 2 then
        return false, ERR.NOT_TWO
    end
    local iPid = oPlayer:GetPid()
    if not oTeam:IsLeader(iPid) then
        return false, ERR.NOT_LEADER
    end
    if iCheckType == CHECK_TYPE.ACC_TASK then
        if oTeam:HasTaskKind(taskdefines.TASK_KIND.LINGXI) then
            return false, ERR.HAS_THE_TASK
        end
    end
    local lTogetherMembers = oTeam:GetTeamMember()
    if #lTogetherMembers ~= table_count(mAllMembers) then
        return false, ERR.NOT_ALL_TOGETHER
    end
    local iMemberPid
    for _, iMemId in ipairs(lTogetherMembers) do
        if iMemId ~= iPid then
            iMemberPid = iMemId
        end
    end
    local oMem = global.oWorldMgr:GetOnlinePlayerByPid(iMemberPid)
    if not oMem then
        return false, ERR.MEMBNER_NOT_ONLINE, oMem
    end
    if oMem:GetSex() == oPlayer:GetSex() then
        return false, ERR.HOMOSEXUAL, oMem
    end
    if iCheckType == CHECK_TYPE.ACC_TASK then
        if oMem:GetGrade() < global.oToolMgr:GetSysOpenPlayerGrade("LINGXI") then
            return false, ERR.MEMBER_GRADE_FAIL, oMem
        end
        local iScheduleId = loadschedule.GetScheduleIdByName("lingxi")
        if oPlayer.m_oScheduleCtrl:IsFullTimes(iScheduleId) then
            return false, ERR.SCHEDULE_FULL, oPlayer
        end
        if oMem.m_oScheduleCtrl:IsFullTimes(iScheduleId) then
            return false, ERR.SCHEDULE_FULL, oMem
        end
    end
    if not oMem:HasFriend(iPid) or not oPlayer:HasFriend(iMemberPid) then
        return false, ERR.NOT_FRIEND, oMem
    end
    return true
end

function CHuodong:GetErrMsg(iErr, iCheckType, oErrPlayer)
    local lTexts = mErr2MsgNo[iErr]
    if not lTexts then
        return
    end
    local iText = lTexts[iCheckType]
    if not iText then
        return
    end
    local sMsg
    if not oErrPlayer then
        sMsg = GetText(iText)
    else
        local sName = oErrPlayer:GetName()
        sMsg = GetTextFormated(iText, {role = sName})
    end
    return sMsg
end

function CHuodong:GiveTask(oPlayer)
    if not global.oToolMgr:IsSysOpen("LINGXI", oPlayer) then
        return
    end
    local bSucc, iErr, oErrPlayer = self:ValidGiveTask(oPlayer)
    if not bSucc then
        if iErr == ERR.NO_TEAM then
            self:ToConfirmTeamup(oPlayer, true)
            return
        end
        if iErr == ERR.MEMBER_GRADE_FAIL then
            local sMsg = self:GetErrMsg(iErr, CHECK_TYPE.ACC_TASK, oErrPlayer)
            oPlayer:NotifyMessage(sMsg)
            oErrPlayer:NotifyMessage(sMsg)
            return
        end
        oPlayer:NotifyMessage(self:GetErrMsg(iErr, CHECK_TYPE.ACC_TASK, oErrPlayer))
        return
    end

    self:DoGiveTaskToTeam(oPlayer)
end

function CHuodong:DoGiveTaskToTeam(oPlayer)
    local iTaskid = GetHuodongConfig("taskid")
    local oTask = global.oTaskLoader:CreateTask(iTaskid)
    -- oPlayer:NotifyMessage("任务领取成功")
    handleteam.AddTask(oPlayer:GetPid(), oTask)
end

function CHuodong:ToConfirmTeamup(oPlayer, bAutoGoOn)
    local iPid = oPlayer:GetPid()
    local fCallback = function(oPlayer, mData)
        local oHuodong = global.oHuodongMgr:GetHuodong("lingxi")
        if oHuodong then
            oHuodong:OnConfirmTeamup(oPlayer, mData, bAutoGoOn)
        end
    end
    local mCbData = GetText(1113)
    global.oCbMgr:SetCallBack(iPid, "GS2CConfirmUI", mCbData, nil, fCallback)
end

function CHuodong:OnConfirmTeamup(oPlayer, mData, bAutoGoOn)
    if mData.answer == 1 then
        self:InjectMatchTeamPool(oPlayer, bAutoGoOn)
    end
end

function CHuodong:GetFlowerUsePoses()
    return table_get_depth(res.daobiao, {"huodong", "lingxi", "flower_use_pos"})
end

function CHuodong:IsUserPosNeerUsePos(iUserMap, mUserPos, mUsePosInfo)
    if iUserMap == mUsePosInfo.map then
        if mUserPos.x >= mUsePosInfo.pos_x - mUsePosInfo.radius
            and mUserPos.x <= mUsePosInfo.pos_x + mUsePosInfo.radius
            and mUserPos.y >= mUsePosInfo.pos_y - mUsePosInfo.radius
            and mUserPos.y <= mUsePosInfo.pos_y + mUsePosInfo.radius then
            return true
        end
    end
end

function CHuodong:RandOutFlowerUsePos()
    local mUsePoses = self:GetFlowerUsePoses()
    local mInfo = extend.Random.random_choice(table_value_list(mUsePoses))
    return mInfo.map, mInfo.pos_x, mInfo.pos_y, mInfo.radius
end

function CHuodong:CanPosUseFlower(iUserMap, mUserPos)
    local mUsePoses = self:GetFlowerUsePoses()
    for iId, mInfo in pairs(mUsePoses) do
        if self:IsUserPosNeerUsePos(iUserMap, mUserPos, mInfo) then
            return true
        end
    end
    return false
end

function CHuodong:CanUseFlowerItem(oPlayer)
    -- 用花不限制
    -- if not global.oToolMgr:IsSysOpen("LINGXI", oPlayer) then
    --     return
    -- end
    local iPid = oPlayer:GetPid()
    if self:HasFlowerRewardTick(iPid) then
        oPlayer:NotifyMessage(GetText(1111))
        return false
    end
    local bSucc, iErr, oErrPlayer = self:ValidCouple(oPlayer, CHECK_TYPE.USE_FLOWER)
    if not bSucc then
        oPlayer:NotifyMessage(self:GetErrMsg(iErr, CHECK_TYPE.USE_FLOWER, oErrPlayer))
        return false
    end
    local oUserScene = oPlayer.m_oActiveCtrl:GetNowScene()
    if not oUserScene or not self:CanPosUseFlower(oUserScene:MapId(), oPlayer:GetNowPos()) then
        -- oPlayer:NotifyMessage("请在指定地点使用")
        oPlayer:Send("GS2CLingxiShowFlowerUsePos", {})
        return false
    end
    return true
end

function CHuodong:UseFlowerItem(oPlayer)
    local oTeam = oPlayer:HasTeam()
    if not oTeam then
        return
    end
    local lMems = oTeam:GetTeamMember()
    local iFlowerRewardPeriod = GetHuodongConfig("flower_reward_period")
    local iFlowerRewardTimes = GetHuodongConfig("flower_reward_times")
    local iTotalSec = iFlowerRewardPeriod * iFlowerRewardTimes
    for _, iMem in ipairs(lMems) do
        self.m_mFlowerRewarding[iMem] = {
            rest_times = iFlowerRewardTimes,
        }
        self:SetFlowerRewardTick(iMem)
        local oMem = global.oWorldMgr:GetOnlinePlayerByPid(iMem)
        oMem.m_oTaskCtrl:SetData("lingxi_flower_reward_times", iFlowerRewardTimes)
        oMem:Send("GS2CLingxiShowFlowerPoem", {sec = iTotalSec})
        oMem:Send("GS2CShowProgressBar", {
            msg = GetText(1112),
            sec = iTotalSec,
            uninterruptable = 1,
            modal = 1,
            pos = 8,
        })
    end
    handleteam.TeamCancelAutoMatch(oPlayer)
    oTeam:AddServStateByArgs("lingxi_flower_using")
    local iTeamId = oTeam:TeamID()
    self:SetTeamFlowerTimeout(iTeamId, iTotalSec)
    return true
end

function CHuodong:HasFlowerRewardTick(iPid)
    local sTickKey = string.format("flower_rew%d", iPid)
    return self:GetTimeCb(sTickKey)
end

function CHuodong:SetTeamFlowerTimeout(iTeamId, iTotalSec)
    local sTickKey = string.format("flower_timeout%d", iTeamId)
    self:DelTimeCb(sTickKey)
    self:AddTimeCb(sTickKey, iTotalSec * 1000, function()
        TeamFlowerTimeout(iTeamId)
    end)
end

function TeamFlowerTimeout(iTeamId)
    local oTeam = global.oTeamMgr:GetTeam(iTeamId)
    if not oTeam then
        return
    end
    oTeam:RemoveServState("lingxi_flower_using")
end

function CHuodong:SetFlowerRewardTick(iPid)
    local sTickKey = string.format("flower_rew%d", iPid)
    local iFlowerRewardPeriod = GetHuodongConfig("flower_reward_period")
    self:DelTimeCb(sTickKey)
    self:AddTimeCb(sTickKey, iFlowerRewardPeriod * 1000, function()
        RewardingFlower(iPid)
    end)
end

function CHuodong:TickFlowerRewarding(iPid)
    local mRewardInfo = self.m_mFlowerRewarding[iPid]
    if not mRewardInfo then
        return
    end
    local iRestTimes = mRewardInfo.rest_times
    if not iRestTimes or iRestTimes <= 0 then
        self.m_mFlowerRewarding[iPid] = nil
        return
    end
    iRestTimes = iRestTimes - 1
    if iRestTimes > 0 then
        mRewardInfo.rest_times = iRestTimes
        self:SetFlowerRewardTick(iPid)
    else
        self.m_mFlowerRewarding[iPid] = nil
    end
    local oPlayer = global.oWorldMgr:GetOnlinePlayerByPid(iPid)
    if oPlayer then
        local iRecRestTimes = oPlayer.m_oTaskCtrl:GetData("lingxi_flower_reward_times")
        if iRecRestTimes then
            iRecRestTimes = iRecRestTimes - 1
            if iRecRestTimes <= 0 then
                oPlayer.m_oTaskCtrl:SetData("lingxi_flower_reward_times", nil)
            else
                oPlayer.m_oTaskCtrl:SetData("lingxi_flower_reward_times", iRecRestTimes)
            end
        end
    end
    local iFlowerRewardTbl = GetHuodongConfig("flower_reward_tbl")
    self:Reward(iPid, iFlowerRewardTbl, {})
end

function CHuodong:ReissueFlowerReward(oPlayer)
    local iRecRestTimes = oPlayer.m_oTaskCtrl:GetData("lingxi_flower_reward_times")
    if not iRecRestTimes then
        return
    end
    local iPid = oPlayer:GetPid()
    local iOnlineRestTimes = table_get_depth(self.m_mFlowerRewarding, {iPid, "rest_times"}) or 0
    if iOnlineRestTimes > 0 then
        oPlayer.m_oTaskCtrl:SetData("lingxi_flower_reward_times", iOnlineRestTimes)
        -- 继续显示进度条
        local iFlowerRewardPeriod = GetHuodongConfig("flower_reward_period")
        local iFlowerRewardTimes = GetHuodongConfig("flower_reward_times")
        local iTotalSec = iFlowerRewardPeriod * iFlowerRewardTimes
        local iStartSec = (iFlowerRewardTimes - iOnlineRestTimes) * iFlowerRewardPeriod
        oPlayer:Send("GS2CShowProgressBar", {
            msg = GetText(1112),
            sec = iTotalSec,
            start_sec = iStartSec,
            uninterruptable = 1,
            modal = 1,
            pos = 8,
        })
    else
        oPlayer.m_oTaskCtrl:SetData("lingxi_flower_reward_times", nil)
    end
    local iMissCnt = iRecRestTimes - (iOnlineRestTimes or 0)
    local iFlowerRewardTbl = GetHuodongConfig("flower_reward_tbl")
    for i = 1, iMissCnt do
        self:Reward(iPid, iFlowerRewardTbl, {})
    end
end

function RewardingFlower(iPid)
    local oHuodong = global.oHuodongMgr:GetHuodong("lingxi")
    if oHuodong then
        oHuodong:TickFlowerRewarding(iPid)
    end
end

function CHuodong:OnLogout(oPlayer)
    self:RemoveFromMatchTeamPool(oPlayer)
end

function CHuodong:OnLogin(oPlayer, bReEnter)
    self:ReissueFlowerReward(oPlayer)
    self:ReSyncMatching(oPlayer)
end
