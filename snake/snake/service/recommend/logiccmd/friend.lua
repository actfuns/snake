--import module
local global = require "global"
local skynet = require "skynet"

function DigTwoDegreeFriends(mRecord,mData)
    local oRelationObj = global.oRelationObj
    oRelationObj:DigTwoDegreeFriends(mData.pid, mRecord)
end

function UpdateOneDegreeFriends(mRecord, mData)
    local oRelationObj = global.oRelationObj
    oRelationObj:UpdateOneDegreeFriends(mData.pid, mData.data)
end

function ClearAllCache(mRecord, mData)
    local oRelationObj = global.oRelationObj
    oRelationObj:ClearAllCache()
end
