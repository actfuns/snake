--import module
local global = require "global"
local skynet = require "skynet"
local mongoop = require "base.mongoop"
local interactive = require "base.interactive"

local sGlobalTableName = "global"

function LoadGlobal(mCond, mData)
    local oGameDb = global.oGameDb
    local m = oGameDb:FindOne(sGlobalTableName, {name = mCond.name}, {data = true})
    m = m or {}
    return {
        data = m.data,
        name = mCond.name,
    }
end

function SaveGlobal(mCond, mData)
    local oGameDb = global.oGameDb
    oGameDb:Update(sGlobalTableName, {name = mCond.name}, {["$set"]={data = mData.data}},true)
end