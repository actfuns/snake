--import module
local global = require "global"
local skynet = require "skynet"
local interactive = require "base.interactive"

function LoginResult(mRecord, mData)
    local oGateMgr = global.oGateMgr
    local oConnection = oGateMgr:GetConnection(mData.handle)
    if oConnection then
        oConnection:LoginResult(mData)
    end
end

function ReadyCloseGS(mRecord, mData)
    local oGateMgr = global.oGateMgr
    oGateMgr:SetOpenStatus(0)
end

function SetGateOpenStatus(mRecord, mData)
    local oGateMgr = global.oGateMgr
    oGateMgr:SetOpenStatus(mData.status)
end

function OnLogout(mRecord, mData)
    local oLoginQueueMgr = global.oLoginQueueMgr
    oLoginQueueMgr:OnLogout(mData.pid)
    local oGateMgr = global.oGateMgr
    oGateMgr:OnLogout(mData)
end

function SetOnlinePlayerLimit(mRecord, mData)
    local oLoginQueueMgr = global.oLoginQueueMgr
    oLoginQueueMgr:SetOnlinePlayerLimit(mData.limit)
end

function GetGateOpenStatus(mRecord, mData)
    local oGateMgr = global.oGateMgr
    interactive.Response(mRecord.source, mRecord.session, {open_status=oGateMgr:GetOpenStatus()})
end
