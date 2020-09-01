local global = require "global"

function C2GSOpenStall(oPlayer, mData)
    --打开出售界面
    if not global.oToolMgr:IsSysOpen("BAITAN", oPlayer) then
        return
    end

    local iPid = oPlayer:GetPid()
    local oStall = GetStallObj(iPid)
    oStall:SendAllGridInfo()
end

function C2GSAddSellItem(oPlayer, mData)
    if not global.oToolMgr:IsSysOpen("BAITAN", oPlayer) then
        return
    end

    local iPos = mData.pos_id
    local iItem = mData.item_id
    local iAmount = mData.amount
    local iPrice = mData.price
    
    local iPid = oPlayer:GetPid()
    local oStall = GetStallObj(iPid)
    oStall:AddSellItem(iPos, iItem, iAmount, iPrice)
end

function C2GSAddSellItemList(oPlayer, mData)
    if not global.oToolMgr:IsSysOpen("BAITAN", oPlayer) then
        return
    end

    --批量上架
    local lItemList = mData.item_list
    local iPid = oPlayer:GetPid()
    local oStall = GetStallObj(iPid)
    oStall:AddSellItemList(lItemList)
end

function C2GSAddOverTimeItem(oPlayer, mData)
    if not global.oToolMgr:IsSysOpen("BAITAN", oPlayer) then
        return
    end

    --一键上架 上架过期物品
    local iPid = oPlayer:GetPid()
    local oStall = GetStallObj(iPid)
    oStall:AddOverTimeItem(oPlayer)
end

function C2GSResetItemPrice(oPlayer, mData)
    if not global.oToolMgr:IsSysOpen("BAITAN", oPlayer) then
        return
    end

    --设置已下过期商品的价格
    local iPos = mData.pos_id
    local iPrice = mData.price
    local iPid = oPlayer:GetPid()
    local oStall = GetStallObj(iPid)
    oStall:ResetItemPrice(iPos, iPrice)
end

function C2GSResetItemListPrice(oPlayer, mData)
    if not global.oToolMgr:IsSysOpen("BAITAN", oPlayer) then
        return
    end

    --批量设置已下过期商品的价格
    local lItemList = mData.item_list
    local iPid = oPlayer:GetPid()
    local oStall = GetStallObj(iPid)
    oStall:ResetItemListPrice(lItemList)
end

function C2GSRemoveSellItem(oPlayer, mData)
    if not global.oToolMgr:IsSysOpen("BAITAN", oPlayer) then
        return
    end

    --下架商品
    local iPos = mData.pos_id
    local iAmount = mData.amount
    
    local iPid = oPlayer:GetPid()
    local oStall = GetStallObj(iPid)
    oStall:ReturnItem2Owner(iPos, iAmount)
end

function C2GSWithdrawAllCash(oPlayer)
    if not global.oToolMgr:IsSysOpen("BAITAN", oPlayer) then
        return
    end

    --取售出道具获得的银币
    local iPid = oPlayer:GetPid()
    local oStall = GetStallObj(iPid)
    oStall:WithdrawAllCash()
end

function C2GSWithdrawOneGrid(oPlayer, mData)
    if not global.oToolMgr:IsSysOpen("BAITAN", oPlayer) then
        return
    end

    local iPos = mData.pos_id
    local iPid = oPlayer:GetPid()
    local oStall = GetStallObj(iPid)
    oStall:WithdrawOneGrid(iPos)
end

function C2GSUnlockGrid(oPlayer)
    if not global.oToolMgr:IsSysOpen("BAITAN", oPlayer) then
        return
    end

    --解锁摊位格子
    local iPid = oPlayer:GetPid()
    local oStall = GetStallObj(iPid)
    oStall:UnlockGrid()
end

function C2GSBuySellItem(oPlayer, mData)
    if not global.oToolMgr:IsSysOpen("BAITAN", oPlayer) then
        return
    end

    --买目录下某道具
    local iCatalog = mData.cat_id
    local iPos = mData.pos_id
    local iAmount = mData.amount
    local iPid = oPlayer:GetPid()
    local oCatalog = GetCatalogObj(iPid)
    oCatalog:BuySellItem(iCatalog, iPos, iAmount)
end

function C2GSSellItemDetail(oPlayer, mData)
    if not global.oToolMgr:IsSysOpen("BAITAN", oPlayer) then
        return
    end

    --请求目录下道具详细信息
    local iCatalog = mData.cat_id
    local iPos = mData.pos_id
    local iPid = oPlayer:GetPid()
    local oCatalog = GetCatalogObj(iPid)
    oCatalog:SendSellItemDetail(iCatalog, iPos)
end

function C2GSOpenCatalog(oPlayer, mData)
    if not global.oToolMgr:IsSysOpen("BAITAN", oPlayer) then
        return
    end

    --打开目录界面
    local iCatalog = mData.cat_id
    local iPage = mData.page or 1
    local iFirst = mData.first
    local iItemSid = mData.item_sid
    local iPid = oPlayer:GetPid()
    local oCatalog = GetCatalogObj(iPid)
    oCatalog:SendCatalog(iCatalog, iPage, iFirst, iItemSid)
end

function C2GSRefreshCatalog(oPlayer, mData)
    if not global.oToolMgr:IsSysOpen("BAITAN", oPlayer) then
        return
    end

    --刷新目录界面
    local iPid = oPlayer:GetPid()
    local oStall = GetStallObj(iPid)
    local iCat = mData.cat_id
    local iGold = mData.gold
    local oCatalog = GetCatalogObj(iPid)
    oCatalog:TryRefreshCatalog(iCat, iGold)
end

function C2GSGetDefaultPrice(oPlayer, mData)
    --sid  sid * 1000 + iquality
    local iSid = mData.sid
    local iPid = oPlayer:GetPid()
    local oStall = GetStallObj(iPid)
    oStall:SendDefaultPrice(iSid)
end

function GetStallObj(iPid)
    local oStallMgr = global.oStallMgr
    return oStallMgr:GetStallObj(iPid)
end

function GetCatalogObj(iPid)
    local oCatalogMgr = global.oCatalogMgr
    return oCatalogMgr:GetCatalogByPid(iPid)
end
