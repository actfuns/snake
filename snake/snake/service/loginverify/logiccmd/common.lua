--import module
local global = require "global"
local skynet = require "skynet"
local interactive = require "base.interactive"

function ClientCheckSdkOpen(mRecord, mData)
    local sIp = mData.ip

    local oVerifyMgr = global.oVerifyMgr
    local iIsOpen = oVerifyMgr:ClientCheckSdkOpen(sIp)
    interactive.Response(mRecord.source, mRecord.session, {
        open_state = iIsOpen
    })
end

function ClientVerifyAccount(mRecord, mData)
    local sToken = mData.token
    local iChannel = mData.demi_channel
    local sDeviceId = mData.device_id
    local sCpsChannel = mData.cps
    local sChannelUuid = mData.account
    local iPlatform = mData.platform
    local mOther = {
        notice_ver = mData.notice_ver,  --对应公告内容
        area = mData.area,              --服务器分区
        ckey = mData.ckey,              --对应staticconfig中的release/emu
        cname = mData.cname,            --对应staticconfig中的name
        startver = mData.startver,      --对应staticconfig中的ver
        ip = mData.ip,
        device_id = sDeviceId
    }

    local oVerifyMgr = global.oVerifyMgr
    oVerifyMgr:ClientVerifyAccount(sToken, iChannel, sDeviceId, sCpsChannel, sChannelUuid, iPlatform, mOther, function (mData)
        interactive.Response(mRecord.source, mRecord.session, mData)
    end)
end

function ClientQueryRoleList(mRecord, mData)
    local sToken = mData.token

    local oVerifyMgr = global.oVerifyMgr
    oVerifyMgr:ClientQueryRoleList(sToken, function (mData)
        interactive.Response(mRecord.source, mRecord.session, mData)
    end)
end

function ClientQRCodeScan(mRecord, mData)
    local sAccountToken = mData.account_token
    local sCodeToken = mData.code_token

    local oVerifyMgr = global.oVerifyMgr
    oVerifyMgr:ClientQRCodeScan(sAccountToken, sCodeToken, function (iErrCode)
        interactive.Response(mRecord.source, mRecord.session, {errcode = iErrCode})
    end)
end

function ClientQRCodeLogin(mRecord, mData)
    local sAccountToken = mData.account_token
    local sCodeToken = mData.code_token
    local mOther = {
        notice_ver = mData.notice_ver
    }
    local mTransferInfo = mData.transfer_info or {}

    local oVerifyMgr = global.oVerifyMgr
    oVerifyMgr:ClientQRCodeLogin(sAccountToken, sCodeToken, mOther, mTransferInfo, function (iErrCode)
        interactive.Response(mRecord.source, mRecord.session, {errcode = iErrCode})
    end)
end

function ClientDeleteRole(mRecord, mData)
    local sAccountToken = mData.account_token
    local iPid = mData.pid or {}

    local oVerifyMgr = global.oVerifyMgr
    oVerifyMgr:ClientDeleteRole(sAccountToken, iPid, function (iErrCode)
        interactive.Response(mRecord.source, mRecord.session, {errcode = iErrCode})
    end)
end
