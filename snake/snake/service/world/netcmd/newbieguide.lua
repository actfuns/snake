local global = require "global"
local net = require "base.net"

function C2GSUpdateNewbieGuideInfo(oPlayer, mData)
    local oNewbieGuideMgr = global.oNewbieGuideMgr
    mData = net.UnMask("C2GSUpdateNewbieGuideInfo", mData)
    global.oNewbieGuideMgr:UpdateNewbieGuideInfo(oPlayer, mData.guide_links, mData.exdata)
end

function C2GSNewSysOpenNotified(oPlayer, mData)
    global.oNewbieGuideMgr:SetNewSysOpenNotified(oPlayer, mData.sys_ids)
end

function C2GSSelectNewbieSummon(oPlayer, mData)
    global.oNewbieGuideMgr:SelectNewbieSummon(oPlayer, mData.selection)
end

function C2GSGetNewbieGuildInfo(oPlayer, mData)
    global.oNewbieGuideMgr:GetNewbieGuildInfo(oPlayer)
end
