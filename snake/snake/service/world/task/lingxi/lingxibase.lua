-- 帮派任务mgr
local global = require "global"
local record = require "public.record"
local extend = require "base.extend"
local res = require "base.res"
local net = require "base.net"

local taskobj = import(service_path("task/taskobj"))
local taskdefines = import(service_path("task/taskdefines"))
local gamedefines = import(lualib_path("public.gamedefines"))
local clientnpc = import(service_path("task/clientnpc"))
local lingxihuodong = import(service_path("huodong/lingxi"))
local handleteam = import(service_path("team.handleteam"))

local LINGXI_SCHEDULE_ID = 1022

local PHASE = {
    LEADER_FORWARD = 1, -- 队长前往
    MEMBER_FORWARD = 2, -- 队员前往汇合（前端要判断二人都在范围内）
    TO_USE_SEED = 3,    -- 种植（使用种子）
    GROWING = 4,        -- 成长（QTE玩法）
    PICK = 5,           -- 采摘
    -- TO_USE_FLOWER = 6,  -- 用花（仿道具使用）
}

function GetTask(iTeamId, iTaskId)
    local oTeam = global.oTeamMgr:GetTeam(iTeamId)
    if not oTeam then
        return
    end
    local oTask = oTeam:GetTask(iTaskId)
    return oTask
end

function GetQte(iTeamId, iTaskId)
    local oTask = GetTask(iTeamId, iTaskId)
    if not oTask then
        return
    end
    return oTask:GetCurQte()
end

function GetQteConfig(sQteName, sKey)
    return table_get_depth(res, {"daobiao", "huodong", "lingxi", "qte_config", sQteName, sKey})
end

function GetHuodong()
    return global.oHuodongMgr:GetHuodong("lingxi")
end

--------------------------------

CLingxiTask = {}
CLingxiTask.__index = CLingxiTask
CLingxiTask.m_sName = "lingxi"
CLingxiTask.m_sTempName = "灵犀任务"
CLingxiTask.m_sStatisticsName = "task_lingxi"
inherit(CLingxiTask, taskobj.CTeamTask)

function CLingxiTask:New(taskid)
    local o = super(CLingxiTask).New(self, taskid)
    return o
end

function CLingxiTask:AllowShortLeave()
    return true
end

function CLingxiTask:IsLogTaskWanfa()
    return true
end

function CLingxiTask:OnTeamAddDone()
    local oTeam = self:GetTeamObj()
    if oTeam then
        oTeam:AddServStateByArgs("lingxi_task")
    end
    -- 防止Remove后取不到Owners，先保存起来
    self.m_lOwnerList = table_key_list(self:GetOwners())

    super(CLingxiTask).OnTeamAddDone(self)
end

function CLingxiTask:Remove()
    local oTeam = self:GetTeamObj()
    if oTeam then
        oTeam:RemoveServState("lingxi_task")
    end
    if self:IsDone() and not self:TmpGetNext() then
        self:RecPlayersGrow()
    end
    super(CLingxiTask).Remove(self)
end

-- 主动离队触发任务失败
function CLingxiTask:LeaveTeam(iPid, iFlag)
    if iFlag == 2 then -- shortleave
        return
    else
        local sMsg = lingxihuodong.GetText(2201)
        for _, iMem in ipairs(self.m_lOwnerList or {}) do
            if iMem ~= iPid then
                local oMem = global.oWorldMgr:GetOnlinePlayerByPid(iMem)
                if oMem then
                    oMem:NotifyMessage(sMsg)
                end
            end
        end
        self:FullRemove()
        return
    end
    -- super(CLingxiTask).LeaveTeam(self, iPid, iFlag)
end

function CLingxiTask:AllBackTeam()
    for _, iPid in ipairs(self.m_lOwnerList or {}) do
        local oPlayer = global.oWorldMgr:GetOnlinePlayerByPid(iPid)
        if oPlayer then
            global.oTeamMgr:TeamBack(oPlayer)
        end
    end
end

function CLingxiTask:RecPlayersGrow()
    for _, iPid in ipairs(self.m_lOwnerList or {}) do
        local oPlayer = global.oWorldMgr:GetOnlinePlayerByPid(iPid)
        if oPlayer then
            oPlayer:MarkGrow(24)
        end
    end
end

------------------------------

CUseFlowerTask = {}
CUseFlowerTask.__index = CUseFlowerTask
inherit(CUseFlowerTask, CLingxiTask)

function CUseFlowerTask:New(taskid)
    local o = super(CUseFlowerTask).New(self, taskid)
    return o
end

function CUseFlowerTask:SubConfig(pid)
    self:SetToUseFlowerPos()
    super(CUseFlowerTask).SubConfig(self, pid)
end

function CUseFlowerTask:SetToUseFlowerPos()
    local iMap, iPosX, iPosY, iRadius = global.oHuodongMgr:CallHuodongFunc("lingxi", "RandOutFlowerUsePos")
    local iItemSid = lingxihuodong.GetHuodongConfig("use_flower_sid")
    self:SetToUseTaskItem(iMap, iPosX, iPosY, iRadius, iItemSid)
end

function CUseFlowerTask:AfterMissionDone(pid)
    super(CUseFlowerTask).AfterMissionDone(self, pid)
    local oPlayer = global.oWorldMgr:GetOnlinePlayerByPid(pid)
    return global.oHuodongMgr:CallHuodongFunc("lingxi", "UseFlowerItem", oPlayer)
end

------------------------------

CProcTask = {}
CProcTask.__index = CProcTask
inherit(CProcTask, CLingxiTask)

function CProcTask:New(taskid)
    local o = super(CProcTask).New(self, taskid)
    o.m_mSeedInfo = nil -- 组队任务不考虑存盘
    o.m_oFlowerNpc = nil
    o.m_oGrowthTicker = nil
    return o
end

function CProcTask:Release()
    if self.m_oFlowerNpc then
        baseobj_safe_release(self.m_oFlowerNpc)
        self.m_oFlowerNpc = nil
    end
    if self.m_oGrowthTicker then
        baseobj_safe_release(self.m_oGrowthTicker)
        self.m_oGrowthTicker = nil
    end
    super(CProcTask).Release(self)
end

function CProcTask:GetTransportDest()
    local mTaskData = self:GetTaskData()
    local lMaps = lingxihuodong.GetHuodongConfig("transport_maps")
    if #lMaps <= 0 then
        return
    end
    local iMapId = lMaps[math.random(#lMaps)]
    local oScene = global.oSceneMgr:SelectDurableScene(iMapId)
    if not oScene then
        return
    end
    local iNewX, iNewY = global.oSceneMgr:RandomPos(iMapId)
    local sSceneName = oScene:GetName()
    return oScene:GetSceneId(), iNewX, iNewY, sSceneName
end

function CProcTask:DoNpcEvent(pid, npcid)
    local oNpc = self:GetNpcObj(npcid)
    local bDeal = false
    if self.m_oGrowthTicker then
        bDeal = self.m_oGrowthTicker:DoNpcEvent(pid, oNpc)
    end
    if bDeal then
        return true
    end
    if oNpc == self.m_oFlowerNpc then
        if self:GetData("phase", 0) == PHASE.PICK then
            self:PickFlower(pid)
        end
        return true
    end
    return super(CProcTask).DoNpcEvent(self, pid, npcid)
end

function CProcTask:NotifyTeamSeparately(pid, sPidMsg, sElseMsg)
    for iOwner, _ in pairs(self:GetOwners()) do
        if iOwner == pid then
            global.oNotifyMgr:Notify(iOwner, sPidMsg)
        else
            global.oNotifyMgr:Notify(iOwner, sElseMsg)
        end
    end
end

function CProcTask:BreakPickFlower()
    local iSid = self.m_iPickProgressSid
    if not iSid then
        return
    end
    global.oCbMgr:RemoveCallBack(iSid)
    local oPlayer = global.oWorldMgr:GetOnlinePlayerByPid(self.m_iPickProgressPid)
    if oPlayer then
        oPlayer:Send("GS2CCloseProgressBar", {sessionidx = iSid})
    end
end

function CProcTask:PickFlower(pid)
    local oTeam = self:GetTeamObj()
    if not oTeam then
        return
    end
    if pid ~= oTeam:Leader() then
        global.oNotifyMgr:Notify(pid, lingxihuodong.GetText(2122))
        return
    end
    for iOwner, _ in pairs(self:GetOwners()) do
        local oOwner = global.oWorldMgr:GetOnlinePlayerByPid(iOwner)
        if oOwner and oOwner:InWar() then
            if iOwner == pid then
                global.oNotifyMgr:Notify(pid, lingxihuodong.GetText(2301))
            else
                global.oNotifyMgr:Notify(pid, lingxihuodong.GetText(2302))
            end
            return
        end
    end
    local iTeamId, iTaskId = self:GetTeamID(), self:GetId()
    local sProgressText = lingxihuodong.GetHuodongConfig("pick_progress_text")
    local iProgressTime = lingxihuodong.GetHuodongConfig("pick_progress_time")
    local iSid = global.oCbMgr:SetCallBack(pid, "GS2CShowProgressBar", {msg = sProgressText, sec = iProgressTime}, nil, function(oPlayer, mData)
        PickFlowerEnd(oPlayer, mData, iTeamId, iTaskId)
    end)
    self.m_iPickProgressSid = iSid
    self.m_iPickProgressPid = pid
end

function PickFlowerEnd(oPlayer, mData, iTeamId, iTaskId)
    if mData.answer ~= 1 then
        return
    end
    local oTask = GetTask(iTeamId, iTaskId)
    if not oTask then
        return
    end
    oTask:OnPickFlowerEnd(oPlayer)
end

function CProcTask:PackIsDone()
    if not self:TmpGetNext() then
        return super(CProcTask).PackIsDone(self)
    end
    return 0
end

function CProcTask:OnPickFlowerEnd(oPlayer)
    -- self:SetData("phase", PHASE.TO_USE_FLOWER)

    self:RemoveFlowerNpc()

    -- 队伍集合
    local oTeam = self:GetTeamObj()
    for iOwner, _ in pairs(oTeam:GetShortLeave()) do
        local oOwner = global.oWorldMgr:GetOnlinePlayerByPid(iOwner)
        if oOwner then
            global.oTeamMgr:TeamBack(oOwner)
        end
    end

    -- -- 奖励
    -- local iRewardId = lingxihuodong.GetHuodongConfig("pick_reward_tbl")
    -- if iRewardId and iRewardId > 0 then
    --     self:TeamReward(oPlayer:GetPid(), iRewardId)
    -- end
    -- global.oNotifyMgr:Notify(iPid, lingxihuodong.GetText(2010))
    -- self:SyncPhase()

    self:MissionDone()
end

function CProcTask:OnTeamAddDone()
    local oTeam = self:GetTeamObj()
    if not oTeam then
        return
    end
    local iLeaderPid = oTeam:Leader()
    for iPid, _ in pairs(self:GetOwners()) do
        if iPid ~= iLeaderPid then
            -- shortleave
            oTeam:ShortLeave(iPid)
            -- random pos
            local oMem = global.oWorldMgr:GetOnlinePlayerByPid(iPid)
            if oMem then
                local iSceneId, iNewX, iNewY, sSceneName = self:GetTransportDest()
                if iSceneId then
                    local mPos = {x = iNewX, y = iNewY}
                    global.oSceneMgr:DoTransfer(oMem, iSceneId, mPos)
                    oMem:NotifyMessage(lingxihuodong.GetTextFormated(2001, {map = sSceneName}))
                end
            end
        end
    end

    local oLeader = global.oWorldMgr:GetOnlinePlayerByPid(iLeaderPid)
    if oLeader then
        handleteam.TeamCancelAutoMatch(oLeader)

        local iSceneId, iNewX, iNewY, sSceneName = self:GetTransportDest()
        if iSceneId then
            local mPos = {x = iNewX, y = iNewY}
            global.oSceneMgr:DoTransfer(oLeader, iSceneId, mPos)
            oLeader:NotifyMessage(lingxihuodong.GetTextFormated(2001, {map = sSceneName}))
        end
    end
    self:RecScheduleTimes()
    self:NotifyAccept()
    super(CProcTask).OnTeamAddDone(self)
end

function CProcTask:NotifyAccept()
end

function CProcTask:SubConfig(pid)
    self:SetData("phase", PHASE.LEADER_FORWARD)
    -- self:SetData("phase_tasktype", gamedefines.TASK_TYPE.TASK_USE_ITEM)
    local mFlowerSeedInfo = lingxihuodong.GetHuodongConfig("flower_seed_info")
    assert(mFlowerSeedInfo and #mFlowerSeedInfo >= 3, "lingxi flower_seed_info need")
    local itemsid, radius, map_id, x, y = table.unpack(mFlowerSeedInfo)
    local oSceneMgr = global.oSceneMgr
    if map_id < 100000 then
        local maplist = self:GetSceneGroup(map_id)
        map_id = maplist[math.random(#maplist)]
    end
    if not x or not y then
        x, y = oSceneMgr:RandomPos2(map_id)
    end
    if itemsid < 1000 then
        local lItemGroup = global.oItemLoader:GetItemGroup(itemsid)
        itemsid = extend.Random.random_choice(lItemGroup)
    end
    local mSeedInfo = {
        itemid = itemsid,
        map_id = map_id,
        pos_x = x,
        pos_y = y,
        radius = radius,
    }
    self.m_mSeedInfo = mSeedInfo
    super(CProcTask).SubConfig(self, pid)
end

function CProcTask:GS2CLingxiInfo(iPid)
    local oPlayer = global.oWorldMgr:GetOnlinePlayerByPid(iPid)
    if not oPlayer then
        return
    end
    local mNet = {
        taskid = self:GetId(),
        phase = self:GetData("phase", 0),
    }
    oPlayer:Send("GS2CLingxiInfo", net.Mask("GS2CLingxiInfo", mNet))
end

function CProcTask:AddPlayer(iPid)
    super(CProcTask).AddPlayer(self, iPid)
end

function CProcTask:GS2CAddTask(iPid)
    super(CProcTask).GS2CAddTask(self, iPid)
    self:GS2CLingxiInfo(iPid)
end

function CProcTask:CanUseSeed(oPlayer, iPutX, iPutY)
    if not oPlayer:IsTeamLeader() then
        oPlayer:NotifyMessage(lingxihuodong.GetText(2002))
        return
    end
    if self:GetData("phase", 0) ~= PHASE.TO_USE_SEED then
        oPlayer:NotifyMessage(lingxihuodong.GetText(2003))
        return
    end
    -- 后端不做坐标校验
    -- local mItemInfo = self.m_mSeedInfo
    -- local iMap, iX, iY, iRadius = mItemInfo.map_id, mItemInfo.pos_x, mItemInfo.pos_y, mItemInfo.radius
    -- if not self:WithinRadius(iPutX, iPutY, iX, iY, iRadius) then
    --     oPlayer:NotifyMessage(lingxihuodong.GetText(2004))
    --     return
    -- end
    -- TODO 没有判断队员是否在附近，是否加入坐标校验
    return true
end

function CProcTask:OnUseSeed(oPlayer, iPutX, iPutY)
    if not self:CanUseSeed(oPlayer, iPutX, iPutY) then
        return
    end
    local iTeamId, iTaskId = self:GetTeamID(), self:GetId()
    local sProgressText = lingxihuodong.GetHuodongConfig("plant_progress_text")
    local iProgressTime = lingxihuodong.GetHuodongConfig("plant_progress_time")
    global.oCbMgr:SetCallBack(oPlayer:GetPid(), "GS2CShowProgressBar", {msg = sProgressText, sec = iProgressTime}, nil, function(oPlayer, mData)
        UseSeedEnd(oPlayer, mData, iTeamId, iTaskId, iPutX, iPutY)
    end)
end

function UseSeedEnd(oPlayer, mData, iTeamId, iTaskId, iPutX, iPutY)
    if mData.answer ~= 1 then
        return
    end
    local oTask = GetTask(iTeamId, iTaskId)
    if not oTask then
        return
    end
    oTask:OnUseSeedEnd(oPlayer, iPutX, iPutY)
end

function CProcTask:OnUseSeedEnd(oPlayer, iPutX, iPutY)
    if not self:CanUseSeed(oPlayer, iPutX, iPutY) then
        return
    end
    if self.m_oFlowerNpc then
        baseobj_delay_release(self.m_oFlowerNpc)
        self.m_oFlowerNpc = nil
    end
    local mItemInfo = self.m_mSeedInfo
    local iMap = mItemInfo.map_id
    -- 放弃的方案（缺陷是后端判断坐标不准确）
    -- local mInRangePids = {}
    -- for iOwner, _ in pairs(self:GetOwners()) do
    --     local oOwner = global.oWorldMgr:GetOnlinePlayerByPid(iOwner)
    --     if oOwner then
    --         if self:IsNearGrowPos(oOwner) then
    --             mInRangePids[iOwner] = true
    --         end
    --     end
    -- end
    self.m_mSeedInfo = nil
    self:SetData("phase", PHASE.GROWING)
    local iNpcType = lingxihuodong.GetHuodongConfig("flower_planted")
    self:BuildFlower(iNpcType, iMap, iPutX, iPutY)
    self:SyncPhase()
    self:StartGrow()
end

function CProcTask:BuildFlower(iNpcType, iMapId, iPutX, iPutY)
    local oTeam = self:GetTeamObj()
    assert(oTeam, "lingxi task no team")
    local mArgs = self:BuildClientNpcArgs(iNpcType)
    local mPosInfo = {
        x = iPutX,
        y = iPutY,
        z = 0,
        face_x = 0,
        face_y = 0,
        face_z = 0,
    }
    mArgs.pos_info = mPosInfo
    mArgs.map_id = iMapId
    mArgs.no_turnface = 1
    local oClientNpc = clientnpc.TouchNewClientNpc(mArgs)
    assert(oClientNpc, string.format("lingxi task build flower fail, npctype:%s", iNpcType))
    global.oNpcMgr:AddObject(oClientNpc)
    self.m_oFlowerNpc = oClientNpc

    self:RefreshTaskClientNpc(oClientNpc)

    -- local iLeaderPid = oTeam:Leader()
    -- local lNames = {}
    -- local oLeader = oTeam:GetLeaderObj()
    -- for iPid, _ in pairs(self:GetOwners()) do
    --     local oPlayer = global.oWorldMgr:GetOnlinePlayerByPid(iPid)
    --     if oPlayer then
    --         if iPid ~= iLeaderPid then
    --             table.insert(lNames, oPlayer:GetName())
    --             oPlayer:NotifyMessage(lingxihuodong.GetTextFormated(2005, {role = oLeader:GetName()}))
    --         end
    --     end
    -- end
    -- oLeader:NotifyMessage(lingxihuodong.GetTextFormated(2006, {role = table.concat(lNames, "、")}))
end

function CProcTask:BuildExtApplyInfo()
    local mExtInfo = super(CProcTask).BuildExtApplyInfo(self)
    if self:GetData("phase", 0) < PHASE.GROWING then
        return mExtInfo
    end
    mExtInfo = mExtInfo or {}
    local oQte = self:GetCurQte()
    if not oQte then
        return mExtInfo
    end
    -- mExtInfo.npcid = self.m_oFlowerNpc:ID()
    mExtInfo.qte = oQte:GetQteNo()
    return mExtInfo
end

function CProcTask:TouchMembersWithinFlowerRange(mActions)
    if not self.m_oGrowthTicker then
        return false
    end
    -- 后端不做坐标校验
    -- local mInRangePids = self:CheckMembersWithinFlowerRange()
    -- self.m_oGrowthTicker:FillFlowerGrow(mInRangePids)
    local bCanGrow = self.m_oGrowthTicker:TriggerFlowerGrow(mActions)
    if not bCanGrow then
        local sMsg = lingxihuodong.GetText(2124)
        self:NotifyMsgToOwners(sMsg, {tips = true})
    end
    return bCanGrow
end

function CProcTask:SwitchFlower(iNpcType)
    local oClientNpc = self.m_oFlowerNpc
    local mArgs = self:BuildClientNpcArgs(iNpcType)
    mArgs.map_id = oClientNpc:GetMap()
    mArgs.pos_info = oClientNpc:GetPos()
    mArgs.no_turnface = 1
    oClientNpc:Init(mArgs)
    self:RefreshTaskClientNpc(oClientNpc)
end

function CProcTask:PackClientNpc()
    local lData = super(CProcTask).PackClientNpc(self)
    if self.m_oFlowerNpc then
        local mClientNpcInfo = self.m_oFlowerNpc:PackInfo()
        table.insert(lData, mClientNpcInfo)
    end
    return lData
end

function CProcTask:RemoveFlowerNpc()
    if not self.m_oFlowerNpc then
        return
    end
    local npcid = self.m_oFlowerNpc:ID()
    baseobj_safe_release(self.m_oFlowerNpc)
    self.m_oFlowerNpc = nil

    local mNet = {}
    mNet["taskid"] = self:GetId()
    mNet["npcid"] = npcid
    self:NotifyProto("GS2CRemoveTaskNpc", mNet)
end

function CProcTask:OnClickLeaderForward(pid)
    local oTeam = self:GetTeamObj()
    if not oTeam then
        return
    end
    if pid ~= oTeam:Leader() then
        global.oNotifyMgr:Notify(pid, lingxihuodong.GetText(2011))
        return
    end
    self:PathToGrowPos(pid)
end

function CProcTask:OnClickMemberForward(pid)
    local oTeam = self:GetTeamObj()
    if not oTeam then
        return
    end
    if pid == oTeam:Leader() then
        local oPlayer = global.oWorldMgr:GetOnlinePlayerByPid(pid)
        if not oPlayer then
            return
        end
        if self:IsNearGrowPos(oPlayer) then
            global.oNotifyMgr:Notify(pid, lingxihuodong.GetText(2012))
            return
        end
    end
    self:PathToGrowPos(pid)
end

function CProcTask:OnClickToUseSeed(pid)
    local oTeam = self:GetTeamObj()
    if not oTeam then
        return
    end
    if pid ~= oTeam:Leader() then
        local oPlayer = global.oWorldMgr:GetOnlinePlayerByPid(pid)
        if not oPlayer then
            return
        end
        if self:IsNearGrowPos(oPlayer) then
            global.oNotifyMgr:Notify(pid, lingxihuodong.GetText(2008))
            return
        else
            self:PathToGrowPos(pid)
        end
        return
    end
    local iTaskid = self:GetId()
    local func = function(oPlayer, mData)
        local oTask = global.oTaskMgr:GetUserTask(oPlayer, iTaskid, true)
        if oTask then
            oTask:UseSeedItem(oPlayer)
        end
    end
    self:PathToGrowPos(pid, func)
end

function CProcTask:PathToGrowPos(pid, fCbFunc)
    local mItemInfo = self.m_mSeedInfo
    if not mItemInfo then
        return
    end
    local iMap, iX, iY, iRadius = mItemInfo.map_id, mItemInfo.pos_x, mItemInfo.pos_y, mItemInfo.radius
    local oPlayer = global.oWorldMgr:GetOnlinePlayerByPid(pid)
    if not oPlayer then
        return
    end
    if not fCbFunc then
        global.oSceneMgr:SceneAutoFindPath(pid, iMap, iX, iY, nil, self:AutoType())
    else
        local mNet = {
            map_id = iMap,
            pos_x = iX,
            pos_y = iY,
            autotype = self:AutoType(),
        }
        global.oCbMgr:SetCallBack(pid, "AutoFindPath", mNet, nil, fCbFunc)
    end
end

function CProcTask:Click(pid)
    local oTeam = self:GetTeamObj()
    if not oTeam then
        return
    end
    local iPhase = self:GetData("phase", 0)
    if iPhase == PHASE.LEADER_FORWARD then
        self:OnClickLeaderForward(pid)
    elseif iPhase == PHASE.MEMBER_FORWARD then
        self:OnClickMemberForward(pid)
    elseif iPhase == PHASE.TO_USE_SEED then
        self:OnClickToUseSeed(pid)
    else
        local oClientNpc = self.m_oFlowerNpc
        if not oClientNpc then
            return
        end
        local mPos = oClientNpc:GetPos()
        local iMap = oClientNpc:GetMap()
        if iPhase == PHASE.PICK then
            global.oSceneMgr:SceneAutoFindPath(pid, iMap, mPos.x, mPos.y, oClientNpc:ID(), self:AutoType())
        else
            global.oSceneMgr:SceneAutoFindPath(pid, iMap, mPos.x, mPos.y, nil, self:AutoType())
        end
    end
end

function CProcTask:ValidUseSeedItem(oPlayer, bNotify)
    if self:GetData("phase", 0) ~= PHASE.TO_USE_SEED then
        if bNotify then
            oPlayer:NotifyMessage(lingxihuodong.GetText(2003))
        end
        return false
    end
    if not oPlayer:IsTeamLeader() then
        if bNotify then
            oPlayer:NotifyMessage(lingxihuodong.GetText(2002))
        end
        return false
    end
    local mItemInfo = self.m_mSeedInfo
    if not mItemInfo then
        if bNotify then
            oPlayer:NotifyMessage(lingxihuodong.GetText(2009))
        end
        return false
    end
    -- 后端不做坐标校验
    -- if not self:IsNearGrowPos(oPlayer) then
    --     if bNotify then
    --         oPlayer:NotifyMessage(lingxihuodong.GetText(2004))
    --     end
    --     return false
    -- end
    -- local iPid = oPlayer:GetPid()
    -- for _, iMem in ipairs(self.m_lOwnerList or {}) do
    --     if iMem ~= iPid then
    --         local oMem = global.oWorldMgr:GetOnlinePlayerByPid(iMem)
    --         if not oMem or not self:IsNearGrowPos(oMem) then
    --             if bNotify then
    --                 oPlayer:NotifyMessage(lingxihuodong.GetText(2013))
    --             end
    --             return false
    --         end
    --     end
    -- end
    return true
end

function CProcTask:IsNearGrowPos(oPlayer)
    local mItemInfo = self.m_mSeedInfo
    if not mItemInfo then
        return false
    end
    local iMap, iX, iY, iRadius = mItemInfo.map_id, mItemInfo.pos_x, mItemInfo.pos_y, mItemInfo.radius
    local oNowScene = oPlayer.m_oActiveCtrl:GetNowScene()
    local mNowPos = oPlayer.m_oActiveCtrl:GetNowPos()
    if not oNowScene or oNowScene:MapId() ~= iMap or not self:WithinRadius(mNowPos.x, mNowPos.y, iX, iY, iRadius) then
        return false
    end
    return true
end

function CProcTask:WithinRadius(iCurX, iCurY, iX, iY, iRadius)
    local iDX = iCurX - iX
    local iDY = iCurY - iY
    -- 后端允许范围增大0.5的误差
    if iDX ^ 2 + iDY ^ 2 <= (iRadius + 0.5) ^ 2 then
        return true
    end
end

function CProcTask:PackUseTaskItem()
    return {[1] = self.m_mSeedInfo}
end

function CProcTask:UseSeedItem(oPlayer)
    if not self:ValidUseSeedItem(oPlayer, true) then
        return
    end
    local mItemInfo = self.m_mSeedInfo
    oPlayer:Send("GS2CLingxiUseSeed", {
        taskid = self:GetId(),
        seed_item = mItemInfo,
    })
end

function CProcTask:OnCloseToGrowPos(oPlayer)
    if self:GetData("phase", 0) == PHASE.LEADER_FORWARD then
        if oPlayer:IsTeamLeader() then
            self:SetData("phase", PHASE.MEMBER_FORWARD)
            self:SyncPhase()
        end
    elseif self:GetData("phase", 0) == PHASE.MEMBER_FORWARD then
        local oTeam = self:GetTeamObj()
        if oTeam then
            if oTeam:IsShortLeave(oPlayer:GetPid()) then
                self:SetData("phase", PHASE.TO_USE_SEED)
                self:SyncPhase()
                local iLeaderPid = oTeam:Leader()
                self:OnClickToUseSeed(iLeaderPid)
            end
        end
    end
end

function CProcTask:OnAwayFromFlower(oPlayer)
    if self:GetData("phase", 0) ~= PHASE.GROWING then
        return
    end
    self.m_oGrowthTicker:OnAwayFromFlower(oPlayer:GetPid())
end

function CProcTask:OnCloseToFlower(oPlayer)
    if self:GetData("phase", 0) ~= PHASE.GROWING then
        return
    end
    self.m_oGrowthTicker:OnCloseToFlower(oPlayer:GetPid())
end

function CProcTask:GetCurQte()
    if self.m_oGrowthTicker then
        return self.m_oGrowthTicker:GetCurQte()
    end
end

function CProcTask:QuestionAnswer(oPlayer, mData)
    local oQte = self:GetCurQte()
    if oQte and oQte.m_sName == "question" then
        oQte:OnAnswer(oPlayer, mData)
    end
end

function CProcTask:FlowerBubbleTalk(sMsg, iSec)
    local oFlower = self.m_oFlowerNpc
    if not oFlower then
        return
    end
    local mNet = {npcid = oFlower:ID(), msg = sMsg, timeout = iSec}
    self:NotifyProto("GS2CNpcBubbleTalk", mNet)
end

function CProcTask:NotifyMsgToOwners(sMsg, mArgs)
    if not mArgs then
        mArgs = {tips = true, chat = true}
    end
    for iPid, _ in pairs(self:GetOwners()) do
        local oPlayer = global.oWorldMgr:GetOnlinePlayerByPid(iPid)
        if oPlayer then
            if mArgs.tips then
                oPlayer:NotifyMessage(sMsg)
            end
            if mArgs.chat then
                global.oChatMgr:HandleMsgChat(oPlayer, sMsg)
            end
        end
    end
end

function CProcTask:NotifyProto(sProto, mNet)
    for iPid, _ in pairs(self:GetOwners()) do
        local oPlayer = global.oWorldMgr:GetOnlinePlayerByPid(iPid)
        if oPlayer then
            oPlayer:Send(sProto, mNet)
        end
    end
end

function CProcTask:SyncPhase()
    for iPid, _ in pairs(self:GetOwners()) do
        self:GS2CLingxiInfo(iPid)
    end
end

function CProcTask:CheckMembersWithinFlowerRange()
    -- 圆内有效（考虑到范围判断是前端在触发，先通过信任前端的判断上行结果）
    local mInRangePids = {}
    local oFlower = self.m_oFlowerNpc
    if not oFlower then
        return mInRangePids
    end
    local mFlowerPos = oFlower:GetPos()
    local iRadius = lingxihuodong.GetHuodongConfig("trigger_flower_grow_radius")
    local iMap = oFlower:GetMap()
    for iPid, _ in pairs(self:GetOwners()) do
        local oPlayer = global.oWorldMgr:GetOnlinePlayerByPid(iPid)
        if not oPlayer then
            mInRangePids[iPid] = false
            goto continue
        end
        local oNowScene = oPlayer.m_oActiveCtrl:GetNowScene()
        if not oNowScene or oNowScene:MapId() ~= iMap then
            mInRangePids[iPid] = false
            goto continue
        end
        local mNowPos = oPlayer:GetNowPos()
        if not self:WithinRadius(mNowPos.x, mNowPos.y, mFlowerPos.x, mFlowerPos.y, iRadius) then
            mInRangePids[iPid] = false
            goto continue
        end
        mInRangePids[iPid] = true
        ::continue::
    end
    return mInRangePids
end

function CProcTask:StartGrow()
    self.m_oGrowthTicker = CGrowthTicker:New(self:GetTeamID(), self:GetId())
    local iGrowTimeout = lingxihuodong.GetHuodongConfig("grow_task_timeout") or 0
    self:SetTimer(iGrowTimeout, true) -- 加超时
    -- self.m_oGrowthTicker:FillFlowerGrow(mInRangePids)
    -- self:Refresh({time = 1})
    self:SyncQteCnt()
    -- self:TouchMembersWithinFlowerRange()
    self:ListenEnterWar()
end

function CProcTask:SyncQteCnt(oToPlayer)
    local iTotalCnt = 0
    local iDoneCnt = 0
    if self.m_oGrowthTicker then
        iTotalCnt = self.m_oGrowthTicker.m_iNeedQteTimes
        iDoneCnt = self.m_oGrowthTicker.m_iDoneQteTimes
    end
    local mNet = {taskid = self:GetId(), total_cnt = iTotalCnt, done_cnt = iDoneCnt}
    if oToPlayer then
        oToPlayer:Send("GS2CLingxiQteCnt", mNet)
    else
        self:PostOwners("GS2CLingxiQteCnt", mNet)
    end
end

function CProcTask:GrowDone(bQte)
    -- self.m_bQteDone = bQte
    if self.m_oGrowthTicker then
        baseobj_safe_release(self.m_oGrowthTicker)
        self.m_oGrowthTicker = nil
    end
    local sMsg
    if bQte then
        sMsg = lingxihuodong.GetText(2120)
    else
        sMsg = lingxihuodong.GetText(2121)
    end
    self:NotifyMsgToOwners(sMsg, {tips = true})
    self:SetTimer(0, true)
    self:SetData("phase", PHASE.PICK)
    self:SwitchFlower(lingxihuodong.GetHuodongConfig("flower_ripe"))
    sMsg = lingxihuodong.GetText(2123)
    self:FlowerBubbleTalk(sMsg, 10)
    self:SyncPhase()
end

function CProcTask:MissionDone(npcobj, mArgs)
    -- 改为领取时备份owners
    self:NotifyMsgToOwners(lingxihuodong.GetText(2125), {tips = true})
    super(CProcTask).MissionDone(self, npcobj, mArgs)
end

function CProcTask:OnMissionDone(pid)
    super(CProcTask).OnMissionDone(self, pid)
    -- 改为领取时计次
    -- self:RecScheduleTimes()
end

function CProcTask:Detach()
    self:UnListenEnterWar()
    super(CProcTask).Detach(self)
end

function CProcTask:RecScheduleTimes()
    for iMemId, _ in pairs(self:GetOwners()) do
        local oPlayer = global.oWorldMgr:GetOnlinePlayerByPid(iMemId)
        if oPlayer then
            local iDoneCnt = oPlayer.m_oWeekMorning:Query("lingxi_donecnt", 0)
            oPlayer.m_oWeekMorning:Set("lingxi_donecnt", iDoneCnt + 1)
            oPlayer.m_oScheduleCtrl:RefreshMaxTimes(LINGXI_SCHEDULE_ID)
            -- oPlayer.m_oScheduleCtrl:AddByName("lingxi")
        end
    end
end

function CProcTask:Remove()
    if self.m_oGrowthTicker then
        self.m_oGrowthTicker:OnRemove()
    end

    super(CProcTask).Remove(self)

    if self:IsDone() then
        self:AllBackTeam()
    end
end

function CProcTask:TeamReward(pid, sIdx, mArgs)
    local iRewardId = tonumber(sIdx)
    if not iRewardId then
        return
    end
    local bRewarded = true
    for _, iPid in pairs(self.m_lOwnerList) do
        local mRewardInfo = self:Reward(iPid, iRewardId, mArgs)
        if not mRewardInfo then
            bRewarded = false
        end
    end
    if bRewarded and #self.m_lOwnerList == 2 then
        self:RewardFriendDegree(iRewardId, mRewardInfo)
    end
end

function CProcTask:RewardFriendDegree(iRewardId, mRewardInfo)
    local mRewardInfo = self:GetRewardData(iRewardId)
    local iFriendDegree = tonumber(mRewardInfo.friend_degree)
    if not iFriendDegree or iFriendDegree <= 0 then
        return
    end
    local iPid1, iPid2 = table.unpack(self.m_lOwnerList)
    local oFriend1 = global.oWorldMgr:GetFriend(iPid1)
    local oFriend2 = global.oWorldMgr:GetFriend(iPid2)
    local iNewFD1, iNewFD2, iOldFD1, iOldFD2 = 0
    if oFriend1 then
        iOldFD1 = oFriend1:GetFriendDegree(iPid2)
    end
    if oFriend2 then
        iOldFD2 = oFriend2:GetFriendDegree(iPid1)
    end
    global.oFriendMgr:AddFriendDegree(iPid1, iPid2, iFriendDegree)
    if oFriend1 then
        iNewFD1 = oFriend1:GetFriendDegree(iPid2)
    end
    if oFriend2 then
        iNewFD2 = oFriend2:GetFriendDegree(iPid1)
    end
    record.log_db("huodong", "lingxi_reward_friend_degree", {
        pid1 = iPid1,
        pid2 = iPid2,
        old_degree1 = iOldFD1,
        old_degree2 = iOldFD2,
        new_degree1 = iNewFD1,
        new_degree2 = iNewFD2,
        add_degree = iFriendDegree,
        rewardid = iRewardId,
    })
    -- tips
    local oPlayer1 = global.oWorldMgr:GetOnlinePlayerByPid(iPid1)
    local oPlayer2 = global.oWorldMgr:GetOnlinePlayerByPid(iPid2)
    if oPlayer1 and oPlayer2 then
        local iPlayer1Add = iNewFD1 - iOldFD1
        local iPlayer2Add = iNewFD2 - iOldFD2
        if iPlayer1Add > 0 then
            local sMsg = lingxihuodong.GetTextFormated(3001, {role = oPlayer2:GetName(), friendegree = iPlayer1Add})
            -- oPlayer1:NotifyMessage(sMsg)
            global.oChatMgr:HandleMsgChat(oPlayer1, sMsg)
        end
        if iPlayer2Add > 0 then
            local sMsg = lingxihuodong.GetTextFormated(3001, {role = oPlayer1:GetName(), friendegree = iPlayer2Add})
            -- oPlayer2:NotifyMessage(sMsg)
            global.oChatMgr:HandleMsgChat(oPlayer2, sMsg)
        end
    end
end

function CProcTask:TimeOut()
    super(CProcTask).TimeOut(self)
    -- 奖励超时
    local iRewardId = lingxihuodong.GetHuodongConfig("timeout_reward_tbl")
    if iRewardId and iRewardId > 0 then
        self:TeamReward(self:GetOwner(), iRewardId)
    end
end

function CProcTask:OnLogin(oPlayer, bReEnter)
    if super(CProcTask).OnLogin(self, oPlayer, bReEnter) then
        local oQte = self:GetCurQte()
        if oQte then
            oQte:OnLogin(oPlayer, bReEnter)
        end
        if self:GetData("phase", 0) == PHASE.GROWING then
            self:SyncQteCnt()
        end
        if self.m_oGrowthTicker then
            self:Refresh({ext_apply_info = 1})
        end
        return true
    end
end

-- 取消此设定
-- function CProcTask:OnAfterClickNpc(oPlayer, oNpc)
--     if PHASE.GROWING ~= self:GetData("phase", 0) then
--         return
--     end
--     local oFlower = self.m_oFlowerNpc
--     if oFlower and oNpc == oFlower then
--         return
--     end
--     oPlayer:NotifyMessage(lingxihuodong.GetText(2303))
-- end

-- GROWING开始后的阶段都是监听期间
function CProcTask:ListenEnterWar()
    local iTeamId = self:GetTeamID()
    local iTaskId = self:GetId()
    for _, iPid in ipairs(self.m_lOwnerList) do
        local oPlayer = global.oWorldMgr:GetOnlinePlayerByPid(iPid)
        if oPlayer then
            oPlayer:AddEvent(self, gamedefines.EVENT.PLAYER_ENTER_WAR_SCENE, function(iEvType, mData)
                OnEvEnterWarScene(iPid, iTeamId, iTaskId, mData)
            end)
        end
    end
end

function CProcTask:UnListenEnterWar()
    for _, iPid in ipairs(self.m_lOwnerList) do
        local oPlayer = global.oWorldMgr:GetOnlinePlayerByPid(iPid)
        if oPlayer then
            oPlayer:DelEvent(self, gamedefines.EVENT.PLAYER_ENTER_WAR_SCENE)
        end
    end
end

function OnEvEnterWarScene(iPid, iTeamId, iTaskId, mData)
    local oTask = GetTask(iTeamId, iTaskId)
    if not oTask then
        return
    end
    oTask:OnEnterWarScene(iPid)
end

function CProcTask:OnEnterWarScene(iPid)
    local iPhase = self:GetData("phase", 0)
    if iPhase < PHASE.GROWING then
        return
    end
    if iPhase == PHASE.GROWING then
        local oGrowthTicker = self.m_oGrowthTicker
        if not oGrowthTicker or not oGrowthTicker:CanFlowerGrow() then
            return
        end
        local oQte = self:GetCurQte()
        if oQte then
            oQte:EndQte(false, false)
        end
    elseif iPhase == PHASE.PICK then
        self:BreakPickFlower()
    end
    for _, iOwner in ipairs(self.m_lOwnerList) do
        if iPid == iOwner then
            global.oNotifyMgr:Notify(iOwner, lingxihuodong.GetText(2301))
        else
            global.oNotifyMgr:Notify(iOwner, lingxihuodong.GetText(2302))
        end
    end
end

function NewTask(taskid)
    local mTaskData = global.oTaskLoader:GetTaskBaseData(taskid)
    local iLingxiType = mTaskData.lingxi_type
    local o
    if not iLingxiType or iLingxiType == 1 then
        o = CProcTask:New(taskid)
    else
        o = CUseFlowerTask:New(taskid)
    end
    return o
end

--------------------------
CQteBase = {}
CQteBase.__index = CQteBase
CQteBase.m_sName = "base"
CQteBase.m_iTimeoutSec = 10
inherit(CQteBase, logic_base_cls())

function CQteBase:New(iTeamId, iTaskId, lOwnerList)
    local o = super(CQteBase).New(self)
    o.m_iTeamId = iTeamId
    o.m_iTaskId = iTaskId
    o.m_lOwnerList = lOwnerList
    o:Init()
    return o
end

function CQteBase:Init()
    self.m_iTimeoutSec = GetQteConfig(self.m_sName, "timeout")
    self.m_iQteNo = GetQteConfig(self.m_sName, "no")
end

function CQteBase:Release()
    self:DelTimeCb("timeout")
    super(CQteBase).Release(self)
end

function CQteBase:GetQteNo()
    return self.m_iQteNo
end

function CQteBase:DoStart()
    self:OnQteStart()
end

function CQteBase:IsOwnersInWar()
    for _, iOwner in ipairs(self.m_lOwnerList) do
        local oOwner = global.oWorldMgr:GetOnlinePlayerByPid(iOwner)
        if oOwner and oOwner:InWar() then
            return true
        end
    end
    return false
end

function CQteBase:OnQteStart()
    -- PS. 虚基类函数，不要使用
    local iTeamId, iTaskId = self.m_iTeamId, self.m_iTaskId
    -- qte交互时间很短
    self:DelTimeCb("timeout")
    self:AddTimeCb("timeout", self.m_iTimeoutSec * 1000, function()
        QteTimeout(iTeamId, iTaskId)
    end)
    local oTask = GetTask(iTeamId, iTaskId)
    if oTask then
        oTask:Refresh({ext_apply_info = 1}) -- 任务qte状态下行，用于前端挂载手势
    end
end

function QteTimeout(iTeamId, iTaskId)
    local oTask = GetTask(iTeamId, iTaskId)
    if not oTask then
        return
    end
    local oQte = oTask:GetCurQte()
    if not oQte then
        return
    end
    oQte:TimeOut()
end

function CQteBase:StopQte()
    local oTask = GetTask(self.m_iTeamId, self.m_iTaskId)
    if not oTask then
        return
    end
    if oTask.m_oGrowthTicker then
        oTask.m_oGrowthTicker:OnQteStop(self.m_sName)
    end
end

function CQteBase:EndQte(bSucc, bTimeout)
    local oTask = GetTask(self.m_iTeamId, self.m_iTaskId)
    local oGrowthTicker
    local bIsLastQte
    if oTask then
        oGrowthTicker = oTask.m_oGrowthTicker
        if oGrowthTicker then
            bIsLastQte = oGrowthTicker:IsLastQte()
        end
    end
    self:NotifyEnd(bSucc, bTimeout, bIsLastQte)
    if oGrowthTicker then
        oGrowthTicker:OnTickQteEnd(bSucc, self.m_sName)
    end
end

function CQteBase:Shut()
    self:DelTimeCb("timeout")
end

function CQteBase:TimeOut()
    self:EndQte(false, true)
end

function CQteBase:NotifyEnd(bSucc, bTimeout, bIsLastQte)
    if bSucc then
        self:NotifyDone(bIsLastQte)
    elseif bTimeout then
        self:NotifyTimeout()
    end
end

function CQteBase:NotifyDone(bIsLastQte)
    if bIsLastQte then
        return
    end
    local sMsg = lingxihuodong.GetText(2101)
    for _, iPid in ipairs(self.m_lOwnerList) do
        global.oNotifyMgr:Notify(iPid, sMsg)
    end
end

function CQteBase:NotifyTimeout()
end

function CQteBase:DoNpcEvent(pid, oNpc)
end

function CQteBase:OnLogin(oPlayer, bReEnter)
end

function CQteBase:OnInteractiveEnd(oPlayer, mData)
end

function GetCurQte(iTeamId, iTaskId, sQteName)
    local oTask = GetTask(iTeamId, iTaskId)
    if not oTask then
        return
    end
    local oQte = oTask:GetCurQte()
    if not oQte then
        return
    end
    if oQte.m_sName ~= sQteName then
        return
    end
    return oQte
end

function QteInteractiveEnd(oPlayer, mData, iTeamId, iTaskId, sQteName)
    local oQte = GetCurQte(iTeamId, iTaskId, sQteName)
    if oQte then
        oQte:OnInteractiveEnd(oPlayer, mData)
    end
end

-----------------------------
CQteHeart = {}
CQteHeart.__index = CQteHeart
CQteHeart.m_sName = "heart"
inherit(CQteHeart, CQteBase)

function CQteHeart:Init()
    super(CQteHeart).Init(self)
    self.m_mQteSession = {}
end

function CQteHeart:Release()
    super(CQteHeart).Release(self)
end

function CQteHeart:OnQteStart()
    local oTask = GetTask(self.m_iTeamId, self.m_iTaskId)
    if not oTask then
        return
    end
    local iTeamId, iTaskId = self.m_iTeamId, self.m_iTaskId
    local sQteName = self.m_sName
    local fCallBack = function(oPlayer, mData)
        QteInteractiveEnd(oPlayer, mData, iTeamId, iTaskId, sQteName)
    end
    local iQteId = GetQteConfig(self.m_sName, "qteid")
    local mNet = {
        qteid = iQteId,
        lasts = self.m_iTimeoutSec - 1 -- 前端播动画后才上行session，提高容错让前端时间减少1s
    }
    self.m_mQteSession = {}
    for _, iPid in ipairs(self.m_lOwnerList) do
        local iSid = global.oCbMgr:SetCallBack(iPid, "GS2CPlayQte", mNet, nil, fCallBack)
        self.m_mQteSession[iPid] = iSid
    end
    super(CQteWater).OnQteStart(self)
end

function CQteHeart:OnInteractiveEnd(oPlayer, mData)
    local iPid = oPlayer:GetPid()
    local iSid = self.m_mQteSession[iPid]
    if iSid ~= mData.sessionidx then
        return
    end
    if mData.answer == 1 then
        self.m_mQteSession[iPid] = nil
        if not next(self.m_mQteSession) then
            self:EndQte(true)
            -- OnQteEnd(self.m_iTeamId, self.m_iTaskId, true)
        end
    else
        self.m_mQteSession[iPid] = 0
        local function _check(k,v)
            return (v == 0)
        end
        if table_all_true(self.m_mQteSession, _check) then
            self:EndQte(false)
            -- OnQteEnd(self.m_iTeamId, self.m_iTaskId, false)
        end
    end
end

function CQteHeart:Shut()
    for iPid, iSid in pairs(self.m_mQteSession) do
        global.oCbMgr:RemoveCallBack(iSid)
    end
    self.m_mQteSession = {}
    super(CQteHeart).Shut(self)
end

function CQteHeart:NotifyTimeout()
    local sMsg = lingxihuodong.GetText(2113)
    for _, iPid in ipairs(self.m_lOwnerList) do
        global.oNotifyMgr:Notify(iPid, sMsg)
    end
end

-----------------------------
CQteWater = {}
CQteWater.__index = CQteWater
CQteWater.m_sName = "water"
CQteWater.m_iTimeoutSec = 10
inherit(CQteWater, CQteBase)

function CQteWater:DoNpcEvent(pid, oNpc)
    if not extend.Array.find(self.m_lOwnerList, pid) then
        return true
    end
    local oPlayer = global.oWorldMgr:GetOnlinePlayerByPid(pid)
    if not oPlayer then
        return true
    end
    if oPlayer:GetSex() ~= gamedefines.SEX_TYPE.SEX_FEMALE then
        oPlayer:NotifyMessage(lingxihuodong.GetText(2102))
        return true
    end
    if self.m_iProgressSid then
        oPlayer:NotifyMessage(lingxihuodong.GetText(2103))
        return true
    end
    local iTeamId, iTaskId = self.m_iTeamId, self.m_iTaskId
    local sQteName = self.m_sName
    local sProgressText = GetQteConfig(self.m_sName, "progress_text")
    local iProgressTime = GetQteConfig(self.m_sName, "progress_time")
    self.m_iProgressPid = pid
    self.m_sProgressPName = oPlayer:GetName()
    self.m_iProgressSid = global.oCbMgr:SetCallBack(oPlayer:GetPid(), "GS2CShowProgressBar", {msg = sProgressText, sec = iProgressTime}, nil, function(oPlayer, mData)
        QteInteractiveEnd(oPlayer, mData, iTeamId, iTaskId, sQteName)
    end)
    return true
end

function CQteWater:OnQteStart()
    local oTask = GetTask(self.m_iTeamId, self.m_iTaskId)
    if not oTask then
        return
    end
    oTask:FlowerBubbleTalk(lingxihuodong.GetText(2104), 10)
    oTask:NotifyMsgToOwners(lingxihuodong.GetText(2117), {tips = true})
    super(CQteWater).OnQteStart(self)
end

function CQteWater:OnInteractiveEnd(oPlayer, mData)
    if self.m_iProgressSid ~= mData.sessionidx then
        return
    end
    self.m_iProgressSid = nil
    self.m_iProgressPid = nil
    if mData.answer == 1 then
        self:EndQte(true)
        -- OnQteEnd(self.m_iTeamId, self.m_iTaskId, true)
    end
end

function CQteWater:Shut()
    local iSid = self.m_iProgressSid
    local iPid = self.m_iProgressPid
    self.m_iProgressSid = nil
    self.m_iProgressPid = nil
    if iSid then
        global.oCbMgr:RemoveCallBack(iSid)
        local oPlayer = global.oWorldMgr:GetOnlinePlayerByPid(iPid)
        if oPlayer then
            oPlayer:Send("GS2CCloseProgressBar", {sessionidx = iSid})
        end
    end
    super(CQteWater).Shut(self)
end

function CQteWater:NotifyTimeout()
    local sMsg = lingxihuodong.GetText(2105)
    for _, iPid in ipairs(self.m_lOwnerList) do
        global.oNotifyMgr:Notify(iPid, sMsg)
    end
end

function CQteWater:NotifyDone(bIsLastQte)
    super(CQteWater).NotifyDone(self, bIsLastQte)
    local oTask = GetTask(self.m_iTeamId, self.m_iTaskId)
    if not oTask then
        return
    end
    local sMsg = lingxihuodong.GetTextFormated(2112, {role = self.m_sProgressPName})
    oTask:FlowerBubbleTalk(sMsg)
    -- oTask:NotifyMsgToOwners(lingxihuodong.GetTextFormated(2119, {role = self.m_sProgressPName}), {tips = true})
end
--------------------------

CQteWorm = {}
CQteWorm.__index = CQteWorm
CQteWorm.m_sName = "worm"
CQteWorm.m_iTimeoutSec = 10
inherit(CQteWorm, CQteBase)

function CQteWorm:DoNpcEvent(pid, oNpc)
    if not extend.Array.find(self.m_lOwnerList, pid) then
        return true
    end
    local oPlayer = global.oWorldMgr:GetOnlinePlayerByPid(pid)
    if not oPlayer then
        return true
    end
    if oPlayer:GetSex() ~= gamedefines.SEX_TYPE.SEX_MALE then
        oPlayer:NotifyMessage(lingxihuodong.GetText(2106))
        return true
    end
    if self.m_iProgressSid then
        oPlayer:NotifyMessage(lingxihuodong.GetText(2107))
        return true
    end
    local iTeamId, iTaskId = self.m_iTeamId, self.m_iTaskId
    local sQteName = self.m_sName
    local sProgressText = GetQteConfig(self.m_sName, "progress_text")
    local iProgressTime = GetQteConfig(self.m_sName, "progress_time")
    self.m_iProgressPid = pid
    self.m_sProgressPName = oPlayer:GetName()
    self.m_iProgressSid = global.oCbMgr:SetCallBack(oPlayer:GetPid(), "GS2CShowProgressBar", {msg = sProgressText, sec = iProgressTime}, nil, function(oPlayer, mData)
        QteInteractiveEnd(oPlayer, mData, iTeamId, iTaskId, sQteName)
    end)
    return true
end

function CQteWorm:OnQteStart()
    local oTask = GetTask(self.m_iTeamId, self.m_iTaskId)
    if not oTask then
        return
    end
    local sMsg = lingxihuodong.GetText(2108)
    oTask:FlowerBubbleTalk(sMsg, 10)
    oTask:NotifyMsgToOwners(lingxihuodong.GetText(2116), {tips = true})
    super(CQteWorm).OnQteStart(self)
end

function CQteWorm:OnInteractiveEnd(oPlayer, mData)
    if self.m_iProgressSid ~= mData.sessionidx then
        return
    end
    self.m_iProgressSid = nil
    self.m_iProgressPid = nil
    if mData.answer == 1 then
        self:EndQte(true)
        -- OnQteEnd(self.m_iTeamId, self.m_iTaskId, true)
    end
end

function CQteWorm:Shut()
    local iSid = self.m_iProgressSid
    local iPid = self.m_iProgressPid
    self.m_iProgressSid = nil
    self.m_iProgressPid = nil
    if iSid then
        global.oCbMgr:RemoveCallBack(iSid)
        local oPlayer = global.oWorldMgr:GetOnlinePlayerByPid(iPid)
        if oPlayer then
            oPlayer:Send("GS2CCloseProgressBar", {sessionidx = iSid})
        end
    end
    super(CQteWorm).Shut(self)
end

function CQteWorm:NotifyTimeout()
    local sMsg = lingxihuodong.GetText(2109)
    for _, iPid in ipairs(self.m_lOwnerList) do
        global.oNotifyMgr:Notify(iPid, sMsg)
    end
end

function CQteWorm:NotifyDone(bIsLastQte)
    super(CQteWorm).NotifyDone(self, bIsLastQte)
    local oTask = GetTask(self.m_iTeamId, self.m_iTaskId)
    if not oTask then
        return
    end
    local sMsg = lingxihuodong.GetTextFormated(2111, {role = self.m_sProgressPName})
    oTask:FlowerBubbleTalk(sMsg)
    -- oTask:NotifyMsgToOwners(lingxihuodong.GetTextFormated(2118, {role = self.m_sProgressPName}), {tips = true})
end
--------------------------

CQteQuestion = {}
CQteQuestion.__index = CQteQuestion
CQteQuestion.m_sName = "question"
inherit(CQteQuestion, CQteBase)

function CQteQuestion:Init()
    super(CQteQuestion).Init(self)
    self.m_lQuestions = {}
    self.m_mPlayers = {}
    self.m_iCnt = GetQteConfig(self.m_sName, "ques_cnt")
    self.m_iQuesTime = GetQteConfig(self.m_sName, "sec_per_ques")
    self.m_iNeedCorrectCnt = GetQteConfig(self.m_sName, "ques_correct_cnt")
    self.m_iTimeoutSec = GetQteConfig(self.m_sName, "timeout")
end

function CQteQuestion:Release()
    self:DelTimeCb("question")
    super(CQteQuestion).Release(self)
end


function CQteQuestion:OnQteStart()
    local oTask = GetTask(self.m_iTeamId, self.m_iTaskId)
    if not oTask then
        return
    end
    local mPlayers = oTask:GetOwners()
    self.m_mPlayers = {}
    for iPid, _ in pairs(mPlayers) do
        self.m_mPlayers[iPid] = {}
    end
    local lAllQuestionIds = table_get_depth(res, {"daobiao", "huodong", "lingxi", "choose_question"})
    local lRandQuestIds = extend.Random.random_size(table_copy(lAllQuestionIds), self.m_iCnt)
    self.m_lQuestions = {}
    local iNow = get_time()
    for idx, iQuesId in ipairs(lRandQuestIds) do
        local mQuesInfo = {
            id = iQuesId,
            timeout = iNow + idx * self.m_iQuesTime,
            player_answer = {},
        }
        self.m_lQuestions[idx] = mQuesInfo
    end
    self:TickNextQuestion()
    super(CQteQuestion).OnQteStart(self)
end

function NextQuestion(iTeamId, iTaskId, sQteName)
    local oQte = GetCurQte(iTeamId, iTaskId, sQteName)
    if oQte then
        oQte:TickNextQuestion()
    end
end
function CQteQuestion:Shut()
    self:DelTimeCb("timeout")

    local mNet = {
        taskid = self.m_iTaskId,
    }
    for iPid, mPlayerRec in pairs(self.m_mPlayers) do
        local oPlayer = global.oWorldMgr:GetOnlinePlayerByPid(iPid)
        if oPlayer then
            oPlayer:Send("GS2CLingxiQuestionClose", mNet)
        end
    end
    super(CQteQuestion).Shut(self)
end

function CQteQuestion:TickNextQuestion()
    self.m_iRound = (self.m_iRound or 0) + 1
    local mQuesInfo = self.m_lQuestions[self.m_iRound]
    if not mQuesInfo then
        return
    end
    local iQuesId = mQuesInfo.id
    local iTimeout = mQuesInfo.timeout
    local iRestSec = iTimeout - get_time()
    assert(iRestSec > 0, string.format("qte question resttime <= 0, task:%s, round:%d, owner:%s", self.m_iTaskId, self.m_iRound, table.concat(table_key_list(self.m_mPlayers), "|")))
    local mNet = {
        taskid = self.m_iTaskId,
        round = self.m_iRound,
        ques = iQuesId,
        total_round = #self.m_lQuestions,
        rest_sec = iRestSec,
    }
    local iTeamId, iTaskId = self.m_iTeamId, self.m_iTaskId
    local sQteName = self.m_sName
    -- qte交互时间较短
    self:DelTimeCb("question")
    self:AddTimeCb("question", iRestSec * 1000, function()
        NextQuestion(iTeamId, iTaskId, sQteName)
    end)
    for iPid, mPlayerRec in pairs(self.m_mPlayers) do
        local oPlayer = global.oWorldMgr:GetOnlinePlayerByPid(iPid)
        if oPlayer then
            mNet.my_answer = mQuesInfo.player_answer[iPid]
            mNet.correct_cnt = mPlayerRec.correct_cnt
            oPlayer:Send("GS2CLingxiQuestion", mNet)
        end
    end
end

function CQteQuestion:OnAnswer(oPlayer, mData)
    local iAnswer = mData.answer
    if not iAnswer then
        return
    end
    local iRound = self.m_iRound
    if not iRound or iRound ~= mData.round then
        return
    end
    local mQuesInfo = self.m_lQuestions[iRound]
    if not mQuesInfo then
        return
    end
    local iPid = oPlayer:GetPid()
    if table_get_depth(mQuesInfo, {"player_answer", iPid}) then
        oPlayer:NotifyMessage(lingxihuodong.GetText(2110))
        return
    end
    table_set_depth(mQuesInfo, {"player_answer"}, iPid, iAnswer)
    if iAnswer == 1 then
        local mPlayerRec = table_get_set_depth(self.m_mPlayers, {iPid})
        mPlayerRec.correct_cnt = (mPlayerRec.correct_cnt or 0) + 1
        local sMsg = lingxihuodong.GetText(2114)
        oPlayer:NotifyMessage(sMsg)
        global.oChatMgr:HandleMsgChat(oPlayer, sMsg)
    else
        local sMsg = lingxihuodong.GetText(2115)
        oPlayer:NotifyMessage(sMsg)
        global.oChatMgr:HandleMsgChat(oPlayer, sMsg)
    end
    local iQuesId = mQuesInfo.id
    local mNet = {
        taskid = self.m_iTaskId,
        round = self.m_iRound,
        ques = iQuesId,
        my_answer = iAnswer,
    }
    oPlayer:Send("GS2CLingxiQuestionAnswered", mNet)
end

function CQteQuestion:NotifyTimeout()
    local sMsg = lingxihuodong.GetTextFormated(2128, {amount = self.m_iNeedCorrectCnt})
    for _, iPid in ipairs(self.m_lOwnerList) do
        global.oNotifyMgr:Notify(iPid, sMsg)
    end
    -- oTask:NotifyMsgToOwners(sMsg, {tips = true})
end

function CQteQuestion:NotifyDone(bIsLastQte)
    if bIsLastQte then
        return
    end
    local sMsg = lingxihuodong.GetTextFormated(2127, {amount = self.m_iNeedCorrectCnt})
    for _, iPid in ipairs(self.m_lOwnerList) do
        global.oNotifyMgr:Notify(iPid, sMsg)
    end
end

function CQteQuestion:TimeOut()
    local iTotalCorr = 0
    for iPid, mPlayerRec in pairs(self.m_mPlayers) do
        iTotalCorr = iTotalCorr + (mPlayerRec.correct_cnt or 0)
    end
    if iTotalCorr >= self.m_iNeedCorrectCnt then
        self:EndQte(true, false)
    else
        self:EndQte(false, true)
    end
end

function CQteQuestion:OnLogin(oPlayer, bReEnter)
    self:SendCurQuesState(oPlayer)
end

function CQteQuestion:SendCurQuesState(oPlayer)
    local mQuesInfo = self.m_lQuestions[self.m_iRound]
    if not mQuesInfo then
        return
    end
    local iPid = oPlayer:GetPid()
    local iQuesId = mQuesInfo.id
    local iTimeout = mQuesInfo.timeout
    local mNet = {
        taskid = self.m_iTaskId,
        round = self.m_iRound,
        ques = iQuesId,
        total_round = #self.m_lQuestions,
        rest_sec = iTimeout - get_time(),
        my_answer = mQuesInfo.player_answer[iPid],
        correct_cnt = table_get_depth(self.m_mPlayers, {iPid, "correct_cnt"}),
    }
    oPlayer:Send("GS2CLingxiQuestion", mNet)
end
------------------------------

CGrowthTicker = {}
CGrowthTicker.__index = CGrowthTicker
inherit(CGrowthTicker, logic_base_cls())

function CGrowthTicker:New(iTeamId, iTaskId)
    local o = super(CGrowthTicker).New(self)
    o.m_iTeamId = iTeamId
    o.m_iTaskId = iTaskId
    o.m_iTickPeriod = lingxihuodong.GetHuodongConfig("grow_tick_period")
    o.m_iNeedDoneSec = lingxihuodong.GetHuodongConfig("grow_total_sec")
    o.m_iNeedQteTimes = lingxihuodong.GetHuodongConfig("grow_qte_cnt")
    o.m_iTotalDoneSec = 0
    o.m_iDoneQteTimes = 0
    o.m_iTickFrom = nil
    o.m_oQte = nil
    o.m_mNear = {}
    local iCheckNearWaitSec = 1
    o.m_iCheckNearFlowerTime = get_time() + iCheckNearWaitSec -- 1s内的OnCloseToFlower作为前端自动流程，超过才视为玩家处理
    o:AddTimeCb("check_near", iCheckNearWaitSec * 1000, function()
        OnGrowthTickerCheckNearFlower(iTeamId, iTaskId)
    end)
    return o
end

function CGrowthTicker:Release()
    self:DelTimeCb("grow")
    if self.m_oQte then
        baseobj_safe_release(self.m_oQte)
        self.m_oQte = nil
    end
    super(CGrowthTicker).Release(self)
end

function OnGrowthTickerCheckNearFlower(iTeamId, iTaskId)
    local oTask = GetTask(iTeamId, iTaskId)
    if oTask then
        local oGrowthTicker = oTask.m_oGrowthTicker
        if oGrowthTicker then
            oGrowthTicker:OnGrowthTickerCheckNearFlower(oTask)
        end
    end
end

function CGrowthTicker:OnGrowthTickerCheckNearFlower(oTask)
    for iOwner, _ in pairs(oTask:GetOwners()) do
        if not self.m_mNear[iOwner] then
            oTask:NotifyTeamSeparately(iOwner, lingxihuodong.GetText(2311), lingxihuodong.GetText(2312))
        end
    end
end

function CGrowthTicker:Start()
    self.m_iTickFrom = get_time()
    self:GoOn()
end

function CGrowthTicker:GoOn()
    self:DelTimeCb("grow")
    local oTask = GetTask(self.m_iTeamId, self.m_iTaskId)
    -- (这个检查会加重服务器负担，因为是心跳触发)检查玩家在情花苗附近
    if not oTask or not oTask:TouchMembersWithinFlowerRange({no_start = true}) then
        return
    end
    local iWaitSec = self.m_iNeedDoneSec - self.m_iTotalDoneSec
    if iWaitSec <= 0 then
        self:Finish()
        return
    end
    iWaitSec = math.min(iWaitSec, self.m_iTickPeriod)
    --- TEST --------
    if not is_production_env() then
        if oTask and oTask.m_tmp_lingxi_qte_name then
            -- if self.m_iTotalDoneSec > 10 then
            --     self:Finish()
            --     return
            -- end
            iWaitSec = 3
        end
    end
    --- END TEST ----
    local iNow = get_time()
    self.m_iTickStartAt = iNow
    local iTaskId = self.m_iTaskId
    local iTeamId = self.m_iTeamId
    -- qte交互时间较短
    self:AddTimeCb("grow", iWaitSec * 1000, function()
        OnGrowthTickEnd(iTeamId, iTaskId)
    end)
end

function CGrowthTicker:GetTask()
    return GetTask(self.m_iTeamId, self.m_iTaskId)
end

function OnGrowthTickEnd(iTeamId, iTaskId)
    local oTask = GetTask(iTeamId, iTaskId)
    if not oTask then
        return
    end
    if not oTask.m_oGrowthTicker then
        return
    end
    oTask.m_oGrowthTicker:OnTickEnd()
end

function CGrowthTicker:OnTickEnd()
    if self:Pause() then
        return
    end
    self:CallQte()
end

-- @return: bFinished
function CGrowthTicker:Pause()
    self:DelTimeCb("grow")
    local iStart = self.m_iTickStartAt
    if not iStart then
        return
    end
    self.m_iTickStartAt = nil
    self.m_iTotalDoneSec = self.m_iTotalDoneSec + (get_time() - iStart)
    if self.m_iTotalDoneSec >= self.m_iNeedDoneSec then
        self:Finish()
        return true
    end
end

function CGrowthTicker:RewardQteEnd(sQteName, bSucc)
    if not bSucc then
        -- 玩法改成极长的超时，会很多次QTE，故不再失败奖励
        return
    end
    local oTask = self:GetTask()
    if oTask then
        local iOwner = oTask:GetOwner()
        local iRewardId
        if bSucc then
            iRewardId = GetQteConfig(sQteName, "reward_succ_tbl")
        else
            iRewardId = GetQteConfig(sQteName, "reward_fail_tbl")
        end
        if iRewardId and iRewardId > 0 then
            oTask:TeamReward(iOwner, iRewardId)
        end
    end
end

function CGrowthTicker:Finish(bQte)
    local oTask = self:GetTask()
    if oTask then
        oTask:GrowDone(bQte)
    end
end

function CGrowthTicker:OnRemove()
    self:RemoveQte()
end

function CGrowthTicker:RemoveQte()
    if self.m_oQte then
        self.m_oQte:Shut()
        baseobj_delay_release(self.m_oQte)
        self.m_oQte = nil

        local oTask = GetTask(self.m_iTeamId, self.m_iTaskId)
        if oTask then
            oTask:Refresh({ext_apply_info = 1}) -- 任务qte状态下行，用于前端移除挂载的手势
        end
    end
end

function CGrowthTicker:IsLastQte()
    if self.m_iDoneQteTimes + 1 >= self.m_iNeedQteTimes then
        return true
    end
end

function CGrowthTicker:OnQteStop(sQteName)
    self:RemoveQte()
end

function CGrowthTicker:OnTickQteEnd(bSucc, sQteName)
    self:RemoveQte()
    self:RewardQteEnd(sQteName, bSucc)
    if bSucc then
        self.m_iDoneQteTimes = self.m_iDoneQteTimes + 1
        local bFinish = self.m_iDoneQteTimes >= self.m_iNeedQteTimes
        self:OnQteSucc(sQteName, bFinish)
        if bFinish then
            self:Finish(true)
            return
        end
    end
    self:GoOn()
end

function CGrowthTicker:OnQteSucc(sQteName, bFinish)
    local oTask = GetTask(self.m_iTeamId, self.m_iTaskId)
    if not oTask then
        return
    end
    if not bFinish then
        oTask:SyncQteCnt()
    end
    local iSeedlingNeedQteCnt = lingxihuodong.GetHuodongConfig("seedling_qte_cnt") or 0
    if self.m_iDoneQteTimes == iSeedlingNeedQteCnt then
        local mTaskData = oTask:GetTaskData()
        oTask:SwitchFlower(lingxihuodong.GetHuodongConfig("flower_growing"))
        local sMsg = lingxihuodong.GetText(2007)
        oTask:NotifyMsgToOwners(sMsg, {tips = true})
    end
end

function CGrowthTicker:GetCurQte()
    return self.m_oQte
end

function CGrowthTicker:AbleGrow()
    local oTask = self:GetTask()
    if not oTask then
        return false
    end
    local oInWarOnwer = self:FindInWarOnwer()
    if oInWarOnwer then
        return false
    end
    return true
end

function CGrowthTicker:FindInWarOnwer()
    local oTask = self:GetTask()
    if not oTask then
        return nil
    end
    local mOwners = oTask:GetOwners()
    for iOwner, _ in pairs(mOwners) do
        local oOwner = global.oWorldMgr:GetOnlinePlayerByPid(iOwner)
        if oOwner and oOwner:InWar() then
            return oOwner
        end
    end
    return nil
end

function CGrowthTicker:CallQte()
    if self.m_oQte then
        return
    end
    if self:AbleGrow() then
        local oQte = self:RandOutQte()
        if oQte then
            self.m_oQte = oQte
            oQte:DoStart()
            -- local iTeamId, iTaskId = self.m_iTeamId, self.m_iTaskId
            -- oQte:DoStart(function(bSucc)
            --     OnQteEnd(iTeamId, iTaskId, bSucc)
            -- end)
            return
        end
    end
    self:GoOn()
end

function OnQteEnd(iTeamId, iTaskId, bSucc)
    local oQte = GetQte(iTeamId, iTaskId)
    if oQte then
        oQte:EndQte(bSucc)
    end
end

local mAllQtes = {
    worm = "CQteWorm",
    water = "CQteWater",
    -- heart = "CQteHeart",
    question = "CQteQuestion",
}

function CGrowthTicker:RandOutQte()
    local oTask = GetTask(self.m_iTeamId, self.m_iTaskId)
    if not oTask then
        return
    end
    local cQteClass, sQteClass
    --- TEST --------
    if not is_production_env() then
        local sQteName = oTask.m_tmp_lingxi_qte_name
        if sQteName then
            sQteClass = mAllQtes[sQteName]
        end
    end
    --- END TEST ----
    if not sQteClass then
        sQteClass = extend.Random.random_choice(table_value_list(mAllQtes))
    end
    cQteClass = _ENV[sQteClass]
    if not cQteClass then
        return
    end
    local mOwners = oTask:GetOwners()
    local lOwnerList = table_key_list(mOwners)
    return cQteClass:New(self.m_iTeamId, self.m_iTaskId, lOwnerList)
end

function CGrowthTicker:DoNpcEvent(pid, oNpc)
    local oInWarOnwer = self:FindInWarOnwer()
    if oInWarOnwer then
        if oInWarOnwer:GetPid() == pid then
            global.oNotifyMgr:Notify(pid, lingxihuodong.GetText(2301))
        else
            global.oNotifyMgr:Notify(pid, lingxihuodong.GetText(2302))
        end
        return true
    end
    if self.m_oQte then
        return self.m_oQte:DoNpcEvent(pid, oNpc)
    end
    global.oNotifyMgr:Notify(pid, lingxihuodong.GetText(2014))
    return true
end

function CGrowthTicker:OnAwayFromFlower(iPid)
    if not self.m_mNear[iPid] then
        return
    end
    self.m_mNear[iPid] = nil
    self:TriggerFlowerGrow()
    if get_time() < self.m_iCheckNearFlowerTime then
        return
    end
    local oTask = GetTask(self.m_iTeamId, self.m_iTaskId)
    if oTask then
        oTask:NotifyTeamSeparately(iPid, lingxihuodong.GetText(2311), lingxihuodong.GetText(2312))
    end
end

function CGrowthTicker:OnCloseToFlower(iPid)
    if self.m_mNear[iPid] then
        return
    end
    self.m_mNear[iPid] = 1
    local bCanGrow = self:TriggerFlowerGrow()
    if get_time() < self.m_iCheckNearFlowerTime then
        return
    end
    local oTask = GetTask(self.m_iTeamId, self.m_iTaskId)
    if oTask then
        if bCanGrow then
            oTask:NotifyTeamSeparately(iPid, lingxihuodong.GetText(2313), lingxihuodong.GetText(2314))
        else
            oTask:NotifyTeamSeparately(iPid, lingxihuodong.GetText(2315), lingxihuodong.GetText(2316))
        end
    end
end

function CGrowthTicker:FillFlowerGrow(mInRangePids)
    for iPid, bIn in pairs(mInRangePids) do
        if bIn then
            self.m_mNear[iPid] = 1
        else
            self.m_mNear[iPid] = nil
        end
    end
end

function CGrowthTicker:TriggerFlowerGrow(mActions)
    local bCanGrow = self:CanFlowerGrow()
    if bCanGrow then
        if not mActions or not mActions.no_start then
            if not self:GetTimeCb("grow") and not self:GetCurQte() then
                self:GoOn()
            end
        end
    else
        local oQte = self:GetCurQte()
        if oQte then
            oQte:StopQte()
        end
        self:DelTimeCb("grow")
    end
    return bCanGrow
end

function CGrowthTicker:CanFlowerGrow()
    if table_count(self.m_mNear) >= 2 then
        return true
    else
        return false
    end
end
