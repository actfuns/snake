--import module

local global = require "global"
local skynet = require "skynet"
local record = require "public.record"

Cmds = {}

Cmds.common = import(service_path("logiccmd.common"))
Cmds.business = import(service_path("logiccmd.business"))
Cmds.gmtools = import(service_path("logiccmd.gmtools"))
Cmds.behavior = import(service_path("logiccmd.behavior"))
Cmds.query = import(service_path("logiccmd.query"))
Cmds.backendinfo = import(service_path("logiccmd.backendinfo"))

function Invoke(sModule, sCmd, mRecord, mData)
    local m = Cmds[sModule]
    if m then
        local f = m[sCmd]
        if f then
            return f(mRecord, mData)
        end
    end
    record.error(string.format("Invoke fail %s %s %s %s", MY_SERVICE_NAME, MY_ADDR, sModule, sCmd))
end
