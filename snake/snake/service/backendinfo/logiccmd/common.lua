--import module
local global = require "global"
local skynet = require "skynet"
local interactive = require "base.interactive"
local extend = require "base.extend"

function Test(mRecord, mData)
    interactive.Response(mRecord.source, mRecord.session, {
        errcode = 0,
        data = {},
    })
end
