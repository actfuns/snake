local skynet = require "skynet"
local global = require "global"
local interactive = require "base.interactive"
local extend = require "base.extend"
local record = require "public.record"

local datactrl = import(lualib_path("public.datactrl"))
local gamedb = import(lualib_path("public.gamedb"))

CBaseOfflineCtrl = {}
CBaseOfflineCtrl.__index = CBaseOfflineCtrl
inherit(CBaseOfflineCtrl, datactrl.CDataCtrl)

function CBaseOfflineCtrl:New(iPid)
    local o = super(CBaseOfflineCtrl).New(self, {pid = iPid})
    o.m_iPid = iPid
    o.m_iLastTime = get_time()
    o.m_sDbFlag = nil
    return o
end

function CBaseOfflineCtrl:GetPid()
    return self.m_iPid
end

function CBaseOfflineCtrl:GetDbFlag()
    assert(self.m_sDbFlag, "GetDbFlag fail")
    return self.m_sDbFlag
end

function CBaseOfflineCtrl:GetSaveDbFlag()
    assert(self.m_sDbFlag, "GetSaveDbFlag fail")
    return "SaveOffline"..self.m_sDbFlag
end

function CBaseOfflineCtrl:GetLoadDbFlag()
    assert(self.m_sDbFlag, "GetLoadDbFlag fail")
    return "LoadOffline"..self.m_sDbFlag
end

function CBaseOfflineCtrl:GetWorldKey()
    assert(self.m_sDbFlag, "GetWorldKey fail")
    return self.m_sDbFlag
end

function CBaseOfflineCtrl:SetLastTime()
    self.m_iLastTime = get_time()
end

function CBaseOfflineCtrl:GetLastTime()
    return self.m_iLastTime
end

function CBaseOfflineCtrl:IsActive()
    local iNowTime = get_time()
    if iNowTime - self:GetLastTime() <= 5 * 60 then
        return true
    end
    if self:IsDirty() then
        return true
    end
    local oWorldMgr = global.oWorldMgr
    local oPlayer = oWorldMgr:GetOnlinePlayerByPid(self:GetPid())
    if oPlayer then
        return true
    end
    if is_gs_server() then
        local oKuaFu = global.oKuaFuMgr:GetKuaFuObj(self:GetPid())
        if oKuaFu then
            return true
        end
    end
    return false
end

function CBaseOfflineCtrl:Save()
    local mData = {}
    return mData
end

function CBaseOfflineCtrl:Load(m)
end

function CBaseOfflineCtrl:OnLogin()
end

function CBaseOfflineCtrl:OnLogout()
    self:DoSave()
end

function CBaseOfflineCtrl:LoadedExec()
    super(CBaseOfflineCtrl).LoadedExec(self)
    self:SetLastTime()
end

function CBaseOfflineCtrl:WaitLoaded(func)
    super(CBaseOfflineCtrl).WaitLoaded(self, func)
    if self:IsLoaded() then
        self:SetLastTime()
    end
end

function CBaseOfflineCtrl:Schedule()
    local sWorldKey = self:GetWorldKey()
    local iPid = self:GetPid()

    local f2
    f2 = function ()
        local oWorldMgr = global.oWorldMgr
        local obj = oWorldMgr:GetOfflineObject(sWorldKey, iPid)
        if obj then
            obj:DelTimeCb("_CheckClean")
            obj:AddTimeCb("_CheckClean", 2*60*1000, f2)
            obj:_CheckClean()
        end
    end
    f2()
end

function CBaseOfflineCtrl:ConfigSaveFunc()
    local sWorldKey = self:GetWorldKey()
    local iPid = self:GetPid()
    self:ApplySave(function ()
        local oWorldMgr = global.oWorldMgr
        local obj = oWorldMgr:GetOfflineObject(sWorldKey, iPid)
        if obj then
            obj:_CheckSaveDb()
        else
            record.warning("offline %s save err: no obj[%s]", sWorldKey, iPid)
        end
    end)
end

function CBaseOfflineCtrl:_CheckSaveDb()
    assert(not is_release(self), string.format("offline %s save err: has release", self:GetWorldKey()))
    assert(self:IsLoaded(), string.format("offline %s save err: is loading", self:GetWorldKey()))
    self:SaveDb()
end

function CBaseOfflineCtrl:SaveDb()
    local sFlag = self:GetSaveDbFlag()
    local iPid = self:GetPid()
    if self:IsDirty() then
        local mInfo = {
            module = "offlinedb",
            cmd = sFlag,
            cond = {pid = self:GetPid()},
            data = {data = self:Save()},
        }
        gamedb.SaveDb(iPid, "common", "DbOperate", mInfo)
        self:UnDirty()
    end
end

function CBaseOfflineCtrl:_CheckClean()
    assert(not is_release(self), "_CheckClean fail")
    if self:IsLoaded() and not self:IsActive() then
        local oWorldMgr = global.oWorldMgr
        oWorldMgr:CleanOfflineBlock(self:GetDbFlag(), self:GetPid())
    end
end
