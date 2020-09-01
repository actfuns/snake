--import module
local global = require "global"
local skynet = require "skynet"

function RemoteEvent(mRecord, mData)
    local sEventName = mData.event
    local m = mData.data
    local oWarMgr = global.oWarMgr
    oWarMgr:RemoteEvent(sEventName, m)
end

function WarUseItem(mRecord, mData)
    local iWarId = mData.warid
    local iPid = mData.pid
    local iItemId = mData.itemid
    local iAmount = mData.amount
    local bSucc = mData.succ

    local oWarMgr = global.oWarMgr
    oWarMgr:WarUseItem(iWarId, iPid, iItemId, iAmount, bSucc)
end

function OnWarCapture(mRecord, mData)
    local iWarId = mData.warid
    local iPid = mData.pid
    local bSucc = mData.succ
    -- 回调到具体战斗的响应逻辑
    global.oWarMgr:OnWarCapture(mData)
end
