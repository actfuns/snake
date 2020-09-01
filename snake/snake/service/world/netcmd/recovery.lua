local global = require "global"
local skynet = require "skynet"

function C2GSRecoveryItem(oPlayer, mData)
    local itemid = mData["id"]
    oPlayer.m_mRecoveryCtrl:RecoveryItem(oPlayer,itemid)
end

function C2GSRecoverySum(oPlayer, mData)
    local sumid = mData["id"]
    oPlayer.m_mRecoveryCtrl:RecoverySum(oPlayer,sumid)
end