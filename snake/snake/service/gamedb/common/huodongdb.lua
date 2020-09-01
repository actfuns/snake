--import module
local global = require "global"
local skynet = require "skynet"
local mongoop = require "base.mongoop"
local interactive = require "base.interactive"

local sHuoDongTableName = "huodong"

function LoadHuoDong(mCond, mData)
    local oGameDb = global.oGameDb
    local m = oGameDb:FindOne(sHuoDongTableName, {name = mCond.name}, {data = true})
    m = m or {}
    return {
        data = m.data,
        name = mCond.name,
    }
end

function SaveHuoDong(mCond, mData)
    local oGameDb = global.oGameDb
    oGameDb:Update(sHuoDongTableName, {name = mCond.name}, {["$set"]={data = mData.data}},true)
end