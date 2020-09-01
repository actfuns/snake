--import module

local global = require "global"
local skynet = require "skynet"
local net = require "base.net"
local interactive = require "base.interactive"
local res = require "base.res"
local record = require "public.record"
local cjson = require "cjson"
local extend = require "base.extend"
local router = require "base.router"
local lsum = require "lsum"
local playersend = require "base.playersend"

local datactrl = import(lualib_path("public.datactrl"))
local bigpacket = import(lualib_path("public.bigpacket"))
local playernet = import(service_path("netcmd/player"))
local playerctrl = import(service_path("playerctrl.init"))
local skillmgr = import(service_path("skillmgr"))
local equipmgr = import(service_path("equipmgr"))
local titlemgr = import(service_path("title/titleattrmgr"))
local loadskill = import(service_path("skill/loadskill"))
local itemdefines = import(service_path("item.itemdefines"))
local playerop = import(service_path("playerctrl.playerop"))
local gamedefines = import(lualib_path("public.gamedefines"))
local gmobj = import(service_path("gmobj"))
local analy = import(lualib_path("public.dataanaly"))
local gamedb = import(lualib_path("public.gamedb"))
local psum = import(lualib_path("public.psum"))
local analylog = import(lualib_path("public.analylog"))


function NewPlayer(...)
    local o = CPlayer:New(...)
    return o
end


PropHelperFunc = {}

function PropHelperFunc.grade(oPlayer)
    return oPlayer:GetGrade()
end

function PropHelperFunc.name(oPlayer)
    return oPlayer:GetName()
end

function PropHelperFunc.title_list(oPlayer)
    return {}
end

function PropHelperFunc.goldcoin(oPlayer)
    return oPlayer:GetProfile():TrueGoldCoin()
end

function PropHelperFunc.rplgoldcoin(oPlayer)
    return oPlayer:GetProfile():RplGoldCoin()
end

function PropHelperFunc.gold(oPlayer)
    return oPlayer.m_oActiveCtrl:GetData("gold")
end

function PropHelperFunc.silver(oPlayer)
    return oPlayer.m_oActiveCtrl:GetData("silver")
end

function PropHelperFunc.exp(oPlayer)
    return oPlayer.m_oActiveCtrl:GetData("exp")
end

function PropHelperFunc.chubeiexp(oPlayer)
    return oPlayer.m_oActiveCtrl:GetData("chubeiexp")
end

function PropHelperFunc.max_hp(oPlayer)
    return oPlayer:GetMaxHp()
end

function PropHelperFunc.max_mp(oPlayer)
    return oPlayer:GetMaxMp()
end

function PropHelperFunc.hp(oPlayer)
    return oPlayer:GetHp()
end

function PropHelperFunc.mp(oPlayer)
    return oPlayer:GetMp()
end

function PropHelperFunc.energy(oPlayer)
    return oPlayer.m_oActiveCtrl:GetData("energy")
end

function PropHelperFunc.vigor(oPlayer)
    return oPlayer:GetVigor()
end

function PropHelperFunc.physique(oPlayer)
    return oPlayer:GetAttr("physique")
end

function PropHelperFunc.strength(oPlayer)
    return oPlayer:GetAttr("strength")
end

function PropHelperFunc.magic(oPlayer)
    return oPlayer:GetAttr("magic")
end

function PropHelperFunc.endurance(oPlayer)
    return oPlayer:GetAttr("endurance")
end

function PropHelperFunc.agility(oPlayer)
    return oPlayer:GetAttr("agility")
end

function PropHelperFunc.phy_attack(oPlayer)
    return oPlayer:GetPhyAttack()
end

function PropHelperFunc.phy_defense(oPlayer)
    return oPlayer:GetPhyDefense()
end

function PropHelperFunc.mag_attack(oPlayer)
    return oPlayer:GetMagAttack()
end

function PropHelperFunc.mag_defense(oPlayer)
    return oPlayer:GetMagDefense()
end

function PropHelperFunc.cure_power(oPlayer)
    return oPlayer:GetCurePower()
end

function PropHelperFunc.speed(oPlayer)
    return oPlayer:GetSpeed()
end

function PropHelperFunc.seal_ratio(oPlayer)
    return oPlayer:GetClientSealRatio()
end

function PropHelperFunc.res_seal_ratio(oPlayer)
    return oPlayer:GetClientResSealRatio()
end

function PropHelperFunc.phy_critical_ratio(oPlayer)
    return oPlayer:GetPhyCriticalRatio()
end

function PropHelperFunc.res_phy_critical_ratio(oPlayer)
    return oPlayer:GetResPhyCriticalRatio()
end

function PropHelperFunc.mag_critical_ratio(oPlayer)
    return oPlayer:GetMagCriticalRatio()
end

function PropHelperFunc.res_mag_critical_ratio(oPlayer)
    return oPlayer:GetResMagCriticalRatio()
end

function PropHelperFunc.model_info(oPlayer)
    return oPlayer:GetModelInfo()
end

function PropHelperFunc.model_info_changed(oPlayer)
    return oPlayer:GetChangedModelInfo()
end

function PropHelperFunc.school(oPlayer)
    return oPlayer:GetSchool()
end

function PropHelperFunc.point(oPlayer)
    return oPlayer:GetPoint()
end

function PropHelperFunc.critical_multiple(oPlayer)
    return oPlayer:GetCriticalMultiple()
end

function PropHelperFunc.gold_over(oPlayer)
    return oPlayer.m_oActiveCtrl:GetData("gold_over")
end

function PropHelperFunc.silver_over(oPlayer)
    return oPlayer.m_oActiveCtrl:GetData("silver_over")
end

function PropHelperFunc.silver_owe(oPlayer)
    return oPlayer.m_oActiveCtrl:GetData("silver_owe")
end

function PropHelperFunc.gold_owe(oPlayer)
    return oPlayer.m_oActiveCtrl:GetData("gold_owe")
end

function PropHelperFunc.goldcoin_owe(oPlayer)
    return oPlayer:GetProfile():GoldCoinOwe()
end

function PropHelperFunc.truegoldcoin_owe(oPlayer)
    return oPlayer:GetProfile():TrueGoldCoinOwe()
end

function PropHelperFunc.followers(oPlayer)
    return oPlayer:GetFollowers()
end

function PropHelperFunc.sex(oPlayer)
    return oPlayer:GetSex()
end

function PropHelperFunc.icon(oPlayer)
    return oPlayer:GetIcon()
end

function PropHelperFunc.upvote_amount(oPlayer)
    return oPlayer:GetUpvoteAmount()
end

function PropHelperFunc.achieve(oPlayer)
    return oPlayer:GetAchieve()
end

function PropHelperFunc.score(oPlayer)
    return oPlayer:GetScore()
end

function PropHelperFunc.position(oPlayer)
    return oPlayer:GetPosition()
end

function PropHelperFunc.position_hide(oPlayer)
    return oPlayer:GetPositionHide()
end

function PropHelperFunc.rename(oPlayer)
    return oPlayer:GetRename()
end

function PropHelperFunc.org_id(oPlayer)
    return oPlayer:GetOrgID()
end

function PropHelperFunc.org_status(oPlayer)
    return oPlayer:GetOrgStatus()
end

function PropHelperFunc.org_pos(oPlayer)
    return oPlayer:GetOrgPos()
end

function PropHelperFunc.org_offer(oPlayer)
    return oPlayer:GetOffer()
end

function PropHelperFunc.title_info(oPlayer)
    return oPlayer:PackTitleInfo()
end

function PropHelperFunc.title_info_changed(oPlayer)
    return oPlayer:PackChangedTitleInfo()
end

function PropHelperFunc.skill_point(oPlayer)
    return oPlayer.m_oActiveCtrl:GetData("sk_point")
end

function PropHelperFunc.orgname(oPlayer)
    return oPlayer:GetOrgName()
end

function PropHelperFunc.show_id(oPlayer)
    return oPlayer:GetShowId()
end

function PropHelperFunc.max_sp(oPlayer)
    return oPlayer:GetMaxSp()
end

function PropHelperFunc.sp(oPlayer)
    return oPlayer:GetSp()
end

function PropHelperFunc.fly_height(oPlayer)
    return oPlayer.m_oRideCtrl:GetRideFly()
end

function PropHelperFunc.wuxun(oPlayer)
    return oPlayer.m_oActiveCtrl:GetData("wuxun")
end

function PropHelperFunc.jjcpoint(oPlayer)
    return oPlayer.m_oActiveCtrl:GetData("jjcpoint")
end

function PropHelperFunc.leaderpoint(oPlayer)
    return oPlayer.m_oActiveCtrl:GetData("leaderpoint")
end

function PropHelperFunc.xiayipoint(oPlayer)
    return oPlayer.m_oActiveCtrl:GetData("xiayipoint")
end

function PropHelperFunc.summonpoint(oPlayer)
    return oPlayer.m_oActiveCtrl:GetData("summonpoint")
end

function PropHelperFunc.storypoint(oPlayer)
    return oPlayer.m_oActiveCtrl:GetData("storypoint")
end

function PropHelperFunc.prop_info(oPlayer)
    return oPlayer:PackSecondUnit()
end

function PropHelperFunc.engage_info(oPlayer)
    return oPlayer:PackCoupleInfo()
end

function PropHelperFunc.chumopoint(oPlayer)
    return oPlayer.m_oActiveCtrl:GetData("chumopoint")
end

CPlayer = {}
CPlayer.__index = CPlayer
inherit(CPlayer, datactrl.CDataCtrl)

function CPlayer:New(mConn, mRole)
    local o = super(CPlayer).New(self)

    o.m_iNetHandle = mConn.handle
    o.m_sIP = mConn.ip
    o.m_sMac = mRole.mac
    o.m_sDevice = mRole.device
    o.m_iPlatform = mRole.platform
    o.m_iFakePlatform = mRole.fake_platform
    o.m_sRoleToken = mRole.role_token
    o.m_sAccountToken = mRole.account_token
    o.m_iPid = mRole.pid
    o.m_sAccount = mRole.account
    o.m_iChannel = mRole.channel
    o.m_sCpsChannel = mRole.cps
    o.m_iCreateTime = mRole.create_time or 0
    o.m_sBornServer = mRole.born_server or get_server_tag()
    o.m_sIMEI = mRole.imei
    o.m_sClientOs = mRole.os
    o.m_sClientVer = mRole.client_ver
    o.m_sUDID = mRole.udid
    o.m_mCbtPay = mRole.cbtpay
    o.m_iForceLogin = mRole.forcelogin or 0

    o.m_oBigPacketMgr = bigpacket.CBigPacketMgr:New()
    o.m_iDisconnectedTime = nil
    o.m_fHeartBeatTime = get_time()
    o.m_iLogoutJudgeTime = 20*60
    o.m_iTestLogoutJudgeTimeMode = nil
    o.m_orgInviteInfo = {}                  -- 帮派邀请信息，不存库
    o.m_mWarEndCB = {}
    o.m_iDurationCalTime = get_time()
    o.m_mTempInfo = {}

    o.m_oBaseCtrl = playerctrl.NewBaseCtrl(o.m_iPid)
    o.m_oActiveCtrl = playerctrl.NewActiveCtrl(o.m_iPid)
    o.m_oItemCtrl = playerctrl.NewItemCtrl(o.m_iPid)
    o.m_oThisTemp = playerctrl.NewThisTempCtrl(o.m_iPid)
    o.m_oToday = playerctrl.NewTodayCtrl(o.m_iPid)
    o.m_oThisWeek = playerctrl.NewWeekCtrl(o.m_iPid)
    o.m_oSeveralDay = playerctrl.NewSeveralDayCtrl(o.m_iPid)
    o.m_oTodayMorning = playerctrl.NewTodayMorningCtrl(o.m_iPid)
    o.m_oWeekMorning = playerctrl.NewWeekMorningCtrl(o.m_iPid)
    o.m_oTimeCtrl = playerctrl.NewTimeCtrl(o.m_iPid,{
        ["Today"] = o.m_oToday,
        ["Week"] = o.m_oThisWeek,
        ["ThisTemp"] = o.m_oThisTemp,
        ["SeveralDay"] = o.m_oSeveralDay,
        ["TodayMorning"] = o.m_oTodayMorning,
        ["WeekMorning"] = o.m_oWeekMorning,
        })
    o.m_oTaskCtrl = playerctrl.NewTaskCtrl(o.m_iPid)
    o.m_oWHCtrl = playerctrl.NewWHCtrl(o.m_iPid)
    o.m_oSkillCtrl = playerctrl.NewSkillCtrl(o.m_iPid)
    o.m_oSkillMgr = skillmgr.NewSkillMgr(o.m_iPid)
    o.m_oEquipMgr = equipmgr.NewEquipMgr(o.m_iPid)
    o.m_oTitleMgr = titlemgr.NewAttrMgr(o.m_iPid)
    o.m_oSummonCtrl = playerctrl.NewSummonCtrl(o.m_iPid)
    o.m_oScheduleCtrl = playerctrl.NewScheduleCtrl(o.m_iPid)
    o.m_oStateCtrl = playerctrl.NewStateCtrl(o.m_iPid)
    o.m_oPartnerCtrl = playerctrl.NewPartnerCtrl(o.m_iPid)
    o.m_oTitleCtrl = playerctrl.NewTitleCtrl(o.m_iPid)
    o.m_oTouxianCtrl= playerctrl.NewTouxianCtrl(o.m_iPid)
    o.m_oAchieveCtrl = playerctrl.NewAchieveCtrl(o.m_iPid)
    o.m_oRideCtrl = playerctrl.NewRideCtrl(o.m_iPid)
    o.m_mPromoteCtrl = playerctrl.NewPromoteCtrl(o.m_iPid)
    o.m_mTempItemCtrl = playerctrl.NewTempItemCtrl(o.m_iPid)
    o.m_mRecoveryCtrl = playerctrl.NewRecoveryCtrl(o.m_iPid)
    o.m_oStoreCtrl = playerctrl.NewStoreCtrl(o.m_iPid)
    o.m_oEquipCtrl = playerctrl.NewEquipCtrl(o.m_iPid)
    o.m_cSumCtrl = lsum.lsum_create()
    o.m_oPSumCtrl = psum:NewCSumAttr()
    o.m_oSummCkCtrl = playerctrl.NewSummonCkCtrl(o.m_iPid)
    o.m_oFaBaoCtrl = playerctrl.NewFaBaoCtrl(o.m_iPid)
    o.m_oArtifactCtrl = playerctrl.NewArtifactCtrl(o.m_iPid)
    o.m_oWingCtrl = playerctrl.NewWingCtrl(o.m_iPid)
    o.m_oMarryCtrl = playerctrl.NewMarryCtrl(o.m_iPid)
    return o
end

function CPlayer:Release()
    baseobj_safe_release(self.m_oBaseCtrl)
    baseobj_safe_release(self.m_oActiveCtrl)
    baseobj_safe_release(self.m_oItemCtrl)
    baseobj_safe_release(self.m_oTimeCtrl)
    baseobj_safe_release(self.m_oTaskCtrl)
    baseobj_safe_release(self.m_oWHCtrl)
    baseobj_safe_release(self.m_oSkillCtrl)
    baseobj_safe_release(self.m_oSkillMgr)
    baseobj_safe_release(self.m_oEquipMgr)
    baseobj_safe_release(self.m_oTitleMgr)
    baseobj_safe_release(self.m_oStateCtrl)
    baseobj_safe_release(self.m_oSummonCtrl)
    baseobj_safe_release(self.m_oScheduleCtrl)
    baseobj_safe_release(self.m_oPartnerCtrl)
    baseobj_safe_release(self.m_oTitleCtrl)
    baseobj_safe_release(self.m_oTouxianCtrl)
    baseobj_safe_release(self.m_oAchieveCtrl)
    baseobj_safe_release(self.m_mPromoteCtrl)
    baseobj_safe_release(self.m_mTempItemCtrl)
    baseobj_safe_release(self.m_mRecoveryCtrl)
    baseobj_safe_release(self.m_oRideCtrl)
    baseobj_safe_release(self.m_oStoreCtrl)
    baseobj_safe_release(self.m_oEquipCtrl)
    baseobj_safe_release(self.m_oSummCkCtrl)
    baseobj_safe_release(self.m_oFaBaoCtrl)
    baseobj_safe_release(self.m_oArtifactCtrl)
    baseobj_safe_release(self.m_oWingCtrl)
    baseobj_safe_release(self.m_oMarryCtrl)
    if self.m_oPSumCtrl then
        baseobj_safe_release(self.m_oPSumCtrl)
    end
    super(CPlayer).Release(self)
end

function CPlayer:AfterLoad()
    self.m_oFaBaoCtrl:AfterLoadByPlayer(self)
end

function CPlayer:ReInitRoleInfo(mConn, mRole)
    self.m_sIP = mConn.ip
    self.m_sMac = mRole.mac
    self.m_sDevice = mRole.device
    self.m_iPlatform = mRole.platform
    self.m_sRoleToken = mRole.role_token
    self.m_sAccountToken = mRole.account_token
    self.m_iChannel = mRole.channel
    self.m_sCpsChannel = mRole.cps
    self.m_sIMEI = mRole.imei
    self.m_sClientOs = mRole.os
    self.m_sClientVer = mRole.client_ver
    self.m_iFakePlatform = mRole.fake_platform
    self.m_mCbtPay = mRole.cbtpay
end

function CPlayer:GetRoleToken()
    return self.m_sRoleToken
end

function CPlayer:GetAccountToken()
    return self.m_sAccountToken
end

function CPlayer:GetBornServer()
    return self.m_sBornServer
end

function CPlayer:GetBornServerKey()
    return make_server_key(self.m_sBornServer)
end

function CPlayer:GetNowServer()
    return self:GetData("now_server")
end

function CPlayer:SetNowServer()
    return self:SetData("now_server", get_server_tag())
end

function CPlayer:SetLogoutJudgeTime(i)
    self.m_iLogoutJudgeTime = i or 20*60
end

function CPlayer:GetLogoutJudgeTime()
    return self.m_iLogoutJudgeTime
end

function CPlayer:SetTestLogoutJudgeTimeMode(iMode)
    assert(table_in_list({1, 2, 3, 4}, iMode), string.format("SetTestLogoutJudgeTimeMode %d", iMode))
    self.m_iTestLogoutJudgeTimeMode = iMode
end

function CPlayer:GetTestLogoutJudgeTimeMode()
    return self.m_iTestLogoutJudgeTimeMode
end

function CPlayer:GetWarModel(oWarBianshen)
    local mModel = {}
    if oWarBianshen then
        mModel = self:PackBianShenModelInfo(oWarBianshen)
    else
        mModel = self:GetModelInfo()
    end
    return mModel
end

function CPlayer:PackWarInfo(mWarInitInfo)
    local mRet = {}
    mRet.pid = self.m_iPid
    mRet.grade = self:GetGrade()
    mRet.name = self:GetName()
    mRet.school = self:GetSchool()
    mRet.sex = self:GetSex()
    mRet.hp = self:GetHp()
    mRet.mp = self:GetMp()
    mRet.max_hp = self:GetMaxHp()
    mRet.max_mp = self:GetMaxMp()
    mRet.exp = self:GetExp()
    mRet.physique = self:GetAttr("physique")
    mRet.magic = self:GetAttr("magic")
    mRet.strength = self:GetAttr("strength")
    mRet.endurance = self:GetAttr("endurance")
    mRet.agility = self:GetAttr("agility")
    local oWarBianshen = self.m_oBaseCtrl.m_oBianShenMgr:GetCurWarBianShen(mWarInitInfo or {})
    mRet.model_info = self:GetWarModel(oWarBianshen)
    mRet.mag_defense = self:GetMagDefense()
    mRet.phy_defense = self:GetPhyDefense()
    mRet.mag_attack = self:GetMagAttack()
    mRet.phy_attack = self:GetPhyAttack()
    mRet.phy_critical_ratio = self:GetPhyCriticalRatio()
    mRet.res_phy_critical_ratio = self:GetResPhyCriticalRatio()
    mRet.mag_critical_ratio = self:GetMagCriticalRatio()
    mRet.res_mag_critical_ratio = self:GetResMagCriticalRatio()
    mRet.seal_ratio = self:GetSealRatio()
    mRet.res_seal_ratio = self:GetResSealRatio()
--    mRet.hit_ratio = self:GetHitRatio()
--    mRet.hit_res_ratio = self:GetHitResRatio()
    mRet.phy_hit_ratio = self:GetPhyHitRatio()
    mRet.phy_hit_res_ratio = self:GetPhyHitResRatio()
    mRet.mag_hit_ratio = self:GetMagHitRatio()
    mRet.mag_hit_res_ratio = self:GetMagHitResRatio()
    mRet.res_phy_defense_ratio = self:GetAttr("res_phy_defense_ratio")
    mRet.res_mag_defense_ratio = self:GetAttr("res_mag_defense_ratio")

    mRet.cure_power = self:GetCurePower()
    mRet.speed = self:GetSpeed()
    mRet.perform = self:GetPerformMap(oWarBianshen)
    mRet.expertskill = self.m_oSkillCtrl:PackExpertSkill()
    mRet.mag_damage_add = self:GetAttr("mag_damage_add")
    mRet.phy_damage_add = self:GetAttr("phy_damage_add")
    mRet.protectors = self:GetProtectors()
    mRet.appoint = self:IsAppoint()
    mRet.auto_perform = self.m_oActiveCtrl:GetAutoPerform()
    mRet.auto_fight = self.m_oActiveCtrl:GetAutoFight()
    if self.m_mTestWarAttr then
        mRet.testdata = self.m_mTestWarAttr
    end

    local iCouplePid = self:GetCouplePid()
    mRet.couple_pid = iCouplePid
    if iCouplePid and iCouplePid > 0 then
        mRet.couple_degree = self:GetFriend():GetFriendDegree(iCouplePid)
    end
    mRet.zhenqi = self.m_oFaBaoCtrl:GetZhenQi()
    return mRet
end

function CPlayer:PackBackendWarInfo()
    local mRet = {}
    mRet.max_hp = self:GetMaxHp()
    mRet.max_mp = self:GetMaxMp()
    mRet.hp = self:GetHp()
    mRet.mp = self:GetMp()
    mRet.physique = self:GetAttr("physique")
    mRet.magic = self:GetAttr("magic")
    mRet.strength = self:GetAttr("strength")
    mRet.endurance = self:GetAttr("endurance")
    mRet.agility = self:GetAttr("agility")
    mRet.mag_defense = self:GetMagDefense()
    mRet.phy_defense = self:GetPhyDefense()
    mRet.mag_attack = self:GetMagAttack()
    mRet.phy_attack = self:GetPhyAttack()
    mRet.phy_critical_ratio = self:GetPhyCriticalRatio()
    mRet.res_phy_critical_ratio = self:GetResPhyCriticalRatio()
    mRet.mag_critical_ratio = self:GetMagCriticalRatio()
    mRet.res_mag_critical_ratio = self:GetResMagCriticalRatio()
    mRet.seal_ratio = self:GetSealRatio()
    mRet.res_seal_ratio = self:GetResSealRatio()
    mRet.phy_hit_ratio = self:GetPhyHitRatio()
    mRet.phy_hit_res_ratio = self:GetPhyHitResRatio()
    mRet.mag_hit_ratio = self:GetMagHitRatio()
    mRet.mag_hit_res_ratio = self:GetMagHitResRatio()
    mRet.cure_power = self:GetCurePower()
    mRet.speed = self:GetSpeed()
    mRet.mag_damage_add = self:GetAttr("mag_damage_add")
    mRet.phy_damage_add = self:GetAttr("phy_damage_add")
    return mRet
end

function CPlayer:GetPerformMap(oWarBianshen)
    local mPerform = self:GetSchoolPerform(false, oWarBianshen)
    for iPer, iLv in pairs(self.m_oRideCtrl:GetPerformMap()) do
        mPerform[iPer] = iLv
    end
    for iPer, iLv in pairs(self.m_oFaBaoCtrl:GetPerformMap()) do
        mPerform[iPer] = iLv
    end
    for iSkill, oSkill in pairs(self.m_oSkillCtrl:GetItemSkill()) do
        table_combine(mPerform, oSkill:GetPerformList())
    end
    for iSkill, oSkill in pairs(self.m_oArtifactCtrl:GetSpiritSkill()) do
        table_combine(mPerform, oSkill:GetPerformList())
    end
    for iSkill, oSkill in pairs(self.m_oSkillCtrl:GetMarrySkills()) do
        table_combine(mPerform, oSkill:GetPerformList())
    end

    local mPfConflict = res["daobiao"]["pfconflict"]
    for _, mInfo in ipairs(mPfConflict) do
        if not mPerform[mInfo.pfid] then
            goto continue
        end
        for _, iPerform in ipairs(mInfo.pfid_list) do
            mPerform[iPerform] = nil
        end
        ::continue::
    end
    return mPerform
end

function CPlayer:PackRoData()
    local mData = self:PackWarInfo()
    mData.auto_perform = nil
    mData.auto_fight = nil
    mData.score = self:GetScore()
    mData.icon = self:GetIcon()
    mData.hp = self:GetMaxHp()
    mData.mp = self:GetMaxMp()
    return mData
end

function CPlayer:PackWarFormationInfo(iLimit)
    local oFmtMgr = self:GetFormationMgr()
    return oFmtMgr:PackWarFormationInfo(iLimit)
end

function CPlayer:OnEnterWar(bReEnter)
    local oNotifyMgr = global.oNotifyMgr
    for iPos=1,6 do
        local oItem = self.m_oItemCtrl:GetItem(iPos)
        if oItem then
            if oItem:GetData("last",0) <= 0 then
                oNotifyMgr:Notify(self.m_iPid,string.format("[%s]已损坏，请点击装备修理耐久度",oItem:Name()))
            end
        end
    end
end

function CPlayer:GetNowScene()
    return self.m_oActiveCtrl:GetNowScene()
end

function CPlayer:GetNowPos()
    return self.m_oActiveCtrl:GetNowPos()
end

function CPlayer:GetFollowers()
    local mFollowers = {}
    local mFollowSumm = self.m_oSummonCtrl:FollowerInfo()
    if mFollowSumm then
        table.insert(mFollowers, mFollowSumm)
    end
    local mFollowNpcs = self.m_oTaskCtrl:FollowersInfo()
    if mFollowNpcs then
        list_combine(mFollowers, mFollowNpcs)
    end
    return mFollowers
end

function CPlayer:GetSubmitableSummons(sid)
    return self.m_oSummonCtrl:GetSubmitableSummons(sid)
end

function CPlayer:PackSceneInfo()
    local mRet = {}
    mRet.name = self:GetName()
    mRet.model_info = self:GetChangedModelInfo()
    mRet.icon = self:GetIcon()
    mRet.followers = self:GetFollowers()
    mRet.title_info = self:GetChangedTitleInfo()
    mRet.show_id = self:GetShowId()
    mRet.touxian_tag = self.m_oTouxianCtrl:GetTouxianID()
    mRet.marker_limit = self.m_oBaseCtrl.m_oSysConfigMgr:GetMarkerCountSetting()
    mRet.org_id = self:GetOrgID()
    mRet.fly_height = self.m_oRideCtrl:GetRideFly()
    mRet.engage_pid = self:GetCouplePid()
    mRet.dance_tag = self.m_oStateCtrl:GetState(1002) and 1 or 0
    return mRet
end

function CPlayer:SyncSceneInfo(m)
    local oNowScene = self.m_oActiveCtrl:GetNowScene()
    if oNowScene then
        oNowScene:SyncPlayerInfo(self, m)
    end
end

function CPlayer:GetAccount()
    return self.m_sAccount
end

function CPlayer:GetCpsChannel()
    return self.m_sCpsChannel
end

function CPlayer:GetChannel()
    return self.m_iChannel
end

function CPlayer:GetChannelUuid()
    return self:GetAccount()
end

function CPlayer:GetPlatform()
    return self.m_iPlatform or 3
end

function CPlayer:GetFakePlatform()
    return self.m_iFakePlatform
end

function CPlayer:GetIMEI()
    return self.m_sIMEI
end

function CPlayer:GetClientOs()
    return self.m_sClientOs
end

function CPlayer:GetClientVer()
    return self.m_sClientVer
end

function CPlayer:GetCreateTime()
    return self.m_iCreateTime
end

function CPlayer:GetPlatformDesc()
    return gamedefines.PLATFORM_DESC[self:GetPlatform()]
end

function CPlayer:GetIP()
    return self.m_sIP or ""
end

function CPlayer:SetDevice(sDevice)
    self.m_sDevice = sDevice
end

function CPlayer:GetDevice()
    return self.m_sDevice or ""
end

function CPlayer:GetMac()
    return self.m_sMac or ""
end

function CPlayer:GetTrueMac()
    local sMac = self.m_sMac or ""
    local lMac = split_string(sMac," ")
    if next(lMac) then
        return lMac[1]
    else
        return sMac
    end
end

function CPlayer:GetUDID()
    return self.m_sUDID or ""
end

function CPlayer:GetPid()
    return self.m_iPid
end

function CPlayer:GetConn()
    local oWorldMgr = global.oWorldMgr
    return oWorldMgr:GetConnection(self.m_iNetHandle)
end

function CPlayer:GetNetHandle()
    return self.m_iNetHandle
end

function CPlayer:SetNetHandle(iNetHandle)
    self.m_iNetHandle = iNetHandle
    if iNetHandle then
        self.m_iDisconnectedTime = nil
    else
        self.m_iDisconnectedTime = get_msecond()
        self:OnDisconnected()
    end
    self:OnConnectionChange()
end

function CPlayer:OnConnectionChange()
    global.oMailAddrMgr:OnConnectionChange(self)
end

function CPlayer:Send(sMessage, mData)
    playersend.Send(self:GetPid(),sMessage,mData)
end

function CPlayer:SendRaw(sData)
    playersend.SendRaw(self:GetPid(),sData)
end

function CPlayer:MailAddr()
    local oConn = self:GetConn()
    if oConn then
        return oConn:MailAddr()
    end
end

function CPlayer:OnLogout()
    local mLogData = self:LogData()
    mLogData["account"] = self:GetAccount()
    mLogData["channel"] = self:GetChannel()
    mLogData["duration"] = string.format("%.2f", (get_time() - self.m_iDurationCalTime) / 60)
    record.log_db("player", "logout", mLogData)

    -- 数据中心log
    self:LoginOrOutAnalyInfo(2)

    global.oRankMgr:RefreshRankByPid(self:GetPid())

    self.m_mTempItemCtrl:OnLogout()
    self.m_oTaskCtrl:OnLogout()
    self.m_oSummonCtrl:OnLogout(self)
    local oWarMgr = global.oWarMgr
    oWarMgr:OnLogout(self)
    local oTeamMgr = global.oTeamMgr
    oTeamMgr:OnLogout(self)
    local oSceneMgr = global.oSceneMgr
    oSceneMgr:OnLogout(self)
    local oNotifyMgr = global.oNotifyMgr
    oNotifyMgr:OnLogout(self)
    local oFriendMgr = global.oFriendMgr
    oFriendMgr:OnLogout(self)
    local oHuodongMgr = global.oHuodongMgr
    oHuodongMgr:OnLogout(self)
    local oProfile = self:GetProfile()
    oProfile:OnLogout(self)
    local oFriend = self:GetFriend()
    oFriend:OnLogout(self)
    local oJJCCtrl = self:GetJJC()
    oJJCCtrl:OnLogout(self)
    local oChallenge = self:GetChallenge()
    oChallenge:OnLogout(self)
    local oWanfaCtrl = self:GetWanfaCtrl()
    oWanfaCtrl:OnLogout(self)
    local oOrgMgr = global.oOrgMgr
    oOrgMgr:OnLogout(self)
    local oInterfaceMgr = global.oInterfaceMgr
    oInterfaceMgr:OnLogout(self)
    local oRankMgr = global.oRankMgr
    oRankMgr:OnLogout(self)
    local oWorldMgr = global.oWorldMgr
    oWorldMgr:SetPlayerByShowId(self:GetShowId(), nil)
    local oCatalogMgr = global.oCatalogMgr
    oCatalogMgr:OnLogout(self)
    local oAuction = global.oAuction
    oAuction:OnLogout(self)
    global.oMentoring:OnLogout(self)
    local oFeedBack = self:GetFeedBack()
    oFeedBack:OnLogout()

    self:UnRegisterClientUpdate()

    self.m_oActiveCtrl:SetDisconnectTime()
    --self:DoSave()

    safe_call(self.AllSendBackendLog, self)
end

function CPlayer:HandleBadBoy(sDebug)
    --just disconnect, not to logout
    record.warning("CPlayer HandleBadBoy pid:%d debug:%s", self:GetPid(), sDebug)
    self:Disconnect()
end

function CPlayer:Disconnect()
    --disconnect
    local oWorldMgr = global.oWorldMgr
    local oConn = self:GetConn()
    if oConn then
        oWorldMgr:KickConnection(oConn.m_iHandle)
    end
end

function CPlayer:PreLogin(bReEnter)
    self.m_oBaseCtrl:PreLogin(self, bReEnter)
    self.m_oActiveCtrl:PreLogin(self, bReEnter)
    self.m_oEquipMgr:PreLogin(bReEnter)
    self.m_oPartnerCtrl:PreLogin(self, bReEnter)
    self.m_oRideCtrl:PreLogin(self, bReEnter)
    self.m_oTitleCtrl:PreLogin(self, bReEnter)
    self.m_oTouxianCtrl:PreLogin(self, bReEnter)
end

function CPlayer:LoginEnd(bReEnter)
    safe_call(self.m_oTaskCtrl.LoginEnd, self.m_oTaskCtrl, self, bReEnter)
    safe_call(self.FirstLoginEnd, self)
    self:CheckUpGrade()
end

function CPlayer:OnLogin(bReEnter)
    local mMail = self:MailAddr()
    local mLogData = self:LogData()
    mLogData["account"] = self:GetAccount()
    mLogData["reenter"] = bReEnter and 1 or 0
    mLogData["device"] = self:GetDevice()
    mLogData["mac"] = self:GetMac()
    mLogData["platform"] = self:GetPlatform()
    mLogData["ip"] = self:GetIP()
    mLogData["fd"] = 0
    if mMail then
        mLogData["fd"] = mMail.fd
    end
    record.log_db("player", "login", mLogData)

    -- 数据中心log
    self:LoginOrOutAnalyInfo(1)

    local iNowTime = get_time()
    local oWorldMgr = global.oWorldMgr
    local oNotifyMgr = global.oNotifyMgr
    local oTeamMgr =  global.oTeamMgr
    self.m_iDurationCalTime = iNowTime

    if not bReEnter then
        self:PreCheck()
    end
    self:PreLogin(bReEnter)

    self.m_oItemCtrl:CalApply(self,bReEnter)
    self.m_oSkillCtrl:CalApply(self,bReEnter)
    self.m_oArtifactCtrl:CalApply(self,bReEnter)
    self.m_oWingCtrl:CalApply(self,bReEnter)
    self:CheckAttr()

    local oProfile = self:GetProfile()
    local oFriend = self:GetFriend()
    local oPrivacy = self:GetPrivacy()
    local oWanfaCtrl = self:GetWanfaCtrl()
    local oJJCCtrl = self:GetJJC()
    local oFeedBack = self:GetFeedBack()
    oProfile:OnLogin(self,bReEnter)
    oFriend:OnLogin(self,bReEnter)
    oPrivacy:OnLogin(self,bReEnter)
    oWanfaCtrl:OnLogin(self,bReEnter)
    oJJCCtrl:OnLogin(self,bReEnter)
    oFeedBack:OnLogin(self, bReEnter)
    self.m_oWingCtrl:OnLogin(self,bReEnter)
    global.oScoreCache:RemoveExclude(self:GetPid())

    self:GS2CLoginRole()
    self.m_fHeartBeatTime = get_time()

    oWorldMgr:OnLogin(self, bReEnter)

    local oSceneMgr = global.oSceneMgr
    oSceneMgr:OnLogin(self, bReEnter)

    local oWar = self.m_oActiveCtrl:GetNowWar()
    if oWar then
        local oWarMgr = global.oWarMgr
        oWarMgr:OnLogin(self, bReEnter)
    end
    oNotifyMgr:OnLogin(self, bReEnter)

    if not bReEnter then
        self:AfterSendLogin()
    end
    self.m_oItemCtrl:OnLogin(self,bReEnter)
    self.m_oSkillCtrl:OnLogin(self,bReEnter)
    -- self.m_oTaskCtrl:OnLogin(self,bReEnter)
    safe_call(self.m_oTaskCtrl.OnLogin, self.m_oTaskCtrl, self, bReEnter)
    self.m_oWHCtrl:OnLogin(self,bReEnter)
    self.m_oBaseCtrl:OnLogin(self,bReEnter)
    self.m_oActiveCtrl:OnLogin(self,bReEnter)
    self.m_oSummonCtrl:OnLogin(self,bReEnter)
    self.m_oScheduleCtrl:OnLogin(self, bReEnter)
    self.m_oStateCtrl:OnLogin(self,bReEnter)
    self.m_oPartnerCtrl:OnLogin(self, bReEnter)
    self.m_oTitleCtrl:OnLogin(self, bReEnter)
    self.m_oFaBaoCtrl:OnLogin(self, bReEnter)
    self.m_oTouxianCtrl:OnLogin(self, bReEnter)
    self.m_mPromoteCtrl:OnLogin(self,bReEnter)
    self.m_mTempItemCtrl:OnLogin(self,bReEnter)
    self.m_mRecoveryCtrl:OnLogin(self,bReEnter)
    self.m_oRideCtrl:OnLogin(self, bReEnter)
    self.m_oStoreCtrl:OnLogin(self, bReEnter)
    self.m_oEquipCtrl:OnLogin(self, bReEnter)
    self.m_oSummCkCtrl:OnLogin(self, bReEnter)
    self.m_oMarryCtrl:OnLogin(self, bReEnter)
    self:SyncStrengthenInfo(-1, true)

    local oTeamMgr = global.oTeamMgr
    oTeamMgr:OnLogin(self,bReEnter)

    local oMailMgr = global.oMailMgr
    oMailMgr:OnLogin(self,bReEnter)

    local oFriendMgr = global.oFriendMgr
    oFriendMgr:OnLogin(self,bReEnter)

    global.oSysOpenMgr:OnLogin(self, bReEnter)

    local oNewbieGuideMgr = global.oNewbieGuideMgr
    oNewbieGuideMgr:OnLogin(self, bReEnter)

    local oOrgMgr = global.oOrgMgr
    oOrgMgr:OnLogin(self, bReEnter)

    local oInterfaceMgr = global.oInterfaceMgr
    oInterfaceMgr:OnLogin(self, bReEnter)

    local oRankMgr = global.oRankMgr
    oRankMgr:OnLogin(self, bReEnter)

    local oCatalogMgr = global.oCatalogMgr
    oCatalogMgr:OnLogin(self, bReEnter)

    local oStallMgr = global.oStallMgr
    oStallMgr:OnLogin(self, bReEnter)

    local oHuodongMgr = global.oHuodongMgr
    oHuodongMgr:OnLogin(self,bReEnter)

    local oHotTopicMgr = global.oHotTopicMgr
    oHotTopicMgr:OnLogin(self, bReEnter)

    local oAuction = global.oAuction
    oAuction:OnLogin(self, bReEnter)

    global.oEngageMgr:OnLogin(self, bReEnter)
    global.oMentoring:OnLogin(self, bReEnter)
    global.oMarryMgr:OnLogin(self, bReEnter)
    global.oChatMgr:OnLogin(self, bReEnter)
    global.oYunYingInfoMgr:OnLogin(self, bReEnter)

    self:RegisterClientUpdate()
    self:SyncRoleData2DataCenter()

    if not bReEnter then
        global.oPayMgr:DealUntreatedOrder(self)
        global.oMergerMgr:OnLogin(self)
        local iDiffDisconnect = iNowTime - self.m_oActiveCtrl:GetDisconnectTime()
        if self:GetGrade() >= 20 and iDiffDisconnect >= 30*60 then
            local sFormula = res["daobiao"].chubeiexplimit.formula.value
            local iLimitTime = tonumber(res["daobiao"].chubeiexplimit.timelimit.value)
            local mEnv = {
                lv = self:GetGrade(),
                disconnect = iDiffDisconnect,
            }
            local iAdd = formula_string(sFormula, mEnv)

            local mLimitEnv = {
                    lv = self:GetGrade(),
                    disconnect = iLimitTime * 3600,
             }
            local iMaxLimit = formula_string(sFormula,mLimitEnv)
            local iCurChubei = self.m_oActiveCtrl:GetData("chubeiexp")
            if iCurChubei < iMaxLimit  then
                if iCurChubei + iAdd >= iMaxLimit then
                    iAdd = iMaxLimit - iCurChubei
                end
                self:AddChubeiExp(iAdd, "OnLogin")
                self:PropChange("chubeiexp")
            else
                iAdd = 0
            end

            local iChat = iDiffDisconnect > 72*3600 and 2013 or 2012
            if iAdd == 0 then
                iChat = iDiffDisconnect > iLimitTime* 3600 and 2015 or 2014
            end
            local sMsg = global.oToolMgr:GetTextData(iChat)
            local mReplace = {hour= iLimitTime,min=math.floor(iDiffDisconnect/60), chubei=iAdd}
            sMsg = global.oToolMgr:FormatColorString(sMsg, mReplace)
            global.oChatMgr:SendNotifyAndMessage(self, sMsg)
        end
        -- if iDiffDisconnect > 30 * 60 then
        if iDiffDisconnect > 10 then
            if self.m_oActiveCtrl:GetData("gold_over",0) >= 0 then
                self.m_oActiveCtrl:SetData("gold_over",0)
                self:PropChange("gold_over")
            end
            if self.m_oActiveCtrl:GetData("silver_over",0) >= 0 then
                self.m_oActiveCtrl:SetData("silver_over", 0)
                self:PropChange("silver_over")
            end
        end

        self:Schedule()
    end

    if global.oOffsetMgr then
        global.oOffsetMgr:OnLogin(self)
    end

    self:LoginEnd(bReEnter)
end

function CPlayer:ConfigSaveFunc()
    local iPid = self:GetPid()
    self:ApplySave(function ()
        local oWorldMgr = global.oWorldMgr
        local obj = oWorldMgr:GetOnlinePlayerByPid(iPid)
        if obj then
            obj:SaveDb()
        else
            record.warning("playerobj save fail: %d", iPid)
        end
    end)
end

function CPlayer:OnDisconnected()
    -- 数据中心log
    safe_call(self.LoginOrOutAnalyInfo, self, 3)

    local oWarMgr = global.oWarMgr
    oWarMgr:OnDisconnected(self)
    local oSceneMgr = global.oSceneMgr
    oSceneMgr:OnDisconnected(self)
    local oNotifyMgr = global.oNotifyMgr
    oNotifyMgr:OnDisconnected(self)
    local oFriendMgr = global.oFriendMgr
    oFriendMgr:OnDisconnected(self)
    local oInterfaceMgr = global.oInterfaceMgr
    oInterfaceMgr:OnDisconnected(self)
    if global.oOrgMgr then
        global.oOrgMgr:OnDisconnected(self)
    end
end

function CPlayer:SaveDb(bForce)
    local iPid = self:GetPid()
    if self:IsDirty() or bForce then
        local mInfo = {
            module = "playerdb",
            cmd = "SavePlayerMain",
            cond = {pid = self:GetPid()},
            data = {data = self:Save()},
        }
        self:SaveModuleDb(mInfo)
    end
    if self.m_oBaseCtrl:IsDirty() or bForce then
        local mInfo = {
            module = "playerdb",
            cmd = "SavePlayerBase",
            cond = {pid = self:GetPid()},
            data = {data = self.m_oBaseCtrl:Save()},
        }
        self:SaveModuleDb(mInfo, "m_oBaseCtrl")
    end
    if self.m_oActiveCtrl:IsDirty() or bForce then
        local mInfo = {
            module = "playerdb",
            cmd = "SavePlayerActive",
            cond = {pid = self:GetPid()},
            data = {data = self.m_oActiveCtrl:Save()},
        }
        self:SaveModuleDb(mInfo, "m_oActiveCtrl")
    end
    if self.m_oItemCtrl:IsDirty() or bForce then
        local mInfo = {
            module = "playerdb",
            cmd = "SavePlayerItem",
            cond = {pid = self:GetPid()},
            data = {data = self.m_oItemCtrl:Save()},
        }
        self:SaveModuleDb(mInfo, "m_oItemCtrl")
    end

    if self.m_oTimeCtrl:IsDirty() or bForce then
        local mInfo = {
            module = "playerdb",
            cmd = "SavePlayerTimeInfo",
            cond = {pid = self:GetPid()},
            data = {data = self.m_oTimeCtrl:Save()},
        }
        self:SaveModuleDb(mInfo, "m_oTimeCtrl")
    end
    if self.m_oTaskCtrl:IsDirty() or bForce then
        local mInfo = {
            module = "playerdb",
            cmd = "SavePlayerTaskInfo",
            cond = {pid = self:GetPid()},
            data = {data = self.m_oTaskCtrl:Save()},
        }
        self:SaveModuleDb(mInfo, "m_oTaskCtrl")
    end
    if self.m_oWHCtrl:IsDirty() or bForce then
        local mInfo = {
            module = "playerdb",
            cmd = "SavePlayerWareHouse",
            cond = {pid = self:GetPid()},
            data = {data = self.m_oWHCtrl:Save()},
        }
        self:SaveModuleDb(mInfo, "m_oWHCtrl")
    end
    if self.m_oSkillCtrl:IsDirty() or bForce then
        local mInfo = {
            module = "playerdb",
            cmd = "SaveSkillInfo",
            cond = {pid = self:GetPid()},
            data = {data = self.m_oSkillCtrl:Save()},
        }
        self:SaveModuleDb(mInfo, "m_oSkillCtrl")
    end
    if self.m_oSummonCtrl:IsDirty() or bForce then
        local mInfo = {
            module = "playerdb",
            cmd = "SavePlayerSummon",
            cond = {pid = self:GetPid()},
            data = {data = self.m_oSummonCtrl:Save()},
        }
        self:SaveModuleDb(mInfo, "m_oSummonCtrl")
    end
    if self.m_oScheduleCtrl:IsDirty() or bForce then
        local mInfo = {
            module = "playerdb",
            cmd = "SavePlayerSchedule",
            cond = {pid = self:GetPid()},
            data = {data = self.m_oScheduleCtrl:Save()},
        }
        self:SaveModuleDb(mInfo, "m_oScheduleCtrl")
    end
    if self.m_oPartnerCtrl:IsDirty() or bForce then
        local mInfo = {
            module = "playerdb",
            cmd = "SavePlayerPartner",
            cond = {pid = self:GetPid()},
            data = {data = self.m_oPartnerCtrl:Save()},
        }
        self:SaveModuleDb(mInfo, "m_oPartnerCtrl")
    end
    if self.m_oTitleCtrl:IsDirty() or bForce then
        local mInfo = {
            module = "playerdb",
            cmd = "SavePlayerTitle",
            cond = {pid = self:GetPid()},
            data = {data = self.m_oTitleCtrl:Save()},
        }
        self:SaveModuleDb(mInfo, "m_oTitleCtrl")
    end
    if self.m_oTouxianCtrl:IsDirty() or bForce then
        local mInfo = {
            module = "playerdb",
            cmd = "SavePlayerTouxian",
            cond = {pid = self:GetPid()},
            data = {data = self.m_oTouxianCtrl:Save()},
        }
        self:SaveModuleDb(mInfo, "m_oTouxianCtrl")
    end
    if self.m_oAchieveCtrl:IsDirty() or bForce then
        local mInfo = {
            module = "playerdb",
            cmd = "SavePlayerAchieve",
            cond = {pid = self:GetPid()},
            data = {data = self.m_oAchieveCtrl:Save()},
        }
        self:SaveModuleDb(mInfo, "m_oAchieveCtrl")
    end
    if self.m_oStateCtrl:IsDirty() or bForce then
        local mInfo = {
            module = "playerdb",
            cmd = "SavePlayerState",
            cond = {pid = self:GetPid()},
            data = {data = self.m_oStateCtrl:Save()},
        }
        self:SaveModuleDb(mInfo, "m_oStateCtrl")
    end
    if self.m_oRideCtrl:IsDirty() or bForce then
        local mInfo = {
            module = "playerdb",
            cmd = "SavePlayerRide",
            cond = {pid = self:GetPid()},
            data = {data = self.m_oRideCtrl:Save()},
        }
        self:SaveModuleDb(mInfo, "m_oRideCtrl")
    end

    if self.m_mTempItemCtrl:IsDirty() or bForce then
        local mInfo = {
            module = "playerdb",
            cmd = "SavePlayerTempItem",
            cond = {pid = self:GetPid()},
            data = {data = self.m_mTempItemCtrl:Save()},
        }
        self:SaveModuleDb(mInfo, "m_mTempItemCtrl")
    end

    if self.m_mRecoveryCtrl:IsDirty() or bForce then
        local mInfo = {
            module = "playerdb",
            cmd = "SavePlayerRecovery",
            cond = {pid = self:GetPid()},
            data = {data = self.m_mRecoveryCtrl:Save()},
        }
        self:SaveModuleDb(mInfo, "m_mRecoveryCtrl")
    end

    if self.m_oEquipCtrl:IsDirty() or bForce then
        local mInfo = {
            module = "playerdb",
            cmd = "SavePlayerEquip",
            cond = {pid = self:GetPid()},
            data = {data = self.m_oEquipCtrl:Save()},
        }
        self:SaveModuleDb(mInfo, "m_oEquipCtrl")
    end

    if self.m_oStoreCtrl:IsDirty() or bForce then
        local mInfo = {
            module = "playerdb",
            cmd = "SavePlayerStore",
            cond = {pid = self:GetPid()},
            data = {data = self.m_oStoreCtrl:Save()},
        }
        self:SaveModuleDb(mInfo, "m_oStoreCtrl")
    end

    if self.m_oSummCkCtrl:IsDirty() or bForce then
        local mInfo = {
            module = "playerdb",
            cmd = "SavePlayerSummonCk",
            cond = {pid = self:GetPid()},
            data = {data = self.m_oSummCkCtrl:Save()},
        }
        self:SaveModuleDb(mInfo, "m_oSummCkCtrl")
    end
    if self.m_oFaBaoCtrl:IsDirty() or bForce then
        local mInfo = {
            module = "playerdb",
            cmd = "SavePlayerFaBao",
            cond = {pid = self:GetPid()},
            data = {data = self.m_oFaBaoCtrl:Save()},
        }
        self:SaveModuleDb(mInfo, "m_oFaBaoCtrl")
    end

    if self.m_oArtifactCtrl:IsDirty() or bForce then
        local mInfo = {
            module = "playerdb",
            cmd = "SavePlayerArtifact",
            cond = {pid = self:GetPid()},
            data = {data = self.m_oArtifactCtrl:Save()},
        }
        self:SaveModuleDb(mInfo, "m_oArtifactCtrl")
    end

    if self.m_oWingCtrl:IsDirty() or bForce then
        local mInfo = {
            module = "playerdb",
            cmd = "SavePlayerWing",
            cond = {pid = self:GetPid()},
            data = {data = self.m_oWingCtrl:Save()},
        }
        self:SaveModuleDb(mInfo, "m_oWingCtrl")
    end

    if self.m_oMarryCtrl:IsDirty() or bForce then
        local mInfo = {
            module = "playerdb",
            cmd = "SavePlayerMarryInfo",
            cond = {pid = self:GetPid()},
            data = {data = self.m_oMarryCtrl:Save()},
        }
        self:SaveModuleDb(mInfo, "m_oMarryCtrl")
    end
    self:SaveOfflineDb()
end

function CPlayer:SaveModuleDb(mSave, sModule)
    local iPid = self:GetPid()
    gamedb.SaveDb(iPid, "common", "DbOperate", mSave)
    if sModule then
        self[sModule]:UnDirty()
    else
        self:UnDirty()
    end
end

function CPlayer:SaveOfflineDb()
    local oProfile = self:GetProfile()
    local oFriend = self:GetFriend()
    local oMailBox = self:GetMailBox()
    oProfile:SaveDb()
    oFriend:SaveDb()
    oMailBox:SaveDb()
end

-- @param iSec: <nil/int>超时时间
-- @param iPrio: <nil/int>优先级
-- @param mSource: <mapping>设置来源
function CPlayer:BianShen(iBianshenId, iSec, iPrio, sGroup, mSource)
    return self.m_oBaseCtrl.m_oBianShenMgr:BianShen(iBianshenId, iSec, iPrio, sGroup, mSource)
end

function CPlayer:DelBianShen(mBianshenArgs)
    self.m_oBaseCtrl.m_oBianShenMgr:DelBianShenByKey(mBianshenArgs)
end

-- TODO 如果不同的任务发的变身都有带战斗变身效果，那么进战斗要判断变身所属战斗目标
function CPlayer:DelBianShenGroup(sGroup)
    self.m_oBaseCtrl.m_oBianShenMgr:DelBianShenGroup(sGroup)
end

function CPlayer:GetSchoolTeacher()
    return global.oToolMgr:GetSchoolTeacher(self:GetSchool())
end

function CPlayer:PreCheck()
    if not self.m_oBaseCtrl:GetData("model_info") then
        local mModelInfo = {
            shape = 0,
            scale = 0,
            color = {0,},
            mutate_texture = 0,
            weapon = 0,
            adorn = 0,
        }
        self.m_oBaseCtrl:SetData("model_info", mModelInfo)
    end
    if not self.m_oBaseCtrl:GetData("school") then
        local mSchool = res["daobiao"]["school"]
        --local lSchool = table_value_list(mSchool)
         --local o = lSchool[math.random(#lSchool)]
         --暂时开放两个门派
        local lSchool = {1,3}
        local iSchool = lSchool[math.random(#lSchool)]
        local o = mSchool[iSchool]
        self.m_oBaseCtrl:SetData("school", o.id)
    end

    if not self.m_oActiveCtrl:GetData("scene_info") then
        self:SetBornPos()
    end
end

function CPlayer:SetBornPos()
    local iSchool = self:GetSchool()
    local mPosInfo = table_get_depth(res, {"daobiao", "school", iSchool, "born_pos"})
    local mSceneInfo = {
        map_id = 103000,
        pos = {
            x = 28.0,
            y = 21.0,
            z = 0,
            face_x = 0,
            face_y = 0,
            face_z = 0,
        },
    }
    if mPosInfo then
        local iMapId = mPosInfo.scene
        local iX = mPosInfo.x
        local iY = mPosInfo.y
        if iMapId and iX and iY then
            mSceneInfo.map_id = iMapId
            mSceneInfo.pos.x = iX
            mSceneInfo.pos.y = iY
        end
    end
    self.m_oActiveCtrl:SetData("scene_info", mSceneInfo)
end

function CPlayer:AfterSendLogin()
    if not self.m_oBaseCtrl:GetData("init_newrole") then
        local mLogData = {}
        mLogData.pid = self:GetPid()
        mLogData.account = self:GetAccount()
        mLogData.channel = self:GetChannel()
        mLogData.name = self:GetName()
        mLogData.create_time = get_time()
        mLogData.shape = self:GetOriginShape()
        mLogData.school = self:GetSchool()
        record.user("player", "newrole", mLogData)
        self.m_oBaseCtrl:SetData("init_newrole",1)
        self:Born()
    end
end

function CPlayer:Born()
    -- 发出生任务
    -- if not is_production_env() and not global.oToolMgr:IsSysOpen("BORN_STORY_TASK", oPlayer, true) then
    --     -- 测试环境，先不发任务
    --     local sMsg = "测试关闭出生主线任务，需要领取请使用borntask指令"
    --     global.oChatMgr:HandleMsgChat(self, sMsg, true)
    --     self:NotifyMessage(sMsg)
    -- else
    --     self:InitNewRoleTask()
    -- end
    self:InitNewRoleTask()
    -- 发出生装备并着装 （策划要求屏蔽）
    -- global.oNewbieGuideMgr:GiveNewbieEquip(self)
end

function CPlayer:InitNewRoleTask()
    local iSchool = self:GetSchool()
    local taskid = table_get_depth(res, {"daobiao", "school", iSchool, "born_task"})
    if not taskid then
        taskid = 10001
    end
    local taskobj = global.oTaskLoader:CreateTask(taskid)
    if taskobj then
        self.m_oTaskCtrl:AddTask(taskobj)
    end
end

function CPlayer:Save()
    local mData = {}
    mData.name = self:GetData("name")
    mData.now_server = self:GetData("now_server")
    return mData
end

function CPlayer:Load(mData)
    self:SetData("name", mData.name or string.format("DEBUG%d", self:GetPid()))
    self:SetData("now_server", mData.now_server or get_server_tag())
end

function CPlayer:RegisterClientUpdate()
    interactive.Send(".clientupdate", "common", "Register", {
        pid = self:GetPid(),
        info = {
            pid = self:GetPid(),
        },
    })
end

function CPlayer:UnRegisterClientUpdate()
    interactive.Send(".clientupdate", "common", "UnRegister", {
        pid = self:GetPid(),
    })
end

function CPlayer:Schedule()
    local iPid = self:GetPid()
    local f1
    f1 = function ()
        local oPlayer = global.oWorldMgr:GetOnlinePlayerByPid(iPid)
        if oPlayer then
            oPlayer:DelTimeCb("_CheckHeartBeat")
            oPlayer:AddTimeCb("_CheckHeartBeat", 10*1000, f1)
            oPlayer:_CheckHeartBeat()
        end
    end
    f1()

    local f4
    f4 = function ()
        local oPlayer = global.oWorldMgr:GetOnlinePlayerByPid(iPid)
        if oPlayer then
            oPlayer:DelTimeCb("_KeepAccountToken")
            oPlayer:AddTimeCb("_KeepAccountToken",10*60*1000,f4)
            oPlayer:KeepAccountTokenAlive()
        end
    end
    f4()

    local f5
    f5 = function()
        local oPlayer = global.oWorldMgr:GetOnlinePlayerByPid(iPid)
        if oPlayer then
            oPlayer:DelTimeCb("_CheckSelf")
            oPlayer:AddTimeCb("_CheckSelf", 5*60*1000, f5)
            oPlayer:CheckSelf()
        end
    end
    f5()
end

function CPlayer:KeepAccountTokenAlive()
    local sToken = self:GetAccountToken()
    if not sToken or sToken == "" then
        return
    end
    local iNo = string.match(sToken, "%w+_(%d+)")
    local sServiceName = string.format(".loginverify%s",iNo)
    local mArgs = {token = sToken}
    router.Send("cs", sServiceName, "common", "GSKeepTokenAlive", mArgs)
end

function CPlayer:CheckSelf()
    self.m_oActiveCtrl.m_oVigorCtrl:CheckSelf(self)
    self.m_oWingCtrl:CheckSelf(self)
end

function CPlayer:ClientHeartBeat()
    self.m_fHeartBeatTime = get_time()
    self:Send("GS2CHeartBeat", {time = math.floor(self.m_fHeartBeatTime)})
end

function CPlayer:_CheckHeartBeat()
    assert(not is_release(self), "_CheckHeartBeat fail")

    local iTestMode = self:GetTestLogoutJudgeTimeMode()
    local iJudgeTime = self:GetLogoutJudgeTime()
    local fTime = get_time()

    if iJudgeTime < 0 then
        return
    end
    local iTime = iJudgeTime
    if iTestMode then
        if iTestMode == 1 then
            iTime = -1
        elseif iTestMode == 2 then
            iTime = 2 * 60
        elseif iTestMode == 3 then
            iTime = 1 * 60
        elseif iTestMode == 4 then
            iTime = 0
        end
    end
    if iTime < 0 then
        return
    end

    if fTime - self.m_fHeartBeatTime >= iTime then
        local oWorldMgr = global.oWorldMgr
        oWorldMgr:Logout(self:GetPid())
    end
end

--道具相关
function CPlayer:RewardItem(itemobj,sReason,mArgs)
    mArgs = mArgs or {}
    self:LogItemOnChange("add_item", itemobj:SID(), itemobj:GetAmount(), sReason, itemobj:PackLogInfo())

    local oNotifyMgr = global.oNotifyMgr
    local oChatMgr = global.oChatMgr
    local oWorldMgr = global.oWorldMgr
    local oToolMgr = global.oToolMgr
    local oMailMgr = global.oMailMgr
    local retobj
    local oTargetItem = itemobj
    local iAmount = oTargetItem:GetAmount()
    if itemobj:SID() < 10000 then
        local oRealObj = itemobj:RealObj()
        if oRealObj then
            -- 真实物品用来取代原先想执行的虚拟物品下行逻辑(真实物品可能是random出来的)
            oTargetItem = oRealObj
        else
            itemobj:Reward(self, sReason, mArgs)
            baseobj_delay_release(itemobj) -- 虚拟物品发奖后不存身上，销毁
            return
        end
    end
    retobj = self.m_oItemCtrl:AddItem(oTargetItem, mArgs)
    if retobj then
        if not oToolMgr:IsSysOpen("TEMPBAG",self,true) or mArgs.send_mail == true then
            local mData, name = oMailMgr:GetMailInfo(1001)
            oMailMgr:SendMail(0, name, self:GetPid(), mData, 0, {retobj})
            self:SendNotification(2009)
            return
        else
            local oTempItemObj = self.m_mTempItemCtrl:AddItem(retobj)
            if oTempItemObj then
                local mData, name = oMailMgr:GetMailInfo(1008)
                oMailMgr:SendMail(0, name, self:GetPid(), mData, 0, {oTempItemObj})
                local sText = res["daobiao"]["tempitem"]["text"][1009]["text"]
                sText = global.oToolMgr:FormatColorString(sText, {item = oTempItemObj:TipsName()})
                oNotifyMgr:Notify(self:GetPid(), sText)
            end
            return
        end
    end

    local sName = oTargetItem:TipsName()
    if not mArgs.cancel_tip then
        oNotifyMgr:ItemNotify(self.m_iPid, {sid=oTargetItem:SID(), amount=iAmount})
    end
    if not mArgs.cancel_chat then
        local sMsg = global.oToolMgr:FormatString("获得#item×#G#amount#n", {amount = iAmount, item = sName})
        oChatMgr:HandleMsgChat(self, sMsg)
    end

    -- 数据中心log
    analylog.LogBackpackChange(self, 1, oTargetItem:SID(), iAmount, sReason)
end

function CPlayer:RewardItems(itemsid, iAmount, sReason, mArgs)
    local lItems = {}
    if itemsid < 10000 then
        local oItem = global.oItemLoader:Create(itemsid)
        oItem:SetData("Value", iAmount)
        self:RewardItem(oItem, sReason, mArgs)
    else
        local iPid = self:GetPid()
        while (iAmount > 0) do
            local oItem = global.oItemLoader:Create(itemsid)
            if mArgs and mArgs.bind then
                oItem:Bind(iPid)
            end
            local iAddAmount = math.min(oItem:GetMaxAmount(), iAmount)
            oItem:SetAmount(iAddAmount)
            iAmount = iAmount - iAddAmount
            table.insert(lItems, oItem)
        end
        for _,oItem in ipairs(lItems) do
            self:RewardItem(oItem, sReason, mArgs)
        end
    end
end

function CPlayer:GiveItem(sidlist,sReason,mArgs)
    return self.m_oItemCtrl:GiveItem(sidlist,sReason,mArgs)
end

function CPlayer:GiveItemobj(itemlist,sReason,mArgs)
    mArgs = mArgs or {}
    self.m_oItemCtrl:GiveItemobj(self,itemlist,sReason,mArgs)
end

-- @return: 进入背包的物品对象（其他去向的不返回）
function CPlayer:GiveEquip(sid, iFix, sReason, mArgs)
    local sDir = global.oItemLoader:GetItemDir(sid)
    if sDir ~= "equip" then
        return
    end
    local oItem = global.oItemLoader:CreateFixedItem(sid, iFix)
    oItem:SetAmount(1)
    if not self:ValidGive({[sid] = 1}, mArgs) then
        self:RewardItem(oItem, sReason, mArgs)
        return
    end
    self:RewardItem(oItem, sReason, mArgs)
    return oItem
end

--ItemList:{sid:amount}
function CPlayer:ValidGive(sidlist, mArgs)
    local bSuc = self.m_oItemCtrl:ValidGive(sidlist, mArgs)
    return bSuc
end

--ItemList:{itemobj,...}
function CPlayer:ValidGiveitemlist(itemlist,mArgs)
    mArgs = mArgs or {}
    local bSuc = self.m_oItemCtrl:ValidGiveitemlist(itemlist, mArgs)
    if not bSuc and not mArgs.cancel_tip then
        local sMsg = "你的背包已满，请清理后再领取"
        if mArgs.tip then sMsg = mArgs.tip end
        global.oNotifyMgr:Notify(self:GetPid(),sMsg)
    end
    return bSuc
end

function CPlayer:RemoveOneItemAmount(itemobj, iAmount, sReason, mArgs)
    assert(iAmount > 0, "RemoveOneItemAmount amount err")
    local iCurAmount = itemobj:GetAmount()
    if iCurAmount < iAmount then
        record.error("remove item less pid:%s, item:%s, Amount:%s, CurAmount:%s, sReason:%s",
            self:GetPid(), itemobj:SID(), iAmount, iCurAmount, sReason or "")
        iAmount = iCurAmount
    end

    local iSid = itemobj:SID()
    self:LogItemOnChange("sub_item", iSid, iAmount, sReason)

    -- 不为空即需要记录
    local mConsume = self:GetTemp("consume_content")
    if mConsume then
        mConsume[iSid] = (mConsume[iSid] or 0) + iAmount
    end

    if not mArgs or not mArgs.cancel_chat then
        local sMsg = global.oToolMgr:FormatColorString("消耗#amount个#item", {amount = iAmount, item = itemobj:TipsName()})
        global.oChatMgr:HandleMsgChat(self, sMsg)
    end
    if not mArgs or not mArgs.cancel_tip then
        global.oNotifyMgr:ItemNotify(self:GetPid(), {sid=iSid, amount=-iAmount})
    end

    itemobj:AddAmount(-iAmount, sReason)

    -- 数据中心log
    analylog.LogBackpackChange(self, 2, iSid, iAmount, sReason)
end

function CPlayer:RemoveItemAmount(sid,iAmount,sReason, mArgs)
    self:LogItemOnChange("sub_item", sid, iAmount, sReason)

    local bSuc = self.m_oItemCtrl:RemoveItemAmount(sid,iAmount,sReason,mArgs)

    -- 数据中心log
    if bSuc then
        analylog.LogBackpackChange(self, 2, sid, iAmount, sReason)
    end

    -- 不为空即需要记录
    local mConsume = self:GetTemp("consume_content")
    if mConsume then
        mConsume[sid] = (mConsume[sid] or 0) + iAmount
    end
    return bSuc
end

function CPlayer:GetItemAmount(sid)
    local iAmount = self.m_oItemCtrl:GetItemAmount(sid)
    return iAmount
end

function CPlayer:HasItem(id)
    return self.m_oItemCtrl:HasItem(id)
end

function CPlayer:TriggerItemChange(itemobj,iAmount,sReason)
    if iAmount>=0 then return end
    if sReason then
        if sReason  == "gm" then return end
        if table_in_list({"装备分解", "分解","精气炼化"}, sReason) then
            if  not self.m_bIngoreRecovery then
                return
            end
        end
        if itemobj:Quality()<3 then return end
    end
    local mSaveData = itemobj:Save()
    mSaveData["amount"] = 1
    self.m_mRecoveryCtrl:AddItem(mSaveData,iAmount)
end

function CPlayer:CheckUpGrade()
    if is_ks_server() then return end

    local mUpGrade = res["daobiao"]["upgrade"]
    local iFromGrade = self:GetGrade()
    local i = iFromGrade + 1
    while true do
        local m = mUpGrade[i]
        if not m then
            break
        end
        if i > self:GetServerGradeLimit() then
            break
        end
        if self:GetExp() < m.player_exp then
            break
        end
        self:UpGrade()
        self.m_oActiveCtrl:UpgradeCoin()
        i = i + 1
    end
    local iCurGrade = self:GetGrade()
    if iCurGrade > iFromGrade then
        self:OnUpGradeEnd(iFromGrade)
    end
end

function CPlayer:MaxFutureExp()
    return res["daobiao"]["futureexplimit"]["maxlimit"]["value"]
end

function CPlayer:UpGrade()
    local iNextGrade = self:GetGrade() + 1
    self.m_oBaseCtrl:SetData("grade", iNextGrade)

    local mUpGrade = res["daobiao"]["upgrade"][iNextGrade]
    local iExp = math.max(0, self:GetExp() - mUpGrade.player_exp)
    self.m_oActiveCtrl:SetData("exp", iExp)

    local mSchool = res["daobiao"]["school"]
    local m = mSchool[self:GetSchool()]
    local mPoint = m.points
    local mWashPoint = m.washpoints
    self:AddPrimaryProp(mPoint)
    self:AddPrimaryProp(mWashPoint)

    self:PropChange("exp", "grade", "agility", "strength", "magic", "endurance", "physique")

    self.m_oActiveCtrl:SetData("hp",self:GetMaxHp())
    self.m_oActiveCtrl:SetData("mp",self:GetMaxMp())
    self:SecondLevelPropChange()
end

function CPlayer:OnUpGradeEnd(iFromGrade)
    global.oScoreCache:Dirty(self:GetPid(), "base")

    local iGrade = self:GetGrade()
    self.m_oTaskCtrl:OnUpGradeEnd(self, iFromGrade, iGrade)

    local oRankMgr = global.oRankMgr
    oRankMgr:PushDataToGradeRank(self)

    if iFromGrade < 20 and iGrade >= 20 then
        self:AddEnergy(200, "20级", {cancel_tip=true, cancel_chat=true})
    end

    self.m_oBaseCtrl:OnUpGrade(iFromGrade, iGrade)
    self.m_oSkillCtrl:OnUpGrade(self)
    self.m_oPartnerCtrl:OnUpGrade(self, iGrade)
    self.m_oTouxianCtrl:OnUpGrade(self)
    self.m_oSummonCtrl:OnUpGrade(self, iFromGrade)
    self.m_oRideCtrl:OnPlayerUpGrade(self)
    self.m_oStateCtrl:OnUpGrade(self)
    self.m_oFaBaoCtrl:OnUpGrade(self)
    self.m_oArtifactCtrl:OnUpGrade(self, iFromGrade)

    local oTeamMgr = global.oTeamMgr
    oTeamMgr:UpdatePlayer(self)

    local oMailMgr = global.oMailMgr
    oMailMgr:OnUpGrade(self, iFromGrade, iGrade)

    self:RefreshCulSkillUpperLevel()
    self:SyncUpGrade2Org()
    self:SyncRoleData2DataCenter()

    local mLogData = self:LogData()
    mLogData["grade_from"] = iFromGrade
    mLogData["school"] = self:GetSchool()
    record.log_db("player", "upgrade", mLogData)

    global.oSysOpenMgr:OnUpgradeEnd(self, iFromGrade, iGrade)
    global.oNewbieGuideMgr:OnUpGradeEnd(self, iFromGrade, iGrade)
    global.oMentoring:OnUpgrade(self, iFromGrade, iGrade)

    self:TriggerEvent(gamedefines.EVENT.ON_UPGRADE, {player = self, from = iFromGrade, player_grade = iGrade})
end

function CPlayer:RefreshPropAll()
    self:FirstLevelPropChange()
    self:SecondLevelPropChange()
    self:ThreeLevelPropChange()
end

function CPlayer:AddPrimaryProp(mPoint)
    local iAdd
    iAdd = mPoint["agility"]
    if iAdd > 0 then
        self.m_oBaseCtrl:SetData("agility", self.m_oBaseCtrl:GetData("agility") + iAdd)
    end
    iAdd = mPoint["strength"]
    if iAdd > 0 then
        self.m_oBaseCtrl:SetData("strength", self.m_oBaseCtrl:GetData("strength") + iAdd)
    end
    iAdd = mPoint["magic"]
    if iAdd > 0 then
        self.m_oBaseCtrl:SetData("magic", self.m_oBaseCtrl:GetData("magic") + iAdd)
    end
    iAdd = mPoint["endurance"]
    if iAdd > 0 then
        self.m_oBaseCtrl:SetData("endurance", self.m_oBaseCtrl:GetData("endurance") + iAdd)
    end
    iAdd = mPoint["physique"]
    if iAdd > 0 then
        self.m_oBaseCtrl:SetData("physique", self.m_oBaseCtrl:GetData("physique") + iAdd)
    end
end

function CPlayer:SubPrimaryProp(mPoint)
    local iSub
    iSub = mPoint["agility"] or 0
    if iSub > 0 then
        self.m_oBaseCtrl:SetData("agility", self.m_oBaseCtrl:GetData("agility") - iSub)
    end
    iSub = mPoint["strength"] or 0
    if iSub > 0 then
        self.m_oBaseCtrl:SetData("strength", self.m_oBaseCtrl:GetData("strength") - iSub)
    end
    iSub = mPoint["magic"] or 0
    if iSub > 0 then
        self.m_oBaseCtrl:SetData("magic", self.m_oBaseCtrl:GetData("magic") - iSub)
    end
    iSub = mPoint["endurance"] or 0
    if iSub > 0 then
        self.m_oBaseCtrl:SetData("endurance", self.m_oBaseCtrl:GetData("endurance") - iSub)
    end
    iSub = mPoint["physique"] or 0
    if iSub > 0 then
        self.m_oBaseCtrl:SetData("physique", self.m_oBaseCtrl:GetData("physique") - iSub)
    end
end

local function  ValidGold(oPlayer,iVal,mArgs)
    return oPlayer.m_oActiveCtrl:ValidGold(iVal, mArgs)
end

local function  ValidSilver(oPlayer,iVal,mArgs)
    return oPlayer.m_oActiveCtrl:ValidSilver(iVal, mArgs)
end

local function ValidGoldCoin(oPlayer,iVal,mArgs)
    local oProfile = oPlayer:GetProfile()
    return oProfile:ValidGoldCoin(iVal, mArgs)
end

local function ValidRplGoldCoin(oPlayer, iVal, mArgs)
    return oPlayer:ValidRplGoldCoin(iVal, mArgs)
end

local function ValidOrgOffer(oPlayer, iVal, mArgs)
    return oPlayer.m_oActiveCtrl:ValidOrgOffer(iVal, mArgs)
end

local function ValidWuXun(oPlayer, iVal, mArgs)
    return oPlayer:ValidWuXun(iVal, mArgs)
end

local function ValidJJCPoint(oPlayer, iVal, mArgs)
    return oPlayer:ValidJJCPoint(iVal, mArgs)
end

local function ValidLeaderPoint(oPlayer, iVal, mArgs)
    return oPlayer:ValidLeaderPoint(iVal, mArgs)
end

local function ValidXiayiPoint(oPlayer, iVal, mArgs)
    return oPlayer:ValidXiayiPoint(iVal, mArgs)
end

local function ValidSummonPoint(oPlayer, iVal, mArgs)
    return oPlayer:ValidSummonPoint(iVal, mArgs)
end

local function ValidStoryPoint(oPlayer, iVal, mArgs)
    return oPlayer:ValidStoryPoint(iVal, mArgs)
end

local function ValidTrueGoldCoin(oPlayer, iVal, mArgs)
    return oPlayer:ValidTrueGoldCoin(iVal, mArgs)
end

local function ValidChumoPoint(oPlayer, iVal, mArgs)
    return oPlayer:ValidChumoPoint(iVal, mArgs)
end

local ValidMoneyFunc = {
    [gamedefines.MONEY_TYPE.GOLD] = ValidGold,
    [gamedefines.MONEY_TYPE.SILVER] = ValidSilver,
    [gamedefines.MONEY_TYPE.GOLDCOIN] = ValidGoldCoin,
    [gamedefines.MONEY_TYPE.RPLGOLD] = ValidRplGoldCoin,
    [gamedefines.MONEY_TYPE.ORGOFFER] = ValidOrgOffer,
    [gamedefines.MONEY_TYPE.WUXUN] = ValidWuXun,
    [gamedefines.MONEY_TYPE.JJCPOINT] = ValidJJCPoint,
    [gamedefines.MONEY_TYPE.LEADERPOINT] = ValidLeaderPoint,
    [gamedefines.MONEY_TYPE.XIAYIPOINT] = ValidXiayiPoint,
    [gamedefines.MONEY_TYPE.SUMMONPOINT] = ValidSummonPoint,
    [gamedefines.MONEY_TYPE.STORYPOINT] = ValidStoryPoint,
    [gamedefines.MONEY_TYPE.TRUE_GOLDCOIN] = ValidTrueGoldCoin,
    [gamedefines.MONEY_TYPE.CHUMOPOINT] = ValidChumoPoint,
}

function CPlayer:ValidMoneyByType(iMoneyType,iVal,mArgs)
    return ValidMoneyFunc[iMoneyType](self,iVal,mArgs)
end

local function ResumeGold(oPlayer,iVal,sReason,mArgs)
    return oPlayer.m_oActiveCtrl:ResumeGold(iVal, sReason, mArgs)
end

local function ResumeSilver(oPlayer,iVal,sReason,mArgs)
    return oPlayer.m_oActiveCtrl:ResumeSilver(iVal, sReason, mArgs)
end

local function ResumeGoldCoin(oPlayer,iVal,sReason,mArgs)
    local oProfile = oPlayer:GetProfile()
    return oProfile:ResumeGoldCoin(iVal, sReason, mArgs)
end

local function ResumeOrgOffer(oPlayer,iVal,sReason,mArgs)
    oPlayer.m_oActiveCtrl:ResumeOrgOffer(iVal,sReason,mArgs)
end

local function ResumeWuXun(oPlayer,iVal,sReason,mArgs)
    oPlayer:ResumeWuXun(iVal,sReason,mArgs)
end

local function ResumeJJCPoint(oPlayer, iVal, sReason, mArgs)
    oPlayer:ResumeJJCPoint(iVal, sReason, mArgs)
end

local function ResumeLeaderPoint(oPlayer, iVal, sReason, mArgs)
    oPlayer:ResumeLeaderPoint(iVal, sReason, mArgs)
end

local function ResumeXiayiPoint(oPlayer, iVal, sReason, mArgs)
    oPlayer:ResumeXiayiPoint(iVal, sReason, mArgs)
end

local function ResumeSummonPoint(oPlayer, iVal, sReason, mArgs)
    oPlayer:ResumeSummonPoint(iVal, sReason, mArgs)
end

local function ResumeStoryPoint(oPlayer, iVal, sReason, mArgs)
    oPlayer:ResumeStoryPoint(iVal, sReason, mArgs)
end

local function ResumeTrueGoldCoin(oPlayer,iVal,sReason,mArgs)
    local oProfile = oPlayer:GetProfile()
    return oProfile:ResumeTrueGoldCoin(iVal, sReason, mArgs)
end

local function ResumeRplGoldCoin(oPlayer, iVal, sReason, mArgs)
    local oProfile = oPlayer:GetProfile()
    return oProfile:ResumeRplGoldCoin(iVal, sReason, mArgs)
end

local function ResumeChumoPoint(oPlayer, iVal, sReason, mArgs)
    oPlayer:ResumeChumoPoint(iVal, sReason, mArgs)
end

local ResumeMoneyFunc = {
    [gamedefines.MONEY_TYPE.GOLD] = ResumeGold,
    [gamedefines.MONEY_TYPE.SILVER] = ResumeSilver,
    [gamedefines.MONEY_TYPE.GOLDCOIN] = ResumeGoldCoin,
    [gamedefines.MONEY_TYPE.ORGOFFER] = ResumeOrgOffer,
    [gamedefines.MONEY_TYPE.WUXUN] = ResumeWuXun,
    [gamedefines.MONEY_TYPE.JJCPOINT] = ResumeJJCPoint,
    [gamedefines.MONEY_TYPE.LEADERPOINT] = ResumeLeaderPoint,
    [gamedefines.MONEY_TYPE.XIAYIPOINT] = ResumeXiayiPoint,
    [gamedefines.MONEY_TYPE.SUMMONPOINT] = ResumeSummonPoint,
    [gamedefines.MONEY_TYPE.STORYPOINT] = ResumeStoryPoint,
    [gamedefines.MONEY_TYPE.TRUE_GOLDCOIN] = ResumeTrueGoldCoin,
    [gamedefines.MONEY_TYPE.RPLGOLD] = ResumeRplGoldCoin,
    [gamedefines.MONEY_TYPE.CHUMOPOINT] = ResumeChumoPoint,
}

function CPlayer:ResumeMoneyByType(iMoneyType,iVal,sReason,mArgs)
    return ResumeMoneyFunc[iMoneyType](self,iVal,sReason,mArgs)
end

local function GetGold(oPlayer)
    return oPlayer.m_oActiveCtrl:GetData("gold")
end

local function GetSilver(oPlayer)
   return oPlayer.m_oActiveCtrl:GetData("silver")
end

local function GetGoldCoin(oPlayer)
   return oPlayer:GetProfile():GoldCoin()
end

local function GetOrgOffer(oPlayer)
    return oPlayer:GetOffer()
end

local function GetTrueGoldCoin(oPlayer)
    return oPlayer:GetProfile():TrueGoldCoin()
end

local function GetRplGoldCoin(oPlayer)
    return oPlayer:GetProfile():RplGoldCoin()
end

local GetMoneyCnt = {
    [gamedefines.MONEY_TYPE.GOLD] = GetGold,
    [gamedefines.MONEY_TYPE.SILVER] = GetSilver,
    [gamedefines.MONEY_TYPE.GOLDCOIN] = GetGoldCoin,
    [gamedefines.MONEY_TYPE.ORGOFFER] = GetOrgOffer,
    [gamedefines.MONEY_TYPE.TRUE_GOLDCOIN] = GetTrueGoldCoin,
    [gamedefines.MONEY_TYPE.RPLGOLD] = GetRplGoldCoin,
}

function CPlayer:GetMoney(iMoneyType)
    assert(GetMoneyCnt[iMoneyType],string.format("getmoney error %s %s",self:GetPid(),iMoneyType))
    return GetMoneyCnt[iMoneyType](self)
end

function CPlayer:AddPoint(iPoint)
    self.m_oBaseCtrl:AddPoint(iPoint)
end

local function RewardGold(oPlayer,iVal,sReason,mArgs)
    oPlayer.m_oActiveCtrl:RewardGold(iVal,sReason,mArgs)
end

local function RewardSilver(oPlayer,iVal,sReason,mArgs)
    oPlayer.m_oActiveCtrl:RewardSilver(iVal,sReason,mArgs)
end

local function RewardExp(oPlayer,iVal,sReason,mArgs)
    oPlayer.m_oActiveCtrl:RewardExp(iVal,sReason,mArgs)
end

local function RewardGoldCoin(oPlayer, iVal, sReason, mArgs)
    local oProfile = oPlayer:GetProfile()
    oProfile:AddRplGoldCoin(iVal, sReason, mArgs)
end

local function RewardOrgOffer(oPlayer, iVal, sReason, mArgs)
    oPlayer.m_oActiveCtrl:RewardOrgOffer(iVal, sReason, mArgs)
end

local function RewardWuXun(oPlayer, iVal, sReason, mArgs)
    oPlayer:RewardWuXun(iVal, sReason, mArgs)
end

local RewardFunc = {
    [gamedefines.MONEY_TYPE.GOLD] = RewardGold,
    [gamedefines.MONEY_TYPE.SILVER] = RewardSilver,
    [gamedefines.MONEY_TYPE.GOLDCOIN] = RewardGoldCoin,
    [gamedefines.MONEY_TYPE.ORGOFFER] = RewardOrgOffer,
    [gamedefines.MONEY_TYPE.WUXUN] = RewardWuXun,
}

function CPlayer:RewardByType(iType,iVal,sReason,mArgs)
    assert(RewardFunc[iType],string.format("没有配置奖励 %s 的方法",iType))
    RewardFunc[iType](self,iVal,sReason,mArgs)
end

function CPlayer:ChargeGold(iVal, sReason, mArgs)
    self:GetProfile():ChargeGold(iVal, sReason, mArgs)
end

function CPlayer:RewardGoldCoin(iVal, sReason, mArgs)
    self:GetProfile():AddRplGoldCoin(iVal, sReason, mArgs)
end

function CPlayer:RewardGold(iVal,sReason,mArgs)
    self.m_oActiveCtrl:RewardGold(iVal,sReason,mArgs)
end

function CPlayer:RewardCultivateExp(iVal, sReason, mArgs)
    -- 修炼经验
    self.m_oSkillCtrl:AddCurrCulSkillExp(iVal)
end

function CPlayer:ValidGold(iVal, mArgs)
    return self.m_oActiveCtrl:ValidGold(iVal, mArgs)
end

function CPlayer:ResumeGold(iVal, sReason, mArgs)
    return self.m_oActiveCtrl:ResumeGold(iVal, sReason, mArgs)
end

function CPlayer:RewardSilver(iVal,sReason,mArgs)
    self.m_oActiveCtrl:RewardSilver(iVal,sReason,mArgs)
end

function CPlayer:ValidSilver(iVal, mArgs)
    return self.m_oActiveCtrl:ValidSilver(iVal, mArgs)
end

function CPlayer:ResumeSilver(iVal, sReason, mArgs)
    return self.m_oActiveCtrl:ResumeSilver(iVal, sReason, mArgs)
end

function CPlayer:RewardExp(iVal,sReason,mArgs)
    return self.m_oActiveCtrl:RewardExp(iVal,sReason,mArgs)
end

function CPlayer:AddChubeiExp(iVal, sReason)
    sReason = sReason or ""
    self.m_oActiveCtrl:AddChubeiExp(iVal, sReason)
end

function CPlayer:ValidGoldCoin(iVal, mArgs)
    local oProfile = self:GetProfile()
    local bFlag = oProfile:ValidGoldCoin(iVal, mArgs)
    return bFlag
end

function CPlayer:ResumeGoldCoin(iVal,sReason,mArgs)
    local oProfile = self:GetProfile()
    return oProfile:ResumeGoldCoin(iVal,sReason,mArgs)
end

function CPlayer:ValidTrueGoldCoin(iVal, mArgs)
    local oProfile = self:GetProfile()
    return oProfile:ValidTrueGoldCoin(iVal, mArgs)
end

function CPlayer:ResumeTrueGoldCoin(iVal, sReason, mArgs)
    local oProfile = self:GetProfile()
    return oProfile:ResumeTrueGoldCoin(iVal, sReason, mArgs)
end

function CPlayer:ValidRplGoldCoin(iVal, mArgs)
    local oProfile = self:GetProfile()
    return oProfile:ValidRplGoldCoin(iVal, mArgs)
end

function CPlayer:ResumeRplGoldCoin(iVal, sReason, mArgs)
    local oProfile = self:GetProfile()
    return oProfile:ResumeRplGoldCoin(iVal, sReason, mArgs)
end

function CPlayer:FrozenGoldCoin(iVal, sReason, iTime)
    local oProfile = self:GetProfile()
    return oProfile:FrozenGoldCoin(iVal, sReason, iTime)
end

function CPlayer:RewardWuXun(iVal,sReason,mArgs)
    self.m_oActiveCtrl:RewardWuXun(iVal,sReason,mArgs)
end

function CPlayer:ValidWuXun(iVal, mArgs)
    return self.m_oActiveCtrl:ValidWuXun(iVal, mArgs)
end

function CPlayer:ResumeWuXun(iVal, sReason, mArgs)
    return self.m_oActiveCtrl:ResumeWuXun(iVal, sReason, mArgs)
end

function CPlayer:RewardJJCPoint(iVal,sReason,mArgs)
    self.m_oActiveCtrl:RewardJJCPoint(iVal,sReason,mArgs)
end

function CPlayer:ValidJJCPoint(iVal, mArgs)
    return self.m_oActiveCtrl:ValidJJCPoint(iVal, mArgs)
end

function CPlayer:ResumeJJCPoint(iVal, sReason, mArgs)
    return self.m_oActiveCtrl:ResumeJJCPoint(iVal, sReason, mArgs)
end

function CPlayer:RawRewardLeaderPoint(sSource, iTeamSize, sReason)
    self.m_oActiveCtrl:RawAddLeaderPoint(sSource, iTeamSize, sReason)
end

function CPlayer:RewardLeaderPoint(iVal, sReason, mArgs)
    self.m_oActiveCtrl:AddLeaderPoint(iVal, sReason, mArgs)
end

function CPlayer:ValidLeaderPoint(iVal, mArgs)
    return self.m_oActiveCtrl:ValidLeaderPoint(iVal, mArgs)
end

function CPlayer:ResumeLeaderPoint(iVal, sReason, mArgs)
    self.m_oActiveCtrl:ResumeLeaderPoint(iVal, sReason, mArgs)
end

function CPlayer:RawRewardXiayiPoint(sSource, sReason)
    self.m_oActiveCtrl:RawAddXiayiPoint(sSource, sReason)
end

function CPlayer:RewardXiayiPoint(iVal, sReason, mArgs)
    self.m_oActiveCtrl:AddXiayiPoint(iVal, sReason, mArgs)
end

function CPlayer:ValidXiayiPoint(iVal, mArgs)
    return self.m_oActiveCtrl:ValidXiayiPoint(iVal, mArgs)
end

function CPlayer:ResumeXiayiPoint(iVal, sReason, mArgs)
    self.m_oActiveCtrl:ResumeXiayiPoint(iVal, sReason, mArgs)
end

function CPlayer:RewardSummonPoint(iVal, sReason, mArgs)
    self.m_oActiveCtrl:RewardSummonPoint(iVal, sReason, mArgs)
end

function CPlayer:ValidSummonPoint(iVal, mArgs)
    return self.m_oActiveCtrl:ValidSummonPoint(iVal, mArgs)
end

function CPlayer:ResumeSummonPoint(iVal, sReason, mArgs)
    self.m_oActiveCtrl:ResumeSummonPoint(iVal, sReason, mArgs)
end

function CPlayer:RewardStoryPoint(iVal, sReason, mArgs)
    self.m_oActiveCtrl:RewardStoryPoint(iVal, sReason, mArgs)
end

function CPlayer:ValidStoryPoint(iVal, mArgs)
    self.m_oActiveCtrl:ValidStoryPoint(iVal, mArgs)
end

function CPlayer:ResumeStoryPoint(iVal, sReason, mArgs)
    self.m_oActiveCtrl:ResumeStoryPoint(iVal, sReason, mArgs)
end

function CPlayer:RawRewardChumoPoint(sSource, sReason)
    self.m_oActiveCtrl:RawAddChumoPoint(sSource, sReason)
end

function CPlayer:RewardChumoPoint(iVal, sReason, mArgs)
    self.m_oActiveCtrl:AddChumoPoint(iVal, sReason, mArgs)
end

function CPlayer:ValidChumoPoint(iVal, mArgs)
    return self.m_oActiveCtrl:ValidChumoPoint(iVal, mArgs)
end

function CPlayer:ResumeChumoPoint(iVal, sReason, mArgs)
    self.m_oActiveCtrl:ResumeChumoPoint(iVal, sReason, mArgs)
end

function CPlayer:GetGrade()
    return self.m_oBaseCtrl:GetData("grade")
end

function CPlayer:GetPoint()
    return self.m_oBaseCtrl:GetData("point")
end

function CPlayer:GetExp()
    return self.m_oActiveCtrl:GetData("exp")
end

function CPlayer:GetName()
    return self:GetData("name")
end

function CPlayer:GetIcon()
    return self.m_oBaseCtrl:GetData("icon")
end

function CPlayer:GetSex()
    return self.m_oBaseCtrl:GetData("sex")
end

function CPlayer:GetSchool()
    return self.m_oBaseCtrl:GetData("school")
end

function CPlayer:GetSilver()
    return self.m_oActiveCtrl:GetData("silver")
end

function CPlayer:GetGold()
    return self.m_oActiveCtrl:GetData("gold")
end

function CPlayer:GetGoldCoin()
    return self:GetProfile():GoldCoin()
end

function CPlayer:GetTrueGoldCoin()
    return self:GetProfile():TrueGoldCoin()
end

function CPlayer:GetRplGoldCoin()
    return self:GetProfile():RplGoldCoin()
end

function CPlayer:GetRoleType()
    return self.m_oBaseCtrl:GetData("role_type")
end

function CPlayer:GetRace()
    return playerop.ParseOutRace(self:GetRoleType())
end

function CPlayer:GetOrg()
    local oProfile = self:GetProfile()
    if oProfile then
        return oProfile:GetOrg()
    end
end

function CPlayer:GetOrgID()
    return self:GetProfile():GetOrgID()
end

function CPlayer:GetOrgStatus()
    local iOrg = self:GetOrgID()
    if  iOrg and iOrg ~= 0 then
        return 2
    end
    local oOrgMgr = global.oOrgMgr
    if oOrgMgr:GetReadyOrgByPid(self:GetPid()) then
        return 1
    end
    return 0
end

function CPlayer:GetOrgName()
    return self:GetProfile():GetOrgName()
end

function CPlayer:GetOrgPos()
    return self:GetProfile():GetOrgPos()
end

function CPlayer:SyncName2Org()
    local mData = {}
    mData["name"] = self:GetName()
    self:SyncTosOrg(mData)
end

function CPlayer:SyncUpGrade2Org()
    local mData = {}
    mData["grade"] = self:GetGrade()
    self:SyncTosOrg(mData)
end

function CPlayer:SyncLogoutTime2Org()
    local mData = {}
    mData["logout_time"] = get_time()
    self:SyncTosOrg(mData)
end

function CPlayer:SyncTosOrg(mData)
    if not global.oToolMgr:IsSysOpen("ORG_SYS", self, true) then
        return
    end
    local oOrg = self:GetOrg()
    if oOrg then
        oOrg:SyncMemberData(self:GetPid(), mData)
    else
        local oOrgMgr = global.oOrgMgr
        oOrgMgr:SyncPlayerData(self:GetPid(), mData)
    end
end

function CPlayer:GetEnergy()
    return self.m_oActiveCtrl:GetData("energy")
end

function CPlayer:GetVigor()
    return self.m_oActiveCtrl:GetData("vigor", 0)
end

function CPlayer:GetUpvote()
    return self:GetProfile():GetUpvote()
end

function CPlayer:GetUpvoteAmount()
    return self:GetProfile():GetUpvoteAmount()
end

function CPlayer:GetAchieve()
    return 0
end

function CPlayer:GetPosition()
    return self.m_oBaseCtrl:GetData("position")
end

function CPlayer:GetPositionHide()
    return self.m_oBaseCtrl:GetData("position_hide")
end

function CPlayer:GetRename()
    return self.m_oBaseCtrl:GetData("rename")
end

function CPlayer:GetOffer()
    return self.m_oActiveCtrl:GetOffer()
end

function CPlayer:HasBianShen()
    if  self.m_oBaseCtrl.m_oBianShenMgr:GetCurBianShen() then
        return true
    end
    return false
end

function CPlayer:PackBianShenModelInfo(oBianshen)
    local mMode = oBianshen:GetModelInfo()
    mMode["isbianshen"] = 1
    mMode["horse"] = self.m_oRideCtrl:GetUseRideID()
    return mMode
end

function CPlayer:GetChangedModelInfo()
    local oBianshen = self.m_oBaseCtrl.m_oBianShenMgr:GetCurBianShen()
    local mMode
    if oBianshen then
        mMode = self:PackBianShenModelInfo(oBianshen)
    else
        mMode = self:GetModelInfo()
    end
    return mMode
end

function CPlayer:PackBianShenTitleInfo(oBianshen)
    local mInfo = oBianshen:GetTitleInfo()
    return mInfo
end

function CPlayer:GetChangedTitleInfo(bSimple)
    local oBianshen = self.m_oBaseCtrl.m_oBianShenMgr:GetCurBianShen()
    local mInfo = {}
    if oBianshen then
        mInfo = self:PackBianShenTitleInfo(oBianshen)
    elseif not bSimple then
        mInfo = self:GetTitleInfo() or {} -- 防止设置失败（协议mask问题）
    end
    return mInfo
end

function CPlayer:GetOriginShape()
    local m = self.m_oBaseCtrl:GetData("model_info")
    return m.shape
end

function CPlayer:GetModelInfo()
    local oWaiGuan = self.m_oBaseCtrl.m_oWaiGuan
    local m = self.m_oBaseCtrl:GetData("model_info")
    local mRet = {}
    mRet.shape = m.shape
    mRet.scale = m.scale
    mRet.color = m.color
    mRet.mutate_texture = m.mutate_texture
    mRet.weapon = m.weapon
    mRet.adorn = m.adorn
    mRet.horse = self.m_oRideCtrl:GetUseRideID()
    mRet.fuhun = m.fuhun
    mRet.follow_spirit = self.m_oArtifactCtrl:GetFollowSpirit()
    mRet.show_wing = self.m_oWingCtrl:GetShowWing()
    
    local oSZObj = oWaiGuan:GetCurSZObj()
    if oSZObj then
        mRet.ranse_clothes = oSZObj:GetCurClothes()
        mRet.ranse_hair = oSZObj:GetCurHair()
        mRet.ranse_pant = oSZObj:GetCurPant()
        mRet.shizhuang = oWaiGuan:GetCurSZ()
        -- mRet.ranse_shizhuang = oWaiGuan:GetCurSZColor()
    else
        mRet.ranse_clothes = oWaiGuan:GetCurClothes()
        mRet.ranse_hair = oWaiGuan:GetCurHair()
        mRet.ranse_pant = oWaiGuan:GetCurPant()
    end
    return mRet
end


function CPlayer:GetShowId()
    local oProfile = self:GetProfile()
    return oProfile:GetShowId()
end

function CPlayer:GetMaxHp()
    return self:GetAttr("max_hp")
end

function CPlayer:GetMaxMp()
    return self:GetAttr("max_mp")
end

function CPlayer:GetHp()
    return self.m_oActiveCtrl:GetData("hp")
end

function CPlayer:GetMp()
    return self.m_oActiveCtrl:GetData("mp")
end

function CPlayer:GetMaxSp()
    return 150
end

function CPlayer:GetSp()
    return 0
end

function CPlayer:GetSpeed()
    return self:GetAttr("speed")
end

function CPlayer:GetCurePower()
    return self:GetAttr("cure_power")
end

function CPlayer:GetMagDefense()
    return self:GetAttr("mag_defense")
end

function CPlayer:GetPhyDefense()
    return self:GetAttr("phy_defense")
end

function CPlayer:GetMagAttack()
    return self:GetAttr("mag_attack")
end

function CPlayer:GetPhyAttack()
    return self:GetAttr("phy_attack")
end

function CPlayer:GetPhyCriticalRatio()
    return self:GetAttr("phy_critical_ratio")
end

function CPlayer:GetResPhyCriticalRatio()
    return self:GetAttr("res_phy_critical_ratio")
end

function CPlayer:GetMagCriticalRatio()
    return self:GetAttr("mag_critical_ratio")
end

function CPlayer:GetResMagCriticalRatio()
    return self:GetAttr("res_mag_critical_ratio")
end

function CPlayer:GetSealRatio()
    return self:GetAttr("seal_ratio")
end

function CPlayer:GetResSealRatio()
    return self:GetAttr("res_seal_ratio")
end

---------仅仅用于客户端显示--------------
function CPlayer:GetClientSealRatio()
    local iValue = self:GetAttr("seal_ratio", true)
    return my_floor(iValue * 10)
end

function CPlayer:GetClientResSealRatio()
    local iValue = self:GetAttr("res_seal_ratio", true)
    return my_floor(iValue * 10)
end
-----------------------------------------

function CPlayer:GetHitRatio()
    return self:GetAttr("hit_ratio")
end

function CPlayer:GetHitResRatio()
    return self:GetAttr("hit_res_ratio")
end

function CPlayer:GetPhyHitRatio()
    return self:GetAttr("phy_hit_ratio")
end

function CPlayer:GetPhyHitResRatio()
    return self:GetAttr("phy_hit_res_ratio")
end

function CPlayer:GetMagHitRatio()
    return self:GetAttr("mag_hit_ratio")
end

function CPlayer:GetMagHitResRatio()
    return self:GetAttr("mag_hit_res_ratio")
end

function CPlayer:GetCriticalMultiple()
    return self:GetAttr("critical_multiple")
end

function CPlayer:GetAttr(sAttr, bFloat)
    local fRet
    if gamedefines.USE_C_SUM and psum.IsAttr2C(sAttr) then
        fRet = self:GetCAttr(sAttr)
    else
        fRet = self:GetLAttr(sAttr)
    end
    return bFloat and fRet or math.floor(fRet)
end

function CPlayer:GetCAttr(sAttr)
    if gamedefines.USE_NEW_C_SUM then
        return self.m_oPSumCtrl:GetAttr(sAttr)
    else
        return self.m_cSumCtrl:getattr(sAttr)
    end
end

function CPlayer:GetLAttr(sAttr)
    local iValue = self:GetLBaseAttr(sAttr) * (100 + self:GetLBaseRatio(sAttr)) / 100 + self:GetLAttrAdd(sAttr)
    return iValue
end

function CPlayer:GetBaseAttr(sAttr, bFloat)
    local fRet
    if gamedefines.USE_C_SUM then
        fRet = self:GetCBaseAttr(sAttr)
    else
        fRet = self:GetLBaseAttr(sAttr)
    end
    return bFloat and fRet or decimal(fRet)
end

function CPlayer:GetCBaseAttr(sAttr)
    if gamedefines.USE_NEW_C_SUM then
        return self.m_oPSumCtrl:GetBaseAttr(sAttr)
    else
        return self.m_cSumCtrl:getbaseattr(sAttr)
    end
end

function CPlayer:GetLBaseAttr(sAttr)
    local mPointAttr = {"speed","mag_defense","phy_defense","mag_attack","phy_attack","max_hp", "max_mp"}
    if table_in_list(mPointAttr,sAttr) then
        local iRet = 0
        local mInitProp = res["daobiao"]["roleprop"][1]
        iRet = mInitProp[sAttr]
        if sAttr == "max_mp" then
            iRet = iRet + self:GetGrade() * 10 + 30
        else
            local key = string.format("%s_add",sAttr)
            local m = res["daobiao"]["point"]
            for k, v in pairs(m) do
                local i = self.m_oBaseCtrl:GetData(v.macro, 0)
                i = i * (100+self:GetLBaseRatio(v.macro)) / 100 + self:GetLAttrAdd(v.macro)
                i = i * v[key]
                if i then
                    iRet = iRet + i
                end
            end
--            if sAttr == "max_hp" then
--                iRet = iRet + self:GetGrade() * 5
--            end
        end
        return iRet
    else
        return self.m_oBaseCtrl:GetData(sAttr, 0)
    end
end

function CPlayer:GetBaseRatio(sAttr, bFloat)
    local fRet
    if gamedefines.USE_C_SUM then
        fRet = self:GetCBaseRatio(sAttr)
    else
        fRet = self:GetLBaseRatio(sAttr)
    end
    return bFloat and fRet or math.floor(fRet)
end

function CPlayer:GetCBaseRatio(sAttr)
    if gamedefines.USE_NEW_C_SUM then
        return self.m_oPSumCtrl:GetBaseRatio(sAttr)
    else
        return self.m_cSumCtrl:getbaseratio(sAttr)
    end
end

function CPlayer:GetLBaseRatio(sAttr)
    local iRatio = self.m_oSkillMgr:GetRatioApply(sAttr) + self.m_oEquipMgr:GetRatioApply(sAttr)
    + self.m_oRideCtrl:GetRatioApply(sAttr) + self.m_oTitleMgr:GetRatioApply(sAttr) + self.m_oFaBaoCtrl:GetRatioApply(sAttr)
    return iRatio
end

function CPlayer:GetAttrAdd(sAttr, bFloat)
    local fRet
    if gamedefines.USE_C_SUM then
        fRet = self:GetCAttrAdd(sAttr)
    else
        fRet = self:GetLAttrAdd(sAttr)
    end
    return bFloat and fRet or math.floor(fRet)
end

function CPlayer:GetCAttrAdd(sAttr)
    if gamedefines.USE_NEW_C_SUM then
        return self.m_oPSumCtrl:GetAttrAdd(sAttr)
    else
        return self.m_cSumCtrl:getattradd(sAttr)
    end
end

function CPlayer:GetLAttrAdd(sAttr)
    local iValue = self.m_oSkillMgr:GetApply(sAttr) + self.m_oEquipMgr:GetApply(sAttr)
    + self.m_oPartnerCtrl:GetApply(sAttr) + self.m_oTitleMgr:GetApply(sAttr)
    + self.m_oRideCtrl:GetApply(sAttr) + self.m_oTouxianCtrl:GetApply(sAttr)
    + self.m_oFaBaoCtrl:GetApply(sAttr)
    return iValue
end

function CPlayer:GetScore(mExclude)
    local iScore = 0
    if self.m_TestScore then
        iScore =  self.m_TestScore
    else
        iScore = global.oScoreCache:GetScore(self, mExclude)
    end
    local iMaxScore = self:Query("max_score", 0)
    self:Set("max_score", math.max(iScore, iMaxScore))
    safe_call(self.OnScoreChange,self,iScore)
    return iScore
end

function CPlayer:OnScoreChange(iScore)
    local iLastScore = self.m_iLastScore or 0
    if iLastScore == iScore then
        return
    end
    self.m_iLastScore = iScore

    local oHD = global.oHuodongMgr:GetHuodong("kaifudianli")
    if oHD then
        oHD:OnScoreChange(self,iScore)
    end
    local oHD = global.oHuodongMgr:GetHuodong("fightgiftbag")
    if oHD then
        oHD:OnScoreChange(self,iScore)
    end
    global.oMentoring:OnScoreChange(self, iScore)
end

function CPlayer:GetRoleScore()
    local iScore = global.oScoreCache:GetRoleScore(self)
    self.m_iRecordScore = iScore
    return iScore
end

function CPlayer:GetRecordScore()
    if self.m_iRecordScore then
        return self.m_iRecordScore
    end
    return self:GetRoleScore()
end

function CPlayer:GetSchoolPerform(bOrigin, oWarBianshen)
    if not bOrigin then
        -- BianShen 技能设置(顶替原有)
        if oWarBianshen then
            local mBianshenPerform = oWarBianshen:GetWarPerform()
            if mBianshenPerform then
                return mBianshenPerform
            end
        end
    end

    local mPerform = {}
    local mActiveSkill = loadskill.GetActiveSkill(self:GetSchool())
    for _,iSkill in pairs(mActiveSkill) do
        local oSk = self.m_oSkillCtrl:GetSkill(iSkill)
        if oSk then
            local mSkPerform = oSk:GetPerformList()
            for iPerform,iLevel in pairs(mSkPerform) do
                mPerform[iPerform] = iLevel
            end
        end
    end
    local mTestPerform = self.m_oActiveCtrl:GetInfo("TestPerform",{})
    for pfid,iLevel in pairs(mTestPerform) do
        mPerform[pfid] = iLevel
    end
    return mPerform
end

function CPlayer:GetProtectors()
    local mProtectors = {}
    if not self:IsSingle() then
        local lMember = self:HasTeam():GetTeamMember()
        mProtectors = self:GetFriend():GetProtectFriends(lMember)
    end
    return mProtectors
end

function CPlayer:GetProfile()
    local oWorldMgr = global.oWorldMgr
    return oWorldMgr:GetProfile(self.m_iPid)
end

function CPlayer:GetFriend()
    local oWorldMgr = global.oWorldMgr
    return oWorldMgr:GetFriend(self.m_iPid)
end

function CPlayer:GetMailBox()
    local oWorldMgr = global.oWorldMgr
    return oWorldMgr:GetMailBox(self.m_iPid)
end

function CPlayer:GetJJC()
    local oWorldMgr = global.oWorldMgr
    return oWorldMgr:GetJJC(self.m_iPid)
end

function CPlayer:GetChallenge()
    local oWorldMgr = global.oWorldMgr
    return oWorldMgr:GetChallenge(self.m_iPid)
end

function CPlayer:GetWanfaCtrl()
    local oWorldMgr = global.oWorldMgr
    return oWorldMgr:GetWanfaCtrl(self.m_iPid)
end

function CPlayer:GetPrivacy()
    local oWorldMgr = global.oWorldMgr
    return oWorldMgr:GetPrivacy(self.m_iPid)
end

function CPlayer:GetFeedBack()
    local oWorldMgr = global.oWorldMgr
    return oWorldMgr:GetFeedBack(self.m_iPid)
end

function CPlayer:HasFriend(iPid)
    local oFriend = self:GetFriend()
    if not oFriend then
        return false
    end
    return oFriend:HasFriend(iPid)
end

function CPlayer:IsGM()
    return global.oGMMgr:IsGM(self:GetPid())
end

function CPlayer:GS2CLoginRole()
    local mNet = {
        account = self:GetAccount(),
        channel = self:GetChannel(),
        pid = self:GetPid(),
        role = self:RoleInfo(),
        is_gm = self:IsGM() and 1 or 0,
        role_token = self:GetRoleToken(),
        create_time = self.m_iCreateTime,
    }
    self:Send("GS2CLoginRole", mNet)
end

function CPlayer:RoleInfo(m)
    local mRet = {}
    if not m then
        m = PropHelperFunc
    end
    for k, _ in pairs(m) do
        local f = assert(PropHelperFunc[k], string.format("RoleInfo fail f get %s", k))
        mRet[k] = f(self)
    end
    return net.Mask("base.Role", mRet)
end

function CPlayer:AddChallengeMatchInfo()
    if is_ks_server() then return end

    local oChallengeMgr = global.oChallengeMgr
    oChallengeMgr:AddChallengeMatchInfo(self:GetPid(), self:GetGrade(), self:GetScore())
end

function CPlayer:AddTrialMatchInfo()
    if is_ks_server() then return end

    global.oChallengeMgr:AddTrialMatchInfo(self:GetPid(), {
        school = self:GetSchool(),
        grade = self:GetGrade(),
        score = self:GetScore(),   
    })
end

--一阶属性统一计算(装备等赋予的属性)
function CPlayer:FirstLevelPropChange()
    self:PropChange("agility", "strength", "magic", "endurance", "physique")
end

--二阶属性统一计算(可能受到一阶属性或者其他类似装备/坐骑/技能等系统影响)
function CPlayer:SecondLevelPropChange()
    self:CheckAttr(bForce)
    self:PropChange("max_hp", "max_mp", "phy_attack",
        "phy_defense", "mag_attack", "mag_defense",
        "cure_power", "speed","hp", "mp", "score")
    self:AddChallengeMatchInfo()
    self:PropSecondChange("max_hp")
end

--三阶属性统一计算(主要受其他类似装备/坐骑/技能等系统影响)
function CPlayer:ThreeLevelPropChange()
    self:PropChange("seal_ratio", "res_seal_ratio", "phy_critical_ratio",
        "res_phy_critical_ratio", "mag_critical_ratio", "res_mag_critical_ratio",
        "critical_multiple")
end

function CPlayer:PropChange(...)
    local l = table.pack(...)
    local oWorldMgr = global.oWorldMgr
    oWorldMgr:SetPlayerPropChange(self:GetPid(), l)
end

function CPlayer:ClientPropChange(m)
    local mRole = self:RoleInfo(m)
    self:Send("GS2CPropChange", {
        role = mRole,
    })
    self:OnPropChange(mRole)
end

function CPlayer:AttrPropChange(...)
    local l = table.pack(...)
    local lNew = {}
    for _, k in pairs(l) do
        if PropHelperFunc[k] then
            table.insert(lNew, k)
        end
    end
    local oWorldMgr = global.oWorldMgr
    oWorldMgr:SetPlayerPropChange(self:GetPid(), lNew)
end

function CPlayer:OnPropChange(mRole)
    if mRole.score or mRole.grade then
        self:AddTrialMatchInfo()
    end


    local oTeam = self:HasTeam()
    if oTeam then
        local oMem = oTeam:GetMember(self.m_iPid)
        if oMem then
            oMem:Update(mRole)
        end
    end
end

function CPlayer:AddTask(taskobj, npcobj)
    local bSucc, iErr = self.m_oTaskCtrl:AddTask(taskobj, npcobj)
    if not bSucc then
        local taskdefines = import(service_path("task/taskdefines"))
        self:NotifyMessage(string.format("领取任务失败 %s", taskdefines.GetErrMsg(iErr)))
    end
    return bSucc
end

function CPlayer:TeamID()
    local oTeamMgr = global.oTeamMgr
    local iTeamID  = oTeamMgr.m_mPid2TeamID[self.m_iPid]
    return iTeamID
end

function CPlayer:HasTeam()
    local iTeamID = self:TeamID()
    if not iTeamID then
        return false
    end
    local oTeamMgr = global.oTeamMgr
    local oTeam = oTeamMgr:GetTeam(iTeamID)
    return oTeam
end

function CPlayer:IsTeamLeader()
    local oTeam = self:HasTeam()
    if not oTeam then
        return false
    end
    return oTeam:IsLeader(self.m_iPid)
end

function CPlayer:IsSingle()
    local oTeam = self:HasTeam()
    local pid = self:GetPid()
    if not oTeam  then
        return true
    end
    if oTeam:IsShortLeave(pid) then
        return true
    end
    return false
end

function CPlayer:SceneTeamMember()
    local oTeam = self:HasTeam()
    if not oTeam then
        return
    end
    local m = oTeam:GetFmtPosList()
    local ret = {}
    for iPos,pid in pairs(m) do
        ret[pid] = iPos
    end
    return ret
end

function CPlayer:IsTeamShortLeave()
    local oTeam = self:HasTeam()
    if not oTeam then
        return false
    end
    return oTeam:IsShortLeave(self:GetPid())
end

function CPlayer:SceneTeamShort()
    local oTeam = self:HasTeam()
    if not oTeam then
        return
    end
    local m = oTeam:GetTeamShort()
    local ret = {}
    for iPos,pid in pairs(m) do
        ret[pid] = iPos
    end
    return ret
end

function CPlayer:GetTeamLeader()
    local oTeam = self:HasTeam()
    if not oTeam then return end

    local oWorldMgr = global.oWorldMgr
    local iLeader = oTeam:Leader()
    return oWorldMgr:GetOnlinePlayerByPid(iLeader)
end

function CPlayer:SyncTeamSceneInfo()
    if self:IsTeamShortLeave() then
        local oLeader = self:GetTeamLeader()
        if oLeader then
            local oScene = oLeader.m_oActiveCtrl:GetNowScene()
            if oScene then
                oScene:SyncSceneTeam(oLeader)
            end
        end
    end
end


function CPlayer:GetTeamMember()
    local oTeam = self:HasTeam()
    if not oTeam then
        return
    end
    local m = oTeam:GetTeamMember()
    return m
end

function CPlayer:GetTeamSize(bOnline)
    local oTeam = self:HasTeam()
    if not oTeam then
        return 0
    end

    if bOnline then
        return oTeam:OnlineMemberSize()
    end
    return oTeam:TeamSize()
end

function CPlayer:GetMemberSize()
    local oTeam = self:HasTeam()
    if not oTeam then
        return 0
    end

    if oTeam:IsShortLeave(self:GetPid()) then
        return 1
    end

    return oTeam:MemberSize()
end

function CPlayer:GetTeamInfo( )
    local oTeam = self:HasTeam()
    if oTeam then
        local mTeamInfo = {}
        mTeamInfo["team_id"] = self:TeamID()
        mTeamInfo["team_size"] = oTeam:TeamSize()
        return mTeamInfo
    end
end

function CPlayer:SetAutoMatching(iTargetID, bAutoMatch)
    self.m_oActiveCtrl:SetInfo("auto_targetid", iTargetID)
    local mNet = {}
    mNet["player_match"] = 0
    mNet["auto_target"] = iTargetID
    if bAutoMatch then
        self.m_oActiveCtrl:SetInfo("auto_matching", true)
        mNet["player_match"] = 1
    else
        self.m_oActiveCtrl:SetInfo("auto_matching", false)
    end
    self:Send("GS2CNotifyAutoMatch", mNet)
end

function CPlayer:NewHour(mNow)
    local iHour = mNow.date.hour
    if iHour == 0 then
        self:NewDay(mNow)
    elseif iHour == 5 then
        self:NewHour5(mNow)
    elseif iHour == 4 then
        self:NewHour4(mNow)
    end
    self.m_oBaseCtrl:NewHour(mNow)
end

function CPlayer:NewDay(mNow)
    local oHuodongMgr = global.oHuodongMgr
    local oHuodong = oHuodongMgr:GetHuodong("welfare")
    if oHuodong then
        oHuodong:HandleLoginGift(self, true)
    end
    if global.oMarryMgr then
        global.oMarryMgr:CheckMarryDate(self)
    end

    local mLogData = self:LogData()
    mLogData["account"] = self:GetAccount()
    mLogData["channel"] = self:GetChannel()
    mLogData["duration"] = (mNow.time - self.m_iDurationCalTime) / 60
    self.m_iDurationCalTime = mNow.time
    record.log_db("player", "newday", mLogData)
end

--5点刷新接口
function CPlayer:NewHour5(mNow)
    self.m_oTaskCtrl:OnNewHour5(self)
    self.m_oScheduleCtrl:OnNewHour5(self, mNow)
    self.m_oStoreCtrl:NewHour5()
    self.m_oActiveCtrl:NewHour5(self)
    self.m_oBaseCtrl:NewHour5(mNow)
    if global.oMentoring then
        global.oMentoring:NewHour5(self)
    end
end

function CPlayer:NewHour4(mNow)
    self.m_oRideCtrl:CheckTimeCb()
    self.m_oTitleCtrl:CheckTimeCb()
    local oMailBox = self:GetMailBox()
    oMailBox:CheckTimeCb()
    self.m_oTaskCtrl:CheckTimeCb()
    self.m_oBaseCtrl.m_oBianShenMgr:CheckTimeCb()
end

function CPlayer:SyncModelInfo()
    self:PropChange("model_info", "model_info_changed")
    self:SyncSceneInfo({
        model_info = self:GetChangedModelInfo(),
    })
end

function CPlayer:SyncBianshenInfo()
    self:PropChange("model_info", "title_info_changed", "model_info_changed", "fly_height")
    local mNet = {
        model_info = self:GetChangedModelInfo(),
        title_info = self:GetChangedTitleInfo(),
        fly_height = self.m_oRideCtrl:GetRideFly(),
    }
    --秘宝护送取消掉fly_height,不然前端速度会被还原
    local oNowScene = self:GetNowScene()
    local oHuodong = global.oHuodongMgr:GetHuodong("treasureconvoy")
    if oNowScene and oHuodong and oNowScene:GetSceneId() == oHuodong:GetSceneId() then
        mNet.fly_height = nil
    end
    self:SyncSceneInfo(mNet)
end

function CPlayer:SyncFollowers()
    self:PropChange("followers")
    self:SyncSceneInfo({
        followers = self:GetFollowers(),
    })
end

function CPlayer:ChangeWeapon()
    local m = self.m_oBaseCtrl:GetData("model_info")
    local iWeapon = 0
    local iFuHun = 0
    local oWeapon = self.m_oItemCtrl:GetItem(1)
    if oWeapon and oWeapon:IsValid() then
        iWeapon = oWeapon:Shape()
        iFuHun = oWeapon:FuHunFlag()
    end
    m.weapon = iWeapon
    m.fuhun = iFuHun
    self.m_oBaseCtrl:SetData("model_info",m)
    if self:HasBianShen() then
        return
    end
    self:PropChange("model_info")
    self:SyncModelInfo()
end

function CPlayer:StrengthenLevel(iPos)
    return self.m_oEquipCtrl:GetStrengthenLevel(iPos)
end

-- @param iPos:<int iPos(装备位置)/-1(全部)>
function CPlayer:PackStrengthenInfo(iPos)
    if not iPos then return nil end

    local mLevel = self.m_oEquipCtrl:GetStrengthenLevels()
    local oStrengthMgr = global.oItemHandler.m_oEquipStrengthenMgr
    local lPosList
    if iPos > 0 then
        lPosList = {iPos}
    else
        lPosList = table_key_list(mLevel)
    end

    local lStrengthenInfo = {}
    for _, ipos in ipairs(lPosList) do
        local iBaseRatio, iAddRatio = oStrengthMgr:QueryStrengthenRatio(self, ipos)
        table.insert(lStrengthenInfo, {
            pos=ipos,
            level=mLevel[ipos] or 0,
            success_ratio_base = iBaseRatio,
            success_ratio_add = iAddRatio,
            break_level=self.m_oEquipCtrl:GetBreakLevel(ipos),
            score = math.floor(1000 * self.m_oEquipMgr:GetStrengthenPosScore(ipos))
        })
    end
    return lStrengthenInfo
end

-- 向前端推送强化信息
-- @param iPos:<int iPos(装备位置)/nil(无)/-1(全部)>
function CPlayer:SyncStrengthenInfo(iPos, bMasterScore)
    local mNet = {}
    if iPos then
        mNet.strengthen_info = self:PackStrengthenInfo(iPos)
    end
    if bMasterScore then
        mNet.master_score = math.floor(1000 * self.m_oEquipMgr:GetStrengthenMasterScore())
    end
    mNet = net.Mask("GS2CUpdateStrengthenInfo", mNet)
    self:Send("GS2CUpdateStrengthenInfo", mNet)
end

function CPlayer:StrengthFailCnt(iPos)
    return self.m_oEquipCtrl:GetStrengthenFailCnt(iPos)
end

function CPlayer:EquipStrength(iPos,iLevel)
    local oItem = self.m_oItemCtrl:GetItem(iPos)
    oItem:StrengthUnEffect(self)
    local iMasterLevelOld = self:StrengthMasterLevel()
    self.m_oEquipCtrl:SetStrengthenLevel(iPos, iLevel)
    global.oScoreCache:Dirty(self:GetPid(), "strength")
    global.oScoreCache:Dirty(self:GetPid(), "equip")
    -- 刷新部位强化效果Apply
    self.m_oEquipMgr:UpdateStrengthenSource(iPos, iLevel)
    -- TODO 装备已经没有强化逻辑了，要改到EquipMgr里去
    oItem:StrengthEffect(self)

    -- 判断强化大师的加成是否要重新计算
    local iMasterLevelNew = self:StrengthMasterLevel()
    local bMasterChanged = false
    if iMasterLevelOld ~= iMasterLevelNew then
        self:TriggerStrengthMaster(iMasterLevelNew)
        bMasterChanged = true
    end
end

function CPlayer:GetStrengthenMinPosLevel(bCheckWield)
    local iMin
    for iPos = 1, 6 do
        if bCheckWield then
            local oItem = self.m_oItemCtrl:GetItem(iPos)
            if not oItem then
                return 0
            end
        end
        local iLevel = self.m_oEquipCtrl:GetStrengthenLevel(iPos)
        if not iMin or iMin > iLevel then
            iMin = iLevel
        end
    end
    return iMin or 0
end

--强化大师等级
function CPlayer:StrengthMasterLevel()
    local res = require "base.res"
    local mData = res["daobiao"]["strengthmaster"] or {}
    local iSchool = self:GetSchool()
    mData = mData[iSchool]
    if not mData then
        return 0
    end
    local iMinStrengthenLevel = self:GetStrengthenMinPosLevel(true)
    local iMasterLevel = 0
    local mLevel = table_key_list(mData)
    table.sort(mLevel)
    for _,iLevel in ipairs(mLevel) do
        if iMinStrengthenLevel >= iLevel then
            iMasterLevel = iLevel
        else
            break
        end
    end
    return iMasterLevel
end

-- 强化大师的属性是逐级叠加的，因此要依次增加
function CPlayer:TriggerStrengthMaster(iNewMasterLv)
    local iMasterSourceId = itemdefines.STRENGTH_MASTER
    -- clear old source AttrApplyInfo
    self.m_oEquipMgr:RemoveSource(iMasterSourceId)
    -- 更新强化属性记录
    self.m_oEquipMgr:UpdateStrengthenSource(iMasterSourceId, iNewMasterLv)

    -- 将记录的属性刷到角色属性上
    self.m_oEquipMgr:CalMasterApply()
    self:RefreshPropAll()
end

function CPlayer:SetStrengthFailCnt(iPos, iCnt)
    self.m_oEquipCtrl:SetStrengthenFailCnt(iPos, iCnt)
end

function CPlayer:SetOrgInviteInfo(pid, mData)
    local m = {}
    m.orgId = mData.orgId
    m.inviteTime = get_time()
    self.m_orgInviteInfo[pid] = m
end

function CPlayer:RemoveOrgInviteInfo(pid)
    self.m_orgInviteInfo[pid] = nil
end

function CPlayer:ClearOrgInviteInfo()
    self.m_orgInviteInfo = {}
end

function CPlayer:GetOrgInviteInfo(pid)
    return self.m_orgInviteInfo[pid]
end

function CPlayer:CheckAttr(bForce)
    if bForce or self.m_oStateCtrl:GetBaoShiCount() > 0 then
        self.m_oActiveCtrl:SetData("hp", self:GetMaxHp())
        self.m_oActiveCtrl:SetData("mp", self:GetMaxMp())
    else
        local iHp = self.m_oActiveCtrl:GetData("hp")
        if not iHp or iHp <= 0 or iHp > self:GetMaxHp() then
            self.m_oActiveCtrl:SetData("hp", self:GetMaxHp())
        end
        local iMp = self.m_oActiveCtrl:GetData("mp")
        if not iMp or iMp <= 0 or iMp > self:GetMaxMp() then
            self.m_oActiveCtrl:SetData("mp", self:GetMaxMp())
        end
    end
end

function CPlayer:Query(sKey, default)
    local mInfo = self.m_oBaseCtrl:GetData("other_info", {})
    return mInfo[sKey] or default
end

function CPlayer:Set(sKey, value)
    local mInfo = self.m_oBaseCtrl:GetData("other_info", {})
    mInfo[sKey] = value
    self.m_oBaseCtrl:SetData("other_info", mInfo)
end

function CPlayer:Add(sKey, value)
    local iOld = self:Query(sKey, 0)
    self:Set(sKey, iOld+value)
end

function CPlayer:SetTemp(sKey, value)
    self.m_mTempInfo[sKey] = value
end

function CPlayer:GetTemp(sKey, default)
    return self.m_mTempInfo[sKey] or default
end

function CPlayer:AddOrgOffer(iVal, sReason, mArgs)
    if iVal > 0 then
        self.m_oActiveCtrl:RewardOrgOffer(iVal, sReason, mArgs)
    else
        self.m_oActiveCtrl:ResumeOrgOffer(-iVal, sReason, mArgs)
    end
end

function CPlayer:GetOffer()
    return self.m_oActiveCtrl:GetOffer()
end

function CPlayer:AddFreezeOrgOffer(iVal)
    self.m_oActiveCtrl:AddFreezeOrgOffer(iVal)
end

function CPlayer:GetFreezeOrgOffer()
    return self.m_oActiveCtrl:GetFreezeOrgOffer()
end

function CPlayer:GetMaxEnergy()
    local iMax = 220 + math.min(2000, self:GetGrade() * 18)
    return iMax
end

function CPlayer:GetMaxLimitEnergy()
    local iMax = 2*self:GetMaxEnergy()
    return iMax
end

function CPlayer:AddEnergy(iVal, sReason, mArgs)
    if iVal > 0 then
        self.m_oActiveCtrl:RewardEnergy(iVal, sReason, mArgs)
    else
        self.m_oActiveCtrl:ResumeEnergy(-iVal, sReason, mArgs)
    end
end

function CPlayer:AddVigor(iVal, sReason)
    self.m_oActiveCtrl:AddVigor(iVal, sReason)
end

function CPlayer:RefreshCulSkillUpperLevel()
    if global.oToolMgr:IsSysOpen("XIU_LIAN_SYS", self, true) then
        self.m_oSkillCtrl:RefreshCulSkillUpperLevel(self)
    end
end

function CPlayer:NotifyMessage(msg)
    local oNotifyMgr = global.oNotifyMgr
    oNotifyMgr:Notify(self:GetPid(), msg)
end

function CPlayer:AddOrgHuoYue(iVal)
    local oOrg = self:GetOrg()
    if oOrg then
        oOrg:AddMemberHuoYue(self:GetPid(), iVal)
    end
end

function CPlayer:PackTitleInfo2Chat()
    return self.m_oTitleCtrl:GetTitleInfo2Chat() or {}
end

function CPlayer:PackTitleInfo()
    return self:GetTitleInfo() or {}
end

function CPlayer:PackChangedTitleInfo()
    return self:GetChangedTitleInfo(true)
end

function CPlayer:GetTitleInfo()
    return self.m_oTitleCtrl:GetTitleInfo()
end

function CPlayer:AddTitle(iTid, createTime, name)
    self.m_oTitleCtrl:AddTitle(self, iTid, createTime, name)
end

function CPlayer:RemoveTitles(tidList)
    self.m_oTitleCtrl:RemoveTitles(self, tidList)
end

function CPlayer:GetTitle(iTid)
    return self.m_oTitleCtrl:GetTitleByTid(iTid)
end

function CPlayer:SyncTitleName(iTid, name)
    self.m_oTitleCtrl:SyncTitleName(self, iTid, name)
end

function CPlayer:PackSimpleInfo()
    local mNet = {}
    mNet.pid = self:GetPid()
    mNet.name = self:GetName()
    mNet.grade = self:GetGrade()
    mNet.school = self:GetSchool()
    mNet.icon = self:GetIcon()
    return mNet
end

function CPlayer:PackTouxianInfo()
    if self.m_oTouxianCtrl.m_oTouxian then
        return self.m_oTouxianCtrl.m_oTouxian:PackNetInfo()
    end
    return {}
end

function CPlayer:PackRole2Chat()
    local mRoleInfo = {}
    mRoleInfo.pid = self:GetPid()
    mRoleInfo.grade = self:GetGrade()
    mRoleInfo.name = self:GetName()
    -- mRoleInfo.shape = self:GetModelInfo().shape
    mRoleInfo.icon = self:GetIcon()
    mRoleInfo.title_info = self:PackTitleInfo2Chat()
    return mRoleInfo
end

function CPlayer:PackRole2OrgChat()
    local mRoleInfo = self:PackRole2Chat()
    local oOrg = self:GetOrg()
    if oOrg then
        mRoleInfo.position = oOrg:GetPosition(self:GetPid())
        mRoleInfo.honor = oOrg:GetOrgHonor(self:GetPid())
    end
    return mRoleInfo
end

function CPlayer:GetLastDayHuoYue()
    return self.m_oScheduleCtrl:GetLastDayPoint()
end

function CPlayer:SendNotification(iText, mArgs)
    local oNotifyMgr = global.oNotifyMgr
    local oToolMgr = global.oToolMgr
    local sTip = oToolMgr:GetTextData(iText)
    local sMsg = oToolMgr:FormatColorString(sTip, mArgs)
    oNotifyMgr:Notify(self:GetPid(), sMsg)
end

function CPlayer:GetFormationMgr()
    return self.m_oBaseCtrl.m_oFmtMgr
end

function CPlayer:GetFubenMgr()
    return self.m_oBaseCtrl.m_oFubenMgr
end

function CPlayer:HasDoneFuben(iFuben)
    local oFubenMgr = self:GetFubenMgr()
    return oFubenMgr:HasDoneFuben(iFuben)
end

function CPlayer:HasSeenNpc(npctype)
    return self.m_oActiveCtrl.m_oVisualMgr:HasSeenNpc(npctype)
end

function CPlayer:RecSeenNpc(npctype)
    self.m_oActiveCtrl.m_oVisualMgr:RecSeenNpc(npctype)
end

function CPlayer:LogData()
    return {pid=self:GetPid(), show_id=self:GetShowId(), name=self:GetName(), grade=self:GetGrade(), channel=self:GetChannel()}
end

function CPlayer:LeaveWar(mData)
    if mData and mData.hp and mData.mp and mData.gameplay ~= "arena" then
        if mData.relife == true then
            self:CheckAttr(true)
        else
            local iHP = mData.hp
            self.m_oActiveCtrl:SetData("hp",iHP)
            local iMP = mData.mp
            self.m_oActiveCtrl:SetData("mp",iMP)
            self:CheckAttr()
        end
        self:PropChange("mp","hp")
    end
end

function CPlayer:InWar()
    return self.m_oActiveCtrl:GetNowWar()
end

function CPlayer:WarEnd()
    self:ExecWarEndCB()
    global.oTaskMgr:ResetPosForAnlei(self)
end

function CPlayer:HasWarEndCB(flag)
    return self.m_mWarEndCB[flag]
end

function CPlayer:AddWarEndCB(flag,func,args)
    args = args or {}
    self.m_mWarEndCB[flag]={func=func,args=args}
end

function CPlayer:DelWarEndCB(flag)
    self.m_mWarEndCB[flag]=nil
end

function CPlayer:ExecWarEndCB()
    for flag,funccode in pairs(self.m_mWarEndCB) do
        local func = funccode.func
        local args = funccode.args
        if func and args then
            safe_call(func,args,self)
        else
            record.warning(string.format("ExecWarEndCB %s",flag))
        end
    end
    self.m_mWarEndCB={}
end

function CPlayer:IsAppoint()
    local oTeam = self:HasTeam()
    if oTeam and oTeam:IsTeamMember(self.m_iPid) then
        if  oTeam.m_iAppoint == self.m_iPid then
            return 1
        else
            return 0
        end
    end
    return 1
end

-- 下线将所有必要信息推送至后台数据库
function CPlayer:AllSendBackendLog()
    -- war info to backenddb
    safe_call(self.SendBackendLog, self, "player", "warinfo", self:PackBackendWarInfo())
    -- task info to backenddb
    safe_call(self.SendBackendLog, self, "player", "taskinfo", self.m_oTaskCtrl:PackBackendInfo())
end

--玩家登出时保存数据至后台数据库
--@param sTableName 表名，默认player
--@param sType 所存数据类型
--＠param mData 数据，可以是map,可以是list
function CPlayer:SendBackendLog(sTableName, sType, mData)
    sTableName = sTableName or "player"
    sType = sType or sTableName
    mData = mData or {}

    local mLog = {}

    mLog["pid"] = self:GetPid()
    mLog["tablename"] = sTableName
    mLog["type"] = sType
    mLog["data"] = mData or {}

    local sLog = extend.Table.serialize(mLog)
    router.Send("bs", ".backend", "common", "SaveBackendLog", sLog)
end

function CPlayer:SyncRoleData2DataCenter()
    safe_call(self.UpdateDataCenterRoleInfo, self)
end

function CPlayer:UpdateDataCenterRoleInfo()
    local mArgs = {}
    mArgs.pid = self:GetPid()
    mArgs.icon = self:GetIcon()
    mArgs.grade = self:GetGrade()
    mArgs.school = self:GetSchool()
    mArgs.name = self:GetName()
    mArgs.login_time = self.m_oActiveCtrl:GetData("login_time")

    router.Send("cs", ".datacenter", "common", "UpdateRoleInfo", mArgs)
end

function CPlayer:ResumeBaoShi(iResume,sGamePlay)
    local oState = self.m_oStateCtrl:GetState(1003)
    if not oState then
        return false
    end
    if gamedefines.BAOSHI_GAMEPLAY[sGamePlay]  then
        oState:TryPopUI(self.m_iPid)
        return true
    end
    if iResume == 0 then
        oState:TryPopUI(self.m_iPid)
        return true
    end
    if oState:GetCount() >0 then
        oState:AddCount(self.m_iPid,-1)
        return true
    end
    oState:TryPopUI(self.m_iPid)
    return false
end

function CPlayer:IsFixed()
    return false
end

function CPlayer:PushPlayerScoreRank()
    local mData = {}
    mData.score  = self:GetScore()
    mData.pid  = self.m_iPid
    mData.school  = self:GetSchool()
    mData.touxian = self.m_oTouxianCtrl:GetTouxianID()
    mData.name = self:GetName()
    global.oRankMgr:PushDataToRank("player_score",mData)
end

function CPlayer:PushRoleScoreRank()
    local mData = {}
    mData.score = self:GetRoleScore()
    mData.pid  = self.m_iPid
    mData.school  = self:GetSchool()
    mData.touxian = self.m_oTouxianCtrl:GetTouxianID()
    mData.name = self:GetName()
    mData.time = get_time()
    global.oRankMgr:PushDataToRank("role_score",mData)
end

function CPlayer:PushSumScoreRank()
    local mData = self.m_oSummonCtrl:GetRankData()
    global.oRankMgr:PushDataToRank("summon_score",mData)
end

function CPlayer:LogItemOnChange(sLogType, iSid, iAmount, sReason, mItemInfo)
    local mLogData = self:LogData()
    mLogData.item = iSid
    mLogData.amount = iAmount
    mLogData.reason = sReason or ""
    mLogData.iteminfo = mItemInfo or {}
    record.user("item", sLogType, mLogData)
end

function CPlayer:LoginOrOutAnalyInfo(iOperation)
    if not global.oWorldMgr:GetOnlinePlayerByPid(self:GetPid()) then
        return
    end

    local iNowTime = get_time()
    local iOnline = iNowTime - (self.m_iLoginAnalyTime or iNowTime)
    self.m_iLoginAnalyTime = nil
    if iOperation == 1 then
        self.m_iLoginAnalyTime = get_time()
    end

    if self:GetProfile() then
        local mLog = self:BaseAnalyInfo()
        mLog["operation"] = iOperation
        mLog["online_time"] = iOnline * 1000
        mLog["yuanbao"] = self:GetGoldCoin()
        analy.log_data("Login_outRole", mLog)
    end
end

function CPlayer:BaseAnalyInfo()
    return {
        account_id = self:GetAccount(),
        role_id = self:GetPid(),
        role_name = self:GetName(),
        profession = self:GetSchool(),
        role_level = self:GetGrade(),
        fight_point = self:GetRecordScore(),
        ip = self:GetIP(),
        device_model = self:GetDevice(),
        udid = self:GetUDID(),
        os = self:GetClientOs(),
        version = self:GetClientVer(),
        app_channel = self:GetChannel(),
        sub_channel = self:GetCpsChannel(),
        server = self:GetBornServerKey() or get_server_key(),
        plat = self:GetFakePlatform(),
        is_recharge = self:HasCharge() and 1 or 0,
    }
end

function CPlayer:RecordAnalyContent()
    self:SetTemp("reward_content", {})
    self:SetTemp("consume_content", {})
    local oWorldMgr = global.oWorldMgr
    oWorldMgr:RecordPlayerAnalyInfo(self:GetPid())
end

function CPlayer:ClearAnalyContent()
    self:SetTemp("reward_content", nil)
    self:SetTemp("consume_content", nil)
end

function CPlayer:RedeemCodeReward(sCode, iErr, iGift, iRedeem)
    global.oRedeemCodeMgr:RedeemCodeReward(self, sCode, iErr, iGift, iRedeem)
end

function CPlayer:GetVirtualScene(iMapID,sVirtual)
    if sVirtual == "fumo" then
        local oTeam = self:HasTeam()
        if not oTeam then return end
        local oFuben = oTeam:GetFuben()
        if not oFuben then return end
        return oFuben:GetSceneByMapID(iMapID)
    elseif sVirtual == "org" then
        local orgobj = self:GetOrg()
        local oScene = global.oSceneMgr:GetScene(orgobj.m_iSceneID)
        return oScene
    elseif sVirtual == "jyfuben" then
        local oHD = global.oHuodongMgr:GetHuodong(sVirtual)
        return oHD:GetSceneByMapID(self.m_iPid,iMapID)
    end
end

function CPlayer:IsInFuBen()
    local oTeam = self:HasTeam()
    if not oTeam then return false end
    local oFuben=oTeam:GetFuben()
    if oFuben then return oFuben end
    return false
end

function CPlayer:SyncTesterKeys()
    local lKeys = self.m_oBaseCtrl.m_oTestCtrl:GetTesterAllKeys()
    self:Send("GS2CSyncTesterKeys", {keys = lKeys})
end

function CPlayer:SynclSumAdd(iModule,sAttr,value)
    if type(iModule) == "number" and type(sAttr) == "string" and type(value) == "number" then
        if gamedefines.USE_NEW_C_SUM then
            self.m_oPSumCtrl:Add(iModule,sAttr,value)
        else
            self.m_cSumCtrl:add(iModule,sAttr,value)
        end
    end
end

function CPlayer:SynclSumSet(iModule,sAttr,value)
    if type(iModule) == "number" and type(sAttr) == "string" and type(value) == "number" then
        if gamedefines.USE_NEW_C_SUM then
            if sAttr == "grade" then
                self.m_oPSumCtrl:SetGrade(value)
            else
                self.m_oPSumCtrl:Set(iModule,sAttr,value)
            end
        else
            self.m_cSumCtrl:set(iModule,sAttr,value)
        end
    end
end

function CPlayer:ClearlSum(iModule)
    if gamedefines.USE_NEW_C_SUM then
        self.m_oPSumCtrl:Clear(iModule)
    else
        self.m_cSumCtrl:clear(iModule)
    end
end

function CPlayer:ExchangeMoneyByGoldCoin(iMoneyType,iGoldCoin,sReason,mArgs)
    if not self:ValidGoldCoin(iGoldCoin) then
        return
    end
    sReason = sReason or "exchange_goldcoin"
    local mRes = res["daobiao"]["exchangemoney"][gamedefines.MONEY_TYPE.GOLDCOIN]
    local iServerGrade = self:GetServerGrade()
    if iMoneyType == gamedefines.MONEY_TYPE.GOLD then
        local sFormula = mRes.gold
        local mEnv = {}
        mEnv.value = iGoldCoin
        mEnv.SLV = iServerGrade
        local iValue = formula_string(sFormula, mEnv)
        if iValue<=0 then
            return
        end
        self:ResumeGoldCoin(iGoldCoin,sReason,mArgs)
        self:RewardGold(iValue,sReason,mArgs)
    elseif iMoneyType == gamedefines.MONEY_TYPE.SILVER then
        local sFormula = mRes.silver
        local mEnv = {}
        mEnv.value = iGoldCoin
        mEnv.SLV = iServerGrade
        local iValue = formula_string(sFormula,mEnv)
        if iValue<=0 then
            return
        end
        self:ResumeGoldCoin(iGoldCoin,sReason,mArgs)
        self:RewardSilver(iValue,sReason,mArgs)
    end
end

function CPlayer:MarkGrow(index)
    self.m_oBaseCtrl.m_oGrow:MarkGrow(index)
end

function CPlayer:GetServerGrade()
    return global.oWorldMgr:GetServerGrade()
end

function CPlayer:GetServerGradeLimit()
    return self:GetServerGrade() + 5
end

function CPlayer:IsForceLogin()
    return self.m_iForceLogin == 1
end

function CPlayer:DissolveEngage()
    global.oEngageMgr:OnDissolveEngage(self)
end

function CPlayer:GetCouplePid()
    return self.m_oMarryCtrl:GetCouplePid()
end

function CPlayer:GetCoupleName()
    return self.m_oMarryCtrl:GetCoupleName()
end

function CPlayer:GetEngageType()
    return self.m_oMarryCtrl:GetEngageType()
end

function CPlayer:PackSecondUnit()
    local mNet = {}
    for sAttr,_ in pairs(gamedefines.SECOND_PROP_MAP) do
        table.insert(mNet, {
            base = self:GetBaseAttr(sAttr) * 1000,
            extra = self:GetAttrAdd(sAttr) * 1000,
            ratio = self:GetBaseRatio(sAttr) * 1000,
            name = sAttr,
        })
    end
    return mNet
end

function CPlayer:PropSecondChange(sAttr)
    local sAttrUnit = gamedefines.SECOND_PROP_MAP[sAttr]
    if not sAttrUnit then return end

    self:PropChange("prop_info")
end

function CPlayer:GetWalkSpeed()
    local oRide = self.m_oRideCtrl:GetUseRide()
    if oRide then
        return oRide:GetRideSpeed()
    end
    return gamedefines.WALK_SPEED
end

function CPlayer:FireEnterWarScene()
    self:TriggerEvent(gamedefines.EVENT.PLAYER_ENTER_WAR_SCENE, {})
end

function CPlayer:SyncMarryCoupleName(sName)
    self.m_oMarryCtrl:SyncCoupleName(sName)
end

function CPlayer:DoForceDivorce(iTime, sName)
    global.oMarryMgr:_DoForceDivorce2(self, iTime, sName)
end

function CPlayer:OnSuccessDivorce()
    global.oMarryMgr:OnSuccessDivorce(self, true)
end

function CPlayer:PackCoupleInfo()
    return self.m_oMarryCtrl:PackCoupleInfo()
end

function CPlayer:GenItemLockMask()
    if not self.m_iItemLockMask then
        self.m_iItemLockMask = 0
    end
    self.m_iItemLockMask = self.m_iItemLockMask + 1
    if self.m_iItemLockMask > 7 then
        self.m_iItemLockMask = 1
    end
    return self.m_iItemLockMask
end

--总的充值数据
function CPlayer:GetAllCharge()
    return self:Query("all_charge", {rmb = 0, goldcoin = 0})
end

--从商城充值的数据
function CPlayer:GetStoreCharge()
    return self:Query("store_charge", {rmb = 0, goldcoin = 0})
end

function CPlayer:HasCharge()
    local mCharge = self:GetAllCharge()
    if mCharge.rmb and mCharge.rmb > 0 then
        return true
    end
    return false
end

function CPlayer:IsFirstLogin()
    local sKey = "today_first_login"
    if self.m_oTodayMorning:Query(sKey, 1) == 1 then
        return true
    else
        return false
    end
end

function CPlayer:FirstLoginEnd()
    local sKey = "today_first_login"
    if self.m_oTodayMorning:Query(sKey, 1) == 1 then
        self.m_oTodayMorning:Set(sKey, 0)
    end
end
