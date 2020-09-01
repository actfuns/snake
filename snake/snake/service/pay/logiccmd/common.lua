--import module
local global = require "global"
local skynet = require "skynet"
local interactive = require "base.interactive"

function PayCallback(mRecord, mData)
    local oPayMgr = global.oPayMgr
    oPayMgr:PayCallback(mData)
    interactive.Response(mRecord.source, mRecord.session, {ret="SUCCESS"})
end

function ClientQrpayScan(mRecord, mData)
    local oPayMgr = global.oPayMgr
    oPayMgr:ClientQrpayScan(mData)
    interactive.Response(mRecord.source, mRecord.session, {errcode = 0})
end

function QueryRoleHasPay(mRecord, mData)
    local iPid = mData.pid

    local oPayMgr = global.oPayMgr
    local bPay = oPayMgr:HasPay(iPid)
    interactive.Response(mRecord.source, mRecord.session, {ret = bPay})
end