local global = require "global"
local extend = require "base.extend"
local record = require "public.record"

local datactrl = import(lualib_path("public.datactrl"))
local loadsummon = import(service_path("summon.loadsummon"))
local gamedefines = import(lualib_path("public.gamedefines"))
local summondefines = import(service_path("summon.summondefines"))


local SUMMON_SIZE = 5
local MAX_SUMMON_SIZE = 10

local RECOVERY_REASON={
    ["洗宠"] = true,
    ["合宠"] = true,
    ["神兽兑换"] = true,
}

CSummonCtrl = {}
CSummonCtrl.__index = CSummonCtrl
inherit(CSummonCtrl, datactrl.CDataCtrl)

function CSummonCtrl:New(pid)
    local o = super(CSummonCtrl).New(self, {pid = pid})
    o.m_mSummons = {}
    o:SetInfo("size", SUMMON_SIZE)
    o:SetData("trace_no", 1)
    o:SetData("extendsize", 0)
    o.m_lShowSummonUI = {}
    return o
end

function CSummonCtrl:Release()
    for _, oSummon in pairs(self.m_mSummons) do
        baseobj_safe_release(oSummon)
    end
    self.m_mSummons = {}
    super(CSummonCtrl).Release(self)
end

function CSummonCtrl:Save()
    local mData = {}

    local summondata = {}
    for k, oSummon in pairs(self.m_mSummons) do
        table.insert(summondata, oSummon:Save())
    end
    mData.summondata = summondata
    mData.fightsummon = self:GetData("fightsummon")
    mData.traceno = self:GetData("trace_no", 1)
    mData.extendsize = self:GetData("extendsize", 0)
    mData.follow = self:GetData("follow")
    mData.showui = self.m_lShowSummonUI or {}
    return mData
end

-- 任务提交判断准则
function CSummonCtrl:IsSummonUnChanged(oSummon)
    return oSummon:IsWild() -- or oSummon:Grade() == 0
end

function CSummonCtrl:IsSummonSubmitable(oSummon)
    local oFightSummon = self:GetFightSummon()
    return oFightSummon ~= oSummon and not oSummon:IsBind() and not oSummon:GetIsZhenPinState() and self:IsSummonUnChanged(oSummon)
end

function CSummonCtrl:GetSubmitableSummons(sid)
    local lSummids = {}
    local oFightSummon = self:GetFightSummon()
    for summid, oSummon in pairs(self.m_mSummons) do
        if sid == oSummon:TypeID() then
            if oFightSummon ~= oSummon then
                if self:IsSummonUnChanged(oSummon) then
                    table.insert(lSummids, summid)
                end
            end
        end
    end
    return lSummids
end

function CSummonCtrl:Load(mData)
    local mData = mData or {}
    local summondata = mData.summondata or {}
    for _, data in pairs(summondata) do
        local oSummon = loadsummon.LoadSummon(data["sid"], data)
        assert(oSummon, string.format("summon sid error:%s,%s", self:GetInfo("pid"), data["sid"]))
        self.m_mSummons[oSummon.m_iID] = oSummon
        oSummon.m_Container = self
    end
    self:SetData("fightsummon", mData.fightsummon)
    self:SetData("trace_no", mData.traceno or 1)
    self:SetData("extendsize", mData.extendsize or 0)
    self:SetData("follow", mData.follow)
    self.m_lShowSummonUI = mData.showui or {}
end

function CSummonCtrl:DispatchTraceNo()
    local iTraceNo = self:GetData("trace_no", 1)
    self:SetData("trace_no", iTraceNo + 1)
    return iTraceNo
end

function CSummonCtrl:UnDirty()
    super(CSummonCtrl).UnDirty(self)
    for _, oSummon in pairs(self.m_mSummons) do
        if oSummon:IsDirty() then
            oSummon:UnDirty()
        end
    end
end

function CSummonCtrl:IsDirty()
    local bDirty = super(CSummonCtrl).IsDirty(self)
    if bDirty then
        return true
    end
    for _,oSummon in pairs(self.m_mSummons) do
        if oSummon:IsDirty() then
            return true
        end
    end
    return false
end

function CSummonCtrl:GetSize()
    return self:GetInfo("size", SUMMON_SIZE) + self:GetData("extendsize", 0)
end

function CSummonCtrl:GetExtendSize()
    return self:GetData("extendsize", 0)
end

function CSummonCtrl:AddExtendSize(iSize)
    local iSize = iSize or 1
    self:SetData("extendsize", self:GetExtendSize() + iSize)
end

function CSummonCtrl:CanAddExtendSize()
    return self:GetSize() < MAX_SUMMON_SIZE
end

function CSummonCtrl:SummonList()
    return self.m_mSummons
end

function CSummonCtrl:GetSummon(summid)
    return self.m_mSummons[summid]
end

function CSummonCtrl:GetSummonByTraceNo(mTraceNo)
    if not mTraceNo or not next(mTraceNo) then
        return nil
    end
    for _, oSummon in pairs(self.m_mSummons) do
        local traceno = oSummon:GetData("traceno")
        if traceno and mTraceNo[1] == traceno[1] and mTraceNo[2] == traceno[2] then
            return oSummon
        end
    end
    return nil
end

function CSummonCtrl:EmptySpaceCnt()
    return self:GetSize() - table_count(self:SummonList())
end

function CSummonCtrl:IsFull()
    if table_count(self:SummonList()) >= self:GetSize() then
        return true
    end
    return false
end

function CSummonCtrl:IsShowUI(oSummon)
    if not oSummon:IsShowUI() then return false end

    if summondefines.IsImmortalBB(oSummon:Type()) then return true end

    return not table_in_list(self:GetSummonShowUI(), oSummon:TypeID())
end

function CSummonCtrl:AddSummon(oSummon, sReason, mArgs)
    if self:IsFull() then
        return false
    end
    self:Dirty()
    if not oSummon:GetData("traceno") then
        local iTraceNo = self:DispatchTraceNo()
        oSummon:SetData("traceno",{self:GetInfo("pid"),iTraceNo})
        oSummon:SetData("got_time", get_time())
    end

    mArgs = mArgs or {}
    self.m_mSummons[oSummon.m_iID] = oSummon
    oSummon.m_Container = self
    if oSummon:NeedBind() then
        oSummon:Bind(self:GetInfo("pid"))
    end
    self:GS2CAddSummon(oSummon)
    global.oScoreCache:Dirty(self:GetInfo("pid"), "summonctrl")
    local oPlayer = global.oWorldMgr:GetOnlinePlayerByPid(self:GetInfo("pid"))
    if oPlayer then
        oPlayer:PropChange("score")
        if self:IsShowUI(oSummon) and not mArgs.cancel_ui then
            self:SetSummonShowUI(oSummon:TypeID())
            oPlayer:Send("GS2CShowNpcCloseup", {summon = oSummon:TypeID()})
        end
    end
    oPlayer:MarkGrow(1)

    local mLog = oSummon:LogData(oPlayer)
    mLog.reason = sReason or ""
    record.user("summon", "add_summon", mLog)
    if not mArgs.cancel_record then
        oSummon:LogPlayerSummonInfo(oPlayer, 1)
    end
    return true
end

function CSummonCtrl:RemoveSummon(oSummon, sReason, mArgs)
    self:Dirty()
    mArgs = mArgs or {}
    local oPlayer = global.oWorldMgr:GetOnlinePlayerByPid(self:GetInfo("pid"))
    if oPlayer and oSummon:Type()~= summondefines.TYPE_WILD and mArgs.recevery then
        oPlayer.m_mRecoveryCtrl:AddSum(oSummon:Save(),sReason)
    end
    global.oRankMgr:DeleteSummon(oSummon)
    if oSummon == self:GetFightSummon() then
        self:UnFight()
    end
    if self:GetFollowID() == oSummon:ID() then
        self:UnFollow()
    end

    if oPlayer then
        oPlayer:PropChange("score") 
        if not mArgs.cancel_record then
            oSummon:LogPlayerSummonInfo(oPlayer, 2)
        end
    end
    if oSummon:GetData("traceno") and not mArgs.cancel_record then
        oSummon:SetData("traceno",nil)
    end
    self:GS2CDelSummon(oSummon, mArgs.newid)
    self.m_mSummons[oSummon.m_iID] = nil
    oSummon.m_Container = nil
    
    local mLog = oSummon:LogData(oPlayer)
    mLog.reason = sReason or ""
    record.user("summon", "del_summon", mLog)
    baseobj_delay_release(oSummon)
    global.oScoreCache:Dirty(self:GetInfo("pid"), "summonctrl")
    self:OnRemoveSummon()
end

function CSummonCtrl:OnRemoveSummon()
    local oPlayer = global.oWorldMgr:GetOnlinePlayerByPid(self:GetInfo("pid"))
    if not oPlayer then return end

    oPlayer:GetJJC():SyncSummonData(oPlayer)    
end

function CSummonCtrl:GetSummonShowUI()
    return self.m_lShowSummonUI        
end

function CSummonCtrl:SetSummonShowUI(iSummon)
    if table_in_list(self.m_lShowSummonUI, iSummon) then return end

    table.insert(self.m_lShowSummonUI, iSummon)
    self:Dirty() 
end

function CSummonCtrl:GetFightSummon()
    local rFight = self:GetData("fightsummon")
    if not rFight or rFight == 0 then
        return nil
    end
    return self:GetSummonByTraceNo(rFight)
end

function CSummonCtrl:SetFight(summid)
    local oSummon = self:GetSummon(summid)
    if oSummon and oSummon:GetData("traceno") then
        local oFight = self:GetFightSummon()
        if oFight then
            -- self:UnFight()
            self:SetData("fightsummon", 0)         
        end
        self:SetData("fightsummon", oSummon:GetData("traceno"))
        self:GS2CSummonSetFight()
        if not oSummon:IsBind() then
            oSummon:Bind(self:GetInfo("pid"))
        end
    end
end

function CSummonCtrl:UnFight()
    self:SetData("fightsummon", 0)
    self:GS2CSummonSetFight()
end

function CSummonCtrl:Follow(summid)
    local oSummon = self:GetSummon(summid)
    if oSummon and oSummon:GetData("traceno") then
        self:SetData("follow", oSummon:GetData("traceno"))
        self:GS2CSummonFollow()
        self:SyncSceneInfo()
        local oWorldMgr = global.oWorldMgr
        local oPlayer = oWorldMgr:GetOnlinePlayerByPid(self:GetInfo("pid"))
        if oPlayer then
            oPlayer:PropChange("followers")
        end
    end
end

function CSummonCtrl:UnFollow()
    self:SetData("follow", nil)
    self:GS2CSummonFollow()
    self:SyncSceneInfo()
    local oWorldMgr = global.oWorldMgr
    local oPlayer = oWorldMgr:GetOnlinePlayerByPid(self:GetInfo("pid"))
    if oPlayer then
        oPlayer:PropChange("followers")
    end
end

function CSummonCtrl:GetFollowID()
    local rFollow = self:GetData("follow")
    if not rFollow then
        return nil
    end
    local oSummon = self:GetSummonByTraceNo(rFollow)
    if not oSummon then
        return nil
    end
    return oSummon.m_iID
end

function CSummonCtrl:FollowerInfo()
    local rFollow = self:GetData("follow")
    if not rFollow then
        return nil
    end
    local oSummon = self:GetSummonByTraceNo(rFollow)
    if not oSummon then
        return nil
    end
    local mNet = {
        name = oSummon:Name(),
        model_info = oSummon:GetModelInfo(),
        type = "s",
    }
    return mNet
end

function CSummonCtrl:OnLogin()
    local oFight = self:GetFightSummon()
    local iFightID = oFight and oFight.m_iID or 0

    local mNet = {}
    local summondata = {}
    for _, oSummon in pairs(self.m_mSummons) do
        table.insert(summondata, oSummon:SummonInfo())
    end
    mNet["summondata"] = summondata
    mNet["extsize"] = self:GetExtendSize()
    mNet["fightid"] = iFightID
    
    local oWorldMgr = global.oWorldMgr
    local oPlayer = oWorldMgr:GetOnlinePlayerByPid(self:GetInfo("pid"))
    if oPlayer then
        oPlayer:Send("GS2CLoginSummon",mNet)
        self:GS2CSummonFollow()
    end
end

function CSummonCtrl:OnLogout(oPlayer)
    for _,oSummon in pairs(self.m_mSummons) do
        if oSummon:IsRecord() then
            oSummon:LogPlayerSummonInfo(oPlayer, 1)
        end
    end
end

function CSummonCtrl:OnUpGrade(oPlayer, iFromGrade)
    for _,oSummon in pairs(self.m_mSummons) do
        oSummon:CheckUpGrade()
    end

    local iBeginCnt = global.oSummonMgr:GetFightSummonCount(iFromGrade)
    local iEndCnt = global.oSummonMgr:GetFightSummonCount(oPlayer:GetGrade())
    if iBeginCnt ~= iEndCnt then
        global.oScoreCache:Dirty(self:GetInfo("pid"), "summonctrl")    
    end 
end

function CSummonCtrl:GS2CAddSummon(oSummon)
    local mNet = {}
    local summondata = oSummon:SummonInfo()
    mNet["summondata"] = summondata
    local oWorldMgr = global.oWorldMgr
    local oPlayer = oWorldMgr:GetOnlinePlayerByPid(self:GetInfo("pid"))
    if oPlayer then
        oPlayer:Send("GS2CAddSummon",mNet)
    end
end

function CSummonCtrl:GS2CDelSummon(oSummon, iNewID)
    local mNet = {}
    mNet["id"] = oSummon.m_iID
    if iNewID then
        mNet["newid"] = iNewID
    end
    local oWorldMgr = global.oWorldMgr
    local oPlayer = oWorldMgr:GetOnlinePlayerByPid(self:GetInfo("pid"))
    if oPlayer then
        oPlayer:Send("GS2CDelSummon",mNet)
    end
end

function CSummonCtrl:GS2CSummonSetFight()
    local mNet = {}
    local oSummon = self:GetFightSummon()
    if oSummon then
        mNet["id"] = oSummon.m_iID
    else
        mNet["id"] = 0
    end
    local oWorldMgr = global.oWorldMgr
    local oPlayer = oWorldMgr:GetOnlinePlayerByPid(self:GetInfo("pid"))
    if oPlayer then
        oPlayer:Send("GS2CSummonSetFight", mNet)
    end
end

function CSummonCtrl:GS2CSummonFollow()
    local mNet = {}
    local iFollowID = self:GetFollowID()
    if iFollowID then
        mNet["id"] = iFollowID
    else
        mNet["id"] = 0
    end
    local oWorldMgr = global.oWorldMgr
    local oPlayer = oWorldMgr:GetOnlinePlayerByPid(self:GetInfo("pid"))
    if oPlayer then
        oPlayer:Send("GS2CSummonFollow", mNet)
    end
end

function CSummonCtrl:SyncSceneInfo()
    local oWorldMgr = global.oWorldMgr
    local oPlayer = oWorldMgr:GetOnlinePlayerByPid(self:GetInfo("pid"))
    if oPlayer then
        oPlayer:SyncSceneInfo({
            followers = oPlayer:GetFollowers()
        })
    end
end

function CSummonCtrl:GetLimitSummonCnt()
    local oPlayer = global.oWorldMgr:GetOnlinePlayerByPid(self:GetInfo("pid"))
    return global.oSummonMgr:GetFightSummonCount(oPlayer:GetGrade())
end

function CSummonCtrl:GetScore(bForce)
    local iLimit = self:GetLimitSummonCnt()
    local iScore = 0
    local lSumScore = {}

    local oPlayer = global.oWorldMgr:GetOnlinePlayerByPid(self:GetInfo("pid"))
    for id,v in pairs(oPlayer.m_oSummCkCtrl:GetSummonScore()) do
        table.insert(lSumScore, v)        
    end
    for _, oSummon in pairs(self.m_mSummons) do
        table.insert(lSumScore,oSummon:GetScore(bForce))
    end
    table.sort(lSumScore,function (a,b)
        return a>b
    end)
    for i=1,math.min(iLimit, #lSumScore) do
        iScore = iScore + lSumScore[i]
    end
    iScore = math.floor(iScore)
    return iScore
end

function CSummonCtrl:GetMaxScore()
    local iScore = 0
    local lScore = {}
    for _, oSummon in pairs(self.m_mSummons) do
        table.insert(lScore,oSummon:GetScore())
    end
    table.sort(lScore,function (a,b)
        return a>b
    end)
    iScore = lScore[1] or 0
    return iScore
end

function CSummonCtrl:PacketWarKeepSummon(oCurrSummon)
    local oWorldMgr = global.oWorldMgr
    local iPid = self:GetInfo("pid")
    local oPlayer = oWorldMgr:GetOnlinePlayerByPid(iPid)
    if not oPlayer then return {} end

    local iGradeLimit = oPlayer:GetGrade() + 10
    local mSummon, iTotal = {}, 4
    for iSummon, oSummon in pairs(self:SummonList()) do
        if iSummon ~= oCurrSummon.m_iID then
            if oSummon:Grade() <= iGradeLimit then
                mSummon[iSummon] = oSummon:PackWarInfo(oPlayer)
                iTotal = iTotal - 1
            end
        end
        if iTotal <= 0 then break end
    end
    return mSummon
end

function CSummonCtrl:GetRankData()
    local mData = {}
    for _, oSummon in pairs(self.m_mSummons) do
        table.insert(mData,oSummon:GetRankData())
    end
    return mData
end

function CSummonCtrl:PackBackendInfo()
    local mData = {}

    local summondata = {}
    for k, oSummon in pairs(self.m_mSummons) do
        table.insert(summondata, oSummon:PackBackendInfo())
    end
    mData.summondata = summondata
    mData.fightsummon = self:GetData("fightsummon")
    mData.follow = self:GetData("follow")
    return mData
end

function CSummonCtrl:FireUseSummonExpBook(oSummon, iCnt)
    self:TriggerEvent(gamedefines.EVENT.SUMMON_USE_EXP_BOOK, {summon = oSummon, cnt = iCnt})
end

function CSummonCtrl:FireSummonSkillLevelUp(oSummon, bSucc)
    self:TriggerEvent(gamedefines.EVENT.SUMMON_SKILL_LEVELUP, {summon = oSummon, succ = bSucc})
end

function CSummonCtrl:FireSummonStickSkill(oSummon, oNewSkill, oDelOldSkill)
    self:TriggerEvent(gamedefines.EVENT.SUMMON_STICK_SKILL, {summon = oSummon, newskill = oNewSkill, delskill = oDelOldSkill})
end

function CSummonCtrl:FireSummonCombine(oNewSummon, lOldSummons)
    self:TriggerEvent(gamedefines.EVENT.SUMMON_COMBINE, {newsummon = oNewSummon, oldsummons = lOldSummons})
end

function CSummonCtrl:FireSummonWash(oNewSummon, oOldSummon)
    self:TriggerEvent(gamedefines.EVENT.SUMMON_WASH, {newsummon = oNewSummon, oldsummon = oOldSummon})
end

function CSummonCtrl:FireCultivateSummonAptitude(oSummon)
    self:TriggerEvent(gamedefines.EVENT.SUMMON_CULTIVATE_APTITUDE, {summon = oSummon})
end
