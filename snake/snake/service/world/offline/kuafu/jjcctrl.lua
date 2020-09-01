local skynet = require "skynet"
local global = require "global"

local gamedefines = import(lualib_path("public.gamedefines"))
local basectrl = import(service_path("offline.jjcctrl"))

CJJCCtrl = {}
CJJCCtrl.__index = CJJCCtrl
inherit(CJJCCtrl, basectrl.CJJCCtrl)

function CJJCCtrl:New(pid)
    local o = super(CJJCCtrl).New(self, pid)
    return o
end

function CJJCCtrl:SaveDb()
end

function CJJCCtrl:ConfigSaveFunc()
end

function CJJCCtrl:NewHour(mNow)
end

function CJJCCtrl:OnLogin(oPlayer)
end

function CJJCCtrl:OnLogout(oPlayer)
end

function CJJCCtrl:SyncData(oPlayer)
end
