local global = require "global"
local record = require "public.record"
local templ = import(service_path("templ"))

function NewRewardMgr(...)
    return CRewardMgr:New(...)
end

CRewardMgr = {}
CRewardMgr.__index = CRewardMgr
-- 待赋值
CRewardMgr.m_sName = nil
inherit(CRewardMgr, templ.CTempl)

function CRewardMgr:New()
    local o = super(CRewardMgr).New(self)
    o.m_sTempName = nil
    o.m_tmp_lRewardGroupNameStack = {}
    return o
end

function CRewardMgr:GetFortune(iMoneyType, mArgs)
    if mArgs and mArgs.fortune then
        return true
    end
    return false
end

function CRewardMgr:BackupGroupName(sGroupName)
    table.insert(self.m_tmp_lRewardGroupNameStack, sGroupName)
    self.m_sName = sGroupName
    return #self.m_tmp_lRewardGroupNameStack
end

function CRewardMgr:RestoreGroupName(iStackLen)
    if iStackLen ~= #self.m_tmp_lRewardGroupNameStack then
        record.error(string.format("rewardmgr restore groupName error, lenght should:%d, curNameStack:%s", iStackLen, table.concat(self.m_tmp_lRewardGroupNameStack)))
        self.m_tmp_lRewardGroupNameStack = {}
    end
    table.remove(self.m_tmp_lRewardGroupNameStack)
    -- 可能为nil
    self.m_sName = self.m_tmp_lRewardGroupNameStack[iStackLen - 1]
end

function CRewardMgr:GetRewardReason(mArgs)
    return "rewardmgr." .. self.m_sName
end

function CRewardMgr:PackRewardContentByGroup(oPlayer, sGroupName, iRewardId, mArgs)
    local iStackLen = self:BackupGroupName(sGroupName)
    local mRewardInfo = self:GetRewardData(iRewardId)
    -- assert(mRewardInfo, string.format("reward %s[%s] null", sGroupName, iRewardId))
    local bSafeCalled, mRewardContent = safe_call(super(CRewardMgr).GenRewardContent, self, oPlayer, mRewardInfo, mArgs)
    self:RestoreGroupName(iStackLen)
    return mRewardContent
end

function CRewardMgr:PreviewRewardByGroup(oPlayer, sGroupName, iRewardId, mArgs)
    local iStackLen = self:BackupGroupName(sGroupName)
    local bSafeCalled, mPreview = safe_call(super(CRewardMgr).PreviewReward, self, oPlayer, iRewardId, mArgs)
    self:RestoreGroupName(iStackLen)
    return mPreview
end

function CRewardMgr:CountRewardItemProbableGridsByGroup(oPlayer, sGroupName, iRewardId, mArgs)
    local iStackLen = self:BackupGroupName(sGroupName)
    local bSafeCalled, iMaxGrids = safe_call(super(CRewardMgr).CountRewardItemProbableGrids, self, oPlayer, iRewardId, mArgs)
    self:RestoreGroupName(iStackLen)
    return iMaxGrids
end

function CRewardMgr:RewardByGroup(oPlayer, sGroupName, iRewardId, mArgs)
    local iStackLen = self:BackupGroupName(sGroupName)
    local bSafeCalled = safe_call(super(CRewardMgr).Reward, self, oPlayer:GetPid(), iRewardId, mArgs)
    self:RestoreGroupName(iStackLen)
end

function CRewardMgr:RewardItemFilter(oPlayer, iFilterId, iAmount, sReason, mArgs)
    local iSid = self:FindItemInFilter(oPlayer, iFilterId)
    oPlayer:RewardItems(iSid, iAmount, sReason, mArgs)
end

function CRewardMgr:InitRewardItemListByGroup(oPlayer, sGroupName, lItemIdxs, mArgs)
    local iStackLen = self:BackupGroupName(sGroupName)
    local bSafeCalled, mAllItems = safe_call(super(CRewardMgr).InitRewardItemList, self, oPlayer, lItemIdxs, mArgs)
    self:RestoreGroupName(iStackLen)
    return mAllItems
end

function CRewardMgr:RewardItemsByGroup(oPlayer, sGroupName, mAllItems, mArgs)
    local iStackLen = self:BackupGroupName(sGroupName)
    local bSafeCalled = safe_call(super(CRewardMgr).RewardItems, self, oPlayer, mAllItems, mArgs)
    self:RestoreGroupName(iStackLen)
end
