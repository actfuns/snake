local global = require "global"
local skynet = require "skynet"
local net = require "base.net"
local interactive = require "base.interactive"
local router = require "base.router"
local texthandle = require "base.texthandle"
local res = require "base.res"
local record = require "public.record"
local serverdefines = require "public.serverdefines"

require "skynet.manager"

local textcmd = import(service_path("textcmd.init"))
local netcmd = import(service_path("netcmd.init"))
local routercmd = import(service_path("routercmd.init"))
local logiccmd = import(service_path("logiccmd.init"))
local gateobj = import(service_path("gateobj"))
local loginqueuemgr = import(service_path("loginqueue"))
local invitecode = import(service_path("invitecode"))

skynet.start(function()
    net.Dispatch(netcmd)
    interactive.Dispatch(logiccmd)
    texthandle.Dispatch(textcmd)
    router.DispatchC(routercmd)

    global.oGateMgr = gateobj.NewGateMgr()
    global.oGateMgr:Init()
    local  sPorts = serverdefines.get_gateway_ports()
    local lPorts = split_string(sPorts, ",", tonumber)
    for _, v in ipairs(lPorts) do
        local oGate = gateobj.NewGate(v)
        global.oGateMgr:AddGate(oGate)
    end
    global.oLoginQueueMgr = loginqueuemgr:NewLoginQueueMgr()
    global.oLoginQueueMgr:Init()

    global.oInviteCodeMgr = invitecode:NewInviteCodeMgr()

    skynet.register ".login"
    interactive.Send(".dictator", "common", "Register", {
        type = ".login",
        addr = MY_ADDR,
    })

    record.info("login service booted")
end)
