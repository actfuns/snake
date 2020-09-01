local global = require "global"

function NewLoginMonitor(...)
    return CLoginMonitor:New(...)
end

CLoginMonitor = {}
CLoginMonitor.__index = CLoginMonitor
inherit(CLoginMonitor, logic_base_cls())

function CLoginMonitor:New()
    local o = super(CLoginMonitor).New(self)
    o.m_sType = "login"
    o.m_iInterval = 30
    o.m_iPerDeal = 10
    o.m_mLoginMonitor = {}
    o:IntervalCheck()
end

function CLoginMonitor:IntervalCheck()
    local sKey = self.m_sType
    self:DelTimeCb(sKey)
    self:AddTimeCb(sKey, self.m_iInterval * 1000, function()
        self:IntervalCheck()
    end)
    self:CheckLoginValid()
end

function CLoginMonitor:CheckLoginValid()
    if self:GetTimeCb("DealLoginFail") then
        return
    end
    local oWorldMgr = global.oWorldMgr
    local iNowTime = get_time()
    local mPid = {}
    local mRemove = {}
    for pid, iTime in pairs(self.m_mLoginMonitor) do
        if oWorldMgr:IsOnline(pid) or not oWorldMgr:IsLogining(pid) then
            table.insert(mRemove, pid)
            goto continue
        end
        if iNowTime - iTime >= 300 then
            table.insert(mPid, pid)
        end
        ::continue::
    end
    mRemove = list_combine(mRemove, mPid)
    for _, pid in pairs(mRemove) do
        self.m_mLoginMonitor[pid] = nil
    end
    local mLoginPlayer = oWorldMgr:GetLoginingPlayerList()
    for pid, _ in pairs(mLoginPlayer) do
        if self.m_mLoginMonitor[pid] then
            goto continue
        end
        
        if table_in_list(mRemove, pid) then
            goto continue
        end
        self.m_mLoginMonitor[pid] = iNowTime
        ::continue::
    end
    self:DealLoginFail(mPid)
end

function CLoginMonitor:DealLoginFail(mLogin)
    self:DelTimeCb("DealLoginFail")
    if table_count(mLogin) <= 0 then
        return
    end
    local oWorldMgr = global.oWorldMgr
    for idx, pid in ipairs(mLogin) do
        oWorldMgr:OnLoginFail(pid)
        if idx >= self.m_iPerDeal then
            break
        end
    end
    mLogin = list_split(mLogin, self.m_iPerDeal + 1, #mLogin)
    self:AddTimeCb("DealLoginFail", 100, function ()
        self:DealLoginFail(mLogin)
    end)
end

