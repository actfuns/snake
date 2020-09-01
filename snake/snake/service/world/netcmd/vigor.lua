local global = require "global"

function C2GSOpenVigorChange(oPlayer, mData)
    local oVigorCtrl = oPlayer.m_oActiveCtrl.m_oVigorCtrl
    oVigorCtrl:TryOpenVigorUI(oPlayer)
end
 
function C2GSVigorChangeStart(oPlayer, mData)
    local oVigorCtrl = oPlayer.m_oActiveCtrl.m_oVigorCtrl
    local iType = mData.change_type
    oVigorCtrl:TryStartTransform(oPlayer, iType)
end

function C2GSVigorChangeItemStatus(oPlayer, mData)
    local oVigorCtrl = oPlayer.m_oActiveCtrl.m_oVigorCtrl

    local iType = mData.change_type
    local iSet = mData.is_change_all 
    oVigorCtrl:SetTranfromAllByType(oPlayer, iType, iSet)
end

function C2GSVigorChangeList(oPlayer, mData)
    local oVigorCtrl = oPlayer.m_oActiveCtrl.m_oVigorCtrl

    oVigorCtrl:TryTransformAll(oPlayer)
end

function C2GSVigorChangeProduct(oPlayer, mData)
    local oVigorCtrl = oPlayer.m_oActiveCtrl.m_oVigorCtrl

    local iType = mData.change_type
    oVigorCtrl:GetRewardByType(oPlayer, iType)
end

function C2GSVigorChangeALLProducts(oPlayer, mData)
    local oVigorCtrl = oPlayer.m_oActiveCtrl.m_oVigorCtrl
    oVigorCtrl:GetAllReward(oPlayer)
end

function C2GSBuyGrid(oPlayer, mData)
    local oVigorCtrl = oPlayer.m_oActiveCtrl.m_oVigorCtrl
    local iType = mData.change_type
    oVigorCtrl:OpenGridLimitByType(oPlayer, iType)
end

function C2GSChangeGoldcoinToVigor(oPlayer, mData)
    local oVigorCtrl = oPlayer.m_oActiveCtrl.m_oVigorCtrl
    oVigorCtrl:ExchangeGoldcoinToVigor(oPlayer)
end

function C2GSChangeItemToVigor(oPlayer, mData)
    local oVigorCtrl = oPlayer.m_oActiveCtrl.m_oVigorCtrl
    local lItemList = mData.changeItemList

    oVigorCtrl:ChangeItemToVigor(oPlayer, lItemList)
end
