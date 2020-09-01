local global = require "global"
local skynet = require "skynet"
local interactive = require "base.interactive"
local router = require "base.router"
local record = require "public.record"
local res = require "base.res"

require "skynet.manager"

local demisdk = import(lualib_path("public.demisdk"))
local logiccmd = import(service_path("logiccmd.init"))
local routercmd = import(service_path("routercmd.init"))
local verifymgr = import(service_path("verifymgr"))

local iNo = ...

skynet.start(function()
    interactive.Dispatch(logiccmd)
    router.DispatchC(routercmd)

    global.oVerifyMgr = verifymgr.NewVerifyMgr(iNo)
    global.oVerifyMgr:Init()

    global.oDemiSdk = demisdk.NewDemiSdk()

    skynet.register(string.format(".loginverify%d",iNo))
    interactive.Send(".dictator", "common", "Register", {
        type = ".loginverify",
        addr = MY_ADDR,
    })

    record.info("loginverify service booted")
end)