local global = require "global"
local res = require "base.res"

local datactrl = import(lualib_path("public.datactrl"))
local loadskill = import(service_path("partner.skill.loadskill")) 

function NewRoPartner(...)
    return CRoPartner:New(...)
end

CRoPartner = {}
CRoPartner.__index = CRoPartner
inherit(CRoPartner, datactrl.CDataCtrl)

function CRoPartner:New(sid)
    local o = super(CRoPartner).New(self)
    o.m_iSID = sid
    return o
end

function CRoPartner:GetIcon()
    return self.m_iIcon
end

function CRoPartner:GetQuality()
    return self.m_iQuality
end

function CRoPartner:GetGrade()
    return self.m_iGrade
end

function CRoPartner:GetOwner()
    return self.m_iOwner
end

function CRoPartner:GetScore()
    return self.m_iScore or 0
end

function CRoPartner:GetSchool()
    return self.m_iSchool
end

function CRoPartner:Init(mData)
    self:Dirty()
    self.m_iGrade = mData.grade
    self.m_sName = mData.name
    self.m_iSchool = mData.school
    self.m_mModel = mData.model_info
    self.m_iType = mData.type
    self.m_iIcon = mData.icon
    self.m_iQuality = mData.quality
    self.m_iOwner = mData.owner
    self.m_iAIType = mData.aitype
    self.m_iScore = mData.score

    local mAttrData = {}
    mAttrData.hp = mData.hp
    mAttrData.mp = mData.mp
    mAttrData.max_hp = mData.max_hp
    mAttrData.max_mp = mData.max_mp
    mAttrData.physique = mData.physique
    mAttrData.magic = mData.magic
    mAttrData.strength = mData.strength
    mAttrData.endurance = mData.endurance
    mAttrData.agility = mData.agility
    
    mAttrData.mag_defense = mData.mag_defense
    mAttrData.phy_defense = mData.phy_defense
    mAttrData.mag_attack = mData.mag_attack
    mAttrData.phy_attack = mData.phy_attack
    mAttrData.cure_power = mData.cure_power
    mAttrData.speed = mData.speed

    mAttrData.phy_critical_ratio = mData.phy_critical_ratio
    mAttrData.res_phy_critical_ratio = mData.res_phy_critical_ratio
    mAttrData.mag_critical_ratio = mData.mag_critical_ratio
    mAttrData.res_mag_critical_ratio = mData.res_mag_critical_ratio
    mAttrData.seal_ratio = mData.seal_ratio
    mAttrData.res_seal_ratio = mData.res_seal_ratio
--    mAttrData.hit_ratio = mData.hit_ratio
--    mAttrData.hit_res_ratio = mData.hit_res_ratio
    mAttrData.phy_hit_ratio = mData.phy_hit_ratio
    mAttrData.phy_hit_res_ratio = mData.phy_hit_res_ratio
    mAttrData.mag_hit_ratio = mData.mag_hit_ratio
    mAttrData.mag_hit_res_ratio = mData.mag_hit_res_ratio
    self.m_mAttrData = mAttrData

    self.m_mPerform = mData.perform
    self.m_mExpertSkill = mData.expertskill
end

function CRoPartner:Save()
    local mData = {}
    mData.school = self.m_iSchool
    mData.grade = self.m_iGrade
    mData.name = self.m_sName
    mData.model_info = self.m_mModel
    mData.type = self.m_iType
    mData.icon = self.m_iIcon
    mData.owner = self.m_iOwner
    mData.attr = self.m_mAttrData
    mData.score = self.m_iScore
    mData.aitype = self.m_iAIType
    local mPerform = {}
    for skid, v in pairs(self.m_mPerform) do
        mPerform[db_key(skid)] = v
    end
    mData.perform = mPerform
    local mExpert = {}
    for skid, v in pairs(self.m_mExpertSkill) do
        mExpert[db_key(skid)] = v
    end
    mData.expertskill = mExpert
    return mData
end

function CRoPartner:Load(mData)
    mData = mData or {}
    self.m_iSchool = mData.school
    self.m_iGrade = mData.grade
    self.m_sName = mData.name
    self.m_mModel = mData.model_info
    self.m_iType = mData.type
    self.m_iIcon = mData.icon
    self.m_iOwner = mData.owner
    self.m_mAttrData = mData.attr
    self.m_iScore = mData.score
    self.m_iAIType = mData.aitype
    self.m_mPerform = {}
    if mData.perform then
        for skid, v in pairs(mData.perform) do
            self.m_mPerform[tonumber(skid)] = v
        end
    end
    self.m_mExpertSkill = {}
    if mData.expertskill then
        for skid, v in pairs(mData.expertskill) do
            self.m_mExpertSkill[tonumber(skid)] = v
        end
    end
end

function CRoPartner:PackWarInfo()
    local mRet = {}
    mRet.pid = self.m_iSID
    mRet.school = self.m_iSchool
    mRet.grade = self.m_iGrade
    mRet.name = self.m_sName
    mRet.model_info = self.m_mModel
    mRet.type = self.m_iType
    mRet.owner = self.m_iOwner
    mRet.aitype = self:GetRoAIType()
    for k, v in pairs(self.m_mAttrData) do
        mRet[k] = v
    end
    mRet.perform = self.m_mPerform
    mRet.expertskill = self.m_mExpertSkill
    return mRet
end

function CRoPartner:GetRoAIType()
    local mData = res["daobiao"]["partner"]["info"][tonumber(self.m_iSID)]
    return mData["ro_aitype"]
end
