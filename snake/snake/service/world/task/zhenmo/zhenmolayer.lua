local global  = require "global"
local res = require "base.res"
local extend = require "base.extend"
local record = require "public.record"

local datactrl = import(lualib_path("public.datactrl"))
local huodongbase = import(service_path("huodong.huodongbase"))
local handleteam = import(service_path("team.handleteam"))
local analy = import(lualib_path("public.dataanaly"))
local gamedefines = import(lualib_path("public.gamedefines"))

function NewZhenmoLayer(...)
    local o = CZhenmoLayer:New(...)
    return o
end

CZhenmoLayer = {}
CZhenmoLayer.__index = CZhenmoLayer
inherit(CZhenmoLayer, huodongbase.CHuodong)

function CZhenmoLayer:New(iPid, iLayer)
    local o = super(CZhenmoLayer).New(self)
    o.m_iLayer = iLayer
    o.m_iPid = iPid
    return o
end

function CZhenmoLayer:Init()
    local mData = self:GetLayerConfig()
    self.m_sName = mData.layer_name
    self.m_iStep = 1
    self.m_oScene = nil
    self:CreateVirtualScene()
end

function CZhenmoLayer:Release()
    self:RemoveCurTask(true)
    self:RemoveVirtualScene()
    super(CZhenmoLayer).Release(self)
end

function CZhenmoLayer:CreateVirtualScene()
    if self.m_oScene then return end

    local mConfig = self:GetLayerConfig()
    local sLayerName = mConfig.layer_name
    local iSceneId = mConfig.scene_id
    local mConfig = self:GetLayerSceneConfig()
    local mData = {
        map_id = mConfig.map_id,
        team_allowed = mConfig.team_allowed,
        deny_fly = mConfig.deny_fly,
        is_durable = mConfig.is_durable ==1,
        has_anlei = mConfig.has_anlei == 1,
        url = {"zhenmo", "scene", iSceneId},
    }
    local oScene = global.oSceneMgr:CreateVirtualScene(mData)
    local iPid = self.m_iPid
    local func = function(iEvent, mData)
        local oPlayer = mData.player
        local oLeaveScene = mData.scene
        oLeaveScene:DelEvent(self, gamedefines.EVENT.PLAYER_LEAVE_SCENE)
        if not oLeaveScene.is_release_layer then
            oPlayer.m_oBaseCtrl.m_oZhenmoCtrl:ExitLayer()
        end
    end
    oScene:AddEvent(self, gamedefines.EVENT.PLAYER_LEAVE_SCENE, func)
    self.m_oScene = oScene
end

function CZhenmoLayer:RemoveVirtualScene()
    if self.m_oScene then
        self.m_oScene.is_release_layer = true
        local iSceneId = self.m_oScene:GetSceneId()
        global.oSceneMgr:RemoveVirtualScene(iSceneId)
        self.m_oScene = nil
    end
end

function CZhenmoLayer:GetPlayer()
    local oPlayer = global.oWorldMgr:GetOnlinePlayerByPid(self.m_iPid)
    assert(oPlayer, "CZhenmoLayer: player is not online")
    return oPlayer
end

function CZhenmoLayer:GameStart(iStep)
    self.m_iStep = iStep or 1
    --上次完整通关的，从第一关开始
    if self:IsComplete() then
        self.m_iStep = 1
    end
    self:CreateTask()
end

function CZhenmoLayer:CreateTask()
    local oPlayer = self:GetPlayer()
    local iTask = self:GetTaskIdByStep(self.m_iStep)
    local oTask = global.oTaskLoader:CreateTask(iTask)
    local bSuc = oPlayer.m_oTaskCtrl:AddTask(oTask)
    if bSuc then
        self:TransferLayer()
    end
end

function CZhenmoLayer:NextStep()
    local oTask = self:GetCurTask()
    if oTask then
        self.m_iStep = self.m_iStep + 1
    end
end

function CZhenmoLayer:TransferLayer()
    if not self.m_oScene then return end
    local oPlayer = self:GetPlayer()
    global.oSceneMgr:DoTransfer(oPlayer, self.m_oScene:GetSceneId())
end

function CZhenmoLayer:GetLayer()
    return self.m_iLayer
end

function CZhenmoLayer:GetStep()
    return self.m_iStep or 1
end

function CZhenmoLayer:IsComplete()
    local lList = self:GetLayerTaskList()
    return self.m_iStep > #lList
end

function CZhenmoLayer:GetTaskIdByStep(iStep)
    local mConfig = self:GetLayerTaskList()
    return mConfig[iStep]
end

function CZhenmoLayer:GetCurTask()
    local oPlayer = self:GetPlayer()
    local iTask = self:GetTaskIdByStep(self.m_iStep)
    local oTask = oPlayer.m_oTaskCtrl:GetTask(iTask)
    return oTask
end

function CZhenmoLayer:RemoveCurTask(bIsLeaveScene)
    local oPlayer = self:GetPlayer()
    local oTask = self:GetCurTask()
    if oTask then
        oTask.is_leave_scene = bIsLeaveScene
        oPlayer.m_oTaskCtrl:RemoveTask(oTask)
    end
end

function CZhenmoLayer:GetLayerConfig()
    local mConfig = res["daobiao"]["zhenmo"]["layer_config"][self.m_iLayer]
    assert(mConfig, string.format("CZhenmoLayer not find layer config: %s", self.m_iLayer))
    return mConfig
end

function CZhenmoLayer:GetLayerSceneConfig()
    local mConfig = self:GetLayerConfig()
    local iSceneId = mConfig.scene_id
    local mSceneConfig = res["daobiao"]["zhenmo"]["scene"][iSceneId]
    assert(mSceneConfig, string.format("CZhenmoLayer not find scene config: %s", sLayerName))
    return mSceneConfig
end

function CZhenmoLayer:GetLayerTaskList()
    local mConfig = self:GetLayerConfig()
    assert(mConfig.task_list, string.format("CZhenmoLayer not find layer config task_list : %s", self.m_iLayer))
    return mConfig.task_list
end
