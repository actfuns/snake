--import module
local global = require "global"
local skynet = require "skynet"

function RemoteEvent(mRecord, mData)
    local sEventName = mData.event
    local m = mData.data
    local oSceneMgr = global.oSceneMgr
    oSceneMgr:RemoteEvent(sEventName, m)
end

function NpcJumpScene(mRecord, mData)
    local targetsc = mData.targetsc
    local targetpos = mData.targetpos
    local nowscid = mData.nowscid
    local entityid = mData.entityid

    local oSceneMgr = global.oSceneMgr
    oSceneMgr:NpcJumpScene(nowscid, entityid, targetsc, targetpos)
end

function NpcMoveEnd(mRecord, mData)
    local nowscid = mData.nowscid
    local entityid = mData.entityid

    local oSceneMgr = global.oSceneMgr
    oSceneMgr:OnNpcMoveEnd(nowscid, entityid)
end