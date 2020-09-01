local global = require "global"
local skynet = require "skynet"
local interactive = require "base.interactive"
local router = require "base.router"
local record = require "public.record"
local res = require "base.res"

require "skynet.manager"

local serverinfo = import(lualib_path("public.serverinfo"))
local logiccmd = import(service_path("logiccmd.init"))
local routercmd = import(service_path("routercmd.init"))
local backendmgr = import(service_path("backendmgr"))
local yunyinginfomgr = import(service_path("yunyinginfomgr"))

skynet.start(function()
    interactive.Dispatch(logiccmd)
    router.DispatchC(routercmd)

    global.oBackendMgr = backendmgr.NewBackendMgr()
    global.oBackendMgr:LoadDB()

    global.oYunYingInfoMgr = yunyinginfomgr.NewYunYingInfoMgr()
    global.oYunYingInfoMgr:LoadDb()

    skynet.register ".backendinfo"
    interactive.Send(".dictator", "common", "Register", {
        type = ".backendinfo",
        addr = MY_ADDR,
    })

    record.info("backendinfo service booted")
end)
