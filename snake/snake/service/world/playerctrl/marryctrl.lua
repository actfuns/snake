--import module

local global = require "global"
local skynet = require "skynet"
local res = require "base.res"
local record = require "public.record"

local datactrl = import(lualib_path("public.datactrl"))
local mdefines = import(service_path("marry.defines"))


CMarryCtrl = {}
CMarryCtrl.__index = CMarryCtrl
inherit(CMarryCtrl, datactrl.CDataCtrl)

function CMarryCtrl:New(iPid)
    local o = super(CMarryCtrl).New(self,{pid=iPid})
    o:Init()
    return o
end

function CMarryCtrl:Init()
    self.m_iCouplePid = 0
    self.m_sCoupleName = nil
    self.m_iEngageTime = 0
    self.m_iEngageType = 0
    self.m_iMarryTime = 0
    self.m_iActive = 0
    self.m_sMarryPic = nil
    self.m_iMarryNo = 0
    self.m_iModNo = 0
    self.m_iResDivorceCnt = 0
    self.m_iForceDivorceTime = 0
    self.m_oRingItem = nil
end

function CMarryCtrl:Release()
    if self.m_oRingItem then
        baseobj_safe_release(self.m_oRingItem)
    end
    super(CMarryCtrl).Release(self)
end

function CMarryCtrl:Load(mData)
    if not mData then return end

    self.m_iCouplePid = mData["couplepid"]
    self.m_sCoupleName = mData["couplename"]
    self.m_iEngageTime = mData["engagetime"]
    self.m_iEngageType = mData["engagetype"]
    self.m_iMarryTime = mData["marrytime"]
    self.m_iActive = mData["active"]
    self.m_sMarryPic = mData["marrypic"]
    self.m_iMarryNo = mData["marryno"]
    self.m_iModNo = mData["modno"]
    self.m_iResDivorceCnt = mData["resdivorcecnt"] or 0
    self.m_iForceDivorceTime = mData["forcedivorcetime"] or 0

    local mItem = mData["ring"]
    if mItem then
        self.m_oRingItem = global.oItemLoader:LoadItem(mItem["sid"], mItem)
    end
end

function CMarryCtrl:Save()
    local mData = {}
    mData["couplepid"] = self.m_iCouplePid
    mData["couplename"] = self.m_sCoupleName
    mData["engagetype"] = self.m_iEngageType
    mData["engagetime"] = self.m_iEngageTime
    mData["marrytime"] = self.m_iMarryTime
    mData["active"] = self.m_iActive
    mData["marrypic"] = self.m_sMarryPic
    mData["marryno"] = self.m_iMarryNo
    mData["modno"] = self.m_iModNo
    mData["resdivorcecnt"] = self.m_iResDivorceCnt
    mData["forcedivorcetime"] = self.m_iForceDivorceTime
     
    if self.m_oRingItem then
        mData['ring'] = self.m_oRingItem:Save()
    end
    return mData
end

function CMarryCtrl:GetPid()
    return self:GetInfo("pid")
end

function CMarryCtrl:OnLogin(oPlayer)
end

function CMarryCtrl:IsActive()
    return self.m_iActive == 1
end

function CMarryCtrl:GetMarryStatus()
    if not self.m_iCouplePid or self.m_iCouplePid <= 0 then
        return mdefines.MARRY_STATUS.NONE
    elseif self.m_iMarryTime > 0 then
        return mdefines.MARRY_STATUS.MARRY
    else
        return mdefines.MARRY_STATUS.ENGAGE
    end
end

function CMarryCtrl:SetEngageRelation(oPlayer, iType, bActive, oEquip)
    self.m_iCouplePid = oPlayer:GetPid()
    self.m_sCoupleName = oPlayer:GetName()
    self.m_iEngageType = iType
    self.m_iEngageTime = get_time()
    self.m_iActive = bActive and 1 or 0
    self.m_oRingItem = oEquip
    self:Dirty()
end

function CMarryCtrl:SyncCoupleName(sName)
    self.m_sCoupleName = sName
    self:Dirty()
end

function CMarryCtrl:ResetRelation()
    if self.m_oRingItem then
        baseobj_safe_release(self.m_oRingItem)
    end

    self:Init()
    self:Dirty()
end

function CMarryCtrl:SetMarryRelation(iMarryNo)
    self.m_iMarryNo = iMarryNo
    self.m_iMarryTime = get_time()
    self:Dirty()
end

function CMarryCtrl:SetMarryPic(sUrl)
    self.m_sMarryPic = sUrl
    self:Dirty()
end

function CMarryCtrl:GetMarryPic()
    return self.m_sMarryPic
end

function CMarryCtrl:GetCouplePid()
    return self.m_iCouplePid
end

function CMarryCtrl:GetCoupleName()
    return self.m_sCoupleName
end

function CMarryCtrl:GetEngageType()
    return self.m_iEngageType
end

function CMarryCtrl:GetMarryTime()
    return self.m_iMarryTime
end

function CMarryCtrl:AddResDivorceCnt(iCnt)
    self.m_iResDivorceCnt = self.m_iResDivorceCnt + iCnt
    self:Dirty() 
end

function CMarryCtrl:GetResDivorceCnt()
    return self.m_iResDivorceCnt
end

function CMarryCtrl:SetForceDivorceTime()
    self.m_iForceDivorceTime = get_time()
    self:Dirty()
end

function CMarryCtrl:GetForceDivorceTime()
    return self.m_iForceDivorceTime
end

function CMarryCtrl:GetMarryNo()
    return self.m_iMarryNo
end

function CMarryCtrl:GetModNo()
    return self.m_iModNo
end

function CMarryCtrl:SetModNo(iMod)
    self.m_iModNo = iMod
    self:Dirty()
end

function CMarryCtrl:PackCoupleInfo()
    local mNet = {}
    if self.m_iCouplePid and self.m_iCouplePid > 0 then
        mNet.pid = self:GetCouplePid()
        mNet.name = self:GetCoupleName()
        mNet.equip = self.m_oRingItem:PackItemInfo()
        mNet.active = self.m_iActive
        mNet.etype = self.m_iEngageType
        mNet.status = self:GetMarryStatus()
        mNet.marry_time = self.m_iMarryTime
    end
    return mNet
end
