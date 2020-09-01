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

    local iItem = mArgs[1]
    iItem = self:MakeItem(iItem)
    if not iItem then
        oPlayer:NotifyMessage("不能制作该物品")
        return 
    end

    oPlayer:AddEnergy(-iEnergy, "打造符")
    local oItem = global.oItemLoader:Create(iItem)
    oItem:SetAmount(1)
    oPlayer:RewardItem(oItem, "打造")
    oPlayer:Send("GS2CUseOrgSkill", {infos={{itemid=iItem, cnt=1}}})
end

function COrgSkill:MakeItem(iItem)
    local iLv = math.floor(self:Level() / 10) * 10
    for _, mItem in pairs(self:GetSkillData()["item"]) do
        if iItem then
            if mItem["level"] <= iLv and mItem["id"] == iItem then
                return mItem["id"]
            end
        else
            if mItem["level"] == iLv then
                return mItem["id"]
            end
        end
    end
    return nil
end

function COrgSkill:LearnNeedCost(iLv)
    local res = require "base.res"
    local mData = res["daobiao"]["orgskill"]["upgrade"][iLv]
    return mData["pro_silver"], mData["pro_offer"]
end

function COrgSkill:LimitLevel(oPlayer)
    return math.min(oPlayer:GetGrade() + 10, self:MaxLevel())
end
