--离线档案
local skynet = require "skynet"
local global = require "global"

local gamedefines = import(lualib_path("public.gamedefines"))
local basectrl = import(service_path("offline.wanfactrl"))


CWanfaCtrl = {}
CWanfaCtrl.__index = CWanfaCtrl
inherit(CWanfaCtrl, basectrl.CWanfaCtrl)

function CWanfaCtrl:New(iPid)
    local o = super(CWanfaCtrl).New(self, iPid)
    return o
end

function CWanfaCtrl:SaveDb()
end

function CWanfaCtrl:ConfigSaveFunc()
end

function CWanfaCtrl:OnLogin(oPlayer, bReEnter)
end

function CWanfaCtrl:OnLogout(oPlayer)
end
