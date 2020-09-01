--import module
local global = require "global"
local skynet = require "skynet"
local interactive = require "base.interactive"

function GetRoleList(mRecord, mData)
    local sAccount = mData.account
    local lChannel = mData.channel
    local iPlatform = mData.platform
    local lServer = mData.server
    local sDeviceId = mData.device_id

    local oDataCenter = global.oDataCenter
    local bFirst, bFirst4Device = oDataCenter:CheckFirstRegister(sAccount, lChannel, iPlatform, sDeviceId)
    local mRoleList = oDataCenter:GetRoleList(sAccount, lChannel, iPlatform, lServer)
    if mRoleList then
        interactive.Response(mRecord.source, mRecord.session, {
            errcode = 0,
            roles = mRoleList,
            first_register = bFirst and 1 or 0,
            first_register_device = bFirst4Device and 1 or 0,
        })
    else
        interactive.Response(mRecord.source, mRecord.session, {
            errcode = 1,
        })
    end
end

function QueryRoleNowServer(mRecord, mData)
    local iPid = mData.pid

    local oDataCenter = global.oDataCenter
    local sServerTag = oDataCenter:GetRoleNowServer(iPid)
    if sServerTag then
        interactive.Response(mRecord.source, mRecord.session, {
            errcode = 0,
            server = sServerTag,
        })
    else
        interactive.Response(mRecord.source, mRecord.session, {
            errcode = 1,
        })
    end
end

function DeleteRole(mRecord, mData)
    local sAccount = mData.account
    local iChannel = mData.channel
    local iPid = mData.pid

    local oDataCenter = global.oDataCenter
    oDataCenter:DeleteRole(sAccount, iChannel, iPid, function (errcode)
        interactive.Response(mRecord.source, mRecord.session, {errcode = errcode})
    end)
end
