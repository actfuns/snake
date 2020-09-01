local global = require "global"
local skynet = require "skynet"

local interactive =  require "base.interactive"
local extend = require "base.extend"
local res = require "base.res"
local recor d= require "public.record"

local gamedefines = import(lualib_path("public.gamedefines"))
local itembase = import(service_path("item/itembase"))
local defines = import(service_path("item.itemdefines"))
local loadskill = import(service_path("summon.skill.loadskill"))


function NewItem(sid)
    local o = CItem:New(sid)
    return o
end


CItem = {}
CItem.__index = CItem
inherit(CItem,itembase.CItem)
CItem.m_ItemType = "summonequip"

function CItem:Init(sid)
    super(CItem).Init(self, sid)
    self.m_mApply = {}
    self.m_lSkills = {}
end

function CItem:Create(mArgs)
    super(CItem).Create(self, mArgs)
    mArgs = mArgs or {}
    self:GenerateAttr()
    self:GenerateSkill(mArgs)
end

function CItem:Release()
    self.m_mApply = {}
    for _,oSkill in pairs(self.m_lSkills) do
        baseobj_safe_release(oSkill)
    end

    super(CItem).Release(self)
end

function CItem:EquipType()
    return self:GetItemData()["equippos"]
end

function CItem:GetPoint()
    return self:GetItemData()["point"] or 0
end

function CItem:IsEquipType(iType)
    return iType == self:EquipType()
end

function CItem:Load(mData)
    super(CItem).Load(self, mData)

    self.m_mApply = mData["apply"]
    for _, info in pairs(mData["skills"] or {}) do
        local skid = info["skid"]
        local oSkill = loadskill.LoadSkill(skid, info)
        table.insert(self.m_lSkills, oSkill)
    end
end

function CItem:Save()
    local mData = super(CItem).Save(self)
    mData["apply"] = self.m_mApply
    
    mData["skills"] = {}
    for _, oSkill in pairs(self.m_lSkills) do
        table.insert(mData["skills"], oSkill:Save())
    end
    return mData
end

function CItem:Setup()
    super(CItem).Setup(self)

    if self:IsEquipType(defines.SUMMON_EQUIP_HF) and self:GetSKillCnt() <= 0 then
        self:GenerateSkill()
    end
end

function CItem:GetSkills()
    return self.m_lSkills
end

function CItem:RandomAttrRatio()
    local mInfo = res["daobiao"]["summonequipratio"]
    
    local mRatio = {}
    for id, m in pairs(mInfo) do
        mRatio[id] = m["ratio"]
    end
    local key = table_choose_key(mRatio)
    local iMin, iMax = mInfo[key]["min"], mInfo[key]["max"]
    return math.random(iMin, iMax)
end

function CItem:GenerateAttr()
    if self:IsEquipType(defines.SUMMON_EQUIP_HF) then return end

    local sFormat = self:GetItemData()["equip_effect"]
    local mFormat = formula_string(sFormat, {})
    local mApply = extend.Random.sample_table(mFormat, 1)
    for sKey, iVal in pairs(mApply) do
        self.m_mApply[sKey] = math.floor(iVal * self:RandomAttrRatio() / 100)
    end
end

function CItem:GetSkillByGroup(lGroup)
    local mInfo = res["daobiao"]["summonskillgroup"]
    local lSkill = {}
    for _, id in pairs(lGroup) do
        if mInfo[id] then
            lSkill = list_combine(lSkill, mInfo[id]["skills"])
        end
    end
    local iRan = math.random(#lSkill)
    local iSkill = lSkill[iRan]
    if self:CanSkillPick(iSkill) then
        return iSkill
    end
    for i = 1, #lSkill do
        iRan = iRan + 1
        if iRan > #lSkill then
            iRan = 1
        end
        local iSkill = lSkill[iRan]
        if self:CanSkillPick(iSkill) then
            return iSkill
        end
    end
    return nil
end

function CItem:CanSkillPick(iSkill)
    for _, oSkill in pairs(self.m_lSkills) do
        if oSkill:SkID() == iSkill then
            return false
        end
        if table_in_list({5116, 5117}, oSkill:SkID()) and table_in_list({5116, 5117}, iSkill) then
            return false
        end
    end
    return true
end

function CItem:GenerateSkill(mArgs)
    if not self:IsEquipType(defines.SUMMON_EQUIP_HF) then return end
    
    mArgs = mArgs or {}
    local sFormat = self:GetItemData()["equip_effect"]
    local mFormat = formula_string(sFormat, {})
    if mArgs.skill then
        self:InitSkill(mArgs.skill)
    elseif mArgs.skcnt then
        local iCnt = mArgs.skcnt
        for idx,mEffect in pairs(mFormat) do
            if idx > iCnt then break end

            local skid = self:GetSkillByGroup(mEffect["group"])
            local oSkill = loadskill.NewSkill(skid)
            table.insert(self.m_lSkills, oSkill)
        end
    else
        for _,mEffect in pairs(mFormat) do
            if math.random(100) <= mEffect["ratio"] then
                local skid = self:GetSkillByGroup(mEffect["group"])
                local oSkill = loadskill.NewSkill(skid)
                table.insert(self.m_lSkills, oSkill)
            end
        end
    end
end

function CItem:InitSkill(lSkill)
    self.m_lSkills = {}
    for _, iSkill in pairs(lSkill) do
        local oSkill = loadskill.NewSkill(iSkill)
        table.insert(self.m_lSkills, oSkill)
    end   
end

function CItem:ResetSkill()
    local iCnt = math.max(self:GetSKillCnt(), 1)
    self.m_lSkills = {}
    self:GenerateSkill({skcnt=iCnt})
end

function CItem:GetSKillCnt()
    return #self.m_lSkills
end

function CItem:EquipEffect(oSummon)
    for sAttr, iValue in pairs(self.m_mApply) do
        oSummon:AddApply(sAttr, iValue, self:SID())
    end
    for _, oSkill in pairs(self.m_lSkills) do
        oSkill:SkillEffect(oSummon, true)
    end
end

function CItem:EquipUnEffect(oSummon)
    for sAttr, iValue in pairs(self.m_mApply) do
        oSummon:RemoveApply(self:SID())
    end
    for _, oSkill in pairs(self.m_lSkills) do
        oSkill:SkillUnEffect(oSummon, true)
    end
end

function CItem:PackEquipInfo()
    local mNet = {}
    mNet.attach_attr = {}
    for sKey, iValue in pairs(self.m_mApply) do
        table.insert(mNet.attach_attr, {key=sKey, value=iValue})
    end
    mNet.skills = {}
    for _, oSkill in pairs(self.m_lSkills) do
        table.insert(mNet.skills, oSkill:PackNetInfo())
    end
    return mNet
end

function CItem:PackItemInfo()
    local mNet = super(CItem).PackItemInfo(self)
    mNet.equip_info = self:PackEquipInfo()
    return mNet
end

function CItem:GetScore()
    local iType = self:EquipType()
    local iScore = 0
    if iType == 3 then
        for _, oSkill in pairs(self.m_lSkills) do
            iScore = iScore + oSkill:GetScore()
        end
    else
        local sScore = self:GetItemData()["score"]
        iScore = math.floor(formula_string(sScore,{}))
    end
    return iScore
end

