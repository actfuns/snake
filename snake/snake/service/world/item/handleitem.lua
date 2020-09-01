local global = require "global"
local extend = require "base.extend"
local record = require "public.record"
local res = require "base.res"

local itemdefines = import(service_path("item/itemdefines"))
local gamedefines = import(lualib_path("public/gamedefines"))
local washequip = import(service_path("item/washequip"))
local strengthenquip = import(service_path("item/strength"))
local makeequip = import(service_path("item/makeequip"))
local boxmgr = import(service_path("item/boxmgr"))
local stalldefines = import(service_path("stall.defines"))
local analylog = import(lualib_path("public.analylog"))

local string = string

function NewItemHandler()
    return CItemHandler:New()
end

CItemHandler = {}
CItemHandler.__index = CItemHandler
inherit(CItemHandler, logic_base_cls())

function CItemHandler:New()
    local o = super(CItemHandler).New(self)
    o.m_oEquipWashMgr = washequip.CEquipWashMgr:New()
    o.m_oEquipStrengthenMgr = strengthenquip.CEquipStrengthenMgr:New()
    o.m_oEquipMakeMgr = makeequip.CEquipMakeMgr:New()
    o.m_oBoxMgr = boxmgr.NewBoxMgr()
    return o
end

function CItemHandler:Release()
    baseobj_safe_release(self.m_oEquipWashMgr)
    self.m_oEquipWashMgr = nil
    baseobj_safe_release(self.m_oEquipStrengthenMgr)
    self.m_oEquipStrengthenMgr = nil
    baseobj_safe_release(self.m_oEquipMakeMgr)
    self.m_oEquipMakeMgr = nil
    baseobj_safe_release(self.m_oBoxMgr)
    self.m_oBoxMgr = nil
    super(CItemHandler).Release(self)
end

function CItemHandler:GetTextData(iText, mReplace)
    return global.oToolMgr:GetSystemText({"itemtext"}, iText, mReplace)
end

function CItemHandler:GetGlobalData(idx)
    local res = require "base.res"
    local mData = res["daobiao"]["global"][idx]
    local iVal = mData["value"]
    iVal = tonumber(iVal) or 1000000
    return iVal
end

function CItemHandler:ValidRoleWield(oPlayer, oEquip, bNotify)
    local oNotifyMgr = global.oNotifyMgr
    local pid = oPlayer.m_iPid
    local iRoleType = oEquip:RoleType()
    if iRoleType ~= 0 then
        if iRoleType ~= oPlayer:GetRoleType() then
            if bNotify then
                oNotifyMgr:Notify(pid, self:GetTextData(1003))
            end
            return false
        end
    else
        local iSex = oEquip:Sex()
        if iSex ~= 0 and oPlayer:GetSex() ~= iSex then
            if bNotify then
                local sMsg = self:GetTextData(1002)
                local sSexStr = (iSex == 1) and "男" or "女"
                sMsg = global.oToolMgr:FormatColorString(sMsg, {sex = sSexStr})
                oNotifyMgr:Notify(pid, sMsg)
            end
            return false
        end
        local iRace = oEquip:Race()
        if iRace ~= 0 and iRace ~= oPlayer:GetRace() then
            if bNotify then
                oNotifyMgr:Notify(pid, self:GetTextData(1003))
            end
            return false
        end
    end
    local iSchool = oEquip:School()
    if iSchool ~= 0 and oPlayer:GetSchool() ~= iSchool then
        if bNotify then
            oNotifyMgr:Notify(pid, self:GetTextData(1001))
        end
        return false
    end
    return true
end

function CItemHandler:ValidWield(oPlayer,oEquip)
    local oNotifyMgr = global.oNotifyMgr
    local oToolMgr = global.oToolMgr
    local pid = oPlayer.m_iPid
    if not self:ValidRoleWield(oPlayer, oEquip, true) then
        return false
    end
    local bCanWield, sMsg = oEquip:CanWield(oPlayer)
    if not bCanWield then
        oNotifyMgr:Notify(pid, sMsg)
        return bCanWield
    end
    if oEquip:GetLast() <= 0 then
        oNotifyMgr:Notify(pid, oToolMgr:FormatColorString(self:GetTextData(1022)))
        return false
    end
    return true
end

function CItemHandler:Wield(oPlayer, oEquip, mArgs)
    local oNotifyMgr = global.oNotifyMgr
    if not self:ValidWield(oPlayer,oEquip) then
        return
    end
    local iPos = oEquip:EquipPos()
    local pid = oPlayer.m_iPid
    local oOldEquip = oPlayer.m_oItemCtrl:GetItem(iPos)
    local iMasterLevelOld = oPlayer:StrengthMasterLevel()
    if oOldEquip then
        oOldEquip:UnWield(oPlayer)
        oPlayer.m_oItemCtrl:ItemChange(oOldEquip,oEquip)
        local mChangePos = {}
        table.insert(mChangePos,{itemid=oEquip.m_ID,pos=oEquip.m_Pos})
        table.insert(mChangePos,{itemid=oOldEquip.m_ID,pos=oOldEquip.m_Pos})
        oPlayer.m_oItemCtrl:GS2CItemArrange(pid,mChangePos)
    else
        oPlayer.m_oItemCtrl:ChangeToPos(oEquip,iPos)
        local mChangePos = {}
        table.insert(mChangePos,{itemid=oEquip.m_ID,pos=oEquip.m_Pos})
        oPlayer.m_oItemCtrl:GS2CItemArrange(pid,mChangePos)
    end
    if oEquip:IsValid() then
        oEquip:Wield(oPlayer)
        if iPos == itemdefines.EQUIP_WEAPON then
            oPlayer:ChangeWeapon()
        end
    end
    global.oScoreCache:Dirty(oPlayer:GetPid(), "equip")
    local bNeedCheckFix = false
    if oOldEquip then
        bNeedCheckFix = oOldEquip:IsNeedFix() ~= oEquip:IsNeedFix()
    else
        bNeedCheckFix = oEquip:IsNeedFix()
    end
    if bNeedCheckFix then
        oPlayer.m_oItemCtrl:CheckNeedFixEquips(oPlayer)
    end

    oPlayer:CheckAttr()
    local iMasterLevelNew = oPlayer:StrengthMasterLevel()
    if iMasterLevelNew ~= iMasterLevelOld then
        oPlayer:TriggerStrengthMaster(iMasterLevelNew)
        oPlayer:SyncStrengthenInfo(nil, true)
    end
    oPlayer:RefreshPropAll()
    if not mArgs or not mArgs.cancel_tip then
        local sMsg = global.oToolMgr:FormatColorString(self:GetTextData(1005), {item = oEquip:TipsName()})
        oNotifyMgr:Notify(pid, sMsg)
        if oOldEquip and oPlayer:StrengthenLevel(iPos) > 0  then
            local sMsg = global.oToolMgr:FormatColorString(self:GetTextData(1039))
            oNotifyMgr:Notify(pid,sMsg)
        end
    end
    oPlayer:Send("GS2CGetScore",{op = 2,score = oPlayer:GetRoleScore()})
    return {unwielded = oOldEquip}
end

function CItemHandler:UnWield(oPlayer, oEquip, mArgs)
    local oNotifyMgr = global.oNotifyMgr
    local pid = oPlayer.m_iPid
    if not oEquip:Equiped() then
        oNotifyMgr:Notify(pid, self:GetTextData(1007))
        return
    end
    local iPos = oEquip:EquipPos()
    -- 先移动位置，确保可以进背包才扣角色数值
    local iTargetPos = oPlayer.m_oItemCtrl:GetValidPos()
    if not iTargetPos then
        oNotifyMgr:Notify(pid, self:GetTextData(1008))
        return
    end
    oEquip:UnWield(oPlayer)
    oPlayer.m_oItemCtrl:ChangeToPos(oEquip,iTargetPos)
    local mChangePos = {}
    table.insert(mChangePos,{itemid=oEquip.m_ID,pos=oEquip.m_Pos})
    oPlayer.m_oItemCtrl:GS2CItemArrange(pid,mChangePos)
    if iPos == itemdefines.EQUIP_WEAPON then
        oPlayer:ChangeWeapon()
    end
    global.oScoreCache:Dirty(oPlayer:GetPid(), "equip")
    if oEquip:IsNeedFix() then
        oPlayer.m_oItemCtrl:CheckNeedFixEquips(oPlayer)
    end
    oPlayer:CheckAttr()
    -- oPlayer:SecondLevelPropChange()
    -- oPlayer:ThreeLevelPropChange()
    local iMasterLevelNew = oPlayer:StrengthMasterLevel()
    oPlayer:TriggerStrengthMaster(iMasterLevelNew)
    oPlayer:SyncStrengthenInfo(nil, true)
    oPlayer:RefreshPropAll()
    oPlayer:Send("GS2CGetScore",{op = 2,score = oPlayer:GetRoleScore()})
    if not mArgs or not mArgs.cancel_tip then
        local sMsg = global.oToolMgr:FormatColorString(self:GetTextData(1006), {item = oEquip:TipsName()})
        oNotifyMgr:Notify(pid, sMsg)
    end
    return true
end

function CItemHandler:GetDaZaoData()
    local res = require "base.res"
    return res["daobiao"]["dazao"]
end

-- 玩家拥有的足够的最优先的符
function CItemHandler:GetUsersEquipFu(oPlayer, iEquipLv, iPos, iAmount)
    local lFuSids = itemdefines.GetEquipFus(iEquipLv, iPos)
    for idx, iFuSid in ipairs(lFuSids) do
        if oPlayer:GetItemAmount(iFuSid) >= iAmount then
            return iFuSid
        end
    end
    local iFuDefault = lFuSids[1]
    return iFuDefault
end

function CItemHandler:GetMakeEquipBook(oPlayer, iEquipLv)
    local mData = self:GetDaZaoData()
    for iSid, m in pairs(mData) do
        if m["sex"] == oPlayer:GetSex() and m["school"] == oPlayer:GetSchool() 
            and iEquipLv == m["level"] then
            return iSid
        end
    end
    return nil
end

function CItemHandler:GetMakeEquipCost(oPlayer, iEquipLv, iPos)
    local mResult, lCostItem = {}, {}
    local iBook = self:GetMakeEquipBook(oPlayer, iEquipLv, iPos)
    assert(iBook, string.format("GetMakeEquipCost equipbook err, level:%d, pos:%d", iEquipLv, iPos))
    mResult[iBook] = 1
    table.insert(lCostItem, {sid = iBook, amount = 1})

    local iRealSid = self:GetUsersEquipFu(oPlayer, iEquipLv, iPos, 1)
    assert(iRealSid, string.format("GetMakeEquipCost fu err, level:%d, pos:%d", iEquipLv, iPos))
    mResult[iRealSid] = 1
    table.insert(lCostItem, {sid = iRealSid, amount = 1})        
    return mResult, lCostItem 
end

function CItemHandler:GetMakeCostSliver(iEquipLv)
    return iEquipLv * 1000
end

-- 打造iSid的装备需要哪些消耗
function CItemHandler:SendMakeEquip(oPlayer, iSid)
    local mItemData = global.oItemLoader:GetItemData(iSid)
    assert(mItemData, string.format("make equip err, sid:%d", iSid))

    local _, lCostItem = self:GetMakeEquipCost(oPlayer, mItemData.equipLevel, mItemData.equipPos)
    assert(#lCostItem > 0, string.format("not find cost make equip err, sid:%d", iSid))

    table.insert(lCostItem, {sid = 1002, amount = self:GetMakeCostSliver(mItemData.equipLevel)})
    local bFlag, iCost = self:GetQuickMakeGoldCoin(oPlayer, iSid)
    oPlayer:Send("GS2CEquipMake",{sid = iSid, make_info = lCostItem, goldcoin=iCost})
end

function CItemHandler:GetQuickMakeGoldCoin(oPlayer, iSid)
    local mItemData = global.oItemLoader:GetItemData(iSid)
    assert(mItemData, string.format("make equip err, sid:%d", iSid))
    local iEquipLv, iPos = mItemData.equipLevel, mItemData.equipPos

    local iGoldCoin = 0
    local iSLV = oPlayer:GetServerGrade()
    local lFuSids = itemdefines.GetEquipFus(iEquipLv, iPos)
    assert(#lFuSids > 0, string.format("not find cost fu make equip err, sid:%d", iSid))
    local iFuSid = lFuSids[1]
    local iStallSid = stalldefines.EncodeSid(iFuSid)
    if not global.oStallMgr then
        return false, 0
    end
    local oStall = global.oStallMgr:GetStallObj(oPlayer:GetPid())
    local iSliverPrice = oStall:GetDefaultPrice(iStallSid)
    if iSliverPrice <= 0 then
        record.warning(string.format("not find price stall err, sid:%d", iFuSid))
        return false
    end
    iGoldCoin = iGoldCoin + math.ceil(iSliverPrice / (iSLV * 50 + 8000))

    local iBook = self:GetMakeEquipBook(oPlayer, iEquipLv)
    local iGoldPrice = global.oGuild:GetItemPrice(iBook)
    if not iGoldPrice or iGoldPrice <= 0 then
        record.warning(string.format("not find price guild err, sid:%d", iBook))
        return false
    end
    iGoldCoin = iGoldCoin + math.ceil(iGoldPrice / 100)    

    local iSilver = self:GetMakeCostSliver(iEquipLv)
    iGoldCoin = iGoldCoin + math.ceil(iSilver / (iSLV * 50 + 8000))
    return true, iGoldCoin
end

-- 返回打造的 银币 和 道具花费
function CItemHandler:GetMakeEquipCostInfo(oPlayer, iSid)
    local mItemData = global.oItemLoader:GetItemData(iSid)
    assert(mItemData, string.format("make equip get %d makecostinfo error", iSid))
    local iEquipLv, iPos = mItemData.equipLevel, mItemData.equipPos
    local iSLV = oPlayer:GetServerGrade()
    local iFuSid = self:GetUsersEquipFu(oPlayer, iEquipLv, iPos, 1)
    -- 装备元灵
    local iBookSid = self:GetMakeEquipBook(oPlayer, iEquipLv)
    local mRetCostItem = {}
    mRetCostItem[iFuSid] = 1
    mRetCostItem[iBookSid] = 1
    local iRetSilver = self:GetMakeCostSliver(iEquipLv)
    return iRetSilver, mRetCostItem
end

function CItemHandler:MakeEquip(oPlayer, iSid, iFlag)
    if not global.oToolMgr:IsSysOpen("EQUIP_DZ", oPlayer) then return end

    if oPlayer.m_oItemCtrl:GetCanUseSpaceSize() <= 0 then
        oPlayer:NotifyMessage(self:GetTextData(1009))
        return
    end

    local bBind = false
    local iSilver, mCostItem = self:GetMakeEquipCostInfo(oPlayer, iSid)
    if not next(mCostItem) then
        oPlayer:NotifyMessage(self:GetTextData(1028))
        return
    end
    local sReason
    local mLogCost = {}
    if iFlag and iFlag > 0 then
        sReason = "快捷装备打造"
        local mNeedCost = {}
        mNeedCost["silver"] = iSilver
        mNeedCost["item"] = {}
        for iSid, iAmount in pairs(mCostItem) do
            mNeedCost["item"][iSid] = iAmount
        end
        local bSucc, mTrueCost = global.oFastBuyMgr:FastBuy(oPlayer, mNeedCost, sReason, {cancel_tip = true})
        if not bSucc then return end
        if mTrueCost["goldcoin"] then
            mLogCost[gamedefines.MONEY_TYPE.GOLDCOIN] = mTrueCost["goldcoin"]
        end
        if mTrueCost["silver"] then
            mLogCost[gamedefines.MONEY_TYPE.SILVER] = mTrueCost["silver"]
        end
        for iSid, iUseAmount in pairs(mTrueCost["item"]) do
            mLogCost[iSid] = iUseAmount
        end
        -- 默认绑定属性为 false,玩家可能通过分解获得绑定物品，打造后再分解变成非打造
    else
        sReason = "装备打造"
        if iSilver > 0 then
            if not oPlayer:ValidSilver(iSilver) then return end
        end
        for iSid, iAmount in pairs(mCostItem) do
            if oPlayer:GetItemAmount(iSid) < iAmount then
                local sTipsName = global.oItemLoader:GetItemTipsNameBySid(iSid)
                oPlayer:NotifyMessage(self:GetTextData(1027, {item = sTipsName}))
                return
            end
        end

        if iSilver > 0 then
            oPlayer:ResumeSilver(iSilver, sReason)
            mLogCost[gamedefines.MONEY_TYPE.SILVER] = iSilver
        end
        for iSid, iAmount in pairs(mCostItem) do
            local mResult = oPlayer:RemoveItemAmount(iSid, iAmount, sReason, {cancel_tip = true})
            mLogCost[iSid] = iAmount
            if not mResult then return end
            if mResult.bind then bBind = true end
        end
    end
    analylog.LogSystemInfo(oPlayer, "equip_make", iSid, mLogCost)
    local mArgs = {
        equip_make = 1,
        school = oPlayer:GetSchool(),
    }
    local oEquip = global.oItemLoader:Create(iSid, mArgs)
    if bBind then oEquip:Bind(iPid) end
    oPlayer:RewardItem(oEquip, sReason, {cancel_tip = true, cancel_chat = true})
    local oToolMgr = global.oToolMgr
    local sMsg = oToolMgr:FormatColorString(self:GetTextData(1010), {item = oEquip:TipsName()})
    global.oNotifyMgr:UIEffectNotify(oPlayer:GetPid(), gamedefines.UI_EFFECT_MAP.DAO_ZAO, {sMsg})
    -- oPlayer:NotifyMessage(sMsg)
    oPlayer:MarkGrow(25)
    oPlayer.m_oItemCtrl:FireEquipDazao(oEquip)
    global.oRankMgr:PushDataToEveryDayRank(oPlayer, "make_equip", {cnt=1})
end

--物品暂时 缺省元宝价格
local NameToTblType = {
    [gamedefines.MONEY_TYPE.GOLD] = "buyPrice",
    [gamedefines.MONEY_TYPE.SILVER] = "buyPrice",
    [gamedefines.MONEY_TYPE.GOLDCOIN] = "buyPrice",
}

--获取物品对应的货币价格
function CItemHandler:GetItemCostByMoneyType(sid,iMoneyType)
    local res = require "base.res"
    local mItemTbl = res["daobiao"]["item"]
    assert(mItemTbl[sid][NameToTblType[iMoneyType]],"没有定义物品对应的"..iMoneyType.."价格")
    return mItemTbl[sid][NameToTblType[iMoneyType]]
end

function CItemHandler:GetItemCompoundMaterial(sid)
    local res = require "base.res"
    local mUseTbl = res["daobiao"]["itemcompound"]
    assert(mUseTbl[sid], string.format("没有配置%d的合成材料", sid))
    return mUseTbl[sid]["sid_item_list"]
end

function CItemHandler:GetItemCompoundCost(sid)
    local res = require "base.res"
    local mUseTbl = res["daobiao"]["itemcompound"]
    return mUseTbl[sid]["sid_money_list"]
end

function CItemHandler:GetItemCompoundPermissionMoneyType(sid)
    local res = require "base.res"
    local mUseTbl = res["daobiao"]["itemcompound"]
    return mUseTbl[sid]["sid_permit_money_list"]
end

function CItemHandler:GetItemExchangeInfo(iExcID)
    local res = require "base.res"
    local mExchangeInfo = res["daobiao"]["itemexchange"]
    return mExchangeInfo[iExcID]
end

--判断材料是否足够，返回是否可以合成，可以消耗的材料，额外需要的货币，仍缺的材料
function CItemHandler:CheckIsMaterialEnough(oPlayer,sid,iMoneyType)
    local mMaterialTbl = self:GetItemCompoundMaterial(sid)
    local mCanUseItemTbl = {}
    local mExtraUseMoneyTbl = {}
    local mStillNeedItemTbl = {}
    local bCanCompound = true
    for _,value in pairs(mMaterialTbl) do
        if value["amount"] <= oPlayer:GetItemAmount(value["sid"]) then
            mCanUseItemTbl[value["sid"]] = (mCanUseItemTbl[value["sid"]] or 0) + value["amount"]
        elseif iMoneyType then
            mCanUseItemTbl[value["sid"]] = (mCanUseItemTbl[value["sid"]] or 0) + oPlayer:GetItemAmount(value["sid"])
            mExtraUseMoneyTbl[iMoneyType] = (mExtraUseMoneyTbl[iMoneyType] or 0) + self:GetItemCostByMoneyType(value["sid"],iMoneyType) * (value["amount"] - oPlayer:GetItemAmount(value["sid"]))
        else
            table.insert(mStillNeedItemTbl,value["sid"])
            bCanCompound = false
        end
    end
    return bCanCompound,mCanUseItemTbl,mExtraUseMoneyTbl,mStillNeedItemTbl
end

--合成方式:
--      混合合成：材料不足则扣除材料对应价格的货币
--      单一合成：材料不足则直接合成失败
function CItemHandler:CompoundItem(oPlayer,sid,bMix,iMoneyType)
    local oNotifyMgr = global.oNotifyMgr
    local oToolMgr = global.oToolMgr
    local iPid = oPlayer:GetPid()

    if bMix then
        local bTag = false
        local PermissionMoneyTbl = self:GetItemCompoundPermissionMoneyType(sid)
        for _,value in pairs(PermissionMoneyTbl) do
            if value == iMoneyType then
                bTag = true
                break
            end
        end
        assert(bTag,string.format("%s 物品合成使用错误合成方式",oPlayer:GetPid()))
    end

    local mMaterialTbl = self:GetItemCompoundMaterial(sid)
    local mMoneyTbl = self:GetItemCompoundCost(sid) or {}
    local bCanCompound,mTrulyUseItemTbl,mTrulyUseMoneyTbl,mStillNeedItemTbl = self:CheckIsMaterialEnough(oPlayer,sid,(bMix and iMoneyType or nil))
    if not bCanCompound then
        if #mStillNeedItemTbl > 0 then
            local oTmpItem = global.oItemLoader:Create(mStillNeedItemTbl[1])
            local sMsg = oToolMgr:FormatColorString(self:GetTextData(1011), {item = oTmpItem:TipsName()})
            oNotifyMgr:Notify(iPid, sMsg)
        end
        return
    end

    for key,value in pairs(mMoneyTbl) do
        mTrulyUseMoneyTbl[value["coin_name"]] = (mTrulyUseMoneyTbl[value["coin_name"]] or 0)  + value["cost"]
    end

    for iType,iAmount in pairs(mTrulyUseMoneyTbl) do
        if iAmount > 0 and not oPlayer:ValidMoneyByType(iType,iAmount,{tip = gamedefines.MONEY_NAME[iType].."不足，合成失败！"}) then
            bCanCompound = false
            break
        end
    end
    if not bCanCompound then
        return false
    end

    local sReason = "物品合成"

---开始消耗物品
    local bBind = false
    for iSid,iAmount in pairs(mTrulyUseItemTbl) do
        if iAmount > 0 then
            local mResult = oPlayer:RemoveItemAmount(iSid,iAmount,sReason)
            if not mResult then
                return
            end
            if mResult.bind then
                bBind = true
            end
        end
    end
---开始消耗货币
    for iType,iAmount in pairs(mTrulyUseMoneyTbl) do
        if iAmount > 0 then
            oPlayer:ResumeMoneyByType(iType,iAmount,sReason)
        end
    end

    local oTargetItem = global.oItemLoader:Create(sid)
    if bBind then
        oTargetItem:Bind(iPid)
    end
    oPlayer:RewardItem(oTargetItem,sReason)

    local sMsg = oToolMgr:FormatColorString(self:GetTextData(1012), {item = oTargetItem:TipsName()})
    oNotifyMgr:Notify(iPid, sMsg)

    return true
end

function CItemHandler:GetFenJieData()
    local res = require "base.res"
    return res["daobiao"]["equipfenjie"]
end

function CItemHandler:GetFenjieKuData()
    local res = require "base.res"
    return res["daobiao"]["fenjieku"]
end

function CItemHandler:GetFuhunCostData(iSid)
    return res["daobiao"]["fuhuncost"][iSid]
end

function CItemHandler:DeComposeItem(oPlayer, itemid, iAmount)
    local oChatMgr = global.oChatMgr
    local oToolMgr = global.oToolMgr
    local mGiveItem = self:DoItemDecompose(oPlayer, itemid, iAmount)
    if not mGiveItem then return end
    
    for iSid, iAmount in pairs(mGiveItem) do
        if iSid > 10000 then
            local oItem = global.oItemLoader:GetItem(iSid)
            local sMsg = self:GetTextData(1029, {amount = iAmount, item = oItem:TipsName()})
            global.oNotifyMgr:ItemNotify(oPlayer:GetPid(), {sid=iSid, amount=iAmount})
            oChatMgr:HandleMsgChat(oPlayer, sMsg)
        end
    end
end

function CItemHandler:DeComposeItemList(oPlayer, lItemList)
    local oChatMgr = global.oChatMgr
    local oToolMgr = global.oToolMgr
    local mGiveItem = {}
    local mHunShi = {}
    local mEquipHS = {}

    for _, mItem in pairs(lItemList) do
        local oItem = oPlayer.m_oItemCtrl:HasItem(mItem.id)
        if oItem and oItem:IsHunShi() then
            mHunShi[mItem.id] = mItem.amount
            goto continue 
        elseif oItem and oItem:ItemType() == "equip" and table_count(oItem:GetHunShi())>0 then
            table.insert(mEquipHS,oItem:GetHunShi())
        end
        local mResultItem = self:DoItemDecompose(oPlayer, mItem.id, mItem.amount)
        if not mResultItem or table_count(mResultItem) <= 0 then break end

        local sMsg = oToolMgr:FormatColorString(self:GetTextData(1090), {decamount = mItem.amount, decitem = oItem:TipsName()})
        for iSid, iAmount in pairs(mResultItem) do
            mGiveItem[iSid] = (mGiveItem[iSid] or 0) + iAmount

            if iSid == 1002 then
                sMsg = sMsg .. oToolMgr:FormatColorString(self:GetTextData(1089), {amount = iAmount})
            elseif iSid > 10000 then
                local oGetItem = global.oItemLoader:GetItem(iSid)
                sMsg = sMsg .. oToolMgr:FormatColorString(self:GetTextData(1029), { amount = iAmount, item = oGetItem:TipsName()})
            end
        end
        oPlayer:NotifyMessage(sMsg)
        oChatMgr:HandleMsgChat(oPlayer, sMsg)
        ::continue::
    end

    for itemid,iAmount in pairs(mHunShi) do
        self:DeComposeHunShi(oPlayer,itemid,iAmount)
    end
    for _,mAllInfo in pairs(mEquipHS) do
        for pos ,mInfo in pairs(mAllInfo) do
            self:BackHunShi(oPlayer,mInfo,"DeComposeItem")
        end
    end
end

function CItemHandler:DoItemDecompose(oPlayer, iItemId, iAmount)
    local oItem = oPlayer.m_oItemCtrl:HasItem(iItemId)
    if not oItem then return end
    
    if oItem:GetAmount() < math.max(iAmount, 1) then return end

    if not oItem:ValidDeCompose() then return end
    
    local mDecomItem = oItem:DeComposeItems()
    if table_count(mDecomItem) <= 0 then return end

    local mArgs = {
        cancel_tip = true,
        cancel_chat = true,
        bind = oItem:IsBind() or oItem:ItemType() == "equip" or oItem:ItemType() == "wenshi",
    }
    local sReason = "分解"
    if oItem:ItemType() == "equip" then
        sReason = "装备分解"
    end
    oPlayer:RemoveOneItemAmount(oItem, iAmount, sReason, {cancel_tip = true, cancel_chat = true})

    local mGiveItem = {}
    for iSid, iCnt in pairs(mDecomItem) do
        mGiveItem[iSid] = iCnt * iAmount
        oPlayer:RewardItems(iSid, iCnt * iAmount, "分解", mArgs)
    end
    -- TODO add log
    return mGiveItem
end

function CItemHandler:ComposeItem(oPlayer, iTarSid, iAmount, itemid)
    if iAmount <= 0 then return end
    
    local mData = self:GetItemCompoundMaterial(iTarSid)
    if not mData then return end

    if itemid and itemid > 0 then
        local itemobj = oPlayer.m_oItemCtrl:HasItem(itemid)
        if not itemobj then return end

        if not itemobj:ValidCompose() then return end
    end


    local mCostItem = {}
    for _, mCost in pairs(mData) do
        mCostItem[mCost["sid"]] = mCost["amount"] * iAmount
    end
    if table_count(mCostItem) <= 0 then
        record.warning("CItemHandler:ComposeItem not find cost %d %d", iTarSid, iAmount)
        return 
    end

    if iTarSid < 1000 then
        -- 物品组
        local lItemGroup = global.oItemLoader:GetItemGroup(iTarSid)
        if not lItemGroup or #lItemGroup <= 0 then
            record.warning("CItemHandler:ComposeItem not find itemgourp %d %d", iTarSid, iAmount)
            return 
        end
        iTarSid = lItemGroup[math.random(#lItemGroup)] 
    end

    for iSid, iCnt in pairs(mCostItem) do
        if oPlayer:GetItemAmount(iSid) < iCnt then
            oPlayer:NotifyMessage("物品不足")
            return
        end
    end

    local mGiveItem = {}
    mGiveItem[iTarSid] = iAmount
    if not oPlayer:ValidGive(mGiveItem) then
        oPlayer:NotifyMessage(self:GetTextData(1015))
        return
    end

    local sReason = "道具合成"
    local mArgs = {}
    for iSid, iCnt in pairs(mCostItem) do
        local mResult = oPlayer:RemoveItemAmount(iSid, iCnt, sReason)
        if mResult.bind then
            mArgs.bind = true
        end
    end
    oPlayer:GiveItem(mGiveItem, sReason, mArgs)
end

-- 逻辑和合成物品一样
function CItemHandler:ExchangeItem(oPlayer,iExcID,iAmount)
    if not iAmount or iAmount <= 0 then return end
    local mExcInfo = self:GetItemExchangeInfo(iExcID)
    if not mExcInfo then return end
    local iTragetSid = mExcInfo["sid"]
    local lCostItemInfo = mExcInfo["cost_item_list"]

    local mCostItem = {}
    for _,mCost in pairs(lCostItemInfo) do
        mCostItem[mCost["sid"]] = mCost["amount"] * iAmount
    end
    if table_count(mCostItem) <= 0 then
        record.warning("CItemHandler:ExchangeItem not find cost %d %d",iExcID,iTragetSid)
        return
    end

    for iSid,iCnt in pairs(mCostItem) do
        if oPlayer:GetItemAmount(iSid) < iCnt then
            oPlayer:NotifyMessage("道具不足")
            return
        end
    end

    local mGiveItem = {}
    mGiveItem[iTragetSid] = iAmount
    if not oPlayer:ValidGive(mGiveItem) then
        oPlayer:NotifyMessage(self:GetTextData(1015))
        return
    end
    --扣除发奖
    local sReason = "道具兑换"
    local mArgs = {}
    for iSid,iCnt in pairs(mCostItem) do
        local mResult = oPlayer:RemoveItemAmount(iSid,iCnt,sReason)
        if mResult.bind then
            mArgs.bind = true
        end
    end
    oPlayer:GiveItem(mGiveItem,sReason,mArgs)
end

function CItemHandler:ItemMove(oPlayer, itemid, iPos)
    local srcobj = oPlayer.m_oItemCtrl:HasItem(itemid)
    if not srcobj then
        return
    end
    local destobj = oPlayer.m_oItemCtrl:GetItem(iPos)
    if not destobj then
        oPlayer.m_oItemCtrl:ChangeToPos(srcobj,iPos)
    else
        oPlayer.m_oItemCtrl:ItemChange(srcobj,destobj)
    end
end

function CItemHandler:AddItemExtendSize(oPlayer, iSize)
    if not extend.Table.find({5,10},iSize) then
        return
    end
    local iSilver = self:GetGlobalData(103)
    if iSize == 10 then
        iSilver = 2 * iSilver
    end

    if not oPlayer.m_oActiveCtrl:ValidSilver(iSilver,"购买仓库") then
        return
    end
    oPlayer.m_oActiveCtrl:ResumeSilver(iSilver,"购买仓库")
    local oContainer = oPlayer.m_oItemCtrl
    if not oContainer then
        return
    end
    if not oContainer:CanAddExtendSize() then
        return
    end
    oPlayer.m_oItemCtrl:AddExtendSize(iSize)
    analylog.LogSystemInfo(oPlayer, "item_extend_size", nil, {[gamedefines.MONEY_TYPE.SILVER]=iSilver})
end

function CItemHandler:RecycleItem(oPlayer, itemid, iAmount, bAuto, bSilent)
    local oItemCtrl = oPlayer.m_oItemCtrl
    local oItem = oItemCtrl:HasItem(itemid)
    if oItem and oItem:ValidRecycle() then
        local iSalePrice = oItem:SalePrice()
        local iAmount = math.max(1, iAmount)
        if iSalePrice > 0  then
            local oToolMgr = global.oToolMgr
            if bAuto then
                self:OnConfirmRecycleItem(oPlayer, {answer = 1}, itemid, iAmount, iSalePrice, bSilent)
            else
                local mData = self:GetTextData(1021)
                local sContent = mData.sContent
                mData.sContent = oToolMgr:FormatColorString(sContent, {item = oItem:TipsName(), price = iSalePrice*iAmount})
                local func = function (oPlayer, mData)
                    global.oItemHandler:OnConfirmRecycleItem(oPlayer, mData, itemid, iAmount, iSalePrice, bSilent)
                end
                global.oCbMgr:SetCallBack(oPlayer:GetPid(), "GS2CConfirmUI", mData, nil, func)
            end
        end
    end
end

function CItemHandler:OnConfirmRecycleItem(oPlayer, mData, itemid, iAmount, iSalePrice, bSilent)
    local iAnswer = mData["answer"]
    local iAmount = math.max(1, iAmount)
    if iAnswer == 1 then
        local oItem = oPlayer.m_oItemCtrl:HasItem(itemid)
        if not oItem or not oItem:ValidRecycle() then
            return
        end
        if oItem:GetAmount() < iAmount then
            return
        end
        local sReason = "道具回收"
        if not bSilent then
            local sMsg = self:GetTextData(1030, {amount = 1, item = oItem:TipsName()})
            oPlayer:NotifyMessage(sMsg)
        end
        local mArgs = {}
        mArgs.cancel_chat  = true
        mArgs.cancel_tip = true
        oPlayer:RemoveOneItemAmount(oItem, iAmount, sReason,mArgs)
        local sMsg = self:GetTextData(1036,{item = oItem:TipsName()})
        global.oChatMgr:HandleMsgChat(oPlayer,sMsg)
        oPlayer:RewardSilver(iSalePrice*iAmount, sReason)
    end
end

function CItemHandler:FixAllEquips(oPlayer)
    local iSilver = oPlayer.m_oItemCtrl:CalcFixAllEquipPrice(oPlayer)
    if iSilver <= 0 then
        return
    end
    if not oPlayer:ValidSilver(iSilver) then
        return
    end
    oPlayer:ResumeSilver(iSilver, "修理全部装备")
    for iPos = 1,6 do
        local oItem = oPlayer.m_oItemCtrl:GetItem(iPos)
        if oItem and oItem:GetLast() < oItem:GetMaxLast() then
            oItem:FixEquip(oPlayer, true)
        end
    end
    local oWar = oPlayer.m_oActiveCtrl:GetNowWar()
    local oNotifyMgr = global.oNotifyMgr
    if oWar then
        oNotifyMgr:Notify(iPid, self:GetTextData(1017))
    else
        oNotifyMgr:Notify(iPid, self:GetTextData(1018))
    end
    local iNeedFixState = 1001
    oPlayer.m_oStateCtrl:RemoveState(iNeedFixState)
end

function CItemHandler:FixEquip(oPlayer, iPos)
    local oNotifyMgr = global.oNotifyMgr
    local iPid = oPlayer.m_iPid
    local oItem = oPlayer.m_oItemCtrl:GetItem(iPos)
    if not oItem then
        return
    end
    if oItem:GetLast() >= oItem:GetMaxLast() then
        oNotifyMgr:Notify(iPid, self:GetTextData(1016))
        return
    end
    local iSilver = oItem:GetFixPrice()
    if not oPlayer:ValidSilver(iSilver) then
        return
    end
    oPlayer:ResumeSilver(iSilver,"修复装备")
    oItem:FixEquip(oPlayer)
    local oWar = oPlayer.m_oActiveCtrl:GetNowWar()
    if oWar then
        oNotifyMgr:Notify(iPid, self:GetTextData(1017))
    else
        oNotifyMgr:Notify(iPid, self:GetTextData(1018))
    end
end

function CItemHandler:GetShenHunData()
    local res = require "base.res"
    return res["daobiao"]["shenhunmerge"]
end

function CItemHandler:MergeShenHun(oPlayer, iTargetShape)
    if not global.oToolMgr:IsSysOpen("EQUIP_FH", oPlayer) then return end
        
    local oToolMgr = global.oToolMgr
    local mData = self:GetShenHunData()[iTargetShape]
    if not mData then return end
        
    local mCostItem, iSilver = {}, 0
    for _, mAmount in pairs(mData["sid_list"]) do
        local iSid = mAmount["sid"]
        local iAmount = mAmount["amount"]
        if iSid == 1002 then
            iSilver = iAmount
            if not oPlayer:ValidSilver(iSilver) then return end
        else
            mCostItem[iSid] = iAmount
            if oPlayer:GetItemAmount(iSid) < iAmount then
                local sTipsName = global.oItemLoader:GetItemTipsNameBySid(iSid)
                local sMsg = oToolMgr:FormatColorString(self:GetTextData(1019), {item = sTipsName})
                oPlayer:NotifyMessage(sMsg)
                return
            end
        end
    end

    if oPlayer.m_oItemCtrl:GetCanUseSpaceSize() < 0 then
        oPlayer:NotifyMessage(self:GetTextData(1015))
        return
    end

    if iSilver > 0 then
        oPlayer:ResumeSilver(iSilver, "合成神魂")
    end
    
    for iSid,iAmount in pairs(mCostItem) do
        oPlayer:RemoveItemAmount(iSid, iAmount, "合成神魂")
    end

    local oItem = global.oItemLoader:Create(iTargetShape)
    oPlayer:RewardItem(oItem, "合成神魂")
    oPlayer:NotifyMessage(oToolMgr:FormatColorString(self:GetTextData(1020), {item = oItem:TipsName()}))
end

function CItemHandler:GetFuHunCost(oPlayer, iSid, iEquipLv, iPos)
    -- 部分配表 部分需要计算
    local mCost, lCost, iSHSid  = {}, {}
    local mData = self:GetFuhunCostData(iSid)
    assert(mData, string.format("GetFuHunCost not find fu data, %d", iSid))

    for _, mItem in pairs(mData["cost_list"]) do
        local oItem = global.oItemLoader:GetItem(mItem["sid"])
        if oItem:ItemType() == "shenhun" then
            iSHSid = mItem["sid"]
        end
        mCost[mItem["sid"]] = mItem["cnt"]
        table.insert(lCost, {sid = mItem["sid"], amount = mItem["cnt"]})
    end

    local iFuSid = self:GetUsersEquipFu(oPlayer, iEquipLv, iPos, 1)
    assert(iFuSid, string.format("GetFuHunCost fu err, level:%d, pos:%d", iEquipLv, iPos))
    mCost[iFuSid] = 1
    table.insert(lCost, {sid = iFuSid, amount = 1})
    -- local iSHSid = itemdefines.GetShenHun(iEquipLv)
    -- assert(iSHSid, string.format("GetFuHunCost shenhun err, level:%d, pos:%d", iEquipLv, iPos))
    -- mCost[iSHSid] = 1

    -- local iStoreSid = itemdefines.GetFuHunStore(iEquipLv, iPos)
    -- assert(iStoreSid, string.format("GetFuHunCost fuhun store err, level:%d, pos:%d", iEquipLv, iPos))
    -- mCost[iStoreSid] = 1
    mCost[1002] = iEquipLv * 2000
    table.insert(lCost, {sid = 1002, amount = iEquipLv * 2000})
    return mCost, iSHSid, lCost
end

function CItemHandler:SendFuHunCost(oPlayer, iEquipId)
    local oEquip = oPlayer.m_oItemCtrl:HasItem(iEquipId, true)
    if not oEquip or oEquip:ItemType() ~= "equip" then return end
    
    local _, _, lCost = self:GetFuHunCost(oPlayer, oEquip:SID(), oEquip:EquipLevel(), oEquip:EquipPos())
    oPlayer:Send("GS2CFuHunCost",{equip_id = iEquipId, cost_info = lCost})
end

-- 装备附魂时获取消耗，与netcmd/partner 获取所需合成物数量完全一致
function CItemHandler:GetReplaceItem(iSid, iAmount)
    local lReplace = {}
    local mUseTbl = res["daobiao"]["itemcompound"]
    if not mUseTbl[iSid] then
        local mUnit = {}
        mUnit.sid = iSid
        mUnit.amount = iAmount
        table.insert(lReplace, mUnit)
    else
        local lCostItem = mUseTbl[iSid]["sid_item_list"]
        for _, mItem in ipairs(lCostItem) do
            local mUnit = {}
            mUnit.sid = mItem.sid
            mUnit.amount = mItem.amount*iAmount
            table.insert(lReplace, mUnit)
        end
    end
    return lReplace
end

function CItemHandler:UseShenHun(oPlayer, iEquipId, iShenhunId, iFlag)
    if not global.oToolMgr:IsSysOpen("EQUIP_FH", oPlayer) then return end
        
    local oEquip = oPlayer.m_oItemCtrl:HasItem(iEquipId, true)
    if not oEquip or oEquip:ItemType() ~= "equip" then return end
        
    -- local oItem = oPlayer.m_oItemCtrl:HasItem(iShenhunId)
    -- if not oItem or oItem:ItemType() ~= "shenhun" then return end
        
    local mCost, iSHSid = self:GetFuHunCost(oPlayer, oEquip:SID(), oEquip:EquipLevel(), oEquip:EquipPos())
    if not mCost or table_count(mCost) <= 0 then
        oPlayer:NotifyMessage(self:GetTextData(1028))
        return
    end

    -- 提取出银币
    local iSilver = 0
    if mCost[1002] then
        iSilver = mCost[1002]
        mCost[1002] = nil
    end
    local lTrueCostItem = {}
    local lReplaceItem = {}
    for iSid, iAmount in pairs(mCost) do
        local iHasAmount = oPlayer:GetItemAmount(iSid)
        if iHasAmount < iAmount then
            if iHasAmount > 0 then
                table.insert(lTrueCostItem, {sid = iSid, amount = iHasAmount})
            end
            for _, mReplace in pairs(self:GetReplaceItem(iSid, iAmount - iHasAmount)) do
                table.insert(lReplaceItem, mReplace)
            end
        else
            table.insert(lTrueCostItem, {sid = iSid, amount = iAmount})
        end
    end

    local mTrueCostItem = {}
    for _, mData in ipairs(lTrueCostItem) do
        mTrueCostItem[mData.sid] = (mTrueCostItem[mData.sid] or 0) + mData.amount
    end

    local sReason
    local mLogCost = {}
    if iFlag and iFlag > 0 then
        local sReason = "快捷附魂"
        local mNeedCost = {}
        mNeedCost["silver"] = iSilver
        mNeedCost["item"] = {}
        for iSid, iAmount in pairs(mTrueCostItem) do
            mNeedCost["item"][iSid] = iAmount
        end
        for _, mData in ipairs(lReplaceItem) do 
            mNeedCost["item"][mData.sid] = (mNeedCost["item"][mData.sid] or 0 ) + mData.amount
        end
        local bSucc, mTrueCost = global.oFastBuyMgr:FastBuy(oPlayer, mNeedCost, sReason, {cancel_tip = true})
        if not bSucc then return end
        if mTrueCost["silver"] then
            mLogCost[gamedefines.MONEY_TYPE.SILVER] = mTrueCost["silver"]
        end
        if mTrueCost["goldcoin"] then
            mLogCost[gamedefines.MONEY_TYPE.GOLDCOIN] = mTrueCost["goldcoin"]
        end
        for iSid, iUseAmount in pairs(mTrueCost["item"]) do
            mLogCost[iSid] = iUseAmount
        end
    else
        sReason = "附魂"
        if iSilver > 0 then
            if not oPlayer:ValidSilver(iSilver) then
                return
            end
        end
        for _, mData in ipairs(lReplaceItem) do
            local iHasAmount = oPlayer:GetItemAmount(mData.sid)
            local iTrueCostNeed = mTrueCostItem[mData.sid] or 0
            if oPlayer:GetItemAmount(mData.sid) - iTrueCostNeed < mData.amount then
                local sTipsName = global.oItemLoader:GetItemTipsNameBySid(mData.sid)
                oPlayer:NotifyMessage(self:GetTextData(1031, {item=sTipsName}))
                return
            end
        end
        if iSilver > 0 then
            mLogCost[gamedefines.MONEY_TYPE.SILVER] = iSilver
            oPlayer:ResumeSilver(iSilver, sReason)
        end
        for _, mData in ipairs(lTrueCostItem) do
            mLogCost[mData.sid] = mData.amount
            oPlayer:RemoveItemAmount(mData.sid, mData.amount, sReason, {cancel_tip = true})
        end
        for _, mData in ipairs(lReplaceItem) do
            mLogCost[mData.sid] = mData.amount
            oPlayer:RemoveItemAmount(mData.sid, mData.amount, sReason, {cancel_tip = true})
        end
    end
    oEquip:EquipFH(oPlayer, iSHSid or 1)
    local mPointData = res["daobiao"]["fuhunpoint"][oEquip:EquipLevel()]
    local iPoint = math.random(mPointData["min_point"], mPointData["max_point"])
    oPlayer.m_oEquipCtrl:AddFuHunPoint(iPoint)
    oPlayer.m_oEquipCtrl:GS2CUpdateFuHunPoint(oPlayer)
    oPlayer:MarkGrow(35)

    if oEquip:IsWield() then
        if oEquip:EquipPos() == itemdefines.EQUIP_WEAPON then
            oPlayer:ChangeWeapon()
        end
        oPlayer:SecondLevelPropChange()
        oPlayer:ThreeLevelPropChange()
    end
    analylog.LogSystemInfo(oPlayer, "equip_fuhun", iSHSid, mLogCost)
    oPlayer.m_oItemCtrl:FireEquipFuhun(oEquip)
    -- oPlayer:NotifyMessage(self:GetTextData(1032))
    global.oNotifyMgr:UIEffectNotify(oPlayer:GetPid(), gamedefines.UI_EFFECT_MAP.FU_HUN, {self:GetTextData(1032)})
end

function CItemHandler:SummonEquipResetSkill(oPlayer, iItem)
    local oEquip = oPlayer.m_oItemCtrl:HasItem(iItem)
    if not oEquip or oEquip:ItemType() ~= "summonequip" then return end

    if not oEquip:IsEquipType(itemdefines.SUMMON_EQUIP_HF) then return end
    -- 
    local iSid = oEquip:GetItemData()['resetcost']
    if oPlayer:GetItemAmount(iSid) < 1 then
        local sTipsName = global.oItemLoader:GetItemTipsNameBySid(iSid)
        local sMsg = global.oToolMgr:FormatColorString(self:GetTextData(1019), {item = sTipsName})
        oPlayer:NotifyMessage(sMsg)
        return
    end
    oPlayer:RemoveItemAmount(iSid, 1, "重置宠物装备技能")
    oEquip:ResetSkill()
    oPlayer:Send("GS2CUpdateItemInfo", {itemdata=oEquip:PackItemInfo()})
end

function CItemHandler:SummonEquipCombine(oPlayer, lItemId)
    if not table_in_list({2, 4}, #lItemId) then return end

    local iNewSid, isHuFu
    local bFlag = (#lItemId == 4)
    for _, id in pairs(lItemId) do
        local oItem = oPlayer:HasItem(id)
        if not oItem then return end

        if iNewSid and iNewSid ~= oItem:SID() then return end
        iNewSid = oItem:SID()
        isHuFu = oItem:IsEquipType(itemdefines.SUMMON_EQUIP_HF)

        if bFlag then
            if oItem:GetSKillCnt() < 2 then
                oPlayer:NotifyMessage(global.oSummonMgr:GetText(2021)) 
                return 
            end
        else
            if oItem:GetSKillCnt() >= 2 then
                oPlayer:NotifyMessage(global.oSummonMgr:GetText(2038)) 
                return 
            end
        end
    end
    for _, id in pairs(lItemId) do
        local oItem = oPlayer:HasItem(id)
        oPlayer:RemoveOneItemAmount(oItem, 1, "宠物装备合成", {cancel_chat=true, cancel_tip=true})
    end
    
    local mArgs = {} 
    if isHuFu then
        mArgs.skcnt = 1
        if bFlag or math.random(100) <= 10 then
            mArgs.skcnt = 2
        end
    end

    local oNewItem = global.oItemLoader:Create(iNewSid, mArgs)
    local sMsg = global.oToolMgr:FormatColorString("消耗#amount个#item", {amount = #lItemId, item = oNewItem:TipsName()})
    global.oChatMgr:HandleMsgChat(oPlayer, sMsg)
    global.oNotifyMgr:ItemNotify(oPlayer:GetPid(), {sid=oNewItem:SID(), amount=-#lItemId})
    oPlayer:RewardItem(oNewItem, "宠物装备合成")
    oPlayer:Send("GS2CSummonEquipCombine", {id=oNewItem:ID()})
end

function CItemHandler:ComposeHunShi1(oPlayer,itemid,iAddRadio)
    local pid  = oPlayer:GetPid()
    local oNotifyMgr = global.oNotifyMgr
    local itemobj = oPlayer.m_oItemCtrl:HasItem(itemid)
    if not itemobj then
        return
    end
    if not itemobj:IsHunShi() then
        return
    end
    local mBasicData = itemobj:GetHunShiBasicData()
    local iNeedAmount = mBasicData.upgrade_cost
    if iNeedAmount<=0 then
        return
    end
    local mResult = self:GetHunShiByComkey(oPlayer,itemobj)

    if mResult.amount <iNeedAmount then
        oNotifyMgr:Notify(pid,string.format("%s不足",itemobj:TipsName()))
        return
    end

    local sReason = "hunshi_compose1"
    local itemsid = itemobj:SID()
    local tAddAttr = itemobj:GetAddAttr()
    local iGrade = itemobj:GetGrade()
    local mComposeRadio = itemobj:GetComposeRadio()
    local mRadio = mComposeRadio[iGrade+1]
    if not mRadio then
        return
    end
    local iAddRadioItem = 11181
    local iAddRadioAmount = 0
    if not mRadio then
        return
    end
    local iRatio = mRadio["ratio"]
    if iAddRadio ==1 and iRatio < 100  then
        if oPlayer:GetItemAmount(iAddRadioItem)>= mRadio["protectneed"] then
            iAddRadioAmount = mRadio["protectneed"]
            iRatio = 100
        else
            local oNeedItem  = global.oItemLoader:GetItem(iAddRadioItem)
            oNotifyMgr:Notify(pid,string.format("%s不足",oNeedItem:TipsName()))
            return
        end
    end
    
    local iTrueRatio = math.random(100)
    if iTrueRatio<=iRatio then
        local oItem = global.oItemLoader:Create(itemsid)
        oItem:SetGrade(iGrade+1)
        oItem:SetAddAttr(tAddAttr)
         if itemobj:IsBind() then
            oItem:Bind(pid)
        end
        local itemlist = {oItem}
        if not oPlayer:ValidGiveitemlist(itemlist) then
            return
        end
        if iAddRadioAmount>0 then
            oPlayer:RemoveItemAmount(iAddRadioItem,iAddRadioAmount,sReason)
        end
        self:ResumeHS(oPlayer,itemobj,iNeedAmount,sReason)
        oPlayer:GiveItemobj(itemlist,sReason)
    else
        oPlayer:RemoveOneItemAmount(itemobj, 1, sReason)
        oNotifyMgr:Notify(pid,"合成失败")
    end
end

function CItemHandler:GetHunShiByComkey(oPlayer,itemobj)
    local sid = itemobj:SID()
    local iKey = itemobj:CustomCombineKey()
    local itemlist = oPlayer.m_oItemCtrl:GetShapeItem(sid)
    local samelist = {}
    local iAmount = 0
    for _,oItem in pairs(itemlist) do 
        if iKey == oItem:CustomCombineKey() then
            table.insert(samelist,oItem)
            iAmount = iAmount + oItem:GetAmount()
        end
    end
    local mResult = {}
    mResult.itemlist = samelist
    mResult.amount = iAmount
    return mResult
end

function CItemHandler:ResumeHS(oPlayer,itemobj,iAmount,sReason)
    local iNeedAmount = iAmount
    local sTipsName = itemobj:TipsName()
    local sid = itemobj:SID()
    local iKey = itemobj:CustomCombineKey()
    local itemlist = oPlayer.m_oItemCtrl:GetShapeItem(sid)
    local samelist = {}
    for _,oItem in pairs(itemlist) do 
        if iKey == oItem:CustomCombineKey() then
            table.insert(samelist,oItem)
        end
    end
    table.sort(samelist,function (itemobj1,itemobj2)
        if itemobj1:GetData("Bind",0) > itemobj2:GetData("Bind",0) then
            return true 
        end
    end)
    while iAmount>0 and #samelist>0 do
        local itemobj = samelist[1]
        local iAddAmount = math.min(iAmount,itemobj:GetAmount())
        iAmount = iAmount - iAddAmount
        if iAddAmount == itemobj:GetAmount() then
            table.remove(samelist,1)
        end
        oPlayer:RemoveOneItemAmount(itemobj, iAddAmount, sReason)
    end
    local sMsg = global.oToolMgr:FormatColorString("消耗#amount个#item", {amount = iNeedAmount, item = sTipsName})
    global.oChatMgr:HandleMsgChat(oPlayer,sMsg)
end

function CItemHandler:ComposeHunShi2(oPlayer,itemid1,itemid2,iAddRadio)
    local pid  = oPlayer:GetPid()
    local oNotifyMgr = global.oNotifyMgr
    local itemobj1 = oPlayer.m_oItemCtrl:HasItem(itemid1)
    local itemobj2 = oPlayer.m_oItemCtrl:HasItem(itemid2)
    if not itemobj1 or not itemobj2 then
        return
    end
    if not itemobj1:IsHunShi() or not itemobj2:IsHunShi()  then
        return
    end
    local iNeedAmount = 1
    local mResult1 = self:GetHunShiByComkey(oPlayer,itemobj1)
    local mResult2 = self:GetHunShiByComkey(oPlayer,itemobj2)
    if mResult1.amount<iNeedAmount or mResult2.amount<iNeedAmount then
        return
    end
    local sReason = "hunshi_compose2"
    local iGrade1 = itemobj1:GetGrade()
    local iGrade2 = itemobj2:GetGrade()
    local tAddAttr1 = itemobj1:GetAddAttr()
    local tAddAttr2 = itemobj2:GetAddAttr()
    local itemsid1  = itemobj1:SID()
    local itemsid2 = itemobj2:SID()
    if itemsid1 == itemsid2 then
        return
    end
    if iGrade1 ~= iGrade2 then
        return
    end
    local mBasicData1  = itemobj1:GetHunShiBasicData()
    local mBasicData2 = itemobj2:GetHunShiBasicData()
    if mBasicData1.level ~= 1  or mBasicData2.level~=1 then
        return
    end
    local mFatherBasic1 = itemobj1:GetFatherBasicData()
    local mFatherBasic2 = itemobj2:GetFatherBasicData()
    local iFatherColor
    for iFather,_ in pairs(mFatherBasic1) do
        if mFatherBasic2[iFather] then
            iFatherColor = iFather
            break
        end
    end
    if not iFatherColor then
        return
    end
    local iAddRadioItem = 11181
    local iAddRadioAmount = 0
    local mLianHuaRes = res["daobiao"]["hunshi"]["lianhua"][iGrade1]
    local iRatio = mLianHuaRes["ratio"]
    if iAddRadio==1 and iRatio<100 then
        if oPlayer:GetItemAmount(iAddRadioItem)>= mLianHuaRes["protectneed"] then
            iAddRadioAmount = mLianHuaRes["protectneed"]
            iRatio = 100
        else
            local oNeedItem  = global.oItemLoader:GetItem(iAddRadioItem)
            oNotifyMgr:Notify(pid,string.format("%s不足",oNeedItem:TipsName()))
            return
        end
    end
    if math.random(100) <= iRatio then 
        local mFatherRes = res["daobiao"]["hunshi"]["color"][iFatherColor]
        local iFatherItemSid = mFatherRes["itemsid"]
        local oItem = global.oItemLoader:Create(iFatherItemSid)
        oItem:SetGrade(iGrade1)
        oItem:SetAddAttr({tAddAttr1[1],tAddAttr2[1]})
         if itemobj1:IsBind() or itemobj2:IsBind() then
            oItem:Bind(pid)
        end
        local itemlist = {oItem}
        if not oPlayer:ValidGiveitemlist(itemlist) then
            return
        end
        if iAddRadioAmount>0 then
            oPlayer:RemoveItemAmount(iAddRadioItem,iAddRadioAmount,sReason)
        end
        self:ResumeHS(oPlayer,itemobj1,iNeedAmount,sReason)
        self:ResumeHS(oPlayer,itemobj2,iNeedAmount,sReason)
        oPlayer:GiveItemobj(itemlist,sReason)
    else
        oPlayer:RemoveOneItemAmount(itemobj1, 1, sReason)
        oNotifyMgr:Notify(pid,"合成失败")
    end
end

function CItemHandler:DeComposeHunShi(oPlayer,itemid,iAmount)
    local oNotifyMgr = global.oNotifyMgr
    local itemobj = oPlayer.m_oItemCtrl:HasItem(itemid)
    if not itemobj then
        return
    end
    if iAmount<1 then
        return
    end
    if itemobj:GetAmount() <iAmount then
        return
    end

    if not itemobj:IsHunShi() then
        return
    end
    local sReason = "hunshi_decompose"
    local pid  = oPlayer:GetPid()
    local mBasicData = itemobj:GetHunShiBasicData()
    local itemsid = itemobj:SID()
    local tAddAttr = itemobj:GetAddAttr()
    local iGrade = itemobj:GetGrade()
    local sDeposeMoney = mBasicData["compose_money"]
    local iDeposeMoney = math.floor(formula_string(sDeposeMoney,{lv = iGrade}))
    if not oPlayer:ValidSilver(iDeposeMoney) then
        return
    end
    if mBasicData.level == 1 then
        if iGrade<=1 then
            return
        end
        local oItem = global.oItemLoader:Create(itemsid)
        oItem:SetGrade(iGrade-1)
        oItem:SetAddAttr(tAddAttr)
        local iRandom = math.random(1, 3)
        oItem:SetAmount(iRandom*iAmount)
         if itemobj:IsBind() then
            oItem:Bind(pid)
        end
        local itemlist = {oItem}
        if not oPlayer:ValidGiveitemlist(itemlist) then
            return
        end
        oPlayer:ResumeSilver(iDeposeMoney,sReason)
        oPlayer:RemoveOneItemAmount(itemobj, iAmount, "hunshi_decompose")
        oPlayer:GiveItemobj(itemlist,sReason)
        oNotifyMgr:Notify(pid,"分解成功")
    elseif mBasicData.level == 2 then
        local mSonBasic = itemobj:GetSonBasicData()
        local mSonAttr = itemobj:GetSonAttrData()
        local lRewardItem = {}
        for _,sAttr in pairs(tAddAttr) do
            for iSonColor,mSonAttr in pairs(mSonAttr) do
                if mSonAttr[sAttr] then
                    local itemsid = mSonBasic[iSonColor]["itemsid"]
                    local oItem = global.oItemLoader:Create(itemsid)
                    oItem:SetGrade(iGrade)
                    oItem:SetAddAttr({sAttr})
                    oItem:SetAmount(iAmount)
                    if itemobj:IsBind() then
                        oItem:Bind(pid)
                    end
                    table.insert(lRewardItem,oItem)
                end
            end
        end
        if not oPlayer:ValidGiveitemlist(lRewardItem) then
            return
        end
        oPlayer:RemoveOneItemAmount(itemobj, iAmount, sReason)
        oPlayer:ResumeSilver(iDeposeMoney,sReason)
        oPlayer:GiveItemobj(lRewardItem,sReason)
        oNotifyMgr:Notify(pid,"分解成功")
    end
end

function CItemHandler:EquipAddHunShi(oPlayer,equipid,hunshiid,iPos)
    local oNotifyMgr = global.oNotifyMgr
    local pid  = oPlayer:GetPid()
    local oHunShi = oPlayer.m_oItemCtrl:HasItem(hunshiid)
    local oEquip = oPlayer.m_oItemCtrl:HasItem(equipid,true)
    if not oHunShi  or not oEquip then
        return
    end
    if oHunShi:GetAmount() <1 then
        return
    end
    if not oHunShi:IsHunShi() then
        return
    end
    if iPos<1 or iPos>3 then
        return
    end
    local sReason = "equip_addhunshi"
    local mBasicData = oHunShi:GetHunShiBasicData()
    local mEquipHS = oEquip:GetHunShi()
    local iEquipPos = oEquip:EquipPos()
    local iEquipLv = oEquip:EquipLevel()
    local mEquipHSColor = res["daobiao"]["hunshi"]["equipcolor"][iEquipPos]
    local mEquipHSLimit = res["daobiao"]["hunshi"]["equiplimit"][iEquipLv]
    if not mEquipHSColor or not mEquipHSLimit then
        return
    end
    local iHoleColor = mEquipHSColor["colorlist"][iPos]
    if mBasicData.level ==1 then
        if  iHoleColor ~= oHunShi:GetColor() then
            return
        end
    elseif mBasicData.level ==2 then
        if not extend.Table.find(mBasicData.son,iHoleColor) then
            return
        end
    else
        return
    end
    local iHoleCnt = mEquipHSLimit["holecnt"]
    if table_count(mEquipHS)>=iHoleCnt and not mEquipHS[iPos]  then
        return
    end
    if not mEquipHS[iPos] then
        local mData = {}
        mData.color = oHunShi:GetColor()
        mData.addattr = oHunShi:GetAddAttr()
        mData.grade = oHunShi:GetGrade()
        mData.pos = iPos
        oEquip:AddHunShi(mData)
        oPlayer:RemoveOneItemAmount(oHunShi, 1, sReason)
        oNotifyMgr:Notify(pid,"镶嵌成功")
        if iEquipPos <=100  then
            oPlayer:RefreshPropAll()
        end
    else
        local mInfo = mEquipHS[iPos]
        local iColor = mInfo.color 
        local iGrade = mInfo.grade 
        local tAddAttr = mInfo.addattr 
        local mRes = res["daobiao"]["hunshi"]["color"][iColor]
        if not mRes then
            return
        end
        local oItem = global.oItemLoader:Create(mRes.itemsid)
        oItem:SetGrade(iGrade)
        oItem:SetAddAttr(tAddAttr)
        oItem:Bind(pid)
        local itemlist = {oItem}
        if not oPlayer:ValidGiveitemlist(itemlist) then
            return
        end
        local sReason = "equip_delhunshi"
        oPlayer:GiveItemobj(itemlist,sReason,{cancel_chat=true,cancel_tip=true})
        oEquip:DelHunShi(iPos)
        oNotifyMgr:Notify(pid,"更换成功")

        local mData = {}
        mData.color = oHunShi:GetColor()
        mData.addattr = oHunShi:GetAddAttr()
        mData.grade = oHunShi:GetGrade()
        mData.pos = iPos
        oEquip:AddHunShi(mData)
        oPlayer:RemoveOneItemAmount(oHunShi, 1, sReason)
        if iEquipPos <=100  then
            oPlayer:RefreshPropAll()
        end
    end
    local mLog = oPlayer:LogData()
    mLog["pos"] = iPos
    mLog["item"] = oHunShi:PackLogInfo()
    mLog["equip"] = oEquip:PackLogInfo()
    record.user("equip", "add_hunshi", mLog)
end

function CItemHandler:EquipDelHunShi(oPlayer,equipid,iPos)
    local oNotifyMgr = global.oNotifyMgr
    local pid  = oPlayer:GetPid()
    local oEquip = oPlayer.m_oItemCtrl:HasItem(equipid,true)
    if not oEquip then
        return
    end
    if iPos<1 or iPos>3 then
        return
    end
    local mEquipHS = oEquip:GetHunShi()
    local mInfo = mEquipHS[iPos]
    if not mInfo then
        return
    end
    
    local iEquipPos = oEquip:EquipPos()
    local iColor = mInfo.color 
    local iGrade = mInfo.grade 
    local tAddAttr = mInfo.addattr 
    local mRes = res["daobiao"]["hunshi"]["color"][iColor]
    if not mRes then
        return
    end
    local oItem = global.oItemLoader:Create(mRes.itemsid)
    oItem:SetGrade(iGrade)
    oItem:SetAddAttr(tAddAttr)
    oItem:Bind(pid)
    local itemlist = {oItem}
    if not oPlayer:ValidGiveitemlist(itemlist) then
        return
    end
    local sReason = "equip_delhunshi"
    oPlayer:GiveItemobj(itemlist,sReason,{cancel_chat=true,cancel_tip=true})
    oEquip:DelHunShi(iPos)
    oNotifyMgr:Notify(pid,"卸下成功")
    if iEquipPos <=100  then
        oPlayer:RefreshPropAll()
    end
    local mLog = oPlayer:LogData()
    mLog["pos"] = iPos
    mLog["item"] = oItem:PackLogInfo()
    mLog["equip"] = oEquip:PackLogInfo()
    record.user("equip", "del_hunshi", mLog)
end

function CItemHandler:BackHunShi(oPlayer,mInfo,sReason)
    local pid = oPlayer:GetPid()
    local iColor = mInfo.color 
    local iGrade = mInfo.grade 
    local tAddAttr = mInfo.addattr 
    local mRes = res["daobiao"]["hunshi"]["color"][iColor]
    if not mRes then
        return
    end
    local oItem = global.oItemLoader:Create(mRes.itemsid)
    oItem:SetGrade(iGrade)
    oItem:SetAddAttr(tAddAttr)
    oItem:Bind(pid)
    local itemlist = {oItem}
    if not oPlayer:ValidGiveitemlist(itemlist) then
        return
    end
    oPlayer:GiveItemobj(itemlist,sReason,{cancel_chat=true,cancel_tip=true})
end

function CItemHandler:ChangeHunShi(oPlayer,itemid,iColor,sAttr)
    local iResumeSID = 11182
    local pid = oPlayer:GetPid()
    local itemobj = oPlayer.m_oItemCtrl:HasItem(itemid)
    if not itemobj then
        return
    end
    local iGrade = itemobj:GetGrade()
    local itemlist = oPlayer.m_oItemCtrl:GetShapeItem(iResumeSID)
    local lResumeList = {}
    for _,oItem in pairs(itemlist) do
        if oItem:Level()>=iGrade then
            table.insert(lResumeList,oItem)
        end
    end
    if #lResumeList<=0 then
        return
    end

    table.sort(lResumeList,function (oItem1,oItem2)
        if oItem1:Level()<oItem2:Level() then
            return true 
        elseif oItem1:Level()>oItem2:Level() then
            return false 
        else
            if oItem1:IsBind() then
                return true 
            else
                return false
            end
        end
    end)
    local oResumeObj = lResumeList[1]
    local mAttrData = res["daobiao"]["hunshi"]["attr"][iColor]
    local mRes2 = res["daobiao"]["hunshi"]["color"][iColor]
    local mRes1 = itemobj:GetHunShiBasicData()
    if not mRes1 or not mRes2 or not mAttrData  then
        return
    end
    if mRes1.level ~=1 or mRes2.level~=1 then
        return
    end
    if not mAttrData[sAttr] then
        return
    end

    local oRewardObj = global.oItemLoader:Create(mRes2.itemsid)
    oRewardObj:SetGrade(iGrade)
    oRewardObj:SetAddAttr({sAttr})
    if itemobj:IsBind() then
        oRewardObj:Bind(pid)
    end
    local sReason = "changehs"
    local lrewardlist = {oRewardObj}
    if not oPlayer:ValidGiveitemlist(lrewardlist,sReason,{cancel_chat=true,cancel_tip=true}) then
        return
    end
    oPlayer:GiveItemobj(lrewardlist,sReason,{cancel_chat=true,cancel_tip=true})
    oPlayer:RemoveOneItemAmount(oResumeObj, 1, sReason)
    oPlayer:RemoveOneItemAmount(itemobj, 1, sReason)
    global.oNotifyMgr:Notify(pid,"转换成功")
end

function CItemHandler:ItemListUse(oPlayer, lUseInfo, iTarget, mArgs)
    local lUsingItems = {}
    local lUsingEquips = {}
    for _, mUseInfo in ipairs(lUseInfo) do
        local iItemId = mUseInfo.itemid
        local iAmount = mUseInfo.amount
        local oItem = oPlayer.m_oItemCtrl:HasItem(iItemId, true)
        if oItem and not oItem:IsLocked() then
            if oItem:ItemType() == "equip" then
                local iPos = oItem:EquipPos()
                local oOldEquip = oPlayer.m_oItemCtrl:GetItem(iPos)
                if not oOldEquip or oOldEquip:EquipLevel() <= oItem:EquipLevel() then
                    table.insert(lUsingEquips, {item = oItem, amount = iAmount})
                end
            else
                table.insert(lUsingItems, {item = oItem, amount = iAmount})
            end
        end
    end

    local mEquipArgs = table_deep_copy(mArgs)
    local bInWar = oPlayer:InWar()
    if bInWar then
        mEquipArgs.silent = true
    end
    for _, mUsingItemInfo in ipairs(lUsingEquips) do
        -- 装备使用需要特殊处理战斗中的使用，将提示消息整合(包含回收消息的屏蔽与奖励银币消息的缓存(战斗后推送))
        local oItem = mUsingItemInfo.item
        local iAmount = mUsingItemInfo.amount
        if not oItem:UseAmount(oPlayer, iTarget, iAmount, mEquipArgs) then
            -- 使用出现异常就中止后续使用
            break
        end
    end
    if bInWar and #lUsingEquips > 0 then
        oPlayer:NotifyMessage(self:GetTextData(1038))
    end

    for _, mUsingItemInfo in ipairs(lUsingItems) do
        local oItem = mUsingItemInfo.item
        local iAmount = mUsingItemInfo.amount
        if not oItem:UseAmount(oPlayer, iTarget, iAmount, mArgs) then
            -- 使用出现异常就中止后续使用
            break
        end
    end
end

function CItemHandler:C2GSItemGoldCoinPrice(oPlayer, iSid)
    local iGoldPrice = global.oGuild:GetItemPrice(iSid) or 0
    local iGoldCoin = global.oToolMgr:ChangeGold2GoldCoin(iGoldPrice)
    oPlayer:Send("GS2CItemGoldCoinPrice",{sid = iSid, goldcoin = iGoldCoin})
end

---------------------wenshi----------------------------
function CItemHandler:MakeWenShi(oPlayer, iItemId)
    local oItem = oPlayer:HasItem(iItemId)
    if not oItem then return end

    local mData = res["daobiao"]["wenshi"]["wenshi_combine"][oItem:SID()]
    if not mData then return end

    local iAmount = mData["amount"]
    if iAmount > oPlayer:GetItemAmount(oItem:SID()) then
        oPlayer:NotifyMessage(self:GetTextData(1067, {amount=iAmount}))
        return
    end

    local o = global.oItemLoader:GetItem(mData["combine_id"])
    assert(o, string.format("not find combine item %s", mData["combine_id"]))

    local bBind = oItem:IsBind()
    if oItem:GetAmount() >= iAmount then
        oPlayer:RemoveOneItemAmount(oItem, iAmount, "纹饰合成")
    else
        iAmount = iAmount - oItem:GetAmount()
        oPlayer:RemoveOneItemAmount(oItem, oItem:GetAmount(), "纹饰合成")
        local lShareItem = oPlayer.m_oItemCtrl:GetShapeItem(oItem:SID())
        table.sort(lShareItem, function (o1,o2)
            if o1:IsBind() ~= o2:IsBind() then
                return o1:IsBind() and bBind
            end
            return false
        end)

        for _,oCost in pairs(lShareItem) do
            bBind = bBind or oCost:IsBind() 
            if oCost:GetAmount() >= iAmount then
                oPlayer:RemoveOneItemAmount(oCost, iAmount, "纹饰合成")
                break
            else
                iAmount = iAmount - oCost:GetAmount()
                oPlayer:RemoveOneItemAmount(oCost, oCost:GetAmount(), "纹饰合成")
            end
        end
    end

    local oWenShi = global.oItemLoader:Create(mData["combine_id"])
    oWenShi:Bind(oPlayer:GetPid())
    -- if bBind then
    --     oWenShi:Bind(oPlayer:GetPid())            
    -- end
    oPlayer:RewardItem(oWenShi, "纹饰合成")

    local mLog = oPlayer:LogData()
    mLog["item"] = {sid=oWenShi:SID()}
    record.user("item", "wenshi_make", mLog)
end

function CItemHandler:CombineWenShi(oPlayer, iItemId1, iItemId2) 
    local oItem1 = oPlayer:HasItem(iItemId1)
    local oItem2 = oPlayer:HasItem(iItemId2)
    if not oItem1 or oItem1:ItemType() ~= "wenshi" then return end
    if not oItem2 or oItem2:ItemType() ~= "wenshi" then return end

    if oItem1:GetLast() <= 0 or oItem2:GetLast() <= 0 then
        oPlayer:NotifyMessage(self:GetTextData(1065))
        return
    end
    if oItem1:SID() ~= oItem2:SID() then
        oPlayer:NotifyMessage(self:GetTextData(1057))
        return
    end
    if oItem1:GrowLevel() ~= oItem2:GrowLevel() then
        oPlayer:NotifyMessage(self:GetTextData(1058))
        return
    end
    if oItem1:GrowLevel() >= oItem1:GetMaxGrowLevel() then
        oPlayer:NotifyMessage(self:GetTextData(1059))
        return
    end

    local iRatio = 0
    local lConfig = oItem1:GetColorConfig()["combine_ratio"]
    for _,v in pairs(lConfig) do
        if v.level == oItem1:GrowLevel() then
            iRatio = v.ratio
        end  
    end
    assert(iRatio > 0, string.format("wen shi combine error sid:%s, level:%s", oItem1:SID(), oItem1:GrowLevel()))
    if math.random(100) <= iRatio then
        local iIdx = math.random(oItem2:GetAttrCnt())
        local mAttr = oItem2:GetAttrByIndex(iIdx)

        oPlayer:RemoveOneItemAmount(oItem2, 1, "纹饰合成成功")
        oItem1:SetAttr(mAttr)
        oItem1:SetData("growlevel", oItem1:GrowLevel() + 1)
        oItem1:SetData("last", oItem1:GetMaxLast())
        oItem1:Bind(oPlayer:GetPid())
        oPlayer.m_oItemCtrl:GS2CAddItem(oItem1, {refresh=1})
        oPlayer:NotifyMessage(self:GetTextData(1060))
        oPlayer:Send("GS2CWenShiCombineResult", {flag=1})

        local mLog = oPlayer:LogData()
        mLog["flag"] = 1
        mLog["item"] = {sid=oItem1:SID(), level=oItem1:GrowLevel()}
        record.user("item", "wenshi_combine", mLog)
    else
        local iSid = oItem1:SID()
        if math.random(2) <= 1 then
            oPlayer:RemoveOneItemAmount(oItem1, 1, "纹饰合成失败")
        else
            oPlayer:RemoveOneItemAmount(oItem2, 1, "纹饰合成失败")
        end
        oPlayer:NotifyMessage(self:GetTextData(1061))
        oPlayer:Send("GS2CWenShiCombineResult", {flag=0})

        local mLog = oPlayer:LogData()
        mLog["item"] = {sid=iSid}
        mLog["flag"] = 0
        record.user("item", "wenshi_combine", mLog)
    end
end

function CItemHandler:WashShenShi(oPlayer, iItemId, locks, iFlag)
    local oItem = oPlayer:HasItem(iItemId)
    if not oItem or oItem:ItemType() ~= "wenshi" then return end

    if oItem:GetLast() <= 0 then
        oPlayer:NotifyMessage(self:GetTextData(1066))
        return
    end

    locks = locks or {}
    local iAttrCnt = oItem:GetAttrCnt()
    local lWashIndex = {}
    for iIdx = 1, iAttrCnt do
        if not table_in_list(locks, iIdx) then
            table.insert(lWashIndex, iIdx)
        end
    end

    local mConfig = oItem:GetGradeConfig()
    local iLockCnt = iAttrCnt - #lWashIndex
    if iLockCnt > mConfig["wash_lock_cnt"] then
        oPlayer:NotifyMessage(self:GetTextData(1062))
        return
    end

    local iGoldCoin = 0
    if iLockCnt > 0 then
        iGoldCoin = formula_string(mConfig["wash_lock_cost"], {}) * iLockCnt
    end

    local mCost = oItem:GetWashCost()
    assert(mCost, string.format("wenshi wash cost error %s", oItem:SID()))
    if iFlag and iFlag > 0 then
        local mNeedCost = {}
        mNeedCost["item"] = {}
        for iSid, iCnt in pairs(mCost) do
            mNeedCost["item"][iSid] = iCnt
        end
        if iGoldCoin > 0 then
            mNeedCost["goldcoin"] = iGoldCoin 
        end

        local bSucc, mTrueCost = global.oFastBuyMgr:FastBuy(oPlayer, mNeedCost, "纹饰洗练", {cancel_tip = true})
        if not bSucc then return end
    else
        for iSid, iCnt in pairs(mCost) do
            if oPlayer:GetItemAmount(iSid) < iCnt then
                oPlayer:NotifyMessage(self:GetTextData(1064))
                return
            end
        end

        if iGoldCoin > 0 then
            if not oPlayer:ValidGoldCoin(iGoldCoin) then return end
            
            oPlayer:ResumeGoldCoin(iGoldCoin, "纹饰洗练")
        end
        for iSid, iCnt in pairs(mCost) do
            oPlayer:RemoveItemAmount(iSid, iCnt, "纹饰洗练")
        end
    end

    oItem:WashAttr(lWashIndex)
    oItem:Bind(oPlayer:GetPid())
    oPlayer.m_oItemCtrl:GS2CAddItem(oItem, {refresh=1})
    oPlayer:NotifyMessage(self:GetTextData(1063))

    local mLog = oPlayer:LogData()
    mLog["item"] = {sid=oItem:SID()}
    mLog["goldcoin"] = iGoldCoin
    record.user("item", "wenshi_wash", mLog)
end
---------------------wenshi----------------------------



