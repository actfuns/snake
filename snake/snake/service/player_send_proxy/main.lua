local global = require "global"
local skynet = require "skynet"
local res = require "base.res"
local net = require "base.net"
local interactive = require "base.interactive"
local record = require "public.record"

require "skynet.manager"

local logiccmd = import(service_path("logiccmd.init"))
local proxy = import(service_path("proxy"))
local iNo = ...

skynet.start(function()
    interactive.Dispatch(logiccmd)
    net.Dispatch()

    global.oProxy = proxy.NewProxy()
    global.oProxy:Init()

    skynet.register(".player_send_proxy"..iNo)

    interactive.Send(".dictator", "common", "Register", {
        type = ".player_send_proxy",
        addr = MY_ADDR,
    })

    record.info("player_send_proxy service booted")
end)
