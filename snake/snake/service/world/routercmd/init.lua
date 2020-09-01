--import module
local global = require "global"
local skynet = require "skynet"
local record = require "public.record"

Cmds = {}

Cmds.common = import(service_path("routercmd.common"))
Cmds.gmtools = import(service_path("routercmd.gmtools"))
Cmds.pay = import(service_path("routercmd.pay"))
Cmds.idsupply = import(service_path("routercmd.idsupply"))
Cmds.datacenter = import(service_path("routercmd.datacenter"))
Cmds.backend = import(service_path("routercmd.backend"))
Cmds.kuafu_gs = import(service_path("routercmd.kuafu_gs"))
Cmds.kuafu_ks = import(service_path("routercmd.kuafu_ks"))


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
