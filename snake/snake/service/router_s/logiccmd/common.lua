--import module
local global = require "global"
local skynet = require "skynet"
local interactive = require "base.interactive"

function GetServerStatus(mRecord, mData)
    local mResult = global.oGateMgr:PackAllServerStatus()
    interactive.Response(mRecord.source, mRecord.session, {result=mResult})
end
