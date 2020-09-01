local global = require "global"

local datactrl = import(lualib_path("public.datactrl"))

function NewRoPlayer(...)
    return CRoPlayer:New(...)
end

CRoPlayer = {}
CRoPlayer.__index = CRoPlayer
inherit(CRoPlayer, datactrl.CDataCtrl)

function CRoPlayer:New(iPid)
    local o = super(CRoPlayer).New(self)
    o.m_iPid = iPid
    return o
end

function CRoPlayer:Init(mData)
    self:Dirty()
    self.m_iGrade = mData.grade
    self.m_sName = mData.name
    self.m_iSchool = mData.school
    self.m_mModel = mData.model_info
    self.m_iIcon = mData.icon
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

    self.m_mPerform = mData.perform or {}
    self.m_mExpertSkill = mData.expertskill or {}
end

function CRoPlayer:GetName()
    return self.m_sName
end

function CRoPlayer:GetGrade()
    return self.m_iGrade
end

function CRoPlayer:GetSchool()
    return self.m_iSchool
end

function CRoPlayer:GetIcon()
    return self.m_iIcon
end

function CRoPlayer:GetScore()
    return self.m_iScore
end

function CRoPlayer:GetModelInfo()
    return self.m_mModel
end

function CRoPlayer:GetAttr(sAttr)
    return self.m_mAttrData[sAttr] or 0
end

function CRoPlayer:Save()
    local mData = {}
    mData.school = self.m_iSchool
    mData.grade = self.m_iGrade
    mData.name = self.m_sName
    mData.model_info = self.m_mModel
    mData.icon = self.m_iIcon
    mData.score = self.m_iScore

    mData.attr = self.m_mAttrData
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

function CRoPlayer:Load(mData)
    mData = mData or {}
    self.m_iSchool = mData.school
    self.m_iGrade = mData.grade
    self.m_sName = mData.name
    self.m_mModel = mData.model_info
    self.m_iIcon = mData.icon
    self.m_iScore = mData.score
    self.m_mAttrData = mData.attr
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

function CRoPlayer:PackWarInfo()
    local mRet = {}
    mRet.pid = self.m_iPid
    mRet.school = self.m_iSchool
    mRet.grade = self.m_iGrade
    mRet.name = self.m_sName
    mRet.model_info = self.m_mModel
    for k, v in pairs(self.m_mAttrData) do
        mRet[k] = v
    end
    mRet.perform = self.m_mPerform
    mRet.expertskill = self.m_mExpertSkill
    return mRet
end
