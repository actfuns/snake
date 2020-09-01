local global = require "global"
local fubenbase = import(service_path("fuben.fubenbase"))


function NewFuben(...)
    local o = CFuben:New(...)
    return o
end

CFuben = {}
CFuben.__index = CFuben
inherit(CFuben, fubenbase.CFuben)

function CFuben:GameStart(oPlayer)
end
