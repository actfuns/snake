local global  = require "global"
local res = require "base.res"
local extend = require "base.extend"
local record = require "public.record"

local datactrl = import(lualib_path("public.datactrl"))
local huodongbase = import(service_path("huodong.huodongbase"))
local handleteam = import(service_path("team.handleteam"))
local analy = import(lualib_path("public.dataanaly"))

function NewFuben(...)
    local o = CFuben:New(...)
    return o
end


CFuben = {}
CFuben.__index = CFuben
inherit(CFuben, huodongbase.CHuodong)

function CFuben:New(id, iFuben)
    local mData = self:GetFubenConfig(iFuben)
    local o = super(CFuben).New(self, mData.fuben_name)
    o.m_ID = id
    o.m_iFuben = iFuben
    o:Init()
    return o
end

function CFuben:Init()
    self.m_iStep = 1
    self.m_iStartTime = 0
    self.m_mSceneIdx2Obj = {}
    self.m_mMemberList = {}
    self.m_mPoint = {}
    self.m_mExp = {}
    self.m_mSilver = {}
    self.m_mFBItem = {}
    self.m_mNotifySSS = {}
    self.m_iWarCount = 0 
end

function CFuben:BeforeRelease()
    self:TransferHome()
    for iScene, _ in pairs(self.m_mSceneList) do
        self:RemoveSceneById(iScene)
    end
end
function CFuben:Release()
    self.m_mSceneIdx2Obj = {}
    self.m_mSceneList = {}
    self.m_mMemberList = {}
    self.m_mPoint = {}
    self.m_mExp = {}
    self.m_mSilver = {}
    self.m_mFBItem = {}
    self.m_mNotifySSS = {}
    super(CFuben).Release(self)
end

function CFuben:IsLastGate()
    local lGroup = self:GetGroupList()
    return self.m_iStep >= #lGroup
end

function CFuben:GetOwner()
    local oPlayer = nil
    for iPid, _ in pairs(self.m_mMemberList) do
        oPlayer = self:GetPlayer(iPid)
        if oPlayer then break end
    end

    if not oPlayer then return end

    if oPlayer:HasTeam() then
        return oPlayer:HasTeam():Leader()
    else
        return oPlayer:GetPid()
    end
end

function CFuben:GameStart(oPlayer, iStep)
    self:InitMember(oPlayer)
    local iTask = self:GetTaskByStep(iStep)
    local oTask = global.oTaskLoader:CreateTask(iTask)
    oTask:SetFubenId(self.m_ID)
    oTask:SetOwner(self:GetOwner())
    self:SetFubenStep(iStep)
    self:SetStartTime()
    self.m_iWarCount = 0
    local oTask = handleteam.AddTask(oPlayer:GetPid(), oTask)
    if oTask then
        local oNpc = oTask:GetNpcObjByType(oTask:Target())
        self:TransferPlayer(oPlayer:GetPid(),oNpc:MapId(),0,0)

        -- 记录玩法次数
        local mPid = {}
        local mMember = oPlayer:GetTeamMember()
        if mMember then
            for _, iPid in pairs(mMember) do
                mPid[iPid] = true
            end
            local mLogData={
            teammember = extend.Table.serialize(mMember),
            }
            record.log_db("huodong", "fumo_start",mLogData)
        else
            mPid[oPlayer:GetPid()] = true
        end
        safe_call(oTask.RecordPlayerCnt, oTask, mPid)
        safe_call(self.LogAnalyInfo, self, oPlayer:GetPid(), 1)
    end

end

function CFuben:GameOver(iPid)
    safe_call(self.LogAnalyInfo, self, iPid, 2)
    self:GameOverReward()
    local iFubenID = self:GetFubenId()
    for iPid, _ in pairs(self.m_mMemberList) do
        local oPlayer = self:GetPlayer(iPid)
        if oPlayer then
            oPlayer.m_oBaseCtrl.m_oFubenMgr:FireFubenDone(iFubenID)
            if iFubenID == 10001 then
                oPlayer:MarkGrow(28)
            elseif iFubenID == 10002 then
                 oPlayer:MarkGrow(38)
            end
        end
    end
    self.m_iWarCount = 0
    global.oFubenMgr:DelFuben(self.m_ID)

    local oPlayer = global.oWorldMgr:GetOnlinePlayerByPid(iPid)
    local oMentoring = global.oMentoring
    if oPlayer and oMentoring then
        local iTask = iFubenID//10000 == 1 and 7 or 6
        safe_call(oMentoring.AddTaskCnt, oMentoring, oPlayer, iTask, 1, "师徒副本")
    end
end

function CFuben:LogAnalyInfo(iPid, iOperation)
    local oWorldMgr = global.oWorldMgr
    local oPlayer = oWorldMgr:GetOnlinePlayerByPid(iPid)
    if not oPlayer then return end

    local oWorldMgr = global.oWorldMgr
    local mMember = oPlayer:GetTeamMember()
    if mMember then
        for _, iPid in pairs(mMember) do
            local oMem = oWorldMgr:GetOnlinePlayerByPid(iPid)
            if oMem then
                local mAnalyLog = oMem:BaseAnalyInfo()
                mAnalyLog["fbid"] = self.m_iFuben
                mAnalyLog["operation"] = iOperation
                analy.log_data("fuBen", mAnalyLog)
            end
        end
    else
        local mAnalyLog = oPlayer:BaseAnalyInfo()
        mAnalyLog["fbid"] = self.m_iFuben
        mAnalyLog["operation"] = iOperation
        analy.log_data("fuBen", mAnalyLog)
    end
end

function CFuben:SetStartTime()
    self.m_iStartTime = get_time()
end

function CFuben:GetStartTime()
    return self.m_iStartTime or get_time()
end

function CFuben:InitMember(oPlayer)
    local oTeam = oPlayer:HasTeam()
    local lMember = oTeam and oTeam:GetTeamMember() or {oPlayer:GetPid()}
    for _, pid in pairs(lMember) do
        self.m_mMemberList[pid] = 1
        self.m_mPoint[pid] = 0
    end
end

function CFuben:TransferHome(iPid)
    iPid = iPid or self:GetOwner()
    if not iPid then return end
    
    local iMapID, iX, iY = 101000, 13.0, 14.0
    self:TransferPlayer(iPid, iMapID, iX, iY)
end

function CFuben:SetFubenStep(iStep)
    self.m_iStep = iStep
end

function CFuben:GetFubenStep()
    return self.m_iStep
end

function CFuben:GetTaskByStep(iStep)
    local mData = self:GetFubenConfig()
    local iGroup = mData.group_list[iStep]
    local iTask = self:GetTaskByGroup(iGroup)
    return iTask
end

function CFuben:GetId()
    return self.m_ID
end

-- @Override
function CFuben:GetCbSelfGetter()
    local iObjId = self:GetId()
    return function()
        return global.oFubenMgr:GetFuben(iObjId)
    end
end

function CFuben:GetFubenId()
    return self.m_iFuben
end

function CFuben:GetName()
    local mData = self:GetFubenConfig()
    return mData.fuben_name
end

function CFuben:GetGroupList()
    local mData = self:GetFubenConfig()
    return mData.group_list
end

function CFuben:GetTaskObjByStep(iPid)
    local oPlayer = self:GetPlayer(iPid)
    if not oPlayer then return end

    local oTeam = oPlayer:HasTeam()
    if not oTeam then return end

    local lGroup = self:GetGroupList()
    local iGroup = lGroup[self.m_iStep]
    local iTask = self:GetTaskByGroup(iGroup)
    return oTeam:GetTask(iTask)
end

function CFuben:OtherScript(iPid, oNpc, s, mArgs)
    local sCmd = string.match(s, "^([$%a]+)")
    if not sCmd then return end

    local sArgs = string.sub(s, #sCmd+1, -1)

    if sCmd == "FSC" then
        local iSceneIdx = tonumber(sArgs)
        self:CreateVirtualScene(iSceneIdx)
        return true
    elseif sCmd == "NFT" then
        local iGroup  = tonumber(sArgs)
        local iTask = self:GetTaskByGroup(iGroup)
        local oTask = global.oTaskLoader:CreateTask(iTask)
        oTask:SetFubenId(self.m_ID)
        oTask:SetOwner(self:GetOwner())
        handleteam.AddTask(iPid, oTask)
        return true
    elseif sCmd == "MARK" then
        local oTask = self:GetTaskObjByStep(iPid)
        if not oTask then return end
        local lArgs = split_string(string.sub(sArgs, 2, -2), "|")
        if #lArgs > 1 then
            oTask:MarkCondition(iPid, table.unpack(lArgs))
        else
            table.insert(lArgs, string.format("%s:1", oNpc:Type()))
            oTask:MarkCondition(iPid, table.unpack(lArgs))
        end
        return true
    elseif sCmd == "NEXT" then
        local lArgs = split_string(string.sub(sArgs, 2, -2), "|")
        self:CheckNextStep(iPid, table.unpack(lArgs),oNpc,mArgs)
        return true
    end
end

function CFuben:CheckNextStep(iPid, sCond, oNpc,mArgs)
    local oTask = self:GetTaskObjByStep(iPid)
    if not oTask then return end

    if not oTask:CheckCondition(iPid, sCond) then
        return
    end

    oTask:MissionDone(oNpc,mArgs)

    self.m_iStep = self.m_iStep + 1
    if self.m_iStep > #self:GetGroupList() then
        self:GameOver(iPid)
    end
end

function CFuben:GetTaskByGroup(iGroup)
    local tasklist = res["daobiao"]["fuben"]["taskgroup"][iGroup]["task_list"]
    assert(tasklist,string.format("GetTaskByGroup %s",iGroup))
    local iTask  = extend.Random.random_choice(tasklist)
    return iTask
end
----------------scene mgr---------------
function CFuben:CreateVirtualScene(iIdx)
    if self.m_mSceneIdx2Obj[iIdx] and #self.m_mSceneIdx2Obj[iIdx] >0 then
        return
    end

    local mInfo = self:GetSceneData(iIdx)
    local mData ={
        map_id = mInfo.map_id,
        team_allowed = mInfo.team_allowed,
        deny_fly = mInfo.deny_fly,
        is_durable =mInfo.is_durable==1,
        has_anlei = mInfo.has_anlei == 1,
        url = {"fuben", self:GetName(), "scene", iIdx},
    }
    local oScene = global.oSceneMgr:CreateVirtualScene(mData)
    oScene.fubenname = self.m_sName
    oScene.m_iIdx = iIdx
    oScene:SetCallback("customfly",_CustomFly)
    self.m_mSceneList[oScene:GetSceneId()] = true
    self:InsertScene2IdxTable(oScene)
end

function CFuben:GetSceneObjById(id)
    local oSceneMgr = global.oSceneMgr
    return oSceneMgr:GetScene(id)
end

function CFuben:GetSceneByMapID(iMapID)
    for iSceneID,_ in pairs(self.m_mSceneList)  do
        local oScene = global.oSceneMgr:GetScene(iSceneID)
        if oScene:MapId() == iMapID then
            return oScene
        end
    end
end

function CFuben:RemoveSceneById(id)
    local oScene = self:GetSceneObjById(id)
    if oScene then
        local oSceneMgr = global.oSceneMgr
        oSceneMgr:RemoveScene(id)
        self.m_mSceneList[id] = nil
    end
end

function CFuben:RemoveSceneByIdx(iIdx)
    local lScene = self:GetSceneListByIdx(iIdx)
    for _, iSceneID in ipairs(lScene) do
        self:RemoveSceneById(iSceneID)
    end
end

function CFuben:InsertScene2IdxTable(oScene)
    local iIdx = oScene.m_iIdx
    if not iIdx then return end
    local mData = self.m_mSceneIdx2Obj[iIdx] or {}
    table.insert(mData, oScene:GetSceneId())
    self.m_mSceneIdx2Obj[iIdx] = mData
end

function CFuben:GetSceneListByIdx(iIdx)
    return self.m_mSceneIdx2Obj[iIdx] or {}
end

function CFuben:GetSceneObjByIdx(iIdx, iPos)
    local lScene = self:GetSceneListByIdx(iIdx)
    local iLen = #lScene
    if iLen > 0 then
        iPos = iPos or math.random(iLen)
        return self:GetSceneObjById(lScene[iPos])
    end
end

function CFuben:FormatMsg(iChat, mReplace)
    local oToolMgr = global.oToolMgr
    local sMsg = oToolMgr:GetTextData(iChat, {"fuben"})
    if mReplace then
        sMsg = oToolMgr:FormatColorString(sMsg, mReplace)
    end
    return sMsg
end

function CFuben:ValidEnterTeam(oPlayer,oLeader,iApply)
    local oNotifyMgr = global.oNotifyMgr
    local pid = oPlayer:GetPid()
    local iLeader = oLeader:GetPid()
    local mData = self:GetFubenConfig()
    local mOpen = res["daobiao"]["open"][mData.open_name]
    local LIMIT_GRADE  = mOpen.p_level
    if oPlayer:GetGrade() < LIMIT_GRADE then
        if iApply ==1 then
            oNotifyMgr:Notify(pid,self:FormatMsg(1002,{role=oPlayer:GetName(),grade = LIMIT_GRADE,name = mData.name}))
        elseif iApply == 2 then
            oNotifyMgr:Notify(iLeader,self:FormatMsg(1003,{role=oPlayer:GetName(),grade = LIMIT_GRADE,name = mData.name}))
        end
        return false
    end
    local oTeam = oLeader:HasTeam()
    if oTeam then
        if not oTeam.m_oFubenSure:CheckEnterSure(self.m_iFuben,nil,pid) then
            return false
        end
    end
    return true
end


function CFuben:TransferPlayer(iPid, iMapID, iX, iY)
    local oPlayer = self:GetPlayer(iPid)
    local oScene = self:GetSceneByMapID(iMapID)
    if iMapID == 101000 then
        oScene = global.oSceneMgr:SelectDurableScene(iMapID)
    end
    local lMapList = {600010,600020,600030,600040}
    if extend.Array.find(lMapList,iMapID) then
        iX ,iY = global.oSceneMgr:GetFlyData(iMapID)
    end
    if iX == 0 or iY == 0 then
        iX, iY = global.oSceneMgr:RandomPos2(oScene:MapId())
    end
    local mPos = {x = iX, y = iY}
    global.oSceneMgr:DoTransfer(oPlayer, oScene:GetSceneId(), mPos)
end

------------------reward mgr----------
function CFuben:GameOverReward()
    self:RefreshPoint()
    local mData = self:GetFubenConfig()
    local sLog = ""
    for iPid, _ in pairs(self.m_mMemberList) do
        local oPlayer = self:GetPlayer(iPid)
        if oPlayer then
            local oFubenMgr = oPlayer.m_oBaseCtrl.m_oFubenMgr
            local iFuben = self:GetFubenId()
            local iExpRadio,iSilverRadio,sLevel  = self:GetPointRadio(oPlayer)
            local iExtraExp = self.m_mExp[iPid] or 0
            iExtraExp = math.floor(iExtraExp*iExpRadio/100)
            if iExtraExp>0 then
                local mArgs = {}
                mArgs.bIgnoreFortune =true
                mArgs.bEffect = false
                oPlayer:RewardExp(iExtraExp, mData.fuben_name,mArgs)
            end
            local iExtraSilver = self.m_mSilver[iPid] or 0
            iExtraSilver = math.floor(iExtraSilver*iSilverRadio/100)
            if iExtraSilver>0 then
                oPlayer:RewardSilver(iExtraSilver, mData.fuben_name)
            end
            local mNet = {}
            mNet.fuben = self.m_iFuben
            mNet.exp = self.m_mExp[iPid] or 0
            mNet.expradio = iExpRadio
            mNet.silver = self.m_mSilver[iPid] or 0
            mNet.silverradio = iSilverRadio
            mNet.point = self.m_mPoint[iPid] or 0
            local mItemList={}
            if self.m_mFBItem[iPid] then
                for itemsid,amount in pairs(self.m_mFBItem[iPid]) do
                    table.insert(mItemList,{itemsid = itemsid,amount = amount})
                end
            end
            mNet.itemlist = mItemList
            mNet.level = sLevel
            oPlayer:Send("GS2CFBOver",mNet)
            
            local sSubLog = string.format("fuben=%s\n",extend.Table.serialize(mNet))
            if not is_production_env() then
                global.oChatMgr:HandleMsgChat(oPlayer,sSubLog)
            end
            sLog = sLog .. sSubLog
        end
    end
    local mLogData={
        doneinfo = sLog,
    }
    record.log_db("huodong", "fumo_done",mLogData)
end

function CFuben:GetFixBout2()
    local mData = self:GetFubenConfig()
    local mStandardFix = mData.standard_fix or {}
    local iBout = 0
    for pid,_ in pairs(self.m_mPoint) do
        local oPlayer = self:GetPlayer(pid)
        if oPlayer then
            local iSchool = oPlayer:GetSchool()
            for _, mInfo in pairs(mStandardFix) do
                if mInfo.school == iSchool then
                    iBout = iBout +mInfo.value
                end
            end
        end
    end
    return math.min(5,iBout)
end

function CFuben:RefreshPoint()
    local oChatMgr = global.oChatMgr
    local mData = self:GetFubenConfig()
    local mRelationFix = mData.relation_fix or {}
    for pid , _ in pairs(self.m_mMemberList) do 
        local oPlayer = self:GetPlayer(pid)
        if oPlayer then
            local iOrgid = oPlayer:GetOrgID()
            local iSchool = oPlayer:GetSchool()
            local lFriend = oPlayer:GetFriend():GetFriends()
            local sPid = db_key(pid)
            for target in pairs(self.m_mPoint) do
                if pid ~= target then
                    local iPoint = 0
                    local lPoint = {0}
                    local oTarget = self:GetPlayer(target)
                    if oTarget then
                        if iOrgid ~=0 and iOrgid == oTarget:GetOrgID() then
                            table.insert(lPoint,mRelationFix[1])
                        end
                        if iSchool == oTarget:GetSchool() then
                            table.insert(lPoint,mRelationFix[2])
                        end
                        local lTargetFriend = oTarget:GetFriend():GetFriends()
                        if lFriend[db_key(target)] and lTargetFriend[sPid] then
                            table.insert(lPoint,mRelationFix[4])
                        end
                        iPoint = extend.Array.max(lPoint) 
                        local iPrePoint = self.m_mPoint[pid]
                        self.m_mPoint[pid] = self.m_mPoint[pid]+ iPoint
                        if not is_production_env() then
                            oChatMgr:HandleMsgChat(oPlayer,string.format("评分加成%s = %s+%s",self.m_mPoint[pid],iPrePoint,iPoint))
                        end
                    end
                end
            end
        end
    end
end

function CFuben:GetPointRadio(oPlayer)
    local mData = self:GetFubenConfig()
    local mPointReward = mData.point_reward or {}
    local pid = oPlayer:GetPid()
    local iPoint = self.m_mPoint[pid] or 0
    for _,mInfo in ipairs(mPointReward) do
        if iPoint<=mInfo.point then
            return mInfo.exp_radio,mInfo.silver_radio,mInfo.level
        end
    end
    local mInfo = mPointReward[#mPointReward]
    return mInfo.exp_radio,mInfo.silver_radio,mInfo.level
end

function CFuben:GetRewardEnv(oAwardee)
    local iServerGrade = global.oWorldMgr:GetServerGrade()
    if oAwardee and oAwardee.GetServerGrade then
        iServerGrade = oAwardee:GetServerGrade()
    end
    local iExpRadio ,iSilverRadio,_ = self:GetPointRadio(oAwardee)
    return {
        lv = oAwardee:GetGrade(),
        SLV = iServerGrade,
        fb_silver_radio = iExpRadio ,
        fb_exp_radio = iSilverRadio,
    }
end

function CFuben:AddTotalBout(iBout, lPlayer)
    self.m_iWarCount = self.m_iWarCount +1
    local oChatMgr = global.oChatMgr
    local iPreBout = iBout
    local iFixBout = self:GetFixBout2()
    iBout = math.max(1,iBout - iFixBout )
    local mData = self:GetFubenConfig()
    local mBoutPoint = mData.boutpoint or {}
    local iValue = 0
    for index, mInfo in ipairs(mBoutPoint) do
        if iBout<mInfo.bout then
            iValue = mInfo.point
            break
        end
    end
    local sScheduleFlag = string.format("%s_schedule",self.m_sName)
    for _, pid in ipairs(lPlayer) do
        local oPlayer = self:GetPlayer(pid)
        local iPoint = self.m_mPoint[pid] or 0
        self.m_mPoint[pid] = iPoint+iValue
        if oPlayer and not is_production_env() then
            oChatMgr:HandleMsgChat(oPlayer,string.format("副本回合数加成 %s = %s +%s\n 修正回合数:最终:%s 初始:%s 修正:%s",self.m_mPoint[pid],iPoint ,iValue,iBout,iPreBout,iFixBout))
        end
        if oPlayer then
            if oPlayer.m_oTodayMorning:Query(sScheduleFlag,0) ==0 then
                oPlayer.m_oTodayMorning:Set(sScheduleFlag,1)
                oPlayer.m_oScheduleCtrl:Add(mData.schedule)
            end
        end
    end
end

function CFuben:CheckNotifySSS()
    local oNotifyMgr = global.oNotifyMgr
    local mData = self:GetFubenConfig()
    local mPointReward = mData.point_reward or {}
    local mInfo = mPointReward[#mPointReward]
    for pid,iPoint in pairs(self.m_mPoint) do
        if not self.m_mNotifySSS[pid]  and iPoint>mInfo.point then
            oNotifyMgr:Notify(pid,"恭喜你获的最高评级：SSS")
            self.m_mNotifySSS[pid] = true
        end
    end
end

function CFuben:OnLogin(oPlayer, bReEnter)
end

function CFuben:OnLogout(oPlayer)
    self.m_oMemberMgr:OnLogout(oPlayer)
end

function CFuben:OnLeaveTeam(pid,iFlag)
    if iFlag == 1 or iFlag == 4 then
        self.m_mMemberList[pid] = nil
        self.m_mPoint[pid] = nil
    end
end

function CFuben:OnEnterTeam(pid,iFlag)
    local iOwner = self:GetOwner()
    if iFlag == 1 or iFlag == 3 then
        if iOwner then 
            self.m_mMemberList[pid] = 1
            self.m_mPoint[pid] = self.m_mPoint[iOwner]
        else
            self.m_mMemberList[pid] = 1
            self.m_mPoint[pid] = {0,0}
        end
    end
end

function CFuben:GetPlayer(iPid)
    local oWorldMgr = global.oWorldMgr
    return oWorldMgr:GetOnlinePlayerByPid(iPid)
end

function CFuben:GetFubenConfig(iFuben)
    iFuben = iFuben or self.m_iFuben
    return res["daobiao"]["fuben"]["fuben_config"][iFuben]
end

function CFuben:GetFubenTable()
    local sName = self:GetName()
    return res["daobiao"]["fuben"][sName]
end

function CFuben:GetEventData(iEvent)
    local mData = self:GetFubenTable()
    return mData["event"][iEvent]
end

function CFuben:GetSceneData(iScene)
    local mData = self:GetFubenTable()
    return mData["scene"][iScene]
end

function CFuben:GetTextData(iText)
    local oToolMgr = global.oToolMgr
    return oToolMgr:GetTextData(iText, {"fuben", self:GetName()})
end

function CFuben:AddFBExp(pid,iExp)
    self.m_mExp[pid] = self.m_mExp[pid] or 0
    local iPreExp = self.m_mExp[pid]
    self.m_mExp[pid] = self.m_mExp[pid] + iExp
    if not is_production_env() then
        local oPlayer = global.oWorldMgr:GetOnlinePlayerByPid(pid)
        if oPlayer then
            global.oChatMgr:HandleMsgChat(oPlayer,string.format("副本经验累计:%s = %s  +%s",self.m_mExp[pid],iPreExp,iExp))
        end
    end
end

function CFuben:AddFBSilver(pid,iSilver)
    self.m_mSilver[pid] = self.m_mSilver[pid] or 0
    local iPreSilver = self.m_mSilver[pid]
    self.m_mSilver[pid] = self.m_mSilver[pid] + iSilver
    if not is_production_env() then
        local oPlayer = global.oWorldMgr:GetOnlinePlayerByPid(pid)
        if oPlayer then
            global.oChatMgr:HandleMsgChat(oPlayer,string.format("副本银币累计:%s = %s  +%s",self.m_mSilver[pid],iPreSilver,iSilver))
        end
    end
end

function CFuben:AddFBItem(pid,mItem)
    self.m_mFBItem[pid] = self.m_mFBItem[pid] or {}
    for itemsid ,iAmount in pairs(mItem) do
        if not self.m_mFBItem[pid][itemsid] then
            self.m_mFBItem[pid][itemsid] =0
        end
        self.m_mFBItem[pid][itemsid] = self.m_mFBItem[pid][itemsid] +iAmount
    end
    if not is_production_env() then
        local oPlayer = global.oWorldMgr:GetOnlinePlayerByPid(pid)
        if oPlayer then
            global.oChatMgr:HandleMsgChat(oPlayer,string.format("副本道具累计:\n获得之后:\n%s\n获得的道具\n%s",extend.Table.serialize(self.m_mFBItem[pid]),extend.Table.serialize(mItem)))
        end
    end 
end

function CFuben:GetWarCount( )
    return self.m_iWarCount or 0
end

function NewFubenNpc(idx, mArgs)
    local oNpc = CFubenNpc:New(mArgs)
    oNpc.m_iIdx = idx
    return oNpc
end

CFubenNpc = {}
CFubenNpc.__index = CFubenNpc
inherit(CFubenNpc, huodongbase.CHDNpc)

function CFubenNpc:Release()
    self.m_oTaskObj = nil
    super(CFubenNpc).Release(self)
end

function CFubenNpc:GetEventData(iEvent)
    return self.m_oTaskObj:GetEventData(iEvent)
end

function CFubenNpc:do_look(oPlayer)
    if self.m_oTaskObj then
        self.m_oTaskObj:do_look(oPlayer, self)
    end
end


function _CustomFly(mData)
    local oPlayer = mData.player
    local iMap = mData.map
    local oTeam = oPlayer:HasTeam()
    if oTeam then
        local oFuben = oTeam:GetFuben()
        if oFuben and iMap then
            if oFuben:GetSceneByMapID(iMap) then
                return false
            end
        end
        global.oNotifyMgr:Notify(oPlayer:GetPid(),"请离开队伍再操作")
        return true
    end
    return false
end


