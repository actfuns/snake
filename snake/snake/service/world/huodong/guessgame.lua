local global = require "global"
local res = require "base.res"
local interactive = require "base.interactive"
local record = require "public.record"
local extend = require "base.extend"
local gamedefines = import(lualib_path("public.gamedefines"))
local huodongbase = import(service_path("huodong.huodongbase"))
local taskdefines = import(service_path("task/taskdefines"))

TASK_ID = 622401

function NewHuodong(sHuodongName)
    return CHuodong:New(sHuodongName)
end


CHuodong = {}
CHuodong.__index = CHuodong
CHuodong.m_sTempName = "火眼金睛"
inherit(CHuodong, huodongbase.CHuodong)

function CHuodong:New(sHuodongName)
    local o = super(CHuodong).New(self, sHuodongName)
    return o
end

function CHuodong:CreateTaskScene(iIdx)
    local mInfo = self:GetSceneData(iIdx)
    local mData ={
        map_id = mInfo.map_id,
        team_allowed = mInfo.team_allowed,
        deny_fly = mInfo.deny_fly,
        is_durable = mInfo.is_durable==1,
        has_anlei = mInfo.has_anlei == 1,
        url = {"huodong", self.m_sName, "scene", iIdx},
    }
    local oScene = global.oSceneMgr:CreateVirtualScene(mData)
    self.m_mSceneList[oScene:GetSceneId()] = true

    local func1 = function(iEvent, mData)
        self:OnEnterTaskScene(mData)
    end
    oScene:AddEvent(self, gamedefines.EVENT.PLAYER_ENTER_SCENE, func1)

    local func2 = function(iEvent, mData)
        self:OnLeaveTaskScene(mData)
    end
    oScene:AddEvent(self, gamedefines.EVENT.PLAYER_LEAVE_SCENE, func2)

    oScene.ValidEnter = function(oScene, oPlayer)
        return self:ValidEnterTaskScene(oScene, oPlayer)
    end

    oScene.ValidLeave = function(oSrcScene, oPlayer, oDstScene)
        return self:ValidLeaveTaskScene(oSrcScene, oPlayer, oDstScene)
    end
    return oScene
end

function CHuodong:OnEnterTaskScene(mData)
    local oPalyer, oScene = mData.player, mData.scene

    --TODO refresh ui -add
end

function CHuodong:OnLeaveTaskScene(mData)
    local oPlayer, oScene, bLogout = mData.player, mData.scene, mData.logout
    
    local iScene = nil
    local oTask = oPlayer.m_oTaskCtrl:GotTaskKind(taskdefines.TASK_KIND.GUESSGAME)
    if oTask then
        iScene = oTask.m_iScene
        if not bLogout then
            oTask:OnLeaveTaskScene()
        end
    end
    if iScene then
        global.oSceneMgr:RemoveScene(iScene)
    end
end

function CHuodong:ValidEnterTaskScene(oScene, oPlayer)
    return true
end

function CHuodong:ValidLeaveTaskScene(oSrcScene, oPlayer, oDstScene)
    local oTask = oPlayer.m_oTaskCtrl:GotTaskKind(taskdefines.TASK_KIND.GUESSGAME)
    if not oTask then return true end

    local iDst = oDstScene and oDstScene:GetSceneId() or nil
    local iSrc = oSrcScene:GetSceneId()
    self:TryLeaveTaskScene(oPlayer, iSrc, iDst)
    return true
end

function CHuodong:TryLeaveTaskScene(oPlayer, iSrc, iDst)
    local oNowScene = oPlayer.m_oActiveCtrl:GetNowScene()
    if oNowScene:GetSceneId() ~= iSrc then return end
    
    if iDst then
        if oNowScene:GetSceneId() == iDst then return end
        local oDstScene = global.oSceneMgr:GetScene(iDst)
        local oTeam = oPlayer:HasTeam()
        if oTeam and oDstScene then
            oTeam:BackTeam(oPlayer)
        end
    end

    local oTask = oPlayer.m_oTaskCtrl:GotTaskKind(taskdefines.TASK_KIND.GUESSGAME)
    if oTask then
        oTask:OnLeaveTaskScene()
    end
end

function CHuodong:ValidGiveTask(oPlayer)
    if not global.oToolMgr:IsSysOpen("GUESSGAME", oPlayer, false) then
        return 2002
    end
    if oPlayer:HasTeam() then
        return 2001
    end
    local iStatus = oPlayer.m_oActiveCtrl:GetWarStatus() 
    if iStatus ~= gamedefines.WAR_STATUS.NO_WAR then
        return 2003, {name=oPlayer:GetName()}
    end
    if oPlayer.m_oTaskCtrl:GotTaskKind(taskdefines.TASK_KIND.GUESSGAME) then
        return 2004
    end
    if oPlayer.m_oScheduleCtrl:IsFullTimes(1024) then
        return 2005
    end
    return 1
end

function CHuodong:CheckGiveTask(oPlayer, oNpc, bConfirm)
    local iRet, mReplace = self:ValidGiveTask(oPlayer)
    if iRet ~= 1 then
        if iRet == 2004 then
            local oTask = oPlayer.m_oTaskCtrl:GotTaskKind(taskdefines.TASK_KIND.GUESSGAME)
            oTask:Config(oPlayer:GetPid(), nil)
            return
        elseif iRet ~= 2002 then 
            self:Notify(oPlayer:GetPid(), iRet, mReplace)
        end
        return
    end
    local oTask = global.oTaskLoader:CreateTask(TASK_ID)
    oPlayer.m_oTaskCtrl:AddTask(oTask, oNpc, true)
    oPlayer:Send("GS2CGuessGameIntroduce", {})
end

function CHuodong:ReCheckGiveTask(oPlayer, mData, iNpc)
    local oNpc = global.oNpcMgr:GetObject(iNpc)
    if not oNpc then return end
    if mData.answer ~= 1 then return end

    self:CheckGiveTask(oPlayer, oNpc)
end

function CHuodong:InitTaskNpc(oTask)
    local iOrder, lNpcId = 1, {}
    local mConfig = self:GetConfig()
    local lMonster = mConfig["monster_list"]
    for _, sMonster in ipairs(lMonster) do
        local iNpcIdx, iAmount = table.unpack(split_string(sMonster, ":",tonumber))

        for i = 1,iAmount do
            local oNpc = self:CreateTempNpc(iNpcIdx)
            oNpc.OnNpcMoveEnd = function(oNpc)
                self:OnNpcMoveEnd(oNpc)
            end
            oNpc.m_iOrder = iOrder
            iOrder = iOrder + 1
            oNpc.m_iMove = 0
            table.insert(lNpcId, oNpc.m_ID)
        end
    end
    return lNpcId
end

function CHuodong:OnNpcMoveEnd(oNpc)
    oNpc.m_iMove = nil
end

function CHuodong:IsLogWarWanfa()
    return true
end

function CHuodong:OtherScript(pid,npcobj,s,mArgs)
    local oPlayer = global.oWorldMgr:GetOnlinePlayerByPid(pid)
    if not oPlayer then return end
    local oTask = oPlayer.m_oTaskCtrl:GotTaskKind(taskdefines.TASK_KIND.GUESSGAME)
    if not oTask then return end
    local sCmd = string.match(s,"^([$%a]+)")
    if sCmd then
        local sArgs = string.sub(s,#sCmd + 1,-1)
        if sCmd == "$openbox" then
            local iRewardId = npcobj.reward_id
            oTask:OpenOneBox(npcobj.m_ID)
            mArgs = mArgs or {}
            mArgs.cancel_tip = true
            local mRet = self:Reward(pid,iRewardId,mArgs)
            if mRet then
                for sRewardType,iValue in pairs(mRet) do
                    local mRewardDataResult = {}
                    if  sRewardType == "gold" then
                        mRewardDataResult["moneyreward_info"] = {{["money_type"] = "金币", ["amount"] = iValue }}
                        mRewardDataResult["reward_type"] = "金币"
                    elseif sRewardType == "silver"  then
                        mRewardDataResult["moneyreward_info"] = {{["money_type"] = "银币", ["amount"] = iValue}}
                        mRewardDataResult["reward_type"] = "银币"
                    end
                    mRewardDataResult["itemreward_info"] = {}
                    local oCbMgr = global.oCbMgr
                    oCbMgr:SetCallBack(oPlayer:GetPid(),"GS2CStartShowRewardByType",mRewardDataResult,nil,nil) 
                end
            end
            oTask:IsOpenAllBox()
        elseif sCmd == "$choicenpc" then
            oTask:OnChoiceNpc(oPlayer, npcobj)
        end
    end
end

function CHuodong:CheckRewardMonitor(iPid, iRewardId, iCnt, mArgs)
    local  oPlayer = global.oWorldMgr:GetOnlinePlayerByPid(iPid)
    if not oPlayer then return false end
    local oTask = oPlayer.m_oTaskCtrl:GotTaskKind(taskdefines.TASK_KIND.GUESSGAME)
    if not oTask then return false end
    return oTask:CheckRewardMonitor(iPid,iRewardId,iCnt,mArgs)
end

function CHuodong:GetRewardEnv(oPlayer)
    local mEnv = super(CHuodong).GetRewardEnv(self,oPlayer)
    local oTask = oPlayer.m_oTaskCtrl:GotTaskKind(taskdefines.TASK_KIND.GUESSGAME)
    if not oTask then return mEnv end
    mEnv.win_real_count = oTask:GetWinRealRound()
    return mEnv
end

function CHuodong:GetPartnerLimit(oWar)
    if oWar and oWar.m_iIdx == 1003 then
        return 0
    end
end

function CHuodong:ChangeNpcShape(oPlayer, oNpc)
    local mConfig = self:GetConfig()
    if oNpc.m_mModel.figure ~= mConfig.changed then
        return
    end

    local iNpcIdx = oNpc:Type()
    local mData = self:GetTempNpcData(iNpcIdx)
    oNpc.m_mModel.figure = mData.figureid
    oNpc.m_sName = mData.name
    oNpc.m_sTitle = mData.title
    local mRefresh = {
        name = oNpc:Name(),
        title = oNpc:GetTitle(),
        model_info = oNpc:ModelInfo(),
    }
    oNpc:SyncSceneInfo(mRefresh)
end

function CHuodong:CheckAnswer(oPlayer, oNpc, iAnswer)
    local iNpcIdx = oNpc:Type()
   
    if iNpcIdx == 1007 then
        local oTask = oPlayer.m_oTaskCtrl:GotTaskKind(taskdefines.TASK_KIND.GUESSGAME)
        if not oTask then return false end
        if iAnswer == 1 then
            oTask:NextRoundStart(oPlayer)
        elseif iAnswer == 3 then
            oPlayer:Send("GS2CGuessGameIntroduce", {})
        end
    end
    return super(CHuodong).CheckAnswer(self, oPlayer, oNpc, iAnswer)
end

function CHuodong:do_look(oPlayer, oNpc)
    if oNpc and oNpc.m_iMove then
        return
    end
    super(CHuodong).do_look(self, oPlayer, oNpc)
end

function CHuodong:Notify(iPid, iChat, mReplace)
    local oNotifyMgr = global.oNotifyMgr
    local sMsg = self:GetTextData(iChat)
    if mReplace then
        sMsg = global.oToolMgr:FormatColorString(sMsg, mReplace)
    end
    oNotifyMgr:Notify(iPid, sMsg)
end

function CHuodong:GetSceneData(iScene)
    local mData = res["daobiao"]["huodong"][self.m_sName]
    return mData["scene"][iScene]
end

function CHuodong:GetConfig()
    return res["daobiao"]["huodong"][self.m_sName]["config"][1]
end

function CHuodong:TestOp(iFlag, mArgs)
    local iPid = mArgs[#mArgs]
    local oMaster = global.oWorldMgr:GetOnlinePlayerByPid(iPid)
    if iFlag == 100 then
        global.oNotifyMgr:Notify(iPid, [[
        101 - 进入103战斗
        ]])
    elseif iFlag == 103 then
        self:DoScript2(iPid, nil, "F1003")
    end
end
