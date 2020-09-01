local global = require "global"

function PushCostData(mRecord, mData)
    local oSystemObj = global.oSystemObj
    oSystemObj:PushCostData(mData.type, mData.pid, mData.costs, mData.rewards, mData.count)
end

function AddCostPlayerCnt(mRecord, mData)
    local oSystemObj = global.oSystemObj
    oSystemObj:AddCostPlayerCnt(mData.type, mData.pid)
end

function PushGameSystemReward(mRecord, mData)
    local oSystemObj = global.oSystemObj
    oSystemObj:PushGameSystemReward(mData.type, mData.rewards, mData.pid) 
end

function AddGameSystemCnt(mRecord, mData)
    local oSystemObj = global.oSystemObj
    oSystemObj:AddGameSystemCnt(mData.type, mData.pid) 
end

function RecordOrgMember(mRecord, mData)
    local oSystemObj = global.oSystemObj
    oSystemObj:RecordOrgMember(mData.member, mData.org) 
end

function DoLogStatistics(mRecord, mData)
    local oBasicObj = global.oBasicObj
    local iTime = mData.time
    oBasicObj:DoStatistics(iTime)
end