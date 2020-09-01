local global = require "global"
local res = require "base.res"
local record = require "public.record"
local extend = require "base.extend"

local taskobj = import(service_path("task/taskobj"))
local taskdefines = import(service_path("task/taskdefines"))
local rewardmonitor = import(service_path("rewardmonitor"))

function NewTask(taskid)
    local o = CTask:New(taskid)
    return o
end

CTask = {}
CTask.__index = CTask
CTask.m_sName = "guessgame"
CTask.m_sTempName = "火眼金睛"
inherit(CTask, taskobj.CTask)


function CTask:GetBuddy()
    return global.oHuodongMgr:GetHuodong("guessgame")
end

function CTask:Init()
    super(CTask).Init(self)

    self.m_mSceneEffect = {}
    self:InitRound()
end


function CTask:TrueDoClick(oPlayer)
    super(CTask).TrueDoClick(self, oPlayer)
    if not self.m_iScene then
        local oGlobalNpc = global.oNpcMgr:GetGlobalNpc(5284)
        if oGlobalNpc and oPlayer then
            global.oNpcMgr:GotoNpcAutoPath(oPlayer, oGlobalNpc, self:AutoType())
            return
        end
    end
    local iNpc = self.m_lNpcList and self.m_lNpcList[1]
    local oNpc = self:GetNpcObj(iNpc)
    local oHuodong = self:GetBuddy()
    if oNpc and oHuodong then
        if oNpc:Type() == oHuodong:GetConfig().messenger then
            global.oNpcMgr:GotoNpcAutoPath(oPlayer, oNpc, self:AutoType())
        end
    end
end

function CTask:GetPosList()
    local oHuodong = self:GetBuddy()
    local mConfig = oHuodong:GetConfig()
    local lPos = formula_string(mConfig.pos_list, {})
    return extend.Random.random_size(lPos, #lPos)
end

function CTask:InitPosList()
    if not self:GetData("step_pos_5") then
        local lPosList = self:GetPosList()
        local iSize = #lPosList
        self:SetData("step_pos_1", extend.Random.random_size(lPosList, iSize))
        self:SetData("step_pos_2", extend.Random.random_size(lPosList, iSize))
        self:SetData("step_pos_3", extend.Random.random_size(lPosList, iSize))
        self:SetData("step_pos_4", extend.Random.random_size(lPosList, iSize))
        self:SetData("step_pos_5", extend.Random.random_size(lPosList, iSize))
    end
end

function CTask:Config(iPid, oNpc, mArgs)
    if  mArgs then
        self.m_iScene = mArgs.scene_id
    end

    local sStatus = self:GetData("status","begin")
    if sStatus == "reward" then
        self:CreateTaskScene(1001)
        self:InitBoxNpcToScene()
        self:OtherScript(iPid, nil, "$tranfer")
    else
        super(CTask).Config(self, iPid, oNpc)
    end
end

function CTask:OtherScript(pid, npcobj, s, mArgs)
    local sCmd = string.match(s, "^([$%a]+)")
    if sCmd then
        local sArgs = string.sub(s, #sCmd+ 1, -1)
        if sCmd == "$createscene" then
            if not self.m_iScene then
                local iScene = tonumber(sArgs)
                self:CreateTaskScene(iScene)
            end
            return true
        elseif sCmd == "$createmess" then
            if self.m_iScene then
                self:InsertMessNpcToScene()
            end
        elseif sCmd == "$tranfer" then
            if self.m_iScene then
                local oPlayer = global.oWorldMgr:GetOnlinePlayerByPid(pid)
                local oScene = global.oSceneMgr:GetScene(self.m_iScene)
                local oHuodong = self:GetBuddy()
                local iNpc = self.m_lNpcList and self.m_lNpcList[1]
                local oNpc = oHuodong:GetNpcObj(iNpc)
                local mNpcPos = oNpc:PosInfo()
                local iReferPosX,iReferPosY = mNpcPos.x , mNpcPos.y
                local mPos = {x = iReferPosX+1, y = iReferPosY+1}
                global.oSceneMgr:DoTransfer(oPlayer, oScene:GetSceneId(), mPos)
            end
        elseif sCmd == "$introduce" then
            local oPlayer = global.oWorldMgr:GetOnlinePlayerByPid(pid)
            if oPlayer then
                oPlayer:Send("GS2CGuessGameIntroduce", {})
            end
        end
    end
end

function CTask:OpenOneBox(iNpc)
    local oHuodong = self:GetBuddy()
    local oNpc = oHuodong:GetNpcObj(iNpc)
    if oNpc then
        oHuodong:RemoveTempNpc(oNpc)
        local iBoxAmount = self:GetData("box_amount",0)
        self:SetData("box_amount",iBoxAmount - 1)
        local mSaveNpcList = self:GetData("boxes",{})
        if mSaveNpcList[iNpc] then
            mSaveNpcList[iNpc] = nil
            self:SetData("boxes",mSaveNpcList)
        end
        self:Dirty()
        for  index,iNpcId in ipairs(self.m_lNpcList) do
            if self.m_lNpcList[index] == iNpc then
                table.remove(self.m_lNpcList,index)
                break
            end
        end
    end
end

function CTask:IsOpenAllBox()
    local iBoxAmount = self:GetData("box_amount",0)
        if  iBoxAmount <= 0 then
            self:TryStopRewardMonitor()
            self:SetData("boxes",{})
            self:SetData("win_real",0)
            self:SetData("total",0)
            self:SetData("win_list",{})
            self:SetData("status","end")
            self:Dirty()
            self:MissionDone()
        end
end

function CTask:CreateTaskScene(iScene)
    local oHuodong = self:GetBuddy()
    local oScene = oHuodong:CreateTaskScene(iScene)
    self.m_iScene = oScene:GetSceneId()

    local lPos = self:GetData("step_pos_5") or self:GetPosList()
    if self.m_mSceneEffect and not next(self.m_mSceneEffect) then
        for _, mPos in ipairs(lPos) do
            local oSceneEffect = oHuodong:CreateTempEffect(1001)
            self.m_mSceneEffect[oSceneEffect.m_ID] = oSceneEffect
            local mPosInfo = {x=mPos.x, y=mPos.y, z=0}
            oHuodong:EffectEnterScene(oSceneEffect, self.m_iScene, mPosInfo)
        end
    end
end

function CTask:InsertNpcToScene()
    local oHuodong = self:GetBuddy()
    self.m_lNpcList = oHuodong:InitTaskNpc(self)
    self:SetData("status", "insertnpc")
    self:Dirty()
    local mConfig = oHuodong:GetConfig()
    local lPos = self:GetData("step_pos_5") or self:GetPosList()
    local lCoverList = self:GetCoverList()

    for iOrder, iNpc in ipairs(self.m_lNpcList) do
        local mPos = lPos[iOrder]
        local oNpc = oHuodong:GetNpcObj(iNpc)
        oNpc.m_mPosInfo.x = mPos.x
        oNpc.m_mPosInfo.y = mPos.y
        if self:GetData("step_pos_5") and not extend.Array.member(lCoverList, iOrder) then
            self:FakeNpc(oNpc, mConfig)
            oNpc.m_iMove = nil
        end
        oHuodong:Npc_Enter_Scene(oNpc, self.m_iScene)
    end

    if not self:GetData("step_pos_5") then
        self:InitPosList()
        local iOwner = self:GetOwner()
        local iTask = self:GetId()
        self:DelTimeCb("TryNpcMove")
        self:AddTimeCb("TryNpcMove", mConfig.wait_time, function()
            TryNpcMove(iOwner, iTask)
        end)
        oHuodong:Notify(self:GetOwner(), 3007)
    end
end

function CTask:InsertMessNpcToScene()
    local oHuodong = self:GetBuddy()
    local iNpcIdx = oHuodong:GetConfig().messenger
    local oNpc = oHuodong:CreateTempNpc(iNpcIdx)
    oHuodong:Npc_Enter_Scene(oNpc, self.m_iScene)
    self.m_lNpcList = {}
    table.insert(self.m_lNpcList, oNpc:ID())
    self:SetData("status", "mess")
    self:Dirty()
end

function CTask:InitRound()
    local oHuodong = self:GetBuddy()
    local mConfig = oHuodong:GetConfig()
    if not self:GetData("total") then
        self:SetData("total", mConfig.total)
    end
    if not self:GetData("win_list") then
        self:SetData("win_list", {})
    end
end

-- 填写task内的信息
function CTask:TransFuncTable()
    local mTable = super(CTask).TransFuncTable(self)
    mTable.ret = "GetRetRound"
    mTable.total = "GetTotalRound"
    mTable.real = "GetWinRealRound"
    return mTable
end

function CTask:GetTotalRound()
    return self:GetData("total", 0)
end

function CTask:GetRound()
    local oHuodong = self:GetBuddy()
    local mConfig = oHuodong:GetConfig()
    return #self:GetData("win_list", {}) // mConfig.win
end

function CTask:GetRetRound()
    return self:GetTotalRound() - self:GetRound()
end

function CTask:GetWinRealOverRound()
     local oHuodong = self:GetBuddy()
     local mConfig = oHuodong:GetConfig()
     return mConfig["win_real_over"]
end

function CTask:GetWinRealRound()
    return self:GetData("win_real",0) 
end

function CTask:GetRealID()
     local oHuodong = self:GetBuddy()
     local mConfig = oHuodong:GetConfig()
     return mConfig["real_id"]
end

function CTask:GetRewardGoldRound()
    local oHuodong = self:GetBuddy()
    local mConfig = oHuodong:GetConfig()
    return mConfig["reward_gold"]
end

function CTask:GetCoverList()
    return {}
--    local lWinList = self:GetData("win_list", {})
--    local iRet = self:GetRetRound()
--    if iRet >= 3 then
--        return {lWinList[1], lWinList[2]}
--    elseif iRet >= 2 then
--        return {lWinList[3], lWinList[4]}
--    elseif iRet >= 1 then
--        return {lWinList[5], lWinList[6]}
--    else
--        return {}
--    end
end

function CTask:InitBoxNpcToScene()
        local mBoxList = self:GetData("boxes",{})
        local oHuodong = self:GetBuddy()
        self.m_lNpcList = {}
        local mSaveNpcList = {}
        for _,mBox in pairs(mBoxList) do
            local oNpc = oHuodong:CreateTempNpc(mBox.iNpcIdx)
            if not oNpc then
                goto continue
            end
            oNpc.m_mPosInfo.x = mBox.pos.x
            oNpc.m_mPosInfo.y = mBox.pos.y
            oNpc.reward_id = mBox.reward_id
            oHuodong:Npc_Enter_Scene(oNpc,self.m_iScene)
            table.insert(self.m_lNpcList,oNpc.m_ID)
            local mSaveNpc = {}
            mSaveNpc.pos = {x = oNpc.m_mPosInfo.x, y = oNpc.m_mPosInfo.y}
            mSaveNpc.reward_id = oNpc.reward_id
            mSaveNpc.iNpcIdx = oNpc:NpcID()
            mSaveNpcList[oNpc.m_ID] = mSaveNpc
            ::continue::
        end
        self:SetData("boxes",mSaveNpcList)
        self:Dirty()
end

function CTask:BoxEnterScene(iRewardGroup) 
    local oHuodong = self:GetBuddy()
    local mConfig = oHuodong:GetConfig()
    local mRewardGroup = formula_string(mConfig.reward_group,{})
    local mBoxRewardInfo = formula_string(mConfig.box_reward_info,{})
    local mBoxPosInfo = formula_string(mConfig.box_pos_list,{})
    local iOrder = 1
    local mBoxList = mRewardGroup[iRewardGroup]
    local mSaveNpcList = {}
    for iNpcIdx,iAmount in pairs(mBoxList) do
        for index = 1,iAmount do
            local oNpc = oHuodong:CreateTempNpc(iNpcIdx)
            if not oNpc then
                goto continue
            end
            oNpc.m_mPosInfo.x = mBoxPosInfo[iOrder].x
            oNpc.m_mPosInfo.y = mBoxPosInfo[iOrder].y
            local iRandom = math.random(1,#mBoxRewardInfo[iNpcIdx])
            oNpc.reward_id = mBoxRewardInfo[iNpcIdx][iRandom]
            oHuodong:Npc_Enter_Scene(oNpc,self.m_iScene)
            iOrder = iOrder + 1
            table.insert(self.m_lNpcList,oNpc.m_ID)
            local mSaveNpc = {}
            mSaveNpc.pos = {x = oNpc.m_mPosInfo.x, y = oNpc.m_mPosInfo.y}
            mSaveNpc.reward_id = oNpc.reward_id
            mSaveNpc.iNpcIdx = oNpc:NpcID()
            mSaveNpcList[oNpc.m_ID] = mSaveNpc
            :: continue::
        end
    end
    self:SetData("status","reward")
    self:SetData("boxes",mSaveNpcList)
    self:SetData("box_amount",#self.m_lNpcList)
    self:Dirty()
end

function CTask:CreateRewardBox(iRewardGroup)
    self:BoxEnterScene(iRewardGroup)
    self:TryStartRewardMonitor()
end

function CTask:OnChoiceNpc(oPlayer, oNpc)
    local oHuodong = self:GetBuddy()
    local mConfig = oHuodong:GetConfig()
    local iOrder = oNpc.m_iOrder
    local lFightWin = self:GetData("win_list", {})
    table.insert(lFightWin, iOrder)
    self:SetData("win_list", lFightWin)
    local iWinRealGuard = self:GetData("win_real",0)
    if oNpc:NpcID() ==  mConfig.real_id then
        self:SetData("win_real",iWinRealGuard + 1)
    end
    self:Dirty()
    self:Refresh({targetdesc = true})

    self:RestoreNpc()
    if  oNpc:NpcID() == mConfig.real_id then
        oHuodong:Notify(oPlayer:GetPid(), 3006)
    else;
        oHuodong:Notify(oPlayer:GetPid(), 3009)
    end
    self:DelTimeCb("OneRoundEnd")
    self:AddTimeCb("OneRoundEnd", mConfig.nextround_time, function()
        self:OneRoundEnd()
    end)
end

function CTask:NextRoundStart(oPlayer)
    local oHuodong = self:GetBuddy()
    if not oHuodong then return end
    self:RemoveHuodongNpc()
    self:InsertNpcToScene()
end

function CTask:OneRoundEnd()
    local oHuodong = self:GetBuddy()
    if not oHuodong then return end
    self:RemoveHuodongNpc()
    if self:GetWinRealRound() >= self:GetWinRealOverRound() then
        self:CreateRewardBox(1)
    elseif self:GetRetRound() <= 0 then
        self:CreateRewardBox(2)
    else
        self:InsertMessNpcToScene()
    end
end

function CTask:OnLogin(oPlayer, bReEnter)
    if self:GetId() == 622402 then
        self:Abandon()
        return true
    end
    local iCreateTime = self:GetCreateTime()
    local iCreateDayno = get_morningdayno(iCreateTime)
    local iCurDayno = get_morningdayno()
    if iCreateDayno < iCurDayno then
        self:Abandon()
        return true
    end
    super(CTask).OnLogin(self, bReEnter)
    return true
end

-- 兼容6.7 日 5:00 -- 7:00 玩家领取火眼金晶任务后停留在老任务622401 阶段
-- 去除任务临时npc 1001
function CTask:OnLogout(oPlayer)
    if self.m_ID == 622401 then
        self.m_mClientNpc = {}
        self:Dirty()
    end
    super(CTask).OnLogout(self)
end

function CTask:Remove()
    self:RemoveHuodongNpc()
    self:RemoveHuodongScene()
    super(CTask).Remove(self)
end

function CTask:Abandon()
    if self:GetId() ~= 622402 then
        local iCreateDayno = get_morningdayno(self:GetCreateTime())
        local iCurDayno = get_morningdayno()
        if iCreateDayno >= iCurDayno then return end
    end
    local oPlayer = global.oWorldMgr:GetOnlinePlayerByPid(self:GetOwner())
    super(CTask).Abandon(self)
    if self.m_iScene then
        self:RemoveHuodongNpc()
        self:RemoveHuodongScene()
    end
end

function CTask:MissionDone()
    super(CTask).MissionDone(self)
    local oPlayer = global.oWorldMgr:GetOnlinePlayerByPid(self:GetOwner())
    if oPlayer then
        oPlayer.m_oScheduleCtrl:Add(1024)
        oPlayer:MarkGrow(21)
    end
end

function CTask:OnLeaveTaskScene()
    self:RemoveHuodongNpc()
    self:RemoveHuodongScene()
end

function CTask:RemoveHuodongNpc()
    local oHuodong = self:GetBuddy()
    self:SetData("step_pos_1", nil)
    self:SetData("step_pos_2", nil)
    self:SetData("step_pos_3", nil)
    self:SetData("step_pos_4", nil)
    self:SetData("step_pos_5", nil)
    for _, iNpc in pairs(self.m_lNpcList or {}) do
        local oNpc = oHuodong:GetNpcObj(iNpc)
        if oNpc then
            oHuodong:RemoveTempNpc(oNpc)
        end
    end
    self.m_lNpcList = {}
end

function CTask:RemoveHuodongScene()
    local oHuodong = self:GetBuddy()
    for iEff, oEff in pairs(self.m_mSceneEffect) do
        oHuodong:RemoveTempEffect(oEff)
    end
    self.m_mSceneEffect = {}
    if self.m_iScene then
        oHuodong.m_mSceneList[self.m_iScene] = nil
        global.oSceneMgr:RemoveScene(self.m_iScene)
    end
    self.m_iScene = nil
end

function CTask:InitMigrate(iOrder)
    local oHuodong = self:GetBuddy()
    local mConfig = oHuodong:GetConfig()

    local mInfo = {}
    mInfo.interval = mConfig.time/1000
    mInfo.routeline =
        {
            {0, 0},
            table_copy(self:GetData("step_pos_1", {})[iOrder]),
            table_copy(self:GetData("step_pos_2", {})[iOrder]),
            table_copy(self:GetData("step_pos_3", {})[iOrder]),
            table_copy(self:GetData("step_pos_4", {})[iOrder]),
            table_copy(self:GetData("step_pos_5", {})[iOrder]),
        }
    if self.m_iScene then
        return {[self.m_iScene] = mInfo}
    end
end

function CTask:FakeNpc(oNpc, mConfig)
    oNpc.m_mModel.figure = mConfig.changed
    oNpc.m_sName = mConfig.name
    oNpc.m_sTitle = mConfig.title
end

function TryNpcMove(iPid, iTask)
    local oPlayer = global.oWorldMgr:GetOnlinePlayerByPid(iPid)
    if not oPlayer then return end

    local oTask = oPlayer.m_oTaskCtrl:GetTask(iTask)
    if not oTask then return end

    local oHuodong = oTask:GetBuddy()
    local mConfig = oHuodong:GetConfig()
    local oScene = global.oSceneMgr:GetScene(oTask.m_iScene)
    for iOrder, iNpc in ipairs(oTask.m_lNpcList) do
        local oNpc = oHuodong:GetNpcObj(iNpc)
        if oNpc then
            oScene:RemoveSceneNpc(iNpc)
            oTask:FakeNpc(oNpc, mConfig)
            local mMigrate = oTask:InitMigrate(oNpc.m_iOrder)
            oNpc:SetMigrateInfo(mMigrate)
            oNpc.m_iMove = 1
            oHuodong:Npc_Enter_Scene(oNpc, oTask.m_iScene)
        end
    end
end

function CTask:TryStartRewardMonitor()
    if not self.m_oRewardMonitor then
        local lUrl = {"reward", self.m_sName}
        local o = rewardmonitor.NewMonitor(self.m_sName, lUrl)
        self.m_oRewardMonitor = o
    end
end

function CTask:TryStopRewardMonitor()
    if self.m_oRewardMonitor then
        self.m_oRewardMonitor:ClearRecordInfo()
    end
end

function CTask:CheckRewardMonitor(iPid, iRewardId, iCnt, mArgs)
    if self.m_oRewardMonitor then
        if not self.m_oRewardMonitor:CheckRewardGroup(iPid, iRewardId, iCnt, mArgs) then
            return false
        end
    end
    return true
end

function CTask:RestoreNpc()    
    local oHuodong = self:GetBuddy()
    local oScene = global.oSceneMgr:GetScene(self.m_iScene)
    local lPos = self:GetData("step_pos_5")
    for iOrder, iNpc in ipairs(self.m_lNpcList) do
        local oNpc = oHuodong:GetNpcObj(iNpc)
        if oNpc then
            local mConfig = oHuodong:GetTempNpcData(oNpc:NpcID())
            local mPos = lPos[iOrder]
            oScene:RemoveSceneNpc(iNpc)
            oNpc.m_mPosInfo.x = mPos.x
            oNpc.m_mPosInfo.y = mPos.y
            self:FakeNpc(oNpc, {changed = mConfig.figureid, name = mConfig.name, title = mConfig.title})
            -- 停止移动
            oNpc:SetMigrateInfo(nil)
            oNpc.m_iMove = 1
            oHuodong:Npc_Enter_Scene(oNpc, self.m_iScene)
        end
    end
end


