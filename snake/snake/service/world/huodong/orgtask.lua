local global  = require "global"
local res = require "base.res"
local extend = require "base.extend"
local record = require "public.record"
local interactive = require "base.interactive"
local analy = import(lualib_path("public.dataanaly"))


local gamedefines = import(lualib_path("public.gamedefines"))
local huodongbase = import(service_path("huodong.huodongbase"))
local tableop = import(lualib_path("base.tableop"))
local taskdefines = import(service_path("task/taskdefines"))
local analylog = import(lualib_path("public.analylog"))

local RING_CNT = 7
local TASK_LIMIT = 35
local TASK_ITEM = 10077

function NewHuodong(sHuodongName)
    return CHuodong:New(sHuodongName)
end

CHuodong = {}
CHuodong.__index = CHuodong
CHuodong.m_sTempName = "帮派任务"
inherit(CHuodong, huodongbase.CHuodong)

function CHuodong:New(sHuodongName)
    local o = super(CHuodong).New(self, sHuodongName)
    o.m_iScheduleID = 1008
    return o
end

function CHuodong:Init()
    
end

function CHuodong:OnLogin(oPlayer,reenter)
    if not reenter then
        local mOrgTaskInfo = oPlayer.m_oActiveCtrl:GetData("orgtask_taskinfo",{})
        if not oPlayer:GetOrg() and mOrgTaskInfo.curtask then
            self:OnLeaveOrg(nil,oPlayer:GetPid())
        end
        if mOrgTaskInfo.curtask and not  mOrgTaskInfo.pretaskinfo then
            mOrgTaskInfo.pretaskinfo = self:GetTaskPreInfo(mOrgTaskInfo.curtask)
            oPlayer.m_oActiveCtrl:SetData("orgtask_taskinfo",mOrgTaskInfo)
        end
    end
    oPlayer.m_oScheduleCtrl:RefreshMaxTimes(self.m_iScheduleID)
end

function CHuodong:ValidOperate(oPlayer)
    local oNotifyMgr = global.oNotifyMgr
    local pid = oPlayer:GetPid()
    if not global.oToolMgr:IsSysOpen("ORGTASK",oPlayer,false) then   
        return false
    end
    local iLimitGrade = res["daobiao"]["open"]["ORGTASK"]["p_level"]
    if iLimitGrade>oPlayer:GetGrade() then
        local sText = self:GetTextData(1001)  
        sText = global.oToolMgr:FormatColorString(sText,{grade = iLimitGrade })
        oNotifyMgr:Notify(pid,sText)
        return false
    end
    if not oPlayer:GetOrg() then
        local sText = self:GetTextData(1006)
        oNotifyMgr:Notify(pid,sText)
        return false
    end
    local iFinishCnt = oPlayer.m_oThisWeek:Query("orgtask_finish",0)
    if iFinishCnt>=TASK_LIMIT then
        local sText = global.oToolMgr:GetTextData(62307, {"task_ext"})
        oNotifyMgr:Notify(pid,sText)
        return false
    end
    return true
end

function CHuodong:OpenOrgTaskUI(oPlayer)
    if not self:ValidOperate(oPlayer) then
        return
    end
    local mOrgTaskInfo = oPlayer.m_oActiveCtrl:GetData("orgtask_taskinfo",{})
    local iFinishCnt = oPlayer.m_oThisWeek:Query("orgtask_finish",0)

    local mNet = {}
    mNet.task = mOrgTaskInfo.curtask
    mNet.starlist = mOrgTaskInfo.starlist or {}
    mNet.ringcnt = mOrgTaskInfo.ring or 0
    if mOrgTaskInfo.curtask then
        mNet.ringcnt = mNet.ringcnt +1
        iFinishCnt  = iFinishCnt +1
    end
    mNet.star = mOrgTaskInfo.curstar
    mNet.bout = math.floor((TASK_LIMIT - iFinishCnt)/RING_CNT)
    self:PackStarReward(oPlayer,mNet)
    self:PackTaskReward(oPlayer,mOrgTaskInfo.curtask,mNet)
    local mPreTaskInfo = mOrgTaskInfo.pretaskinfo or {}
    mNet.pretaskinfo = mPreTaskInfo
    --print("cg_debug GS2COpenOrgTaskUI",mNet)
    oPlayer:Send("GS2COpenOrgTaskUI",mNet)
end

function CHuodong:PackStarReward(oPlayer,mNet)
    local iStarReward = 2001
    local mStarReward = self:GetRewardData(iStarReward)
    local mEnv = self:GetRewardEnv(oPlayer)
    local iStarExp = 0
    local iStarOrgoffer = 0 
    local lStarItem = {}

    local mOrgTaskInfo = oPlayer.m_oActiveCtrl:GetData("orgtask_taskinfo",{})
    local iRing = mOrgTaskInfo.ring or 0
    mEnv.ring = iRing + 1

    if mStarReward.exp then
        iStarExp = math.floor(formula_string(mStarReward.exp, mEnv))
    end
    
    if mStarReward.org_offer then
        iStarOrgoffer = math.floor(formula_string(mStarReward.org_offer, mEnv))
    end
    if mStarReward.item then
        for _,itemidx in pairs(mStarReward.item) do
            local mItemReward = self:GetItemRewardData(itemidx)
            local sShape = mItemReward[1].sid
            local iAmount = mItemReward[1].amount
            local iShape,tShapeArg = string.match(sShape,"(%d+)(.*)")
            iShape = tonumber(iShape)

            table.insert(lStarItem,{itemsid = iShape,amount = iAmount})
        end
    end
    mNet.starexp = iStarExp
    mNet.starorgoffer = iStarOrgoffer
    mNet.staritem = lStarItem
end

function CHuodong:PackTaskReward(oPlayer,iTask,mNet)
    local iTaskExp = 0
    local iTaskOrgoffer = 0
    local lTaskItem = {}
    local mTaskReward
    if not iTask or iTask == 0 then
        return
    end
    local mEnv = self:GetRewardEnv(oPlayer)
    local mOrgTaskInfo = oPlayer.m_oActiveCtrl:GetData("orgtask_taskinfo",{})
    local iRing = mOrgTaskInfo.ring or 0
    mEnv.ring = iRing + 1

    local mData = res["daobiao"]["task"][self.m_sName]["task"][iTask]
    if not mData then
        record.warning(string.format("GetTaskReward %s ",iTask))
        return
    end
    local submitRewardStr = mData.submitRewardStr
    if #submitRewardStr <=0 then
        return
    end
    local iTaskReward = string.match(submitRewardStr[1], "(%d+)")
    if not  iTaskReward then return end
    iTaskReward = math.floor(iTaskReward)
    mTaskReward = self:GetRewardData(iTaskReward)
    if mTaskReward.exp then
        iTaskExp = math.floor(formula_string(mTaskReward.exp, mEnv))
    end
    
    if mTaskReward.org_offer then
        iTaskOrgoffer = math.floor(formula_string(mTaskReward.org_offer, mEnv))
    end
    if mTaskReward.item then
        for _,itemidx in pairs(mTaskReward.item) do
            local mItemReward = self:GetItemRewardData(itemidx)
            local sShape = mItemReward[1].sid
            local iAmount = mItemReward[1].amount
            local iShape,tShapeArg = string.match(sShape,"(%d+)(.*)")
            iShape = tonumber(iShape)
            table.insert(lTaskItem,{itemsid = iShape,amount = iAmount})
        end
    end
    mNet.taskexp = iTaskExp
    mNet.taskorgoffer = iTaskOrgoffer
    mNet.taskitem = lTaskItem
end

function CHuodong:RandTask(oPlayer)
    if not self:ValidOperate(oPlayer) then
        return
    end
    local pid = oPlayer:GetPid()
    local oNotifyMgr = global.oNotifyMgr
    local mOrgTaskInfo = oPlayer.m_oActiveCtrl:GetData("orgtask_taskinfo",{})
    local iFinishCnt = oPlayer.m_oThisWeek:Query("orgtask_finish",0)
    local iRing = mOrgTaskInfo.ring or 0
    local iRing = mOrgTaskInfo.ring or 0
    local iRandRing = math.min(iRing+1,RING_CNT)
    local starlist = mOrgTaskInfo.starlist or {}
    if iFinishCnt>=TASK_LIMIT then
        local sText = self:GetTextData(1003)
        sText = global.oToolMgr:FormatColorString(sText,{amount = TASK_LIMIT })
        oNotifyMgr:Notify(pid,sText)
        return
    end
    if oPlayer.m_oTaskCtrl:GotTaskKind(taskdefines.TASK_KIND.ORGTASK) then
        local sText = self:GetTextData(1002)
        oNotifyMgr:Notify(pid,sText)
        return 
    end
    if #starlist>=RING_CNT then
        oNotifyMgr:Notify(pid,self:GetTextData(1011))
        return
    end

    local mRes = res["daobiao"]["orgtask"]["taskrand"]
    local mRand = {}
    for iTask,mInfo in pairs(mRes) do
        mRand[iTask] = mInfo.task_weight
    end
    local iTask = extend.Random.choosekey(mRand)
    assert(iTask,"orgtask randtask fail")

    local nostarlist = {}
    for i=1 ,RING_CNT do
        if not extend.Array.find(starlist,i) then
            table.insert(nostarlist,i)
        end
    end
    local mRes  = res["daobiao"]["orgtask"]["starrand"][iRandRing]
    local iSumWeight = mRes.has_weight+mRes.nohas_weight
    local iStar = nil 
    if math.random(1,iSumWeight)<=mRes.has_weight and next(starlist) then
        iStar =  extend.Random.random_choice(starlist)
    elseif next(nostarlist) then
        iStar =  extend.Random.random_choice(nostarlist)
    end
    if not iStar then
        iStar = math.random(1,RING_CNT)
    end

    mOrgTaskInfo.curtask  = iTask
    mOrgTaskInfo.curstar = iStar
    local mPreTaskInfo = self:GetTaskPreInfo(iTask)
    mOrgTaskInfo.pretaskinfo = mPreTaskInfo
    oPlayer.m_oActiveCtrl:SetData("orgtask_taskinfo",mOrgTaskInfo)
    local mNet = {}
    mNet.task = mOrgTaskInfo.curtask
    mNet.star = mOrgTaskInfo.curstar
    mNet.ringcnt = iRing
    if mOrgTaskInfo.curtask then
        mNet.ringcnt = mNet.ringcnt +1
        iFinishCnt  = iFinishCnt +1
    end
    mNet.bout = math.floor((TASK_LIMIT - iFinishCnt)/RING_CNT)

    self:PackTaskReward(oPlayer,iTask,mNet)
    --print("GS2COrgTaskRandTask",mNet.bout)
    mNet.pretaskinfo = mPreTaskInfo
    oPlayer:Send("GS2COrgTaskRandTask",mNet)
end

function CHuodong:ResetStar(oPlayer)
    if not self:ValidOperate(oPlayer) then
        return
    end
    local pid = oPlayer:GetPid()
    local oNotifyMgr = global.oNotifyMgr
    local mOrgTaskInfo = oPlayer.m_oActiveCtrl:GetData("orgtask_taskinfo",{})
    local iCurTask = mOrgTaskInfo.curtask
    local iCurStar = mOrgTaskInfo.curstar
    local starlist = mOrgTaskInfo.starlist or {}
    local iRing = mOrgTaskInfo.ring or 0
    local iRandRing = math.min(iRing+1,RING_CNT)

    if not iCurTask or not iCurStar then
        local sText = self:GetTextData(1005)
        oNotifyMgr:Notify(pid,sText)
        return
    end

    if oPlayer.m_oTaskCtrl:GotTaskKind(taskdefines.TASK_KIND.ORGTASK) then
        local sText = self:GetTextData(1002)
        oNotifyMgr:Notify(pid,sText)
        return
    end

    if not oPlayer:RemoveItemAmount(TASK_ITEM,1,self.m_sName) then
        return
    end
    local nostarlist = {}
    for i=1 ,RING_CNT do
        if not extend.Array.find(starlist,i) then
            table.insert(nostarlist,i)
        end
    end
    local mRes  = res["daobiao"]["orgtask"]["starrand"][iRandRing]
    local iSumWeight = mRes.has_weight+mRes.nohas_weight
    local iStar = nil 
    if math.random(1,iSumWeight)<=mRes.has_weight and next(starlist) then
        iStar =  extend.Random.random_choice(starlist)
    elseif next(nostarlist) then
        iStar =  extend.Random.random_choice(nostarlist)
    end
    if not iStar then
        iStar = math.random(1,RING_CNT)
    end
    mOrgTaskInfo.curstar = iStar
    oPlayer.m_oActiveCtrl:SetData("orgtask_taskinfo",mOrgTaskInfo)
    local mNet = {}
    mNet.task = mOrgTaskInfo.curtask
    mNet.star = mOrgTaskInfo.curstar
    --print("GS2COrgTaskResetStar",mNet)
    oPlayer:Send("GS2COrgTaskResetStar",mNet)
    --oNotifyMgr:Notify(pid,self:GetTextData(1008))
end

function CHuodong:ReceiveTask(oPlayer)
    if not self:ValidOperate(oPlayer) then
        return
    end
    local orgobj = oPlayer:GetOrg()
    local pid = oPlayer:GetPid()
    local oNotifyMgr = global.oNotifyMgr
    local mOrgTaskInfo = oPlayer.m_oActiveCtrl:GetData("orgtask_taskinfo",{})
    local iCurTask = mOrgTaskInfo.curtask or 0
    local iCurStar = mOrgTaskInfo.curstar or 0

    if oPlayer.m_oTaskCtrl:GotTaskKind(taskdefines.TASK_KIND.ORGTASK) then
        local sText = self:GetTextData(1002)
        oNotifyMgr:Notify(pid,sText)
        return
    end

    if iCurTask == 0 or iCurStar == 0 then
        local sText = self:GetTextData(1005)
        oNotifyMgr:Notify(pid,sText)
        return
    end
    local taskobj = global.oTaskLoader:CreateTask(iCurTask)
    assert(taskobj,string.format("orgtask receivetask fail %s %s",pid,iCurTask))
    local npcobj = orgobj:GetZhongGuan()
    oPlayer.m_oTaskCtrl:AddTask(taskobj,npcobj)

    analylog.LogWanFaInfo(oPlayer, self.m_sName, iCurTask, 1)
    -- mOrgTaskInfo.pretaskinfo = nil
    -- oPlayer.m_oActiveCtrl:SetData("orgtask_taskinfo",mOrgTaskInfo)
end

function CHuodong:TaskEnd(oPlayer,oTask)
    if oTask.m_mIngore then
        return
    end
    local pid = oPlayer:GetPid()
    local oNotifyMgr = global.oNotifyMgr
    local mOrgTaskInfo = oPlayer.m_oActiveCtrl:GetData("orgtask_taskinfo",{})
    local iCurTask = mOrgTaskInfo.curtask or 0
    local iCurStar = mOrgTaskInfo.curstar or 0
    local starlist = mOrgTaskInfo.starlist or {}
    local iRing = mOrgTaskInfo.ring or 0
    local iFinishTask = oTask:GetId()
    mOrgTaskInfo.pretaskinfo = nil
    oPlayer.m_oActiveCtrl:SetData("orgtask_taskinfo",mOrgTaskInfo)
    if iCurTask == 0 or iCurStar == 0 then
        record.warning(string.format("TaskEnd1 %s %s %s %s",pid,iCurTask,iCurStar,iFinishTask))
        mOrgTaskInfo.curtask = nil
        mOrgTaskInfo.curstar = nil
        oPlayer.m_oActiveCtrl:SetData("orgtask_taskinfo",mOrgTaskInfo)
        return
    end

    if iFinishTask ~= iCurTask then
        record.warning(string.format("TaskEnd2 %s %s %s %s",pid,iCurTask,iCurStar,iFinishTask))
        mOrgTaskInfo.curtask = nil
        mOrgTaskInfo.curstar = nil
        oPlayer.m_oActiveCtrl:SetData("orgtask_taskinfo",mOrgTaskInfo)
        return
    end

    if not extend.Array.find(starlist,iCurStar) then
        table.insert(starlist,iCurStar)
    end
    iRing = iRing + 1
    if iRing >= RING_CNT then
        mOrgTaskInfo = {}
        mOrgTaskInfo.starlist = starlist
    else
        mOrgTaskInfo.curtask = nil
        mOrgTaskInfo.curstar = nil
        mOrgTaskInfo.ring  = iRing
        mOrgTaskInfo.starlist = starlist
    end
    
    local iFinishCnt = oPlayer.m_oThisWeek:Query("orgtask_finish",0)
    iFinishCnt = iFinishCnt+1
    oPlayer.m_oThisWeek:Set("orgtask_finish",iFinishCnt)
    oPlayer.m_oActiveCtrl:SetData("orgtask_taskinfo",mOrgTaskInfo)
    oPlayer.m_oScheduleCtrl:RefreshMaxTimes(self.m_iScheduleID)
    --print("TaskEnd",iFinishCnt,mOrgTaskInfo)

    local orgobj = oPlayer:GetOrg()
    if orgobj and iRing>0 then
        local iCash = math.floor((1+iRing/10.0)*100)
        orgobj:AddCash(iCash,pid)
    end
    
    if iFinishCnt<TASK_LIMIT then
        --self:FindOrgZhongGuan2(oPlayer)
        self:OpenOrgTaskUI(oPlayer)
    else
        local sText = global.oToolMgr:GetTextData(62306, {"task_ext"})
        global.oNotifyMgr:Notify(pid,sText)
        if orgobj then
            local mChuanwen = res["daobiao"]["chuanwen"][1085]
            local sContent = mChuanwen.content
            sContent = global.oToolMgr:FormatColorString(sContent,{role = oPlayer:GetName()})
            global.oChatMgr:SendMsg2Org(sContent,oPlayer:GetOrgID())
        end
    end
    safe_call(self.LogAnalyInfo, self, oPlayer, iFinishTask, iRing)
    analylog.LogWanFaInfo(oPlayer, self.m_sName, iFinishTask, 2)
end

function CHuodong:FindOrgZhongGuan(oPlayer,iFlag)
    iFlag = iFlag or 0
    local pid = oPlayer:GetPid()
    local orgobj = oPlayer:GetOrg()
    local oNotifyMgr = global.oNotifyMgr
    if not orgobj then
        if iFlag == 0 then
            oNotifyMgr:Notify(pid,self:GetTextData(1007))
        elseif iFlag == 2 then
            oNotifyMgr:Notify(pid,self:GetTextData(1008))
        end
        return
    end
    local npcobj = orgobj:GetZhongGuan()
    local mPosInfo = npcobj:PosInfo()
    global.oSceneMgr:SceneAutoFindPath(pid,npcobj:MapId(),mPosInfo.x,mPosInfo.y,npcobj:ID())
end

function CHuodong:FindOrgZhongGuan2(oPlayer,iFlag)
    iFlag = iFlag or 0
    local pid = oPlayer:GetPid()
    local orgobj = oPlayer:GetOrg()
    local oNotifyMgr = global.oNotifyMgr
    if not orgobj then
        if iFlag == 0 then
            oNotifyMgr:Notify(pid,self:GetTextData(1007))
        elseif iFlag == 2 then
            oNotifyMgr:Notify(pid,self:GetTextData(1008))
        end
        return
    end
    local npcobj = orgobj:GetZhongGuan()
    local mPosInfo = npcobj:PosInfo()

    local func = function(oPlayer,mData)
        self:OpenOrgTaskUI(oPlayer)
    end
    local mData = {map_id = npcobj:MapId(),pos_x = mPosInfo.x, pos_y = mPosInfo.y, autotype = 1}
    global.oCbMgr:SetCallBack(oPlayer:GetPid(),"AutoFindPath",mData,nil,func)
end

function CHuodong:OnLeaveOrg(orgobj,pid)
    local oWorldMgr = global.oWorldMgr 
    local oPlayer = oWorldMgr:GetOnlinePlayerByPid(pid)
    if not oPlayer then return end
    local mRes = res["daobiao"]["orgtask"]["taskrand"]
    for iTask,_ in pairs(mRes) do
        local oTask = oPlayer.m_oTaskCtrl:HasTask(iTask)
        if oTask then
            oTask.m_mIngore = true
            oTask:AfterMissionDone(pid)
            oTask:FullRemove()
        end
    end    

end

function CHuodong:GetRewardEnv(oAwardee)
    local iServerGrade = global.oWorldMgr:GetServerGrade()

    local stu = 1
    if oAwardee.GetPid then
        local pid = oAwardee:GetPid()
        local oPlayer = global.oWorldMgr:GetOnlinePlayerByPid(pid)
        local orgobj = oPlayer:GetOrg()
        if orgobj and orgobj:IsXueTu(pid) then
            stu = 2
        end
    end


    return {
        lv = oAwardee:GetGrade(),
        SLV = iServerGrade,
        stu = stu,
    }
end

function CHuodong:C2GSOrgTaskStarReward(oPlayer,mData)
    local mOrgTaskInfo = oPlayer.m_oActiveCtrl:GetData("orgtask_taskinfo",{})
    local starlist = mOrgTaskInfo.starlist or {}
    if #starlist<RING_CNT then
        global.oNotifyMgr:Notify(pid,self:GetTextData(1010))
        return
    end
    mOrgTaskInfo.starlist = {}
    self:Reward(oPlayer:GetPid(),2001)
    oPlayer.m_oActiveCtrl:SetData("orgtask_taskinfo",mOrgTaskInfo)
    oPlayer:Send("GS2COrgTaskCleanStarlist",{})
end

function CHuodong:LogAnalyInfo(oPlayer, iTask, iRing)
    local mLog = oPlayer:BaseAnalyInfo()
    mLog["task_id"] = iTask
    mLog["ring"] = iRing
    analy.log_data("OrgTask", mLog)
end

function CHuodong:GetTaskPreInfo(iTask)
    local mConfig = res["daobiao"]["task"][self.m_sName]["task"][iTask]["initConfig"]
    local mInfo = {}
    for _,ss in pairs(mConfig) do
        local sCmd = string.match(ss, "^([$%a]+)")
        if not sCmd then
            goto continue
        end
        local sArgs = string.sub(ss, #sCmd + 1, -1)
        if sCmd == "E" then
            local lArgs = split_string(sArgs,":")
            mInfo["E"] = {}
            mInfo["E"]["npctype"] = tonumber(lArgs[1])
            local npctype = mInfo["E"]["npctype"]
            if npctype < 1000 then
                local npclist = res["daobiao"]["npcgroup"][npctype]["npc"]
                mInfo["E"]["npctype"] = npclist[math.random(#npclist)]
            end
            if npctype>60000  then
                local mNPCData = res["daobiao"]["task"][self.m_sName]["tasknpc"][npctype]
                if mNPCData["nameType"] == 3 then
                    mInfo["E"]["npcname"] = global.oToolMgr:GenRandomNpcName()
                end
                if mNPCData["mapid"] <1000 then
                    local mMapList = res["daobiao"]["scenegroup"][mNPCData["mapid"]]["maplist"]
                    local iMapId = mMapList[math.random(#mMapList)]
                    mInfo["E"]["mapid"] = iMapId
                end
            end
        elseif  sCmd == "PICK" then
            local lArgs = split_string(sArgs,":")
            mInfo["PICK"]  = tonumber(lArgs[1])
        elseif sCmd == "I" then
            local lArgs = split_string(sArgs,":")
            mInfo["I"]  = tonumber(lArgs[1])
            if mInfo["I"] < 1000 then
                local lItemSids = global.oItemLoader:GetItemGroup(mInfo["I"])
                mInfo["I"] = extend.Random.random_choice(lItemSids)
            end
        elseif sCmd == "TASKSAY" then
            local lArgs = split_string(sArgs,":")
            mInfo["TASKSAY"]  = tonumber(lArgs[2])
        end
        ::continue::
    end
    local mNet = {}
    if mInfo["E"] then
        mNet= mInfo["E"]
    end
    if mInfo["TASKSAY"] then
        mNet["mapid"] = mInfo["TASKSAY"]
    end
    if mInfo["PICK"] then
        mNet["mapid"] = mInfo["PICK"]
    end
    if mInfo["I"] then
        mNet["itemsid"] = mInfo["I"]
    end
    return mNet
end

function CHuodong:TestOp(iFlag, arg)
    local oNotifyMgr = global.oNotifyMgr
    local pid = arg[#arg]
    local oWorldMgr = global.oWorldMgr
    local oPlayer = oWorldMgr:GetOnlinePlayerByPid(pid)
    
    local mCommand={
        "100 指令查看",
        "101 清空帮派任务\nhuodongop orgtask 101",
        "102 清空进度信息\nhuodongop orgtask 102",
    }
    if iFlag == 100 then
        for idx=#mCommand,1,-1 do
            global.oChatMgr:HandleMsgChat(oPlayer,mCommand[idx])
        end
        oNotifyMgr:Notify(pid,"请看消息频道咨询指令")
    elseif iFlag == 101 then
        local mRes = res["daobiao"]["orgtask"]["taskrand"]
        for iTask,_ in pairs(mRes) do
            local oTask = oPlayer.m_oTaskCtrl:HasTask(iTask)
            if oTask then
                oTask:AfterMissionDone(pid)
                oTask:FullRemove()
            end
        end
        oNotifyMgr:Notify(pid,"清空完毕")
    elseif iFlag == 102 then
        oPlayer.m_oActiveCtrl:SetData("orgtask_taskinfo",{})
        oPlayer.m_oThisWeek:Delete("orgtask_finish")
        oNotifyMgr:Notify(pid,"清空完毕")
    elseif iFlag == 201 then
        self:OpenOrgTaskUI(oPlayer)
    elseif iFlag == 202 then
        self:RandTask(oPlayer)
    elseif iFlag == 203 then
        self:ResetStar(oPlayer)
    elseif iFlag == 204 then
        self:ReceiveTask(oPlayer)
    elseif iFlag == 206 then
        self:FindOrgZhongGuan(oPlayer)
    elseif iFlag == 207 then
        local mOrgTaskInfo = oPlayer.m_oActiveCtrl:GetData("orgtask_taskinfo",{})
        mOrgTaskInfo.starlist = {1,2,3,4,5,6}
        oPlayer.m_oActiveCtrl:SetData("orgtask_taskinfo",mOrgTaskInfo)
    elseif iFlag == 208 then
        self:GetTaskPreInfo(arg.task)
    elseif iFlag == 209 then
        local oNowScene = oPlayer.m_oActiveCtrl:GetNowScene()
        local orgobj = oPlayer:GetOrg()
        local npcobj = orgobj:GetZhongGuan()
        print("cg_debug",orgobj:OrgID(),npcobj:PackSceneInfo(),npcobj:GetScene(),oNowScene:GetSceneId(),orgobj.m_iSceneID)
    end
    oNotifyMgr:Notify(pid,"执行完毕")
end


