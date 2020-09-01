local skynet = require "skynet"
local global = require "global"

local gamedefines = import(lualib_path("public.gamedefines"))
local datactrl = import(lualib_path("public.datactrl"))
local roplayer = import(service_path("rofighter.roplayer"))
local ropartner = import(service_path("rofighter.ropartner"))
local rosummon = import(service_path("rofighter.rosummon"))

function NewWarDataCtrl(...)
    return CWarDataCtrl:New(...)
end

CWarDataCtrl = {}
CWarDataCtrl.__index = CWarDataCtrl
inherit(CWarDataCtrl, datactrl.CDataCtrl)

function CWarDataCtrl:New(pid)
    local o = super(CWarDataCtrl).New(self, {pid=pid})
    o.m_oRoFight = nil
    o.m_lFormation = {1,1}
    o.m_iFightSummon = nil
    o.m_mRoSummons = {}
    o.m_lLineup = {}
    o.m_mRoPartners = {}
    return o
end

function CWarDataCtrl:IsDirty()
    return super(CWarDataCtrl).IsDirty(self)
end

function CWarDataCtrl:Release()
    if self.m_oRoFight then
        baseobj_safe_release(self.m_oRoFight)
    end
    for _, oRoPartner in pairs(self.m_mRoPartners) do
        baseobj_safe_release(oRoPartner)
    end
    for _, oRoSummon in pairs(self.m_mRoSummons) do
        baseobj_safe_release(oRoSummon)
    end

    self.m_mRoPartners = {}
    self.m_mRoSummons = {}
    super(CWarDataCtrl).Release(self)
end

function CWarDataCtrl:Save()
    local mData = {}
    mData.formation = self.m_lFormation
    mData.fight_summon = self.m_iFightSummon
    mData.lineup = self.m_lLineup

    if self.m_oRoFight then
        mData.rofight = self.m_oRoFight:Save()
    end

    local mPartners = {}
    for sid, oRoPartner in pairs(self.m_mRoPartners) do
        mPartners[db_key(sid)] = oRoPartner:Save()
    end
    mData.ropartners = mPartners

    local mSummons = {}
    for iTraceNo, oRoSummon in pairs(self.m_mRoSummons) do
        mSummons[db_key(iTraceNo)] = oRoSummon:Save()
    end
    mData.rosummons = mSummons
    return mData
end

function CWarDataCtrl:Load(mData)
    if not mData then return end

    self.m_lFormation = mData.formation or {1,1}
    self.m_iFightSummon = mData.fight_summon
    self.m_lLineup = mData.lineup

    if mData.rofight then
        local oRoPlayer = roplayer.NewRoPlayer(self:GetPid())
        oRoPlayer:Load(mData.rofight)
        self.m_oRoFight = oRoPlayer
    end

    for iTraceNo, mSummon in pairs(mData.rosummons or {}) do
        local oRoSummon = rosummon.NewRoSummon(self:GetPid(), iTraceNo)
        oRoSummon:Load(mSummon)
        self.m_mRoSummons[tonumber(iTraceNo)] = oRoSummon
    end

    for sid, data in pairs(mData.ropartners or {}) do
        local oRoPartner = ropartner.NewRoPartner(sid)
        oRoPartner:Load(data)
        self.m_mRoPartners[tonumber(sid)] = oRoPartner
    end
end

function CWarDataCtrl:GetPid()
    return self:GetInfo("pid")
end

function CWarDataCtrl:OnLogout(oPlayer)
    if oPlayer then
        self:SyncData(oPlayer)
    end
end

function CWarDataCtrl:SyncData(oPlayer)
    self:SyncFightInfo(oPlayer)
    self:SyncSummonData(oPlayer)
    self:SyncPartnerData(oPlayer)
    self:SyncFormation(oPlayer)
    self:SyncLineup(oPlayer)
end

function CWarDataCtrl:SyncFightInfo(oPlayer)
    if not self.m_oRoFight then
        self.m_oRoFight = roplayer.NewRoPlayer(self:GetPid())
    end
    self.m_oRoFight:Init(oPlayer:PackRoData())
    self:Dirty()
end

function CWarDataCtrl:SetFightSummon(iTraceNo)
    self.m_iFightSummon = iTraceNo
    self:Dirty()
end

function CWarDataCtrl:SyncSummonData(oPlayer, iTraceNo)
    if not iTraceNo then
        local oSummon = oPlayer.m_oSummonCtrl:GetFightSummon()
        if oSummon then
            local pid, iNo = table.unpack(oSummon:GetData("traceno", {}))
            self.m_iFightSummon = iNo
        end
        self.m_mRoSummons = {}
        local mSummons = oPlayer.m_oSummonCtrl:SummonList()
        for iSummon, oSummon in pairs(mSummons) do
            local pid, iNo = table.unpack(oSummon:GetData("traceno", {}))
            local oRoSummon = rosummon.NewRoSummon(pid, iNo)
            oRoSummon:Init(oSummon:PackRoData(oPlayer))
            self.m_mRoSummons[iNo] = oRoSummon
        end
    else
        local mTrace = {oPlayer:GetPid(), iTraceNo}
        local oSummon = oPlayer.m_oSummonCtrl:GetSummonByTraceNo(mTrace)
        if not oSummon then
            if iTraceNo == self.m_iFightSummon then
                self.m_iFightSummon = nil
            end
            local oRoSummon = self.m_mRoSummons[iTraceNo]
            if oRoSummon then
                baseobj_delay_release(oRoSummon)
                self.m_mRoSummons[iTraceNo] = nil
            end
        else
            if not self.m_mRoSummons[iTraceNo] then
                local oRoSummon = rosummon.NewRoSummon(pid, iNo)
                self.m_mRoSummons[iTraceNo] = oRoSummon
            end
            self.m_mRoSummons[iTraceNo]:Init(oSummon:PackRoData(oPlayer))
        end
    end
    self:Dirty()
end

function CWarDataCtrl:SyncPartnerData(oPlayer)
    local mAllPartners = oPlayer.m_oPartnerCtrl:GetAllPartner()
    for _, oPartner in pairs(mAllPartners) do
        local iSid = oPartner:GetSID()
        local oRoPartner = ropartner.NewRoPartner(iSid)
        oRoPartner:Init(oPartner:PackRoData(oPlayer))
        self.m_mRoPartners[iSid] = oRoPartner
    end
    self:Dirty()
end

function CWarDataCtrl:SyncLineup(oPlayer)
    local mData = oPlayer.m_oPartnerCtrl:SaveLineup()
    local sCurrLineup = tostring(mData.lineup_curr)
    if mData.lineup_info[sCurrLineup] then
        self.m_lLineup = mData.lineup_info[sCurrLineup].pos_list
    else
        self.m_lLineup = {}
    end
    self:Dirty()
end

function CWarDataCtrl:SyncFormation(oPlayer)
    local oFmtMgr = oPlayer:GetFormationMgr()
    local oFmtObj = oFmtMgr:GetCurrFmtObj()
    self.m_lFormation = {oFmtObj:GetId(), oFmtObj:GetGrade()}
    self:Dirty()
end

function CWarDataCtrl:GetFmtAndGrade()
    return table.unpack(self.m_lFormation)
end

function CWarDataCtrl:GetFormation()
    local iPid = self:GetPid()
    local iFmt, iGrade = table.unpack(self.m_lFormation)
    local mResult = {}
    mResult.grade = iGrade
    mResult.fmt_id = iFmt
    mResult.pid = iPid
    mResult.player_list = {iPid,}
    mResult.partner_list = self.m_lLineup
    if table_count(mResult.player_list) + table_count(mResult.partner_list) < 5 then
        mResult.fmt_id = 1
        mResult.grade = 1
    end
    return mResult
end

function CWarDataCtrl:PackWarInfo()
    return self.m_oRoFight:PackWarInfo()
end

function CWarDataCtrl:PacketSummonWarInfo()
    if self.m_iFightSummon and self.m_mRoSummons[self.m_iFightSummon] then
        return self.m_mRoSummons[self.m_iFightSummon]:PackWarInfo()
    end
end

function CWarDataCtrl:PacketWarKeepSummon()
    local mSummon, iTotal = {}, 4
    local iGradeLimit = self.m_oRoFight:GetGrade() + 10
    for iNo, oRoSummon in pairs(self.m_mRoSummons or {}) do
        if iNo ~= self.m_iFightSummon and oRoSummon:GetGrade() <= iGradeLimit then
            mSummon[iNo] = oRoSummon:PackWarInfo()
            iTotal = iTotal - 1
        end
        if iTotal <= 0 then break end
    end
    return mSummon
end

function CWarDataCtrl:PackPartnerWarInfo()
    local lPartnerInfo = {}
    for _, sid in ipairs(self.m_lLineup) do
        table.insert(lPartnerInfo, self.m_mRoPartners[sid]:PackWarInfo())
    end
    return lPartnerInfo
end
