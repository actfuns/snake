--import module
local global = require "global"
local skynet = require "skynet"
local mongoop = require "base.mongoop"
local interactive = require "base.interactive"

local sNameCounterTableName = "namecounter"

function InsertNewNameCounter(mCond, mData)
    local oGameDb = global.oGameDb
    local bOk, sErr = oGameDb:Insert(sNameCounterTableName, mData)
    return {
        success = bOk,
        errmsg = sErr,
    }
end

function DeleteName(mCond, mData)
    local oGameDb = global.oGameDb
    local bOk, sErr = oGameDb:Delete(sNameCounterTableName, {name = mCond.name})
    assert(bOk, string.format("delete name fail, %s", mCond.name))
end

function FindName(mCond, mData)
    local oGameDb = global.oGameDb
    local m = oGameDb:FindOne(sNameCounterTableName, {name = mCond.name})
    local bOk = false
    if m then
        bOk = true
    end
    return {
        success = bOk
    }
end
