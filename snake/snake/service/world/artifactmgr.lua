local global = require "global"
local skynet = require "skynet"
local res = require "base.res"
local extend = require "base.extend"
local gamedefines = import(lualib_path("public.gamedefines"))
local analylog = import(lualib_path("public.analylog"))


function NewArtifactMgr()
    return CArtifactMgr:New()
end

CArtifactMgr = {}
CArtifactMgr.__index = CArtifactMgr
inherit(CArtifactMgr, logic_base_cls())

function CArtifactMgr:New()
    local o = super(CArtifactMgr).New(self)
    return o
end

function CArtifactMgr:TryGetArtifact(oPlayer)
    local bRet = self:ValidGetArtifact(oPlayer)
    if not bRet then
        return 
    end
    local mConfig = self:GetConfig()
    local iSchool = oPlayer:GetSchool()
    local iEquip = mConfig["school2artifact"][iSchool]
    assert(iEquip, "unconfig school2artifact:"..iSchool)

    local oEquip = global.oItemLoader:Create(iEquip)
    oPlayer.m_oItemCtrl:AddArtifact(oEquip)
    local mRefresh = oPlayer.m_oArtifactCtrl:CalBaseAttr() or {}
    mRefresh.score = 1
    global.oScoreCache:Dirty(oPlayer:GetPid(), "artifactctrl")
    oPlayer.m_oArtifactCtrl:PropArtifactChange(mRefresh, true)
end

function CArtifactMgr:ValidGetArtifact(oPlayer)
    local oEquip = oPlayer.m_oItemCtrl:GetArtifact()
    if oEquip then
        return false
    end
    local iPid = oPlayer:GetPid()
    if not global.oToolMgr:IsSysOpen("ARTIFACT", oPlayer, true) then
        return false
    end
    return true
end

function CArtifactMgr:OpenArtifactUI(oPlayer)
    if not global.oToolMgr:IsSysOpen("ARTIFACT", oPlayer, true) then
        return
    end

    local oEquip = oPlayer.m_oItemCtrl:GetArtifact()
    if not oEquip then
        return
    end

    local mNet = oPlayer.m_oArtifactCtrl:PackArtifactNetInfo()
    oPlayer:Send("GS2COpenArtifactUI",{info = mNet})
end

function CArtifactMgr:UpgradeUseAll(oPlayer, bGoldCoin)
    if not global.oToolMgr:IsSysOpen("ARTIFACT", oPlayer, true) then
        return
    end

    local oEquip = oPlayer.m_oItemCtrl:GetArtifact()
    if not oEquip then
        return
    end

    local mConfig = self:GetConfig()
    local iPid = oPlayer:GetPid()
    local iNeedSid = mConfig.maincost
    local oCacheItem = global.oItemLoader:GetItem(iNeedSid)
    if not oCacheItem then return end

    local oCtrl = oPlayer.m_oArtifactCtrl
    local iGrade = oCtrl:GetGrade()
    if iGrade >= oCtrl:GetMaxGrade() then
        self:Notify(iPid, 1001)
        return
    end

    local iNeedExp = oCtrl:GetUpgradeUseExp(iGrade+1)
    if iNeedExp <= 0 then
        self:Notify(iPid, 1001)
        return
    end

    local sReason = "神器升级"
    local sAddReason = ""
    local iTotalAdd = 0
    local iOneAdd = oCacheItem:CalItemFormula(oPlayer)
    local iHasAmount = oPlayer:GetItemAmount(iNeedSid)
    local iNeedAmount = math.ceil(iNeedExp / iOneAdd)
    local mCostItem = {[iNeedSid] = iNeedAmount}
    local mAnaly = {}

    if not bGoldCoin then
        if iHasAmount > 0 then
            oPlayer:RemoveItemAmount(iNeedSid, iHasAmount, sReason)
            iTotalAdd = iOneAdd * iHasAmount
            sAddReason = string.format("%s(%s)", oCacheItem:Name(), iHasAmount)
            mAnaly[iNeedSid] = iHasAmount
        end
    else
        local bSucc, mLogCost = global.oFastBuyMgr:FastBuy(oPlayer, {item=mCostItem}, sReason)
        if not bSucc then return end

        iTotalAdd = iOneAdd * iNeedAmount

        sAddReason = sAddReason .. string.format("%s(%s)、", oCacheItem:Name(), mLogCost["item"][iNeedSid] or 0)
        sAddReason = sAddReason .. string.format("goldcoin(%s)", mLogCost.goldcoin or 0)
        mAnaly[iNeedSid] = mLogCost["item"][iNeedSid]
        mAnaly[gamedefines.MONEY_TYPE.GOLDCOIN] = mLogCost.goldcoin
    end

    if iTotalAdd > 0 then
        self:Notify(iPid, 1002, {amount = iTotalAdd})
        oCtrl:AddExp(iTotalAdd, sAddReason)
        oPlayer:MarkGrow(56)
        analylog.LogSystemInfo(oPlayer, "upgrade_artifact", nil, mAnaly)
    end
end

function CArtifactMgr:StrengthArtifact(oPlayer, bGoldCoin)
    if not global.oToolMgr:IsSysOpen("ARTIFACT", oPlayer, true) then
        return
    end

    local oEquip = oPlayer.m_oItemCtrl:GetArtifact()
    if not oEquip then
        return
    end

    local mConfig = self:GetConfig()
    local oCtrl = oPlayer.m_oArtifactCtrl
    local iGrade = oCtrl:GetGrade()
    local iPid = oPlayer:GetPid()

    if iGrade < mConfig.strength_open_level then
        self:Notify(iPid, 2001, {level=mConfig.strength_open_level})
        return
    end

    local mConfig = self:GetConfig()
    local iNeedSid = mConfig.strengthcost
    local oCacheItem = global.oItemLoader:GetItem(iNeedSid)
    if not oCacheItem then return end

    local iStrengthLv = oCtrl:GetStrengthLv()
    if iStrengthLv >= oCtrl:GetMaxStrengthLv() then
        self:Notify(iPid, 2002)
        return
    end
    local iNeedExp = oCtrl:GetStrengthUpgradeUseExp(iStrengthLv+1)
    if iNeedExp <= 0 then
        self:Notify(iPid, 2002)
        return
    end

    local sReason = "神器强化"
    local iTotalAdd = 0
    local sAddReason = ""
    local iOneAdd = oCacheItem:CalItemFormula(oPlayer)
    local iHasAmount = oPlayer:GetItemAmount(iNeedSid)
    local iNeedAmount = math.ceil(iNeedExp / iOneAdd)
    local mCostItem = {[iNeedSid] = iNeedAmount}
    local mAnaly = {}

    if not bGoldCoin then
        if iHasAmount > 0 then
            oPlayer:RemoveItemAmount(iNeedSid, iHasAmount, sReason)
            iTotalAdd = iOneAdd * iHasAmount
            sAddReason = string.format("%s(%s)", oCacheItem:Name(), iHasAmount)
            mAnaly[iNeedSid] = iHasAmount
        end
    else
        local bSucc, mLogCost = global.oFastBuyMgr:FastBuy(oPlayer, {item=mCostItem}, sReason)
        if not bSucc then return end

        iTotalAdd = iOneAdd * iNeedAmount

        sAddReason = sAddReason .. string.format("%s(%s)、", oCacheItem:Name(), mLogCost["item"][iNeedSid] or 0)
        sAddReason = sAddReason .. string.format("goldcoin(%s)", mLogCost.goldcoin or 0)
        mAnaly[iNeedSid] = mLogCost["item"][iNeedSid]
        mAnaly[gamedefines.MONEY_TYPE.GOLDCOIN] = mLogCost.goldcoin
    end

    if iTotalAdd > 0 then
        self:Notify(iPid, 2003, {amount = iTotalAdd})
        oCtrl:AddStrengthExp(iTotalAdd, sAddReason)
        analylog.LogSystemInfo(oPlayer, "strength_artifact", nil, mAnaly)
    end
end

function CArtifactMgr:ArtifactSpiritWakeup(oPlayer, iSpirit, bGoldCoin)
    if not global.oToolMgr:IsSysOpen("ARTIFACT", oPlayer, true) then
        return
    end

    local oEquip = oPlayer.m_oItemCtrl:GetArtifact()
    if not oEquip then
        return
    end

    local mConfig = self:GetConfig()
    local oCtrl = oPlayer.m_oArtifactCtrl
    local iGrade = oCtrl:GetGrade()
    local iPid = oPlayer:GetPid()

    if iGrade < mConfig.spirit_open_level then
        self:Notify(iPid, 4001, {level=mConfig.spirit_open_level})
        return
    end
   
    local mSpirit = self:GetSpiritInfo(iSpirit)
    if not mSpirit then
        self:Notify(iPid, 4003)
        return
    end

    if oCtrl:GetSpiritById(iSpirit) then
        self:Notify(iPid, 4002, {name=mSpirit.name})
        return
    end
    
    local sReason = "器灵觉醒" 
    local lCostItem = mSpirit.wake_up_cost
    local lUnEnough, mCostItem = {}, {}
    local mAnaly = {}
    for _, mItem in ipairs(lCostItem) do
        mCostItem[mItem.sid] = mItem.amount
        local iAmount = oPlayer.m_oItemCtrl:GetItemAmount(mItem.sid)
        if iAmount < mItem.amount then
            local oItem = global.oItemLoader:GetItem(mItem.sid)
            table.insert(lUnEnough, oItem:Name())
        end
    end
    if not bGoldCoin then
        if #lUnEnough > 0 then
            self:Notify(iPid, 4004, {item=table.concat(lUnEnough, "、")})
            return
        end
        for _, mItem in ipairs(lCostItem) do
            oPlayer:RemoveItemAmount(mItem.sid, mItem.amount, sReason)
            mAnaly[mItem.sid] = mItem.amount
        end
    else
        local bSucc, mTrueCost = global.oFastBuyMgr:FastBuy(oPlayer, {item=mCostItem}, sReason)
        if not bSucc then return end

        mAnaly[gamedefines.MONEY_TYPE.GOLDCOIN] = mTrueCost.goldcoin
        for iSid, iAmount in pairs(mTrueCost.item or {}) do
            mAnaly[iSid] = iAmount
        end
    end

    oCtrl:AddArtifactSpirit(iSpirit)
    self:Notify(iPid, 4005, {spirit=mSpirit.name})

    analylog.LogSystemInfo(oPlayer, "wakeup_spirit", iSpirit, mAnaly)
end

function CArtifactMgr:ArtifactResetSkill(oPlayer, iSpirit, bGoldCoin)
    if not global.oToolMgr:IsSysOpen("ARTIFACT", oPlayer, true) then
        return
    end

    local oEquip = oPlayer.m_oItemCtrl:GetArtifact()
    if not oEquip then
        return
    end
    
    local mSpirit = self:GetSpiritInfo(iSpirit)
    if not mSpirit then
        self:Notify(oPlayer:GetPid(), 4003)
        return
    end

    if not oPlayer.m_oArtifactCtrl:GetSpiritById(iSpirit) then
        self:Notify(oPlayer:GetPid(), 5001, {name=mSpirit.name})
        return
    end

    local iPid = oPlayer:GetPid()
    local sReason = "器灵重置技能" 
    local lCostItem = mSpirit.reset_skill_cost
    local lUnEnough, mCostItem = {}, {}
    local mAnaly = {}
    for _, mItem in ipairs(lCostItem) do
        mCostItem[mItem.sid] = mItem.amount
        local iAmount = oPlayer.m_oItemCtrl:GetItemAmount(mItem.sid)
        if iAmount < mItem.amount then
            local oItem = global.oItemLoader:GetItem(mItem.sid)
            table.insert(lUnEnough, oItem:Name())
        end
    end

    if not bGoldCoin then
        if #lUnEnough > 0 then
            self:Notify(oPlayer:GetPid(), 6001, {item=table.concat(lUnEnough, "、")})
            return
        end
        for _, mItem in ipairs(lCostItem) do
            oPlayer:RemoveItemAmount(mItem.sid, mItem.amount, sReason)
            mAnaly[mItem.sid] = mItem.amount
        end
    else
        local bSucc, mTrueCost = global.oFastBuyMgr:FastBuy(oPlayer, {item=mCostItem}, sReason)

        if not bSucc then return end

        mAnaly[gamedefines.MONEY_TYPE.GOLDCOIN] = mTrueCost.goldcoin
        for iSid, iAmount in pairs(mTrueCost.item or {}) do
            mAnaly[iSid] = iAmount
        end
    end
    
    oPlayer.m_oArtifactCtrl:ResetSkill(iSpirit)
    analylog.LogSystemInfo(oPlayer, "resetskill_artifact", iSpirit, mAnaly)
end

function CArtifactMgr:ArtifactSaveSkill(oPlayer, iSpirit)
    if not global.oToolMgr:IsSysOpen("ARTIFACT", oPlayer, true) then
        return
    end

    local oEquip = oPlayer.m_oItemCtrl:GetArtifact()
    if not oEquip then
        return
    end
    
    local mSpirit = self:GetSpiritInfo(iSpirit)
    if not mSpirit then
        self:Notify(oPlayer:GetPid(), 4003)
        return
    end

    local oSpirit = oPlayer.m_oArtifactCtrl:GetSpiritById(iSpirit)
    if not oSpirit then
        self:Notify(oPlayer:GetPid(), 5001, {name=mSpirit.name})
        return
    end

    if table_count(oSpirit.m_mBakSkill) <= 0 then
        self:Notify(oPlayer:GetPid(), 6002, {name=mSpirit.name})
        return
    end
    
    oPlayer.m_oArtifactCtrl:SaveSkill(iSpirit)
end

function CArtifactMgr:SetFollowSpirit(oPlayer, iSpirit)
    if not global.oToolMgr:IsSysOpen("ARTIFACT", oPlayer, true) then
        return
    end

    local oEquip = oPlayer.m_oItemCtrl:GetArtifact()
    if not oEquip then
        return
    end

    if iSpirit > 0 then
        local mSpirit = self:GetSpiritInfo(iSpirit)
        if not mSpirit then
            self:Notify(oPlayer:GetPid(), 4003)
            return
        end

        if not oPlayer.m_oArtifactCtrl:GetSpiritById(iSpirit) then
            self:Notify(oPlayer:GetPid(), 5001, {name=mSpirit.name})
            return
        end
    end

    if iSpirit == oPlayer.m_oArtifactCtrl.m_iFollowSpirit then
        return
    end

    oPlayer.m_oArtifactCtrl:SetFollowSpirit(iSpirit)
end

function CArtifactMgr:SetFigthSpirit(oPlayer, iSpirit)
    if not global.oToolMgr:IsSysOpen("ARTIFACT", oPlayer, true) then
        return
    end

    local oEquip = oPlayer.m_oItemCtrl:GetArtifact()
    if not oEquip then
        return
    end

    if iSpirit > 0 then
        local mSpirit = self:GetSpiritInfo(iSpirit)
        if not mSpirit then
            self:Notify(oPlayer:GetPid(), 4003)
            return
        end

        if not oPlayer.m_oArtifactCtrl:GetSpiritById(iSpirit) then
            self:Notify(oPlayer:GetPid(), 5001, {name=mSpirit.name})
            return
        end
    end

    if iSpirit == oPlayer.m_oArtifactCtrl.m_iFightSpirit then
        return
    end

    oPlayer.m_oArtifactCtrl:SetFightSpirit(iSpirit)
end

function CArtifactMgr:GetConfig()
    return res["daobiao"]["artifact"]["config"][1]
end

function CArtifactMgr:GetSpiritInfo(iSpirit)
    return res["daobiao"]["artifact"]["spirit_info"][iSpirit]
end

function CArtifactMgr:Notify(iPid, iChat, mReplace)
    local oNotifyMgr = global.oNotifyMgr
    local sMsg = global.oToolMgr:GetTextData(iChat, {"artifact"})
    if mReplace then
        sMsg = global.oToolMgr:FormatColorString(sMsg, mReplace)
    end
    oNotifyMgr:Notify(iPid, sMsg)
end

