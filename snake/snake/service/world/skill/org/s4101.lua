--import module

local global = require "global"
local extend = require "base.extend"

local skillobj = import(service_path("skill/org/orgbase"))

function NewSkill(iSk)
    local o = COrgSkill:New(iSk)
    return o
end


COrgSkill = {}
COrgSkill.__index = COrgSkill
inherit(COrgSkill, skillobj.COrgSkill)

function COrgSkill:New(iSk)
    local o = super(COrgSkill).New(self, iSk)
    return o
end

function COrgSkill:Use(oPlayer, mArgs)
    if self:Level() < self:EffectLevel() then return end

    local iEnergy = self:GetCostEnergy()
    if oPlayer:GetEnergy() < iEnergy then return end

    local iItem = self:RandomItem()
    if not iItem then return end

    oPlayer:AddEnergy(-iEnergy, "烹饪")
    local oItem = global.oItemLoader:Create(iItem, {quality=self:Level()})
    oItem:SetAmount(1)
    oPlayer:RewardItem(oItem, "烹饪")
    oPlayer:Send("GS2CUseOrgSkill", {infos={{itemid=iItem, cnt=1}}})
end

function COrgSkill:RandomItem()
    local lItem = {}
    for _, mItem in pairs(self:GetSkillData()["item"]) do
        if mItem["level"] <= self:Level() then
            table.insert(lItem, mItem["id"])
        end
    end
    return extend.Random.random_choice(lItem)
end

function COrgSkill:LearnNeedCost(iLv)
    local res = require "base.res"
    local mData = res["daobiao"]["orgskill"]["upgrade"][iLv]
    return mData["pro_silver"], mData["pro_offer"]
end

function COrgSkill:LimitLevel(oPlayer)
    return math.min(oPlayer:GetGrade() + 10, self:MaxLevel())
end
