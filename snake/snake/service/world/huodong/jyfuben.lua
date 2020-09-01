local global  = require "global"
local res = require "base.res"
local extend = require "base.extend"
local record = require "public.record"
local interactive = require "base.interactive"

local gamedefines = import(lualib_path("public.gamedefines"))
local huodongbase = import(service_path("huodong.huodongbase"))
local tableop = import(lualib_path("base.tableop"))
local taskdefines = import(service_path("task/taskdefines"))


local LIMIT_SIZE = 3
local LIMIT_FLOOR = 4
local LIMIT_REWARD = 1

function NewHuodong(sHuodongName)
    return CHuodong:New(sHuodongName)
end

CHuodong = {}
CHuodong.__index = CHuodong
CHuodong.m_sTempName = "精英副本"
inherit(CHuodong, huodongbase.CHuodong)

function CHuodong:New(sHuodongName)
    local o = super(CHuodong).New(self, sHuodongName)
    o.m_mScene = {}
    o.m_mPoint = {}
    o.m_mBackPoint = {}
    o.m_iScheduleID = 1010
    return o
end

function CHuodong:NewHour(mNow)
    self:RemoveScene()
end

function CHuodong:CreateScene(iTeam)
    if self.m_mScene[iTeam] then 
        return 
    end
    self.m_mScene[iTeam] = {}
    local oSceneMgr = global.oSceneMgr
    local mRes = res["daobiao"]["huodong"]["jyfuben"]["scene"]
    for iIndex , mInfo in pairs(mRes) do
        local mData ={
        map_id = mInfo.map_id,
        url = {"huodong", "jyfuben", "scene", iIndex},
        team_allowed = mInfo.team_allowed,
        deny_fly = mInfo.deny_fly,
        is_durable =mInfo.is_durable==1,
        has_anlei = mInfo.has_anlei == 1,
        }
        local oScene = oSceneMgr:CreateVirtualScene(mData)
        oScene.m_HDName = self.m_sName
        self.m_mScene[iTeam][oScene:MapId()] =  oScene:GetSceneId()
    end
end

function CHuodong:GetSceneByMapID(pid,iMapId)
    local oPlayer = global.oWorldMgr:GetOnlinePlayerByPid(pid)
    local oTeam = oPlayer:HasTeam()
    local iTeamID = oTeam:TeamID()
    if not self.m_mScene[iTeamID] then
        self:CreateScene(iTeamID)
    end
    local iSceneId = self.m_mScene[iTeamID][iMapId]
    if not iSceneId then
        return 
    else
        local oScene = global.oSceneMgr:GetScene(iSceneId)
        return oScene
    end
end

function CHuodong:RemoveScene()
    local oSceneMgr = global.oSceneMgr
    local oTeamMgr = global.oTeamMgr
    for iTeamID,lScene in pairs(self.m_mScene) do
        if not oTeamMgr:GetTeam(iTeamID) then
            for _,iSceneId in ipairs(lScene) do
                oSceneMgr:RemoveScene(iSceneId)
            end
        end
    end
end

function CHuodong:ValidJoin(oPlayer)
    local LIMIT_GRADE = res["daobiao"]["open"]["JYFUBEN"]["p_level"]
    local pid = oPlayer:GetPid()
    local oTeam = oPlayer:HasTeam()
    local oNotifyMgr = global.oNotifyMgr
    if not oTeam or oTeam:MemberSize() < LIMIT_SIZE then
        oNotifyMgr:Notify(pid,self:GetFormatText(1002))
        return false
    end
    if not oTeam:IsLeader(pid) then
        return false
    end
    local lName = {}
    for _,oMem in ipairs(oTeam:GetMember()) do
        if oMem:GetGrade()<LIMIT_GRADE then
            table.insert(lName,oMem:GetName())
        end
    end
    if #lName > 0 then
        local sName = table.concat(lName,",")
        oNotifyMgr:Notify(pid,self:GetFormatText(1001,{role = sName,amount = LIMIT_GRADE}))
        return false
    end
    if not global.oToolMgr:IsSysOpen("JYFUBEN",oPlayer) then   
        return false
    end
    if not oTeam.m_oJYFubenSure:CheckEnterSure() then
        return
    end
    local oNowScene = oPlayer.m_oActiveCtrl:GetNowScene()
    if not oNowScene:ValidLeave(oPlayer) then
        return false
    end
    return true
end

function CHuodong:JoinGame(oPlayer)
    local oTeam = oPlayer:HasTeam()
    if oTeam then
        oTeam.m_oJYFubenSure:AutoEnterSure()
    end
    if not self:ValidJoin(oPlayer) then
        return 
    end
    local oTeam = oPlayer:HasTeam()
    local pid = oPlayer:GetPid()
    if oTeam:HasTaskKind(taskdefines.TASK_KIND.JYFUBEN) then
        local oTask = oTeam:HasTaskKind(taskdefines.TASK_KIND.JYFUBEN)
        oTask:TransferClick(oPlayer)
    else
        oTeam.m_JYTask = nil
        local iTask,iTrueFloor = self:GetFloorTask(oPlayer)
        oTeam:NextTask(nil,iTask)
        local oTask = oTeam:GetTask(iTask)
        if oTask then
            oTask.m_iTrueFloor = iTrueFloor
            oTask:Refresh({ext_apply_info=true})
            oTask:TransferClick(oPlayer)
            self:InitTeamPoint(oTeam)
            local sFloorName = self:GetFloorName(iTask)
            for _,oMem in pairs(oTeam:GetMember()) do
                local oTarget = global.oWorldMgr:GetOnlinePlayerByPid(oMem.m_ID)
                if oTarget then
                    oTarget:Send("GS2CJYFubenFloorName",{name = sFloorName,floor = iTrueFloor })
                end
            end
        end
    end
end

function CHuodong:GetFloorTask(oLeader)
    local pid = oLeader:GetPid()
    local oNotifyMgr = global.oNotifyMgr
    local oTeam = oLeader:HasTeam()
    local lCurFinish = oTeam.m_JYTask or {}
    local lTrueFinish = oLeader.m_oTodayMorning:Query("jyfuben",{})
    local iNextFloor = #lCurFinish+1
    local iTrueFloor = nil
    if #lTrueFinish>0 then
        if lTrueFinish[iNextFloor] then
            iTrueFloor = lTrueFinish[iNextFloor]
        end
    end
    if not iTrueFloor then
        local mRes = res["daobiao"]["jyfuben"]["grouptask"]
        local mRadio = {}
        for iFloor,mInfo in pairs(mRes) do
            if not extend.Array.find(lCurFinish,iFloor) then
                mRadio[iFloor] = mInfo.radio
            end
        end
        if table_count(mRadio)>0 then
            iTrueFloor  = extend.Random.choosekey(mRadio)
        end
    end
    if oLeader.m_iTestFloor then
        iTrueFloor = oLeader.m_iTestFloor
    end
    assert(iTrueFloor,string.format("%s %s %s",pid,extend.Table.serialize(lTrueFinish),extend.Table.serialize(lCurFinish)))
    local iTask = res["daobiao"]["jyfuben"]["grouptask"][iTrueFloor]["tasklist"][1]
    --print("cg_debug GetFloorTask",iTrueFloor,iTask,lTrueFinish,lCurFinish)
    return iTask,iNextFloor
end

function CHuodong:GetCurFloor(oTeam)
    local lCurFinish = oTeam.m_JYTask or {}
    return #lCurFinish+1
end

function CHuodong:FloorEnd(oTeam,iTask)
    if not oTeam then return end
    if not self:ValidTask(iTask) then return end
    local iFloor = self:GetFloorByTask(iTask)
    if not iFloor then return end
    local oWorldMgr = global.oWorldMgr
    local oLeader = oTeam:GetLeaderObj()
    local lCurFinish = oTeam.m_JYTask or {}
    if not extend.Array.find(lCurFinish,iFloor) then
        table.insert(lCurFinish,iFloor)
        oTeam.m_JYTask = lCurFinish
        local iReward
        if res["daobiao"]["jyfuben"]["floorreward"][#lCurFinish] then
            iReward = res["daobiao"]["jyfuben"]["floorreward"][#lCurFinish]["reward"]
        end
        local iTeamSize = #oTeam:GetMember()
        for _,oMem in ipairs(oTeam:GetMember()) do
            local oTarget = oWorldMgr:GetOnlinePlayerByPid(oMem.m_ID)
            if oTarget then
                local sRewardFlag = string.format("jyreward_%s",#lCurFinish)
                local iRewardAmount = oTarget.m_oTodayMorning:Query(sRewardFlag,0)
                if iRewardAmount < LIMIT_REWARD then
                    oTarget.m_oTodayMorning:Set(sRewardFlag,iRewardAmount+1)
                    if iReward then
                        self:Reward(oMem.m_ID,iReward)
                        self:RewardLeaderPoint(oTarget,"jyfuben","精英副本",iTeamSize)
                    end
                else
                    self:RewardXiayiPoint(oTarget,"jyfuben","精英副本")
                end
            end
        end
    end
    self:NextFloor(oTeam)
end

function CHuodong:NextFloor(oTeam)
    local oLeader = oTeam:GetLeaderObj()
    local lTrueFinish = oLeader.m_oTodayMorning:Query("jyfuben",{})
    local lCurFinish = oTeam.m_JYTask or {}
    local mRes = res["daobiao"]["jyfuben"]["grouptask"]
    local mRadio = {}
    local bFinish = true
    if #lCurFinish<LIMIT_FLOOR then
        bFinish = false 
    else
        bFinish = true
    end

    if bFinish then
        if #lTrueFinish <=0 then
            oLeader.m_oTodayMorning:Set("jyfuben",lCurFinish)
        end
        oTeam.m_JYTask = nil
        global.oSceneMgr:TeamEnterDurableScene(oLeader)
        self:GameOver(oTeam)
    else
        local iTask,iTrueFloor = self:GetFloorTask(oLeader)
        oTeam:NextTask(nil,iTask)
        local oTask = oTeam:GetTask(iTask)
        if oTask then
            oTask.m_iTrueFloor = iTrueFloor
            oTask:Refresh({ext_apply_info=true})
            oTask:TransferClick(oLeader)
            local sFloorName = self:GetFloorName(iTask)
            
            for _,oMem in pairs(oTeam:GetMember()) do
                local oTarget = global.oWorldMgr:GetOnlinePlayerByPid(oMem.m_ID)
                if oTarget then
                    oTarget:Send("GS2CJYFubenFloorName",{name = sFloorName,floor = iTrueFloor })
                end
            end
        end
    end
end

function CHuodong:ValidTask(iTask)
    local mRes = res["daobiao"]["jyfuben"]["grouptask"]
    for _,mInfo in pairs(mRes) do
        for _,task in ipairs(mInfo.tasklist) do
            if task == iTask then
                return true
            end
        end
    end
end

function CHuodong:GetFloorByTask(iTask)
    local mRes = res["daobiao"]["jyfuben"]["grouptask"]
    for id,mInfo in pairs(mRes) do
        for _,task in ipairs(mInfo.tasklist) do
            if task == iTask then
                return id
            end
        end
    end
end

function CHuodong:GetFloorName(iTask)
    local mRes = res["daobiao"]["jyfuben"]["grouptask"]
    for id,mInfo in pairs(mRes) do
        for _,task in ipairs(mInfo.tasklist) do
            if task == iTask then
                return mInfo.name
            end
        end
    end
end

function CHuodong:GetTaskByCurTask(iFinishTask)
    local mRes = res["daobiao"]["jyfuben"]["grouptask"]
    for _,mInfo in pairs(mRes) do
        for id,task in ipairs(mInfo.tasklist) do
            if task == iFinishTask then
                if mInfo.tasklist[id+1] then
                    return mInfo.tasklist[id+1]
                end
            end
        end
    end
end

function CHuodong:GetFormatText(iText,mReplace)
    local oToolMgr = global.oToolMgr
    local sText = self:GetTextData(iText)
    sText = oToolMgr:FormatColorString(sText,mReplace)
    return sText
end

function CHuodong:ValidEnterTeam(oPlayer,oLeader,iApply)
    local oNotifyMgr = global.oNotifyMgr
    local pid = oPlayer:GetPid()
    local iLeader = oLeader:GetPid()
    local LIMIT_GRADE = res["daobiao"]["open"]["JYFUBEN"]["p_level"]
    if oPlayer:GetGrade() < LIMIT_GRADE then
        if iApply ==1 then
            oNotifyMgr:Notify(pid,self:GetFormatText(1004,{grade = LIMIT_GRADE}))
        elseif iApply == 2 then
            oNotifyMgr:Notify(iLeader,self:GetFormatText(1005,{grade = LIMIT_GRADE}))
        end
        return false
    end
    local oTeam = oLeader:HasTeam()
    if oTeam then
        if not oTeam.m_oJYFubenSure:CheckEnterSure(pid) then
            return false
        end
    end
    return true
end

function CHuodong:OnLeaveTeam(oPlayer,flag,iTeamID)
    if not self.m_mPoint[iTeamID] then 
        return
    end
    if flag ~= 1 then
        return
    end
    local oNowScene = oPlayer.m_oActiveCtrl:GetNowScene()
    local iMapId = oNowScene:MapId()
    local mRes = res["daobiao"]["huodong"]["jyfuben"]["scene"]
    for _,mInfo in pairs(mRes) do
        if mInfo.map_id == iMapId then
            global.oSceneMgr:EnterDurableScene(oPlayer)
            break
        end
    end
    if self.m_mPoint[iTeamID][pid] then
        self.m_mPoint[iTeamID][pid] = nil
        if table_count(self.m_mPoint[iTeamID]) <= 0 then
            self.m_mPoint[iTeamID] = nil
        end
    end
end

function CHuodong:OnEnterTeam(pid,flag,oTeam)
    local iTeamID = oTeam:TeamID()
    if not self.m_mPoint[iTeamID] then 
        return
    end
    if not  self.m_mPoint[iTeamID][iLeader] then 
        return
    end
    if not self.m_mPoint[iTeamID][pid] then
        self.m_mPoint[iTeamID][pid] = {}
    end
    if self.m_mPoint[iLeader]["bout"] then
        self.m_mPoint[iTeamID][pid]["bout"] = self.m_mPoint[iTeamID][iLeader]["bout"]
    end
end


--收益--
function CHuodong:InitTeamPoint(oTeam)
    local iTeamID = oTeam:TeamID()
    if not self.m_mPoint[iTeamID] then
        self.m_mPoint[iTeamID] = {}
    end
end

function CHuodong:GetFixBout(oTeam,iBout)
    local mRes = res["daobiao"]["huodong"]["jyfuben"]["clientconfig"][1]
    local iMaxCutBout = mRes["max_cut_bout"]
    local mSchoolBout = mRes["school_bout"]
    local iCutBout = 0

    local lMember = oTeam:GetMember()
    for _,oMem in ipairs(lMember) do
        local iSchool = oMem:GetSchool()
        if mSchoolBout[iSchool] then
            iCutBout = iCutBout + mSchoolBout[iSchool]["bout"]
        end
    end
    iCutBout = math.min(iCutBout,iMaxCutBout)
    iBout = iBout -iCutBout
    iBout = math.max(iBout,1)
    return iBout
end

function CHuodong:AddJYFBBout(oTeam,iBout)
    local iTeamID = oTeam:TeamID()
    if not self.m_mPoint[iTeamID] then
        return
    end
    iBout = self:GetFixBout(oTeam,iBout)
    local iPoint = 0
    local mRes = res["daobiao"]["huodong"]["jyfuben"]["clientconfig"][1]
    local mBoutPoint = mRes["boutpoint"]
    for index, mInfo in ipairs(mBoutPoint) do
        if iBout<mInfo.bout then
            iPoint = mInfo.point
            break
        end
    end

    for _,oMem in ipairs(oTeam:GetMember()) do
        local pid = oMem.m_ID
        if not self.m_mPoint[iTeamID][pid] then
            self.m_mPoint[iTeamID][pid] = {}
        end
        if not self.m_mPoint[iTeamID][pid]["bout"] then
            self.m_mPoint[iTeamID][pid]["bout"] = 0
        end
        local iPreBout = self.m_mPoint[iTeamID][pid]["bout"]
        self.m_mPoint[iTeamID][pid]["bout"] = self.m_mPoint[iTeamID][pid]["bout"] + iBout
        self:AddJYFBPoint(iTeamID,pid,iPoint)
        if not is_production_env() then
            local oPlayer = global.oWorldMgr:GetOnlinePlayerByPid(pid)
            if oPlayer then
                global.oChatMgr:HandleMsgChat(oPlayer,string.format("%s回合增加:%s = %s +%s",self.m_sTempName,self.m_mPoint[iTeamID][pid]["bout"],iPreBout,iBout))
            end
        end
        local oTarget = global.oWorldMgr:GetOnlinePlayerByPid(pid) 
        if oTarget then
            local sScheduleFlag = string.format("%s_schedule",self.m_sName)
            if oTarget.m_oTodayMorning:Query(sScheduleFlag,0) ==0 then
                oTarget.m_oTodayMorning:Set(sScheduleFlag,1)
                self:AddSchedule(oTarget)
            end
        end
    end
end

function CHuodong:GetJYFBBout(iTeamID,pid,mPointData)
    local mData = self.m_mPoint[iTeamID]
    if mPointData then
        mData = mPointData
    end
    local iBout = 0
    if mData and mData[pid] and mData[pid]["bout"] then
        iBout = mData[pid]["bout"]
    end
    return iBout
end

function CHuodong:AddJYFBPoint(iTeamID,pid,iPoint)
    if not self.m_mPoint[iTeamID] then
        return
    end
    if not self.m_mPoint[iTeamID][pid] then
        self.m_mPoint[iTeamID][pid] = {}
    end
    if not self.m_mPoint[iTeamID][pid]["point"] then
        self.m_mPoint[iTeamID][pid]["point"] = 0
    end
    local iPrePoint = self.m_mPoint[iTeamID][pid]["point"]
    self.m_mPoint[iTeamID][pid]["point"] = self.m_mPoint[iTeamID][pid]["point"] + iPoint
    if not is_production_env() then
        local oPlayer = global.oWorldMgr:GetOnlinePlayerByPid(pid)
        if oPlayer then
            global.oChatMgr:HandleMsgChat(oPlayer,string.format("%s评分累计:%s = %s +%s",self.m_sTempName,self.m_mPoint[iTeamID][pid]["point"],iPrePoint,iPoint))
        end
    end
end

function CHuodong:GetJYFBPoint(iTeamID,pid,mPointData)
    local mData = self.m_mPoint[iTeamID]
    if mPointData then
        mData = mPointData
    end
    local iPoint = 0
    if mData and mData[pid] and mData[pid]["point"] then
        iPoint = mData[pid]["point"]
    end
    return iPoint
end

function CHuodong:AddJYFBExp(iTeamID,pid,iExp)
    if not self.m_mPoint[iTeamID] then
        return
    end
    if not self.m_mPoint[iTeamID][pid] then
        self.m_mPoint[iTeamID][pid] = {}
    end
    if not self.m_mPoint[iTeamID][pid]["exp"] then
        self.m_mPoint[iTeamID][pid]["exp"] = 0
    end
    local iPreExp = self.m_mPoint[iTeamID][pid]["exp"]
    self.m_mPoint[iTeamID][pid]["exp"] = self.m_mPoint[iTeamID][pid]["exp"] + iExp
    if not is_production_env() then
        local oPlayer = global.oWorldMgr:GetOnlinePlayerByPid(pid)
        if oPlayer then
            global.oChatMgr:HandleMsgChat(oPlayer,string.format("%s经验累计:%s = %s +%s",self.m_sTempName,self.m_mPoint[iTeamID][pid]["exp"],iPreExp,iExp))
        end
    end
end

function CHuodong:GetJYFBExp(iTeamID,pid,mPointData)
    local mData = self.m_mPoint[iTeamID]
    if mPointData then
        mData = mPointData
    end
    local iExp = 0
    if mData and mData[pid] and mData[pid]["exp"] then
        iExp = mData[pid]["exp"]
    end
    return iExp
end

function CHuodong:AddJYFBSilver(iTeamID,pid,iSilver)
    if not self.m_mPoint[iTeamID] then
        return
    end
    if not self.m_mPoint[iTeamID][pid] then
        self.m_mPoint[iTeamID][pid] = {}
    end
    if not self.m_mPoint[iTeamID][pid]["silver"] then
        self.m_mPoint[iTeamID][pid]["silver"] = 0
    end
    local iPreSilver = self.m_mPoint[iTeamID][pid]["silver"]
    self.m_mPoint[iTeamID][pid]["silver"] = self.m_mPoint[iTeamID][pid]["silver"] + iSilver
    if not is_production_env() then
        local oPlayer = global.oWorldMgr:GetOnlinePlayerByPid(pid)
        if oPlayer then
            global.oChatMgr:HandleMsgChat(oPlayer,string.format("%s银币累计:%s = %s +%s",self.m_sTempName,self.m_mPoint[iTeamID][pid]["silver"],iPreSilver,iSilver))
        end
    end
end

function CHuodong:GetJYFBSilver(iTeamID,pid,mPointData)
    local mData = self.m_mPoint[iTeamID]
    if mPointData then
        mData = mPointData
    end
    local iSilver = 0
    if mData and mData[pid] and mData[pid]["silver"] then
        iSilver = mData[pid]["silver"]
    end
    return iSilver

end

function CHuodong:AddJYFBItem(iTeamID,pid,mItem)
    if not self.m_mPoint[iTeamID] then
        return
    end
    if not self.m_mPoint[iTeamID][pid] then
        self.m_mPoint[iTeamID][pid] = {}
    end
    if not self.m_mPoint[iTeamID][pid]["item"] then
        self.m_mPoint[iTeamID][pid]["item"] = {}
    end
    for itemsid ,iAmount in pairs(mItem) do
        if not self.m_mPoint[iTeamID][pid]["item"][itemsid] then
            self.m_mPoint[iTeamID][pid]["item"][itemsid] =0
        end
        self.m_mPoint[iTeamID][pid]["item"][itemsid] = self.m_mPoint[iTeamID][pid]["item"][itemsid] +iAmount
    end
    if not is_production_env() then
        local oPlayer = global.oWorldMgr:GetOnlinePlayerByPid(pid)
        if oPlayer then
            global.oChatMgr:HandleMsgChat(oPlayer,string.format("%s道具累计:\n获得之后:\n%s\n获得的道具\n%s\n",self.m_sTempName,extend.Table.serialize(self.m_mPoint[iTeamID][pid]["item"]),extend.Table.serialize(mItem)))
        end
    end 
end

function CHuodong:GetJYFBItem(iTeamID,pid,mPointData)
    local mData = self.m_mPoint[iTeamID]
    if mPointData then
        mData = mPointData
    end
    local mItem = {}
    if mData and mData[pid] and mData[pid]["item"] then
        mItem = mData[pid]["item"]
    end
    return mItem
end

function CHuodong:RewardExp(oPlayer, iExp)
    local mArgs = {}
    mArgs.iLeaderExp = nil
    if oPlayer:IsTeamLeader() then
        local iRatio = oPlayer.m_oStateCtrl:GetLeaderExpRaito(self.m_sName, oPlayer:GetMemberSize())
        mArgs.iLeaderRatio = iRatio
        mArgs.iAddexpRatio = iRatio
    end
    super(CHuodong).RewardExp(self, oPlayer, iExp, mArgs)
    local oTeam = oPlayer:HasTeam()
    if oTeam then
        self:AddJYFBExp(oTeam:TeamID(),oPlayer:GetPid(),iExp)
    end
end

function CHuodong:RewardSilver(oPlayer, iSilver, mArgs)
    super(CHuodong).RewardSilver(self, oPlayer, iSilver, mArgs)
    local oTeam = oPlayer:HasTeam()
    if oTeam then
        self:AddJYFBSilver(oTeam:TeamID(),oPlayer:GetPid(),iSilver)
    end
end

function CHuodong:SendRewardContent(oPlayer, mRewardContent, mArgs)
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
    local oTeam = oPlayer:HasTeam()
    if oTeam  then
        self:AddJYFBItem(oTeam:TeamID(),oPlayer:GetPid(),mItem)
    end
    super(CHuodong).SendRewardContent(self, oPlayer, mRewardContent, mArgs)
end

--收益--
function CHuodong:GameOver(oTeam)
    local oWorldMgr = global.oWorldMgr
    local lPlist = {}
    local iTeamID = oTeam:TeamID()
    for _,oMem in ipairs(oTeam:GetMember()) do
        table.insert(lPlist,oMem.m_ID)
    end

    for _,pid in ipairs(lPlist) do
        local oPlayer = oWorldMgr:GetOnlinePlayerByPid(pid)
        if oPlayer then
            oPlayer:MarkGrow(37)
            local mNet = self:PackAllInfo(oPlayer,lPlist,iTeamID)
            mNet.open = 1
            oPlayer:Send("GS2CJYFBGameOver",mNet)
        end
    end

    local sFlag = string.format("GameOver_%s",iTeamID)
    local mPointData = self.m_mPoint[iTeamID] or {}
    self.m_mPoint[iTeamID] = nil
    self:AddTimeCb(sFlag,15*1000,function ()
        self:GameOver2(iTeamID,lPlist,mPointData)
    end)

    local oPlayer = oTeam:GetLeaderObj()
    local oMentoring = global.oMentoring
    if oPlayer and oMentoring then
        safe_call(oMentoring.AddStepResultCnt, oMentoring, oPlayer, 11, 1)
    end
end

function CHuodong:PackAllInfo(oPlayer,lPlist,iTeamID,mPointData)
    local oWorldMgr = global.oWorldMgr
    local mRes = res["daobiao"]["huodong"]["jyfuben"]["clientconfig"][1]
    local mFriendRes = mRes["friend_add"]
    local mOrgRes = mRes["org_add"]
    local pid = oPlayer:GetPid()
    local sPid = db_key(pid)
    local lFriend = oPlayer:GetFriend():GetFriends()
    local iFriendCnt = 0
    local iOrgID = oPlayer:GetOrgID()
    local iOrgIDCnt = 0

    local iPoint = 0
    local mNet = {}
    iPoint = self:GetJYFBPoint(iTeamID,pid,mPointData)

    for _, target in ipairs(lPlist) do
        if target == pid then
            goto continue
        end
        local oTarget = oWorldMgr:GetOnlinePlayerByPid(target)
        if not oTarget then
            goto continue
        end
        local lTargetFriend = oTarget:GetFriend():GetFriends()
        if lFriend[db_key(target)] and lTargetFriend[sPid] then
            iFriendCnt = iFriendCnt +1
        end
        if iOrgID ~= 0 and oTarget:GetOrgID() == iOrgID then
            iOrgIDCnt = iOrgIDCnt +1
        end
        ::continue::
    end
    if mFriendRes[iFriendCnt] then
        iPoint = iPoint + mFriendRes[iFriendCnt]["point"]
    end
    if mOrgRes[iOrgIDCnt] then
        iPoint = iPoint + mOrgRes[iOrgIDCnt]["point"]
    end


    mNet.exp = self:GetJYFBExp(iTeamID,pid,mPointData)
    mNet.silver = self:GetJYFBSilver(iTeamID,pid,mPointData)
    local mItem = self:GetJYFBItem(iTeamID,pid,mPointData)
    local lItem = {}
    for itemsid , iAmount  in pairs(mItem) do
        table.insert(lItem,{itemsid = itemsid,amount = iAmount})
    end
    mNet.itemlist = lItem
    mNet.point  = iPoint
    return mNet
end

function CHuodong:GameOver2(iTeamID,lPlist,mPointData)
    local oWorldMgr = global.oWorldMgr
    local sFlag = string.format("GameOver_%s",iTeamID)
    self:DelTimeCb(sFlag)
    for _,pid in ipairs(lPlist) do
        local oPlayer = oWorldMgr:GetOnlinePlayerByPid(pid)
        if oPlayer then
            local mNet = self:PackAllInfo(oPlayer,lPlist,iTeamID,mPointData)
            mNet.open = 0
            local mRadioData = self:GetPointRadio(mNet.point)
            local iExtraExp = mNet.exp
            local iExpRadio = mRadioData.expradio
            iExtraExp = math.floor(iExtraExp*iExpRadio/100)
            if iExtraExp>0 then
                oPlayer:RewardExp(iExtraExp, self.m_sName)
            end
            local iExtraSilver = mNet.silver
            local iSilverRadio = mRadioData.silverradio
            iExtraSilver = math.floor(iExtraSilver*iSilverRadio/100)
            if iExtraSilver>0 then
                oPlayer:RewardSilver(iExtraSilver, self.m_sName)
            end
            mNet.expradio = iExpRadio
            mNet.silverradio = iSilverRadio
            oPlayer:Send("GS2CJYFBGameOver",mNet)
        end
    end
end

function CHuodong:GetPointRadio(iPoint)
    local mRes = res["daobiao"]["huodong"]["jyfuben"]["clientconfig"][1]
    local mPointReward = mRes["point_reward"]
    local mTrueInfo = mPointReward[#mPointReward]
    for _,mInfo in ipairs(mPointReward) do
        if iPoint<=mInfo.point then
            mTrueInfo = mInfo
        end
    end
    local mData = {}
    mData.expradio = mTrueInfo.exp_radio
    mData.silverradio = mTrueInfo.silver_radio
    return mData
end

function CHuodong:TestOp(iFlag, arg)
    local oNotifyMgr = global.oNotifyMgr
    local oChatMgr = global.oChatMgr
    local pid = arg[#arg]
    local oWorldMgr = global.oWorldMgr
    local oPlayer = oWorldMgr:GetOnlinePlayerByPid(pid)
    
    local mCommand={
        "100 指令查看",
        "101 清除精英副本进度\nhuodongop jyfuben 101",
        "102 清除奖励限制\nhuodongop jyfuben 102",
        "103 设置获得指定关卡\nhuodongop jyfuben 103 {floor = 1} ",
        "104 清除获得指定关卡\nhuodongop jyfuben 104",
        "105 清除日程活跃标记\nhuodongop jyfuben 105",
        "201 进入精英副本\nhuodongop jyfuben 201",
    }
    if iFlag == 100 then
        for idx=#mCommand,1,-1 do
            oChatMgr:HandleMsgChat(oPlayer,mCommand[idx])
        end
        oNotifyMgr:Notify(pid,"请看消息频道咨询指令")
    elseif iFlag == 101 then
        oPlayer.m_oTodayMorning:Delete("jyfuben")
        oNotifyMgr:Notify(pid,"清除成功")
    elseif iFlag ==  102 then
        local sFlag = "jyreward"
        local mData = oPlayer.m_oTodayMorning.m_mKeepList or {}
        local lDelKey = {}
        for sKey , mInfo in pairs(mData) do
            if string.find(sKey,sFlag) then
                table.insert(lDelKey,sKey)
            end
        end
        for _, sKey in ipairs(lDelKey) do
            oPlayer.m_oTodayMorning:Delete(sKey)
        end
        oNotifyMgr:Notify(pid,"清除成功")
    elseif iFlag == 103 then
        local iFloor = arg.floor
        if not iFloor then
            oNotifyMgr:Notify(pid,"参数错误")
            return 
        end
        local mRes = res["daobiao"]["jyfuben"]["grouptask"]
        if not mRes[iFloor] then
            oNotifyMgr:Notify(pid,"暂无此关卡")
            return
        end
        oPlayer.m_iTestFloor = iFloor
        oNotifyMgr:Notify(pid,"设置成功")
    elseif iFlag == 104 then
        oPlayer.m_iTestFloor = nil
        oNotifyMgr:Notify(pid,"清除成功")
    elseif iFlag == 105 then
        local sScheduleFlag = string.format("%s_schedule",self.m_sName)
        oPlayer.m_oTodayMorning:Delete(sScheduleFlag)
        oNotifyMgr:Notify(pid,"清除成功")
    elseif iFlag == 201 then
        self:JoinGame(oPlayer)
    end
 end
