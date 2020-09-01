--import module

local global = require "global"
local skynet = require "skynet"

local aibase = import(service_path("ai/ai302"))

function NewAI(...)
    local o = CAI:New(...)
    return o
end

CAI = {}
CAI.__index = CAI
inherit(CAI, aibase.CAI)


