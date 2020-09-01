local global = require "global"

function NewWarMonitor(...)
    return CWarMonitor:New(...)
end

CWarMonitor = {}
CWarMonitor.__index = CWarMonitor
inherit(CWarMonitor, logic_base_cls())

function CWarMonitor:New()
    local o = super(CWarMonitor).New(self)
    o.m_sType = "war"
    o.m_iInterval = 30
    o.m_iPerDeal = 10
    o.m_mTmpWar = {}
    o.m_mEndWar = {}
    o:IntervalCheck()
    return o
end

function CWarMonitor:IntervalCheck()
    local sKey = self.m_sType
    self:DelTimeCb(sKey)
    self:CheckWarValid()
    self:AddTimeCb(sKey, self.m_iInterval * 1000, function ()
        self:IntervalCheck()
    end)
end

function CWarMonitor:CheckWarValid()
    if self:GetTimeCb("DealExceptionWar") then
        return
    end
    local oWarMgr = global.oWarMgr
    local iNowTime = get_time()

    local mRemove = {}
    local mException = {}
    for iWarId, iTime in pairs(self.m_mEndWar) do
        local oWar = oWarMgr:GetWar(iWarId)
        if oWar then
            if iNowTime - iTime >= 30 then
                table.insert(mException, iWarId)
            end
        else
            table.insert(mRemove, iWarId)
        end
    end
    mRemove = list_combine(mRemove, mException)
    for _, iWarId in pairs(mRemove) do
        self.m_mEndWar[iWarId] = nil
    end

    for _, iWarId in pairs(self.m_mTmpWar) do
        local oWar = oWarMgr:GetWar(iWarId)
        if oWar then
            if oWar:IsWarEnd() then
                self.m_mEndWar[iWarId] = iNowTime
            elseif not self:IsWarValid(oWar) then
                table.insert(mException, iWarId)
            end
        end
    end
    self.m_mTmpWar = {}
    
    local mWars = oWarMgr:GetWars()
    for iWarId, oWar in pairs(mWars) do
        if oWar:IsWarEnd() then
            self.m_mEndWar[iWarId] = iNowTime
            goto continue
        elseif self:IsWarValid(oWar) then
            goto continue
        end
        table.insert(self.m_mTmpWar, iWarId)
        ::continue::
    end
    self:DealExceptionWar(mException)
end

function CWarMonitor:IsWarValid(oWar)
    if oWar:GetTimeCb("BoutStart") then
        return true
    end
    if oWar:GetTimeCb("BoutProcess") then
        return true
    end
    if oWar:GetTimeCb("WarEnd") then
        return true
    end
    return false
end

function CWarMonitor:DealExceptionWar(mWar)
    self:DelTimeCb("DealExceptionWar")
    if table_count(mWar) <= 0 then
        return
    end
    local oWarMgr = global.oWarMgr
    for idx, iWarId in ipairs(mWar) do
        oWarMgr:DealExceptionWar(iWarId)
        if idx >= self.m_iPerDeal then
            break
        end
    end
    mWar = list_split(mWar, self.m_iPerDeal + 1, #mWar)
    self:AddTimeCb("DealExceptionWar", 100, function ()
        self:DealExceptionWar(mWar)
    end)
end


