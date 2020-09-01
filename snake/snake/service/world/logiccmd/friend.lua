--import module
local global = require "global"
local skynet = require "skynet"

local interactive = require "base.interactive"

function RecommendFindFriend(mRecord, mData)
    local oWorldMgr = global.oWorldMgr
    oWorldMgr:LoadFriend(mData.pid, function (o)
        if not o then
            interactive.Response(mRecord.source, mRecord.session, {
                pid = mData.pid,
            })
        else
            local m = {}
            local mMyFriends = o:GetFriends()
            for k, _ in pairs(mMyFriends) do
                m[tonumber(k)] = 1
            end
            interactive.Response(mRecord.source, mRecord.session, {
                pid = mData.pid,
                data = m,
            })    
        end
    end)
end
