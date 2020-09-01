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
local backendobj = import(service_path("backendobj"))
local noticemgr = import(service_path("noticemgr"))
local businessobj = import(service_path("businessobj"))
local gmtoolsobj = import(service_path("gmtoolsobj"))
local behaviorobj = import(service_path("behaviorobj"))
local queryobj = import(service_path("queryobj"))
local backendinfomgr = import(service_path("backendinfomgr"))


skynet.start(function()
    interactive.Dispatch(logiccmd)
    router.DispatchC(routercmd)

    global.oBackendObj = backendobj.NewBackendObj()
    global.oBackendObj:Init()

    local m = serverinfo.get_local_dbs()

    global.oBackendObj:InitBackendDb({
        host = m.backend.host,
        port = m.backend.port,
        username = m.backend.username,
        password = m.backend.password,
        name = "backend"
    })
    global.oBackendObj:InitGameLogDb({
        host = m.gamelog.host,
        port = m.gamelog.port,
        username = m.gamelog.username,
        password = m.gamelog.password,
    })

    local m2 = serverinfo.get_cs_slave_dbs()
    global.oBackendObj:InitDataCenterDb({
        host = m2.game.host,
        port = m2.game.port,
        username = m2.game.username,
        password = m2.game.password,
    })
    local mSlaveDb = serverinfo.get_slave_dbs()
    for k, v in pairs(mSlaveDb) do
        global.oBackendObj:AddNewServer(k, v.game, v.gamelog, v.gameumlog)
    end
    global.oBackendObj:AfterAddServer()

    global.oBusinessObj = businessobj.NewBusinessObj()
    global.oBusinessObj:Init()
    global.oNoticeMgr = noticemgr.NewNoticeMgr()
    global.oNoticeMgr:Init()
    global.oGmToolsObj = gmtoolsobj.NewGmToolsObj()
    global.oBehaviorObj = behaviorobj.NewBehaviorObj()
    global.oBehaviorObj:Init()
    global.oQueryObj = queryobj.NewQueryObj()
    global.oBackendInfoMgr = backendinfomgr.NewBackendInfoMgr()
    global.oBackendInfoMgr:LoadDB()

    skynet.register ".backend"
    interactive.Send(".dictator", "common", "Register", {
        type = ".backend",
        addr = MY_ADDR,
    })

    record.info("backend service booted")
end)
