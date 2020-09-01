local global = require "global"
local skynet = require "skynet"
local interactive = require "base.interactive"
local router = require "base.router"
local res = require "base.res"
local record = require "public.record"

require "skynet.manager"

local serverinfo = import(lualib_path("public.serverinfo"))
local logiccmd = import(service_path("logiccmd.init"))
local routercmd = import(service_path("routercmd.init"))
local datacenterobj = import(service_path("datacenterobj"))
local cbtpaymgr = import(service_path("cbtpaymgr"))

skynet.start(function()
    interactive.Dispatch(logiccmd)
    router.DispatchC(routercmd)

    global.oDataCenter = datacenterobj.NewDataCenter()
    global.oDataCenter:Init()
    global.oCbtPayMgr = cbtpaymgr.NewCbtPayMgr()
    global.oCbtPayMgr:LoadDb() 

    local m = serverinfo.get_local_dbs()

    global.oDataCenter:InitDataCenterDb({
        host = m.game.host,
        port = m.game.port,
        username = m.game.username,
        password = m.game.password,
        name = "game"
    })

    skynet.register ".datacenter"
    interactive.Send(".dictator", "common", "Register", {
        type = ".datacenter",
        addr = MY_ADDR,
    })

    record.info("datacenter service booted")
end)
