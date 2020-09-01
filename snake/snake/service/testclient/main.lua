local global = require "global"
local skynet = require "skynet"
local res = require "base.res"
local interactive = require "base.interactive"
local router = require "base.router"
local record = require "public.record"

require "skynet.manager"

local logiccmd = import(service_path("logiccmd.init"))

skynet.start(function()
    interactive.Dispatch(logiccmd)
    router.DispatchC()

    skynet.register ".testclient"
    interactive.Send(".dictator", "common", "Register", {
        type = ".testclient",
        addr = MY_ADDR,
    })

    record.info("testclient service booted")
end)
