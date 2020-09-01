--import module
local global = require "global"
local skynet = require "skynet"
local mongoop = require "base.mongoop"
local interactive = require "base.interactive"

local sTableName = "stall"

function SaveInfoToStallByPid(mCond, mData)
    local oGameDb = global.oGameDb
    local mCondition = {pid = mCond.pid}
    local mOperation = {["$set"] = {data = mData.data}}
    local bUpsert = true
    oGameDb:Update(sTableName, mCondition, mOperation, bUpsert)
end

function LoadInfoFromStallByPid(mCond, mData)
    local oGameDb = global.oGameDb
    local mCondition = {pid = mCond.pid}
    local mOutput = {data = true}
    local m = oGameDb:FindOne(sTableName, mCondition, mOutput)
   
    local mResult 
    if m then
        mResult = {data = m.data}
    else
        mResult = {data = {}}
    end
    return mResult
end

function LoadAllInfoFromStall(mCond, mData)
    local oGameDb = global.oGameDb
    local mCondition = {pid = {["$exists"] = true}}
    local mOutput = {pid = true, data = true}
    local m = oGameDb:Find(sTableName, mCondition, mOutput)
    local mResult  = {}
    while m:hasNext() do
        local mInfo = m:next()
        mInfo._id = nil
        table.insert(mResult, mInfo)
    end
    return {data=mResult}
end

