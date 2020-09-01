--import module

local global = require "global"
local res = require "base.res"
local record = require "public.record"
local taskobj = import(service_path("task/taskobj"))
local taskdefines = import(service_path("task/taskdefines"))
local gamedefines = import(lualib_path("public.gamedefines"))
local analy = import(lualib_path("public.dataanaly"))
local handleteam = import(service_path("team.handleteam"))

local gsub = string.gsub

CTask = {}
CTask.__index = CTask
CTask.m_sName = "ghost"
CTask.m_sTempName = "金刚伏魔"
CTask.m_sStatisticsName = "task_ghost"
CTask.m_iSysType = gamedefines.GAME_SYS_TYPE.SYS_TYPE_GHOST
inherit(CTask,taskobj.CTeamTask)

function CTask:New(taskid)
    local o = super(CTask).New(self,taskid)
    o.m_iScheduleId = 1004
    return o
end

function CTask:Abandon(oPlayer)
    local iPid = oPlayer:GetPid()
    if oPlayer:IsTeamLeader() and self:GetOwners()[iPid] then
        super(CTask).Abandon(self, oPlayer)
    end
end

function CTask:TrueDoClick(oPlayer)
    local oTeam = oPlayer:HasTeam()
    if not oTeam then return end

    local iPid = oPlayer:GetPid()
    local sFlag = global.oTeamMgr:GetCBFlag(gamedefines.TEAM_CB_FLAG.LEAVE, iPid)
    local mWarCb = oTeam:HasCB(gamedefines.TEAM_CB_TYPE.LEAVE_WAR, sFlag) or {}
    if table_get_depth(mWarCb, {"args", "pid"}) == iPid then
        return
    end

    super(CTask).TrueDoClick(self, oPlayer)
    
    local oTeam = oPlayer:HasTeam()
    if oTeam then
        oTeam.m_iClickGhost = oTeam:Leader()
    end
end

function CTask:OtherScript(iPid,npcobj,s,mArgs)
    if s == "$looknpc" then
        self:LookNpc(iPid,npcobj)
        return true
    elseif s == "$win" then
        self:FightWin(iPid,npcobj,mArgs)
        return true
    end
end

function CTask:ValidFight(iPid,npcobj)
    local oWorldMgr = global.oWorldMgr
    local oToolMgr = global.oToolMgr
    local oPlayer = oWorldMgr:GetOnlinePlayerByPid(iPid)
    if not oPlayer then
        return false
    end
    local oTeam = oPlayer:HasTeam()
    if not oTeam or not oTeam:IsLeader(iPid) then
        self:DoScript2(iPid, npcobj, "D1009")
        return false
    end
    if oPlayer:GetMemberSize() + oPlayer:Query("testman", 0) < 3 then
        self:DoScript2(iPid, npcobj, "D1011")
        return false
    end
    local iOpenLevel = oToolMgr:GetSysOpenPlayerGrade("ZHUAGUI")

    local function FilterCannotFightMember(oMember)
        if oMember:GetGrade() < iOpenLevel then
            return oMember:GetName()
        end
    end

    local lName = oTeam:FilterTeamMember(FilterCannotFightMember)
    if next(lName) then
        local sMsg = self:GetTextData(1010)
        local oToolMgr = global.oToolMgr
        sMsg = oToolMgr:FormatColorString(sMsg,{role=table.concat(lName, "、"), level = iOpenLevel})
        npcobj:Say(iPid, sMsg, nil,nil,true)
        return false
    end
    local oWar = oPlayer.m_oActiveCtrl:GetNowWar()
    if oWar then
        return false
    end
    return true
end

function CTask:LookNpc(iPid,oNpc)
    if not self:ValidFight(iPid,oNpc) then
        return
    end
    local iType = oNpc:Type()
    self:Fight(iPid,oNpc,iType)
end

function CTask:GetGhostName()
    local res = require "base.res"
    local mData = res["daobiao"]["ghostname"]
    local sName = ""
    for iPos=1,3 do
        local mName = mData[iPos]
        sName = sName .. mName[math.random(#mName)]
    end
    return sName
end

function CTask:GetNpcName(iTempNpc,sDefaultName)
    if table_in_list({1001,1002,1003,1004},iTempNpc) then
        return self:GetGhostName()
    end
end

function CTask:RewardDie(iFight)
    return true
end

-- TODO maybe use self:PrepareWar better
function CTask:MarkWar(oWar,iPid,npcobj)
    super(CTask).MarkWar(self, oWar, iPid, npcobj)
    local oWarMgr = global.oWarMgr
    local res = require "base.res"
    local mData = res["daobiao"]["fight"][self.m_sName]["monster"]
    local mType = {}
    local lMonster = {}
    local iCnt = 0
    local oPlayer = global.oWorldMgr:GetOnlinePlayerByPid(iPid)
    for iMonsterIdx,_ in pairs(mData) do
        if iMonsterIdx // 1000 == 2 then
            local iMonsterCnt = math.random(1,4)
            for i=1,iMonsterCnt do
                if iCnt < 6 then
                    iCnt = iCnt + 1
                    -- FIXME Release
                    local oMonster = self:CreateMonster(oWar,iMonsterIdx,npcobj)
                    if oMonster then
                        table.insert(lMonster, oMonster:PackAttr())
                    end
                end
            end
        end
        if iCnt >= 6 then
            break
        end
    end
    if math.random(100) <= 100 then
        local iCnt = #lMonster
        local oMonster = self:CreateMonster(oWar,3001,npcobj)
        if oMonster then
            table.insert(lMonster, 5, oMonster:PackAttr())
        end
    end
    local mMonster = {
        [2] = lMonster,
    }
    oWarMgr:PrepareWar(oWar:GetWarId(),mMonster)
end

function CTask:FightWin(iPid,oNpc,mArgs)
    local iRing = self:GetData("ring", 1)
    self:GhostReward(iPid, iRing, mArgs)

    self:MissionDone(oNpc, mArgs)

    if self.RecordTeamCnt then
        safe_call(self.RecordTeamCnt, self, iPid, mArgs)
    end
    -- 发新任务
    global.oGhostHandler:ToAddNewTask(iPid, iRing)

    -- 给加好友提示
    safe_call(self.GiveAddFriendTips, self)
end

function CTask:MissionDone(npcobj, mArgs)
    local lPlayers = self.m_mPlayer
    local iRing = self:GetData("ring", 1)
    -- local lPlayers = self:GetFighterList(oPlayer, mArgs)
    super(CTask).MissionDone(self, npcobj, mArgs)
    for iPid, _ in pairs(lPlayers) do
        local oPlayer = global.oWorldMgr:GetOnlinePlayerByPid(iPid)
        if oPlayer then
            oPlayer.m_oTaskCtrl:FireGhostDone(iRing)
            global.oRankMgr:PushDataToEveryDayRank(oPlayer, "kill_ghost", {cnt=1})
        end
    end
end

function CTask:CheckDoublePoint(oPlayer)
    if not oPlayer then return end

    local iPoint, iPointLimit = oPlayer.m_oBaseCtrl:GetDoublePoint()
    if not oPlayer.m_bNotifyDouble and iPoint<=10 and iPointLimit>0 then
        local mData = {
            sContent = string.format("你还有#G%d#n点双倍点数，领取双倍点数后金刚伏魔可获得双倍经验和物品奖励", iPoint),
            sConfirm = "领取",
            sCancle = "取消",
            extend_close = 1,
        }
        local oCbMgr = global.oCbMgr
        mData = oCbMgr:PackConfirmData(nil, mData)
        local func = function (oPlayer, mData)
            OnConfirmDoublePoint(oPlayer, mData)
        end
        oCbMgr:SetCallBack(oPlayer.m_iPid, "GS2CConfirmUI", mData, nil, func)

    elseif iPoint==10 and iPointLimit<=0 then
        local oNotify = global.oNotifyMgr
        local sMsg = self:GetTextData(1006)
        sMsg = self:TransString(oPlayer.m_iPid, nil, sMsg)
        oNotify:Notify(oPlayer.m_iPid, sMsg)
    end
end

function CTask:TransCountingStr()
    return string.format("(%d/%d)", self:GetData("ring",1), taskdefines.GHOST_INFO.ROUND_RINGS)
end

function CTask:Name()
    return super(CTask).Name(self) .. self:TransCountingStr()
end

function CTask:TransString(pid,npcobj,s)
    local oWorldMgr = global.oWorldMgr
    local oPlayer = oWorldMgr:GetOnlinePlayerByPid(pid)

    if string.find(s, "$db_item") then
        s=gsub(s, "$db_item", global.oItemLoader:GetItem(10012):Name())
    end
    if oPlayer then
        local iPoint, _ = oPlayer.m_oBaseCtrl:GetDoublePoint()
        s = gsub(s, "$db_point", iPoint)
    else
        s = gsub(s, "$db_point", 0)
    end
    return super(CTask).TransString(self,pid,npcobj,s)
end

function CTask:RewardMissionDone(pid, npcobj, mRewardArgs)
    -- 奖励单独发，不读表
end

function CTask:GhostReward(iPid, iRing, mArgs)
    local oPlayer = global.oWorldMgr:GetOnlinePlayerByPid(iPid)
    if iRing == taskdefines.GHOST_INFO.ROUND_RINGS then
        self:TeamReward(iPid, 1002, mArgs)
        if math.random(2) < 2 then
            self:Reward(iPid, 1002)
        end

        --队长礼包，每天最多10个
        if oPlayer and oPlayer.m_oTodayMorning:Query("ghost_leader_giftbag_cnt",0) < 10 then
            oPlayer.m_oTodayMorning:Add("ghost_leader_giftbag_cnt", 1)
            self:Reward(iPid, 2001)
        end
    end
    self:TeamReward(iPid, 1001, mArgs)
   
    local lPlayers = self:GetFighterList(oPlayer, mArgs)
    for _, iMemPid in ipairs(lPlayers) do
        local oMemPlayer = global.oWorldMgr:GetOnlinePlayerByPid(iMemPid)
    end
    
    local oMentoring = global.oMentoring
    if oMentoring then
        safe_call(oMentoring.AddTaskCnt, oMentoring, oPlayer, 1, 1, "师徒金刚伏魔")
    end
end

function CTask:TransReward(oAwardee,sReward, mArgs)
    local oWorldMgr = global.oWorldMgr
    local iServerGrade = oWorldMgr:GetServerGrade()
    if mArgs and mArgs.iBaseExp then
        mArgs.iBaseExp = 0
    end
    local mEnv = {
        lv = oAwardee:GetGrade(),
        SLV = iServerGrade,
        ring = self:GetData("ring",1),
    }
    local iValue = formula_string(sReward,mEnv)

    local oPlayer = oAwardee
    if oAwardee.GetOwnerID then
        oPlayer = oWorldMgr:GetOnlinePlayerByPid(oAwardee:GetOwnerID())
    elseif oAwardee.GetOwner then
        oPlayer = oWorldMgr:GetOnlinePlayerByPid(oAwardee:GetOwner())
    end
    if oPlayer and oPlayer.GetServerGrade then
        mEnv.SLV = oPlayer:GetServerGrade()
    end

    local iDouble, iLeader, iSize, iBase = self:BonusFactor(oPlayer)
    -- if iDouble <= 0 and iBase <= 0 then
    --     mArgs.iBaseExp = 0
    --     return 0
    -- end
    -- InitRewardExp 获取奖励玩家的基础经验
    mArgs.iBaseExp = math.floor(iValue * (5 + iSize) / taskdefines.GHOST_INFO.ROUND_RINGS * iBase)
    return  iValue * (1 + iDouble + iLeader ) * (5 + iSize) / taskdefines.GHOST_INFO.ROUND_RINGS * math.floor(iBase)

end

function CTask:BonusFactor(oPlayer)
    local iPoint, _ = oPlayer.m_oBaseCtrl:GetDoublePoint()
    local iBaseTimes = oPlayer.m_oTodayMorning:Query("ghost_base", 0)

    local iDouble = iPoint > 0 and 1 or 0
    local iLeader = 0
    local iTeamSize = 1
    local iBase = (iBaseTimes < 60 or iPoint > 0) and 1 or 0.1

    local oTeam = oPlayer:HasTeam()
    if oTeam then
        iTeamSize = oTeam:MemberSize()
        if oTeam:IsLeader(oPlayer:GetPid()) then
            iLeader = 0.3
        end
    end

    return iDouble, iLeader, iTeamSize, iBase
end

function CTask:Reward(pid, sIdx, mArgs)
    super(CTask).Reward(self, pid, sIdx, mArgs)

    if sIdx ~= 1001 then return end

    local oWorldMgr = global.oWorldMgr
    local oPlayer = oWorldMgr:GetOnlinePlayerByPid(pid)
    if not oPlayer then return end
    oPlayer.m_oScheduleCtrl:Add(self.m_iScheduleId)
    local iPoint, iPointLimit = oPlayer.m_oBaseCtrl:GetDoublePoint()
    oPlayer.m_oTodayMorning:Add("ghost_total",1)
    if iPoint > 0 then
        oPlayer.m_oBaseCtrl:AddDoublePoint(-1)
        oPlayer.m_oBaseCtrl:RefreshDoublePoint()
        oPlayer.m_oStateCtrl:RefreshDoublePoint()
    else
        oPlayer.m_oTodayMorning:Add("ghost_base", 1)
        oPlayer.m_oScheduleCtrl:HandleRetrieve(self.m_iScheduleId, 1)
    end
    if iPointLimit > 0 then
        self:CheckDoublePoint(oPlayer)
    end
end

function CTask:TeamReward(pid,sIdx,mArgs)
    local oPlayer = global.oWorldMgr:GetOnlinePlayerByPid(pid)
    if not oPlayer then 
        return
    end
    mArgs = mArgs or {}
    local lPlayers = self:GetFighterList(oPlayer,mArgs)
    local iNewbee = self:_TeamNewbeeCnt(oPlayer,lPlayers)
    self:RewardLeaderPoint(oPlayer,"ghost","金刚伏魔",#lPlayers)
    self:TryRewardFighterXiayiPoint(pid, lPlayers, {iLowLevel = iNewbee})
    for _,pid in ipairs(lPlayers) do
        self:Reward(pid,sIdx,table_copy(mArgs)) 
    end
end

function CTask:_TeamNewbeeCnt(oPlayer,lPlayers)
    if not oPlayer then return 0 end
    local iNewbee = 0
    local iServerGrade = oPlayer:GetServerGrade()
    for _,pid in ipairs(lPlayers) do
        local oMember = global.oWorldMgr:GetOnlinePlayerByPid(pid)
        if oMember then
            if not self:InvalidRewardExp(oMember) then
                if oMember:GetGrade() <= 100 and oMember:GetGrade() < iServerGrade -5 then
                    iNewbee = iNewbee + 1
                end
            end
        end
    end
    return iNewbee
end

function CTask:TryRewardFighterXiayiPoint(iLeaderPid, lFighterPid, mArgs)
    local iLowLevel = mArgs.iLowLevel
    local lRewardPid = self:RewardFighterFilter(iLeaderPid, lFighterPid, nil)
    for _, pid in pairs(lRewardPid) do
        local oPlayer = global.oWorldMgr:GetOnlinePlayerByPid(pid)
        if oPlayer then
            local bHighLevel = oPlayer:GetGrade() >= oPlayer:GetServerGrade() or false
            local bNoExp = self:InvalidRewardExp(oPlayer)
            if bHighLevel and iLowLevel >= 2 then
                self:RewardXiayiPoint(oPlayer, "ghost2","金刚伏魔二新人")
            elseif bHighLevel and iLowLevel == 1 then
                self:RewardXiayiPoint(oPlayer, "ghost1","金刚伏魔一新人")
            elseif bNoExp then
                self:RewardXiayiPoint(oPlayer, "ghost3","金刚伏魔无经验")
            end
        end
    end
end

function CTask:InvalidRewardExp(oPlayer)
    local iPoint, iPointLimit = oPlayer.m_oBaseCtrl:GetDoublePoint() 
    local bNoExp = iPoint  <= 0 and oPlayer.m_oTodayMorning:Query("ghost_base",0)  > 60 or false
    return bNoExp
end

function CTask:RewardExp(oPlayer, iBaseExp, mArgs)
    mArgs = mArgs or {}
    mArgs.iLeaderRatio = nil
    mArgs.iAddexpRatio = nil
    local iFortune = oPlayer.m_oTodayMorning:Query("signfortune", 0)
    local iEffect = 0
    if iFortune == gamedefines.SIGNIN_FORTUNE.BGYX  then
        iEffect = res["daobiao"]["huodong"]["signin"]["fortune"][iFortune]["effect"]
    end
    local oState = oPlayer.m_oStateCtrl:HasState(1009)
    local iStateRatio = oState and oState:GetExpRatioByName("ghost") or 0
    local iDouble, iLeader, iSize, iBase = self:BonusFactor(oPlayer)
    mArgs.iLeaderRatio =  iLeader * 100
    mArgs.iAddexpRatio = iEffect + iStateRatio + (iDouble + iLeader) * 100
    super(CTask).RewardExp(self, oPlayer, iBaseExp, mArgs)
end

function CTask:GetSelectListByGrade(iGrade)
    local mGrade2ItemGroup = {
        [1] = {201, 202},
        [2] = {201, 202, 203},
        [3] = {202, 203, 204},
        [4] = {203, 204, 205},
        [5] = {204, 205},
    }
    local iGradeKey = math.min(70, math.max(30, iGrade//10*10))
    local lSelect = mGrade2ItemGroup[(iGradeKey-20)/10]
    return lSelect
end

function CTask:TransItemShape(oPlayer, itemidx, iShape, sShape)
    if itemidx==1002 and iShape==9999 then
        local iGrade = oPlayer:GetGrade()
        local lSelect = self:GetSelectListByGrade(iGrade)
        return iShape, lSelect[math.random(#lSelect)]
    end
    return super(CTask).TransItemShape(self, oPlayer, itemidx, iShape, sShape)
end

function CTask:InitRewardItem(oPlayer, itemidx, mArgs)
    local iPoint, _ = oPlayer.m_oBaseCtrl:GetDoublePoint()
    if itemidx == 1002 and iPoint <= 0 then return end
    return super(CTask).InitRewardItem(self, oPlayer, itemidx, mArgs)
end

function CTask:InitRewardExp(oPlayer, sExp, mArgs)
    local iExp = super(CTask).InitRewardExp(self, oPlayer, sExp, mArgs)
    --if iExp <= 0 then return 0 end
    --未经状态叠加的值
    return mArgs.iBaseExp
end

function CTask:LogAnalyInfo(oPlayer)
    if not oPlayer then return end

    local oTeam = oPlayer:HasTeam()
    if not oTeam then return end

    local sTeam_detail = ""
    local oWorldMgr = global.oWorldMgr
    local lMember = oTeam:GetTeamMember()
    for _,iPid in pairs(lMember or {}) do
        local oMem = oTeam:GetMember(iPid)
        if oMem then
            if #sTeam_detail > 0 then
                sTeam_detail = sTeam_detail.."&"
            end
            sTeam_detail = sTeam_detail..iPid.."+"..oMem:GetSchool().."+"..oMem:GetGrade()
        end
    end

    for _,iPid in pairs(lMember or {}) do
        local o = oWorldMgr:GetOnlinePlayerByPid(iPid)
        if o then
            local mAnalyLog = o:BaseAnalyInfo()
            mAnalyLog["team_detail"] = sTeam_detail
            mAnalyLog["team_leader"] = oTeam:IsLeader(iPid)
            mAnalyLog["turn_times"] = self:GetData("ring", 1)
            mAnalyLog["win_mark"] = true
            local mReward = o:GetTemp("reward_content", {})
            mAnalyLog["reward_detail"] = analy.table_concat(mReward)
            analy.log_data("ghost", mAnalyLog)
        end
    end
end

function CTask:OnEnterTeam(iPid,iFlag)
    super(CTask).OnEnterTeam(self, iPid, iFlag)
   
    local iTask = self:GetId() 
    local iTeam = self.m_iTeamID 
    local oTeam = global.oTeamMgr:GetTeam(iTeam)
    if oTeam and table_count(self.m_mPlayer) and oTeam:Leader()==oTeam.m_iClickGhost then
        self:DelTimeCb("ClickTask")
        self:AddTimeCb("ClickTask", 1000, function()
            AutoClickTask(iTeam, iTask)
        end)
    end

    local oPlayer = global.oWorldMgr:GetOnlinePlayerByPid(iPid)
    if oPlayer then
        self:CheckDoublePoint(oPlayer)
    end
end

function CTask:OnLeaveTeam(iPid, iFlag)
    super(CTask).OnLeaveTeam(self, iPid, iFlag)

    local iTeam = self.m_iTeamID 
    local oTeam = global.oTeamMgr:GetTeam(iTeam)
    if not oTeam then return end

    local iLeader = oTeam:Leader()
    oTeam.m_mNotifyPlayer = oTeam.m_mNotifyPlayer or {}
    table_set_depth(oTeam.m_mNotifyPlayer, {iLeader}, iPid, nil)
    oTeam.m_mNotifyPlayer[iPid] = nil

    if iFlag == 3 then      --玩家离线
        -- handleteam.KickoutTeam(oTeam:GetLeaderObj(), iPid)
        oTeam:Leave(iPid)
    elseif iFlag == 4 then
        local oPlayer = global.oWorldMgr:GetOnlinePlayerByPid(iPid)
        if oPlayer then
            local iTarget = oPlayer.m_oActiveCtrl:GetInfo("auto_targetid", 0)
            local iMatchTeam = oPlayer.m_oActiveCtrl:GetInfo("match_team", 0)
            if (iTarget == 0 or iTarget == 1400) and iMatchTeam ~= iTeam then
                --金刚伏魔匹配
                handleteam.PlayerAutoMatch(oPlayer, 1400)
            end
        end
    end

    local iTotal = table_count(self.m_mPlayer)
    if oTeam and iTotal > 0 and iTotal < 5 and oTeam:Leader()==oTeam.m_iClickGhost then
        local oLeader = oTeam:GetLeaderObj()
        handleteam.TeamAutoMatch(oLeader, {
            team_match = 1,
            min_grade = 20,
            max_grade = oLeader:GetServerGrade()+5,
            auto_target = 1400,
        })
    end
end

function CTask:GiveAddFriendTips()
    if is_ks_server() then return end

    local iTeam = self.m_iTeamID 
    local oTeam = global.oTeamMgr:GetTeam(iTeam)
    if not oTeam then return end

    local iLeader = oTeam:Leader()
    if not oTeam.m_mNotifyPlayer or not oTeam.m_mNotifyPlayer[iLeader] then
        oTeam.m_mNotifyPlayer = {[iLeader] = {}}
    end

    local mData = {
        sContent = "如此专业的队长，快快加为好友，天天一起快乐游戏",
        sConfirm = "加为好友",
        sCancle = "取消",
    }

    local oCbMgr = global.oCbMgr
    for _, iPid in ipairs(oTeam:GetTeamMember()) do
        if iPid == iLeader then
            goto continue
        end

        local iCnt = oTeam.m_mNotifyPlayer[iLeader][iPid] or 0
        oTeam.m_mNotifyPlayer[iLeader][iPid] = iCnt + 1

        local oPlayer = global.oWorldMgr:GetOnlinePlayerByPid(iPid)
        if oPlayer and oTeam.m_mNotifyPlayer[iLeader][iPid]==20 then
            local oFriend = oPlayer:GetFriend()
            if not oFriend:IsShield(iLeader) and not oFriend:HasFriend(iLeader) then
                local mNet= oCbMgr:PackConfirmData(nil, mData)
                local func = function(oPlayer, mData)
                    OnConfirmAddFriend(oPlayer, iLeader, mData)
                end
                oCbMgr:SetCallBack(iPid, "GS2CConfirmUI", mNet, nil, func)
            end
        end
        ::continue::
    end
end

function NewTask(taskid)
    local o = CTask:New(taskid)
    return o
end

function FilterMember(oMember)
    local iPid = oMember.m_ID
    local oPlayer = global.oWorldMgr:GetOnlinePlayerByPid(iPid)
    if oPlayer and not global.oToolMgr:IsSysOpen("ZHUAGUI", oPlayer, true) then
        return oPlayer:GetName()
    end
end

function OnConfirmDoublePoint(oPlayer, mData)
    local iAnswer = mData["answer"]
    if iAnswer == 1 then
        oPlayer.m_oBaseCtrl:RewardDoublePoint()
    else
        oPlayer.m_bNotifyDouble = true
    end
end

function OnConfirmAddFriend(oPlayer, iLeader, mData)
    if is_ks_server() then return end

    if mData.answer ~= 1 then
        return
    end
    local oLeader = global.oWorldMgr:GetOnlinePlayerByPid(iLeader)
    if not oLeader then return end
   
    local oLeaderFriend = oLeader:GetFriend()
    if oLeaderFriend:IsVerifyToggle() then
        global.oFriendMgr:VerifyFriend(oPlayer, iLeader, "队长加我为好友，一起玩")
    else
        global.oFriendMgr:AddFriend(oPlayer, iLeader)
    end
end

function AutoClickTask(iTeam, iTask)
    local oTeam = global.oTeamMgr:GetTeam(iTeam)
    if not oTeam then return end

    local oTask = oTeam:GetTask(iTask)
    if not oTask then return end

    oTask:DelTimeCb("ClickTask")
    oTask:Click(oTeam:Leader())
end

