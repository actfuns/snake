local global = require "global"
local res = require "base.res"

local datactrl = import(lualib_path("public.datactrl"))
local itembase = import(service_path("item.itembase"))
local defines = import(service_path("stall.defines"))


function NewItemObj(...)
    local o = CProxyItem:New(...)
    o:Init()
    return o
end

CProxyItem = {}
CProxyItem.__index = CProxyItem
inherit(CProxyItem, datactrl.CDataCtrl)

function CProxyItem:New(id, obj)
    local o = super(CProxyItem).New(self)
    o.m_ID = id
    o.m_oDataCtrl = obj
    return o
end

function CProxyItem:Init()
    self.m_iSellTime = get_time()
    self.m_iPrice = 0
    self.m_iPos = 0
    self.m_iOwner = 0
    self.m_iAmount = 0
    self.m_iSellStart = get_time()
end

function CProxyItem:Load(m)
    if not m then return end
    self.m_oDataCtrl:Load(m.datactrl or {})
    self.m_iSellTime = m.sell_time or get_time()
    self.m_iPrice = m.price
    self.m_iPos = m.pos
    self.m_iOwner = m.owner
    self.m_iAmount = m.amount
    self.m_iIdentify = m.identify
    self.m_iSellStart = m.sellstart or get_time()
end

function CProxyItem:Save()
    local mData = {}
    mData.datactrl = self.m_oDataCtrl:Save()
    mData.sell_time = self.m_iSellTime
    mData.price = self.m_iPrice
    mData.pos = self.m_iPos
    mData.owner = self.m_iOwner
    mData.amount = self.m_iAmount
    mData.identify = self.m_iIdentify
    mData.sellstart = self.m_iSellStart
    return mData
end

function CProxyItem:SID()
    return self.m_oDataCtrl:SID()
end

function CProxyItem:ItemBaseData()
    return table_deep_copy(self.m_oDataCtrl:Save())
end

function CProxyItem:SetOwner(iOwner)
    self.m_iOwner = iOwner
    self:Dirty()
end

function CProxyItem:GetOwner()
    return self.m_iOwner
end

function CProxyItem:SetSellTime(iTime)
    self.m_iSellTime = iTime or get_time()
    self:Dirty()
end

function CProxyItem:GetSellTime()
    return self.m_iSellTime
end

function CProxyItem:SetSellStart(iTime)
    self.m_iSellStart = get_time() + iTime
    self:Dirty()
end

function CProxyItem:GetSellStart()
    return self.m_iSellStart or get_time()
end

function CProxyItem:SetPrice(iPrice)
    local iMinPrice = self:GetTableAttr("min_price")
    local iMaxPrice = self:GetTableAttr("max_price")
    self.m_iPrice = math.min(iMaxPrice, math.max(iPrice, iMinPrice))
    self:Dirty()
end

function CProxyItem:GetPrice()
    return self.m_iPrice
end

function CProxyItem:SetPos(iPos)
    self.m_iPos = iPos
    self:Dirty()
end

function CProxyItem:GetPos(iPos)
    return self.m_iPos
end

function CProxyItem:SetIdentify(iIdentify)
    self.m_iIdentify = iIdentify
    self:Dirty()
end

function CProxyItem:GetIdentify()
    return self.m_iIdentify
end

function CProxyItem:Dirty()
    if self.m_iOwner and self.m_iOwner > 0 then
        local oStallMgr = global.oStallMgr
        local oStall = oStallMgr:GetStallObj(self.m_iOwner)
        oStall:Dirty()
    end
end

function CProxyItem:AddAmount(iAmount, sReason, mArgs)
    self:Dirty()
    self.m_iAmount = self.m_iAmount + iAmount
end

function CProxyItem:SetAmount(iAmount)
    self.m_iAmount = iAmount
end

function CProxyItem:GetAmount()
    return self.m_iAmount
end

function CProxyItem:Release()
    if self.m_bNeedRelease then
        baseobj_safe_release(self.m_oDataCtrl)
    end
    super(CProxyItem).Release(self)
end

function CProxyItem:Status()
    if self.m_iAmount < 1 then
        return defines.ITEM_STATUS_EMPTY
    end
    if self.m_iIdentify then
        local iSeller, iPos = defines.DecodeKey(self.m_iIdentify)
        local oStall = self:GetStallObj()
        local oItem = oStall:GetSellItem(iPos)
        if not oItem then
            return defines.ITEM_STATUS_OVERTIME
        end
        if oItem:GetSellTime() ~= self:GetSellTime() then
            return defines.ITEM_STATUS_OVERTIME
        end
        if self:GetSellTime() + defines.GetKeepTime() < get_time() then
            return defines.ITEM_STATUS_OVERTIME
        end
    end
    return defines.ITEM_STATUS_NORMAL
end

function CProxyItem:ItemType()
    return self.m_oDataCtrl:ItemType()
end

function CProxyItem:Quality()
    --local sType = self:ItemType()
    --if sType == "cook" or sType == "medicine" then
    local iSid = self:SID()
    if (10046<=iSid and iSid<=10050) or (10058<=iSid and iSid<=10064) then
        return self:TrueQuality()
    end
    if defines.FUZHUAN[iSid] then
        return self.m_oDataCtrl:GetData("skill_level", 1) * 10
    end
    return 1
end

function CProxyItem:QueryIdx()
    return defines.EncodeSid(self:SID(), self:Quality())
end

function CProxyItem:TrueQuality()
    return self.m_oDataCtrl:Quality()
end

function CProxyItem:GetPlayer()
    local oWorldMgr = global.oWorldMgr
    return oWorldMgr:GetOnlinePlayerByPid(self:GetOwner())
end

function CProxyItem:GetStallObj()
    local iOwner = self:GetOwner()
    if not iOwner then return end

    local oStallMgr = global.oStallMgr
    return oStallMgr:GetStallObj(iOwner)
end

function CProxyItem:GetCatalogObj()
    local iOwner = self:GetOwner()
    if not iOwner then return end

    local oCatalogMgr = global.oCatalogMgr
    return oCatalogMgr:GetCatalogByPid(iOwner)
end

function CProxyItem:GetCatalogId()
    local mInfo = res["daobiao"]["stall"]["iteminfo"]
    if not mInfo[self:QueryIdx()] then
        return 0
    end
    return mInfo[self:QueryIdx()].cat_id
end

function CProxyItem:GetTableAttr(sAttr)
    local mInfo = res["daobiao"]["stall"]["iteminfo"]
    return mInfo[self:QueryIdx()][sAttr]
end


function NewCatalogItem(...)
    local o = CCatalogItem:New(...)
    o:Init()
    return o
end

CCatalogItem = {}
CCatalogItem.__index = CCatalogItem
inherit(CCatalogItem, CProxyItem)

function CCatalogItem:Dirty()
    return
end
