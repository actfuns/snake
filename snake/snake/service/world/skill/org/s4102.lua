--import module

local global = require "global"
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

    local lItem = mArgs or {}
    if #lItem ~= 4 and #lItem ~= 0 then return end

    local bSpecial = true
    if #lItem <= 0 then
        local iSilver = 10000
        if not oPlayer:ValidSilver(iSilver) then return end
        
        bSpecial = false
        oPlayer:ResumeSilver(iSilver, "炼药")
    else
        local mItem = {}
        for _, iId in ipairs(lItem) do
            local iCnt = mItem[iId] or 0
            mItem[iId] = iCnt + 1
        end

        for iId, iCnt in pairs(mItem) do
            if not table_in_list(self:GetSkillData()["make_item"], iId) then return end

            if iCnt > oPlayer:GetItemAmount(iId) then
                oPlayer:NotifyMessage("物品不足")
                return
            end
        end

        for iId, iCnt in pairs(mItem) do
            oPlayer:RemoveItemAmount(iId, iCnt, "炼药")
        end
    end

    local iItem = self:RefineItem(bSpecial)
    if not iItem then return end

    oPlayer:AddEnergy(-iEnergy, "炼药")
    local mArgs = {}
    if iItem ~= 10057 then
        local iQuality = math.floor(self:Level() * math.random(6, 12) / 10)
        mArgs = {quality=iQuality}
    end

    local oItem = global.oItemLoader:Create(iItem, mArgs)
    oItem:SetAmount(1)
    oPlayer:RewardItem(oItem, "炼药")
    oPlayer:Send("GS2CUseOrgSkill", {infos={{itemid=iItem, cnt=1}}})
end

function COrgSkill:RefineItem(bSpecial)
    if bSpecial then
        return self:SpecialRefine()
    end
    return self:NormalRefine()
end

function COrgSkill:NormalRefine()
    local res = require "base.res"
    local mData = res["daobiao"]["orgskill"]["refine"]
    local iRan, iCnt = math.random(1, 100), 0

    for _,m in pairs(mData) do
        if iRan <= m["radio_1"] + iCnt then
            return m["item_id"]
        end
        iCnt = iCnt + m["radio_1"]
    end
end

function COrgSkill:SpecialRefine()
    local res = require "base.res"
    local mData = res["daobiao"]["orgskill"]["refine"]
    local iRan, iCnt = math.random(1, 100), 0

    for _,m in pairs(mData) do
        if iRan <= m["radio_2"] + iCnt then
            return m["item_id"]
        end
        iCnt = iCnt + m["radio_2"]
    end
end

function COrgSkill:LearnNeedCost(iLv)
    local res = require "base.res"
    local mData = res["daobiao"]["orgskill"]["upgrade"][iLv]
    return mData["pro_silver"], mData["pro_offer"]
end

function COrgSkill:LimitLevel(oPlayer)
    return math.min(oPlayer:GetGrade() + 10, self:MaxLevel())
end
