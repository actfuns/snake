local global = require "global"
local interactive = require "base.interactive"

function UpdateMatchInfo(mRecord, mData)
    global.oSingleWarMatch:UpdateMatchInfo(mData)
end

function ClearMatchInfo(mRecord, mData)
    global.oSingleWarMatch:ClearMatchInfo()
end

function RemoveMatchInfo(mRecord, mData)
    global.oSingleWarMatch:RemoveMatchInfo(mData)
end

function StartMatch(mRecord, mData)
    local bStart = false
    local mResult = global.oSingleWarMatch:CheckGroupStart()
    for iGroup, mCheck in pairs(mResult) do
        bStart = bStart or mCheck[1]
    end
    interactive.Response(mRecord.source, mRecord.session, {result=mResult, start=bStart})
end

function DoStartMatch(mRecord, mData)
    global.oSingleWarMatch:StartMatch()
end

