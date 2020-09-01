local extend = require "base.extend"

local defines = import(service_path("stall.defines"))


---------------目录管理------------
function NewCatalogMgr(...)
    local o = CCatalogMgr:New(...)
    return o
end

CCatalogMgr = {}
CCatalogMgr.__index = CCatalogMgr
inherit(CCatalogMgr, logic_base_cls())

function CCatalogMgr:New(...)
    local o = super(CCatalogMgr).New(self)
    o:Init()
    return o
end

function CCatalogMgr:Init()
    self.m_mCatalog = {}
end

function CCatalogMgr:AddProxyItem(oProxyItem)
    local iCat = oProxyItem:GetCatalogId()
    local iSub = oProxyItem:QueryIdx()
    local iOwner = oProxyItem:GetOwner()
    local iPos = oProxyItem:GetPos()
    local iKey = self:EncodeKey(iOwner, iPos)
    
    local mInfo = table_get_set_depth(self.m_mCatalog, {iCat, iSub})
    mInfo[iKey] = oProxyItem
end

function CCatalogMgr:EncodeKey(iPid, iPos)
    return defines.EncodeKey(iPid, iPos)
end

function CCatalogMgr:DecodeKey(iKey)
    return defines.DecodeKey(iKey)
end

function CCatalogMgr:RemoveProxyItem(oProxyItem)
    local iCat = oProxyItem:GetCatalogId()
    local iSub = oProxyItem:QueryIdx()
    local iOwner = oProxyItem:GetOwner()
    local iPos = oProxyItem:GetPos()
    local iKey = self:EncodeKey(iOwner, iPos)

    local mInfo = table_get_set_depth(self.m_mCatalog, {iCat, iSub})
    mInfo[iKey] = nil
end
   
function CCatalogMgr:GetCatalog(iCat)
    return self.m_mCatalog[iCat]
end

function CCatalogMgr:GetSubCatalog(iCat, iSub)
    local mCatalog = self:GetCatalog(iCat)
    if not mCatalog then return end
    return mCatalog[iSub]
end

function CCatalogMgr:GetProxyItem(iCat, iSub, iKey)
    local mInfo = table_get_set_depth(self.m_mCatalog, {iCat, iSub})
    return mInfo[iKey]
end

function CCatalogMgr:ChooseStallItem(lFilter, iCat, iSub, iAmount)
    local mInfo = table_get_set_depth(self.m_mCatalog, {iCat, iSub})
    local lKeyList = self:FilterItem(lFilter, iCat, iSub)
    local lSelect = extend.Random.random_size(lKeyList, iAmount)
    local lResult = {}
    for idx, iKey in pairs(lSelect or {}) do
        table.insert(lResult, mInfo[iKey])
    end
    return lResult
end

function CCatalogMgr:FilterItem(lFilter, iCat, iSub)
    local mTmp = {}
    for _, v in ipairs(lFilter) do
        mTmp[v] = 1
    end

    local lResult = {}
    local iCurrTime = get_time()
    local mInfo = table_get_set_depth(self.m_mCatalog, {iCat, iSub})
    for iKey, oItem in pairs(mInfo) do
        if not oItem or oItem:GetAmount() <= 0 then
            goto continue
        end
        if get_time() < oItem:GetSellStart() then
            goto continue
        end
        if mTmp[iKey] then goto continue end

        if oItem:GetSellTime() + defines.GetKeepTime() <= iCurrTime then
            goto continue
        end

        table.insert(lResult, iKey)
        ::continue::
    end
    return lResult
end

