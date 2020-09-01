--import module
local global = require "global"

function NewMonster(...)
    return CMonster:New(...)
end


CMonster = {}
CMonster.__index = CMonster
inherit(CMonster,logic_base_cls())

function CMonster:New(mArgs)
    local o = super(CMonster).New(self)
    o:Init(mArgs)
    return o
end

function CMonster:Init(mData)
    self.m_iType = mData["type"]
    self.m_iIsBoss = mData["is_boss"]
    self.m_sName = mData["name"]
    self.m_mModelInfo = mData["model_info"]
    self.m_mPerform = mData["perform"]
    self.m_mPerformAI = mData["perform_ai"]
    self.m_iPhyAttack = mData["phyAttack"]
    self.m_iMagAttack = mData["magAttack"]
    self.m_iPhyDefense = mData["phyDefense"]
    self.m_iMagDefense = mData["magDefense"]
    self.m_iSpeed = mData["speed"]
    self.m_iHp = mData["hp"]
    self.m_iMaxHp = mData["maxhp"]
    self.m_iMp = mData["mp"]
    self.m_iMaxMp = mData["maxmp"]
    self.m_iCritRate = mData["critRate"]
    self.m_iPhyHitRatio = mData["phy_hit_ratio"] or 100
    self.m_iPhyHitResRatio = mData["phy_hit_res_ratio"] or 5
    self.m_iMagHitRatio = mData["mag_hit_ratio"] or 100
    self.m_iMagHitResRatio = mData["mag_hit_res_ratio"] or 0
    self.m_iGrade = mData["grade"]
    self.m_iAIType = mData["aitype"]
    self.m_mExpertSkill = mData["expertskill"]
    self.m_iMirrorSchool = mData["mirror_school"]
    self.m_iCurePower = mData["cure_power"]
    self.m_iSealRatio = mData["seal_ratio"]
    self.m_iResSealRatio = mData["res_seal_ratio"]
    self.m_sTitle = mData["title"]
    self.m_iSpecialNPC = mData["specialnpc"] or 0
end

function CMonster:PackAttr()
    local mRet = {}
    mRet.type = self.m_iType
    mRet.is_boss = self.m_iIsBoss
    mRet.grade = self.m_iGrade
    mRet.name = self.m_sName
    mRet.hp = self.m_iHp
    mRet.mp = self.m_iMp
    mRet.max_hp = self.m_iMaxHp
    mRet.max_mp = self.m_iMaxMp
    mRet.model_info = self.m_mModelInfo
    mRet.phy_defense = self.m_iPhyDefense
    mRet.mag_defense = self.m_iMagDefense
    mRet.phy_attack = self.m_iPhyAttack
    mRet.mag_attack = self.m_iMagAttack
    mRet.phy_hit_ratio = self.m_iPhyHitRatio
    mRet.phy_hit_res_ratio = self.m_iPhyHitResRatio
    mRet.mag_hit_ratio = self.m_iMagHitRatio
    mRet.mag_hit_res_ratio = self.m_iMagHitResRatio
    mRet.speed = self.m_iSpeed
    mRet.perform = self.m_mPerform
    mRet.perform_ai = self.m_mPerformAI
    mRet.aitype = self.m_iAIType
    mRet.expertskill = self.m_mExpertSkill
    mRet.phy_critical_ratio = self.m_iCritRate
    mRet.mag_critical_ratio = self.m_iCritRate
    mRet.mirror_school = self.m_iMirrorSchool
    mRet.cure_power = self.m_iCurePower
    mRet.seal_ratio = self.m_iSealRatio 
    mRet.res_seal_ratio = self.m_iResSealRatio
    mRet.title = self.m_sTitle
    mRet.specialnpc = self.m_iSpecialNPC
    return mRet
end

function CMonster:IsBoss()
    return self.m_iIsBoss == 1
end

function CMonster:Type()
    return self.m_iType
end
