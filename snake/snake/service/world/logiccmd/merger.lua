--import module
local global = require "global"
local skynet = require "skynet"
local interactive = require "base.interactive"

function MergeHuodong(mRecord, mData)
    local sHuodongName = mData.name
    local mFromData = mData.data

    local sErrMsg
    local oHuodongMgr = global.oHuodongMgr
    local oHuodong = oHuodongMgr:GetHuodong(sHuodongName)
    if oHuodong then
        local r, msg = oHuodong:MergeFrom(mFromData)
        if not r then
            sErrMsg = string.format("huodong %s merge failed : %s", sHuodongName, msg)
        end
    else
        sErrMsg = string.format("huodong %s merge failed : no such huodong", sHuodongName)
    end
    interactive.Response(mRecord.source, mRecord.session, {
        err = sErrMsg,
    })
end

function MergeJJC(mRecord, mData)
    local oJJCMgr = global.oJJCMgr
    local r, msg = oJJCMgr:MergeFrom(mData)
    local errmsg
    if not r then
        errmsg = "global jjc merge failed : "..msg
    end
    interactive.Response(mRecord.source, mRecord.session, {
        err = errmsg,
    })
end

function MergeRedPacket(mRecord, mData)
    local oRedPacketMgr = global.oRedPacketMgr
    local r, msg = oRedPacketMgr:MergeFrom(mData)
    local errmsg
    if not r then
        errmsg = "global redpacket merge failed : "..msg
    end
    interactive.Response(mRecord.source, mRecord.session, {
        err = errmsg,
    })
end

function MergeGuild(mRecord, mData)
    local oGuild = global.oGuild
    local r, msg = oGuild:MergeFrom(mData)
    local errmsg
    if not r then
        errmsg = "guild merge failed : "..msg
    end
    interactive.Response(mRecord.source, mRecord.session, {
        err = errmsg,
    })
end

function MergePrice(mRecord, mData)
    local oStallMgr = global.oStallMgr
    local oPriceMgr = oStallMgr.m_oPriceMgr
    local r, msg = oPriceMgr:MergeFrom(mData)
    local errmsg
    if not r then
        errmsg = "price merge failed : "..msg
    end
    interactive.Response(mRecord.source, mRecord.session, {
        err = errmsg,
    })
end

function MergeAuctionSys(mRecord, mData)
    local oAuction = global.oAuction
    local r, msg = oAuction:MergeFrom(mData)
    local errmsg
    if not r then
        errmsg = "auction merge failed : "..msg
    end
    interactive.Response(mRecord.source, mRecord.session, {
        err = errmsg,
    })
end

function MergeWorld(mRecord, mData)
    local oWorldMgr = global.oWorldMgr
    local r, msg = oWorldMgr:MergeFrom(mData)
    local errmsg
    if not r then
        errmsg = "world merge failed : "..msg
    end
    interactive.Response(mRecord.source, mRecord.session, {
        err = errmsg,
    })
end

function MergeYunYingInfo(mRecord, mData)
    local r, msg = global.oYunYingMgr:MergeFrom(mData)
    local errmsg
    if not r then
        errmsg = "yunying merge failed : "..msg
    end
    interactive.Response(mRecord.source, mRecord.session, {
        err = errmsg,
    })
end

function MergeEngageInfo(mRecord, mData)
    local r, msg = global.oEngageMgr:MergeFrom(mData)
    local errmsg
    if not r then
        errmsg = "engageinfo merge failed : "..msg
    end
    interactive.Response(mRecord.source, mRecord.session, {
        err = errmsg,
    })
end

function MergeMarryInfo(mRecord, mData)
    local r, msg = global.oMarryMgr:MergeFrom(mData)
    local errmsg
    if not r then
        errmsg = "marryinfo merge failed : "..msg
    end
    interactive.Response(mRecord.source, mRecord.session, {
        err = errmsg,
    })
end

function MergeMentoring(mRecord, mData)
    local r, msg = global.oMentoring:MergeFrom(mData)
    local errmsg
    if not r then
        errmsg = "mentoring merge failed : "..msg
    end
    interactive.Response(mRecord.source, mRecord.session, {
        err = errmsg,
    })
end

function MergeStallObj(mRecord, mData)
    local r, msg = global.oStallMgr:MergeFrom(mData.data)
    local errmsg
    if not r then
        errmsg = "stall merge failed : "..msg
    end
    interactive.Response(mRecord.source, mRecord.session, {
        err = errmsg,
    })
end

