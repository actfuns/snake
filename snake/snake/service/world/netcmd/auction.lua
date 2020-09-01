local global = require "global"

function C2GSOpenAuction(oPlayer, mData)
    --打开界面获取数据
    if not global.oToolMgr:IsSysOpen("AUCTION", oPlayer) then
        return
    end

    local iCat = mData.cat_id or 0
    local iSub = mData.sub_id or 0
    local iPage = mData.page or 1
    local oOperator = GetOperator()
    oOperator:OpenBuyAuction(oPlayer, iCat, iSub, iPage)
end

function C2GSAuctionBid(oPlayer, mData)
    if not global.oToolMgr:IsSysOpen("AUCTION", oPlayer) then
        return
    end

    --竞价
    local id = mData.id
    local iPrice = mData.price
    local oOperator = GetOperator()
    oOperator:AuctionBid(oPlayer, id, iPrice)
end

function C2GSSetProxyPrice(oPlayer, mData)
    if not global.oToolMgr:IsSysOpen("AUCTION", oPlayer) then
        return
    end

    local id = mData.id
    local iPrice = mData.price
    local oOperator = GetOperator()
    oOperator:SetProxyPrice(oPlayer, id, iPrice)
end

function C2GSCancelProxyPrice(oPlayer, mData)
    do return end
end

function C2GSToggleFollow(oPlayer, mData)
    if not global.oToolMgr:IsSysOpen("AUCTION", oPlayer) then
        return
    end

    --关注
    local id = mData.id
    local oOperator = GetOperator()
    oOperator:ToggleFollow(oPlayer, id)
end

function C2GSCloseAuctionUI(oPlayer, mData)
    if not global.oToolMgr:IsSysOpen("AUCTION", oPlayer) then
        return
    end

    --关闭拍卖界面
    local oOperator = GetOperator()
    oOperator:DelOpenUIPlayer(oPlayer:GetPid())
end

function C2GSClickLink(oPlayer, mData)
    if not global.oToolMgr:IsSysOpen("AUCTION", oPlayer) then
        return
    end

    local id = mData.id
    local oOperator = GetOperator()
    oOperator:ClickLink(oPlayer, id)
end

function C2GSAuctionDetail(oPlayer, mData)
    if not global.oToolMgr:IsSysOpen("AUCTION", oPlayer) then
        return
    end

    local id = mData.id
    local oOperator = GetOperator()
    oOperator:SendAuctionDetail(oPlayer, id)
end

function GetOperator()
    local oAuction = global.oAuction
    return oAuction.m_oOperator
end


