local global = require "global"
local skynet = require "skynet"

local itembase = import(service_path("item/other/otherbase"))

function NewItem(sid)
    local o = CItem:New(sid)
    return o
end

CItem = {}
CItem.__index = CItem
inherit(CItem,itembase.CItem)


function CItem:TrueUse(oPlayer, iTarget)
    local oFmtMgr = oPlayer:GetFormationMgr()
    local iAdd = self:GetAddExp(iTarget)
    if not iAdd then return end

    if not self:IsValidTarget(oPlayer, iTarget) then
        local iLimit = self:GetGradeLimit(oPlayer)
        oFmtMgr:Notify(oPlayer:GetPid(), 1009, {amount=iLimit})
        return
    end

    if oFmtMgr:AddExp(iTarget, iAdd) then
        local iCost = self:GetUseCostAmount()
        -- self:GS2CConsumeMsg(oPlayer)
        oPlayer:RemoveOneItemAmount(self,iCost,"itemuse")
    end
    return true
end

function CItem:UseAmount(oPlayer, iTarget, iAmount, mArgs)
    local oFmtMgr = oPlayer:GetFormationMgr()
    local oFmtObj = oFmtMgr:GetFmtObj(iTarget)
    if not oFmtObj then return false end

    local iAdd = self:GetAddExp(iTarget)
    iAmount = math.min(iAmount, self:GetAmount())
    local iTotal = iAdd * iAmount
    local iFullNeed = oFmtObj:GetFullGradeExpNeed()

    local iNeedAmount = iFullNeed // iAdd
    if iAmount <= iNeedAmount then
        oFmtMgr:AddExp(iTarget, iAdd * iAmount)
        -- self:GS2CConsumeMsg(oPlayer, iAmount)
        oPlayer:RemoveOneItemAmount(self,iAmount,"itemuse")
    else
        iNeedAmount = iNeedAmount + math.min(iFullNeed%iAdd, 1)
        if iNeedAmount < 1 then return false end

        oFmtMgr:AddExp(iTarget, iFullNeed)
        -- self:GS2CConsumeMsg(oPlayer, iNeedAmount)
        oPlayer:RemoveOneItemAmount(self,iNeedAmount,"itemuse")
    end
    return true
end

function CItem:IsValidTarget(oPlayer, iTarget)
    if iTarget < 0 or iTarget > 9 then
        return false
    end
    local oFmtMgr = oPlayer:GetFormationMgr()
    if oFmtMgr:GetFmtObj(iTarget) then
        return true
    end

    local iSize = oFmtMgr:GetFmtSize()
    local iLimit = self:GetUseLimit(oPlayer)
    return iSize < iLimit
end

function CItem:GetFormationInfo()
    local res = require "base.res"
    return res["daobiao"]["formation"]
end

function CItem:GetAddExp(iTarget)
    local mData = self:GetFormationInfo()
    local mInfo = mData["item_info"][self.m_SID]
    if not mInfo then return end

    if iTarget == mInfo.fmt_id then
        return mInfo.exp
    else
        return mInfo.other_exp
    end
end

function CItem:GetUseLimit(oPlayer)
    local mData = self:GetFormationInfo()
    local mLimit = mData["use_limit"]
    local iGrade = oPlayer:GetGrade()
    local iLimit = 0
    for idx, mInfo in ipairs(mLimit) do
        if iGrade >= mInfo.grade then
            iLimit = mInfo.num
        else
            break
        end
    end
    return iLimit
end

function CItem:GetGradeLimit(oPlayer)
    local mData = self:GetFormationInfo()
    local mLimit = mData["use_limit"]
    local iGrade = oPlayer:GetGrade()
    local iLimit = 100
    for idx, mInfo in ipairs(mLimit) do
        if iGrade < mInfo.grade then
            iLimit = mInfo.grade
            break
        end
    end
    return iLimit
end
