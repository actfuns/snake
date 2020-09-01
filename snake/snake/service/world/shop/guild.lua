local global = require "global"
local res = require "base.res"
local interactive = require "base.interactive"
local record = require "public.record"

local datactrl = import(lualib_path("public.datactrl"))
local operator = import(service_path("shop.operator"))
local gamedb = import(lualib_path("public.gamedb"))

function NewGuildObj(...)
    local o = CGuild:New(...)
    return o
end


CGuild = {}
CGuild.__index = CGuild
inherit(CGuild, datactrl.CDataCtrl)

function CGuild:New(...)
    local o = super(CGuild).New(self)
    o.m_sName = "guild"
    o.m_sShowName = "商会"
    o:Init()
    return o
end

function CGuild:Init()
    self.m_oOperator = operator.NewOperatorObj(self)
    self.m_mCatalog = {}
    self.m_mSidToGoodId = {}
end

function CGuild:InitCatalog()
    local oWorldMgr = global.oWorldMgr
    local iSLV = oWorldMgr:GetServerGrade()
    local mData = res["daobiao"][self.m_sName]
    local mSlv2Item = mData["slv2item"]

    for iLv, lItem in pairs(mSlv2Item) do
        if iLv > iSLV then
            goto continue
        end
        for _, iGood in ipairs(lItem) do
            local mItem = self:GetDataByGoodId(iGood)
            if mItem then
                local oProxyItem = self:CreateProxyItem(mItem.item_sid, iGood)
                self:Insert2Catalog(oProxyItem)
            end
        end
        ::continue::
    end
end

function CGuild:CreateProxyItem(iSid, iGood)
    local oItem = global.oItemLoader:GetItem(iSid)
    local oProxyItem = NewProxyItem(oItem, iGood)
    return oProxyItem
end

function CGuild:Insert2Catalog(oProxyItem)
    local mData = oProxyItem:GetTableData()
    local iGood = oProxyItem:GoodId()
    assert(mData, string.format("guild shop %d is empty", iGood))

    local iCat, iSub = mData.cat_id, mData.sub_id
    if not self.m_mCatalog[iCat] then
        self.m_mCatalog[iCat] = {}
    end
    if not self.m_mCatalog[iCat][iSub] then
        self.m_mCatalog[iCat][iSub] = {}
    end
    self.m_mCatalog[iCat][iSub][iGood] = oProxyItem

    local iKey = self:PackGoodKey(oProxyItem)
    self.m_mSidToGoodId[iKey] = iGood
    self:Dirty()
end

function CGuild:GetItem(iGood)
    local mItem = self:GetDataByGoodId(iGood)
    assert(mItem, string.format("guild shop %d is empty", iGood))
    local iCat, iSub = mItem.cat_id, mItem.sub_id
    return table_get_depth(self.m_mCatalog, {iCat, iSub, iGood})
end

function CGuild:GetItemGoodId(iTrueSid)
    local mData = res["daobiao"][self.m_sName]["sid2good"]
    if not mData then return 0 end

    local iGood = mData[iTrueSid]
    return iGood or 0
end

function CGuild:GetItemPrice(iTrueSid)
    local mData = res["daobiao"][self.m_sName]["sid2good"]
    if not mData then return 0 end

    local iGood = mData[iTrueSid]
    if not iGood then return 0 end
    
    local oProxy = self:GetItem(iGood)
    if oProxy then return oProxy:GetPrice() end

    local mItem = self:GetDataByGoodId(iGood)
    if mItem.refer and mItem.refer > 0 then
        local oRefer = self:GetItem(mItem.refer)
        if oRefer then
            local iPrice = math.max(mItem.base_price, oRefer:GetPrice())
            return math.floor(iPrice)
        end
    end
    return mItem.base_price
end

function CGuild:SendItemPrice(oPlayer, iGood)
    local oProxyItem = self:GetItem(iGood)
    local iPrice = 0
    if oProxyItem then
        iPrice = oProxyItem:GetPrice()
    else
        local mItem = self:GetDataByGoodId(iGood)
        iPrice = mItem.base_price
    end
    local mNet = {good_id = iGood, price=iPrice}
    oPlayer:Send("GS2CGuildItemPrice", mNet)
end

--------------inherit function------------

function CGuild:GetName()
    return self.m_sName
end

function CGuild:Release()
    baseobj_safe_release(self.m_oOperator)
    self.m_mCatalog = {}
    super(CGuild).Release(self)
end

function CGuild:Save()
    --方便调整目录位置且保留所有数据
    local mData = {}
    for iCat, mCat in pairs(self.m_mCatalog) do
        for iSub, mSub in pairs(mCat) do
            for iGood, oProxyItem in pairs(mSub) do
                local sGood = db_key(iGood)
                mData[sGood] = oProxyItem:Save()
            end
        end
    end
    return mData
end

function CGuild:Load(m)
    for sGood, mItem in pairs(m or {}) do
        local iGood = tonumber(sGood)
        local oProxyItem = self:GetItem(iGood)
        if oProxyItem then
            oProxyItem:Load(mItem)
        else
            local mData = self:GetDataByGoodId(iGood)
            if not mData then goto continue end

            oProxyItem = self:CreateProxyItem(mData.item_sid, iGood)
            oProxyItem:Load(mItem)
            self:Insert2Catalog(oProxyItem)
            ::continue::
        end
    end
end

function CGuild:MergeFrom(mFrom)
    return true
end

function CGuild:NewHour(mNow)
    for iCat, mCat in pairs(self.m_mCatalog) do
        for iSub, mSub in pairs(mCat) do
            for iGood, oProxyItem in pairs(mSub) do
                oProxyItem:NewHour(mNow)
            end
        end
    end
end

function CGuild:OnUpServerGrade(iGrade, iOldGrade)
    --TODO 存在一份等级对应物品的映射表
    local mData = res["daobiao"][self.m_sName]
    for i = iOldGrade, iGrade do
        local mSlv2Item = mData["slv2item"][i]
        if mSlv2Item then
            for idx, iGood in ipairs(mSlv2Item) do
                local mItem = self:GetDataByGoodId(iGood)
                local oProxyItem = self:CreateProxyItem(mItem.item_sid, iGood)
                safe_call(oProxyItem.CheckReferPrice, oProxyItem)
                self:Insert2Catalog(oProxyItem)
            end
        end
    end
end

function CGuild:GetData()
    local mData = res["daobiao"][self.m_sName]
    return mData["iteminfo"]
end

function CGuild:GetDataByGoodId(iGood)
    local mAllItem = self:GetData()
    return mAllItem[iGood]
end

function CGuild:PackGoodKey(oItem)
    return oItem:SID()
end

function CGuild:TransToGoodId(oItem)
    if not oItem then return end

    local iKey = self:PackGoodKey(oItem) 
    return self.m_mSidToGoodId[iKey]
end

--------------save and load data----------
function CGuild:SaveDb()
    if not self:IsLoaded() then return end
    if not self:IsDirty() then return end
    
    local mInfo = {
        module = "guild",
        cmd = "SaveGuildData",
        cond = {name = self.m_sName},
        data = {data = self:Save()},
    }
    gamedb.SaveDb("guild", "common", "DbOperate", mInfo)
    self:UnDirty()
end

function CGuild:LoadDb()
    local mInfo = {
        module = "guild",
        cmd = "LoadGuildData",
        cond = {name = self.m_sName},
    }
    gamedb.LoadDb("guild", "common", "DbOperate", mInfo,
    function(mRecord, mData)
        if not self:IsLoaded() then
            self:Load(mData.data)
            self:OnLoaded()
        end
    end)
end

function CGuild:ConfigSaveFunc()
    self:ApplySave(function ()
        local obj = global.oGuild
        if obj then
            obj:_CheckSaveDb()
        else
            record.warning("guild save err: no obj")
        end
    end)
end

function CGuild:_CheckSaveDb()
    assert(not is_release(self), string.format("%s is releasing, save fail", self.m_sShowName))
    assert(self:IsLoaded(), string.format("%s is loading, save fail", self.m_sShowName))
    self:SaveDb()
end



function NewProxyItem(...)
    local o = CProxyItem:New(...)
    return o
end

CProxyItem = {}
CProxyItem.__index = CProxyItem
inherit(CProxyItem, datactrl.CDataCtrl)

function CProxyItem:New(oItem, iGood)
    local o = super(CProxyItem).New(self)
    o.m_oDataCtrl = oItem
    o.m_iGood = iGood
    o:Init()
    return o
end

function CProxyItem:Init()
    self:InitPrice()
    self:DoStubDayPrice()
    self:InitAmount()
end

function CProxyItem:SID()
    return self.m_oDataCtrl:SID()
end

function CProxyItem:Name()
    return self.m_oDataCtrl:Name()
end

function CProxyItem:GoodId()
    return self.m_iGood
end

function CProxyItem:InitPrice()
    local mItem = self:GetTableData()
    local iPrice = mItem.base_price
    self:SetPrice(iPrice)
    self:SetLastPrice(iPrice)
end

function CProxyItem:CheckReferPrice()
    local iRefer = self:GetTableAttr("refer")
    if not iRefer or iRefer <= 0 then return end

    local oReferItem = self:GetItem(iRefer)
    if not oReferItem then return end

    local iReferPrice = oReferItem:GetPrice()
    if self:GetPrice() < iReferPrice then
        local iSetPrice = math.floor(iReferPrice * 105 / 100)
        self:SetPrice(iSetPrice)
        self:SetLastPrice(iSetPrice)
    end
end

function CProxyItem:InitAmount()
    local mItem = self:GetTableData()
    self:SetData("amount", mItem.amount)
    self:Dirty()
end

function CProxyItem:GetAmount()
    return self:GetData("amount", 0)
end

function CProxyItem:AddAmount(iAdd)
    local iOldAmount = self:GetAmount()
    local iAmount = math.max(0, iOldAmount + iAdd)
    self:SetData("amount", iAmount)
    self:Dirty()
end

function CProxyItem:GetMaxAmount()
    return self.m_oDataCtrl:GetMaxAmount()
end

function CProxyItem:SetPrice(iPrice)
    local iMinPrice = self:GetTableAttr("min_price")
    local iMaxPrice = self:GetTableAttr("max_price")
    self:SetData("price", math.min(iMaxPrice, math.max(iPrice, iMinPrice)))
    self:Dirty()
end

function CProxyItem:GetPrice()
    return math.floor(self:GetData("price", 0))
end

function CProxyItem:GetTruePrice()
    return self:GetData("price", 0)
end

function CProxyItem:SetLastPrice(iPrice)
    --行情价
    self:SetData("last_price", iPrice)
    self:Dirty()
end

function CProxyItem:GetLastPrice()
    return math.floor(self:GetData("last_price", 0))
end

function CProxyItem:SetUpFlag(iFlag)
    self:SetData("up_flag", iFlag)
    self:Dirty()
end

function CProxyItem:GetUpFlag()
    return self:GetData("up_flag", 0)
end

function CProxyItem:GetDayForbidBuyyingPrice()
    local dRatioLimit = self:GetTableAttr("ratio_limit")
    if dRatioLimit == 0 then
        return true,0
    else
        return false,self:GetData("last_price") * dRatioLimit 
    end
end

function CProxyItem:NewHour(mNow)
    local iHour = mNow.date.hour
    if iHour == 5 then
        self:DoStubDayPrice()
        if self:GetTableAttr("amount") >= 999999 then
            self:InitAmount()
        end
    end
    self:TrySupplyAmount()
end

function CProxyItem:TrySupplyAmount()
    if self:GetTableAttr("amount") < 999999 then
        if self:GetAmount() > 0 then
            return
        end
        if math.random(2) == 1 then
            self:AddAmount(1)
        end
    end
end

function CProxyItem:DoStubDayPrice()
    local iPrice = self:GetPrice()
    self:SetData("last_price", iPrice)
    self:SetData("up_flag", 0)
    self:Dirty()
end

function CProxyItem:GetTableAttr(sKey)
    local mData = self:GetTableData()
    return mData[sKey]
end

function CProxyItem:GetTableData(iGood)
    local mData = res["daobiao"]["guild"]
    iGood = iGood or self:GoodId()
    return mData["iteminfo"][iGood]
end

function CProxyItem:GetItem(iGood)
    local mItem = self:GetTableData(iGood)

    local iCat, iSub = mItem.cat_id, mItem.sub_id
    local oGuild = global.oGuild
    return table_get_depth(oGuild.m_mCatalog, {iCat, iSub, iGood})
end

function CProxyItem:Save()
    local mData = {}
    mData.data = self.m_mData
    return mData
end

function CProxyItem:Load(m)
    if not m then return end
    self.m_mData = m.data
end

function CProxyItem:Dirty()
    local oGuild = global.oGuild
    if oGuild then
        oGuild:Dirty()
    end
end
