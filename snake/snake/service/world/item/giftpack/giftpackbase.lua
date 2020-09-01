local global = require "global"
local res = require "base.res"

local itembase = import(service_path("item/itembase"))

local ERR = {
    LACK_POS = 1,
    NO_OPEN_FUNC = 2,
    HASNOT_CHOOSE = 3,
    CONFIG_ERR = 4,
    CHOICE_ERR = 5,
    INVALID_CHOICE = 6,
    INVALID_GRADE = 7,
}

GIFT_PACK_TYPE = {
    AUTO_RANDOM = 1,
    MANU_CHOOSE = 2,
}

GIFT_TYPE_OPEN_FUNC = {
    [GIFT_PACK_TYPE.AUTO_RANDOM] = "OpenAutoRandom",
    [GIFT_PACK_TYPE.MANU_CHOOSE] = "OpenManuChoose",
}

CItem = {}
CItem.__index = CItem
inherit(CItem, itembase.CItem)
CItem.m_ItemType = "giftpack"

function NewItem(sid)
    local o = CItem:New(sid)
    return o
end

function CItem:ValidUnpack(oPlayer)
    local iNeedPos = self:GetItemData()["needpos"]
    local iHasPos = oPlayer.m_oItemCtrl:GetCanUseSpaceSize()
    if iNeedPos > iHasPos then
        return ERR.LACK_POS, iNeedPos
    end
    local iMinGrade = self:GetItemData()["minGrade"]
    if oPlayer:GetGrade() < iMinGrade then
        return ERR.INVALID_GRADE, iMinGrade
    end
end

function CItem:GetItemRewardConfig(iItemIdx)
    local mItemConfig = table_get_depth(res, {"daobiao", "reward", "giftpack", "itemreward", iItemIdx})
    return mItemConfig
end

function CItem:GetGiftPackType()
    return self:GetItemData()["gift_type"]
end

function CItem:GetGiftPackItemIdxes()
    return self:GetItemData()["gift_items"]
end

function CItem:NotifyErr(oPlayer, iErr, xInfoData)
    local sMsg = "无法打开"
    if iErr == ERR.LACK_POS then
        if type(xInfoData) == "number" then
            sMsg = string.format("背包空间不足，需要%d个空位", xInfoData)
        else
            sMsg = "背包空间不足"
        end
    elseif iErr == ERR.NO_OPEN_FUNC then
        sMsg = "错误的礼包类型"
    elseif iErr == ERR.HASNOT_CHOOSE then
        sMsg = "还未选择获得物品"
    elseif iErr == ERR.CONFIG_ERR then
        sMsg = "礼包错误，无法打开"
    elseif iErr == ERR.CHOICE_ERR then
        sMsg = "选择有误"
    elseif iErr == ERR.INVALID_CHOICE then
        sMsg = "你不能获得此物品"
    elseif iErr == ERR.INVALID_GRADE then
        sMsg = global.oToolMgr:GetSystemText({"itemtext"}, 1033, {level=xInfoData})
    end
    oPlayer:NotifyMessage(sMsg)
end

function CItem:TrueUse(oPlayer, iTarget, iCostAmount, mArgs)
    local iPid = oPlayer:GetPid()
    local iErr, xInfoData = self:ValidUnpack(oPlayer)
    if iErr then
        self:NotifyErr(oPlayer, iErr, xInfoData)
        return
    end
    local fOpenFunc = self:GetOpenFunc()
    if not fOpenFunc then
        self:NotifyErr(oPlayer, ERR.NO_OPEN_FUNC)
        return
    end
    local iCostAmount = self:GetUseCostAmount()
    local mAllItems, iErr = fOpenFunc(self, oPlayer, iTarget, mArgs.exarg)
    if not mAllItems or not next(mAllItems) then
        self:NotifyErr(oPlayer, iErr)
        return
    end
    self:GS2CConsumeMsg(oPlayer, iCostAmount)
    oPlayer:RemoveOneItemAmount(self, iCostAmount, "itemuse", {cancel_chat = true})
    global.oRewardMgr:RewardItemsByGroup(oPlayer, "giftpack", mAllItems)
    return true
end

function CItem:GetOpenFunc()
    return self[GIFT_TYPE_OPEN_FUNC[self:GetGiftPackType()]]
end

function CItem:OpenAutoRandom(oPlayer)
    local lItemIdxes = self:GetGiftPackItemIdxes()
    local mAllItems = global.oRewardMgr:InitRewardItemListByGroup(oPlayer, "giftpack", lItemIdxes)
    return mAllItems
end

-- PS：暂时设定只能取1组物品(单选)
function CItem:OpenManuChoose(oPlayer, iTarget, sExArg)
    local iChooseIdx = tonumber(sExArg)
    if not iChooseIdx then
        return nil, ERR.HASNOT_CHOOSE
    end
    local lItemIdxes = self:GetGiftPackItemIdxes()
    local iItemIdx = lItemIdxes[1]
    -- 手选礼包必定只有一件奖品
    if not iItemIdx then
        return nil, ERR.CONFIG_ERR
    end
    local mItemConfig = self:GetItemRewardConfig(iItemIdx)
    if not mItemConfig then
        return nil, ERR.CONFIG_ERR
    end
    local mItemUnit = mItemConfig[iChooseIdx]
    if not mItemUnit then
        return nil, ERR.CHOICE_ERR
    end
    local mAllItems = {}
    local mItems = global.oRewardMgr:InitRewardByItemUnit(oPlayer, iItemIdx, mItemUnit)
    if mItems then
        mAllItems[iItemIdx] = mItems
    end
    return mAllItems
end
