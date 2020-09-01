local global = require "global"
local res = require "base.res"
local extend = require "base.extend"

local datactrl = import(lualib_path("public.datactrl"))
local defines = import(service_path("fuben.defines"))
local gamedefines = import(lualib_path("public.gamedefines"))
local zhenmolayer = import(service_path("task.zhenmo.zhenmolayer"))
local taskdefines = import(service_path("task/taskdefines"))
local net = require "base.net"

function NewZhenmoCtrl(...)
    local o = CZhenmoCtrl:New(...)
    return o
end

CZhenmoCtrl = {}
CZhenmoCtrl.__index = CZhenmoCtrl
inherit(CZhenmoCtrl, datactrl.CDataCtrl)

function CZhenmoCtrl:New(iPid)
    local o = super(CZhenmoCtrl).New(self)
    o.m_iPid = iPid
    o.m_mLayers = {}
    o.m_iLastRefreshTime = 0
    o.m_bDelayReset = false
    o.m_oCurLayer = nil
    o.m_bSpecialLeave = false
    o.m_iPlayerAnimLayerId = nil
    o.m_bNewDay = false
    o.m_bLastWarWin = false

    o.m_mDay = {}
    o.m_mWeek = {}
    return o
end

function CZhenmoCtrl:OnLogin(oPlayer, bReEnter)
    if not bReEnter then
        self:AddAbandonEvent()
    end

    if not self.m_bDelayReset then
        self:TryResetDay()
    end
    self:GS2CZhenmoRefresh()
end

function CZhenmoCtrl:Release()
    self:ReleaseCurLayer()
    super(CZhenmoCtrl).Release(self)
end

function CZhenmoCtrl:Save()
    local mData = {
        layers = self.m_mLayers,
        lasttime = self.m_iLastRefreshTime,
        day = self.m_mDay,
        week = self.m_mWeek,
    }
    return mData
end

function CZhenmoCtrl:Load(mData)
    if not mData then return end
    self.m_mLayers = mData.layers or {}
    self.m_iLastRefreshTime = mData.lasttime or 0
    self.m_mDay = mData.day or {}
    self.m_mWeek = mData.week or {}
end

function CZhenmoCtrl:AddAbandonEvent()
    local oPlayer = self:GetPlayer()
    oPlayer.m_oTaskCtrl:AddEvent(self, taskdefines.EVENT.DEL_TASK, function(iEvent, mData)
        local oPlayer = global.oWorldMgr:GetOnlinePlayerByPid(mData.pid)
        if oPlayer then
            oPlayer.m_oBaseCtrl.m_oZhenmoCtrl:AbandonTask(mData.task)
        end
    end)
end

--如果从任务界面手动删除时，要销毁场景
function CZhenmoCtrl:AbandonTask(oTask)
    if self.m_oCurLayer then
        if oTask and not oTask:IsDone() and not oTask.is_leave_scene then
            self:TransferHome()
        end        
    end
end

function CZhenmoCtrl:GetPlayer()
    local oPlayer = global.oWorldMgr:GetOnlinePlayerByPid(self.m_iPid)
    assert(oPlayer, "CZhenmoCtrl: player is not online")
    return oPlayer
end

function CZhenmoCtrl:NewHour5(mNow)
    --刷天还在塔中,延迟刷新
    if self.m_oCurLayer then
        self.m_bDelayReset = true
        return
    else
        self:TryResetDay(mNow)
        self:GS2CZhenmoRefresh()
    end
end

function CZhenmoCtrl:TryResetDay(mNow, bForce)
    self.m_bDelayReset = false
    self.m_bNewDay = false
    local iTime = mNow and mNow.time or get_time()
    local iDayNo = get_morningdayno(self.m_iLastRefreshTime)
    local iTodayNo = get_morningdayno(iTime)
    if iDayNo ~= iTodayNo or bForce then
        local oPlayer = self:GetPlayer()
        oPlayer.m_oScheduleCtrl:DeleteSchedule(1040)

        for _, mLayer in pairs(self.m_mLayers) do
            mLayer.step = 1
            mLayer.task = {}
            mLayer.war_time = 0
        end
        self.m_iLastRefreshTime = iTime
        self:Dirty()
        self.m_bNewDay = true

        self.m_mDay = {}
        local iWDay = mNow and mNow.date.wday or get_weekday()
        if iWDay == 1 then
            self.m_mWeek = {}
        end
    end
end

function CZhenmoCtrl:EnterLayer(iLayerId)
    local oPlayer = self:GetPlayer()
    local bOpen = global.oToolMgr:IsSysOpen("ZHENMO")
    if not bOpen then return end

    if self.m_oCurLayer then 
        self:ReleaseCurLayer()
    end
    if not self:ValidCondition(iLayerId) then return end

    self.m_bSpecialLeave = false
    self.m_iPlayerAnimLayerId = nil
    self.m_bLastWarWin = false

    self.m_oCurLayer = zhenmolayer.NewZhenmoLayer(self.m_iPid, iLayerId)
    self.m_oCurLayer:Init()

    if not self.m_mLayers[iLayerId] then
        self.m_mLayers[iLayerId] = {
            complete = false,
            step = 1,
            task = {},
            war_time = 0,
        }
    end
        
    local iStep = self.m_mLayers[iLayerId].step
    self.m_oCurLayer:GameStart(iStep)
end

function CZhenmoCtrl:ValidCondition(iLayerId)
    local oPlayer = self:GetPlayer()

    local oTeam = oPlayer:HasTeam()
    if oTeam then
        local sMsg = self:FormatMsg(1001)
        global.oNotifyMgr:Notify(self.m_iPid, sMsg)
        return false
    end

    local mConfig = self:GetLayerConfig(iLayerId)
    local iNeedGrade = mConfig.player_level
    local iGrade = oPlayer:GetGrade()
    if iGrade < iNeedGrade then
        local sMsg = self:FormatMsg(1002, {grade = iNeedGrade})
        global.oNotifyMgr:Notify(self.m_iPid, sMsg)
        return false
    end

    return true
end

function CZhenmoCtrl:ExitLayer()
    self:RecordStep()
    self:ReleaseCurLayer()

    --刷天时因为正在关卡而延迟，退出时刷新
    if self.m_bDelayReset then
        self:TryResetDay(nil, true)
        self:GS2CZhenmoRefresh()
    end
end

function CZhenmoCtrl:TransferHome()
    local oPlayer = self:GetPlayer()
    local iMapID = 103000
    local oScene = global.oSceneMgr:SelectDurableScene(iMapID)
    global.oSceneMgr:DoTransfer(oPlayer, oScene:GetSceneId())

    if self.m_iPlayerAnimLayerId then
        local iLayerId = self.m_iPlayerAnimLayerId
        local mConfig = self:GetLayerConfig(iLayerId)
        local iAnim = mConfig.anim
        self:PlayAnimation(iAnim)
    end
end

function CZhenmoCtrl:PlayAnimation(iAnim)
    local oPlayer = self:GetPlayer()
    oPlayer.m_oTaskCtrl:PlayStoryAnime(iAnim)
end

function CZhenmoCtrl:OnTaskDone(iTaskId)
    local oLayer = self:GetCurLayer()
    oLayer:NextStep()
    self:RecordStep(iTaskId)

    local oPlayer = self:GetPlayer()
    oPlayer.m_oScheduleCtrl:Add(1040)
end

function CZhenmoCtrl:WarFightEnd()
    self.m_bLastWarWin = false
end

function CZhenmoCtrl:OnAddDone(oTask)
    if oTask and self.m_bLastWarWin then
        local oPlayer = self:GetPlayer()
        oTask:Click(oPlayer:GetPid())
    end
end

function CZhenmoCtrl:IsLastWarWin()
    return self.m_bLastWarWin
end

function CZhenmoCtrl:RecordStep(iTaskId)
    local oLayer = self:GetCurLayer()
    local iLayerId = oLayer:GetLayer()
    local iStep = oLayer:GetStep()
    local bComplete = oLayer:IsComplete()
    local mLayer = self.m_mLayers[iLayerId]
    mLayer.step = iStep
    if not mLayer.complete and bComplete then
        mLayer.complete = bComplete
        self.m_iPlayerAnimLayerId = iLayerId
        local oPlayer = self:GetPlayer()
        oPlayer:MarkGrow(53)
    end
    if iTaskId then
        mLayer.task[iTaskId] = true
    end

    self.m_iLastRefreshTime = get_time()
    self:Dirty()
    self:GS2CZhenmoRefresh()
end

function CZhenmoCtrl:OnWarWin(iWarTime)
    self.m_bLastWarWin = true
    local iLayerId = self:GetCurLayerId()
    local mLayer = self.m_mLayers[iLayerId]
    if mLayer then
        mLayer.war_time = mLayer.war_time + iWarTime
    end
end

function CZhenmoCtrl:GetCurLayer()
    assert(self.m_oCurLayer, "CZhenmoCtrl: error layer")
    return self.m_oCurLayer
end

function CZhenmoCtrl:GetCurLayerId()
    local oLayer = self:GetCurLayer()
    return oLayer:GetLayer()
end

function CZhenmoCtrl:ReleaseCurLayer()
    if not self.m_oCurLayer then return end

    local oPlayer = self:GetPlayer()
    oPlayer:DelTimeCb("ZhenmoSpecialReward")

    baseobj_safe_release(self.m_oCurLayer)
    self.m_oCurLayer = nil
end

function CZhenmoCtrl:SpecialReward(mReward)
    local oPlayer = self:GetPlayer()
    self.m_bSpecialLeave = true
    oPlayer:AddTimeCb("ZhenmoSpecialReward", 10*1000, function()
        if self.m_oCurLayer then
            self:GS2CZhenmoSpecialReward(nil, false)
            self:TransferHome()
        end
    end)
    self:GS2CZhenmoSpecialReward(mReward, true)
end

function CZhenmoCtrl:LayerDone()
    if not self.m_bSpecialLeave then
        self:TransferHome()
    end
end

function CZhenmoCtrl:GetDay()
    return self.m_mDay
end

function CZhenmoCtrl:GetWeek()
    return self.m_mWeek
end

function CZhenmoCtrl:GS2CZhenmoRefresh()
    local mData = {}
    for iLayerId, mLayer in pairs(self.m_mLayers or {}) do
        local mTask = mLayer.task
        local iCount = table_count(mTask)
        local mTmp = {
            layer = iLayerId, 
            reward = iCount,
            complete = mLayer.complete and 1 or 0
        }
        table.insert(mData, mTmp)
    end
    local oPlayer = self:GetPlayer()

    local mNet = {
        layers = mData,
        is_newday = self.m_bNewDay and 1 or 0
    }
    oPlayer:Send("GS2CZhenmoRefresh", mNet)
    self.m_bNewDay = false
end

function CZhenmoCtrl:GS2CZhenmoSpecialReward(mReward, bOpen)
    local iLayerId = self:GetCurLayerId()
    local mLayer = self.m_mLayers[iLayerId]
    local iWarTime = mLayer.war_time

    local oPlayer = self:GetPlayer()
    local mData = {
        is_open = bOpen and 1 or 2
    }
    if mReward then
        mData.rewards = mReward
        mData.war_time = iWarTime
    end
    mData = net.Mask("GS2CZhenmoSpecialReward", mData)
    oPlayer:Send("GS2CZhenmoSpecialReward", mData)
end

function CZhenmoCtrl:C2GSZhenmoEnterLayer(iLayerId)
    if iLayerId then
        self:EnterLayer(iLayerId)
    end
end

function CZhenmoCtrl:C2GSZhenmoPlayAnim(iAnim)
    if iAnim then
        self:PlayAnimation(iAnim)
    end
end

function CZhenmoCtrl:C2GSZhenmoSpecialReward()
    local oPlayer = self:GetPlayer()
    oPlayer:DelTimeCb("ZhenmoSpecialReward")
    self:TransferHome()
end

function CZhenmoCtrl:C2GSZhenmoOpenView()
    local oPlayer = self:GetPlayer()
    local bOpen = global.oToolMgr:IsSysOpen("ZHENMO", oPlayer)
    if not bOpen then return end
    oPlayer:Send("GS2CZhenmoOpenView", {})
end

function CZhenmoCtrl:FormatMsg(iText, mReplace)
    local oToolMgr = global.oToolMgr
    local sMsg = oToolMgr:GetTextData(iText, {"zhenmo"})
    if mReplace then
        sMsg = oToolMgr:FormatColorString(sMsg, mReplace)
    end
    return sMsg
end

function CZhenmoCtrl:GetLayerConfig(iLayerId)
    local mConfig = res["daobiao"]["zhenmo"]["layer_config"][iLayerId]
    assert(mConfig, string.format("CZhenmoLayer not find layer config: %s", iLayerId))
    return mConfig
end

function CZhenmoCtrl:TestOp(oMaster, oPlayer, sCmd, mArgs)
    local iPid = oMaster:GetPid()
    if sCmd == 100 then
         global.oNotifyMgr:Notify(iPid, [[
        101 - 进入指定层 zhenmo 0 101 {layer=10001}
        102 - 返回西湖场景 zhenmo 0 102
        103 - 清空玩家所有数据 zhenmo 0 103
        ]])
    elseif sCmd == 101 then
        local iLayerId = mArgs and mArgs.layer or 10001
        if self.m_oCurLayer then
            baseobj_safe_release(self.m_oCurLayer)
            self.m_oCurLayer = nil
        end
        self:EnterLayer(iLayerId)
    elseif sCmd == 102 then
        self:TransferHome()
    elseif sCmd == 103 then
        self.m_mLayers = {}
        self.m_mDay = {}
        self.m_mWeek = {}
        self:Dirty()
        self:GS2CZhenmoRefresh()
    elseif sCmd == 104 then
        self.m_iLastRefreshTime = 0
        local iTime = get_time() + 24 * 3600
        self:NewHour5({time = iTime , date = {wday = 1}})
    end
end