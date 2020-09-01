local global = require "global"
local skynet = require "skynet"
local res = require "base.res"
local record = require "public.record"
local router = require "base.router"

function NewServerMgr()
    return CServerMgr:New()
end

CServerMgr = {}
CServerMgr.__index = CServerMgr
inherit(CServerMgr, logic_base_cls())

function CServerMgr:New()
    local o = super(CServerMgr).New(self)
    o:Init()
    return o
end

function CServerMgr:Init()
    self.m_mAllServer = {}
    self.m_mWhiteList = {}

    self:Schedule()
end

function CServerMgr:PackServerInfo()
    local mInfo = {
        server_grade = global.oWorldMgr:GetServerGrade(),
    }

    if is_ks_server() then
        mInfo.online_num = table_count(global.oWorldMgr:GetOnlinePlayerList())
    end

    return {[get_server_tag()] = mInfo}
end

function CServerMgr:Schedule()
    --同步当前服务器玩家，获取其他服务器的玩家，以及服务器状态
    local f
    f = function()
        local mArgs = self:PackServerInfo()
        router.Request("cs", ".serversetter", "common", "SyncServerStatus", mArgs,
        function(mRecord, mData)
            self:ReceiveServerStatus(mRecord, mData)
        end)
        self:DelTimeCb("SyncServerStatus")
        self:AddTimeCb("SyncServerStatus", math.random(7, 15)*1000, f)
    end
    f()
end

function CServerMgr:ReceiveServerStatus(mRecord, mData)
    for sKey, mInfo in pairs(mData.result or {}) do
        self.m_mAllServer[sKey] = mInfo
    end
    self.m_mWhiteList = mData.whitelist or {}
end

function CServerMgr:IsConnect(sServerTag)
    local mServer = self.m_mAllServer[sServerTag] or {}
    local iHeartBeat = mServer.heartbeat or 0
    return (get_time() - iHeartBeat) < 100 
end

function CServerMgr:GetOnlineNum(sServerTag)
    local mServer = self.m_mAllServer[sServerTag]
    return mServer and (mServer.online_num or 0) or 0
end

function CServerMgr:GetServerGrade(sServerTag)
    local mServer = self.m_mAllServer[sServerTag]
    return mServer and (mServer.server_grade or 0) or 0
end

function CServerMgr:IsWhiteListAccount(sAccount, iChannel)
    for _, mData in pairs(self.m_mWhiteList) do
        if mData.account == sAccount and mData.channel == iChannel then
            return true
        end
    end
    return false
end

