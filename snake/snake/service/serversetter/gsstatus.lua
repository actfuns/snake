--import module

local global = require "global"
local skynet = require "skynet"
local router = require "base.router"

local serverinfo = import(lualib_path("public.serverinfo"))


function NewStatusMgr(...)
    local o = CStatusMgr:New(...)
    return o
end

CStatusMgr = {}
CStatusMgr.__index = CStatusMgr
inherit(CStatusMgr, logic_base_cls())

function CStatusMgr:New()
    local o = super(CStatusMgr).New(self)
    o.m_mGSStatus = {}
    return o
end

function CStatusMgr:Schedule()
    local f
    f = function ()
        local oStatusMgr = global.oStatusMgr
        oStatusMgr:DelTimeCb("_CheckMaintain")
        oStatusMgr:AddTimeCb("_CheckMaintain", 60*1000, f)
        oStatusMgr:_CheckMaintain()
    end
    self:AddTimeCb("_CheckMaintain", 60*1000, f)
end

function CStatusMgr:_CheckMaintain()
    self.m_mGSStatus = {}
    for _, server_key in ipairs(serverinfo.get_gs_key_list()) do
        router.Send(get_server_tag(server_key), ".login", "common", "CSGetOpenStatus", {})
    end
end

function CStatusMgr:SetGSStatus(server_key, status)
    self.m_mGSStatus[server_key] = status
end

function CStatusMgr:GetGSStatus(server_key)
    return self.m_mGSStatus[server_key] or 0
end

function CStatusMgr:GetRunState(server_key)
    return self:GetGSStatus(server_key) > 1 and 1 or 3
end