local skynet = require "skynet"
require "skynet.manager"

local interactive = require "base.interactive"
local record = require "public.record"

local serverdefines = require "public.serverdefines"

skynet.start(function()
    record.info("cs start")

    local iConsolePort = assert(serverdefines.get_gm_console_port())
    skynet.newservice("debug_console", iConsolePort)
    skynet.newservice("res")
    skynet.newservice("rt_monitor")
    skynet.newservice("mem_monitor")
    skynet.newservice("dictator")
    for iNo=1,ROUTERS_SERVICE_COUNT do
        skynet.newservice("router_s",iNo)
    end
    skynet.newservice("router_c")

    skynet.newservice("webrouter")
    for iNo = 1, GAMEDB_SERVICE_COUNT do
        skynet.newservice("gamedb", iNo)
    end
    skynet.newservice("logdb")
    skynet.newservice("serversetter")
    skynet.newservice("idsupply")
    for iNo=1,VERIFY_SERVICE_COUNT do
        skynet.newservice("loginverify",iNo)
    end
    skynet.newservice("datacenter")
    skynet.newservice("logfile")
    skynet.newservice("logmonitor")
    skynet.newservice("redeemcode")
    local sQrcPorts = serverdefines.get_qrcode_ports()
    local lQrcPorts = split_string(sQrcPorts, ",", tonumber)
    for _, v in ipairs(lQrcPorts) do
        skynet.newservice("qrcode",v)
    end
    for i = 1, PAY_SERVICE_COUNT do
        skynet.newservice("pay", i)
    end
    skynet.newservice("backendinfo")
    skynet.newservice("merger")

    record.info("cs all service booted")
    interactive.Dispatch()
    interactive.Send(".dictator", "common", "AllServiceBooted", {type = "launcher"})

    skynet.exit()
end)
