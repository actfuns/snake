-- import module
local global = require "global"
local skynet = require "skynet"
local mongoop = require "base.mongoop"
local interactive = require "base.interactive"

local sFeedBackTableName = "feedback"

function GetQuestion(mCond, mData)
    local oGameDb = global.oGameDb
    local m = oGameDb:FindOne(sFeedBackTableName, {pid = mCond.pid, id = mCond.id},{pid=true, id = true, info = true})
    return {
        data = m,
        success = true,
    }
end

function SaveQuestion(mCond, mData)
    local oGameDb = global.oGameDb
    local mCondition = {pid = mCond.pid, id = mCond.id}
    local mOperation = {["$set"] = {info = mData}}
    local bUpsert = true
    oGameDb:Update(sFeedBackTableName, mCondition, mOperation, bUpsert)
end

function TestQuery(mCond, mData)
    local oGameDb = global.oGameDb
    local m = oGameDb:Find(sFeedBackTableName, mCond)
    local lRet = {}
    while m:hasNext() do
        local mFeedBack = m:next()
        table.insert(lRet, mFeedBack)
    end
    return {
        data = lRet,
    }
end
