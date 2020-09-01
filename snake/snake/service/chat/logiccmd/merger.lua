--import module
local global = require "global"
local skynet = require "skynet"
local interactive = require "base.interactive"


function MergeChatInfo(mRecord, mData)
    local r, msg = global.oChatMgr:MergeFrom(mData)
    local errmsg
    if not r then
        errmsg = "global chatinfo merge failed : "..msg
    end
    interactive.Response(mRecord.source, mRecord.session, {
        err = errmsg,
    })
end
