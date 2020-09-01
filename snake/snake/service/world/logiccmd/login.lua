--import module
local global = require "global"
local skynet = require "skynet"

local interactive = require "base.interactive"

function DelConnection(mRecord, mData)
    local oWorldMgr = global.oWorldMgr
    local oConnection = oWorldMgr:GetConnection(mData.handle)
    if oConnection then
        oWorldMgr:DelConnection(mData.handle, mData.reason)
    end
end

function LoginPlayer(mRecord, mData)
    local oWorldMgr = global.oWorldMgr
    oWorldMgr:Login(mRecord, mData.conn, mData.role)
end

function CheckMergedServer(mRecord, mData)
    local oMergerMgr = global.oMergerMgr
    local err = oMergerMgr:CheckMergedServer(mData.from_server)
    interactive.Response(mRecord.source, mRecord.session, {
        err = err,
    })
end

function GetPlayerServerKey(mRecord, mData)
    local oWorldMgr = global.oWorldMgr
    local iPid = mData.pid
    interactive.Response(mRecord.source, mRecord.session, {
        serverkey = oWorldMgr:GetServerKey(iPid),
    })
end