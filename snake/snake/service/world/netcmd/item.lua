local global = require "global"
local skynet = require "skynet"
local extend = require "base/extend"

local max = math.max
local min = math.min

-----------------------------------------------C2GS--------------------------------------------
function C2GSItemUse(oPlayer, mData)
    local itemid = mData["itemid"]
    local target = mData["target"]
    local sExArg = mData["exarg"]
    local itemobj = oPlayer.m_oItemCtrl:HasItem(itemid, true)
    if not itemobj then
        return
    end
    local mArgs = {}
    mArgs.exarg = sExArg
    itemobj:Use(oPlayer, target, mArgs)
end

function C2GSItemListUse(oPlayer, mData)
    local lUseInfo = mData.use_list
    local iTarget = mData.target
    local sExArg = mData.exarg
    local mArgs = {exarg = sExArg}
    global.oItemHandler:ItemListUse(oPlayer, lUseInfo, iTarget, mArgs)
end

function C2GSItemInfo(oPlayer,mData)
    local itemid = mData["itemid"]
    local itemobj = oPlayer.m_oItemCtrl:HasItem(itemid, true)
    if not itemobj then
        return
    end
    itemobj:Refresh()
end

function C2GSItemMove(oPlayer,mData)
    local itemid = mData["itemid"]
    local iPos = mData["iPos"]
    global.oItemHandler:ItemMove(oPlayer, itemid, iPos)
end

function C2GSItemArrage(oPlayer,mData)
    local oPubMgr = global.oPubMgr
    local oNotifyMgr = global.oNotifyMgr

    local sKey = "itemarrange"
    if oPlayer.m_oThisTemp:Query(sKey) then
        return
    end
    oPlayer.m_oThisTemp:Set(sKey,1,3)
    oPlayer.m_mTempItemCtrl:TranAllToItemBag(true)
    oPubMgr:Arrange(oPlayer.m_iPid,oPlayer.m_oItemCtrl)
end

function C2GSAddItemExtendSize(oPlayer,mData)
    local iSize = mData["size"]
    global.oItemHandler:AddItemExtendSize(oPlayer, iSize)
end

function C2GSDeComposeItem(oPlayer,mData)
    local itemid = mData["id"]
    local iAmount = mData["amount"]
    global.oItemHandler:DeComposeItem(oPlayer, itemid, iAmount)
end

function C2GSComposeItem(oPlayer,mData)
    local itemid = mData["id"]
    local iAmount = mData["amount"]
    local iTarSid = mData["compose_sid"]
    global.oItemHandler:ComposeItem(oPlayer, iTarSid, iAmount, itemid)
end

function C2GSItemsExchangeItem(oPlayer,mData)
    local iExcID = mData["exchangeid"]
    local iAmount = mData["amount"]
    global.oItemHandler:ExchangeItem(oPlayer,iExcID,iAmount)
end

function C2GSRecycleItem(oPlayer, mData)
    local itemid = mData.itemid
    local iAmount = math.max(mData.amount or 0, 1)
    global.oItemHandler:RecycleItem(oPlayer, itemid, iAmount, true)
end

function C2GSFixEquip(oPlayer,mData)
    local iPos = mData["pos"]
    if not iPos then
        return
    end
    global.oItemHandler:FixEquip(oPlayer, iPos)
end

function C2GSFixAllEquips(oPlayer, mData)
    global.oItemHandler:FixAllEquips(oPlayer)
end

function C2GSMakeEquipInfo(oPlayer,mData)
    global.oItemHandler:SendMakeEquip(oPlayer, mData["sid"])
end

function C2GSMakeEquip(oPlayer,mData)
    global.oItemHandler:MakeEquip(oPlayer, mData["sid"], mData["flag"])
end

function C2GSEquipStrength(oPlayer,mData)
    local iPos = mData["pos"]
    local iFlag = mData["flag"]
    local iFast = mData["fast"]
    local oItem = oPlayer.m_oItemCtrl:GetItem(iPos)
    if not oItem then return end
        
    global.oItemHandler.m_oEquipStrengthenMgr:FastEquipStrengh(oPlayer, oItem, iFlag, iFast)
end

function C2GSWashEquipInfo(oPlayer,mData)
    local iItemId = mData["itemid"]
    local oItem = oPlayer.m_oItemCtrl:HasItem(iItemId, true)
    if not oItem then
        return
    end
    if oItem:ItemType() ~= "equip" then
        return
    end
    oItem:SendNetWash(oPlayer)
end

function C2GSWashEquip(oPlayer,mData)
    local iItemId = mData["itemid"]
    local iFlag = mData["flag"]
    local oItem = oPlayer.m_oItemCtrl:HasItem(iItemId, true)
    if not oItem then
        return
    end
    global.oItemHandler.m_oEquipWashMgr:WashEquip(oPlayer,oItem, iFlag)
end

function C2GSUseWashEquip(oPlayer,mData)
    local iItemId = mData["itemid"]
    local oItem = oPlayer.m_oItemCtrl:HasItem(iItemId, true)
    if not oItem then
        return
    end
    oItem:Wash(oPlayer)
end

function C2GSMergeShenHun(oPlayer,mData)
    local iTargetShape = mData["sid"]
    global.oItemHandler:MergeShenHun(oPlayer, iTargetShape)
end

function C2GSUseShenHun(oPlayer,mData)
    local iEquipId = mData["equip_id"]
    -- 神魂 id 还使用吗？？？
    local iShenhunId = mData["shenhun_id"]
    local iFlag = mData["flag"]
    global.oItemHandler:UseShenHun(oPlayer, iEquipId, iShenhunId, iFlag)
end

function C2GSStrengthInfo(oPlayer,mData)
    local record = require "public.record"
    record.warning("liuzla-- C2GSStrengthInfo proto type need delete after client deal")
end

function C2GSCompoundItem(oPlayer,mData)
    local iSid = mData["targetid"]
    local bMix = mData["compoundtype"] == 2
    local iMoneyType = mData["moneytype"]
    global.oItemHandler:CompoundItem(oPlayer,iSid,bMix,iMoneyType)
end

-- TODO 暂时不加此协议
function C2GSLookItemInfo(oPlayer, mData)
    local iItemId = mData.itemid
    local iVersion = mData.version -- TODO 至少装备要加，做轻量推送用
    -- global.oItemHandler:LookItemInfo(oPlayer, iItemId, iVersion)
end

function C2GSEquipBreak(oPlayer, mData)
    local iPos = mData["pos"]
    local iFlag = mData["flag"]
    local oItem = oPlayer.m_oItemCtrl:GetItem(iPos)
    if not oItem then
        return
    end
    global.oItemHandler.m_oEquipStrengthenMgr:EquipBreak(oPlayer, oItem, iFlag)
end

function C2GSDeComposeItemList(oPlayer, mData)
    local lItems = mData["items"]
    global.oItemHandler:DeComposeItemList(oPlayer, lItems)
end

function C2GSRecFuHunPointReward(oPlayer, mData)
    local iSid = mData["sid"]    
    oPlayer.m_oEquipCtrl:RecFuHunPointReward(iSid)
end

function C2GSGetFuHunCost(oPlayer, mData)
    local iEquipId = mData["equip_id"]    
    global.oItemHandler:SendFuHunCost(oPlayer, iEquipId)
end

function C2GSSummonEquipResetSkill(oPlayer, mData)
    local iEquipId = mData["equip_id"]    
    global.oItemHandler:SummonEquipResetSkill(oPlayer, iEquipId)
end

function C2GSSummonEquipCombine(oPlayer, mData)
    local itemids = mData["itemid"]    
    global.oItemHandler:SummonEquipCombine(oPlayer, itemids)
end

function C2GSHSCompose1(oPlayer, mData)
    local itemid = mData.itemid
    local iAddRatio = mData.addradio or 0
    global.oItemHandler:ComposeHunShi1(oPlayer, itemid,iAddRatio)
end

function C2GSHSCompose2(oPlayer, mData)
    local itemid1 = mData.itemid1
    local itemid2 = mData.itemid2
    local iAddRatio = mData.addradio or 0
    global.oItemHandler:ComposeHunShi2(oPlayer, itemid1,itemid2,iAddRatio)
end

function C2GSHSDeCompose(oPlayer, mData)
    local itemid = mData.itemid
    global.oItemHandler:DeComposeHunShi(oPlayer, itemid)
end

function C2GSEquipAddHS(oPlayer, mData)
    local hunshiid = mData.hunshiid
    local equipid = mData.equipid
    local iPos = mData.pos
    global.oItemHandler:EquipAddHunShi(oPlayer, equipid,hunshiid,iPos)
end

function C2GSEquipDelHS(oPlayer, mData)
    local equipid = mData.equipid
    local iPos = mData.pos
    global.oItemHandler:EquipDelHunShi(oPlayer, equipid,iPos)
end

function C2GSChangeHS(oPlayer,mData)
    local itemid = mData.itemid
    local attr = mData.attr
    local color = mData.color
    global.oItemHandler:ChangeHunShi(oPlayer, itemid,color,attr)
end

function C2GSItemGoldCoinPrice(oPlayer, mData)
    local iSid = mData.sid
    global.oItemHandler:C2GSItemGoldCoinPrice(oPlayer, iSid) 
end

function C2GSFastBuyItemPrice(oPlayer, mData)
    local iSid = mData.sid
    local iStoreType = mData.store_type
    global.oFastBuyMgr:C2GSFastBuyItemPrice(oPlayer, iSid, iStoreType)
end

function C2GSFastBuyItemListPrice(oPlayer, mData)
    local lSidList = mData.item_list
    global.oFastBuyMgr:C2GSFastBuyItemListPrice(oPlayer, lSidList)
end

function C2GSWenShiMake(oPlayer, mData)
    local iItemId = mData.itemid
    global.oItemHandler:MakeWenShi(oPlayer, iItemId) 
end

function C2GSWenShiCombine(oPlayer, mData)
    local iItemId1 = mData.itemid1
    local iItemId2 = mData.itemid2
    global.oItemHandler:CombineWenShi(oPlayer, iItemId1, iItemId2) 
end

function C2GSWenShiWash(oPlayer, mData)
    local locks = mData.locks
    local iItemId = mData.itemid
    local iFlag = mData.flag
    global.oItemHandler:WashShenShi(oPlayer, iItemId, locks, iFlag) 
end

