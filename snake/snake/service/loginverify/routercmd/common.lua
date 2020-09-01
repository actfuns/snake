--import module
local global = require "global"
local skynet = require "skynet"
local router = require "base.router"

function GSGetVerifyAccount(mRecord, mData)
    local sToken = mData.token

    local oVerifyMgr = global.oVerifyMgr
    local mAccount = oVerifyMgr:VerifyMyToken(sToken)
    if mAccount then
        router.Response(mRecord.srcsk, mRecord.src, mRecord.session, {
            errcode = 0,
            account = mAccount,
        })
    else
        router.Response(mRecord.srcsk, mRecord.src, mRecord.session, {
            errcode = 1,
        })
    end
end

function GSKeepTokenAlive(mRecord, mData)
    local sToken = mData.token

    local oVerifyMgr = global.oVerifyMgr
    oVerifyMgr:KeepTokenAlive(sToken)
end
