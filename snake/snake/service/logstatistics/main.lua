local global = require "global"
local skynet = require "skynet"
local interactive = require "base.interactive"
local net = require "base.net"
local record = require "public.record"
local res = require "base.res"

require "skynet.manager"

local logiccmd = import(service_path("logiccmd.init"))
local systemobj = import(service_path("systemobj"))
local basicobj = import(service_path("basicobj"))

skynet.start(function()
    interactive.Dispatch(logiccmd)
    net.Dispatch()

    global.oSystemObj = systemobj.NewSystemObj()
    global.oSystemObj:Init()
    global.oBasicObj = basicobj.NewBasicObj()
    global.oBasicObj:Init()

    skynet.register ".logstatistics"
    interactive.Send(".dictator", "common", "Register", {
        type = ".logstatistics",
        addr = MY_ADDR,
    })
    
    record.info("logstatistics service booted")
end)
