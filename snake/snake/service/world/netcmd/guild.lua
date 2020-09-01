local global = require "global"

function C2GSOpenGuild(oPlayer, mData)
    if not global.oToolMgr:IsSysOpen("SHANGHUI", oPlayer) then
        return
    end

    local iCat = mData.cat_id
    local iSub = mData.sub_id or 0
    
    local oGuild = global.oGuild
    oGuild.m_oOperator:SendData(oPlayer, iCat, iSub)
end

function C2GSBuyGuildItem(oPlayer, mData)
    if not global.oToolMgr:IsSysOpen("SHANGHUI", oPlayer) then
        return
    end

    local iGood = mData.good_id
    local iAmount = mData.amount
   
    local oGuild = global.oGuild
    oGuild.m_oOperator:DoBuy(oPlayer, iGood, iAmount)
end

function C2GSSellGuildItem(oPlayer, mData)
    if not global.oToolMgr:IsSysOpen("SHANGHUI", oPlayer) then
        return
    end

    local iItem = mData.item_id
    local iAmount = mData.amount

    local oGuild = global.oGuild
    oGuild.m_oOperator:DoSell(oPlayer, iItem, iAmount)
end

function C2GSGetGuildPrice(oPlayer, mData)
    if not global.oToolMgr:IsSysOpen("SHANGHUI", oPlayer) then
        return
    end

    local iGood = mData.good_id
    
    local oGuild = global.oGuild
    oGuild:SendItemPrice(oPlayer, iGood)
end
