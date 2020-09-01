--import module

local global = require "global"
local skynet = require "skynet"
local record = require "public.record"

Cmds = {}

Cmds.login = import(service_path("logiccmd.login"))
Cmds.scene = import(service_path("logiccmd.scene"))
Cmds.war = import(service_path("logiccmd.war"))
Cmds.team = import(service_path("logiccmd.team"))
Cmds.dictator = import(service_path("logiccmd.dictator"))
Cmds.notify = import(service_path("logiccmd.notify"))
Cmds.friend = import(service_path("logiccmd.friend"))
Cmds.rank = import(service_path("logiccmd.rank"))
Cmds.merger = import(service_path("logiccmd.merger"))
Cmds.chat = import(service_path("logiccmd.chat"))
Cmds.huodong = import(service_path("logiccmd.huodong"))

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
