local global = require "global"
local skynet = require "skynet"
local interactive = require "base.interactive"
local net = require "base.net"
local record = require "public.record"
require "skynet.manager"

local serverinfo = import(lualib_path("public.serverinfo"))
local logiccmd = import(service_path("logiccmd.init"))
local versionmgr = import(service_path("versionmgr"))


skynet.start(function()
    interactive.Dispatch(logiccmd)
    net.Dispatch()

    global.oVersionMgr = versionmgr.NewVersionMgr()

    skynet.register ".version"
    interactive.Send(".dictator", "common", "Register", {
        type = ".version",
        addr = MY_ADDR,
    })
    
    record.info("version service booted")
end)
