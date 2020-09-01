--import module
local skynet = require "skynet"
local global = require "global"
local record = require "public.record"

local tableop = import(lualib_path("base.tableop"))
local datactrl = import(lualib_path("public.datactrl"))
local stateload = import(service_path("state/stateload"))

local max = math.max
local min = math.min

CStateCtrl = {}
CStateCtrl.__index = CStateCtrl
inherit(CStateCtrl, datactrl.CDataCtrl)

function CStateCtrl:New(pid)
    local o = super(CStateCtrl).New(self, {pid = pid})
    o.m_List = {}
    return o
end

function CStateCtrl:Release()
    for _,oState in pairs(self.m_List) do
        baseobj_safe_release(oState)
    end
    self.m_List = {}
    super(CStateCtrl).Release(self)
end

function CStateCtrl:Load(mData)
    mData = mData or {}
    local mStateData = mData["state"] or {}
    for iState,data in pairs(mStateData) do
        iState = tonumber(iState)
        local oState = stateload.LoadState(iState,data)
        if not oState:IsOutTime() then
            self.m_List[iState] = oState
            oState:SetInfo("pid",self:GetInfo("pid",0))
        end
    end
end

function CStateCtrl:Save()
    local mData = {}
    local mStateData = {}
    for iState,oState in pairs(self.m_List) do
        if oState:ValidSave() then
            mStateData[db_key(iState)] = oState:Save()
        end
    end
    mData["state"] = mStateData
    return mData
end

function CStateCtrl:OnLogin(oPlayer,bReEnter)
    self:AddBaoShi(oPlayer,bReEnter)
    self:AddDoublePoint(oPlayer,bReEnter)
    self:AddOnLogin(oPlayer,bReEnter)

    self:CheckBaoShi(oPlayer)
    if not bReEnter then
        local mState = table_copy(self.m_List)
        for iState,oState in pairs(mState) do
            oState:LoadEnd(oPlayer)
        end
    end
    local mData = {}
    for _,oState in pairs(self.m_List) do
        table.insert(mData,oState:PackNetInfo())
    end
    oPlayer:Send("GS2CLoginState",{state_info = mData})
end

function CStateCtrl:AddOnLogin(oPlayer, bReEnter)
    if bReEnter then return end

    self:AddState(1006, {})
end

function CStateCtrl:OnUpGrade(oPlayer)
    local oState = self:GetState(1006)
    if oState and oPlayer:GetGrade() >= oState:GetMinPGrade() then
        oState:Refresh(oPlayer:GetPid())
    end

    local oDPState = self:GetState(1004)
    if not oDPState then
        self:AddDoublePoint(oPlayer)
        oDPState = self:GetState(1004)
        if oDPState then
            self:GS2CAddState(oDPState)
        end
    end
end

function CStateCtrl:GetState(iState)
    return self.m_List[iState]
end

-- 超时是通过定时器积极超时处理的，因此此处仅供外部不能容忍定时器时间差的上层模块使用
-- 如果后面有需求，可以将其改为GetState(原Get改为GetRaw)
function CStateCtrl:HasState(iState)
    local oState = self:GetState(iState)
    if not oState then
        return false
    end
    if oState:IsOutTime() then
        oState:DelTimeCb("timeout")
        self:RemoveState(iState)
        return false
    end
    return oState
end

-- @param bForce: 某些与状态功能无关的必须挂上state，其用于表现其他功能（比如aoistate），则跳过open表检查
function CStateCtrl:AddState(iState,mData, bForce)
    if not bForce and is_production_env() then
        if not global.oToolMgr:IsSysOpen("STATE") then
            return
        end
    end
    local iPid = self:GetInfo("pid")
    local oState = self:GetState(iState)
    --待处理，暂时返回
    if oState then
        if oState:ReplaceType() == 3 then   --叠加
            oState:ReConfig(iPid, mData)
        end
        return
    end
    local oWorldMgr = global.oWorldMgr
    local oPlayer = oWorldMgr:GetOnlinePlayerByPid(iPid)
    assert(oPlayer,string.format("addstate err:%d %d",iPid,iState))
    self:Dirty()
    oState = stateload.NewState(iState)
    oState:Config(oPlayer,mData)
    self.m_List[iState] = oState
    oState:SetInfo("pid",iPid)
    oState:OnAddState(oPlayer)
    self:GS2CAddState(oState)

    local mLogData = oPlayer:LogData()
    mLogData["state"] = iState
    mLogData["args"] = mData or {}
    record.log_db("player", "add_state", mLogData)
    return oState
end

function CStateCtrl:RemoveState(iState)
    local oState = self:GetState(iState)
    if not oState then
        return
    end
    self:Dirty()
    self:GS2CRemoveState(oState)
    self.m_List[iState] = nil
    baseobj_delay_release(oState)
    local iPid = self:GetInfo("pid")
    local oWorldMgr = global.oWorldMgr
    local oPlayer = oWorldMgr:GetOnlinePlayerByPid(iPid)
    if oPlayer then
        oState:OnRemoveState(oPlayer)
        local mLogData = oPlayer:LogData()
        mLogData["state"] = iState
        record.log_db("player", "del_state", mLogData)
    end
end

function CStateCtrl:GS2CAddState(oState)
    local iPid = self:GetInfo("pid")
    local oWorldMgr = global.oWorldMgr
    local oPlayer = oWorldMgr:GetOnlinePlayerByPid(iPid)
    if not oPlayer then
        return
    end
    oPlayer:Send("GS2CAddState",{state_info=oState:PackNetInfo()})
end

function CStateCtrl:GS2CRemoveState(oState)
    local iPid = self:GetInfo("pid")
    local oWorldMgr = global.oWorldMgr
    local oPlayer = oWorldMgr:GetOnlinePlayerByPid(iPid)
    if not oPlayer then
        return
    end
    oPlayer:Send("GS2CRemoveState",{state_id=oState:ID()})
end

function CStateCtrl:UnDirty()
    super(CStateCtrl).UnDirty(self)
    for _,oState in pairs(self.m_List) do
        if oState:IsDirty() and oState:ValidSave() then
            oState:UnDirty()
        end
    end
end

function CStateCtrl:IsDirty()
    local bDirty = super(CStateCtrl).IsDirty(self)
   if bDirty then
        return true
    end
    for _,oState in pairs(self.m_List) do
        if oState:IsDirty()  and oState:ValidSave() then
            return true
        end
    end
    return false
end

function CStateCtrl:AddBaoShi(oPlayer,bReEnter)
    if is_production_env() then
        if not global.oToolMgr:IsSysOpen("STATE") then
            return
        end
    end
    local iState = 1003
    local mData = {}
    if bReEnter then return end
    local oState = self:GetState(iState)
    if oState then  return end
    local oPlayer = global.oWorldMgr:GetOnlinePlayerByPid(self:GetInfo("pid"))
    self:Dirty()
    oState = stateload.NewState(iState)
    oState:Config(oPlayer,mData)
    self.m_List[iState] = oState
    oState:SetInfo("pid",oPlayer:GetPid())
    local mLogData = oPlayer:LogData()
    mLogData["state"] = iState
    mLogData["args"] = mData
    record.log_db("player", "add_state", mLogData)
end

function CStateCtrl:AddDoublePoint(oPlayer,bReEnter)
    if not global.oToolMgr:IsSysOpen("STATE") then
        return
    end

    local iState = 1004
    --和日程同步
    if not global.oToolMgr:IsSysOpen("SCHEDULE", oPlayer, true) then
        local oState = self:GetState(iState)
        if oState then
            self:RemoveState(iState)
        end
        return
    end

    -- local iState = 1004
    local mData = {}
    if bReEnter then return end
    local oState = self:GetState(iState)
    if oState then  return end
    local oPlayer = global.oWorldMgr:GetOnlinePlayerByPid(self:GetInfo("pid"))
    self:Dirty()
    oState = stateload.NewState(iState)
    oState:Config(oPlayer,mData)
    self.m_List[iState] = oState
    oState:SetInfo("pid",oPlayer:GetPid())
    local mLogData = oPlayer:LogData()
    mLogData["state"] = iState
    mLogData["args"] = mData
    record.log_db("player", "add_state", mLogData)
end

function CStateCtrl:AddBaoShiCount(iVal, sReason)
    local oState = self:GetState(1003)
    if oState then
        oState:AddCount(self:GetInfo("pid"), iVal,true)
    end
end

function CStateCtrl:GetBaoShiMaxCount()
    local oState = self:GetState(1003)
    if oState then
        return oState:GetMaxCount()
    end
    return 0
end

function CStateCtrl:GetBaoShiCount()
    local oState = self:GetState(1003)
    if oState then
        return oState:GetCount()
    end
    return 0    
end

function CStateCtrl:RefreshDoublePoint()
    local oState = self:GetState(1004)
    if oState then
        return oState:Refresh(self:GetInfo("pid"))
    end
    return 0    
end

function CStateCtrl:CheckBaoShi(oPlayer)
    local oState = self:GetState(1003)
    if oState  and oState:GetCount()<30 then
        oState:PopUI(oPlayer:GetPid())
    end
end

function CStateCtrl:GetAllMapFlag()
    local iFlag = 0
    for iState,oState in pairs(self.m_List) do
        iFlag = iFlag | oState:MapFlag()
    end
    return iFlag
end

function CStateCtrl:RefreshMapFlag()
    local iPid = self:GetInfo("pid")
    local oPlayer = global.oWorldMgr:GetOnlinePlayerByPid(iPid)
    if oPlayer then
        local iFlag = self:GetAllMapFlag()
        oPlayer:SyncSceneInfo({state=iFlag})
    end
end

function CStateCtrl:GetAddExtraExpRatio()
    local iRatio = 0
    local oState = self:GetState(1010)
    if oState then
        iRatio = iRatio + oState:GetAddExpRatio()
    end
    return iRatio 
end

function CStateCtrl:GetAddServerExpRatio()
    local iRatio = 0
    local oState = self:GetState(1006)
    if oState then
        iRatio = iRatio + oState:GetAddExpRatio()
    end
    return iRatio 
end

function CStateCtrl:GetSummonExpRatio()
    local oState = self:GetState(1006)
    if not oState then return 0 end

    return math.max(0, oState:GetAddExpRatio())
end

function CStateCtrl:GetPartnerExpRatio()
    local oState = self:GetState(1006)
    if not oState then return 0 end

    return math.max(0, oState:GetAddExpRatio())
end

function CStateCtrl:GetLeaderExpRaito(sName, iMemCnt)
    local iPid = self:GetInfo("pid")
    local oPlayer = global.oWorldMgr:GetOnlinePlayerByPid(iPid)
    if not oPlayer or not oPlayer:IsTeamLeader() then return 0 end

    local oState = self:GetState(1007)
    if not oState then return 0 end

    return oState:GetLeaderExpRaito(sName, iMemCnt)
end

function CStateCtrl:AddTeamLeader()
    local iPid = self:GetInfo("pid")
    local oPlayer = global.oWorldMgr:GetOnlinePlayerByPid(iPid)
    if oPlayer and oPlayer:IsTeamLeader() then
        self:AddState(1007, {})
    end
end

function CStateCtrl:RemoveTeamLeader()
    local iPid = self:GetInfo("pid")
    local oPlayer = global.oWorldMgr:GetOnlinePlayerByPid(iPid)
    if oPlayer and not oPlayer:IsTeamLeader() then
        self:RemoveState(1007)
    end
end

