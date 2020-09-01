local global = require "global"

function NewAnleiCtrl(pid)
    return CAnLeiCtrl:New(pid)
end

CAnLeiCtrl = {}
CAnLeiCtrl.__index = CAnLeiCtrl
inherit(CAnLeiCtrl, logic_base_cls())

function CAnLeiCtrl:New(pid)
    local o = super(CAnLeiCtrl).New(self)
    o.m_iPid = pid
    o.m_mAnleiMap = {} -- {<mapid> = {<taskid> = true, ...}}
    o.m_mRegTask = {} -- {<taskid> = {<mapid> = true, ...}}
    o.m_mPlayerInfo = {} -- {map = mapid, x = curX, y = curY, sync_time = now, start_time = startMoveTime, walked_time = totalWalked, check_time = checkTriggerTime}
    o.m_iCurTriggerTask = nil
    return o
end

function CAnLeiCtrl:Release()
    self.m_mAnleiMap = {}
    self.m_mRegTask = {}
    self.m_mPlayerInfo = {}
    super(CAnLeiCtrl).Release(self)
end

-- FIXME 处理posQueue引发的时间集中问题
function CAnLeiCtrl:UpdatePos(iPid, iMapId, mPosInfo, mExtra)
    -- mExtra = mExtra or {}
    -- if mExtra.stopped then
    --     self:Stand(iPid)
    --     return
    -- end
    local m = self.m_mPlayerInfo[iPid]
    if m then
        if m.map ~= iMapId then
            self:DelPos(iPid)
            self:AddPos(iPid, iMapId, mPosInfo)
            return
        end
        if m.x ~= mPosInfo.x or m.y ~= mPosInfo.y then
            local iNow = get_time()
            m.x = mPosInfo.x
            m.y = mPosInfo.y
            m.sync_time = iNow
            if not m.start_time then
                m.start_time = iNow
            end
        end
    else
        self:AddPos(iPid, iMapId, mPosInfo)
    end
end

-- @param mPosInfo: 玩家的坐标
function CAnLeiCtrl:AddPos(iPid, iMapId, mPosInfo)
    local iNow = get_time()
    self.m_mPlayerInfo[iPid] = {
        map = iMapId,
        x = mPosInfo.x,
        y = mPosInfo.y,
        sync_time = iNow, -- 最新同步时间
        start_time = iNow, -- 连续走路的开始时间
        walked_time = 0, -- 当前连续走路前已走时间
    }
end

function CAnLeiCtrl:Stand(iPid)
    local m = self.m_mPlayerInfo[iPid]
    if m then
        local iNow = get_time()
        local iLastStartTime = m.start_time
        if iLastStartTime then
            m.walked_time = (m.walked_time or 0) + iNow - iLastStartTime
            m.start_time = nil
        end
        m.sync_time = iNow
    end
end

function CAnLeiCtrl:DelPos(iPid)
    self.m_mPlayerInfo[iPid] = nil
end

-- TODO 触发规则调整，需要改成前端触发后端校验(为了更好的表现，防止每次触发命中都在角色移动开始的瞬间)
function CAnLeiCtrl:CheckTriggerAnLei(iPid, iMapId)
    local m = self.m_mPlayerInfo[iPid]
    if not m then
        return
    end
    local iTime = get_time()
    if m.check_time and m.check_time >= iNow then
        return
    end
    m.check_time = iNow
    if (iTime - m.sync_time > 5) then -- 坐标5s内若未同步一次，表示玩家不在移动
        self:Stand(iPid)
    end
    if not m.start_time then
        return
    end
    local oPlayer = global.oWorldMgr:GetOnlinePlayerByPid(iPid)
    if not oPlayer then
        return
    end
    if not oPlayer:IsSingle() and not oPlayer:IsTeamLeader() then
        return
    end
    local oNowWar = oPlayer.m_oActiveCtrl:GetNowWar()
    if oNowWar then
        return
    end
    local oTriggerTask = self:ValidTriggerAnlei(iMapId)
    if not oTriggerTask then
        return
    end
    local bTrigger
    local iWalkedTime = m.walked_time + iTime - m.start_time
    if iWalkedTime >= 7 then
        bTrigger = true
    elseif iWalkedTime >= 3 then
        bTrigger = (math.random(1, 100) <= 50)
    end
    if bTrigger then
        self:DelPos(iPid)
        oTriggerTask:TriggerAnLei(iMapId)
        self.m_iCurTriggerTask = oTriggerTask:GetId()
    end
end

function CAnLeiCtrl:UpdateTriggerAnLei(oPlayer, iMapId, mPosInfo, mExtra)
    local iPid = oPlayer:GetPid()
    local oTriggerTask = self:ValidTriggerAnlei(iMapId)
    if not oTriggerTask then
        return
    end
    self:UpdatePos(iPid, iMapId, mPosInfo, mExtra)
    if mExtra and not mExtra.stopped then
        self:CheckTriggerAnLei(iPid, iMapId)
    end
end

function CAnLeiCtrl:ValidTriggerAnlei(iMapId)
    local oPlayer = global.oWorldMgr:GetOnlinePlayerByPid(self.m_iPid)
    if not oPlayer then
        return false
    end
    local mTasks = self.m_mAnleiMap[iMapId]
    if not mTasks then
        return false
    end
    local mInvalidTasks = {}
    local oTriggerTask
    for iTaskid, _ in pairs(mTasks) do
        local oTask = global.oTaskMgr:GetUserTask(oPlayer, iTaskid, true)
        if oTask and oTask:IsAnlei() then
            if not oTriggerTask then
                oTriggerTask = oTask
                break
            end
        else
            mInvalidTasks[iTaskid] = 1
        end
    end
    for iTaskid, _ in pairs(mInvalidTasks) do
        self:UnregWholeTask(iTaskid)
    end
    return oTriggerTask or false
end

function CAnLeiCtrl:IsMapHasAnlei(iMapId)
    local mMapTasks = self.m_mAnleiMap[iMapId]
    if mMapTasks and next(mMapTasks) then
        return true
    end
end

function CAnLeiCtrl:LoginEnd(bReEnter)
    -- 继续暗雷寻路只有重登需要
    if not bReEnter then
        return
    end
    local iPid = self.m_iPid
    local oPlayer = global.oWorldMgr:GetOnlinePlayerByPid(iPid)
    if not oPlayer then
        return
    end
    local oNowScene = oPlayer.m_oActiveCtrl:GetNowScene()
    if not oNowScene then
        return
    end
    local iMapId = oNowScene:MapId()
    if self.m_iCurTriggerTask then
        if table_get_depth(self.m_mRegTask, {self.m_iCurTriggerTask, iMapId}) then
            if self:TouchLoginAnleiXunluo(oPlayer, self.m_iCurTriggerTask) then
                return
            end
        end
    end
    local mTasks = self.m_mAnleiMap[iMapId]
    if mTasks then
        for iTaskId, _ in pairs(mTasks) do
            if self:TouchLoginAnleiXunluo(oPlayer, iTaskId) then
                return
            end
        end
    end
end

function CAnLeiCtrl:TouchLoginAnleiXunluo(oPlayer, iTaskId)
    local oTask = global.oTaskMgr:GetUserTask(oPlayer, iTaskId, true)
    if not oTask then
        return
    end
    if oTask:IsNeedLoginAnleiXunluo() then
        oPlayer:Send("GS2CXunLuo", {type=1})
        return true
    end
end

function CAnLeiCtrl:RegTaskMap(iTaskid, iMapId)
    table_set_depth(self.m_mAnleiMap, {iMapId}, iTaskid, 1)
    table_set_depth(self.m_mRegTask, {iTaskid}, iMapId, 1)
end

function CAnLeiCtrl:UnregTaskMap(iTaskid, iMapId)
    table_del_depth_casc(self.m_mAnleiMap, {iMapId}, iTaskid)
    table_del_depth_casc(self.m_mRegTask, {iTaskid}, iMapId)
end

function CAnLeiCtrl:UnregWholeTask(iTaskid)
    if not self.m_mRegTask[iTaskid] then
        return
    end
    for iMapId, _ in pairs(self.m_mRegTask[iTaskid] or {}) do
        table_del_depth_casc(self.m_mAnleiMap, {iMapId}, iTaskid)
    end
    self.m_mRegTask[iTaskid] = nil
    -- 结束巡逻
    if iTaskid == self.m_iCurTriggerTask then
        self.m_iCurTriggerTask = nil
        local oPlayer = global.oWorldMgr:GetOnlinePlayerByPid(self.m_iPid)
        if oPlayer then
            oPlayer:Send("GS2CXunLuo", {type=0})
        end
    end
end

function CAnLeiCtrl:CurTriggerTask()
    return self.m_iCurTriggerTask
end

function CAnLeiCtrl:OnStopXunLuo()
    local iPid = self.m_iPid
    local oPlayer = global.oWorldMgr:GetOnlinePlayerByPid(iPid)
    if not oPlayer then
        return
    end

    local m = self.m_mPlayerInfo[iPid]
    local oTriggerTask
    if m then
        local iMapId = m.map
        oTriggerTask = self:ValidTriggerAnlei(iMapId)
    else
        if self.m_iCurTriggerTask then
            oTriggerTask = global.oTaskMgr:GetUserTask(oPlayer, self.m_iCurTriggerTask, true)
        end
    end
    self:DelPos(iPid)

    if not oTriggerTask then
        self.m_iCurTriggerTask = nil
        return
    end
    oTriggerTask:OnStopXunLuo(oPlayer)
end
