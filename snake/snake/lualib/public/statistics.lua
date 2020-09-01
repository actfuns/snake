
local interactive = require "base.interactive"

local M = {}

function M.system_cost(sType, iPid, mCosts, mRewards, bRecordPlayer)
    interactive.Send(".logstatistics", "system", "PushCostData",  {
        type = sType,
        pid = iPid,
        costs = mCosts,
        rewards = mRewards,
        count = bRecordPlayer
    })
end

function M.system_player_cnt(sType, iPid)
    interactive.Send(".logstatistics", "system", "AddCostPlayerCnt",  {type = sType, pid = iPid})
end

function M.system_collect_reward(sType, mRewards, iRecordPid)
    interactive.Send(".logstatistics", "system", "PushGameSystemReward",  {
        type = sType,
        pid = iRecordPid,
        rewards = mRewards,
    })
end

function M.system_collect_cnt(sType, iPid)
    interactive.Send(".logstatistics", "system", "AddGameSystemCnt",  {
        type = sType,
        pid = iPid
    }) 
end

function M.record_org_member(mData, mOrgCnt)
    interactive.Send(".logstatistics", "system", "RecordOrgMember",  {
        member = mData,
        org = mOrgCnt
    })
end

return M

