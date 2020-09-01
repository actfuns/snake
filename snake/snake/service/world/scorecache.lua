-- import module
local global = require "global"
local record = require "public.record"

function NewScoreCache(...)
    return CScoreCache:New(...)
end

CScoreCache = {}
CScoreCache.__index = CScoreCache

function CScoreCache:New()
    local o = setmetatable({}, self)
    o.m_mCache = {}
    o.m_mEquipCache = {}
    o.m_mSummonCache = {}
    o.m_mPartnerCache = {}
    o.m_mExclude = {}
    o.m_mRecordScore = {}
    return o
end

function CScoreCache:GetScore(oPlayer, mExclude)
    mExclude = mExclude or {}
    local iScore  = 0
    iScore = iScore + self:GetRoleScore(oPlayer)
    iScore = iScore + self:GetScoreByKey(oPlayer, "summonctrl")
    iScore = iScore + self:GetScoreByKey(oPlayer, "ridectrl")
    if not mExclude.partner then
        iScore = iScore + self:GetScoreByKey(oPlayer, "partnerctrl")
    end
    iScore = iScore + self:GetScoreByKey(oPlayer, "fabaoctrl")
    iScore = iScore + self:GetScoreByKey(oPlayer, "artifactctrl")
    iScore = iScore + self:GetScoreByKey(oPlayer, "wingctrl")
    iScore = math.floor(iScore)
    return iScore
end

function CScoreCache:GetRoleScore(oPlayer)
    local iScore = 0
    iScore = iScore + self:GetScoreByKey(oPlayer, "base")
    iScore = iScore + self:GetScoreByKey(oPlayer, "strength")
    iScore = iScore + self:GetScoreByKey(oPlayer, "fmt")
    iScore = iScore + self:GetScoreByKey(oPlayer, "huzhu")
    iScore = iScore + self:GetScoreByKey(oPlayer, "skill")
    iScore = iScore + self:GetScoreByKey(oPlayer, "equip")
    iScore = iScore + self:GetScoreByKey(oPlayer, "touxian")
    iScore = math.floor(iScore)
    return iScore
end

function CScoreCache:Dirty(iPid, sKey)
    local mCache = self.m_mCache[iPid]
    if not mCache then
        return
    end
    mCache[sKey] = nil
end

function CScoreCache:GetScoreByKey(oPlayer, sKey)
    local iPid = oPlayer:GetPid()
    if self.m_mExclude[iPid] then
        return self:CalScore(oPlayer, sKey)
    end
    local mCache = self.m_mCache[iPid]
    if not mCache then
        mCache = {}
        self.m_mCache[iPid] = mCache
    end
    if not mCache[sKey] then
        mCache[sKey] = self:CalScore(oPlayer, sKey)
    end
    return mCache[sKey]
end

function CScoreCache:CalScore(oPlayer, sKey)
    local iScore
    if sKey == "base" then
        iScore = 30 + oPlayer:GetGrade() * 30
    elseif sKey == "strength" then
        iScore = oPlayer.m_oEquipMgr:GetStrengthenMasterScore()
    elseif sKey == "fmt" then
        iScore = oPlayer.m_oBaseCtrl.m_oFmtMgr:GetScore()
    elseif sKey == "huzhu" then
        iScore = oPlayer.m_oPartnerCtrl:GetScoreByHuZu()
    elseif sKey == "skill" then
        iScore = oPlayer.m_oSkillCtrl:GetScore()
    elseif sKey == "equip" then
        iScore = oPlayer.m_oEquipMgr:GetScore()
    elseif sKey == "touxian" then
        iScore = oPlayer.m_oTouxianCtrl:GetScore()
    elseif sKey == "summonctrl" then
        iScore = oPlayer.m_oSummonCtrl:GetScore()
    elseif sKey == "ridectrl" then
        iScore = oPlayer.m_oRideCtrl:GetScore()
    elseif sKey == "partnerctrl" then
        iScore = oPlayer.m_oPartnerCtrl:GetScore()
    elseif sKey == "fabaoctrl" then
        iScore = oPlayer.m_oFaBaoCtrl:GetScore()
    elseif sKey == "artifactctrl" then
        iScore = oPlayer.m_oArtifactCtrl:GetScore()
    elseif sKey == "wingctrl" then
        iScore = oPlayer.m_oWingCtrl:GetScore()
    end

    self:RecordScore(oPlayer, sKey, iScore)
    return iScore
end

function CScoreCache:AddExclude(iPid)
    self.m_mExclude[iPid] = true
end

function CScoreCache:RemoveExclude(iPid)
    self.m_mExclude[iPid] = nil
end

function CScoreCache:EquipDirty(iID)
    self.m_mEquipCache[iID] = nil
end

function CScoreCache:GetEquipScore(oEquip)
    local id = oEquip:ID()
    if not self.m_mEquipCache[id] then
        self.m_mEquipCache[id] = oEquip:CalScore()
    end
    return self.m_mEquipCache[id]
end

function CScoreCache:SummonDirty(iID)
    self.m_mSummonCache[iID] = nil
end

function CScoreCache:GetSummonScore(oSummon)
    local id = oSummon:ID()
    if not self.m_mSummonCache[id] then
        self.m_mSummonCache[id] = oSummon:CalScore()
    end
    return self.m_mSummonCache[id]
end

function CScoreCache:PartnerDirty(iID)
    self.m_mPartnerCache[iID] = nil
end

function CScoreCache:GetPartnerScore(oPartner)
    local id = oPartner:GetID()
    if not self.m_mPartnerCache[id] then
        self.m_mPartnerCache[id] = oPartner:CalScore()
    end
    return self.m_mPartnerCache[id]
end

function CScoreCache:RecordScore(oPlayer, sKey, iScore)
    if is_production_env() then return end
    
    -- TODO 记录下评分变化, 查找正式服评分变化原因,log量有点多
    if not oPlayer then return end

    local iPid = oPlayer:GetPid()
    local mScore = self.m_mRecordScore[iPid]
    if not mScore then
        mScore = {}
        self.m_mRecordScore[iPid] = mScore
    end

    local iCurScore = mScore[sKey] or 0
    if iCurScore == iScore then return end

    mScore[sKey] = iScore
    record.log_db("player", "score", {
        pid = oPlayer:GetPid(),
        name = oPlayer:GetName(),
        grade = oPlayer:GetGrade(),
        score = iScore,
        sys = sKey,        
    })
end
