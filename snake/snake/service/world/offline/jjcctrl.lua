local skynet = require "skynet"
local global = require "global"
local res = require "base.res"

local CBaseOfflineCtrl = import(service_path("offline.baseofflinectrl")).CBaseOfflineCtrl
local roplayer = import(service_path("rofighter.roplayer"))
local ropartner = import(service_path("rofighter.ropartner"))
local rosummon = import(service_path("rofighter.rosummon"))
local gamedefines = import(lualib_path("public.gamedefines"))


CJJCCtrl = {}
CJJCCtrl.__index = CJJCCtrl
inherit(CJJCCtrl, CBaseOfflineCtrl)

function CJJCCtrl:New(pid)
    local o = super(CJJCCtrl).New(self, pid)
    o.m_sDbFlag = "JJC"
    o.m_bIsAlwaysActive = false
    o.m_oRoFight = nil

    o.m_lFormation = {1,1}
    o.m_iSummon = 0
    o.m_lLineup = {}
    o.m_oRoSummon = nil
    o.m_mRoPartners = {}
    o.m_mRoSummons = {}

    o.m_lTargets = {}
    o.m_lLog = {}
    o.m_iFightTimes = self:GetJJCFightMaxConfig()
    o.m_iResetTime = get_time()
    o.m_bRankChange = nil
    o.m_bHasInit = nil
    o.m_iMonth = 0
    o.m_iVersion = 0
    return o
end

function CJJCCtrl:Release()
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
    for _, oRoSummon in pairs(self.m_mRoSummons) do
        baseobj_safe_release(oRoSummon)
    end
    self.m_mRoSummons = {}
    super(CJJCCtrl).Release(self)
end

function CJJCCtrl:GetPid()
    return self:GetInfo("pid")
end

function CJJCCtrl:GetName()
    return self.m_oRoFight:GetName()
end

function CJJCCtrl:Save()
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

    local mRoSummons = {}
    for iNo, oRoSummon in pairs(self.m_mRoSummons) do
        mRoSummons[db_key(iNo)] = oRoSummon:Save() 
    end
    mData.rosummons = mRoSummons

    local mRoPartners = {}
    for sid, oRoPartner in pairs(self.m_mRoPartners) do
        mRoPartners[db_key(sid)] = oRoPartner:Save()
    end
    mData.ropartners = mRoPartners

    mData.targets = self.m_lTargets
    mData.log = self.m_lLog
    mData.times = self.m_iFightTimes
    mData.resettime = self.m_iResetTime
    mData.rankchange = self.m_bRankChange
    mData.hasinit = self.m_bHasInit
    mData.month = self.m_iMonth
    mData.version = self.m_iVersion
    return mData
end

function CJJCCtrl:Load(mData)
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

    for sid, mRoSumm in pairs(mData.rosummons or {}) do
        local iNo = tonumber(sid)
        local oRoSummon = rosummon.NewRoSummon(self:GetPid(), iNo)
        oRoSummon:Load(mRoSumm)
        self.m_mRoSummons[iNo] = oRoSummon
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

    self.m_lTargets = mData.targets or {}
    self.m_lLog = mData.log or {}
    self.m_iFightTimes = mData.times or self:GetJJCFightMaxConfig()
    self.m_iResetTime = mData.resettime or get_time()
    self.m_bRankChange = mData.rankchange
    self.m_bHasInit = mData.hasinit
    local mDate = os.date("*t", get_time())
    self.m_iMonth = mData.month or mDate.month
    self.m_iVersion = mData.version or 0
end

function CJJCCtrl:RefreshResetTime(mNow)
    local oJJCMgr = global.oJJCMgr
    local iTimesMax = self:GetJJCFightMaxConfig()
    local iRecover = oJJCMgr:GetJJCRecoverTimesConfig()
    local iHour = oJJCMgr:GetJJCTimeCDHourConfig()

    local iNowTime = mNow and mNow.time or get_time()
    local iDayNo = get_morningdayno(iNowTime)
    if iDayNo ~= get_morningdayno(self.m_iResetTime) then
        self:Dirty()
        self.m_iResetTime = iNowTime
        if self.m_iFightTimes < iRecover then
            self.m_iFightTimes = iRecover
        end
        self:CheckFightTimes()
    end
end

function CJJCCtrl:GetJJCFightMaxConfig()
    return res["daobiao"]["jjc"]["jjc_global"][1]["fight_max"]
end

function CJJCCtrl:GetJJCFightLimitConfig()
    local oJJCMgr = global.oJJCMgr
    return oJJCMgr:GetJJCFightLimitConfig()
end

function CJJCCtrl:GetFightTimes()
    self:RefreshResetTime()
    return self.m_iFightTimes
end

function CJJCCtrl:AddFightTimes(iAdd)
    self:RefreshResetTime()
    self:Dirty()
    if self.m_iFightTimes >= self:GetJJCFightMaxConfig() and iAdd < 0  then
        self.m_iResetTime = get_time()
    end
    self.m_iFightTimes = math.min(self:GetJJCFightLimitConfig(), self.m_iFightTimes + iAdd)
    self.m_iFightTimes = math.max(0, self.m_iFightTimes)
    self:CheckFightTimes()
    self:GS2CJJCLeftTimes()
end

function CJJCCtrl:AddJJCLog(bPassive, sFighter, bWin, iRank)
    if bPassive then
        self:Dirty()
        table.insert(self.m_lLog, {bPassive, sFighter, bWin, iRank, get_time()})
        if #self.m_lLog > 20 then
            table.remove(self.m_lLog, 1)
        end
    end
end

function CJJCCtrl:PacketJJCLog()
    local mNet = {}
    for _, v in ipairs(self.m_lLog) do
        local mData = {}
        mData.fighter = v[2]
        mData.win = v[3] and 1 or 0
        mData.rank = v[4]
        mData.time = v[5]
        table.insert(mNet, mData)
    end
    return mNet
end

function CJJCCtrl:SetRankChange(bChange)
    self:Dirty()
    self.m_bRankChange = bChange
end

function CJJCCtrl:IsRankChange()
    return self.m_bRankChange
end

function CJJCCtrl:SetVersion(iVersion)
    self.m_iVersion = iVersion
    self:Dirty()
end

function CJJCCtrl:SetMonth(iMonth)
    self.m_iMonth = iMonth
    self:Dirty()
end

function CJJCCtrl:IsInitRank(iCheckMonth, iVersion)
    if self.m_iMonth ~= iCheckMonth then
        return true
    end
    if self.m_iVersion ~= iVersion then
        return true
    end

    if not self:HasTarget() then return true end

    if self:IsRankChange() then return true end

    local lInfo = self:GetTargetInfo(gamedefines.JJC_TARGET_TYPE.PLAYER, self:GetInfo("pid"))
    if lInfo then return true end
    
    return false  
end

function CJJCCtrl:NewHour(mNow)
    local iHour = mNow.date.hour
    if iHour == 5 then
        self:NewHour5(mNow)
    end
end

function CJJCCtrl:NewHour5(mNow)
    local iPid = self:GetInfo("pid")
    local oPlayer = global.oWorldMgr:GetOnlinePlayerByPid(iPid)
    if oPlayer and global.oToolMgr:IsSysOpen("JJC_SYS", oPlayer, true) then
        self:RefreshResetTime(mNow)
        self:GS2CJJCLeftTimes()
    end
end

function CJJCCtrl:OnLogin(oPlayer)
    if global.oToolMgr:IsSysOpen("JJC_SYS", oPlayer, true) then
        self:RefreshResetTime()
        self:CheckFightTimes()
        self:GS2CJJCLeftTimes()        
    end
end

function CJJCCtrl:OnLogout(oPlayer)
    if global.oToolMgr:IsSysOpen("JJC_SYS", oPlayer, true) then return end

    if oPlayer then
        self:SyncData(oPlayer)
        global.oJJCMgr:OnLogout(oPlayer)
    end
    super(CJJCCtrl).OnLogout(self, oPlayer)
end

function CJJCCtrl:SyncData(oPlayer)
    self:SyncFightInfo(oPlayer)
    self:SyncSummonData(oPlayer)
    self:SyncPartnerInfo(oPlayer)
end

function CJJCCtrl:SyncFightInfo(oPlayer)
    self:Dirty()
    local oRoPlayer = roplayer.NewRoPlayer(self:GetInfo("pid"))
    oRoPlayer:Init(oPlayer:PackRoData())
    self.m_oRoFight = oRoPlayer
end

function CJJCCtrl:SyncSummonData(oPlayer)
    local mSummons = self:ChooseWarSummon() or {}
    if not next(mSummons) then return end

    for _, oRoSummon in pairs(self.m_mRoSummons) do
        baseobj_delay_release(oRoSummon)
    end

    local iPid = oPlayer:GetPid()
    self.m_mRoSummons = {}
    self.m_iSummon = 0
    for iNo, oSummon in pairs(mSummons) do
        if self.m_iSummon <= 0 then
            self.m_iSummon = iNo
        end
        local oRoSummon = rosummon.NewRoSummon(iPid, iNo)
        oRoSummon:Init(oSummon:PackRoData(oPlayer))
        self.m_mRoSummons[iNo] = oRoSummon
    end
    self:Dirty()
end

function CJJCCtrl:SyncPartnerInfo(oPlayer)
    self:Dirty()
    local oFmtMgr = oPlayer:GetFormationMgr()
    local iFmtId = oFmtMgr:GetCurrFmt()
    if iFmtId and iFmtId ~= 1 then
        self:SetFormation(oPlayer, iFmtId)
    end
    local lPartners = self:ChooseWarPartner()
    if lPartners and next(lPartners) then
        self:SetLineup(oPlayer, lPartners)
    end
end

function CJJCCtrl:SetSummon(oPlayer, summid)
    local oSummon = oPlayer.m_oSummonCtrl:GetSummon(summid)
    if not oSummon then
        self:UnsetSummon()
        return
    end
    self:Dirty()
    local pid, iNo = table.unpack(oSummon:GetData("traceno", {}))
    self.m_iSummon = iNo
end

function CJJCCtrl:UnsetSummon()
    self:Dirty()
    self.m_iSummon = 0
    if self.m_oRoSummon then
        baseobj_delay_release(self.m_oRoSummon)
        self.m_oRoSummon = nil
    end
end

function CJJCCtrl:OnReleaseSummon(traceno)
    local pid, iNo = table.unpack(traceno)
    if self.m_iSummon ~= iNo then
        return
    end
    self:UnsetSummon()
end

function CJJCCtrl:SetFormation(oPlayer, iFormation)
    self:Dirty()
    local oFormationMgr = oPlayer:GetFormationMgr()
    local lv = oFormationMgr:GetGrade(iFormation)
    self.m_lFormation = {iFormation, lv}
end

function CJJCCtrl:GetLineup()
    return self.m_lLineup
end

function CJJCCtrl:SetLineup(oPlayer, lPartners)
    self:Dirty()
    for _, oRoPartner in pairs(self.m_mRoPartners) do
        baseobj_delay_release(oRoPartner)
    end
    local lLineup = {}
    local mPartners = {}
    for _, pnid in ipairs(lPartners) do
        local oPartner = oPlayer.m_oPartnerCtrl:GetPartner(pnid)
        if oPartner then 
            local sid = oPartner:GetSID()
            table.insert(lLineup, sid)
            local oRoPartner = ropartner.NewRoPartner(sid)
            oRoPartner:Init(oPartner:PackRoData(oPlayer))
            mPartners[sid] = oRoPartner
        end
    end
    self.m_lLineup = lLineup
    self.m_mRoPartners = mPartners
end

function CJJCCtrl:SetTargets(lTargets)
    self:Dirty()
    self.m_lTargets = lTargets
end

function CJJCCtrl:GetTargets()
    return self.m_lTargets
end

function CJJCCtrl:HasTarget()
    return self.m_lTargets and next(self.m_lTargets)
end

function CJJCCtrl:GetTargetInfo(iType, id)
    for _, info in ipairs(self.m_lTargets) do
        if info.type == iType and info.id == id then
            return info
        end
    end
end

function CJJCCtrl:GetFormation()
    local iPid = self:GetInfo("pid")
    local iFmt, iGrade = table.unpack(self.m_lFormation)
    local mResult = {}
    mResult.grade = iGrade
    mResult.fmt_id = iFmt
    mResult.pid = iPid
    mResult.player_list = {iPid}

    local oWorldMgr = global.oWorldMgr
    local oPlayer = oWorldMgr:GetOnlinePlayerByPid(iPid)
    if oPlayer then
        mResult.partner_list = self:GetFightPartnerIDs()
    else
        mResult.partner_list = self.m_lLineup
    end
    if table_count(mResult.player_list) + table_count(mResult.partner_list) < 5 then
        mResult.fmt_id = 1
        mResult.grade = 1
    end
    return mResult
end

function CJJCCtrl:GetFightSummID()
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

function CJJCCtrl:GetFightPartnerIDs()
    local iPid = self:GetInfo("pid")
    local oWorldMgr = global.oWorldMgr
    local oPlayer = oWorldMgr:GetOnlinePlayerByPid(iPid)

    local lPartnerIds = {}
    if oPlayer then
        for _, sid in ipairs(self.m_lLineup) do
            local oPartner = oPlayer.m_oPartnerCtrl:QueryPartner(sid)
            if oPartner then
                table.insert(lPartnerIds, oPartner:GetID())
            end
        end
    end
    return lPartnerIds
end

function CJJCCtrl:CheckRoFight(oPlayer)
    if not self.m_oRoFight then
        self:SyncFightInfo(oPlayer)
    end
end

function CJJCCtrl:CheckInitLineup(oPlayer)
    if not self.m_bHasInit then
        self:SyncLineupInfo(oPlayer)
        self:Dirty()
        self.m_bHasInit = true
    end
end

function CJJCCtrl:SyncLineupInfo(oPlayer)
    local oFmtMgr = oPlayer:GetFormationMgr()
    local iFmtId = oFmtMgr:GetCurrFmt()
    if iFmtId and iFmtId ~= 1 then
        self:SetFormation(oPlayer, iFmtId)
    end
    local lEnter = oPlayer.m_oPartnerCtrl:GetCurrLineupPos()
    if lEnter and next(lEnter) then
        self:SetLineup(oPlayer, lEnter)
    end
    local oSummon = oPlayer.m_oSummonCtrl:GetFightSummon()
    if oSummon then
        self:SetSummon(oPlayer, oSummon.m_iID)
    end
end

function CJJCCtrl:PackWarInfo()
    local oWorldMgr = global.oWorldMgr
    local oPlayer = oWorldMgr:GetOnlinePlayerByPid(self:GetPid())
    if oPlayer then
        return oPlayer:PackRoData()
    else
        return self.m_oRoFight:PackWarInfo()
    end
end

function CJJCCtrl:PacketSummonWarInfo()
    local oWorldMgr = global.oWorldMgr
    if self.m_iSummon and self.m_iSummon > 0 then
        local oPlayer = oWorldMgr:GetOnlinePlayerByPid(self:GetPid())
        if oPlayer then
            local lTraceNo = {self:GetPid(), self.m_iSummon}
            local oSummon = oPlayer.m_oSummonCtrl:GetSummonByTraceNo(lTraceNo)
            if oSummon then
                return oSummon:PackRoData(oPlayer)
            end
        else
            local oRoSummon = self.m_mRoSummons[self.m_iSummon] or self.m_oRoSummon
            if oRoSummon then
                return oRoSummon:PackWarInfo()
            end
        end
    end
end

function CJJCCtrl:PackPartnerWarInfo()
    local lWarInfo = {}
    local oWorldMgr = global.oWorldMgr
    local oPlayer = oWorldMgr:GetOnlinePlayerByPid(self:GetPid())
    if oPlayer then
        for _, sid in ipairs(self.m_lLineup) do
            local oPartner = oPlayer.m_oPartnerCtrl:QueryPartner(sid)
            assert(oPartner, string.format("jjcctrl player online get partner err: %s %s", self:GetPid(), sid))
            table.insert(lWarInfo, oPartner:PackRoData(oPlayer))
        end
    else
        for _, sid in ipairs(self.m_lLineup) do
            table.insert(lWarInfo, self.m_mRoPartners[sid]:PackWarInfo())
        end
    end
    return lWarInfo
end

function CJJCCtrl:PacketLineupInfo()
    local oWorldMgr = global.oWorldMgr
    local oPlayer = oWorldMgr:GetOnlinePlayerByPid(self:GetInfo("pid"))

    local mData = {}
    mData.fmtid, mData.fmtlv = table.unpack(self.m_lFormation)
    if oPlayer then
        local oFormationMgr = oPlayer:GetFormationMgr()
        mData.fmtlv = oFormationMgr:GetGrade(mData.fmtid)
    end

    if oPlayer and self.m_iSummon then
        local lTraceNo = {self:GetPid(), self.m_iSummon}
        local oSummon = oPlayer.m_oSummonCtrl:GetSummonByTraceNo(lTraceNo)
        if oSummon then
            mData.summlv = oSummon:GetGrade()
            mData.summid = oSummon.m_iID
            mData.summicon = oSummon:Shape()
        end
    else
        local oRoSummon = self.m_mRoSummons[self.m_iSummon]
        if oRoSummon then
            mData.summlv = oRoSummon:GetGrade()
            mData.summicon = oRoSummon:GetIcon()
        end
    end

    mData.fighters = self:PackPartnerLineup()
    return mData
end

function CJJCCtrl:PackPartnerLineup()
    local oWorldMgr = global.oWorldMgr
    local oPlayer = oWorldMgr:GetOnlinePlayerByPid(self:GetInfo("pid"))

    local lPartners = {}
    for _, sid in ipairs(self.m_lLineup) do
        local mInfo = {}
        local oRoPartner = self.m_mRoPartners[sid]
        mInfo.icon = oRoPartner:GetIcon()
        mInfo.lv = oRoPartner:GetGrade()
        mInfo.quality = oRoPartner:GetQuality()
        if oPlayer then
            local oPartner = oPlayer.m_oPartnerCtrl:QueryPartner(sid)
            if oPartner then
                mInfo.id = oPartner:GetID()
                mInfo.icon = oPartner:GetShape()
                mInfo.lv = oPartner:GetGrade()
                mInfo.quality = oPartner:GetData("quality")
            end
        end
        table.insert(lPartners, mInfo)
    end
    return lPartners
end

function CJJCCtrl:PackTargetInfo(iType, iRank)
    local mNet = {}
    mNet.type = iType
    mNet.rank = iRank
    mNet.id = self:GetPid()
    mNet.fighters = self:PackPartnerLineup()

    local oPlayer = global.oWorldMgr:GetOnlinePlayerByPid(self:GetPid())
    if oPlayer then
        mNet.name = oPlayer:GetName()
        mNet.score = oPlayer:GetScore()
        mNet.model = oPlayer:GetModelInfo()
        mNet.grade = oPlayer:GetGrade()
        mNet.school = oPlayer:GetSchool()
    elseif self.m_oRoFight then
        mNet.name = self.m_oRoFight:GetName()
        mNet.score = self.m_oRoFight:GetScore()
        mNet.model = self.m_oRoFight:GetModelInfo()
        mNet.grade = self.m_oRoFight:GetGrade()
        mNet.school = self.m_oRoFight:GetSchool()    
    end
    return mNet
end

function CJJCCtrl:IsActive()
    if self.m_bIsAlwaysActive then
        return true
    end
    return super(CJJCCtrl).IsActive(self)
end

function CJJCCtrl:SetAlwaysActive(bActive)
    self.m_bIsAlwaysActive = bActive
end

function CJJCCtrl:PacketWarKeepSummon()
    --AI 战斗中可召唤的宠物
    local mSummon = {}
    local oPlayer = global.oWorldMgr:GetOnlinePlayerByPid(self:GetPid())
    if oPlayer then
        local iGrade = oPlayer:GetGrade()
        for iNo, oSummon in pairs(self:ChooseWarSummon() or {}) do
            if iNo ~= self.m_iSummon then
                mSummon[iNo] = oSummon:PackRoData(oPlayer)
            end
        end
    else
        for iNo, oRoSummon in pairs(self.m_mRoSummons or {}) do
            if iNo ~= self.m_iSummon then
                mSummon[iNo] = oRoSummon:PackWarInfo()
            end
        end
    end
    return mSummon
end

function CJJCCtrl:GS2CJJCLeftTimes()
    local iPid = self:GetInfo("pid")
    local oPlayer = global.oWorldMgr:GetOnlinePlayerByPid(iPid)
    if oPlayer then
        oPlayer:Send("GS2CJJCLeftTimes", {left_times=self.m_iFightTimes})
    end
end

function CJJCCtrl:CheckFightTimes()
    self:DelTimeCb("_CheckFightTimes")
    if self.m_iFightTimes >= self:GetJJCFightMaxConfig() then
        return
    end

    local oJJCMgr = global.oJJCMgr
    local iHour = oJJCMgr:GetJJCTimeCDHourConfig()
    local iDelay = iHour * 3600 + self.m_iResetTime - get_time()
    if iDelay <= 0 then return end

    local sWorldKey = self:GetWorldKey()
    local iPid = self:GetPid()
    local f = function ()
        local oWorldMgr = global.oWorldMgr
        local obj = oWorldMgr:GetOfflineObject(sWorldKey, iPid)
        if obj then
            obj:RefreshResetTime()
            obj:GS2CJJCLeftTimes()
        end
    end
    self:AddTimeCb("_CheckFightTimes", iDelay*1000, f)
end

function CJJCCtrl:ChooseWarSummon()
    local oPlayer = global.oWorldMgr:GetOnlinePlayerByPid(self:GetPid())
    if not oPlayer then return {} end

    local lSummid = {}
    for id, oSummon in pairs(oPlayer.m_oSummonCtrl:SummonList()) do
        table.insert(lSummid, {id, oSummon:GetGrade()})
    end
    table.sort(lSummid, function (a, b)
        if a[2] == b[2] then
            return a[1] > b[1]
        end  
        return a[2] > b[2]
    end)
    
    local mSummon = {}
    local iSummonCnt = global.oSummonMgr:GetFightSummonCount(oPlayer:GetGrade())
    for _, v in pairs(lSummid) do
        local oSummon = oPlayer.m_oSummonCtrl:GetSummon(v[1])
        if oSummon and oSummon:CanFight(oPlayer) then
            local _, iNo = table.unpack(oSummon:GetData("traceno", {}))
            mSummon[iNo] = oSummon
        end

        if table_count(mSummon) >= iSummonCnt then break end
    end
    return mSummon    
end

function CJJCCtrl:ChooseWarPartner()
    local oPlayer = global.oWorldMgr:GetOnlinePlayerByPid(self:GetPid())
    if not oPlayer then return {} end

    local lPartnerId = {}
    for id, oPartner in pairs(oPlayer.m_oPartnerCtrl:GetAllPartner()) do
        table.insert(lPartnerId, {id, oPartner:GetScore()})
    end
    table.sort(lPartnerId, function (a, b)
        if a[2] == b[2] then
            return a[1] > b[1]
        end  
        return a[2] > b[2]
    end)
    
    local iAssistCnt = 0
    local iMaxAssistCnt = global.oJJCMgr:GetAssistSchoolCnt()
    if gamedefines.ASSISTANT_SCHOOL[oPlayer:GetSchool()] then
        iAssistCnt = 1
    end

    local lChoosePartner = {}
    for _, v in pairs(lPartnerId) do
        local oPartner = oPlayer.m_oPartnerCtrl:GetPartner(v[1])
        if oPartner then
            if gamedefines.ASSISTANT_SCHOOL[oPartner:GetSchool()] then
                if iAssistCnt <= iMaxAssistCnt then
                    iAssistCnt = iAssistCnt + 1
                    table.insert(lChoosePartner, v[1])    
                end
            else
                table.insert(lChoosePartner, v[1])
            end
        end

        if #lChoosePartner >= 4 then break end
    end
    return lChoosePartner   
end

