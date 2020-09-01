--import module
local skynet = require "skynet"
local global = require "global"
local res = require "base.res"
local net = require "base.net"
local record = require "public.record" 

local datactrl = import(lualib_path("public.datactrl"))
local rideobj = import(service_path("ride.rideobj"))
local ridedefines = import(service_path("ride.ridedefines"))
local attrmgr = import(service_path("ride.rideattr"))
local gamedefines = import(lualib_path("public.gamedefines"))

PropHelperFunc = {}
function PropHelperFunc.grade(o)
    return o:GetGrade()
end

function PropHelperFunc.exp(o)
    return o:GetExp()
end

function PropHelperFunc.point(o)
    return o:GetSkillPoint()
end

function PropHelperFunc.use_ride(o)
    return o:GetUseRideID()
end

function PropHelperFunc.choose_skills(o)
    return o:GetChooseSkills()
end

function PropHelperFunc.skills(o)
    return o:PackSkillInfo()
end

function PropHelperFunc.ride_infos(o)
    local lRideNet = {}
    for _, oRide in pairs(o.m_mRides) do
        table.insert(lRideNet, oRide:PackNetInfo())
    end
    return lRideNet
end

function PropHelperFunc.attrs(o)
    local lAttr = {}
    for sKey, sVal in pairs(o:GetGradeAttrs()) do
        table.insert(lAttr, {key=sKey, value=sVal})
    end
    return lAttr
end

function PropHelperFunc.score(o)
    return o:GetScore()
end


CRideCtrl = {}
CRideCtrl.__index = CRideCtrl
inherit(CRideCtrl, datactrl.CDataCtrl)

function CRideCtrl:New(pid)
    local o = super(CRideCtrl).New(self, {pid=pid})
    o:Init()
    return o
end

function CRideCtrl:Init()
    self.m_mRides = {}
    self.m_iUseRide = 0
    self.m_iGrade = 0
    self.m_iExp = 0
    self.m_iPoint = 0
    self.m_mSkills = {}
    self.m_iFly = 0
    self.m_mBeforBianShen = {}
    self.m_lChooseSkill = {}

    self.m_mBaseSk = {}             -- 基础技能位置 {[1001]=1, [1002]=[3]}
    self.m_mAdvanceSk = {}          -- 进价技能位置 {[2002]={1, 1}}
    -- self.m_iFinalSk = 0
    self.m_oAttrMgr = attrmgr.NewAttrMgr(self:GetPid())

    -- 临时数据
    self.m_mCanLearnSkill = {}
end

function CRideCtrl:Release()
    for _, oRide in pairs(self.m_mRides) do
        baseobj_safe_release(oRide)
    end
    self.m_mRides = {}
    for _, oSkill in pairs(self.m_mSkills) do
        baseobj_safe_release(oSkill)
    end
    self.m_mSkills = {}
    
    baseobj_safe_release(self.m_oAttrMgr)
    super(CRideCtrl).Release(self)
end

function CRideCtrl:Load(mData)
    if not mData then return end

    self.m_iUseRide = mData["use_ride"]
    self.m_iGrade = mData["grade"]
    self.m_iExp = mData["exp"]
    self.m_iPoint = mData["point"]
    -- self.m_lLearnSkill = mData["learn_skill"]

    local oRideMgr = global.oRideMgr
    for iRide, m in pairs(mData["rides"]) do
        local oRide = oRideMgr:LoadRide(tonumber(iRide), self:GetPid(), m)
        self.m_mRides[oRide:RideID()] = oRide
        -- if not oRide:CanDelete() then
        --     self.m_mRides[oRide:RideID()] = oRide
        -- else
        --     baseobj_delay_release(oRide)
        -- end
    end

    for iSk, m in pairs(mData["skill"] or {}) do
        local oSkill = oRideMgr:LoadSkill(tonumber(iSk), m)
        self.m_mSkills[oSkill:SkID()] = oSkill
    end

    for iSk, iIdx in pairs(mData["base_idx"] or {}) do
        self.m_mBaseSk[tonumber(iSk)] = iIdx
    end

    for iSk, lIdx in pairs(mData["advance_idx"] or {}) do
        self.m_mAdvanceSk[tonumber(iSk)] = lIdx
    end

    self.m_iFly = mData["fly"] or 0
    self.m_mBeforBianShen = mData["bianshen"] or {}
end

function CRideCtrl:Save()
    local mData = {}
    mData["use_ride"] = self.m_iUseRide
    mData["grade"] = self.m_iGrade
    mData["exp"] = self.m_iExp
    mData["point"] = self.m_iPoint
    -- mData["learn_skill"] = self.m_lLearnSkill

    local mRide = {}
    for iRide, oRide in pairs(self.m_mRides) do
        mRide[db_key(iRide)] = oRide:Save()
    end
    mData["rides"] = mRide

    local mSkill = {}
    for iSk, oSKill in pairs(self.m_mSkills) do
        mSkill[db_key(iSk)] = oSKill:Save()
    end 
    mData["skill"] = mSkill

    mData["base_idx"] = {}
    for iSk, iIdx in pairs(self.m_mBaseSk) do
        mData["base_idx"][db_key(iSk)] = iIdx
    end

    mData["advance_idx"] = {}
    for iSk, lIdx in pairs(self.m_mAdvanceSk) do
        mData["advance_idx"][db_key(iSk)] = lIdx
    end

    mData["fly"] = self.m_iFly
    mData["bianshen"] = self.m_mBeforBianShen
    return mData
end

function CRideCtrl:PreLogin(oPlayer, bReEnter)
    if bReEnter then return end

    for _,oRide in pairs(self.m_mRides) do
        oRide:OnLogin(oPlayer, bReEnter)
    end

    local oRide = self:GetUseRide()
    if self.m_iUseRide > 0 and (not oRide or oRide:IsExpire()) then
        self.m_iUseRide = 0
    end

    if not bReEnter then
        self:UpdateRideAttr(oPlayer, bReEnter)
        self:SyncUseRidelSumData(oPlayer)
    end
end

function CRideCtrl:UpdateRideAttr(oPlayer, bReEnter)
    -- for _,oRide in pairs(self.m_mRides) do
    --     oRide:OnLogin(oPlayer, bReEnter)
    -- end
    self:UpdateGradeAttr()        
    for _, oSkill in pairs(self.m_mSkills) do
        oSkill:SkillEffect(self)
    end

    local oUserRide = self:GetUseRide()
    if oUserRide then
        oUserRide:OnUse(self)
    end
end

function CRideCtrl:UnDirty()
    super(CRideCtrl).UnDirty(self)
    for _, oRide in pairs(self.m_mRides) do
        if oRide:IsDirty() then oRide:UnDirty() end
    end
    
    for _, oSkill in pairs(self.m_mSkills) do
        if oSkill:IsDirty() then oSkill:UnDirty() end
    end
end

function CRideCtrl:IsDirty()
    local bDirty = super(CRideCtrl).IsDirty(self)
    if bDirty then return true end

    for _, oRide in pairs(self.m_mRides) do
        if oRide:IsDirty() then return true end
    end

    for _, oSkill in pairs(self.m_mSkills) do
        if oSkill:IsDirty() then return true end
    end
    return false
end

function CRideCtrl:GetPid()
    return self:GetInfo("pid")
end

function CRideCtrl:OnLogin(oPlayer, bReEnter)
    -- TODO liuzla
    -- local oToolMgr = global.oToolMgr
    -- oToolMgr:IsSysOpen("RIDE_SYS", oPlayer, false)
    
    if not self:GetUseRide() and self:GetRideFly() > 0 then
        self:SetRideFly(0)
    end

    if not bReEnter then
        for _,oRide in pairs(self.m_mRides) do
            if oRide:CanDelete() then
                for i =1, oRide.m_oWenShiCtrl:GetMaxPos() do
                    global.oRideMgr:UnWieldWenShi2(oPlayer, oRide, i)    
                end
                self:DeleteRide(oRide:RideID())
            else
                oRide:UpdateControlSummon()
            end
        end
    end
    self:GS2CPlayerRideInfo()
end

function CRideCtrl:OnLogout(oPlayer)
    -- TODO
end

function CRideCtrl:InitSkill(oPlayer)
    if self:GetGrade() > 0 then return end

    if self:GetSkillPoint() > 0 then return end

    if self:GetSkillCnt() > 0 then return end

    local mConfig = global.oRideMgr:GetOtherConfigByKey("init_skill")
    for _,v in pairs(mConfig) do
        if v.school == oPlayer:GetSchool() then
            local oSkill = global.oRideMgr:CreatNewSkill(v.skill)
            self:AddSkill(oSkill)
            self:GS2CPlayerRideInfo("skills")
            break
        end
    end    
end

function CRideCtrl:OnPlayerUpGrade(oPlayer)
    for _, oSkill in pairs(self.m_mSkills) do
        oSkill:SkillUnEffect(self)
        oSkill:SkillEffect(self)
    end
    if global.oToolMgr:IsSysOpen("RIDE_UPGRADE", oPlayer, true) then
        self:InitSkill(oPlayer)
    end
end

function CRideCtrl:GS2CPlayerRideInfo(...)
    local oWorldMgr = global.oWorldMgr
    local oPlayer = oWorldMgr:GetOnlinePlayerByPid(self:GetPid())
    if oPlayer then
        local mNet = self:PackRideNetInfo(...)
        oPlayer:Send("GS2CPlayerRideInfo",{info=mNet})
    end
end

function CRideCtrl:PackRideNetInfo(...)
    local l = table.pack(...)
    local m = {}
    if #l <= 0 then
        m = PropHelperFunc
    else
        for _,v in ipairs(l) do
            m[v] = true
        end
    end

    local mRet = {}
    for k,v in pairs(m) do
        local f = assert(PropHelperFunc[k], string.format("ridectrl fail f get %s", k))
        mRet[k] = f(self)
    end
    return net.Mask("PlayerRideInfo", mRet)
end

function CRideCtrl:GetGrade()
    return self.m_iGrade
end

function CRideCtrl:GetExp()
    return self.m_iExp
end

function CRideCtrl:GetSkillPoint()
    return self.m_iPoint
end

function CRideCtrl:AddSkillPoint(iVal)
    self.m_iPoint = math.max(0, self.m_iPoint + iVal)
    self:Dirty()
end

function CRideCtrl:GetRide(iRid)
    return self.m_mRides[iRid]
end

function CRideCtrl:GetRideCnt()
    return table_count(self.m_mRides)
end

function CRideCtrl:AddRide(oRide, sReason)
    if not oRide then
        return false
    end
    local iRideID = oRide:RideID()
    self.m_mRides[iRideID] = oRide
    global.oScoreCache:Dirty(self:GetPid(), "ridectrl")
    oRide:SetPid(self:GetPid())
    self:Dirty()
    self:GS2CAddRide(oRide) 
    self:RefreshScore()

    local oPlayer = global.oWorldMgr:GetOnlinePlayerByPid(self:GetPid())
    if oPlayer then
        if iRideID == 1001 then
            oPlayer:MarkGrow(19)
        end
        local mLog = oPlayer:LogData()
        mLog["ride_id"] = oRide:RideID()
        record.user("ride", "add_ride", mLog)
    end
    return true
end

function CRideCtrl:GS2CAddRide(oRide)
    local oWorldMgr = global.oWorldMgr
    local oPlayer = oWorldMgr:GetOnlinePlayerByPid(self:GetPid())
    if oPlayer then
        oPlayer:Send("GS2CAddRide", {ride_info=oRide:PackNetInfo()})
    end
end

local ERR = {
    NO_CONFIG = 1,
    HAS_FOREVER = 2,
    ADD_WILL_OVERFLOW = 3,
}

function CRideCtrl:TouchAddRide(iRid)
    local oNewRide = global.oRideMgr:CreateNewRide(iRid)
    if not oNewRide then
        return false, ERR.NO_CONFIG
    end
    self:AddRide(oNewRide)
    return true
end

function CRideCtrl:ExtendRide(iRid, bForth, sReason)
    local oRide = self:GetRide(iRid)
    if not oRide then
        return self:TouchAddRide(iRid)
    end
    if oRide:IsForever() then
        return false, ERR.HAS_FOREVER
    end
    local iValidDay = oRide:GetConfigValidDay()
    if oRide:IsExpire() then
        oRide:SetExpireTime(iValidDay)
    else
        if not bForth and not oRide:CanAddExpireTime(iValidDay) then
            return false, ERR.ADD_WILL_OVERFLOW
        end
        oRide:AddExpireTime(iValidDay, bForth)
    end
    local oPlayer = global.oWorldMgr:GetOnlinePlayerByPid(self:GetPid())
    if oPlayer then
        oRide:GS2CUpdateRide(oPlayer)
    end
    return true
end

function CRideCtrl:DeleteRide(iRide, bClient)
    local oRide = self.m_mRides[iRide]
    if not oRide then return end

    self.m_mRides[iRide] = nil
    global.oScoreCache:Dirty(self:GetPid(), "ridectrl")
    if self.m_iUseRide == iRide then
        self.m_iUseRide = 0
    end
    self:Dirty()

    local oPlayer = global.oWorldMgr:GetOnlinePlayerByPid(self:GetPid())
    if oPlayer then
        for i =1, oRide.m_oWenShiCtrl:GetMaxPos() do
            global.oRideMgr:UnWieldWenShi2(oPlayer, oRide, i)    
        end
    end

    if bClient then
        self:GS2CDeleteRide(iRide)
    end
    baseobj_delay_release(oRide)
end

function CRideCtrl:GS2CDeleteRide(iRide)
    local oWorldMgr = global.oWorldMgr
    local oPlayer = oWorldMgr:GetOnlinePlayerByPid(self:GetPid())
    if oPlayer then
        oPlayer:Send("GS2CDeleteRide", {ride_id=iRide})
    end
end

function CRideCtrl:DoExpire(iRide)
    local oRide = self:GetRide(iRide)
    if not oRide then return end

    if self.m_iUseRide == iRide then
        if self:GetRideFly() > 0 then
            self:SetRideFly(0)
        end
        self:UnUseRide()
    end
    
    local oWorldMgr = global.oWorldMgr
    local oPlayer = oWorldMgr:GetOnlinePlayerByPid(self:GetPid())
    global.oScoreCache:Dirty(self:GetPid(), "ridectrl")
    
    if oPlayer then
        oRide:GS2CUpdateRide(oPlayer)
        self:RefreshScore()
    end
end

function CRideCtrl:GetUseRide()
    return self:GetRide(self.m_iUseRide)
end

function CRideCtrl:GetUseRideID()
    return self.m_iUseRide
end

function CRideCtrl:SetRideFly(iFly, bNoScene)
    self.m_iFly = iFly
    self:Dirty()
    self:PlayerProChange("fly_height")
    if not bNoScene then
        self:SyncSceneFlyInfo()
    end
end

function CRideCtrl:GetRideFly()
    return self.m_iFly
end

function CRideCtrl:OnBeforeBianShen()
    self.m_mBeforBianShen = {}
    if not self.m_mBeforBianShen or table_count(self.m_mBeforBianShen) <= 0 then
        self.m_mBeforBianShen = {
            fly = self:GetRideFly(),
            ride = self:GetUseRideID()
        }
    end
end

function CRideCtrl:OnAfterBianShen()
    local oPlayer = global.oWorldMgr:GetOnlinePlayerByPid(self:GetPid())
    if not oPlayer then return end
    local oBianshen = oPlayer.m_oBaseCtrl.m_oBianShenMgr:GetCurBianShen()
    if oBianshen then return end

    local mBefore = self.m_mBeforBianShen
    if table_count(mBefore) <= 0 then return end

    self.m_mBeforBianShen = {}
    if self:GetUseRide() then return end

    local iRide = mBefore["ride"]
    local oRide = self:GetRide(iRide)
    if not oRide or oRide:IsExpire() then return end

    self:UseRide(iRide)
    local iFly = mBefore["fly"] or 0
    if iFly > 0 then
        self:SetRideFly(1, true)
    end
end

function CRideCtrl:GetBeforeBianShen()
    return self.m_mBeforBianShen
end

function CRideCtrl:ClearBeforeBianShen()
    self.m_mBeforBianShen = {}
end

function CRideCtrl:TouchUnRide(bNoScene)
    if self:GetRideFly() > 0 then
        self:SetRideFly(0, bNoScene)
    end
    local oRide = self:GetUseRide()
    if not oRide then
        return false
    end
    self:UnUseRide()
    return true
end

function CRideCtrl:UseRide(iRide, bSilent)
    local oPlayer = global.oWorldMgr:GetOnlinePlayerByPid(self:GetPid())
    if oPlayer then
        if oPlayer.m_oBaseCtrl.m_oBianShenMgr:GetCurBianShen() then
            if not bSilent then
                oPlayer:NotifyMessage("变身期间不可使用坐骑")
            end
            return
        end
    end
    if iRide == self.m_iUseRide then return end

    local oRide = self:GetRide(iRide)
    if not oRide or oRide:IsExpire() then return end
    
    local oOldRide = self:GetUseRide()
    if oOldRide then
        oOldRide:OnUnUse(self)
    end

    self.m_iUseRide = iRide
    -- oSkill:SkillEffect(self)
    -- oRide:SetupApply()
    oRide:OnUse(self)
    self:Dirty()

    self:SyncUseRidelSumData()
    self:GS2CPlayerRideInfo("use_ride")
    self:SyncSceneInfo()
    self:PlayerSecondPropChange()
    self:PlayerProChange("model_info", "model_info_changed")
end

function CRideCtrl:UnUseRide()
    local oRide = self:GetUseRide()
    if not oRide then return end

    self.m_iUseRide = 0
    oRide:OnUnUse(self)
    self:Dirty()

    self:SyncUseRidelSumData()
    self:GS2CPlayerRideInfo("use_ride")
    self:SyncSceneInfo()
    self:PlayerSecondPropChange()
    self:PlayerProChange("model_info", "model_info_changed")
end

function CRideCtrl:GS2CUpdateUseRide()
    local oWorldMgr = global.oWorldMgr
    local oPlayer = oWorldMgr:GetOnlinePlayerByPid(self:GetPid())
    if oPlayer then
        oPlayer:Send("GS2CUpdateUseRide", {ride_id=self.m_iUseRide})
    end
end

function CRideCtrl:SyncSceneInfo()
    local oWorldMgr = global.oWorldMgr
    local oPlayer = oWorldMgr:GetOnlinePlayerByPid(self:GetInfo("pid"))
    if oPlayer then
        oPlayer:SyncSceneInfo({
            model_info = oPlayer:GetChangedModelInfo(),
            walk_speed = oPlayer:GetWalkSpeed(),
        })
    end
end

function CRideCtrl:SyncSceneFlyInfo()
    local oWorldMgr = global.oWorldMgr
    local oPlayer = oWorldMgr:GetOnlinePlayerByPid(self:GetInfo("pid"))
    if oPlayer then
        oPlayer:SyncSceneInfo({
            fly_height = self:GetRideFly(),
            walk_speed = oPlayer:GetWalkSpeed(),
        })
    end
end

function CRideCtrl:IsMaxLevel()
    local mData = res["daobiao"]["ride"]["upgrade"]
    if mData[self:GetGrade() + 1] then
        return false
    end
    return true
end

function CRideCtrl:GetMaxExp()
    local mData = res["daobiao"]["ride"]["upgrade"]
    local iGrade = self:GetGrade()
    local mGrade = mData[iGrade + 1]
    if not mGrade then return 0 end

    local iNextExp = mGrade["ride_exp"]
    local iMaxExp = 0 
    for i = 1, 3 do
        local mInfo = mData[iGrade + i]
        if not mInfo then
            break
        end
        iMaxExp = iMaxExp + mInfo["ride_exp"]
    end
    return math.min(iMaxExp, 3*iNextExp)
end

function CRideCtrl:GetUpGradeExp()
    local mData = res["daobiao"]["ride"]["upgrade"]
    local mGrade = mData[self:GetGrade() + 1]
    if not mGrade then return end

    return mGrade["ride_exp"]
end

function CRideCtrl:AddExp(iExp, sReason)
    if iExp <= 0 then return end

    local iOldGrade = self:GetGrade()
    local iOldExp = self:GetExp()
    local iMaxExp = self:GetMaxExp()
    if self.m_iExp >= iMaxExp then
        return
    end

    local mData = res["daobiao"]["ride"]["upgrade"]
    if self:IsMaxLevel() then
        self:NotifyMessage(1005)
        return
    end

    self.m_iExp = math.min(self.m_iExp + iExp, iMaxExp)
    local oPlayer = global.oWorldMgr:GetOnlinePlayerByPid(self:GetInfo("pid"))
    if oPlayer then
        local sMsg = global.oToolMgr:FormatColorString("你获得了#exp坐骑经验", {exp = iExp})
        global.oChatMgr:HandleMsgChat(oPlayer, sMsg)
    end
    self:Dirty()
    self:GS2CPlayerRideInfo("grade", "exp", "point", "attrs", "score")

    if oPlayer then
        local mLog = oPlayer:LogData()
        mLog["oldlv"] = iOldGrade
        mLog["oldexp"] = iOldExp
        mLog["newlv"] = self:GetGrade()
        mLog["newexp"] = self:GetExp()
        mLog["addexp"] = iExp
        mLog["reason"] = sReason or ""
        record.user("ride", "exp", mLog)
    end
end

function CRideCtrl:CheckUpGrade(iBreakGrade)
    local mData = res["daobiao"]["ride"]["upgrade"]
    if self:IsMaxLevel() then return end

    iBreakGrade = iBreakGrade or 0
    for i=1,200 do
        local iGrade = self:GetGrade() + 1
        local mGrade = mData[iGrade]
        if not mGrade then 
            self.m_iExp = 0
            self:Dirty()
            break 
        end

        if self.m_iExp < mGrade["ride_exp"] then break end

        local lCost = mGrade["break_cost"]
        if iGrade > iBreakGrade and #lCost > 0 then
            break
        end 

        self.m_iExp = self.m_iExp - mGrade["ride_exp"]
        self:UpGrade()
    end
end

function CRideCtrl:GetApply(sAttr)
    return self.m_oAttrMgr:GetApply(sAttr) + self:GetUseRideAttr(sAttr)
end

function CRideCtrl:GetUseRideAttr(sAttr)
    local oRide = self:GetUseRide()
    if not oRide then return 0 end

    return oRide:GetApply(sAttr)
end

function CRideCtrl:GetRatioApply(sAttr)
    return self.m_oAttrMgr:GetRatioApply(sAttr) 
end

function CRideCtrl:SyncUseRidelSumData(oPlayer)
    if not oPlayer then
        oPlayer = global.oWorldMgr:GetOnlinePlayerByPid(self:GetPid())
    end
    if not oPlayer then return end
    local mAttr = global.oRideMgr:GetRideAllAttrEffect()
    for sAttr,_ in pairs(mAttr) do
        oPlayer:SynclSumSet(gamedefines.SUM_DEFINE.MO_RIDE,sAttr,self:GetUseRideAttr(sAttr))
    end
end

function CRideCtrl:UpGrade()
    self:Dirty()
    self.m_iGrade = self.m_iGrade + 1
    self.m_iPoint = self.m_iPoint + 1
    global.oScoreCache:Dirty(self:GetPid(), "ridectrl")
    self:RefreshScore()
    self:UpdateGradeAttr()
end

-- function CRideCtrl:Setup()
--     self:UpdateGradeAttr()        
--     for _, oSkill in pairs(self.m_mSkills) do
--         oSkill:SkillEffect(self)
--     end
-- end

function CRideCtrl:GetGradeAttrs()
    local mData = res["daobiao"]["ride"]["upgrade"][self:GetGrade()]
    if not mData then return {} end

    local oWorldMgr = global.oWorldMgr
    local oPlayer = oWorldMgr:GetOnlinePlayerByPid(self:GetPid())
    local sKey = ridedefines.RIDE_SCHOOL_KEY[oPlayer:GetSchool()]
    return mData[sKey] or {}
end

function CRideCtrl:UpdateGradeAttr()
    local mData = res["daobiao"]["ride"]["upgrade"][self:GetGrade()]
    if not mData then return end

    local oWorldMgr = global.oWorldMgr
    local oPlayer = oWorldMgr:GetOnlinePlayerByPid(self:GetPid())
    self.m_oAttrMgr:RemoveSource(0)
    local sKey = ridedefines.RIDE_SCHOOL_KEY[oPlayer:GetSchool()]
    local mEffect = mData[sKey] or {}
    for sAttr, iVal in pairs(mEffect) do
        self.m_oAttrMgr:AddApply(sAttr, 0, iVal)
    end

    if oPlayer then
        oPlayer:FirstLevelPropChange()
        oPlayer:SecondLevelPropChange()
        oPlayer:ThreeLevelPropChange()
    end 
end

function CRideCtrl:PlayerProChange(...)
    local oWorldMgr = global.oWorldMgr
    local oPlayer = oWorldMgr:GetOnlinePlayerByPid(self:GetPid())
    if oPlayer then
        oPlayer:AttrPropChange(...)
    end 
end

function CRideCtrl:PlayerSecondPropChange()
    local oWorldMgr = global.oWorldMgr
    local oPlayer = oWorldMgr:GetOnlinePlayerByPid(self:GetPid())
    if oPlayer then
        oPlayer:SecondLevelPropChange()
        oPlayer:ThreeLevelPropChange()
    end  
end

function CRideCtrl:GetSkill(iSkill)
    return self.m_mSkills[iSkill]
end

function CRideCtrl:GetSkillCnt()
    return table_count(self.m_mSkills)
end

function CRideCtrl:GetAdvanceIndexs()
    local mRet = {}
    for _, lIndex in pairs(self.m_mAdvanceSk) do
        local lRet = mRet[lIndex[1]]
        if not lRet then
            lRet = {}
            mRet[lIndex[1]] = lRet
        end
        table.insert(lRet, lIndex[2])
    end
    return mRet
end

function CRideCtrl:AddSkill(oSkill)
    if not oSkill or self:GetSkill(oSkill:SkID()) then return false end
    
    if oSkill:IsBaseSkill() then
        return self:_AddBaseSkill(oSkill)
    elseif oSkill:IsAdvanceSkill() then
        return self:_AddAdvanceSkill(oSkill)
    end
end

function CRideCtrl:_AddBaseSkill(oSkill)
    local lBaseIndex = table_value_list(self.m_mBaseSk)
    for iIdx = 1, ridedefines.BASE_SKILL_NUM do
        if not table_in_list(lBaseIndex, iIdx) then
            self.m_mSkills[oSkill:SkID()] = oSkill
            self.m_mBaseSk[oSkill:SkID()] = iIdx
            global.oScoreCache:Dirty(self:GetPid(), "ridectrl")
            oSkill:SkillEffect(self)
            self:Dirty()
            return true
        end
    end
    return false
end

function CRideCtrl:_AddAdvanceSkill(oSkill)
    local iBaseSk = oSkill:GetBaseSkillId()
    local oBaseSk = self:GetSkill(iBaseSk)
    if not oBaseSk then return false end

    local iBaseIdx = self.m_mBaseSk[iBaseSk]
    if not iBaseIdx then return end

    local lIndex = self:GetAdvanceIndexs()[iBaseIdx] or {}
    for iIdx = 1, oBaseSk:GetAdvanceNum() do
        if not table_in_list(lIndex, iIdx) then
            self.m_mSkills[oSkill:SkID()] = oSkill
            self.m_mAdvanceSk[oSkill:SkID()] = {iBaseIdx, iIdx}
            global.oScoreCache:Dirty(self:GetPid(), "ridectrl")
            oSkill:SkillEffect(self)
            self:Dirty()
            return true
        end
    end
    return false
end

function CRideCtrl:GetBaseIndex(iSk)
    return self.m_mBaseSk[iSk]
end

function CRideCtrl:GetAdvanceIndexBy(iSk)
    return self.m_mAdvanceSk[iSk]
end

function CRideCtrl:GetAdvanceSkillByIndex(iIdx)
    local lSkill = {}
    for iSk,v in pairs(self.m_mAdvanceSk) do
        if v[1] == iIdx then
            table.insert(lSkill, iSk)
        end
    end  
    return lSkill 
end

function CRideCtrl:RemoveSkill(iSkill)
    local oSkill = self:GetSkill(iSkill)
    if not oSkill then return false end

    local iIdx = self.m_mBaseSk[oSkill:SkID()]
    if iIdx then
        local lIndex = self:GetAdvanceIndexs()[iIdx] or {}
        if #lIndex > 0 then return false end    

        self.m_mBaseSk[oSkill:SkID()] = nil
    else
        self.m_mAdvanceSk[oSkill:SkID()] = nil
    end

    self.m_mSkills[iSkill] = nil
    global.oScoreCache:Dirty(self:GetPid(), "ridectrl")
    oSkill:SkillUnEffect(self)
    baseobj_delay_release(oSkill)
    self:RefreshScore()
    self:Dirty()
    return true
end

function CRideCtrl:GetCanLearnSkills()
    if table_count(self.m_mCanLearnSkill) > 0 then
        return self.m_mCanLearnSkill
    end

    local oPlayer = global.oWorldMgr:GetOnlinePlayerByPid(self:GetPid())
    local mCanLearnSkill = {}
    local mSkills = global.oRideMgr:GetAllSkillConfig()
    local lIndex = self:GetAdvanceIndexs()
    for iSk, mSk in pairs(mSkills) do
        if self:CanLearn(mSk, lIndex) then
            local sKey = ridedefines.RIDE_SCHOOL_KEY[oPlayer:GetSchool()]
            local iWeight = mSk[sKey]
            mCanLearnSkill[iSk] = iWeight
        end
    end
    self.m_mCanLearnSkill = mCanLearnSkill
    return mCanLearnSkill
end

function CRideCtrl:ClearCanLearnSkill()
    self.m_mCanLearnSkill = {}
end

function CRideCtrl:CanLearn(mSkill, lIndex)
    local iSkill, iType = mSkill["id"], mSkill["ride_type"]
    local oSkill = self:GetSkill(iSkill)
    if oSkill then
        if oSkill:IsMaxLevel() then
            return false
        end
        return true
    end

    for _, skillid in pairs(mSkill["con_skill"]) do
        if not self:GetSkill(skillid) then return false end
    end

    if iType == ridedefines.SKILL_TYPE.BASE_SKILL then
        if table_count(self.m_mBaseSk) < ridedefines.BASE_SKILL_NUM then
            return true
        end
    elseif iType == ridedefines.SKILL_TYPE.ADVANCE_SKILL then
        local oBaseSk = self:GetSkill(mSkill["con_skill"][1])
        local iBaseIdx = self.m_mBaseSk[oBaseSk:SkID()] 
        if oBaseSk then
            local lAdanceIdx = lIndex[iBaseIdx] or {}
            if #lAdanceIdx < oBaseSk:GetAdvanceNum() then
                return true
            end
        end
    end
    return false
end

function CRideCtrl:NotifyMessage(iText, mArgs)
    local oWorldMgr = global.oWorldMgr
    local oPlayer = oWorldMgr:GetOnlinePlayerByPid(self:GetPid())
    if not oPlayer then return end

    local oRideMgr = global.oRideMgr
    local sMsg = oRideMgr:GetText(iText, mArgs)
    oPlayer:NotifyMessage(sMsg)
end

function CRideCtrl:RefreshScore()
    local oWorldMgr = global.oWorldMgr
    local oPlayer = oWorldMgr:GetOnlinePlayerByPid(self:GetPid())
    if not oPlayer then return end
    self:GS2CPlayerRideInfo("score")
    oPlayer:PropChange("score")
end

function CRideCtrl:GetScore()
    local iScore = 0
    local oPlayer = global.oWorldMgr:GetOnlinePlayerByPid(self:GetPid())
    if not oPlayer then
        return iScore
    end
    if not global.oToolMgr:IsSysOpen("RIDE_SYS",oPlayer,true) then
        return iScore
    end
    
    iScore = iScore + self:GetRideScore()
    --print("1",self:GetRideScore())
    iScore = iScore + self:GetSkillScore()
    --print("2",self:GetSkillScore())
    iScore = iScore + self:GetGradeScore()
    --print("3",self:GetGradeScore())
    --print("GetScore",iScore)
    iScore = iScore + self:GetWenShiScore()
    iScore = math.floor(iScore)
    return iScore
end

function CRideCtrl:GetSkillScore()
    local iScore = 0
    for _, oSkill in pairs(self.m_mSkills) do
        iScore = iScore + oSkill:GetScore()
    end
    --print("GetSkillScore",iScore)
    return iScore
end

function CRideCtrl:GetRideScore()
    local iScore = 0
    for _, oRide in pairs(self.m_mRides) do
        local iRideScore = oRide:GetScore()
        if iRideScore >iScore then
            iScore = iRideScore
        end
    end
    --print("GetRideScore",iScore)
    return iScore
end

function CRideCtrl:GetWenShiScore()
    local iScore = 0
    for _, oRide in pairs(self.m_mRides) do
        iScore = iScore + oRide:GetWenShiScore()
    end
    return iScore
end

function CRideCtrl:GetGradeScore()
    local sGradeScore = global.oRideMgr:GetOtherConfigByKey("gradescore")
    local iScore = formula_string(sGradeScore,{grade = self.m_iGrade})
    --print("GetGradeScore",iScore)
    return iScore
end

function CRideCtrl:GetPerformMap()
    local mPerform = {}
    for _, oSk in pairs(self.m_mSkills) do
        for iPer, iLv in pairs(oSk:GetPerformList()) do
            mPerform[iPer] = iLv
        end
    end

    local oRide = self:GetUseRide()
    if oRide then
        for iPer, iLv in pairs(oRide:GetPerformMap()) do
            mPerform[iPer] = iLv
        end
    end
    return mPerform
end

function CRideCtrl:PackSkillInfo()
    local lSkillNet = {}
    for _, oSkill in pairs(self.m_mSkills) do
        local mSkill = oSkill:PackNetInfo()
        local iRow, iCol = 0, 0
        if oSkill:IsBaseSkill() then
            iRow = self.m_mBaseSk[oSkill:SkID()]
            iCol = 1
        elseif oSkill:IsAdvanceSkill() then
            local lIndex = self.m_mAdvanceSk[oSkill:SkID()]
            iCol = lIndex[2] + 1
            iRow = lIndex[1]
        end
        mSkill["row"] = iRow
        mSkill["col"] = iCol
        table.insert(lSkillNet, mSkill)
    end
    return lSkillNet
end

function CRideCtrl:ResetRideSkill(oPlayer, iGrade, iExp)
    self:Dirty()
    self.m_oAttrMgr:ClearApply()
    self.m_oAttrMgr:ClearRatioApply()
    for _, oSkill in pairs(self.m_mSkills) do
        oSkill:SkillUnEffect(self)
    end

    self.m_iGrade = iGrade
    self.m_iExp = iExp
    self.m_iPoint = iGrade
    self.m_mSkills = {}
    self.m_mBaseSk = {}
    self.m_mAdvanceSk = {}
    self.m_mCanLearnSkill = {}

    self:UpdateRideAttr(oPlayer)
    self:SyncUseRidelSumData(oPlayer)
    self:GS2CPlayerRideInfo() 
    global.oScoreCache:Dirty(self:GetPid(), "ridectrl")
end

function CRideCtrl:CheckTimeCb()
    for _,oRide in pairs(self.m_mRides) do
        oRide:CheckTimeCb()
    end
end

function CRideCtrl:HasChooseSkills()
    return #self.m_lChooseSkill > 0
end

function CRideCtrl:SetChooseSkills(lChooseSkill)
    self.m_lChooseSkill = lChooseSkill
    self:Dirty()
end

function CRideCtrl:GetChooseSkills()
    return self.m_lChooseSkill
end



