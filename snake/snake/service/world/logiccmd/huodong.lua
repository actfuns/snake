local global = require "global"

function SingleWarMatchResult(mRecord, mData)
    local oHuodong = global.oHuodongMgr:GetHuodong("singlewar")
    if oHuodong then
        oHuodong:MatchResult(mData.match_list)
    end
end
