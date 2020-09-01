local global = require "global"
local skynet = require "skynet"

local datactrl = import(lualib_path("public.datactrl"))


function NewItem(sid)
    local o = CItem:New(sid)
    return o
end

CItem = {}
CItem.__index = CItem
inherit(CItem,datactrl.CDataCtrl)

function CItem:New(sid)
    local o = super(CItem).New(self)
    o.m_SID = sid
    return o
end

function CItem:Init(mSaveData)
    assert(mSaveData,string.format("%s init error",self.m_SID))
    assert(mSaveData["sid"],string.format("%s init sid error",self.m_SID))
    assert(mSaveData["amount"],string.format("%s init amount error",self.m_SID))
    assert(mSaveData["create_time"],string.format("%s init create_time error",self.m_SID))
    self.m_ID = self:DispatchItemID()
    self.m_SaveData = mSaveData
    self.m_mData = self.m_SaveData["data"] or {}
    self.m_SID = self.m_SaveData["sid"]
end

function CItem:Load(mData)
    if not mData then
        return
    end
    self:Init(mData)
end

function CItem:Save()
    self.m_SaveData["data"] = self.m_mData or {}
    return self.m_SaveData
end

function CItem:GetItemData()
    local res = require "base.res"
    local mData = res["daobiao"]["item"]
    local mItemData = mData[self.m_SID]
    assert(mItemData,string.format("itembase GetItemData err:%s",self.m_SID))
    return mItemData
end

function CItem:DispatchItemID()
    local oWorldMgr = global.oWorldMgr
    return oWorldMgr:DispatchItemID()
end

function CItem:ID()
    return self.m_ID
end

function CItem:SID()
    return self.m_SID
end

function CItem:GetOwner()
    if self.m_Container then
        return self.m_Container:GetOwner()
    end
end

function CItem:Shape()
    return self.m_SID
end

function CItem:Name()
    return self:GetItemData()["name"]
end

function CItem:SalePrice()
    return self:GetItemData()["salePrice"] or 0
end

function CItem:Quality()
    local iQuality = self:GetData("equip_level")
    if iQuality then
        return iQuality
    end
    return self:GetData("quality") or 1
end

function CItem:IsBind()
    if self:GetData("Bind",0) ~= 0 then
        return true
    end
    return false
end

function CItem:Validate()
    local iTime = self:GetData("Time", 0)
    if iTime > 0 and iTime <= get_time() then
        return false
    end
    return true
end

function CItem:IsTimeItem()
    if self:GetData("Time",0) ~= 0 then
        return true
    end
    return false
end

function CItem:IsGuildItem()
    return self:GetData("guild_buy_price", 0) > 0
end

function CItem:IsStallItem()
    return self:GetData("stall_buy_price", 0) > 0
end

function CItem:GetAmount()
    return self.m_SaveData["amount"]
end

function CItem:SetAmount(iAmount)
    assert(iAmount>=0,string.format("%s %s %s setamount error",self:GetOwner(),self.m_SID,self.m_ID))
    self:Dirty()
    self.m_SaveData["amount"] = iAmount
    if self.m_SaveData["amount"] <= 0 then
        if self:GetOwner() then
            self.m_Container:RemoveItem(self)
        end
    else
        if self:GetOwner() then
            self.m_Container:GS2CRefreshTempItem(self)
        end
    end
end

function CItem:GetMaxAmount()
    return self:GetItemData()["maxOverlay"]
end

function CItem:AddAmount(iAmount)
    assert(iAmount and iAmount ~= 0, string.format("Item:AddAmount amount error: amount:%s", iAmount))
    local iAmount  = self:GetAmount() + iAmount
    self:SetAmount(iAmount)
end

function CItem:CombineKey()
    local iKey = 0
    iKey = self:IsBind() and iKey + 10 or iKey
    iKey = self:IsTimeItem() and iKey + 100 or iKey
    iKey = self:IsGuildItem() and iKey + 1000 or iKey
    iKey = iKey + 10000 * self:Quality()
    return iKey
end

function CItem:ValidCombine(oSrcItem)
    if self:IsBind() ~= oSrcItem:IsBind() then
        return false
    end
    if self:IsTimeItem() or oSrcItem:IsTimeItem() then
        return false
    end
    if self:IsGuildItem() ~= oSrcItem:IsGuildItem() then
        return false
    end
    if self:Quality() ~= oSrcItem:Quality() then
        return false
    end
    return true
end

function CItem:AfterCombine(mSaveData)
    local iGuildBuyPrice = table_get_depth(mSaveData, {"data", "guild_buy_price"})
    if iGuildBuyPrice then
        self:SetData("guild_buy_price", iGuildBuyPrice)
    end
    local iStallBuyPrice = table_get_depth(mSaveData, {"data", "stall_buy_price"})
    if iStallBuyPrice then
        self:SetData("stall_buy_price", iStallBuyPrice)
    end
end

function CItem:PackInfo()
    local mNet = {}
    mNet.id = self.m_ID
    mNet.sid = self.m_SID
    mNet.pos = self.m_Pos
    mNet.amount = self:GetAmount()
    --mNet.quality = self:Quality()
    return mNet
end
