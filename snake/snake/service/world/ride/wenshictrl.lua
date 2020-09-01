local global = require "global"
local res = require "base.res"
local record = require "public.record"

local gamedefines = import(lualib_path("public.gamedefines"))
local datactrl = import(lualib_path("public.datactrl"))
local ridedefines = import(service_path("ride.ridedefines"))


function NewWenShiCtrl(...)
    return CWenShiCtrl:New(...)
end


CWenShiCtrl = {}
CWenShiCtrl.__index = CWenShiCtrl
inherit(CWenShiCtrl, datactrl.CDataCtrl)

function CWenShiCtrl:New(iRide, iPid)
    local o = super(CWenShiCtrl).New(self, {ride=iRide, pid=iPid})
    o.m_mPos2WenShi = {}
    o.m_mApply = {}
    o.m_iSkill = 0
    return o
end

function CWenShiCtrl:Release()
    for iPos, oWenShi in pairs(self.m_mPos2WenShi) do
        oWenShi:Release()
    end
    self.m_mPos2WenShi = {}
    super(CWenShiCtrl).Release(self)
end

function CWenShiCtrl:Load(mData)
    if not mData then return end

    for iPos, data in pairs(mData.wenshi or {}) do
        local oItem = global.oItemLoader:LoadItem(data["sid"],data)
        self.m_mPos2WenShi[iPos] = oItem
    end
    self.m_iSkill = mData.skill or self.m_iSkill
end

function CWenShiCtrl:Save()
    local mData = {}
    local mWenShi = {}
    for iPos, oWenShi in pairs(self.m_mPos2WenShi) do
        mWenShi[iPos] = oWenShi:Save()                        
    end
    mData.wenshi = mWenShi
    mData.skill = self.m_iSkill
    return mData
end

function CWenShiCtrl:Setup()
end

function CWenShiCtrl:GetWenShiByPos(iPos)
    return self.m_mPos2WenShi[iPos]
end

function CWenShiCtrl:GetMaxPos()
    return ridedefines.WENSHI_MAX_POS
end

function CWenShiCtrl:WeildWenShi(oWenShi, iPos)
    assert(iPos <= self:GetMaxPos(), string.format("ride equip pos error %s", iPos))
    self.m_mPos2WenShi[iPos] = oWenShi
    local iSkill = self:GetApplySkill()
    if iSkill then
        self:SetSkill(iSkill)
    end
    self:Dirty()
end

function CWenShiCtrl:UnWeildWenShi(iPos)
    local oWenShi = self.m_mPos2WenShi[iPos]
    if not oWenShi then return end

    baseobj_delay_release(oWenShi)
    self.m_mPos2WenShi[iPos] = nil
    if table_count(self.m_mPos2WenShi) <= 0 then
        self:SetSkill(0)
    end
    self:Dirty()
end

function CWenShiCtrl:ResumeLast(iVal)
    local bRefresh = false
    for _,oWenShi in pairs(self.m_mPos2WenShi) do
        oWenShi:AddLast(-iVal)
        if not bRefresh and oWenShi:GetLast() <= 0 then
            bRefresh = true
        end
    end
    self:Dirty()
    return bRefresh
end

function CWenShiCtrl:GetApplys()
    local mApply = {}
    for _,oWenShi in pairs(self.m_mPos2WenShi) do
        for k,v in pairs(oWenShi:GetApplys()) do
            mApply[k] = v + (mApply[k] or 0) 
        end
    end
    return mApply
end

function CWenShiCtrl:IsCondition(lCondition, mType)
    for _,v in pairs(lCondition) do
        local iCnt = mType[v.sid] or 0
        if iCnt < v.cnt then
            return false
        end
    end
    return true
end

function CWenShiCtrl:GetSkillByType(mType)
    local mSkill = res["daobiao"]["wenshi"]["skill_list"]
    for _,m in pairs(mSkill) do
        if self:IsCondition(m.condition, mType) then
            return m.skill
        end
    end
    return nil
end

function CWenShiCtrl:GetApplySkill()
    if table_count(self.m_mPos2WenShi) < self:GetMaxPos() then return end
     
    local mType = {}
    for _,oWenShi in pairs(self.m_mPos2WenShi) do
        if oWenShi:GetLast() <= 0 then return end
        
        local iType = oWenShi:WenShiType()
        mType[iType] = 1 + (mType[iType] or 0)
    end

    return self:GetSkillByType(mType)
end

function CWenShiCtrl:SetSkill(iSkill)
    self.m_iSkill = iSkill
    self:Dirty()
end

function CWenShiCtrl:GetSkill()
    return self.m_iSkill
end

function CWenShiCtrl:IsSkillEffect()
    if table_count(self.m_mPos2WenShi) < self:GetMaxPos() then 
        return false
    end

    for _, oWenShi in pairs(self.m_mPos2WenShi) do
        if oWenShi:GetLast() <= 0 then
            return false
        end        
    end
    return true
end

function CWenShiCtrl:GetScore()
    local iScore = 0 
    for _,oWenShi in pairs(self.m_mPos2WenShi) do
        if oWenShi:GetLast() > 0 then
            iScore = iScore + oWenShi:GetScore()    
        end
    end
    local iSkill = self:GetApplySkill()
    if iSkill then
        iScore = iScore + 100
    end
    return iScore
end

function CWenShiCtrl:PackNetWenShi(oPlayer)
    local lNet = {}
    if not oPlayer then return lNet end

    for iPos, oWenShi in pairs(self.m_mPos2WenShi) do
        local mNet = oWenShi:PackItemInfo()
        mNet.pos = iPos
        table.insert(lNet, mNet)
    end
    return lNet
end


