local skynet = require "skynet"
require "skynet.manager"

local interactive = require "base.interactive"
local record = require "public.record"

local serverdefines = require "public.serverdefines"

skynet.start(function()
    record.info("bs start")

    local iConsolePort = assert(serverdefines.get_gm_console_port())
    skynet.newservice("debug_console", iConsolePort)
    skynet.newservice("res")
    skynet.newservice("rt_monitor")
    skynet.newservice("mem_monitor")
    skynet.newservice("dictator")
    skynet.newservice("router_c")

    skynet.newservice("webrouter")
    skynet.newservice("backend")
    skynet.newservice("logmonitor")
    skynet.newservice("logfile")

    record.info("bs all service booted")
    interactive.Dispatch()
    interactive.Send(".dictator", "common", "AllServiceBooted", {type = "launcher"})

    skynet.exit()
end)
