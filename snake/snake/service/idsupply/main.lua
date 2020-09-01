local global = require "global"
local skynet = require "skynet"
local interactive = require "base.interactive"
local router = require "base.router"
local res = require "base.res"
local record = require "public.record"

require "skynet.manager"

local logiccmd = import(service_path("logiccmd.init"))
local routercmd = import(service_path("routercmd.init"))
local playeridmgr = import(service_path("playeridmgr"))
local showidmgr = import(service_path("showidmgr"))
local orgidmgr = import(service_path("orgidmgr"))
local warvideomgr = import(service_path("warvideomgr"))

skynet.start(function()
    interactive.Dispatch(logiccmd)
    router.DispatchC(routercmd)

    global.oPlayerIdMgr = playeridmgr.NewPlayerIdMgr()
    global.oPlayerIdMgr:LoadDb()

    global.oShowIdMgr = showidmgr:NewShowIdMgr()
    global.oShowIdMgr:LoadDb()

    global.oOrgIdMgr = orgidmgr.NewOrgIdMgr()
    global.oOrgIdMgr:LoadDb()

    global.oWarVideoMgr = warvideomgr.NewWarVideoIdMgr()
    global.oWarVideoMgr:LoadDb()

    skynet.register ".idsupply"
    interactive.Send(".dictator", "common", "Register", {
        type = ".idsupply",
        addr = MY_ADDR,
    })

    record.info("idsupply service booted")
end)
