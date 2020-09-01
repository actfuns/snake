--import module
local global = require "global"
local skynet = require "skynet"
local router = require "base.router"

function CSGetOpenStatus(mRecord, mData)
    local oGateMgr = global.oGateMgr
    local iStatus = oGateMgr:GetOpenStatus()
    router.Send("cs", ".serversetter", "common", "GSSetOpenState", {
        status = iStatus,
        server_key = get_server_key()
    })
end

function CSSetSetterConfig(mRecord, mData)
    local oGateMgr = global.oGateMgr
    oGateMgr:ReloadSetterConfig(mData)
end
