local skynet = require "skynet"
local global = require "global"

local gamedefines = import(lualib_path("public.gamedefines"))
local CBaseOfflineCtrl = import(service_path("offline.baseofflinectrl")).CBaseOfflineCtrl
local roplayer = import(service_path("rofighter.roplayer"))
local ropartner = import(service_path("rofighter.ropartner"))
local rosummon = import(service_path("rofighter.rosummon"))


CChallengeCtrl = {}
CChallengeCtrl.__index = CChallengeCtrl
inherit(CChallengeCtrl, CBaseOfflineCtrl)

function CChallengeCtrl:New(pid)
    local o = super(CChallengeCtrl).New(self, pid)
    o.m_sDbFlag = "Challenge"
    o.m_bIsAlwaysActive = false
    o.m_oRoFight = nil

    o.m_lFormation = {1,1}
    o.m_iSummon = 0
    o.m_lLineup = {}
    o.m_oRoSummon = nil
    o.m_mRoPartners = {}

    o.m_mTargets = {}
    o.m_mRobots = {}
    o.m_iDifficulty = nil
    o.m_lHasBeat = {}
    o.m_iDayNo = 0
    o.m_lExcludes = {}
    o.m_bHasInit = nil
    return o
end

function CChallengeCtrl:Release()
    if self.m_oRoFight then
        baseobj_safe_release(self.m_oRoFight)
        self.m_oRoFight = nil
    end
    if self.m_oRoSummon then
        baseobj_safe_release(self.m_oRoSummon)
        self.m_oRoSummon = nil
    end
    for _, oRoPartner in pairs(self.m_mRoPartners) do
        baseobj_safe_release(oRoPartner)
    end
    self.m_mRoPartners = {}
    super(CChallengeCtrl).Release(self)
end

function CChallengeCtrl:GetPid()
    return self:GetInfo("pid")
end

function CChallengeCtrl:Save()
    local mData = {}
    if self.m_oRoFight then
        mData.rofight = self.m_oRoFight:Save()
    end

    mData.formation = self.m_lFormation
    mData.summonno = self.m_iSummon
    mData.lineup = self.m_lLineup
    if self.m_oRoSummon then
        mData.rosummon = self.m_oRoSummon:Save()
    end
    local mRoPartners = {}
    for sid, oRoPartner in pairs(self.m_mRoPartners) do
        mRoPartners[db_key(sid)] = oRoPartner:Save()
    end
    mData.ropartners = mRoPartners

    mData.targets = self.m_mTargets
    mData.robots = self.m_mRobots
    mData.level = self.m_iDifficulty
    mData.beat = self.m_lHasBeat
    mData.dayno = self.m_iDayNo
    mData.exclude = self.m_lExcludes
    mData.hasinit = self.m_bHasInit
    return mData
end

function CChallengeCtrl:Load(mData)
    mData = mData or {}
    if mData.rofight then
        local oRoPlayer = roplayer.NewRoPlayer(self:GetInfo("pid"))
        oRoPlayer:Load(mData.rofight)
        self.m_oRoFight = oRoPlayer
    end

    self.m_lFormation = mData.formation or {1,1}
    self.m_iSummon = mData.summonno or 0
    self.m_lLineup = mData.lineup or {}
    if mData.rosummon and self.m_iSummon ~= 0 then
        local iPid = self:GetInfo("pid")
        local oRoSummon = rosummon.NewRoSummon(iPid, self.m_iSummon)
        oRoSummon:Load(mData.rosummon)
        self.m_oRoSummon = oRoSummon
    end
    local mPartners = {}
    if mData.ropartners then
        for sid, data in pairs(mData.ropartners) do
            local oRoPartner = ropartner.NewRoPartner(sid)
            oRoPartner:Load(data)
            mPartners[tonumber(sid)] = oRoPartner
        end
    end
    self.m_mRoPartners = mPartners

    self.m_mTargets = mData.targets or {}
    self.m_mRobots = mData.robots or {}
    self.m_iDifficulty = mData.level
    self.m_lHasBeat = mData.beat or {}
    self.m_iDayNo = mData.dayno
    self.m_lExcludes = mData.exclude or {}
    self.m_bHasInit = mData.hasinit
end

function CChallengeCtrl:GetDayNo()
    return self.m_iDayNo
end

function CChallengeCtrl:SetDayNo()
    self:Dirty()
    self.m_iDayNo = get_dayno()
end

function CChallengeCtrl:GetExcludes()
    local mExcludes = {}
    for _, iPid in ipairs(self.m_lExcludes) do
        mExcludes[iPid] = true
    end
    return mExcludes
end

function CChallengeCtrl:AddExcludes()
    self:Dirty()
    for level, infos in pairs(self.m_mTargets) do
        for _, v in ipairs(infos) do
            if v.type == gamedefines.JJC_TARGET_TYPE.PLAYER then
                table.insert(self.m_lExcludes, v.id)
            end
        end
    end
    local iEnough = #self.m_lExcludes - 30
    if iEnough > 0 then
        for i=1,iEnough do
            table.remove(self.m_lExcludes, 1)
        end
    end
end

function CChallengeCtrl:ResetTarget()
    self:SetDifficulty(nil)
    self:SetTargets({})
    self:SetRobots({})
    self:ClearBeat()
    self:SetDayNo()
end

function CChallengeCtrl:ClearBeat()
    self:Dirty()
    self.m_lHasBeat = {}
end

function CChallengeCtrl:SetBeat(iType, id)
    self:Dirty()
    table.insert(self.m_lHasBeat, {
        type = iType,
        id = id,
    })
end

function CChallengeCtrl:GetBeat()
    return self.m_lHasBeat
end

function CChallengeCtrl:HasBeat(iType, id)
    for _, info in ipairs(self.m_lHasBeat) do
        if info.type == iType and info.id == id then
            return true
        end
    end
    return false
end

function CChallengeCtrl:HasBeatAll()
    if #self.m_lHasBeat >= #self.m_mTargets[self.m_iDifficulty] then
        return true
    end
    return false
end

function CChallengeCtrl:HasTarget()
    return next(self.m_mTargets)
end

function CChallengeCtrl:SetTargets(mTargets)
    self:Dirty()
    self.m_mTargets = mTargets
    self:AddExcludes()
end

function CChallengeCtrl:GetTargets()
    return self.m_mTargets
end

function CChallengeCtrl:GetTargetsByLevel(level)
    return self.m_mTargets[level]
end

function CChallengeCtrl:GetTargetInfo(iType, id)
    if not self.m_mTargets[self.m_iDifficulty] then
        return
    end
    for _, info in ipairs(self.m_mTargets[self.m_iDifficulty]) do
        if info.type == iType and info.id == id then
            return info
        end
    end
end

function CChallengeCtrl:IsNowTarget(iType, id)
    local lTargets = self.m_mTargets[self.m_iDifficulty]
    if not lTargets then
        return false
    end
    local info = lTargets[#self.m_lHasBeat + 1]
    if not info then
        return false
    end
    return info.type == iType and info.id == id
end

function CChallengeCtrl:SetRobots(mRobots)
    self:Dirty()
    self.m_mRobots = mRobots
end

function CChallengeCtrl:GetRobotData(id)
    return self.m_mRobots[id]
end

function CChallengeCtrl:SetDifficulty(iLevel)
    self:Dirty()
    self.m_iDifficulty = iLevel
end

function CChallengeCtrl:GetDifficulty()
    return self.m_iDifficulty
end

function CChallengeCtrl:OnLogout(oPlayer)
    if oPlayer then
        self:SyncData(oPlayer)
    end
    super(CChallengeCtrl).OnLogout(self, oPlayer)
end

function CChallengeCtrl:CheckInitLineup(oPlayer)
    if not self.m_bHasInit then
        self:SyncLineupInfo(oPlayer)
        self:Dirty()
        self.m_bHasInit = true
    end
end

function CChallengeCtrl:SyncLineupInfo(oPlayer)
    local oFmtMgr = oPlayer:GetFormationMgr()
    local iFmtId = oFmtMgr:GetCurrFmt()
    if iFmtId and iFmtId ~= 1 then
        self:SetFormation(oPlayer, iFmtId)
    end
    local lEnter = oPlayer.m_oPartnerCtrl:GetCurrLineupPos()
    local lFighters = {}
    if lEnter then
        for _, id in ipairs(lEnter) do
            table.insert(lFighters, {type = 2, id = id})
        end
    end
    if lFighters then
        self:SetLineup(oPlayer, lFighters)
    end
    local oSummon = oPlayer.m_oSummonCtrl:GetFightSummon()
    if oSummon then
        self:SetSummon(oPlayer, oSummon.m_iID)
    end
end

function CChallengeCtrl:SyncData(oPlayer)
    self:SyncFightInfo(oPlayer)
    self:SyncSummonData(oPlayer)
    self:SyncPartnerInfo(oPlayer)
end

function CChallengeCtrl:SyncFightInfo(oPlayer)
    self:Dirty()
    local oRoPlayer = roplayer.NewRoPlayer(self:GetInfo("pid"))
    oRoPlayer:Init(oPlayer:PackRoData())
    self.m_oRoFight = oRoPlayer
end

function CChallengeCtrl:SyncSummonData(oPlayer)
    if self.m_iSummon then
        local iNo = self.m_iSummon
        local lTraceNo = {self:GetInfo("pid"), iNo}
        local oSummon = oPlayer.m_oSummonCtrl:GetSummonByTraceNo(lTraceNo)
        if oSummon then
            self:Dirty()
            self.m_oRoSummon:Init(oSummon:PackRoData(oPlayer))
        end
    end
end

function CChallengeCtrl:SyncPartnerInfo(oPlayer)
    self:Dirty()
    local mPartnerInfos = {}
    for _, mInfo in ipairs(self.m_lLineup) do
        if mInfo.type == gamedefines.JJC_FIGHTER_TYPE.PARTNER then
            local oPartner = oPlayer.m_oPartnerCtrl:QueryPartner(mInfo.id)
            if oPartner then 
                self.m_mRoPartners[mInfo.id]:Init(oPartner:PackRoData(oPlayer))
            end
        end
    end
end

function CChallengeCtrl:SetSummon(oPlayer, summid, bNotify)
    local oNotify = global.oNotifyMgr
    local oJJCMgr = global.oJJCMgr
    local oSummon = oPlayer.m_oSummonCtrl:GetSummon(summid)
    if not oSummon then
        self:UnsetSummon()
        if bNotify then
            oNotify:Notify(oPlayer:GetPid(), oJJCMgr:GetTextData(1017))
        end
        return
    end
    self:Dirty()
    local pid, iNo = table.unpack(oSummon:GetData("traceno", {}))
    self.m_iSummon = iNo
    local oRoSummon = rosummon.NewRoSummon(pid, iNo)
    oRoSummon:Init(oSummon:PackRoData(oPlayer))
    self.m_oRoSummon = oRoSummon
    if bNotify then
        oNotify:Notify(oPlayer:GetPid(), oJJCMgr:GetTextData(1026))
    end
end

function CChallengeCtrl:UnsetSummon()
    self:Dirty()
    self.m_iSummon = 0
    
    if self.m_oRoSummon then
        baseobj_delay_release(self.m_oRoSummon)
        self.m_oRoSummon = nil
    end
end

function CChallengeCtrl:OnReleaseSummon(traceno)
    local pid, iNo = table.unpack(traceno)
    if self.m_iSummon ~= iNo then
        return
    end
    self:UnsetSummon()
end

function CChallengeCtrl:SetFormation(oPlayer, iFormation)
    self:Dirty()
    local oFormationMgr = oPlayer:GetFormationMgr()
    local lv = oFormationMgr:GetGrade(iFormation)
    self.m_lFormation = {iFormation, lv}
end

function CChallengeCtrl:SetLineup(oPlayer, lFighters, bNotify)
    local oNotify = global.oNotifyMgr
    self:Dirty()
    local lLineup = {}
    local mPartners = {}
    local lOldFrd = self:GetFightFriends()
    local iOldPartners = table_count(self.m_mRoPartners)
    for _, oRoPartner in pairs(self.m_mRoPartners) do
        baseobj_delay_release(oRoPartner)
    end
    for _, mInfo in ipairs(lFighters) do
        if mInfo.type == gamedefines.JJC_FIGHTER_TYPE.PARTNER then
            local oPartner = oPlayer.m_oPartnerCtrl:GetPartner(mInfo.id)
            if oPartner then 
                local sid = oPartner:GetSID()
                table.insert(lLineup, {type=mInfo.type, id=sid})
                local oRoPartner = ropartner.NewRoPartner(sid)
                oRoPartner:Init(oPartner:PackRoData(oPlayer))
                mPartners[sid] = oRoPartner
            end
        else
            table.insert(lLineup, {type=mInfo.type, id=mInfo.id})
        end
    end

    self.m_lLineup = lLineup
    self.m_mRoPartners = mPartners

    if bNotify then
        local oJJCMgr = global.oJJCMgr
        local iNewPartners = table_count(mPartners)
        if iOldPartners > iNewPartners then
            oNotify:Notify(oPlayer:GetPid(), oJJCMgr:GetTextData(1016))
        elseif iOldPartners < iNewPartners then
            oNotify:Notify(oPlayer:GetPid(), oJJCMgr:GetTextData(1015))
        end

         local lNewFrd = self:GetFightFriends()
         if #lOldFrd < #lNewFrd then
            oNotify:Notify(oPlayer:GetPid(), oJJCMgr:GetTextData(1006))
        elseif #lOldFrd > #lNewFrd then
            oNotify:Notify(oPlayer:GetPid(), oJJCMgr:GetTextData(1027))
        end
    end
end

function CChallengeCtrl:GetPlayerLineup(bNoSelf)
    local lPlayers = {}
    if not bNoSelf then
        table.insert(lPlayers, self:GetInfo("pid"))
    end
    for _, mInfo in ipairs(self.m_lLineup) do
        if mInfo.type == gamedefines.JJC_FIGHTER_TYPE.PLAYER then
            table.insert(lPlayers, mInfo.id)
        end
    end
    return lPlayers
end

function CChallengeCtrl:GetPartnerLineup()
    local lPartners = {}
    for _, mInfo in ipairs(self.m_lLineup) do
        if mInfo.type == gamedefines.JJC_FIGHTER_TYPE.PARTNER then
            table.insert(lPartners, mInfo.id)
        end
    end
    return lPartners
end

function CChallengeCtrl:GetFormation()
    local iPid = self:GetInfo("pid")
    local iFmt, iGrade = table.unpack(self.m_lFormation)
    local mResult = {}
    mResult.grade = iGrade
    mResult.fmt_id = iFmt
    mResult.pid = iPid
    mResult.player_list = self:GetPlayerLineup()

    local oWorldMgr = global.oWorldMgr
    local oPlayer = oWorldMgr:GetOnlinePlayerByPid(iPid)
    if oPlayer then
        mResult.partner_list = self:GetFightPartnerIDs()
    else
        mResult.partner_list = self:GetPartnerLineup()
    end
    if table_count(mResult.player_list) + table_count(mResult.partner_list) < 5 then
        mResult.fmt_id = 1
        mResult.grade = 1
    end
    return mResult
end

function CChallengeCtrl:GetFightSummID()
    local iPid = self:GetInfo("pid")
    local oWorldMgr = global.oWorldMgr
    local oPlayer = oWorldMgr:GetOnlinePlayerByPid(iPid)
    if oPlayer and self.m_oRoSummon then
        local lTraceNo = self.m_oRoSummon:GetTraceNo()
        local oSummon = oPlayer.m_oSummonCtrl:GetSummonByTraceNo(lTraceNo)
        if oSummon then
            return oSummon.m_iID
        end
    end
end

function CChallengeCtrl:GetFightPartnerIDs()
    local iPid = self:GetInfo("pid")
    local oWorldMgr = global.oWorldMgr
    local oPlayer = oWorldMgr:GetOnlinePlayerByPid(iPid)

    local lPartnerIds = {}
    for _, mInfo in ipairs(self.m_lLineup) do
        if mInfo.type == gamedefines.JJC_FIGHTER_TYPE.PARTNER and oPlayer then
            local oPartner = oPlayer.m_oPartnerCtrl:QueryPartner(mInfo.id)
            if oPartner then
                table.insert(lPartnerIds, oPartner:GetID())
            end
        end
    end
    return lPartnerIds
end

function CChallengeCtrl:CheckRoFight(oPlayer)
    if not self.m_oRoFight then
        self:SyncFightInfo(oPlayer)
    end
end

function CChallengeCtrl:PackWarInfo()
    local oWorldMgr = global.oWorldMgr
    local oPlayer = oWorldMgr:GetOnlinePlayerByPid(self:GetInfo("pid"))
    if oPlayer then
        return oPlayer:PackRoData()
    else
        return self.m_oRoFight:PackWarInfo()
    end
end

function CChallengeCtrl:GetRoPlayerGrade()
    local oWorldMgr = global.oWorldMgr
    local oPlayer = oWorldMgr:GetOnlinePlayerByPid(self:GetInfo("pid"))
    if oPlayer then
        return oPlayer:GetGrade()
    else
        return self.m_oRoFight:GetGrade()
    end
end

function CChallengeCtrl:PacketSummonWarInfo()
    local oWorldMgr = global.oWorldMgr
    if self.m_oRoSummon then
        local oPlayer = oWorldMgr:GetOnlinePlayerByPid(self:GetInfo("pid"))
        if oPlayer then
            local lTraceNo = self.m_oRoSummon:GetTraceNo()
            local oSummon = oPlayer.m_oSummonCtrl:GetSummonByTraceNo(lTraceNo)
            if oSummon then
                return oSummon:PackRoData(oPlayer)
            end
        end
        return self.m_oRoSummon:PackWarInfo()
    end
end

function CChallengeCtrl:GetFightFriends()
    local lPlayers = {}
    for _, mInfo in ipairs(self.m_lLineup) do
        if mInfo.type == gamedefines.JJC_FIGHTER_TYPE.PLAYER then
            table.insert(lPlayers, mInfo.id)
        end
    end
    return lPlayers
end

function CChallengeCtrl:PackPartnerWarInfo()
    local lWarInfo = {}
    local oWorldMgr = global.oWorldMgr
    local oPlayer = oWorldMgr:GetOnlinePlayerByPid(self:GetInfo("pid"))
    if oPlayer then
        for _, mInfo in ipairs(self.m_lLineup) do
            if mInfo.type == gamedefines.JJC_FIGHTER_TYPE.PARTNER then
                local oPartner = oPlayer.m_oPartnerCtrl:QueryPartner(mInfo.id)
                assert(oPartner, string.format("challenge player online get partner err: %s %s", self:GetInfo("pid"), mInfo.id))
                table.insert(lWarInfo, oPartner:PackRoData(oPlayer))
            end
        end
    else
        for _, mInfo in ipairs(self.m_lLineup) do
            if mInfo.type == gamedefines.JJC_FIGHTER_TYPE.PARTNER then
                table.insert(lWarInfo, self.m_mRoPartners[mInfo.id]:PackWarInfo())
            end
        end
    end
    return lWarInfo
end

function CChallengeCtrl:IsActive()
    if self.m_bIsAlwaysActive then
        return true
    end
    return super(CChallengeCtrl).IsActive(self)
end

function CChallengeCtrl:SetAlwaysActive(bActive)
    self.m_bIsAlwaysActive = bActive
end

function CChallengeCtrl:PacketLineupInfo()
    local oWorldMgr = global.oWorldMgr
    local oPlayer = oWorldMgr:GetOnlinePlayerByPid(self:GetInfo("pid"))

    local mData = {}
    mData.fmtid, mData.fmtlv = table.unpack(self.m_lFormation)
    if oPlayer then
        local oFormationMgr = oPlayer:GetFormationMgr()
        mData.fmtlv = oFormationMgr:GetGrade(mData.fmtid)
    end

    if self.m_oRoSummon then
        mData.summicon = self.m_oRoSummon:GetIcon()
        mData.summlv = self.m_oRoSummon:GetGrade()
    end

    if oPlayer and self.m_oRoSummon then
        local lTraceNo = self.m_oRoSummon:GetTraceNo()
        local oSummon = oPlayer.m_oSummonCtrl:GetSummonByTraceNo(lTraceNo)
        if oSummon then
            mData.summid = oSummon.m_iID
            mData.summicon = oSummon:Shape()
            mData.summlv = oSummon:GetGrade()
        end
    end

    local lPartners = {}
    for _, mInfo in ipairs(self.m_lLineup) do
        local mFighter = {}
        mFighter.type = mInfo.type
        if mInfo.type == gamedefines.JJC_FIGHTER_TYPE.PARTNER then
            local oRoPartner = self.m_mRoPartners[mInfo.id]
            mFighter.icon = oRoPartner:GetIcon()
            mFighter.lv = oRoPartner:GetGrade()
            mFighter.quality = oRoPartner:GetQuality()
            if oPlayer then
                local oPartner = oPlayer.m_oPartnerCtrl:QueryPartner(mInfo.id)
                if oPartner then
                    mFighter.id = oPartner:GetID()
                    mFighter.lv = oPartner:GetGrade()
                end
            end
        else
            local oWorldMgr = global.oWorldMgr
            local oFriendPlayer = oWorldMgr:GetOnlinePlayerByPid(mInfo.id)
            if oFriendPlayer then
                mFighter.id = mInfo.id
                mFighter.icon = oFriendPlayer:GetIcon()
                mFighter.lv = oFriendPlayer:GetGrade()
            else
                local oProfile = oWorldMgr:GetProfile(mInfo.id)
                if oProfile then
                    mFighter.id = mInfo.id
                    mFighter.icon = oProfile:GetIcon()
                    mFighter.lv = oProfile:GetGrade()
                end
            end
        end
        table.insert(lPartners, mFighter)
    end
    mData.fighters = lPartners
    return mData
end

function CChallengeCtrl:PacketWarKeepSummon()
    --AI 可以召唤的召唤兽
    return {}
end
