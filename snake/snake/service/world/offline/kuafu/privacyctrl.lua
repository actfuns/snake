--离线档案
local skynet = require "skynet"
local global = require "global"

local gamedefines = import(lualib_path("public.gamedefines"))
local basectrl = import(service_path("offline.privacyctrl"))


CPrivacyCtrl = {}
CPrivacyCtrl.__index = CPrivacyCtrl
inherit(CPrivacyCtrl, basectrl.CPrivacyCtrl)

function CPrivacyCtrl:New(iPid)
    local o = super(CPrivacyCtrl).New(self, iPid)
    return o
end

function CPrivacyCtrl:SaveDb()
end

function CPrivacyCtrl:ConfigSaveFunc()
end

function CPrivacyCtrl:OnLogin(oPlayer, bReEnter)
end

function CPrivacyCtrl:OnLogout(oPlayer)
end

function CPrivacyCtrl:AddDealedOrder(iOrderId)
end

function CPrivacyCtrl:AddFunc(sFunc, mArgs)
    print("liuzla-debug--")
    print(debug.traceback())
end
