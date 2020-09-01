local global = require "global"
local skynet = require "skynet"
local extend = require "base.extend"

local itembase = import(service_path("item/other/i11082"))

function NewItem(sid)
    local o = CItem:New(sid)
    return o
end

CItem = {}
CItem.__index = CItem
inherit(CItem,itembase.CItem)


function CItem:TrueUse(oPlayer, iTarget)
    local oFmtMgr = oPlayer:GetFormationMgr()
    local iAdd = self:GetAddExp()
    if not iAdd then return end

    if not oFmtMgr:GetFmtObj(iTarget) then
        return
    end

    if oFmtMgr:AddExp(iTarget, iAdd) then
        local iCost = self:GetUseCostAmount()
        -- self:GS2CConsumeMsg(oPlayer)
        oPlayer:RemoveOneItemAmount(self,iCost,"itemuse")
    end
    return true
end

function CItem:GetCombineRatio()
    local mInfo = self:GetFormationInfo()
    local mData = mInfo["item_info"]
    return mData[self.m_SID]["combine_ratio"]
end

function CItem:ComposeItemInfo(iSize)
    iSize = iSize or 1
    local mResult = {}
    local mIdx2Sid = self:GetIdx2Sid()
    local mRatio = self:GetCombineRatio()

    for i = 1, iSize do
        local iFmtId = extend.Random.choosekey(mRatio)
        local mTmp = {sid = mIdx2Sid[iFmtId], amount=1}
        table.insert(mResult, mTmp)
    end

    return mResult
end

function CItem:GetAddExp()
    local mData = self:GetFormationInfo()
    local mInfo = mData["item_info"][self.m_SID]
    return mInfo.exp
end

function CItem:GetIdx2Sid()
    local mData = {
        [1] =   11082,
        [2] =   11083,
        [3] =   11084,
        [4] =   11085,
        [5] =   11086,
        [6] =   11087,
        [7] =   11088,
        [8] =   11089,
    }
    return mData
end
