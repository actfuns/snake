--import module
local global = require "global"
local skynet = require "skynet"
local mongoop = require "base.mongoop"
local interactive = require "base.interactive"

local sTableName = "guild"


function SaveGuildData(mCond, mData)
    local oGameDb = global.oGameDb
    local mCondition = {name = mCond.name}
    local mOperation = {["$set"] = {data = mData.data}}
    local bUpsert = true
    oGameDb:Update(sTableName, mCondition, mOperation, bUpsert)
end

function LoadGuildData(mCond, mData)
    local oGameDb = global.oGameDb
    local mCondition = {name = mCond.name}
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
