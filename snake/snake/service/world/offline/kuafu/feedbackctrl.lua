local global = require "global"
local record = require "public.record"

local basectrl = import(service_path("offline.feedbackctrl"))

CFeedBackCtrl = {}
CFeedBackCtrl.__index = CFeedBackCtrl
inherit(CFeedBackCtrl, basectrl.CFeedBackCtrl)

function CFeedBackCtrl:New(pid)
    local o = super(CFeedBackCtrl).New(self, pid)
    return o
end

function CFeedBackCtrl:SaveDb()
end

function CFeedBackCtrl:ConfigSaveFunc()
end

function CFeedBackCtrl:OnLogin(oPlayer, bReEnter)
end

function CFeedBackCtrl:OnLogout(oPlayer)
end



