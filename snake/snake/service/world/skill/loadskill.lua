--import module

local global = require "global"

local mSkillList = {}

local mSkillDir = {
    ["active"] = {1100,2000},
    ["passive"] = {2000,3000},
    ["cultivate"] = {4000, 4007},
    ["se"] = {6000,6199},
    ["org"] = {4101, 4119},         -- 4120 与 4121 不做为辅助技能载入
    ["fuzhuan"] = {4300,4399},
    ["marry"] = {8500,8599},
    ["artifact"] = {9501, 9600},
}

local mPassiveSkill = {}
local mActiveSkill = {}
local mCultivateSkill = {}
local mFuZhuan = {}

function GetDir(iSk)
    for sDir,mPos in pairs(mSkillDir) do
        local iStart,iEnd = table.unpack(mPos)
        if iStart <= iSk and iSk <= iEnd then
            return sDir
        end
    end
end

function NewSkill(iSk)
    local sDir = GetDir(iSk)
    if global.oDerivedFileMgr:ExistFile("skill", sDir, "s"..iSk) then
        local sPath = string.format("skill/%s/s%d", sDir, iSk)
        local oModule = import(service_path(sPath))
        return oModule.NewSkill(iSk)
    end
    assert(sDir,string.format("NewSkill err:%s",iSk))
    local sPath = string.format("skill/%s/%sbase",sDir,sDir)
    local oModule = import(service_path(sPath))
    assert(oModule,string.format("NewSkill err:%d",iSk))
    local oSk = oModule.NewSkill(iSk)
    return oSk
end

function GetSkill(iSk)
    local oSk = mSkillList[iSk]
    if oSk then
        return oSk
    end
    local oSk = NewSkill(iSk)
    mSkillList[iSk] = oSk
    return oSk
end

function LoadSkill(iSk,mData)
    local oSk = NewSkill(iSk)
    oSk:Load(mData)
    return oSk
end

function GetSchoolSkill(iSchool)
    return  mPassiveSkill[iSchool]
end

function GetSkillData()
    local res = require "base.res"
    local mData = res["daobiao"]["skill"]
    return mData
end

function GetOrgSkillData()
    local res = require "base.res"
    return res["daobiao"]["orgskill"]["skill"] or {}
end

function GetActiveSkill(iSchool)
    return mActiveSkill[iSchool] or {}
end

function GetPassiveSkill(iSchool)
    return mPassiveSkill[iSchool] or {}
end

function GetCultivateSkill()
    return mCultivateSkill
end

function GetFuZhuanSkill()
    return mFuZhuan
end

--初始化技能配置
function InitSkillConfig()
    local mSkillData = GetSkillData()
    for iSchool = 1,6 do
        mActiveSkill[iSchool] = {}
        mPassiveSkill[iSchool] = {}
        for i=0,20 do
            local iSk = 1000 + iSchool * 100 + i
            local iPassiveSk = 2000 + iSchool * 100 + i
            if mSkillData[iSk] then
                table.insert(mActiveSkill[iSchool],iSk)
            end
            if mSkillData[iPassiveSk] then
                table.insert(mPassiveSkill[iSchool],iPassiveSk)
            end
        end
    end
    --修炼
    for i=0, 7 do
        local iSk = 4000 + i
        if mSkillData[iSk] then
            mCultivateSkill[iSk] = true
        end
    end

    --
    for i=0, 99 do
        local iSk = 4300 + i
        if mSkillData[iSk] then
            mFuZhuan[iSk] = true
        end
    end
end


function NewSkillLoader()
    return CSkillLoader:New()
end

CSkillLoader = {}
CSkillLoader.__index = CSkillLoader
inherit(CSkillLoader, logic_base_cls())

function CSkillLoader:New()
    local o = super(CSkillLoader).New(self)
    o.m_mLowestEffectiveOrgSkills = {}
    return o
end

function CSkillLoader:GetLowestEffectiveOrgSkill(iSk)
    local oSk = self.m_mLowestEffectiveOrgSkills[iSk]
    if not oSk then
        oSk = NewSkill(iSk)
        oSk:SetLevel(oSk:EffectLevel())
        self.m_mLowestEffectiveOrgSkills[iSk] = oSk
    end
    return oSk
end
