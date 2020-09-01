--import module
local global = require "global"
local skynet = require "skynet"
local router = require "base.router"


function TestRequest(mRecord, mData)
    router.Response(mRecord.srcsk, mRecord.src, mRecord.session, {
        errcode = 0,
    })
end
