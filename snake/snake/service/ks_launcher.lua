local skynet = require "skynet"
require "skynet.manager"

local interactive = require "base.interactive"
local record = require "public.record"

local serverdefines = require "public.serverdefines"

skynet.start(function()
    record.info("ks start")

    local iConsolePort = assert(serverdefines.get_gm_console_port())
    skynet.newservice("debug_console", iConsolePort)
    skynet.newservice("res")
    skynet.newservice("rt_monitor")
    skynet.newservice("mem_monitor")
    skynet.newservice("mem_rt_monitor")
    skynet.newservice("dictator")
    skynet.newservice("router_c")

    skynet.newservice("webrouter")
    -- for iNo = 1, GAMEDB_SERVICE_COUNT do
    --     skynet.newservice("gamedb", iNo)
    -- end
    skynet.newservice("login")
    skynet.newservice("logdb")
    -- skynet.newservice("logstatistics")
    skynet.newservice("broadcast")
    skynet.newservice("clientupdate")
    skynet.newservice("logfile")
    skynet.newservice("logmonitor")
    skynet.newservice("world")
    skynet.newservice("testclient")
    -- skynet.newservice("merger")
    skynet.newservice("chat")

    record.info("ks all service booted")
    interactive.Dispatch()
    interactive.Send(".dictator", "common", "AllServiceBooted", {type = "launcher"})

    skynet.exit()
end)
