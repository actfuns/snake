local global = require "global"
local skynet = require "skynet"
local interactive = require "base.interactive"
local net = require "base.net"
local record = require "public.record"

require "skynet.manager"

local serverinfo = import(lualib_path("public.serverinfo"))
local logiccmd = import(service_path("logiccmd.init"))
local logobj = import(service_path("logobj"))

skynet.start(function()
    interactive.Dispatch(logiccmd)
    net.Dispatch()

    local m = serverinfo.get_local_dbs()

    global.oLogObj = logobj.NewLogObj()
    global.oLogObj:Init({
        host = m.gamelog.host,
        port = m.gamelog.port,
        username = m.gamelog.username,
        password = m.gamelog.password,
        basename = "gamelog"
    })
    global.oLogObj:InitUnmoveLogDb({
        host = m.unmovelog.host,
        port = m.unmovelog.port,
        username = m.unmovelog.username,
        password = m.unmovelog.password,
        basename = "unmovelog"
    })

    skynet.register ".logdb"
    interactive.Send(".dictator", "common", "Register", {
        type = ".logdb",
        addr = MY_ADDR,
    })
    
    record.info("logdb service booted")
end)
