
-- import module
local global = require "global"
local extend = require "base.extend"

local datactrl = import(lualib_path("public.datactrl"))
local tableop = import(lualib_path("base.tableop"))
local loadpartner = import(service_path("partner.loadpartner"))
local gamedefines = import(lualib_path("public.gamedefines"))


CPartnerCtrl = {}
CPartnerCtrl.__index = CPartnerCtrl
inherit(CPartnerCtrl, datactrl.CDataCtrl)

function CPartnerCtrl:New(pid)
    local o = super(CPartnerCtrl).New(self, {pid = pid})
    o.m_mPartners = {}
    o.m_mLineup = {}
    o.m_iLineup = 1
    return o
end

function CPartnerCtrl:Release()
    for _, oPartner in pairs(self.m_mPartners) do
        baseobj_safe_release(oPartner)
    end
    self.m_mPartners = {}
    super(CPartnerCtrl).Release(self)
end

function CPartnerCtrl:Save()
    local mData = self:SaveLineup()
    
    local mPartnerData = {}
    for k, o in pairs(self.m_mPartners) do
        table.insert(mPartnerData, o:Save())
    end
    mData.partnerdata = mPartnerData

    return mData
end

function CPartnerCtrl:SaveLineup()
    local mLineup = {}
    for iIdx, mInfo in pairs(self.m_mLineup) do
        local sIdx = tostring(iIdx)
        mLineup[sIdx] = {}
        local lPidList = mInfo.pos_list or {}
        local lSidList = self:TransPidToSid(lPidList)
        mLineup[sIdx].pos_list = lSidList
        mLineup[sIdx].fmt_id = mInfo.fmt_id
    end
    
    local mData = {}
    mData.lineup_curr = self.m_iLineup
    mData.lineup_info = mLineup
    return mData
end

function CPartnerCtrl:Load(mData)
    mData = mData or {}
    local mPartnerData = mData.partnerdata or {}
    local iPid = self:GetInfo("pid")
    for _, data in ipairs(mPartnerData) do
        local sid = data["sid"]
        local o = loadpartner.LoadPartner(sid, iPid, data)
        assert(o, string.format("partner sid err: %d, %d", iPid, sid))
        self.m_mPartners[o:GetID()] = o
    end

    self:LoadLineup(mData)
end

function CPartnerCtrl:LoadLineup(m)
    local mLineup = {}
    for sKey, mInfo in pairs(m.lineup_info or {}) do
        local lSidList = mInfo.pos_list or {}
        local lPidList = self:TransSidToPid(lSidList)
        local mTmp = {}
        mTmp.pos_list = lPidList
        mTmp.fmt_id = mInfo.fmt_id
        mLineup[tonumber(sKey)] = mTmp
    end
    
    self.m_iLineup = m.lineup_curr or 1
    self.m_mLineup = mLineup
end

function CPartnerCtrl:PreLogin(oPlayer, bReEnter)
    if not bReEnter then
        self:SynclSumData(oPlayer)
    end
end

function CPartnerCtrl:OnLogin(oPlayer, bReEnter)
    local mData = {}
    for ipn, oPartner in pairs(self.m_mPartners) do
        table.insert(mData, oPartner:PartnerInfo())
    end

    local mNet = {}
    mNet["partners"] = mData
    mNet["lineup"] = self:GetCurrLineup()
    mNet["pos_list"] = self:GetCurrLineupPos()
    if oPlayer then
        oPlayer:Send("GS2CLoginPartner", mNet)
    end
end

function CPartnerCtrl:OnUpGrade(oPlayer, iPlayerGrade)
    for ipn, oPartner in pairs(self.m_mPartners) do
        safe_call(oPartner.UpGradeByPlayerGrade, oPartner, iPlayerGrade)
    end
end

function CPartnerCtrl:GetAllPartner()
    return self.m_mPartners
end

function CPartnerCtrl:GetPartner(ipn)
    return self.m_mPartners[ipn]
end

function CPartnerCtrl:AddPartner(o)
    if not o then
        return false
    end
    local iSid = o:GetSID()
    if self:QueryPartner(iSid) then
        return false
    end
    local iPid = self:GetInfo("pid")
    self.m_mPartners[o:GetID()] = o
    global.oScoreCache:Dirty(iPid, "partnerctrl")
    self:GS2CAddPartner(o)
    self:AutoUpline(o)

    local oPlayer = global.oWorldMgr:GetOnlinePlayerByPid(iPid)
    if oPlayer then
        o:UpGradeByPlayerGrade(oPlayer:GetGrade())
        oPlayer:Send("GS2CShowNpcCloseup", {parnter = o:GetSID()})
        oPlayer:PropChange("score")
        if table_count(self.m_mPartners)>=4 then
            oPlayer:MarkGrow(5)
        end
    end
    return true
end

function CPartnerCtrl:QueryPartner(sid)
    for ipn, o in pairs(self.m_mPartners) do
        if o:GetSID() == sid then
            return o
        end
    end
end

function CPartnerCtrl:GetApply(sAttr)
    local idx = self:GetCurrLineup()
    if not self.m_mLineup[idx] then
        return 0
    end
    
    local iRet = 0
    for _, iPid in pairs(self.m_mLineup[idx].pos_list or {}) do
        local oPartner = self:GetPartner(iPid)
        if oPartner and iRet < oPartner:GetOwnerApply(sAttr) then
            iRet = oPartner:GetOwnerApply(sAttr)
        end
    end
    return iRet
end

function CPartnerCtrl:GetAllOwnerApply()
    local mAllApply = {}
    local idx = self:GetCurrLineup()
    if not self.m_mLineup[idx] then
        return mAllApply
    end
    
    for _, iPid in pairs(self.m_mLineup[idx].pos_list or {}) do
        local oPartner = self:GetPartner(iPid)
        if not oPartner then goto continue end

        for sKey, iVal in pairs(oPartner:GetAllOwnerApply()) do
            if not mAllApply[sKey] then
                mAllApply[sKey] = iVal
            else
                if iVal > mAllApply[sKey] then
                    mAllApply[sKey] = iVal
                end
            end
        end
        ::continue::
    end
    return mAllApply
end

function CPartnerCtrl:IsDirty()
    local bDirty = super(CPartnerCtrl).IsDirty(self)
    if bDirty then
        return true
    end
    for k, o in pairs(self.m_mPartners) do
        if o:IsDirty() then
            return true
        end
    end
    return false
end

function CPartnerCtrl:UnDirty()
    super(CPartnerCtrl).UnDirty(self)
    for k, o in pairs(self.m_mPartners) do
        o:UnDirty()
    end
end

function CPartnerCtrl:GetPlayer()
    local iPid = self:GetInfo("pid")
    local oWorldMgr = global.oWorldMgr
    return oWorldMgr:GetOnlinePlayerByPid(iPid)
end

function CPartnerCtrl:GS2CAddPartner(o)
    local oPlayer = self:GetPlayer()
    if oPlayer then
        local mNet = {}
        mNet["partner"] = o:PartnerInfo()
        oPlayer:Send("GS2CAddPartner", mNet)
    end
end

--新阵容系统
function CPartnerCtrl:TransSidToPid(lSidList)
    local mResult = {}
    for _, iSid in ipairs(lSidList) do
        local oPartner = self:QueryPartner(iSid)
        if oPartner then
            table.insert(mResult, oPartner:GetID())
        end
    end
    return mResult
end

function CPartnerCtrl:TransPidToSid(lPidList)
    local mResult = {}
    for _, iPid in ipairs(lPidList) do
        local oPartner = self:GetPartner(iPid)
        if oPartner then
            table.insert(mResult, oPartner:GetSID())
        end
    end
    return mResult
end

function CPartnerCtrl:GetCurrLineup()
    return self.m_iLineup or 1
end

function CPartnerCtrl:IsLineupFull()
    return table_count(self.m_mLineup) >= 3
end

function CPartnerCtrl:ValidSetLineup(idx, lPidList, iFmt)
    if idx<1 or idx>3 then return false end
    
    if not lPidList or #lPidList > 4 then 
        return false
    end

    local oPlayer = self:GetPlayer()
    if not oPlayer then return false end
    
    local oFmtMgr = oPlayer:GetFormationMgr()
    if not oFmtMgr:GetFmtObj(iFmt) then
        return false
    end
    
    for _, iPid in ipairs(lPidList) do
        if not self:GetPartner(iPid) then
            return false
        end
    end
    
    return true
end

function CPartnerCtrl:SetLineup(idx, lPidList, iFmt, iForbid)
    if not self:ValidSetLineup(idx, lPidList, iFmt) then
        return
    end

    local lOldPosList = self:GetCurrLineupPos()
    local mOldOwnerApply = self:GetAllOwnerApply()
    
    local mData = {
        ["pos_list"]    = lPidList,
        ["fmt_id"]      = iFmt,
    }
    self.m_mLineup[idx] = mData
    self:Dirty()
    global.oScoreCache:Dirty(self:GetInfo("pid"), "huzhu")
    self:RefreshSingleLineupInfo(idx)

    if self:GetCurrLineup() == idx then
        self:SetCurrFmt(iFmt)
    end
    self:BroadCastPartner2Team(lOldPosList, iForbid)

    for sKey, v in pairs(mOldOwnerApply) do
        mOldOwnerApply[sKey] = 0
    end
    local mRefresh = table_combine(mOldOwnerApply, self:GetAllOwnerApply())
    mRefresh["score"] = 1
    self:RefreshPlayerProp(mRefresh)
end

function CPartnerCtrl:AutoUpline(oPartner)
    if table_count(self.m_mPartners) > 4 then
        return
    end

    local idx = self:GetCurrLineup()
    if not self.m_mLineup[idx] then
        self.m_mLineup[idx] = {}
    end

    local lPosList = self:GetCurrLineupPos() or {}
    if #lPosList >= 4 then return end

    table.insert(lPosList, oPartner:GetID())
    self.m_mLineup[idx]["pos_list"] = lPosList
    self.m_mLineup[idx]["fmt_id"] = self.m_mLineup[idx]["fmt_id"] or 1
    self:Dirty()
    global.oScoreCache:Dirty(self:GetInfo("pid"), "huzhu")
    self:RefreshSingleLineupInfo(idx)
    self:BroadCastPartner2Team()
    self:RefreshPlayerProp()
end

function CPartnerCtrl:BroadCastPartner2Team(lOldPosList, iForbid)
    lOldPosList = lOldPosList or {}
    local oPlayer = self:GetPlayer()
    local lNewPosList = self:GetCurrLineupPos()
    if oPlayer:IsTeamLeader() and lNewPosList then
        local lPartner = {}
        for _, iPid in ipairs(lNewPosList) do
            if not table_in_list(lOldPosList, iPid) then
                table.insert(lPartner, iPid)
            end
        end
        local oTeam = oPlayer:HasTeam()
        if #lPartner > 0 then
            oTeam:BroadCastTeamPartners(lPartner)
        end
        if not iForbid then
            oTeam:BroadCastTeamAllPos()
        end
    end
end

function CPartnerCtrl:SetCurrFmt(iFmt)
    local oPlayer = self:GetPlayer()
    if oPlayer then
        local oFmtMgr = oPlayer:GetFormationMgr()
        oFmtMgr:SetCurrFmt(iFmt)
    end
end

function CPartnerCtrl:SetCurrLineup(idx)
    assert(idx>0 and idx<4, string.format("illegal curr_lineup %d", idx))

    local mOldOwnerApply = self:GetAllOwnerApply()
    local lOldPosList = self:GetCurrLineupPos()
    self.m_iLineup = idx
    self:Dirty()
    local oPlayer = self:GetPlayer()
    oPlayer:Send("GS2CSetCurrLineup", {lineup=idx})
   
    local mData = self.m_mLineup[idx]
    if mData then
        local iFmt = mData.fmt_id or 1
        self:SetCurrFmt(iFmt)
        self:BroadCastPartner2Team(lOldPosList)
    end
    global.oScoreCache:Dirty(self:GetInfo("pid"), "huzhu")

    for sKey, v in pairs(mOldOwnerApply) do
        mOldOwnerApply[sKey] = 0
    end
    local mRefresh = table_combine(mOldOwnerApply, self:GetAllOwnerApply())
    mRefresh["score"] = 1
    self:RefreshPlayerProp(mRefresh)
end

function CPartnerCtrl:SetCurrLineupFmt(iFmt)
    local idx = self.m_iLineup
    if self.m_mLineup[idx] then
        self.m_mLineup[idx].fmt_id = iFmt
    else
        self.m_mLineup[idx] = {fmt_id = iFmt}
    end
    self:Dirty()
    global.oScoreCache:Dirty(self:GetInfo("pid"), "huzhu")
end

function CPartnerCtrl:GetCurrLineupPos()
    local idx = self:GetCurrLineup()
    return table_get_depth(self.m_mLineup, {idx, "pos_list"})
end

function CPartnerCtrl:RefreshAllLineupInfo()
    local oPlayer = self:GetPlayer()
    if not oPlayer then return end

    local mNet = {}
    mNet.curr_lineup = self:GetCurrLineup()
    local mResult = {}
    for idx, mInfo in pairs(self.m_mLineup) do
        local mTmp = {}
        mTmp.fmt_id = mInfo.fmt_id
        mTmp.lineup = idx
        mTmp.pos_list = mInfo.pos_list
        table.insert(mResult, mTmp)
    end
    mNet.info = mResult
    oPlayer:Send("GS2CAllLineupInfo", mNet)
end

function CPartnerCtrl:RefreshSingleLineupInfo(idx)
    local oPlayer = self:GetPlayer()
    if not oPlayer then return end
    
    local mInfo = self.m_mLineup[idx]
    if not mInfo then return end

    local mNet = {}
    mNet.curr_lineup = self:GetCurrLineup()
    mNet.info = {}
    mNet.info.lineup = idx
    mNet.info.fmt_id = mInfo.fmt_id
    mNet.info.pos_list = mInfo.pos_list
    oPlayer:Send("GS2CSingleLineupInfo", mNet)
end

function CPartnerCtrl:PackTeamPartners(lPartner)
    lPartner = lPartner or self:GetCurrLineupPos()
    if not lPartner or #lPartner < 1 then return end

    local mNet = {}
    for idx, iPartner in ipairs(lPartner) do
        local oPartner = self:GetPartner(iPartner)
        if oPartner then
            local mPartner = {}
            mPartner.id = oPartner:GetID()
            mPartner.sid = oPartner:GetSID()
            mPartner.grade = oPartner:GetGrade()
            mPartner.model_info = oPartner:GetModelInfo()
            table.insert(mNet, mPartner)
        end
    end
    return mNet
end

function CPartnerCtrl:GetScore(bForce)
    local iLimit = 4
    local iScore = 0
    local lPartnerScore = {}
    if table_count(self.m_mPartners)<=iLimit then
        for _,oPartner in pairs(self.m_mPartners) do
            iScore = iScore + oPartner:GetScore(bForce)
        end
    else
        for _,oPartner in pairs(self.m_mPartners) do
            table.insert(lPartnerScore,oPartner:GetScore(bForce))
        end
        table.sort(lPartnerScore,function (a,b)
            return a>b
        end)
        for i=1,iLimit do
            iScore = iScore + lPartnerScore[i]
        end
    end
    iScore = math.floor(iScore)
    return iScore
end

function CPartnerCtrl:GetScoreByHuZu()
    local lPosList = self:GetCurrLineupPos() or {}
    local iScore = 0
    if not next(lPosList) then 
        return iScore
    end
    for _,iPartnerID in ipairs(lPosList) do
        local oPartner = self:GetPartner(iPartnerID)
        if oPartner then
            iScore = iScore +  oPartner:GetScoreByHuZu()
        end
    end
    return iScore
end

function CPartnerCtrl:SynclSumData(oPlayer, mProp)
    local mAllProp = self:GetAllOwnerApply()
    if mProp and next(mProp) then
        for sAttr, _ in pairs(mProp) do
            local iVal = mAllProp[sAttr] or 0
            oPlayer:SynclSumSet(gamedefines.SUM_DEFINE.MO_PARTNER,sAttr,iVal)
        end
    else
        for sAttr,value in pairs(mAllProp) do
            oPlayer:SynclSumSet(gamedefines.SUM_DEFINE.MO_PARTNER,sAttr,value)
        end
    end
end

function CPartnerCtrl:RefreshPlayerProp(mProp)
    local oPlayer = self:GetPlayer()
    if not oPlayer then return end
    self:SynclSumData(oPlayer,mProp)

    if mProp then
        if mProp["max_hp"] or mProp["max_mp"] then
            oPlayer:CheckAttr()
            mProp["hp"] = 1
            mProp["mp"] = 1
        end
        for _, sKey in ipairs({"mag_hit_res_ratio", "phy_hit_res_ratio"}) do
            mProp[sKey] = nil
        end
    end
    mProp = mProp or self:GetAllOwnerApply()
    oPlayer:PropChange(table.unpack(table_key_list(mProp)))
end

function CPartnerCtrl:PackBackendInfo()
    local mData = {}
    
    local mPartnerData = {}
    for k, o in pairs(self.m_mPartners) do
        table.insert(mPartnerData, o:PackBackendInfo())
    end
    mData.partnerdata = mPartnerData
    return mData
end

function CPartnerCtrl:FireUseUpgradeProp(oPartner, iItemSid)
    self:TriggerEvent(gamedefines.EVENT.PARTNER_USE_UPGRADE_PROP, {partner = oPartner, itemsid = iItemSid})
end

function CPartnerCtrl:FireUpgradeSkill(oPartner, oSk, iNewLv)
    self:TriggerEvent(gamedefines.EVENT.PARTNER_SKILL_UPGRADE, {partner = oPartner, skill = oSk, newlv = iNewLv})
end

function CPartnerCtrl:FireIncreaseUpper(oPartner, iNewUpper)
    self:TriggerEvent(gamedefines.EVENT.PARTNER_INCREASE_UPPER, {partner = oPartner, newupper = iNewUpper})
end

function CPartnerCtrl:FireIncreaseQuality(oPartner, iNewQuality)
    self:TriggerEvent(gamedefines.EVENT.PARTNER_INCREASE_QUALITY, {partner = oPartner, newquality = iNewQuality})
end
