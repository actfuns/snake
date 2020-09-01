local global = require "global"
local res = require "base.res"
local record = require "public.record"
local datactrl = import(lualib_path("public.datactrl"))

function NewGiftMgr(pid)
    return CGiftMgr:New(pid)
end

CGiftMgr = {}
CGiftMgr.__index = CGiftMgr
inherit(CGiftMgr, datactrl.CDataCtrl)

function CGiftMgr:New(pid)
    local o = super(CGiftMgr).New(self, {pid = pid})
    o.m_mGradeRewarded = {}
    o.m_mPreopenRewarded = {}
    return o
end

function CGiftMgr:Release()
    self.m_mGradeRewarded = {}
    self.m_mPreopenRewarded = {}
    super(CGiftMgr).Release(self)
end

function CGiftMgr:GetOwner()
    return self:GetInfo("pid")
end

function CGiftMgr:Save()
    local mData = {
        grade_rewarded = table_to_db_key(self.m_mGradeRewarded),
        preopen_rewarded = table_to_db_key(self.m_mPreopenRewarded),
    }
    return mData
end

function CGiftMgr:Load(mData)
    self.m_mGradeRewarded = table_to_int_key(mData.grade_rewarded or {})
    self.m_mPreopenRewarded = table_to_int_key(mData.preopen_rewarded or {})
end

function CGiftMgr:OnLogin(oPlayer, bReEnter)
    local mNet = {rewarded = table_key_list(self.m_mGradeRewarded)}
    oPlayer:Send("GS2CLoginGradeGiftInfo", mNet)
    local mNet = {rewarded = table_key_list(self.m_mPreopenRewarded)}
    oPlayer:Send("GS2CLoginPreopenGiftInfo", mNet)
end

function CGiftMgr:GetText(iText)
    return global.oToolMgr:GetTextData(iText, {"text"})
end

function CGiftMgr:CallRewardGradeGift(iGrade)
    local iPid = self:GetOwner()
    local oPlayer = global.oWorldMgr:GetOnlinePlayerByPid(iPid)
    if not oPlayer then
        return
    end
    if not global.oToolMgr:IsSysOpen("UPGRADEPACK", oPlayer) then
        return
    end
    if iGrade > oPlayer:GetGrade() then
        global.oNotifyMgr:Notify(iPid, self:GetText(3002))
        return
    end
    if self.m_mGradeRewarded[iGrade] then
        global.oNotifyMgr:Notify(iPid, self:GetText(3001))
        return
    end
    if not self:DoRewardGradeGift(oPlayer, iGrade) then
        return
    end
    self:SetGradeGiftRewarded(iGrade)
    oPlayer:Send("GS2CRewardGradeGift", {grade = iGrade})
end

function CGiftMgr:DoRewardGradeGift(oPlayer, iGrade, bSilent)
    local iRewardId = table_get_depth(res, {"daobiao", "gradegift", iGrade, "reward_id"})
    if not iRewardId then
        if not bSilent then
            oPlayer:NotifyMessage(self:GetText(3003))
        end
        return false
    end
    local iNeedGrids = global.oRewardMgr:CountRewardItemProbableGridsByGroup(oPlayer, "gradegift", iRewardId)
    if not iNeedGrids then
        if not bSilent then
            oPlayer:NotifyMessage(self:GetText(3003))
        end
        return false
    end
    local iHasGrids = oPlayer.m_oItemCtrl:GetCanUseSpaceSize()
    if iNeedGrids > iHasGrids then
        if not bSilent then
            oPlayer:NotifyMessage(self:GetText(3010))
        end
        return false
    end
    local mLogData = oPlayer:LogData()
    mLogData.grade = iGrade
    record.user("player", "reward_gradegift", mLogData)

    global.oRewardMgr:RewardByGroup(oPlayer, "gradegift", iRewardId)
    return true
end

function CGiftMgr:SetGradeGiftRewarded(iGrade)
    self:Dirty()
    self.m_mGradeRewarded[iGrade] = true
end

function CGiftMgr:CallRewardPreopenGift(iSysId)
    local iPid = self:GetOwner()
    local oPlayer = global.oWorldMgr:GetOnlinePlayerByPid(iPid)
    if not oPlayer then
        return
    end
    local mData = table_get_depth(res, {"daobiao", "preopen", iSysId})
    if not mData then
        global.oNotifyMgr:Notify(iPid, self:GetText(3003))
        return
    end
    local iGrade = mData.reward_grade
    if iGrade > oPlayer:GetGrade() then
        global.oNotifyMgr:Notify(iPid, self:GetText(3002))
        return
    end
    if self.m_mPreopenRewarded[iSysId] then
        global.oNotifyMgr:Notify(iPid, self:GetText(3001))
        return
    end
    if not self:DoRewardPreopenGift(oPlayer, iSysId) then
        return
    end
    self:SetPreopenGiftRewarded(iSysId)
    oPlayer:Send("GS2CRewardPreopenGift", {sys_id = iSysId})
end

function CGiftMgr:DoRewardPreopenGift(oPlayer, iSysId, bSilent)
    local iRewardId = table_get_depth(res, {"daobiao", "preopen", iSysId, "rewardid"})
    if not iRewardId then
        if not bSilent then
            oPlayer:NotifyMessage(self:GetText(3003))
        end
        return false
    end
    local iNeedGrids = global.oRewardMgr:CountRewardItemProbableGridsByGroup(oPlayer, "preopen", iRewardId)
    if not iNeedGrids then
        if not bSilent then
            oPlayer:NotifyMessage(self:GetText(3003))
        end
        return false
    end
    local iHasGrids = oPlayer.m_oItemCtrl:GetCanUseSpaceSize()
    if iNeedGrids > iHasGrids then
        if not bSilent then
            oPlayer:NotifyMessage(self:GetText(3010))
        end
        return false
    end
    local mLogData = oPlayer:LogData()
    mLogData.sys_id = iSysId
    record.user("player", "reward_preopengift", mLogData)

    global.oRewardMgr:RewardByGroup(oPlayer, "preopen", iRewardId)
    return true
end

function CGiftMgr:SetPreopenGiftRewarded(iSysId)
    self:Dirty()
    self.m_mPreopenRewarded[iSysId] = true
end
