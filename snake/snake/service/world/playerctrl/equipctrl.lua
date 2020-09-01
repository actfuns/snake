--import module
local skynet = require "skynet"
local global = require "global"
local res = require "base.res"

local datactrl = import(lualib_path("public.datactrl"))

CEquipCtrl = {}
CEquipCtrl.__index = CEquipCtrl
inherit(CEquipCtrl, datactrl.CDataCtrl)

function CEquipCtrl:New(pid)
    local o = super(CEquipCtrl).New(self, {pid=pid})
    o:Init()
    return o
end

function CEquipCtrl:Init()
    self.m_mStrengthen = {}
    self.m_mStrengthenFail = {}
    self.m_mBreakLevel = {}
    self.m_iFuHunPoint = 0
end

function CEquipCtrl:Release()
    self.m_mStrengthen = {}
    self.m_mStrengthenFail = {}
    self.m_mBreakLevel = {}
    super(CEquipCtrl).Release(self) 
end

function CEquipCtrl:Save()
    local mData = {}

    mData["strengthen"] = {}
    for iPos, iLv in pairs(self.m_mStrengthen) do
        mData["strengthen"][db_key(iPos)] = iLv
    end

    mData["strengthen_fail_cnt"] = {}
    for iPos, iCnt in pairs(self.m_mStrengthenFail) do
        mData["strengthen_fail_cnt"][db_key(iPos)] = iCnt
    end

    mData["breaklevel"] = {}
    for iPos, iLv in pairs(self.m_mBreakLevel) do
        mData["breaklevel"][db_key(iPos)] = iLv
    end
    mData["fh_point"] = self.m_iFuHunPoint
    return mData
end

function CEquipCtrl:Load(mData)
    if not mData then return end

    for sPos, iVal in pairs(mData["strengthen"] or {}) do
        self.m_mStrengthen[tonumber(sPos)] = iVal
    end

    for sPos, iVal in pairs(mData["strengthen_fail_cnt"] or {}) do
        self.m_mStrengthenFail[tonumber(sPos)] = iVal
    end

    for sPos, iVal in pairs(mData["breaklevel"] or {}) do
        self.m_mBreakLevel[tonumber(sPos)] = iVal
    end
    self.m_iFuHunPoint = mData["fh_point"] or 0
end

function CEquipCtrl:OnLogin(oPlayer)
    self:GS2CEquipLogin(oPlayer)
end

function CEquipCtrl:GetPid()
    return self:GetInfo("pid")
end

function CEquipCtrl:GetStrengthenLevels()
    return self.m_mStrengthen
end

function CEquipCtrl:GetStrengthenLevel(iPos)
    return self.m_mStrengthen[iPos] or 0
end

function CEquipCtrl:SetStrengthenLevel(iPos, iLevel)
    local oPlayer = global.oWorldMgr:GetOnlinePlayerByPid(self:GetPid())
    if oPlayer then 
        oPlayer:PropChange("score")
    end
    self.m_mStrengthen[iPos] = iLevel
    self:Dirty() 
end

function CEquipCtrl:GetStrengthenFailCnt(iPos)
    return self.m_mStrengthenFail[iPos] or 0
end

function CEquipCtrl:SetStrengthenFailCnt(iPos, iCnt)
    self.m_mStrengthenFail[iPos] = iCnt
    self:Dirty()
end

function CEquipCtrl:GetBreakLevel(iPos)
    return self.m_mBreakLevel[iPos] or 0
end

function CEquipCtrl:SetBreakLevel(iPos, iLevel)
    self.m_mBreakLevel[iPos] = iLevel
    self:Dirty()
end

function CEquipCtrl:GetFuHunPoint()
    return self.m_iFuHunPoint
end

function CEquipCtrl:AddFuHunPoint(iPoint)
    self:Dirty()
    self.m_iFuHunPoint = math.max(self.m_iFuHunPoint + iPoint, 0)
end

function CEquipCtrl:RecFuHunPointReward(iChooseSid)
    local oWorldMgr = global.oWorldMgr
    local oPlayer = oWorldMgr:GetOnlinePlayerByPid(self:GetPid())
    if not oPlayer then return end

    local mPointData = res["daobiao"]["fuhunpoint"][oPlayer:GetGrade() // 10 * 10]
    local iNeedPoint = mPointData["point_limit"]
    if iNeedPoint <= 0 or iNeedPoint > self:GetFuHunPoint() then return end

    local mRewardItem = {}
    for _, mData in pairs(mPointData["reward"] or {}) do
        mRewardItem[mData["sid"]] = mData["num"]
    end
    for _, mData in pairs(mPointData["reward_choose"] or {}) do
        local iSid = mData["sid"]
        if iSid == iChooseSid then
            mRewardItem[iSid] = (mRewardItem[iSid] or 0) + mData["num"]    
        end
    end
    if table_count(mRewardItem) <= 0 then return end

    self:AddFuHunPoint(-iNeedPoint)
    self:GS2CUpdateFuHunPoint(oPlayer)
    for iSid, iAmount in pairs(mRewardItem) do
        oPlayer:RewardItems(iSid, iAmount, "领取附魂积分奖励")        
    end
end

function CEquipCtrl:GS2CEquipLogin(oPlayer)
    oPlayer:Send("GS2CEquipLogin", {
        fh_point=self:GetFuHunPoint()
    })
end

function CEquipCtrl:GS2CUpdateFuHunPoint(oPlayer)
    oPlayer:Send("GS2CUpdateFuHunPoint", {
        fh_point=self:GetFuHunPoint()
    })
end
