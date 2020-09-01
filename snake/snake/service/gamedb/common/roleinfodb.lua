--import module
local global = require "global"
local skynet = require "skynet"
local mongoop = require "base.mongoop"
local interactive = require "base.interactive"

local sTableName = "roleinfo"

function FindOne(mCond, mData)
    local oGameDb = global.oGameDb
    local m = oGameDb:FindOne(sTableName, {pid = mCond.pid}, {pid=true, name=true, account=true, channel=true})
    return {
        data = m or {},
        pid = mCond.pid,
    }
end
