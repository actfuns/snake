local global = require "global"
local res = require "base.res"
local defines = import(service_path("auction.defines"))

Commands = {}       --指令函数
Helpers = {}        --帮助信息
Opens = {}          --对外开放

Opens.shopop = true
Helpers.shopop = {
    "商城指令集",
    "shopop 指令编号",
    "shopop 100",
}

function Commands.shopop(oMaster,iFlag,mArgs)
     global.oShopMgr:TestOP(oMaster,iFlag,mArgs)
 end 

Opens.auction_item = true
Helpers.auction_item = {
    "拍卖开启",
    "auction_item 拍品编号",
    "auction_item 1",
}

function Commands.auction_item(oMaster, iSys)
    local oAuction = global.oAuction
    local mGroup = res["daobiao"]["auction"]["group"]
    local mAllItem = res["daobiao"]["auction"]["sys_auction"]
    if not mAllItem then
        oMaster:NotifyMessage(iSys.."不存在")
        return
    end
    if oAuction:IsSysUp(iSys) then
        oMaster:NotifyMessage(iSys.."已上架")
        return
    end
    local oProxy
    local mItem = mAllItem[iSys]
    local iType = mItem.auction_type
    local iSid = mItem.sid
    local mAttr = formula_string(mItem.attr, {})
    local iPrice = mItem.price
    local iMoneyType = mItem.money_type

    if mGroup[iSid] then
        iType, iSid, mAttr, iPrice, iMoneyType = oAuction:ChooseGroupAuction(iSid)
    end

    if not iType then return end

    if iType == defines.PROXY_TYPE_ITEM then
        oProxy = oAuction:CreateProxyItem(iSid, mAttr)
    else
        oProxy = oAuction:CreateProxySummon(iSid, mAttr)
    end
    oProxy:SetAmount(1)
    oProxy:SetOwner(0)
    oProxy:SetSys(iSys)
    oProxy:SetPrice(iPrice)
    oProxy:SetMoneyType(iMoneyType)
    oProxy:InitTime(get_time())
    oAuction:AddAuctionItem(0, oProxy)
end

Opens.auction_over = true
Helpers.auction_over = {
    "拍卖结束",
    "auction_over 拍品编号",
    "auction_over 1",
}
function Commands.auction_over(oMaster, iSys)
    local oAuction = global.oAuction
    local oProxy
    for iProxy, oItem in pairs(oAuction.m_mItemTable) do
        if oItem:GetSys() == iSys then
            oProxy = oItem
            break
        end
    end
    if not oProxy then
        oMaster:NotifyMessage("未找到id:"..iSys.."的拍品")
        return
    end
    if oProxy:InViewTime() or oProxy:InShowTime() then
        oProxy:CancelAuction(true)
        oMaster:NotifyMessage("取消拍卖:"..oProxy:GetName())
        return
    end
    oProxy:TryGenProxyBidders()
    oProxy:AuctionOver()
    oMaster:NotifyMessage("拍卖结束:"..oProxy:GetName())
end

Opens.auction_over_all = true
Helpers.auction_over_all = {
    "拍卖结束",
    "auction_over_all 拍品编号",
    "auction_over_all 1",
}
function Commands.auction_over_all(oMaster)
    local oAuction = global.oAuction
    local lSys = {}
    for iProxy, oItem in pairs(oAuction.m_mItemTable) do
        table.insert(lSys, oItem:GetSys())
    end
    for _, iSys in pairs(lSys) do
        Commands.auction_over(oMaster, iSys)
    end
end

Helpers.add_stall_selltime = {
    "设置上架时间",
    "add_stall_selltime 商品位置 时间(单位分钟)",
    "add_stall_selltime 1 -60",
}
function Commands.add_stall_selltime(oMaster, iPos, iAdd)
    local iPid = oMaster:GetPid()
    local oStall = global.oStallMgr:GetStallObj(iPid)
    if not oStall then return end

    local oItem = oStall:GetSellItem(iPos)
    if not oItem then return end

    local iTime = oItem:GetSellTime()
    iTime = iTime + iAdd*60
    oItem:SetSellTime(iTime)
    local sMsg = string.format("成功设置%s(%s)上架时间为%s",
        oItem.m_oDataCtrl:Name(),
        iPos,
        get_time_format_str(iTime, "%Y-%m-%d %H:%M:%S")
    )
    oMaster:NotifyMessage(sMsg)
end

Helpers.guild_init = {
    "初始化商会",
    "guild_init",
    "guild_init",
}
function Commands.guild_init(oMaster)
    global.oGuild:Init()
    global.oGuild:InitCatalog()
    oMaster:NotifyMessage("初始化商会成功")
end

Helpers.npcstoreop = {
    "NPC商店操作",
    "npcstoreop",
    "npcstoreop",
}
function Commands.npcstoreop(oMaster, sOrder, mArgs)
    mArgs = mArgs or {}
    oMaster.m_oStoreCtrl:TestOp(sOrder, mArgs)
end
