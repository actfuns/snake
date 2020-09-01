--import module

local global = require "global"
local skynet = require "skynet"

local pfload = import(service_path("perform/pfload"))

function NewPerformMgr(...)
    local o = CPerformMgr:New(...)
    return o
end

CPerformMgr = {}
CPerformMgr.__index = CPerformMgr
inherit(CPerformMgr, logic_base_cls())

function CPerformMgr:New(iWarId,iWid)
    local o = super(CPerformMgr).New(self)
    o.m_iWarId = iWarId
    o.m_iWid = iWid
    o.m_mPerform = {}

    o.m_mAttrRatio = {}
    o.m_mAttrAdd = {}

    o.m_mAttrs = {}
    o.m_mFunction = {}
    return o
end

function CPerformMgr:Release()
    for _, oPerform in pairs(self.m_mPerform) do
        baseobj_safe_release(oPerform)
    end
    self.m_mPerform = {}
    super(CPerformMgr).Release(self)
end

function CPerformMgr:GetWar()
    local oWarMgr = global.oWarMgr
    return oWarMgr:GetWar(self.m_iWarId)
end

function CPerformMgr:GetWarrior()
    local oWar = self:GetWar()
    return oWar:GetWarrior(self.m_iWid)
end

function CPerformMgr:SetPerform(oAttack, iPerform, mInfo)
    local oPerform = pfload.NewPerform(iPerform)
    assert(oPerform,"perform err:%d",iPerform)

    if type(mInfo) == "number" then
        mInfo = {lv = mInfo}
    end

    local iLevel = mInfo.lv or 1
    oPerform:SetLevel(iLevel)
    local iPriority = mInfo.ratio
    if iPriority and iPriority >= 0 then
        oPerform:SetPriority(iPriority)
    end
    local iAITarget = mInfo.ai_target
    if iAITarget and iAITarget > 1 then
        oPerform:SetAITarget(iAITarget)
    end

    oPerform:CalWarrior(oAttack,self)
    self.m_mPerform[iPerform] = oPerform

    if oPerform:IsActive() then
        oAttack.m_iHasPerformType = oAttack.m_iHasPerformType | (1<<oPerform:ActionType())
    end
end

function CPerformMgr:GetPerform(iPerform)
   return self.m_mPerform[iPerform]
end

function CPerformMgr:GetPerformTable()
    return self.m_mPerform or {}
end

function CPerformMgr:GetPerformList()
    local mPerform = {}
    for iPerform,oPerform in pairs(self.m_mPerform) do
        if oPerform:CanPerform() then
            table.insert(mPerform,iPerform)
        end
    end
    return mPerform
end

function CPerformMgr:Query(k,rDefault)
    return self.m_mAttrs[k] or rDefault
end

function CPerformMgr:Add(key,value)
    local v = self.m_mAttrs[key] or 0
    self.m_mAttrs[key] = value + v
end

function CPerformMgr:Set(key,value)
    self.m_mAttrs[key] = value
end

function CPerformMgr:GetAttrBaseRatio(sAttr)
    local mBaseRatio = self.m_mAttrRatio[sAttr] or {}
    local iBaseRatio = 0
    for _,iRatio in pairs(mBaseRatio) do
        iBaseRatio = iBaseRatio + iRatio
    end
    return iBaseRatio
end

function CPerformMgr:SetAttrBaseRatio(sAttr,iPerform,iValue)
    local mBaseRatio = self.m_mAttrRatio[sAttr] or {}
    mBaseRatio[iPerform] = iValue
    self.m_mAttrRatio[sAttr] = mBaseRatio
end

function CPerformMgr:GetAttrAddValue(sAttr)
    local mAddValue = self.m_mAttrAdd[sAttr] or {}
    local iAddValue = 0
    for _,iValue in pairs(mAddValue) do
        iAddValue = iAddValue + iValue
    end
    return iAddValue
end

function CPerformMgr:SetAttrAddValue(sAttr,iPerform,iValue)
    local mAddValue = self.m_mAttrAdd[sAttr] or {}
    mAddValue[iPerform] = iValue
    self.m_mAttrAdd[sAttr] = mAddValue
end

function CPerformMgr:AddAttrAddValue(sAttr, iPerform, iValue)
    local mAddValue = self.m_mAttrAdd[sAttr] or {}
    if not mAddValue[iPerform] then
        mAddValue[iPerform] = 0
    end
    mAddValue[iPerform] = mAddValue[iPerform] + iValue
    self.m_mAttrAdd[sAttr] = mAddValue
end

function CPerformMgr:AddFunction(sKey,iNo,fCallback)
    local mFunction = self.m_mFunction[sKey] or {}
    mFunction[iNo] = fCallback
    self.m_mFunction[sKey] = mFunction
end

function CPerformMgr:GetFunction(sKey)
    return self.m_mFunction[sKey] or {}
end

function CPerformMgr:RemoveFunction(sKey,iNo)
    local mFunction = self.m_mFunction[sKey] or {}
    mFunction[iNo] = nil
    self.m_mFunction[sKey] = mFunction
end
