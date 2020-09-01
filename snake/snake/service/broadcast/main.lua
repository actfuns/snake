local global = require "global"
local skynet = require "skynet"
local interactive = require "base.interactive"
local net = require "base.net"
local res = require "base.res"
local record = require "public.record"

require "skynet.manager"

local gamedefines = import(lualib_path("public.gamedefines"))
local logiccmd = import(service_path("logiccmd.init"))

skynet.start(function()
    interactive.Dispatch(logiccmd)
    net.Dispatch()

    global.mChannels[gamedefines.BROADCAST_TYPE.WORLD_TYPE] = {}
    global.mChannels[gamedefines.BROADCAST_TYPE.TEAM_TYPE] = {}
    global.mChannels[gamedefines.BROADCAST_TYPE.FRIEND_FOCUS_TYPE] = {}
    global.mChannels[gamedefines.BROADCAST_TYPE.ORG_TYPE] = {}
    global.mChannels[gamedefines.BROADCAST_TYPE.INTERFACE_TYPE] = {}
    global.mChannels[gamedefines.BROADCAST_TYPE.PUB_TEAM_TYPE] = {}

    skynet.register ".broadcast"
    interactive.Send(".dictator", "common", "Register", {
        type = ".broadcast",
        addr = MY_ADDR,
    })

    record.info("broadcast service booted")
end)
