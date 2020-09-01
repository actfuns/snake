local global = require "global"
local skynet = require "skynet"
local interactive = require "base.interactive"
local net = require "base.net"
local res = require "base.res"
local record = require "public.record"

require "skynet.manager"

local logiccmd = import(service_path("logiccmd.init"))
local rankmgr = import(service_path("rankmgr"))
if is_ks_server() then
    rankmgr = import(service_path("kuafu.rankmgr"))
end
local derivedfilemgr = import(lualib_path("public.derivedfile"))


skynet.start(function()
    interactive.Dispatch(logiccmd)
    net.Dispatch()

    global.oDerivedFileMgr = derivedfilemgr.NewDerivedFileMgr()
    global.oRankMgr = rankmgr.NewRankMgr()
    global.oRankMgr:LoadAllRank()
    
    skynet.register ".rank"
    interactive.Send(".dictator", "common", "Register", {
        type = ".rank",
        addr = MY_ADDR,
    })

    record.info("rank service booted")
end)
