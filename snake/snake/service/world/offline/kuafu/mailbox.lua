local skynet = require "skynet"
local global = require "global"

local gamedefines = import(lualib_path("public.gamedefines"))
local basectrl = import(service_path("offline.mailbox"))
local mailobj = import(service_path("mail.mailobj"))

CMailBox = {}
CMailBox.__index = CMailBox
inherit(CMailBox, basectrl.CMailBox)

function CMailBox:New(pid)
    local o = super(CMailBox).New(self, pid)
    return o
end

function CMailBox:SaveDb()
end

function CMailBox:ConfigSaveFunc()
end

function CMailBox:DelMail(id)
    -- TODO
    print("liuzla-debug------")
    print(debug.traceback())
end

function CMailBox:ClearMail()
    -- TODO
    print("liuzla-debug------")
    print(debug.traceback())
end

function CMailBox:OnLogout(oPlayer)
end
