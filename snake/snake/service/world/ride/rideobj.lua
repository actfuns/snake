--import module

local global = require "global"
local skynet = require "skynet"
local res = require "base.res"

local datactrl = import(lualib_path("public.datactrl"))
local wenshictrl = import(service_path("ride.wenshictrl"))
local ridedefines = import(service_path("ride.ridedefines"))
local sumdefines = import(service_path("summon.summondefines"))
local gamedefines = import(lualib_path("public.gamedefines")) 


function NewRide(iRide)
    local o = CRide:New(iRide)
    return o
end

function CheckRideExpire(iPid, iRide)
    local oWorldMgr = global.oWorldMgr
    local oPlayer = oWorldMgr:GetOnlinePlayerByPid(iPid)
    if not oPlayer then return end
    
    local oRide = oPlayer.m_oRideCtrl:GetRide(iRide)
    if oRide then
        oRide:_DoExpire()
    end
end

CRide = {}
CRide.__index = CRide
inherit(CRide, datactrl.CDataCtrl)

function CRide:New(iRid)
    local o = super(CRide).New(self, {rid = iRid})
    o:Init()
    return o
end

function CRide:Init()
    self.m_iExpireTime = 0
    self.m_iCreateTime = get_time()
    -- self.m_iFly = 0
    self.m_mTalents = {}
    self.m_mApply = {}
    self.m_oWenShiCtrl = wenshictrl.NewWenShiCtrl(self:RideID(), self:GetPid())
    self.m_mSummon = {}

    self:InitTalent()
    self:SetupApply()
end

function CRide:Create(mArgs)
    mArgs = mArgs or {}
    local iDay = mArgs.valid_day or self:GetConfigData()["valid_day"]
    if iDay > 0 then
        self.m_iExpireTime = get_time() + 24 * 60 * 60 * iDay
    end
    self:CheckTimeCb()
end

function CRide:GetConfigData()
    local oRideMgr = global.oRideMgr
    local mData = oRideMgr:GetRideConfigDataById(self:RideID())
    return mData
end

function CRide:InitTalent()
    self.m_mTalents = {}
    local oRideMgr = global.oRideMgr
    local lSkill = self:GetConfigData()["talent"]
    for _, iSkill in pairs(lSkill) do
        local oSkill = oRideMgr:CreatNewSkill(iSkill)
        self.m_mTalents[iSkill] = oSkill
    end
end

function CRide:OnUse(oRideCtrl)
    for _, oSkill in pairs(self.m_mTalents) do
        oSkill:SkillEffect(oRideCtrl)
    end
    self.m_mApply = {}
    self:SetupApply()
end

function CRide:OnUnUse(oRideCtrl)
    for _, oSkill in pairs(self.m_mTalents) do
        oSkill:SkillUnEffect(oRideCtrl)
    end
end

function CRide:UnDirty()
    super(CRide).UnDirty(self)

    if self.m_oWenShiCtrl:IsDirty() then
        self.m_oWenShiCtrl:UnDirty()
    end
end

function CRide:IsDirty()
    local bDirty = super(CRide).IsDirty(self)
    if bDirty then return true end
    
    if self.m_oWenShiCtrl:IsDirty() then return true end

    return false
end

function CRide:Release()
    if self.m_mTalents then
        for _, oSkill in pairs(self.m_mTalents) do
            baseobj_safe_release(oSkill)
        end
    end
    self.m_mTalents = {}
    super(CRide).Release(self)
end

function CRide:Load(mData)
    self.m_iCreateTime = mData["got_time"]
    self.m_iExpireTime = mData["expire_time"]
    -- self.m_iFly = mData["fly"] or 0
    self.m_mSummon = mData["summons"] or {}
    self.m_oWenShiCtrl:Load(mData["wenshi"])
end

function CRide:Save()
    local mData = {}
    mData["ride_id"] = self:RideID()
    mData["got_time"] = self.m_iCreateTime
    mData["expire_time"] = self.m_iExpireTime
    -- mData['fly'] = self.m_iFly
    mData["summons"] = self.m_mSummon
    mData["wenshi"] = self.m_oWenShiCtrl:Save()
    return mData
end

function CRide:RideID()
    return self:GetInfo("rid")
end

function CRide:GetName()
    return self:GetConfigData()["name"]
end

-- function CRide:CanFly()
--     return self:GetConfigData()["flymap"] > 0
-- end

-- function CRide:GetFly()
--     if not self:CanFly() then
--         return 0
--     end
--     return self.m_iFly
-- end

-- function CRide:SetFly(iFly)
--     self.m_iFly = iFly or 0
-- end

function CRide:SetupApply()
    local mEffect = self:GetConfigData()["attr_effect"] or {}
    for _, sEffect in ipairs(mEffect) do
        local sApply, sFormula = string.match(sEffect,"(.+)=(.+)")
        if sApply and sFormula then
            local iValue = tonumber(sFormula)
            self.m_mApply[sApply] = iValue
        end
    end
end

function CRide:GetApply(sAttr)
    return self.m_mApply[sAttr] or 0
end

function CRide:GetPerformMap()
    local mPerform = {}
    for _, oSk in pairs(self.m_mTalents) do
        for iPer, iLv in pairs(oSk:GetPerformList()) do
            mPerform[iPer] = iLv
        end
    end
    return mPerform
end

function CRide:GetCreateTime()
    return self.m_iCreateTime
end

function CRide:GetExpireTime()
    return self.m_iExpireTime
end

function CRide:GetPid()
    return self:GetInfo("pid")
end

function CRide:SetPid(iPid)
    self:SetInfo("pid", iPid)
end

function CRide:OnLogin(oPlayer, bReEnter)
    self:CheckTimeCb()
end

function CRide:CheckTimeCb()
    self:_CheckExpire()
end

function CRide:_CheckExpire()
    self:DelTimeCb("_CheckExpire")
    if self:IsForever() then return end
        
    local iLeftTime = self:GetExpireTime() - get_time()
    if iLeftTime < 0 then return end

    iLeftTime = math.max(1, iLeftTime)
    if iLeftTime > 1 * 24 * 3600 then return end
    
    local iRide = self:RideID()
    local iPid = self:GetPid()
    local f = function ()
        CheckRideExpire(iPid, iRide)
    end
    self:AddTimeCb("_CheckExpire", iLeftTime * 1000, f)
end

function CRide:_DoExpire()
    local oWorldMgr = global.oWorldMgr

    local oPlayer = oWorldMgr:GetOnlinePlayerByPid(self:GetPid())
    if oPlayer then
        oPlayer.m_oRideCtrl:DoExpire(self:RideID())
        self:UpdateControlSummon()
        -- self:GS2CUpdateRide(oPlayer)
    end
end

function CRide:IsExpire()
    return self.m_iExpireTime > 0 and self.m_iExpireTime <= get_time()
end

function CRide:IsForever()
    if self.m_iExpireTime <= 0 then
        return true
    end
    return false
end

local MAX_TIMEOUT = 9999 * 24 * 3600

function CRide:CanAddExpireTime(iDay)
    if self:IsForever() then return false end
    if iDay <= 0 then
        return true
    end
    local iAddSec = iDay * 24 * 3600
    local iNow = get_time()
    if iNow <= self.m_iExpireTime then
        if self.m_iExpireTime + iAddSec - iNow > MAX_TIMEOUT then
            return false
        end
    else
        if iAddSec > MAX_TIMEOUT then
            return false
        end
    end
    return true
end

function CRide:AddExpireTime(iDay)
    if self:IsForever() then return end

    local iNow = get_time()
    if iDay <= 0 then
        self.m_iExpireTime = 0
    elseif self.m_iExpireTime <= iNow then
        self.m_iExpireTime = iNow + iDay * 24 * 60 * 60
    else
        self.m_iExpireTime = self.m_iExpireTime + iDay * 24 * 60 * 60
    end
    if self.m_iExpireTime - iNow > MAX_TIMEOUT then
        self.m_iExpireTime = MAX_TIMEOUT + iNow
    end
    self:UpdateControlSummon()
    self:Dirty()
    self:CheckTimeCb()
end

function CRide:SetExpireTime(iDay)
    if self:IsForever() then return end

    if iDay <= 0 then
        self.m_iExpireTime = 0
    else
        self.m_iExpireTime = get_time() + iDay * 24 * 60 * 60
    end
    self:Dirty()
    self:CheckTimeCb()
end

function CRide:GetConfigValidDay()
    return self:GetConfigData()["valid_day"]
end

function CRide:CanDelete()
    if self:IsForever() then
         return false
    end
    return self.m_iExpireTime + 7 * 24 * 60 * 60 <= get_time()
end

function CRide:GetRideSpeed()
    local mInfo = global.oRideMgr:GetRideConfigDataById(self:RideID())
    return mInfo.speed
end

function CRide:GS2CUpdateRide(oPlayer)
    oPlayer:Send("GS2CUpdateRide", {ride_info = self:PackNetInfo()})
end

function CRide:PackNetInfo()
    local mNet = {}
    mNet["ride_id"] = self:RideID()
    mNet["got_time"] = self.m_iCreateTime
    if self:IsForever() then
        mNet["left_time"] = -1
    else
        mNet["left_time"] = math.max(0, self:GetExpireTime() - get_time())
    end
    local oPlayer = global.oWorldMgr:GetOnlinePlayerByPid(self:GetPid())
    mNet["summons"] = self:PackNetSummons(oPlayer)
    mNet["wenshi"] = self.m_oWenShiCtrl:PackNetWenShi(oPlayer)
    local iSkill = self.m_oWenShiCtrl:GetApplySkill()
    if iSkill then
        mNet["skill"] = iSkill
        if not self:IsExpire() then
            mNet["skill_effect"] = 1
        end
    else
        mNet["skill"] = self.m_oWenShiCtrl:GetSkill()    
    end
    return mNet
end

function CRide:PackNetSummons(oPlayer)
    local lNet = {}
    if not oPlayer then return lNet end
    
    for iPos,mTrace in pairs(self.m_mSummon) do
        local oSummon = oPlayer.m_oSummonCtrl:GetSummonByTraceNo(mTrace)
        if oSummon then
            table.insert(lNet, {
                summon = oSummon:ID(),
                pos = iPos,
            })            
        end
    end
    return lNet
end

function CRide:GetScore()
    local iScore = 0
    if self:IsExpire() then 
        return iScore
    end
    local mRes = self:GetConfigData()
    iScore = mRes.score
    return iScore
end

function CRide:GetWenShiScore()
    if self:IsExpire() then return 0 end

    return self.m_oWenShiCtrl:GetScore()
end

function CRide:GetScoreDebug()
    local mRes = self:GetConfigData()
    return string.format("%s激活评分:%s",mRes.name,self:GetScore())
end

function CRide:CanWield(oWenShi, iPos)
    if iPos > self.m_oWenShiCtrl:GetMaxPos() then
        return false
    end
    return true
end

function CRide:WieldWenShi(oWenShi, iPos)
    self.m_oWenShiCtrl:WeildWenShi(oWenShi, iPos)
    self:UpdateControlSummon()
    global.oScoreCache:Dirty(self:GetPid(), "ridectrl")
    self:RefreshScore()
end

function CRide:UnWieldWenShi(iPos)
    self.m_oWenShiCtrl:UnWeildWenShi(iPos)
    self:UpdateControlSummon()
    global.oScoreCache:Dirty(self:GetPid(), "ridectrl")
    self:RefreshScore()
end

function CRide:GetWenShiByPos(iPos)
    return self.m_oWenShiCtrl:GetWenShiByPos(iPos)
end

function CRide:GetSummonPos(oSummon)
    local m = oSummon:GetData("traceno")
    for iPos, mTraceno in pairs(self.m_mSummon) do
        if m and mTraceno[1] == m[1] and mTraceno[2] == m[2] then
            return iPos
        end
    end
end

function CRide:ControlSummon(oSummon, iPos)
    if iPos > ridedefines.CONTROL_SUMMON then return end

    local mTraceno = oSummon:GetData("traceno")
    if not mTraceno then return end

    oSummon:BindRide(self:RideID())
    self.m_mSummon[iPos] = mTraceno
    self:Dirty()

    self:ControlEffect(oSummon)
end

function CRide:ControlEffect(oSummon)
    local mApply = self.m_oWenShiCtrl:GetApplys()
    local iSource = sumdefines.RIDE_ATTR_SOURCE
    for sAttr, iVal in pairs(mApply) do
        oSummon:AddApply(sAttr, iVal, iSource)
    end
    local iSkill = self.m_oWenShiCtrl:GetApplySkill()
    if iSkill and iSkill > 0 then
        oSummon:AddControlSkill(iSkill)
    end
    oSummon:FullState()
    oSummon:PropChange("hp", "mp")
end

function CRide:UnControlSummon(iPos)
    local mTraceno = self.m_mSummon[iPos]
    if not mTraceno then return end

    local oPlayer = global.oWorldMgr:GetOnlinePlayerByPid(self:GetPid())
    local oSummon = oPlayer.m_oSummonCtrl:GetSummonByTraceNo(mTraceno)
    if oSummon then
        self:UnControlEffect(oSummon)
        oSummon:UnBindRide()
    end
    self.m_mSummon[iPos] = nil
    self:Dirty()
end

function CRide:UnControlEffect(oSummon)
    oSummon:RemoveApply(sumdefines.RIDE_ATTR_SOURCE)
    oSummon:RemoveControlSkill()
    oSummon:FullState()
    oSummon:PropChange("hp", "mp")
end

function CRide:UpdateControlSummon()
    local oPlayer = global.oWorldMgr:GetOnlinePlayerByPid(self:GetPid())
    if not oPlayer then return end

    for _,mTrace in pairs(self.m_mSummon) do
        local oSummon = oPlayer.m_oSummonCtrl:GetSummonByTraceNo(mTrace)
        if oSummon then
            self:UnControlEffect(oSummon)
            if not self:IsExpire() then
                self:ControlEffect(oSummon)
            end
        end
    end
end

function CRide:OnLevelWar(sGameplay, iWarType)
    if sGameplay == "arena" then return end

    local iLast = 0
    if iWarType == gamedefines.WAR_TYPE.PVE_TYPE then
        iLast = global.oRideMgr:GetOtherConfigByKey("pve_last")
    elseif iWarType == gamedefines.WAR_TYPE.PVP_TYPE then
        iLast = global.oRideMgr:GetOtherConfigByKey("pvp_last")
    end
    if iLast <= 0 then return end

    local bRefresh = self.m_oWenShiCtrl:ResumeLast(iLast)
    if bRefresh then
        self:UpdateControlSummon()
        global.oScoreCache:Dirty(self:GetPid(), "ridectrl")
        self:RefreshScore()
    end

    local oPlayer = global.oWorldMgr:GetOnlinePlayerByPid(self:GetPid())
    if oPlayer then
        self:GS2CUpdateRide(oPlayer)     
    end
end

function CRide:RefreshScore()
    local oPlayer = global.oWorldMgr:GetOnlinePlayerByPid(self:GetPid())
    if not oPlayer then return end

    oPlayer:PropChange("score")
end





