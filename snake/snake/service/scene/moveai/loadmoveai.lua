--import module
local global = require "global"
local skynet = require "skynet"

function NewMoveAI(type)
    local sPath = string.format("moveai/%s",type)
    local oModule = import(service_path(sPath))
    assert(oModule,string.format("NewMoveAI err:%s",type))
    local oMoveAI = oModule.NewMoveAI()
    return oMoveAI
end