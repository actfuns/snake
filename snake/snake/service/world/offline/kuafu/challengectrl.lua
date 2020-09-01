local skynet = require "skynet"
local global = require "global"

local gamedefines = import(lualib_path("public.gamedefines"))
local basectrl = import(service_path("offline.challengectrl"))

CChallengeCtrl = {}
CChallengeCtrl.__index = CChallengeCtrl
inherit(CChallengeCtrl, basectrl.CChallengeCtrl)

function CChallengeCtrl:New(pid)
    local o = super(CChallengeCtrl).New(self, pid)
    return o
end

function CChallengeCtrl:ConfigSaveFunc()
end

function CChallengeCtrl:SaveDb()
end

function CChallengeCtrl:OnLogout(oPlayer)
end
