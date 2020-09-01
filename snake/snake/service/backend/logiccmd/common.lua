--import module
local global = require "global"
local skynet = require "skynet"
local interactive = require "base.interactive"
local extend = require "base.extend"

function Test(mRecord, mData)
    local oBackendObj = global.oBackendObj

    local br, m = safe_call(oBackendObj.Test, oBackendObj, mData)
    if br then
        interactive.Response(mRecord.source, mRecord.session, {
            errcode = m.errcode,
            data = m.data,
        })
    else
        interactive.Response(mRecord.source, mRecord.session, {
            errcode = 1,
        })
    end
end
