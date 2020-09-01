--import module
local global = require "global"
local skynet = require "skynet"
local mongoop = require "base.mongoop"
local interactive = require "base.interactive"

local sCbtPayTableName = "cbt_pay"

function LoadCbtPay(mCond, mData)
    local oGameDb = global.oGameDb
    local m = oGameDb:Find(sCbtPayTableName, {})
    local mResult = {}
    while m:hasNext() do
        local mInfo = m:next()
        mInfo._id = nil
        table.insert(mResult, mInfo)
    end
    return {data = mResult}
end

function SaveCbtPay(mCond, mData)
    local oGameDb = global.oGameDb
    oGameDb:Update(sCbtPayTableName, {account=mCond.account, channel=mCond.channel}, {["$set"]=mData}, true)
end