--import module
local global = require "global"
local skynet = require "skynet"
local mongoop = require "base.mongoop"
local interactive = require "base.interactive"

local sRankTableName = "rank"


function SaveRankByName(mCond, mData)
    local oGameDb = global.oGameDb
    local mCondition = {name = mCond.rank_name}
    local mOperation = {["$set"] = {rank_data = mData.rank_data}}
    local bUpsert = true
    oGameDb:Update(sRankTableName, mCondition, mOperation, bUpsert)
end

function LoadRankByName(mCond, mData)
    local oGameDb = global.oGameDb
    local mCondition = {name = mCond.rank_name}
    local mOutput = {rank_data = true}
    local m = oGameDb:FindOne(sRankTableName, mCondition, mOutput)
   
    local mResult 
    if m then
        mResult = {rank_data = m.rank_data}
    else
        mResult = {rank_data = {}}
    end
    return mResult
end
