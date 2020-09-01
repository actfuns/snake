--import module

local global = require "global"

-- 所有属性均不存盘

CAttrMgr = {}
CAttrMgr.__index =CAttrMgr
CAttrMgr.m_ApplySumDef = nil
CAttrMgr.m_RatioSumDef = nil
inherit(CAttrMgr,logic_base_cls())

function CAttrMgr:New(iOwner)
    local o = super(CAttrMgr).New(self)
    o.m_ID = iOwner
    o.m_mApply = {}
    o.m_mRatioApply = {}
    return o
end

function CAttrMgr:SetSynclSum()
    self.m_SynclSum = true
end

function CAttrMgr:AddApply(sApply,iSource,iValue)
    local mApply = self.m_mApply[sApply] or {}
    local v = mApply[iSource] or 0
    mApply[iSource] = v + iValue
    self.m_mApply[sApply] = mApply
    self:AddlSumAttr(sApply,iValue)
end

function CAttrMgr:GetApply(sApply)
    local mApply = self.m_mApply[sApply] or {}
    local iValue = 0
    for _,v in pairs(mApply) do
        iValue = iValue + v
    end
    return iValue
end

function CAttrMgr:GetApplyBySource(sApply,iSource)
    local mApply = self.m_mApply[sApply] or {}
    local iValue = 0
    iValue = mApply[iSource] or iValue
    return iValue
end

function CAttrMgr:ClearApply()
    self.m_mApply = {}
    self:ClearSumAttr()
end

function CAttrMgr:AddRatioApply(sApply,iSource,iValue)
    local mRatioApply = self.m_mRatioApply[sApply] or {}
    local v = mRatioApply[iSource] or 0
    mRatioApply[iSource] = v + iValue
    self.m_mRatioApply[sApply] = mRatioApply
    self:AddlSumAttrRatio(sApply,iValue)
end

function CAttrMgr:GetRatioApplyBySource(sApply, iSource)
    return table_get_depth(self.m_mRatioApply, {sApply, iSource})
end

function CAttrMgr:GetRatioApply(sApply)
    local mApply = self.m_mRatioApply[sApply] or {}
    local iValue = 0
    for _,v in pairs(mApply) do
        iValue = iValue + v
    end
    return iValue
end

function CAttrMgr:ClearRatioApply()
    self.m_mRatioApply = {}
    self:ClearSumAttrRatio()
end

function CAttrMgr:RemoveSource(iDestSource)
    local mPropChange = {}
    local mDelete = {}
    local iValue
    for sApply,mApply in pairs(self.m_mApply) do
        iValue = mApply[iDestSource] or 0
        mApply[iDestSource] = nil
        if table_count(mApply) <=0 then
            table.insert(mDelete,sApply)
        end
        self:SetlSumAttr(sApply)
        if iValue > 0 then
            mPropChange[sApply] = true
        end
    end
    for _,sApply in ipairs(mDelete) do
        self.m_mApply[sApply] = nil
    end

    mDelete = {}
    for sApply,mRatioApply in pairs(self.m_mRatioApply) do
        iValue = mRatioApply[iDestSource] or 0
        mRatioApply[iDestSource] = nil
        if table_count(mRatioApply) <= 0 then
            table.insert(mDelete,sApply)
        end
        self:SetlSumAttrRatio(sApply)
        if iValue > 0 then
            mPropChange[sApply] = true
        end
    end
    
    for _,sApply in ipairs(mDelete) do
        self.m_mRatioApply[sApply] = nil
    end
    return mPropChange
end

function CAttrMgr:AddlSumAttr(sApply,iValue)
    if not self.m_SynclSum then return end
    assert(self.m_ApplySumDef, "undefined sum module")
    local oPlayer = global.oWorldMgr:GetOnlinePlayerByPid(self.m_ID)
    if not oPlayer then return end
    oPlayer:SynclSumAdd(self.m_ApplySumDef,sApply,iValue)
end

function CAttrMgr:AddlSumAttrRatio(sApply,iValue)
    if not self.m_SynclSum then return end
    assert(self.m_RatioSumDef, "undefined sum module")
    local oPlayer = global.oWorldMgr:GetOnlinePlayerByPid(self.m_ID)
    if not oPlayer then return end
    oPlayer:SynclSumAdd(self.m_RatioSumDef,sApply,iValue)
end

function CAttrMgr:SetlSumAttr(sApply)
    if not self.m_SynclSum then return end
    assert(self.m_ApplySumDef, "undefined sum module")
    local oPlayer = global.oWorldMgr:GetOnlinePlayerByPid(self.m_ID)
    if not oPlayer then return end
    oPlayer:SynclSumSet(self.m_ApplySumDef,sApply,self:GetApply(sApply))
end

function CAttrMgr:SetlSumAttrRatio(sApply)
    if not self.m_SynclSum then return end
    assert(self.m_RatioSumDef, "undefined sum module")
    local oPlayer = global.oWorldMgr:GetOnlinePlayerByPid(self.m_ID)
    if not oPlayer then return end
    oPlayer:SynclSumSet(self.m_RatioSumDef,sApply,self:GetRatioApply(sApply))
end

function CAttrMgr:ClearSumAttr()
    if not self.m_SynclSum then return end
    assert(self.m_ApplySumDef, "undefined sum module")
    local oPlayer = global.oWorldMgr:GetOnlinePlayerByPid(self.m_ID)
    if not oPlayer then return end
    oPlayer:ClearlSum(self.m_ApplySumDef)
end

function CAttrMgr:ClearSumAttrRatio()
    if not self.m_SynclSum then return end
    assert(self.m_RatioSumDef, "undefined sum module")
    local oPlayer = global.oWorldMgr:GetOnlinePlayerByPid(self.m_ID)
    if not oPlayer then return end
    oPlayer:ClearlSum(self.m_RatioSumDef)
end

