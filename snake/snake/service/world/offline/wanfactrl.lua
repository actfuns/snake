--离线档案
local skynet = require "skynet"
local global = require "global"
local interactive = require "base.interactive"
local extend = require "base/extend"
local record = require "public.record"

local defines = import(service_path("offline.defines"))
local gamedefines = import(lualib_path("public.gamedefines"))
local CBaseOfflineCtrl = import(service_path("offline.baseofflinectrl")).CBaseOfflineCtrl
local wardata = import(service_path("offline.wardatactrl"))


CWanfaCtrl = {}
CWanfaCtrl.__index = CWanfaCtrl
inherit(CWanfaCtrl, CBaseOfflineCtrl)

function CWanfaCtrl:New(iPid)
    local o = super(CWanfaCtrl).New(self, iPid)
    o.m_sDbFlag = "WanfaCtrl"
    o.m_oWarDataCtrl = wardata.NewWarDataCtrl(iPid)

    o.m_mMengzhu = {}
    return o
end

function CWanfaCtrl:Release()
    baseobj_safe_release(self.m_oWarDataCtrl)
    super(CWanfaCtrl).Release(self)
end

function CWanfaCtrl:GetWarData()
    return self.m_oWarDataCtrl
end

function CWanfaCtrl:Save()
    local mData = {}
    mData.wardata = self.m_oWarDataCtrl:Save()
    mData.mengzhu = self.m_mMengzhu
    return mData
end

function CWanfaCtrl:Load(m)
    m = m or {}
    self.m_mMengzhu = m.mengzhu or {}
    self.m_oWarDataCtrl:Load(m.wardata)
end

function CWanfaCtrl:IsDirty()
    local bDirty = super(CWanfaCtrl).IsDirty(self)
    return bDirty or self.m_oWarDataCtrl:IsDirty()
end

function CWanfaCtrl:OnLogin(oPlayer, bReEnter)
    self:Dirty()
    self:SyncData(oPlayer)
end

function CWanfaCtrl:OnLogout(oPlayer)
    local oPlayer = global.oWorldMgr:GetOnlinePlayerByPid(self:GetPid())
    if oPlayer then
        self:Dirty()
        self.m_oWarDataCtrl:OnLogout(oPlayer)
    end
    super(CWanfaCtrl).OnLogout(self, oPlayer)
end

function CWanfaCtrl:SyncData(oPlayer)
    self.m_oWarDataCtrl:SyncData(oPlayer)
end

function CWanfaCtrl:SetMengzhuProtectTime(iSec)
    self.m_mMengzhu["protect"] = get_time() + iSec
    self:Dirty()
end

function CWanfaCtrl:GetMengzhuProtectTime()
    return self.m_mMengzhu["protect"] or 0
end

function CWanfaCtrl:InMengzhuProtectTime()
    return get_time() < (self.m_mMengzhu["protect"] or 0)
end

function CWanfaCtrl:SetMengzhuWar(iWarId)
    self.m_iInMengzhuWar = iWarId
end

function CWanfaCtrl:InMengzhuWar()
    return self.m_iInMengzhuWar and true or false
end
