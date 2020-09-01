local global = require "global"
local extend = require "base.extend"
local record = require "public.record"
local res = require "base.res"

local taskobj = import(service_path("task.taskobj"))
local gamedefines = import(lualib_path("public.gamedefines"))
local LIMIT_SIZE = 3
function NewTask(taskid)
    local o = CTask:New(taskid)
    return o
end

CTask = {}
CTask.__index = CTask
CTask.m_sName = "fuben"
CTask.m_sTempName = "副本任务"
CTask.m_sStatisticsName = "fuben"
inherit(CTask,taskobj.CTeamTask)

function CTask:CanDealTask(oPlayer)
    local oFuben = self:GetFubenObj()
    if not oFuben then return false end

    local sSys = self:GetOpenSysName(oFuben:GetFubenId())
    if not global.oToolMgr:IsSysOpen(sSys, oPlayer) then
        return false
    end
    return true
end

function CTask:ValidFight(pid,npcobj,iFight)
    local oTeam = self:GetTeamObj()
    if not oTeam then
        return
    end
    if oTeam:MemberSize() < LIMIT_SIZE then
        oTeam:TeamNotify(string.format("队伍不足%s人",LIMIT_SIZE))
        return false
    end

    local oToolMgr = global.oToolMgr
    local oFuben = self:GetFubenObj()
    if not oFuben then return false end
    local iFubenType = oFuben:GetFubenId()
    local sOpen_name = self:GetOpenSysName(iFubenType)
    local iOpenLevel = oToolMgr:GetSysOpenPlayerGrade(sOpen_name)
    
    local function FilterCannotFightMember(oMember)
        if oMember:GetGrade() < iOpenLevel then
            return oMember:GetName()
        end
    end

    local lName = oTeam:FilterTeamMember(FilterCannotFightMember)
    if next(lName) then
        local sMsg = oToolMgr:GetTextData(1005,{"fuben"})
        sMsg = oToolMgr:FormatColorString(sMsg,{role=table.concat(lName, "、"), level = iOpenLevel})
        npcobj:Say(pid, sMsg, nil,nil,true)
        return false
    end
    local bResult = super(CTask).ValidFight(self,pid,npcobj,iFight)
    return bResult
end

function CTask:OnMissionDone(iOwner)
    local oFuben = self:GetFubenObj()
    if not oFuben then return end
    local iFuben = oFuben:GetFubenId()
    local iStep = oFuben:GetFubenStep()

    for iPid, _ in pairs(self.m_mPlayer) do
        local oPlayer = self:GetPlayer(iPid)
        if oPlayer then
            local oFubenMgr = oPlayer:GetFubenMgr()
            oFubenMgr:SetFubenProgress(iFuben, iStep)
        end
    end
end

function CTask:RewardMissionDone(iPid, npcobj, mArgs)
    local oFuben = self:GetFubenObj()
    if not oFuben then return end

    local iFuben = oFuben:GetFubenId()
    local iStep = oFuben:GetFubenStep()
    local mNeedReward = {}
    local lPlayer = self.m_FBlPlayer or {}
    local sSource = self.m_sName .. "_" .. tostring(iFuben)
    local sReason = sSource .. tostring(iStep)
    local oPlayer = global.oWorldMgr:GetOnlinePlayerByPid(iPid)
    if oPlayer then
        self:RewardLeaderPoint(oPlayer,sSource,sReason,#lPlayer)
    end
    for _, pid in pairs(lPlayer) do
        local oPlayer = self:GetPlayer(pid)
        if oPlayer then
            local oFubenMgr = oPlayer:GetFubenMgr()
            if  oFubenMgr:GetFubenReward(iFuben, iStep) >= 1 then
                self:RewardXiayiPoint(oPlayer,sSource,sReason)
                goto continue
            end
            oFubenMgr:SetFubenReward(iFuben, iStep)
            mNeedReward[pid] = 1
            ::continue::
        end
    end
    local mLogData={
        teammember = extend.Table.serialize(mNeedReward),
        step = iStep,
    }
    record.log_db("huodong", "fumo_step_reward",mLogData)


    local mData = self:GetTaskData()
    local s = mData["submitRewardStr"]
    for pid ,_ in pairs(mNeedReward) do
        self:DoScript(pid,npcobj,s, mArgs)
    end
end

function CTask:IsLogWarWanfa()
    return true
end

function CTask:LogKey()
    local oFuben = self:GetFubenObj()
    if oFuben then
        return oFuben:GetName()
    end
    return self.m_sName
end

function CTask:WarFightEnd(oWar, iPid, oNpc, mArgs)
    if mArgs.win_side ==1 then
        local oFuben = self:GetFubenObj()
        local mPlayer = extend.Table.deep_clone(mArgs.player)
        for side,mDie in ipairs(mArgs.die) do
            if not mPlayer[side] then
                mPlayer[side] = {}
            end
            for _,pid in ipairs(mDie) do
                table.insert(mPlayer[side],pid)
            end
        end
        self.m_FBlPlayer = mPlayer[mArgs.win_side]

        oFuben:AddTotalBout(mArgs.bout_cnt or 0, self.m_FBlPlayer)
        --oFuben:RefreshPoint()
        oFuben:CheckNotifySSS()
    end
    super(CTask).WarFightEnd(self, oWar, iPid, oNpc, mArgs)
end

function CTask:BeforeRespond(oPlayer, npcid)
    local bRet = super(CTask).BeforeRespond(self, oPlayer, npcid)
    if not bRet then return false end

    local oFuben = self:GetFubenObj()
    if not oFuben then return false end

    local iFuben = oFuben:GetFubenId()
    local oFubenMgr = global.oFubenMgr
    if not oFubenMgr:OpenCondition(oPlayer, iFuben) then
        return false
    end

    if not oFubenMgr:EnterCondition(oPlayer, iFuben) then
        return false
    end
    return true
end

function CTask:SetFubenId(iFubenId)
    self.m_iFubenId = iFubenId
end

function CTask:GetFubenId()
    return self.m_iFubenId
end

function CTask:OtherScript(iPid, oNpc, s, mArgs)
    local sCmd = string.match(s, "^([$%a]+)")
    if not sCmd then return end
    local sArgs = string.sub(s, #sCmd+1, -1)

    if sCmd == "INIT" then
        local lArgs = split_string(string.sub(sArgs, 2, -2), "|")
        self:InitCondition(iPid, table.unpack(lArgs))
        return true
    elseif sCmd == "CHOOSE" then
        local lArgs = split_string(string.sub(sArgs, 2, -2), "|")
        assert (#lArgs > 2, "CHOOSE condition format")
        local sArgs = lArgs[math.random(#lArgs-1) + 1]
        local lArgs = {lArgs[1], sArgs}
        self:InitCondition(iPid, table.unpack(lArgs))
        return true
    else
        local oFuben = self:GetFubenObj()
        if oFuben then
            oFuben:OtherScript(iPid, oNpc, s, mArgs)
        end
    end
end

function CTask:InitCondition(iPid, sCond, ...)
    local oPlayer = self:GetPlayer(iPid)
    if not oPlayer then return false end

    sCond = string.format("Init%s", sCond)
    self[sCond](self, oPlayer, ...)
end

function CTask:MarkCondition(iPid, sCond, ...)
    local oPlayer = self:GetPlayer(iPid)
    if not oPlayer then return false end

    sCond = string.format("Mark%s", sCond)
    self[sCond](self, oPlayer, ...)
end

function CTask:CheckCondition(iPid, sCond)
    local oPlayer = self:GetPlayer(iPid)
    if not oPlayer then return false end

    if oPlayer:Query("testman", 0) >= 99 then
        return true
    end

    sCond = string.format("Check%s", sCond)
    return self[sCond](self, oPlayer)
end

function CTask:InitWinMonster(oPlayer, sArgs)
    --sArgs = 1001:1|1002:3
    local lArgs = split_string(sArgs, "|")
    for _, sMatch in ipairs(lArgs) do
        local mInfo = split_string(sMatch, ":", tonumber)
        local iIdx = mInfo[1]
        local iAmount = mInfo[2]
        local mData = self:GetData("win_monster", {})
        mData[iIdx] = iAmount
        self:SetData("win_monster", mData)
    end
end

function CTask:MarkWinMonster(oPlayer, sArgs)
    --sArgs = 1001:1
    local mInfo = split_string(sArgs, ":", tonumber)
    local iIdx = mInfo[1]
    local iAmount = mInfo[2]
    local mData = self:GetData("win_monster", {})
    if mData[iIdx] then
        mData[iIdx] = math.max(0, mData[iIdx] - iAmount)
    elseif mData[0] then
        mData[0] = math.max(0, mData[0] - iAmount)
    end
    self:SetData("win_monster", mData)
end

function CTask:CheckWinMonster(oPlayer)
    local mData = self:GetData("win_monster", {})
    local iRet = 0
    for iIdx, iAmount in pairs(mData) do
        iRet = iRet + iAmount
    end
    return iRet <= 0
end

function CTask:CheckAutoPass(oPlayer)
    return true
end

function CTask:OnEnterTeam(pid,iFlag)
    local oFuben = self:GetFubenObj()
    if oFuben then
        return oFuben:OnEnterTeam(pid,iFlag)
    end
end

function CTask:OnLeaveTeam(pid,iFlag)
    local oFuben = self:GetFubenObj()
    if oFuben then
        return oFuben:OnLeaveTeam(pid,iFlag)
    end
end

function CTask:GetFubenObj()
    local oFubenMgr = global.oFubenMgr
    return oFubenMgr:GetFuben(self.m_iFubenId)
end

function CTask:GetPlayer(iPid)
    local oWorldMgr = global.oWorldMgr
    return oWorldMgr:GetOnlinePlayerByPid(iPid)
end

function CTask:GetRewardData(iReward)
    local oFuben = self:GetFubenObj()
    if oFuben then
        return oFuben:GetRewardData(iReward)
    end
end

function CTask:GetItemRewardData(iItemReward)
    local oFuben = self:GetFubenObj()
    if oFuben then
        return oFuben:GetItemRewardData(iItemReward)
    end
end

function CTask:GetOpenSysName(iFubenType)
    return res["daobiao"]["fuben"]["fuben_config"][iFubenType]["open_name"]
end

function CTask:GetTextData(iText)
    local oFuben = self:GetFubenObj()
    if oFuben then
        local oToolMgr = global.oToolMgr
        return oToolMgr:GetTextData(iText, {"fuben", oFuben:GetName()})
    end
end

function CTask:RewardExp(oPlayer, iExp)
    local mArgs = {}
    if oPlayer:IsTeamLeader() then
        local iRatio = oPlayer.m_oStateCtrl:GetLeaderExpRaito(self.m_sName, oPlayer:GetMemberSize())
        mArgs.iLeaderRatio = iRatio
        mArgs.iAddexpRatio = iRatio
    end 
    local mResult =  super(CTask).RewardExp(self, oPlayer, iExp, mArgs)
    local iTrueExp = mResult.exp
    local oFuben = self:GetFubenObj()
    if oFuben and iTrueExp then
        oFuben:AddFBExp(oPlayer:GetPid(),iTrueExp)
        
        local mCofing = oFuben:GetFubenConfig()
        local iSchedule = mCofing["schedule"]
        oPlayer.m_oScheduleCtrl:HandleRetrieve(iSchedule, 1)
    end
end

function CTask:RewardSilver(oPlayer, iSilver, mArgs)
    super(CTask).RewardSilver(self, oPlayer, iSilver, mArgs)
    local oFuben = self:GetFubenObj()
    if oFuben then
        oFuben:AddFBSilver(oPlayer:GetPid(),iSilver)
    end
end

function CTask:SendRewardContent(oPlayer, mRewardContent, mArgs)
    local mAllItems = mRewardContent.items
    local mItem = {}
    if mAllItems then
        for itemidx, mItems in pairs(mAllItems) do
            for _,mInfo in ipairs(mItems["items"]) do
                local itemsid = mInfo["m_SID"]
                if not  mItem[itemsid] then
                    mItem[itemsid] = 0
                end
                mItem[itemsid] = mItem[itemsid] + mInfo["m_iAmount"]
            end
        end
    end
    local oFuben = self:GetFubenObj()
    if oFuben then
        oFuben:AddFBItem(oPlayer:GetPid(),mItem)
    end
    super(CTask).SendRewardContent(self, oPlayer, mRewardContent, mArgs)
end

function CTask:FillWarStartArgs(mTollgateData, mArgs)
    -- 喊话
    local iSpeekId = mTollgateData.speek_id or 0
    if iSpeekId ~= 0 then
        local mSpeekData = self:GetWarSpeekData(iSpeekId)
        assert(mSpeekData, string.format("fight speek err, speekid:%s, sName:%s", iSpeekId, self.m_sName))
        mArgs.speek = mSpeekData
    end
    return mArgs
end

function CTask:OnChangeLeader(iPid)
    local oFuben = self:GetFubenObj()
    if not oFuben then return false end
  
    local oLeader = global.oWorldMgr:GetOnlinePlayerByPid(iPid)
    if not oLeader then return end

    local oTeam = oLeader:HasTeam()
    if not oTeam then return end

    local oNowScene = oLeader.m_oActiveCtrl:GetNowScene()
    if not oNowScene then return end
 
    for iScene, _ in pairs(oFuben.m_mSceneList or {}) do
        if iScene == oNowScene:GetSceneId() then
            return
        end
    end

    oTeam:RemoveTask(self.m_ID)
end
