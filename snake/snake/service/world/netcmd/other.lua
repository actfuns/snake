--import module

local global = require "global"
local skynet = require "skynet"
local interactive = require "base.interactive"

function C2GSHeartBeat(oPlayer, mData)
    oPlayer:ClientHeartBeat()
end

function C2GSGMCmd(oPlayer, mData)
    local oGMMgr = global.oGMMgr
    oGMMgr:ReceiveCmd(oPlayer, mData.cmd)
end

function C2GSCallback(oPlayer,mData)
    local iSessionIdx = mData["sessionidx"]
    local oCbMgr = global.oCbMgr
    oCbMgr:CallBack(oPlayer,iSessionIdx,mData)
end

function C2GSSetActive(oPlayer, mData)
    local oTeam = oPlayer:HasTeam()
    if oTeam and oTeam:IsLeader(oPlayer:GetPid()) then
        oTeam:UpdateLeaderActive()
    end
end

function C2GSBigPacket(oPlayer, mData)
    local iClientType = mData.type
    local sData = mData.data
    local iTotal = mData.total
    local iIndex = mData.index
    local iFd = oPlayer:GetNetHandle()
    if iFd then
        oPlayer.m_oBigPacketMgr:HandleBigPacket(iClientType, sData, iTotal, iIndex, iFd)
    end
end

function C2GSQueryClientUpdateRes(oPlayer, mData)
    interactive.Send(".clientupdate", "common", "QueryResUpdate", {
        pid = oPlayer:GetPid(),
        data = mData,
    })
end

function C2GSOpSession(oPlayer, mData)
    local sSession = mData.session
    oPlayer:Send("GS2COpSessionResponse", {session = sSession})
end

function C2GSRequestPay(oPlayer, mData)
    if not global.oToolMgr:IsSysOpen("PAY_SYS", oPlayer) then
        return
    end

    local sProductKey = mData.product_key
    local iAmount = mData.product_amount
    local bIsDemi = (mData.is_demi_sdk == 1) and 1 or nil
    global.oPayMgr:TryPay(oPlayer, sProductKey, iAmount, "demi", bIsDemi)
end

function C2GSUseRedeemCode(oPlayer, mData)
    local sCode = mData["code"]
    global.oRedeemCodeMgr:UseRedeemCode(oPlayer, sCode)
end

function C2GSFeedBackQuestion(oPlayer, mData)
    global.oFeedBackMgr:FeedBackQuestion(oPlayer, mData)
end

function C2GSFeedBackSetCheckState(oPlayer, mData)
    local oWorldMgr = global.oWorldMgr
    local oFeedBackCtrl = oWorldMgr:GetFeedBack(oPlayer:GetPid())
    if not oFeedBackCtrl then return end
    oFeedBackCtrl:C2GSFeedBackSetCheckState()
end
