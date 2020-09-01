local global = require "global"
local skynet = require "skynet"
local record = require "public.record"
local res = require "base.res"
local net = require "base.net"
local extend = require "base.extend"
local datactrl = import(lualib_path("public.datactrl"))
local gamedefines = import(lualib_path("public.gamedefines")) 

WING_POS = 7

function NewTimeWing(iPid, iWing)
    return CWing:New(iPid, iWing)
end


PropHelperFunc = {}
function PropHelperFunc.id(o)
    return o:GetWieldId()
end

function PropHelperFunc.exp(o)
    return o:GetExp()
end

function PropHelperFunc.star(o)
    return o:GetStar()
end

function PropHelperFunc.level(o)
    return o:GetLevel()
end

function PropHelperFunc.max_hp(o)
    return o:GetAttrByKey("max_hp")
end

function PropHelperFunc.max_mp(o)
    return o:GetAttrByKey("max_mp")
end

function PropHelperFunc.phy_attack(o)
    return o:GetAttrByKey("phy_attack")
end

function PropHelperFunc.phy_defense(o)
    return o:GetAttrByKey("phy_defense")
end

function PropHelperFunc.mag_attack(o)
    return o:GetAttrByKey("mag_attack")
end

function PropHelperFunc.mag_defense(o)
    return o:GetAttrByKey("mag_defense")
end

function PropHelperFunc.cure_power(o)
    return o:GetAttrByKey("cure_power")
end

function PropHelperFunc.speed(o)
    return o:GetAttrByKey("speed")
end

function PropHelperFunc.seal_ratio(o)
    return o:GetAttrByKey("seal_ratio")
end

function PropHelperFunc.res_seal_ratio(o)
    return o:GetAttrByKey("res_seal_ratio")
end

function PropHelperFunc.phy_critical_ratio(o)
    return o:GetAttrByKey("phy_cirtical_ratio")
end

function PropHelperFunc.res_phy_critical_ratio(o)
    return o:GetAttrByKey("res_phy_critical_ratio")
end

function PropHelperFunc.mag_critical_ratio(o)
    return o:GetAttrByKey("mag_critical_ratio")
end

function PropHelperFunc.res_mag_critical_ratio(o)
    return o:GetAttrByKey("res_mag_critical_ratio")
end

function PropHelperFunc.score(o)
    return o:GetScoreCache()
end

function PropHelperFunc.show_wing(o)
    return o:GetShowWing()
end

function PropHelperFunc.time_wing_list(o)
    local lWing = {}
    for iWing, oWing in pairs(o.m_mTimeWings) do
        table.insert(lWing, oWing:PackWingNet())
    end
    return lWing
end

CWingCtrl = {}
CWingCtrl.__index = CWingCtrl
inherit(CWingCtrl, datactrl.CDataCtrl)

function CWingCtrl:New(iPid)
    local o = super(CWingCtrl).New(self, {pid=iPid})
    o.m_iPid = iPid
    o:Init()
    return o
end

function CWingCtrl:Init()
    self.m_iStar = 0
    self.m_iLevel = 0
    self.m_iExp = 0
    self.m_iShowWing = nil
    self.m_mTimeWings = {}              --幻化翅膀具有时效性

    self.m_iMinExpire = 0               --最小过期时间
    self.m_mBaseAttr = {}               --基础属性缓存
end

function CWingCtrl:Release()
    for iWing, oWing in pairs(self.m_mTimeWings) do
        oWing:Release()
    end
    super(CWingCtrl).Release(self)
end

function CWingCtrl:Save()
    local mSave = {}
    mSave.star = self.m_iStar
    mSave.level = self.m_iLevel
    mSave.exp = self.m_iExp
    mSave.show_wing = self.m_iShowWing
    local lTimeWings = {}
    for iWing, oWing in pairs(self.m_mTimeWings) do
        table.insert(lTimeWings, oWing:Save())
    end
    mSave.time_wings = lTimeWings
    return mSave
end

function CWingCtrl:Load(m)
    if not m then return end

    self.m_iStar = m.star
    self.m_iLevel = m.level
    self.m_iExp = m.exp
    self.m_iShowWing = m.show_wing
    for _, mWing in ipairs(m.time_wings or {}) do
        local oWing = NewTimeWing(self.m_iPid, mWing.wing_id)
        self.m_mTimeWings[mWing.wing_id] = oWing
        oWing:Load(mWing)
    end
end

function CWingCtrl:CalApply(oPlayer, bReEnter)
    if self:GetWieldId() then
        self:CalBaseAttr()
        self:TimeWingEffect()
        global.oScoreCache:Dirty(self.m_iPid, "wingctrl")
        self:CheckTimeExpire()
    end
end

function CWingCtrl:CalBaseAttr()
    if not self:GetWieldId() then
        return
    end

    local oPlayer = global.oWorldMgr:GetOnlinePlayerByPid(self.m_iPid)
    if not oPlayer then return end

    local mRefresh = {} 
    for sAttr, iVal in pairs(self.m_mBaseAttr) do
        oPlayer.m_oEquipMgr:AddApply(sAttr, WING_POS, -iVal)
        mRefresh[sAttr] = 1
    end

    local mEnv = {level = self.m_iLevel, star=self.m_iStar}
    local mAttr = self:GetBaseAttr(oPlayer:GetSchool(), mEnv)
    for sAttr, sVal in pairs(mAttr) do
        local iVal = formula_string(sVal, mEnv)
        oPlayer.m_oEquipMgr:AddApply(sAttr, WING_POS, iVal)
        self.m_mBaseAttr[sAttr] = iVal
        mRefresh[sAttr] = 1
    end

    return mRefresh
end

function CWingCtrl:TimeWingEffect()
    local mRefresh = {}
    for iWing, oWing in pairs(self.m_mTimeWings) do
        if not oWing:IsExpire() then
            table_combine(mRefresh, oWing:WingEffect())
        end
    end
    return mRefresh
end

function CWingCtrl:CalNextExpireTime()
    self.m_iMinExpire = 0
    for iWing, oWing in pairs(self.m_mTimeWings) do
        if oWing:IsExpire() then
            goto continue
        end
        local iExpire = oWing:GetExpire()
        if get_time() < iExpire then
            if self.m_iMinExpire == 0 or self.m_iMinExpire > iExpire then
                self.m_iMinExpire = iExpire
            end
        end
        ::continue::
    end
end

function CWingCtrl:GetWieldId()
    local oPlayer = global.oWorldMgr:GetOnlinePlayerByPid(self.m_iPid)
    if oPlayer then
        local oItem = oPlayer.m_oItemCtrl:GetItem(WING_POS)
        if oItem then
            return oItem:SID()
        end
    end
end

function CWingCtrl:Name()
    local oPlayer = global.oWorldMgr:GetOnlinePlayerByPid(self.m_iPid)
    if oPlayer then
        local oItem = oPlayer.m_oItemCtrl:GetItem(WING_POS)
        return oItem:Name()
    end
    return ""
end

function CWingCtrl:GetExp()
    return self.m_iExp
end

function CWingCtrl:GetStar()
    return self.m_iStar
end

function CWingCtrl:GetLevel()
    return self.m_iLevel
end

function CWingCtrl:AddExp(iExp, sReason)
    assert(iExp > 0, sReason)
    self:Dirty()
    self.m_iExp = self.m_iExp + iExp
    local iOldStar = self.m_iStar
    
    for i = 1, 200 do
        local iNextExp = self:GetNeedExp()
        if not iNextExp or self.m_iExp < iNextExp then
            break
        end
        if self.m_iStar >= self:GetMaxStar() then
            break
        end
        
        self.m_iExp = self.m_iExp - iNextExp
        self.m_iStar = self.m_iStar + 1
    end

    self:PropWingChange({exp=1, star=1})

    if iOldStar ~= self.m_iStar then
        self:OnWingUpStar()
        self:Notify(self.m_iPid, 1003, {wing=self:Name(), star=self.m_iStar})
    end

    local mLogData = self:LogData()
    mLogData.old_star = iOldStar
    mLogData.add_exp = iExp
    mLogData.now_exp = self.m_iExp
    mLogData.now_star = self.m_iStar
    mLogData.reason = sReason
    record.log_db("wing", "add_exp", mLogData)
end

function CWingCtrl:OnWingUpStar()
    local mRefresh = self:CalBaseAttr()
    global.oScoreCache:Dirty(self.m_iPid, "wingctrl")
    mRefresh.score = 1
    self:PropWingChange(mRefresh, true)
end

function CWingCtrl:GetNeedExp(iStar, iLevel)
    iLevel = iLevel or self.m_iLevel
    iStar = iStar or self.m_iStar + 1
    return table_get_depth(res, {"daobiao", "wing", "up_star", iLevel, iStar})
end

function CWingCtrl:GetUpStarUseExp(iStar)
    iStar = math.min(iStar, self:GetMaxStar())
    if self.m_iStar >= iStar then
        return 0
    end
    local iNeed = self:GetNeedExp() - self.m_iExp
    if iStar - self.m_iStar >= 2 then
        for i = self.m_iStar+2, iStar do
            iNeed = iNeed + self:GetNeedExp(i)
        end
    end
    return iNeed
end

function CWingCtrl:GetMaxStar()
    local lStar = table_get_depth(res, {"daobiao", "wing", "up_star", self.m_iLevel})
    return lStar and #lStar or 10
end

function CWingCtrl:AddLevel(iLevel, sReason)
    assert(iLevel > 0, sReason)
    self:Dirty()
    local iOldLevel = self.m_iLevel
    self.m_iLevel = self.m_iLevel + iLevel
    self.m_iStar = 0

    self:PropWingChange({level=1, star=1})

   self:OnWingUpLevel()
   self:Notify(self.m_iPid, 2005, {wing=self:Name(), level=self.m_iLevel})

    local mLogData = self:LogData()
    mLogData.old_level = iOldLevel
    mLogData.add_level = iLevel
    mLogData.now_level = self.m_iLevel
    mLogData.reason = sReason
    record.log_db("wing", "add_level", mLogData)
end

function CWingCtrl:OnWingUpLevel()
    local mRefresh = self:CalBaseAttr()
    global.oScoreCache:Dirty(self.m_iPid, "wingctrl")
    mRefresh.score = 1
    self:PropWingChange(mRefresh, true)
end

function CWingCtrl:GetMaxLevel()
    local oPlayer = global.oWorldMgr:GetOnlinePlayerByPid(self.m_iPid)

    local iTargetLimit = 0
    if oPlayer then
        local iPlayerGrade = oPlayer:GetGrade()
        local lLimit = self:GetLevelLimit()
        for i = #lLimit, 1, -1 do
            local mLimit = lLimit[i]
            if iPlayerGrade >= mLimit.player_grade then
                return mLimit.level_limit
            end
        end
    end
    return iTargetLimit
end

function CWingCtrl:AddTimeWing(iWing, sReason)
    self:Dirty()
    local mWing = global.oWingMgr:GetWingInfo()[iWing]
    local oWing = NewTimeWing(self.m_iPid, iWing)
    if mWing.days == -1 then
        oWing:SetTime(-1)
    else
        oWing:AddTime(mWing.days*24*3600)
    end
    self.m_mTimeWings[iWing] = oWing

    self:CalNextExpireTime()
    self:OnAddTimeWing(iWing)

    local mLogData = self:LogData()
    local iExpire = oWing:GetExpire()
    mLogData.wing = iWing
    mLogData.expire = iExpire == -1 and "永久" or get_format_time(iExpire)
    record.log_db("wing", "time_wing", mLogData)
end

function CWingCtrl:OnAddTimeWing(iWing)
    self:RefreshOneTimeWing(iWing)

    local oWing = self:GetTimeWing(iWing)
    local mRefresh = oWing:WingEffect()
    mRefresh.score = 1
    global.oScoreCache:Dirty(self.m_iPid, "wingctrl")
    self:PropWingChange(mRefresh, true)
end

function CWingCtrl:GetTimeWing(iWing)
    return self.m_mTimeWings[iWing]
end

function CWingCtrl:RefreshOneTimeWing(iWing)
    local oWing = self:GetTimeWing(iWing)
    if not oWing then return end

    local oPlayer = global.oWorldMgr:GetOnlinePlayerByPid(self.m_iPid)
    if oPlayer then
        oPlayer:Send("GS2CRefreshOneTimeWing", {info=oWing:PackWingNet()})
    end
end

function CWingCtrl:SetShowWing(iWing)
    self:Dirty()
    self.m_iShowWing = iWing
   
    self:PropWingChange({show_wing=1}) 
    
    local oPlayer = global.oWorldMgr:GetOnlinePlayerByPid(self.m_iPid)
    assert(oPlayer)
    oPlayer:SyncModelInfo()

    local mLogData = self:LogData()
    mLogData.show_wing = iWing
    record.log_db("wing", "show_wing", mLogData)
end

function CWingCtrl:GetShowWing()
    if self.m_iShowWing == 0 then
        return self.m_iShowWing
    end

    if self.m_iShowWing then
        local oWing = self:GetTimeWing(self.m_iShowWing)
        if oWing and oWing:IsExpire() then
            local lWings = self:GetLevelUnlockWings()
            return lWings[#lWings]
        end
        return self.m_iShowWing
    end
end

function CWingCtrl:GetAllWing()
    local mWing = {}
    local lWings = self:GetLevelUnlockWings()
    for _, iWing in ipairs(lWings) do
        mWing[iWing] = 1
    end
    for iWing, oWing in pairs(self.m_mTimeWings) do
        mWing[iWing] = 1
    end
    return mWing
end

function CWingCtrl:GetLevelUnlockWings()
    local mLevelWing = res["daobiao"]["wing"]["level_wing"]
    local lWings = {}
    for _, mWing in ipairs(mLevelWing) do
        if mWing.level <= self.m_iLevel then
            table.insert(lWings, mWing.wing)
        end
    end
    return lWings
end

function CWingCtrl:PackWingNetInfo(mRefresh)
    mRefresh = mRefresh or PropHelperFunc
    local mRet = {}
    for k,v in pairs(mRefresh) do
        local f = assert(PropHelperFunc[k], string.format("wing fail f get %s", k))
        mRet[k] = f(self)
    end
    return net.Mask("WingInfo", mRet)
end

function CWingCtrl:PropWingChange(mRefresh, bSyncPlayer)
    local oPlayer = global.oWorldMgr:GetOnlinePlayerByPid(self.m_iPid)
    if not oPlayer then return end

    local mNet = self:PackWingNetInfo(mRefresh)
    oPlayer:Send("GS2CRefreshWingInfo",{info=mNet})

    if bSyncPlayer and mRefresh and next(mRefresh) then
        if mRefresh.max_hp or mRefresh.max_mp then
            oPlayer:CheckAttr(true)
        end
        local lKey = table_key_list(mRefresh)
        oPlayer:PropChange(table.unpack(lKey))
    end
end

function CWingCtrl:OnLogin(oPlayer, bReEnter)
    local mNet = self:PackWingNetInfo()
    local iOpen = self:GetData("open_wing_ui", 0)
    oPlayer:Send("GS2CLoginWing", {info=mNet, has_open=iOpen})
end

function CWingCtrl:CheckSelf(oPlayer)
    self:CalNextExpireTime()

    local iPid = oPlayer:GetPid()
    local iDelay = self.m_iMinExpire - get_time()
    if self.m_iMinExpire ~= 0 and iDelay < 300 then
        self:DelTimeCb("CheckTimeExpire")
        self:AddTimeCb("CheckTimeExpire", math.max(1, iDelay)*1000, function()
            local oPlayer = global.oWorldMgr:GetOnlinePlayerByPid(iPid)
            if oPlayer then
                oPlayer.m_oWingCtrl:CheckTimeExpire()
            end
        end)
    end
end

function CWingCtrl:CheckTimeExpire()
    self:DelTimeCb("CheckTimeExpire")

    local mRefresh = {}
    for iWing, oWing in pairs(self.m_mTimeWings) do
        if oWing:IsExpire() then
            table_combine(mRefresh, oWing:WingUnEffect())
            mRefresh.score = 1
            global.oScoreCache:Dirty(self.m_iPid, "wingctrl")
        end
    end

    if self.m_iShowWing then
        local oWing = self:GetTimeWing(self.m_iShowWing)
        if oWing and oWing:IsExpire() then
            local lWings = self:GetLevelUnlockWings()
            self:SetShowWing(lWings[#lWings] or 0)
        end
    end

    self:PropWingChange(mRefresh, true)

    local oPlayer = global.oWorldMgr:GetOnlinePlayerByPid(self.m_iPid)
    self:CheckSelf(oPlayer)
end

function CWingCtrl:GetScoreCache()
    local oPlayer = global.oWorldMgr:GetOnlinePlayerByPid(self.m_iPid)
    if oPlayer then
        return global.oScoreCache:GetScoreByKey(oPlayer, "wingctrl")
    else
        return self:GetScore()
    end
end

function CWingCtrl:GetScore()
    if not self:GetWieldId() then
        return 0
    end

    local mEnv = {level = self.m_iLevel, star = self.m_iStar}
    local iScore = self:GetBaseScore(mEnv)
    for iWing, oWing in pairs(self.m_mTimeWings) do
        if not oWing:IsExpire() then
            iScore = iScore + oWing:GetScore()
        end
    end
    return iScore
end

function CWingCtrl:GetAttrByKey(sAttr)
    local oPlayer = global.oWorldMgr:GetOnlinePlayerByPid(self.m_iPid)
    if not oPlayer then return 0 end

    return oPlayer.m_oEquipMgr:GetApplyBySource(sAttr, WING_POS)
end

function CWingCtrl:Notify(iPid, iChat, mReplace)
    local oNotifyMgr = global.oNotifyMgr
    local oToolMgr = global.oToolMgr
    local sMsg = oToolMgr:GetTextData(iChat, {"wing"})
    if mReplace then
        sMsg = oToolMgr:FormatColorString(sMsg, mReplace)
    end
    oNotifyMgr:Notify(iPid, sMsg)
end

function CWingCtrl:LogData()
    local oPlayer = global.oWorldMgr:GetOnlinePlayerByPid(self.m_iPid)
    if oPlayer then
        return oPlayer:LogData()
    end
    return {pid = self.m_iPid}
end

function CWingCtrl:GetLevelLimit()
    return res["daobiao"]["wing"]["level_limit"]
end

function CWingCtrl:GetBaseAttr(iSchool, mEnv)
    local iEffect = res["daobiao"]["wing"]["config"][1]["wing_effect"][iSchool]
    local sEffect = res["daobiao"]["wing"]["wing_effect"][iEffect]["wing_effect"]
    return formula_string(sEffect, mEnv)
end

function CWingCtrl:GetBaseScore(mEnv)
    local sScore = res["daobiao"]["wing"]["config"][1]["score"]
    return formula_string(sScore, mEnv)
end


CWing = {}
CWing.__index = CWing
inherit(CWing, datactrl.CDataCtrl)

function CWing:New(iPid, iWing)
    local o = super(CWing).New(self)
    o.m_iPid = iPid
    o.m_iWing = iWing
    o.m_iExpire = 0
    o.m_mApply = {}
    return o
end

function CWing:Release()
    super(CWing).Release(self)
end

function CWing:Save()
    local mSave = {}
    mSave.wing_id = self.m_iWing
    mSave.expire = self.m_iExpire
    return mSave
end

function CWing:Load(m)
    if not m then return end

    self.m_iWing = m.wing_id
    self.m_iExpire = m.expire
end

function CWing:AddTime(iDelay)
    self.m_iExpire = math.max(self.m_iExpire, get_time())
    self.m_iExpire = self.m_iExpire + iDelay
    self:Dirty()
end

function CWing:SetTime(iTime)
    self.m_iExpire = iTime
    self:Dirty()
end

function CWing:GetExpire()
    return self.m_iExpire
end

function CWing:IsForever()
    return self.m_iExpire == -1
end

function CWing:IsExpire()
    if self:IsForever() then
        return false
    end
    return get_time() >= self.m_iExpire
end

function CWing:PackWingNet()
    local mNet = {}
    mNet.wing_id = self.m_iWing
    mNet.expire = self.m_iExpire
    return mNet
end

function CWing:Dirty()
    local oPlayer = global.oWorldMgr:GetOnlinePlayerByPid(self.m_iPid)
    if oPlayer then
        oPlayer.m_oWingCtrl:Dirty()
    end
end

function CWing:GetWingInfo()
    local mAllWing = global.oWingMgr:GetWingInfo()
    return mAllWing[self.m_iWing]
end

function CWing:WingEffect()
    local mRefresh = self:WingUnEffect()

    local oPlayer = global.oWorldMgr:GetOnlinePlayerByPid(self.m_iPid)
    assert(oPlayer)

    local iSchool = oPlayer:GetSchool()
    local mEffect = global.oWingMgr:GetWingEffect(self.m_iWing, iSchool)
    for sAttr, iVal in pairs(mEffect) do
        oPlayer.m_oEquipMgr:AddApply(sAttr, WING_POS, iVal)
        mRefresh[sAttr] = 1
        self.m_mApply[sAttr] = (self.m_mApply[sAttr] or 0) + iVal
    end
    return mRefresh
end

function CWing:WingUnEffect()
    local oPlayer = global.oWorldMgr:GetOnlinePlayerByPid(self.m_iPid)
    assert(oPlayer)

    local mRefresh = {}
    for sAttr, iVal in pairs(self.m_mApply) do
        oPlayer.m_oEquipMgr:AddApply(sAttr, WING_POS, -iVal)
        mRefresh[sAttr] = 1
    end
    self.m_mApply = {}
    return mRefresh
end

function CWing:GetScore()
    local mInfo = self:GetWingInfo()
    return tonumber(mInfo.score)
end

