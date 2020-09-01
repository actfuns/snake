--import module

local global = require "global"
local skynet = require "skynet"
local record = require "public.record"

Cmds = {}

Cmds.friend = import(service_path("logiccmd.friend"))
Cmds.challenge = import(service_path("logiccmd.challenge"))
Cmds.dictator = import(service_path("logiccmd.dictator"))
Cmds.merger = import(service_path("logiccmd.merger"))
Cmds.mentoring = import(service_path("logiccmd.mentoring"))
Cmds.singlewar = import(service_path("logiccmd.singlewar"))

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
