local global = require "global"

local datactrl = import(lualib_path("public.datactrl"))
local gamedefines = import(lualib_path("public.gamedefines"))

function GetBianshenInfo(iBianshenId)
    if not iBianshenId then
        return nil
    end
    local res = require "base.res"
    return table_get_depth(res, {"daobiao","bianshen", iBianshenId})
end

-----------------------------------

CBianShenObj = {}
CBianShenObj.__index = CBianShenObj
inherit(CBianShenObj, datactrl.CDataCtrl)

function CBianShenObj:New(pid, mBianData)
    local o = super(CBianShenObj).New(self, {pid = pid})
    o:Load(mBianData or {})
    o:UnDirty()
    return o
end

-- 临时的sessionId，用以查询，不能用全局local变量，否则热更会清零从头计数
function CBianShenObj:SetSid(iSid)
    self.m_tmp_Sid = iSid
end

function CBianShenObj:Init(mBianData)
    self:SetData("id", mBianData.id) -- 变身表ID
    self:SetData("prio", mBianData.prio) -- 优先级
    self:SetData("group", mBianData.group) -- 分组（enum定义玩法等）
    if mBianData.source then
        self:SetData("source", table_deep_copy(mBianData.source))
    end
    self:SetData("create_time", mBianData.create_time)
    self:SetData("end_time", mBianData.end_time)
end

function CBianShenObj:GetPid()
    return self:GetInfo("pid")
end

function CBianShenObj:Save()
    local mData = {
        data = self.m_mData
    }
    return mData
end

function CBianShenObj:Load(mData)
    self.m_mData = mData.data or {}
end

function OnBianShenObjTimeOut(iPid, iSid)
    local oPlayer = global.oWorldMgr:GetOnlinePlayerByPid(iPid)
    if not oPlayer then
        return
    end
    local oBianshen = oPlayer.m_oBaseCtrl.m_oBianShenMgr:GetBianShenObj(iSid)
    if not oBianshen then
        return
    end
    oBianshen:TimeOut()
end

function CBianShenObj:CheckTimeCb()
    self:Setup()
end

function CBianShenObj:Setup()
    -- TODO 改为cron
    local iTime = self:Timer()
    if iTime > 0 then
        if iTime > 1 * 24 * 3600 then return end
        local iPid = self:GetPid()
        local iSid = self:SID()
        self:DelTimeCb("timeout")
        self:AddTimeCb("timeout", iTime * 1000, function()
            OnBianShenObjTimeOut(iPid, iSid)
        end)
    elseif iTime == 0 then
        oBianshen:TimeOut()
    end
end

function CBianShenObj:Remove(bNoSync)
    local iPid = self:GetPid()
    local oWorldMgr = global.oWorldMgr
    local oPlayer = oWorldMgr:GetOnlinePlayerByPid(iPid)
    if oPlayer then
        oPlayer.m_oBaseCtrl.m_oBianShenMgr:RemoveBianShen(self, bNoSync)
    end
end

function CBianShenObj:Source()
    return self:GetData("source")
end

function CBianShenObj:Group()
    return self:GetData("group")
end

function CBianShenObj:Priority()
    return self:GetData("prio")
end

function CBianShenObj:GetCreateTime()
    return self:GetData("create_time")
end

function CBianShenObj:ID()
    return self:GetData("id")
end

function CBianShenObj:SID()
    return self.m_tmp_Sid
end

function CBianShenObj:Timer()
    local iEndTime = self:GetData("end_time")
    local iNowTime = get_time()
    if not iEndTime then
        return -1
    elseif iEndTime < 0 then
        return -1
    elseif iEndTime > iNowTime then
        return iEndTime - iNowTime
    end
    return 0
end

function CBianShenObj:TimeOut()
    self:Remove()
end

function CBianShenObj:IsTimeOut()
    local iRestTime = self:Timer()
    return iRestTime == 0
end

function CBianShenObj:GetModelInfo()
    local mBianshenInfo = GetBianshenInfo(self:ID())
    local iFigureId = mBianshenInfo.figure
    local mModelInfo = global.oToolMgr:GetFigureModelData(iFigureId)
    return mModelInfo
end

function CBianShenObj:GetTitleInfo()
    local mBianshenInfo = GetBianshenInfo(self:ID())
    local mTitleStruct = mBianshenInfo.title
    return {
        tid = mTitleStruct.tid,
        name = mTitleStruct.name,
        achieve_time = self:GetCreateTime(),
    }
end

function CBianShenObj:CanInWar()
    local mBianshenInfo = GetBianshenInfo(self:ID())
    local iInWar = mBianshenInfo.in_war
    return iInWar == 1
end

function CBianShenObj:GetWarPerform()
    if not self:CanInWar() then
        return nil
    end
    local mBianshenInfo = GetBianshenInfo(self:ID())
    if mBianshenInfo.no_skill == 1 then
        return {}
    end
    local mActiveSkill = mBianshenInfo.active_skills
    if not mActiveSkill or not next(mActiveSkill) then
        return nil
    end
    local mPerform = {}
    for _,mSkill in pairs(mActiveSkill) do
        local iPerform = mSkill["pfid"]
        mPerform[iPerform] = mSkill["lv"]
    end
    return mPerform
end

-----------------------------------

CBianShenMgr = {}
CBianShenMgr.__index = CBianShenMgr
inherit(CBianShenMgr, datactrl.CDataCtrl)

function NewBianShenMgr(pid)
    return CBianShenMgr:New(pid)
end

function CBianShenMgr:New(pid)
    local o = super(CBianShenMgr).New(self, {pid = pid})
    o.m_mBianshen = {}
    return o
end

function CBianShenMgr:Release()
    for _, oBianshen in pairs(self.m_mBianshen) do
        baseobj_safe_release(oBianshen)
    end
    self.m_mBianshen = {}
    super(CBianShenMgr).Release(self)
end

function CBianShenMgr:GetPid()
    return self:GetInfo("pid")
end

function CBianShenMgr:Save()
    local mData = {}
    local mAllBianshens = {}
    for iSid, oBianshen in pairs(self.m_mBianshen) do
        table.insert(mAllBianshens, oBianshen:Save())
    end
    mData.all_bian = mAllBianshens
    -- mData.origin_origin = self.m_mOriginModel
    return mData
end

function CBianShenMgr:Load(mData)
    local mAllBianshens = {}
    self.m_mBianshen = {}
    local bTimeouted = false
    local iPid = self:GetPid()
    for _, mBianData in pairs(mData.all_bian or {}) do
        local oBianshen = CBianShenObj:New(iPid, mBianData)
        if oBianshen:IsTimeOut() then
            baseobj_delay_release(oBianshen)
            bTimeouted = true
        else
            local iNewTmpSid = self:NewSid()
            oBianshen:SetSid(iNewTmpSid)
            oBianshen:Setup()
            self:AppendBianShen(oBianshen)
        end
    end

    if bTimeouted then
        self:Dirty()
    else
        self:UnDirty()
    end

    self:RefreshSceneFigure(true)
end

function CBianShenMgr:IsDirty()
    if super(CBianShenMgr).IsDirty(self) then
        return true
    end
    for iSid, oBianshen in pairs(self.m_mBianshen) do
        if oBianshen:IsDirty() then
            return true
        end
    end
    return false
end

function CBianShenMgr:UnDirty()
    super(CBianShenMgr).UnDirty(self)
    for iSid, oBianshen in pairs(self.m_mBianshen) do
        if oBianshen:IsDirty() then
            oBianshen:UnDirty()
        end
    end
end

function CBianShenMgr:SyncBianshen()
    local iPid = self:GetPid()
    local oPlayer = global.oWorldMgr:GetOnlinePlayerByPid(iPid)
    if oPlayer then
        oPlayer:SyncBianshenInfo()
    end
end

function CBianShenMgr:NewSid()
    self.m_iTmpSid = (self.m_iTmpSid or 0) + 1
    return self.m_iTmpSid
end


function CBianShenMgr:SetBianShen(iBianshenId, iSec, iPrio, sGroup, mSource)
    self:Dirty()
    local now = get_time()
    local iEndTime
    if not iSec or iSec <= 0 then
        iEndTime = -1
    else
        iEndTime = iSec + now
    end
    local mBianData = {
        id = iBianshenId,
        prio = iPrio or gamedefines.BIANSHEN_PRIORITY.DEFAULT,
        group = sGroup,
        source = mSource,
        create_time = now,
        end_time = iEndTime,
    }
    local iPid = self:GetPid()
    local oBianshen = CBianShenObj:New(iPid)
    local iNewTmpSid = self:NewSid()
    oBianshen:SetSid(iNewTmpSid)
    oBianshen:Init(mBianData)
    oBianshen:Setup()
    self:AppendBianShen(oBianshen)

    -- 需要在worldobj:NewPlayer后加一个InitEventReg时机才能让两个ctrl内建立注册
    -- self:TriggerEvent(gamedefines.EVENT.PLAYER_BIANSHEN, {bianshenid = iBianshenId, group = sGroup})
    -- self:TouchUnRide()
    self:OnBianShen()

    self:RefreshSceneFigure()
end

function CBianShenMgr:OnBianShen()
    local oPlayer = global.oWorldMgr:GetOnlinePlayerByPid(self:GetPid())
    if not oPlayer then return end
    
    oPlayer.m_oRideCtrl:OnBeforeBianShen()
    self:TouchUnRide()
end

function CBianShenMgr:OnRemoveBianShen()
    local oPlayer = global.oWorldMgr:GetOnlinePlayerByPid(self:GetPid())
    if not oPlayer then return end

    oPlayer.m_oRideCtrl:OnAfterBianShen()    
end

function CBianShenMgr:TouchUnRide()
    local iPid = self:GetPid()
    local oPlayer = global.oWorldMgr:GetOnlinePlayerByPid(iPid)
    if not oPlayer then
        return
    end
    oPlayer.m_oRideCtrl:TouchUnRide(true)
end

function CBianShenMgr:AppendBianShen(oBianshen)
    -- 此处设计使用tmpsid来hash，是因为允许同一个iBianshenId的变身在不同的玩法都存在，则玩家身上的变身数据可能是叠加的
    self.m_mBianshen[oBianshen:SID()] = oBianshen
    self:Dirty()
end

function CBianShenMgr:GetBianShenObj(iSid)
    return self.m_mBianshen[iSid]
end

function CBianShenMgr:GetFrontBianShen(fFilter)
    local oFrontBianshen
    local now = get_time()
    local mTimeouts = {}
    for iSid, oBianshen in pairs(self.m_mBianshen or {}) do
        if oBianshen:IsTimeOut() then
            mTimeouts[iSid] = oBianshen
        else
            if fFilter then
                if not fFilter(oBianshen) then
                    goto continue
                end
            end
            if not oFrontBianshen then
                oFrontBianshen = oBianshen
            else
                local iPrioCur, iPrioFront = oBianshen:Priority(), oFrontBianshen:Priority()
                if iPrioCur > iPrioFront then
                    oFrontBianshen = oBianshen
                elseif iPrioCur == iPrioFront then
                    if oBianshen:GetCreateTime() < oFrontBianshen:GetCreateTime() then
                        oFrontBianshen = oBianshen
                    end
                end
            end
        end
        ::continue::
    end
    for iSid, oBianshen in pairs(mTimeouts) do
        oBianshen:Remove(true)
    end
    return oFrontBianshen
end

-- 刷新玩家造型并记录当前的变身sid
-- @param bForth: <bool>为真时不判断self.m_tmp_CurSid当前变身
function CBianShenMgr:RefreshSceneFigure(bForth)
    local oBianshen = self:GetFrontBianShen()
    if not bForth then
        if not oBianshen and not self.m_tmp_CurSid then
            return
        elseif oBianshen and self.m_tmp_CurSid == oBianshen:SID() then
            return
        end
    end

    if not oBianshen then
        self.m_tmp_CurSid = nil
    else
        self.m_tmp_CurSid = oBianshen:SID()
    end
    self:SyncBianshen()
end

function CBianShenMgr:GetCurBianShen()
    if not self.m_tmp_CurSid then
        return nil
    end
    return self.m_mBianshen[self.m_tmp_CurSid]
end

function CBianShenMgr:GetCurWarBianShen(mWarInitInfo)
    local oCurBianshen
    local oCurShowBianshen = self:GetCurBianShen()
    local mWarSource = mWarInitInfo.source
    if mWarSource and mWarSource.type == "task" then
        local iSourceId = mWarSource.id
        if iSourceId then
            local fFilterTask = function(oBianshen)
                local mBianSource = oBianshen:Source()
                if not mBianSource then
                    return false
                end
                if mBianSource.type ~= "task" or iSourceId ~= mBianSource.id then
                    return false
                end
                if not oBianshen:CanInWar() then
                    return false
                end
                return true
            end
            if oCurShowBianshen and fFilterTask(oCurShowBianshen) then
                return oCurShowBianshen
            else
                oCurBianshen = self:GetFrontBianShen(fFilterTask)
            end
        end
    end
    if not oCurBianshen then
        local fFilterNoTask = function(oBianshen)
            if not oBianshen:CanInWar() then
                return false
            end
            if oBianshen:Group() ~= gamedefines.BIANSHEN_GROUP.TASK then
                return true
            end
            return false
        end
        if oCurShowBianshen and fFilterNoTask(oCurShowBianshen) then
            return oCurShowBianshen
        else
            oCurBianshen = self:GetFrontBianShen(fFilterNoTask)
        end
    end
    return oCurBianshen
end

function CBianShenMgr:RemoveBianShen(oBianshen, bNoSync)
    local iSid = oBianshen:SID()
    self.m_mBianshen[iSid] = nil
    baseobj_delay_release(oBianshen)
    self:Dirty()
    self:OnRemoveBianShen()
    if not bNoSync then
        self:RefreshSceneFigure()
    end
end

local mBianShenKeyFuncName = {
    prio = "Priority",
    id = "ID",
    group = "Group",
    source = "Source",
}
function CBianShenMgr:DelBianShenByKey(mArgs)
    local bChanged = false
    local mToRemove = {}
    for iSid, oBianshen in pairs(self.m_mBianshen or {}) do
        for sArgKey, value in pairs(mArgs) do
            local sFuncName = mBianShenKeyFuncName[sArgKey]
            if sFuncName then
                local arg = oBianshen[sFuncName](oBianshen)
                if type(arg) == "table" then
                    if type(value) ~= "table" then
                        goto break_remove
                    else
                        for sK, xV in pairs(value) do
                            if arg[sK] ~= xV then
                                goto break_remove
                            end
                        end
                    end
                else
                    if arg ~= value then
                        goto break_remove
                    end
                end
            end
        end
        mToRemove[iSid] = oBianshen
        ::break_remove::
    end
    if next(mToRemove) then
        for iSid, oBianshen in pairs(mToRemove) do
            self:RemoveBianShen(oBianshen, true)
        end
        self:RefreshSceneFigure()
    end
end

function CBianShenMgr:DelBianShenPrio(iPrio)
    self:DelBianShenByKey({prio = iPrio})
end

function CBianShenMgr:DelBianShenId(iBianshenId)
    self:DelBianShenByKey({id = iBianshenId})
end

function CBianShenMgr:DelBianShenGroup(sGroup)
    self:DelBianShenByKey({group = sGroup})
end

function CBianShenMgr:BianShen(iBianshenId, iSec, iPrio, sGroup, mSource)
    local mBianshenInfo = GetBianshenInfo(iBianshenId)
    if not mBianshenInfo then
        return false
    end
    -- id理论上说可以重复存在，因此玩家可能因为不同的玩法持有同一个变身
    self:DelBianShenByKey({id = iBianshenId, group = sGroup, source = mSource})
    self:SetBianShen(iBianshenId, iSec, iPrio, sGroup, mSource)
    return true
end

function CBianShenMgr:OnLogin(oPlayer, bReEnter)
end

function CBianShenMgr:CheckTimeCb()
    for _, iSid in pairs(table_key_list(self.m_mBianshen or {})) do
        local oBianshen = self.m_mBianshen[iSid]
        if oBianshen then
            oBianshen:CheckTimeCb()
        end
    end
end
