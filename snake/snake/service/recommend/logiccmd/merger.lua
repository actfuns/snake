--import module
local global = require "global"
local skynet = require "skynet"
local interactive = require "base.interactive"

function MergeChlMatch(mRecord, mData)
    local oChallengeObj = global.oChallengeObj
    local r, msg = oChallengeObj:MergeFrom(mData)
    local errmsg
    if not r then
        errmsg = "global chlmatch merge failed : "..msg
    end
    interactive.Response(mRecord.source, mRecord.session, {
        err = errmsg,
    })
end

function MergeTrialMatch(mRecord, mData)
    local oTrialMatchMgr = global.oTrialMatchMgr
    local r, msg = oTrialMatchMgr:MergeFrom(mData)
    local errmsg
    if not r then
        errmsg = "global trialmatch merge failed : "..msg
    end
    interactive.Response(mRecord.source, mRecord.session, {
        err = errmsg,
    })
end

