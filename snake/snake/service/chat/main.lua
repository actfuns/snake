local global = require "global"
local skynet = require "skynet"
local interactive = require "base.interactive"
local router = require "base.router"
local record = require "public.record"
local res = require "base.res"
local net = require "base.net"

require "skynet.manager"

local serverinfo = import(lualib_path("public.serverinfo"))
local logiccmd = import(service_path("logiccmd.init"))
local routercmd = import(service_path("routercmd.init"))
local chatmgr = import(service_path("chatmgr"))


skynet.start(function()
    interactive.Dispatch(logiccmd)
    router.DispatchC(routercmd)
    net.Dispatch()

    global.oChatMgr = chatmgr.NewChatMgr()
    global.oChatMgr:LoadDb()

    skynet.register ".chat"
    interactive.Send(".dictator", "common", "Register", {
        type = ".chat",
        addr = MY_ADDR,
    })

    record.info("chat service booted")
end)
