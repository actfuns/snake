local global = require "global"
local skynet = require "skynet"
local interactive = require "base.interactive"
local net = require "base.net"
local res = require "base.res"
local record = require "public.record"
local playersend = require "base.playersend"

require "skynet.manager"

local logiccmd = import(service_path("logiccmd.init"))
local warmgrobj = import(service_path("warmgrobj"))
local actionmgrobj = import(service_path("actionmgrobj"))
local waritemmgr = import(service_path("waritem.waritemmgr"))
local target = import(service_path("ai.target"))
local derivedfilemgr = import(lualib_path("public.derivedfile"))
local warmonitor = import(service_path("warmonitor"))
local warspeek = import(service_path("warspeek"))

skynet.start(function()
    interactive.Dispatch(logiccmd)
    net.Dispatch()
    playersend.SetNeedSec()

    global.oDerivedFileMgr = derivedfilemgr.NewDerivedFileMgr()
    global.oWarMgr = warmgrobj.NewWarMgr()
    global.oActionMgr = actionmgrobj.NewActionMgr()
    global.oWarItemMgr = waritemmgr.NewWarItemMgr()
    global.oTargetMgr = target.NewTargetMgr()
    global.oWarMonitor = warmonitor.NewWarMonitor()
    global.oSpeekMgr = warspeek.NewSpeekMgr()

    interactive.Send(".dictator", "common", "Register", {
        type = ".war",
        addr = MY_ADDR,
    })

    record.info("war service booted")
end)
