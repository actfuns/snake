local global = require "global"
local extend = require "base/extend"

-----------------------------------------C2GS------------------------------------------


function C2GSSendRP(oPlayer, mData)
    local oRedPacketMgr = global.oRedPacketMgr
    oRedPacketMgr:SendRP(oPlayer,mData)
end

function C2GSRobRP( oPlayer, mData )
    local oRedPacketMgr = global.oRedPacketMgr
    oRedPacketMgr:RobRP(oPlayer,mData)
end

function C2GSQueryAll( oPlayer, mData )
    if is_ks_server() then return end

    local oRedPacketMgr = global.oRedPacketMgr
    oRedPacketMgr:QueryAll(oPlayer, mData)
end

function C2GSQueryBasic( oPlayer, mData )
    local oRedPacketMgr = global.oRedPacketMgr
    oRedPacketMgr:QueryBasic(oPlayer, mData)
end

function C2GSQueryHistory( oPlayer, mData )
    local oRedPacketMgr = global.oRedPacketMgr
    oRedPacketMgr:QueryHistory(oPlayer)
end

function C2GSUseRPItem(oPlayer, mData)
    local oRedPacketMgr = global.oRedPacketMgr
    oRedPacketMgr:RPItem(oPlayer,mData)
end

function C2GSActiveSendSYS(oPlayer,mData)
    local oRedPacketMgr = global.oRedPacketMgr
    local mArgs = {}
    mArgs.index = mData.index
    mArgs.bless = mData.bless
    mArgs.amount = mData.amount
    mArgs.goldcoin = mData.goldcoin
    oRedPacketMgr:ActiveSendSysRP(oPlayer,mArgs)
end
