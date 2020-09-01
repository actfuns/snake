local global = require "global"
local interactive = require "base.interactive"

function PushLog(mRecord, mData)
    local oLogObj = global.oLogObj
    oLogObj:PushLog(mData.type, mData.data)
end

function PushUnmoveLog(mRecord, mData)
    local oLogObj = global.oLogObj
    oLogObj:PushUnmoveLog(mData.type, mData.data)
end

function FindLog(mRecord, mData)
    local oLogObj = global.oLogObj
    local sTableName = mData.table
    local mSearch = mData.search
    local mBackInfo = mData.back
    local iTime = mData.time
    local m = oLogObj:FindLog(sTableName, mSearch, mBackInfo, iTime)
    local mRet = {}
    while m:hasNext() do
        table.insert(mRet, m:next())
    end
    interactive.Response(mRecord.source, mRecord.session, {
        data = mRet,
    })
end

function FindUnmoveLog(mRecord, mData)
    local oLogObj = global.oLogObj
    local sTableName = mData.table
    local mSearch = mData.search
    local mBackInfo = mData.back
    local m = oLogObj:FindUnmoveLog(sTableName, mSearch, mBackInfo)
    local mRet = {}
    while m:hasNext() do
        table.insert(mRet, m:next())
    end
    interactive.Response(mRecord.source, mRecord.session, {
        data = mRet,
    })
end