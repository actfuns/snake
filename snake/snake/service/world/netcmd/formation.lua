
local extend = require "base.extend"

function C2GSAllFormationInfo(oPlayer, mData)
    local oFmtMgr = oPlayer:GetFormationMgr()
    oFmtMgr:RefreshAllFmtInfo()
end

function C2GSSingleFormationInfo(oPlayer, mData)
    --TODO 最后么有使用的话，删掉
    local iFmtId = mData.fmt_id
    local oFmtMgr = oPlayer:GetFormationMgr()
    oFmtMgr:RefreshOneFmtInfo(iFmtId)
end

function C2GSSetPlayerPosInfo(oPlayer, mData)
    local iFmtId = mData.fmt_id
    local lPartnerList = mData.partner_list or {}
    local oPartnerCtrl = oPlayer.m_oPartnerCtrl
    local iLineup = oPartnerCtrl:GetCurrLineup()
    lPartnerList = table_copy(lPartnerList)
    oPartnerCtrl:SetLineup(iLineup, lPartnerList, iFmtId, 1)

    local oFmtMgr = oPlayer:GetFormationMgr()
    local lPlayerList = mData.player_list
    lPlayerList = table_copy(lPlayerList)
    oFmtMgr:SetFmtPosInfo(iFmtId, lPlayerList)
end

function C2GSUpgradeFormation(oPlayer, mData)
    local iFmtId = mData.fmt_id
    local lBookList = mData.book_list
    local oFmtMgr = oPlayer:GetFormationMgr()
    oFmtMgr:FastUpgradeFmt(iFmtId, lBookList)
end