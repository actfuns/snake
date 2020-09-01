--import module
local global = require "global"
local skynet = require "skynet"
local res = require "base.res"

local datactrl = import(lualib_path("public.datactrl"))
local touxianattrmgr = import(service_path("touxian.touxianattrmgr"))

function NewTouxian(...)
    local o = CTouxian:New(...)
    return o
end

CTouxian = {}
CTouxian.__index = CTouxian
inherit(CTouxian, datactrl.CDataCtrl)

function CTouxian:New(iLevel, iPid,iSchool)
    local o = super(CTouxian).New(self,{level = iLevel, pid=iPid,school = iSchool})
    o.m_mTouxianData = {}
    o.m_iIndex = 0
    o:Setup()
    return o
end

function CTouxian:Setup()
    self.m_mTouxianData , self.m_iIndex = self:GetTouxianData()
end

function CTouxian:GetTouxianData()
    local iTid = self:GetTouxianID()
    local mData = res["daobiao"]["touxian"]["touxian"]
    for id , mInfo in pairs(mData) do
        if mInfo.school == self:GetSchool() and mInfo.level == self:GetInfo("level") then
            return mInfo,id
        end
    end
    assert(nil,string.format("touxian init false %s %s %s",self:GetInfo("pid"),self:GetInfo("level"),self:GetInfo("school")))
end

function CTouxian:GetTouxianID()
    return self.m_iIndex
end

function CTouxian:GetPid()
    return self:GetInfo("pid")
end

function CTouxian:GetCost()
    return res["daobiao"]["touxian"]["touxian"][self.m_iIndex]["cost"]
end

function CTouxian:GetName()
    return res["daobiao"]["touxian"]["touxian"][self.m_iIndex]["name"]
end

function CTouxian:GetSchool()
    return self:GetInfo("school")
end

function CTouxian:GetLevel()
    return res["daobiao"]["touxian"]["touxian"][self.m_iIndex]["level"]
end

function CTouxian:GetPower()
    return res["daobiao"]["touxian"]["touxian"][self.m_iIndex]["power"]
end

function CTouxian:GetScore()
    return res["daobiao"]["touxian"]["touxian"][self.m_iIndex]["score"]
end

function CTouxian:GetEffect()
    local mEffectInfo = res["daobiao"]["touxian"]["touxian"][self.m_iIndex]["effect"]
    return mEffectInfo 
end

function CTouxian:PackNetInfo()
    local oWorldMgr = global.oWorldMgr
    local oPlayer = oWorldMgr:GetOnlinePlayerByPid(self:GetPid())
    local mNet = {}
    mNet.tid = self:GetTouxianID()
    return mNet
end

function CTouxian:GetCultivateLevel(iSkill)
    local iLevel = 0
    local mEffectInfo = self:GetEffect()
    if  mEffectInfo[iSkill] then
        iLevel = mEffectInfo[iSkill]["level"]
    end
    return iLevel
end

function CTouxian:GetApplyAttr(sAttr)
    local mApply = res["daobiao"]["touxian"]["touxian"][self.m_iIndex]["apply"]
    return mApply[sAttr] or 0
end

function CTouxian:GetAllApplys()
    local mRet = {}
    local mApply = res["daobiao"]["touxian"]["touxian"][self.m_iIndex]["apply"]
    for sAttr, iVal in pairs(mApply) do
        mRet[sAttr] = iVal
    end
    return mRet
end