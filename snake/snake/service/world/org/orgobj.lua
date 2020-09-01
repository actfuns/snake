--import module
local global = require "global"
local interactive = require "base.interactive"
local extend = require "base.extend"
local net = require "base.net"
local res = require "base.res"
local record = require "public.record"

local datactrl = import(lualib_path("public.datactrl"))
local orgbase = import(service_path("org.orgbase"))
local orgmember = import(service_path("org.orgmember"))
local orgbuild = import(service_path("org.orgbuild"))
local orglog = import(service_path("org.orglog"))
local orgapply = import(service_path("org.orgapply"))
local orgboon = import(service_path("org.orgboon"))
local orgdefines = import(service_path("org.orgdefines"))
local orgachieve = import(service_path("org.orgachieve"))
local loadnpc = import(service_path("org.loadnpc"))
local gamedefines = import(lualib_path("public.gamedefines"))
local effectobj = import(service_path("effect.effectobj"))
local gamedb = import(lualib_path("public.gamedb"))


function NewOrg(...)
    return COrg:New(...)
end

function CheckApplyLeaderSuccess(iOrgID)
    local oOrgMgr = global.oOrgMgr
    local oOrg = oOrgMgr:GetNormalOrg(iOrgID)
    if not oOrg then return end

    oOrg:_ApplyLeaderSuccess()
end

COrg = {}
COrg.__index = COrg
inherit(COrg, datactrl.CDataCtrl)

function COrg:New(orgid)
    local o = super(COrg).New(self)
    o.m_iID = orgid
    o.m_tmp_mData = {}
    o.m_mNpcId = {}
    o.m_mTest = {}
    o.m_bUpdate = false
    o.m_mSyncMember = {}
    o.m_mSceneEffect = {}
    o.m_iMail = 0
    o.m_bNotiyMaxCash = true
    o:Init()
    return o
end

function COrg:Init()
    local iOrgID = self:OrgID()
    self.m_oBaseMgr = orgbase.NewBaseMgr(iOrgID)
    self.m_oMemberMgr = orgmember.NewMemberMgr(iOrgID)
    self.m_oBuildMgr = orgbuild.NewBuildMgr(iOrgID)
    self.m_oLogMgr = orglog.NewLogMgr(iOrgID)
    self.m_oApplyMgr = orgapply.NewApplyMgr(iOrgID)
    self.m_oBoonMgr = orgboon.NewBoonMgr(iOrgID)
    self.m_oAchieveMgr = orgachieve.NewAchieveMgr(iOrgID)
end

function COrg:GetTempData(sKey, vDefault)
    return self.m_tmp_mData[sKey] or vDefault
end

function COrg:SetTempData(sKey, value)
    self.m_tmp_mData[sKey] = value
end

function COrg:Create(sName, iShowId, sAim)
    self:SetData("name", sName)
    self:SetData("showid", iShowId)
    self.m_oBaseMgr:Create(sAim)
end

function COrg:Setup()
    self.m_oAchieveMgr:HandleEvent(orgdefines.ORG_ACH_TYPE.MEM_GRADE_CNT, {pid=self:GetLeaderID(), level=999})
    local iCash = res["daobiao"]["org"]["others"][1]["create_init_cash"]
    self.m_oBaseMgr:AddCash(iCash)
end

function COrg:Release()
    baseobj_safe_release(self.m_oBaseMgr)
    baseobj_safe_release(self.m_oMemberMgr)
    baseobj_safe_release(self.m_oBuildMgr)
    baseobj_safe_release(self.m_oLogMgr)
    baseobj_safe_release(self.m_oApplyMgr)
    baseobj_safe_release(self.m_oBoonMgr)
    baseobj_safe_release(self.m_oAchieveMgr)

    self.m_tmp_mData = {}
    self.m_mNpcId = {}
    self.m_mSceneEffect = {}
    super(COrg).Release(self)
end

function COrg:RemoveOrgScene()
    if self.m_iSceneID then
        local oSceneMgr = global.oSceneMgr
        local oScene = oSceneMgr:GetScene(self.m_iSceneID)
        for iEffectType, oEffect in pairs(self.m_mSceneEffect) do
            safe_call(oScene.RemoveSceneEffect, oScene, oEffect:ID())
            baseobj_delay_release(oEffect)
        end
        self.m_mSceneEffect = {}

        local oSceneMgr = global.oSceneMgr
        oSceneMgr:RemoveVirtualScene(self.m_iSceneID)
    end
end

function COrg:_CheckApplyLeader()
    if not self:HasApplyLeader()  then
        return
    end
    self:DelTimeCb("_CheckApplyLeader")
    local iLeftTime = math.max(self.m_oMemberMgr:GetApplyLeftTime(), 1)

    local iOrgID = self:OrgID()
    local f = function ()
        CheckApplyLeaderSuccess(iOrgID)
        -- self:_ApplyLeaderSuccess()
    end
    self:AddTimeCb("_CheckApplyLeader", iLeftTime * 1000, f)
end

function COrg:_ApplyLeaderSuccess()
    if not self:HasApplyLeader()  then return end

    self:DelTimeCb("_CheckApplyLeader")
    local applyPid = self.m_oMemberMgr:GetApplyLeader()
    local leaderPid = self:GetLeaderID()
    local ioldPos = self:GetPosition(applyPid)
    self:RemovePosition(applyPid)
    self:RemovePosition(leaderPid)
    self:SetLeader(applyPid)
    self:SetPosition(leaderPid, ioldPos)
    self:RemoveApplyLeader()
    self:SendMail4ApplyLeaderSuccess(applyPid)
    self:GS2COrgApplyLeaderFlag()

    local oOrgMgr = global.oOrgMgr
    local sMsg = oOrgMgr:GetOrgText(1113, {role=self:GetLeaderName()})
    oOrgMgr:SendMsg2Org(self:OrgID(), sMsg)

    local sMsg = oOrgMgr:GetOrgText(1161, {role=self:GetLeaderName()})
    self:AddLog(0, sMsg)
    self:PushOrgMember2Version(applyPid, gamedefines.VERSION_OP_TYPE.UPDATE)
    self:PushOrgMember2Version(leaderPid, gamedefines.VERSION_OP_TYPE.UPDATE)
    local oApply = global.oWorldMgr:GetOnlinePlayerByPid(applyPid)
    if oApply then
        oApply:PropChange("org_pos")
    end
    local oLeader = global.oWorldMgr:GetOnlinePlayerByPid(leaderPid)
    if oLeader then
        oLeader:PropChange("org_pos") 
    end
    self:PushOrgListToVersion(true)
end

function COrg:AfterLoad()
    self:InitPlayerOrgId()
    self:_CheckApplyLeader()
    self.m_oBuildMgr:AfterLoad()
    self:CreateOrgScene()
    self.m_oApplyMgr:AfterLoad()
    self.m_oAchieveMgr:HandleEvent(orgdefines.ORG_ACH_TYPE.MEM_GRADE_CNT, {pid=self:GetLeaderID(), level=999})
    self:CreateOrgMemberVersion()
end

function COrg:InitPlayerOrgId()
    local oOrgMgr = global.oOrgMgr
    for iPid,_ in pairs(self.m_oMemberMgr:GetMemberMap()) do
        oOrgMgr:SetPlayerOrgId(iPid, self:OrgID())
    end
    for iPid,_ in pairs(self.m_oMemberMgr:GetXueTuMap()) do
        oOrgMgr:SetPlayerOrgId(iPid, self:OrgID())
    end
end

function COrg:Schedule()
    local f1
    f1 = function ()
        self:DelTimeCb("PushOrgListToVersion")
        self:AddTimeCb("PushOrgListToVersion", 3 * 60 * 1000, f1)
        self:PushOrgListToVersion()
    end
    f1()
    local f2
    f2 = function ()
        self:DelTimeCb("SycnOrgMember2Version")
        self:AddTimeCb("SycnOrgMember2Version", 3 * 60 * 1000, f2)
        self:SycnOrgMember2Version()
    end
    f2()
end

function COrg:ConfigSaveFunc()
    local id = self:OrgID()
    self:ApplySave(function ()
        local oOrgMgr = global.oOrgMgr
        local obj = oOrgMgr:GetNormalOrg(id)
        if obj then
            obj:_CheckSaveDb()
        else
            record.warning("org %d save error: no obj", id)
        end
    end)
end

function COrg:_CheckSaveDb()
    assert(not is_release(self), string.format("org %d save err: has release", self:OrgID()))
    self:SaveDb()
end

function COrg:SaveDb()
    local iOrg = self:OrgID()
    if self:IsDirty() then
        local mInfo = {
            module = "orgdb",
            cmd = "SaveOrg",
            cond = {orgid = self:OrgID()},
            data = {data = self:Save()}
        }
        gamedb.SaveDb(iOrg, "common", "DbOperate", mInfo)
        self:UnDirty()
    end

    if self.m_oBaseMgr:IsDirty() then
        local mInfo = {
            module = "orgdb",
            cmd = "SaveOrgBase",
            cond = {orgid = self:OrgID()},
            data = {data = self.m_oBaseMgr:Save()}
        }
        gamedb.SaveDb(iOrg, "common", "DbOperate", mInfo)
        self.m_oBaseMgr:UnDirty()
    end

    if self.m_oMemberMgr:IsDirty() then
        local mInfo = {
            module = "orgdb",
            cmd = "SaveOrgMember",
            cond = {orgid = self:OrgID()},
            data = {data = self.m_oMemberMgr:Save()}
        }
        gamedb.SaveDb(iOrg, "common", "DbOperate", mInfo)
        self.m_oMemberMgr:UnDirty()
    end

    if self.m_oBuildMgr:IsDirty() then
        local mInfo = {
            module = "orgdb",
            cmd = "SaveOrgBuild",
            cond = {orgid = self:OrgID()},
            data = {data = self.m_oBuildMgr:Save()}
        }
        gamedb.SaveDb(iOrg, "common", "DbOperate", mInfo)
        self.m_oBuildMgr:UnDirty()
    end

    if self.m_oLogMgr:IsDirty() then
        local mInfo = {
            module = "orgdb",
            cmd = "SaveOrgLog",
            cond = {orgid = self:OrgID()},
            data = {data = self.m_oLogMgr:Save()}
        }
        gamedb.SaveDb(iOrg, "common", "DbOperate", mInfo)
        self.m_oLogMgr:UnDirty()
    end

    if self.m_oApplyMgr:IsDirty() then
        local mInfo = {
            module = "orgdb",
            cmd = "SaveOrgApply",
            cond = {orgid = self:OrgID()},
            data = {data = self.m_oApplyMgr:Save()}
        }
        gamedb.SaveDb(iOrg, "common", "DbOperate", mInfo)
        self.m_oApplyMgr:UnDirty()
    end

    if self.m_oBoonMgr:IsDirty() then
        local mInfo = {
            module = "orgdb",
            cmd = "SaveOrgBoon",
            cond = {orgid = self:OrgID()},
            data = {data = self.m_oBoonMgr:Save()}
        }
        gamedb.SaveDb(iOrg, "common", "DbOperate", mInfo)
        self.m_oBoonMgr:UnDirty()
    end

    if self.m_oAchieveMgr:IsDirty() then
        local mInfo = {
            module = "orgdb",
            cmd = "SaveOrgAchieve",
            cond = {orgid = self:OrgID()},
            data = {data = self.m_oAchieveMgr:Save()}
        }
        gamedb.SaveDb(iOrg, "common", "DbOperate", mInfo)
        self.m_oAchieveMgr:UnDirty()
    end
end

function COrg:GetAllSaveData()
    local mData = {}
    mData.orgid = self:OrgID()
    mData.name = self:GetName()
    mData.base_info = self.m_oBaseMgr:Save()
    mData.member_info = self.m_oMemberMgr:Save()
    mData.build_info = self.m_oBuildMgr:Save()
    mData.log_info = self.m_oLogMgr:Save()
    mData.apply_info = self.m_oApplyMgr:Save()
    return mData
end

function COrg:LoadAll(data)
    if not data then
        return
    end
    self:Load(data)
    self.m_oBaseMgr:Load(data.base_info)
    self.m_oMemberMgr:Load(data.member_info)
    self.m_oBuildMgr:Load(data.build_info)
    self.m_oLogMgr:Load(data.log_info)
    self.m_oApplyMgr:Load(data.apply_info)
    self.m_oBoonMgr:Load(data.boon_info)
    self.m_oAchieveMgr:Load(data.achieve_info)
end

function COrg:Load(m)
    m = m or {}
    self:SetData("name", m.name or string.format("帮派%s", self:OrgID()))
    self:SetData("showid", m.showid)
end

function COrg:Save()
    local m = {}
    m.name = self:GetData("name")
    m.showid = self:GetData("showid")
    return m
end

function COrg:NewHour(mNow)
    local iHour = mNow.date.hour
    self:CheckClearXuetu()
    self.m_oBuildMgr:NewHour(mNow)
    if iHour == 0 then
        self:CheckStrongest()
    end
    if iHour == 5 then
        self:CheckMaintain()
        -- safe_call(self.CheckOrgApply, self)
    end
end

function COrg:CheckOrgApply()
    self.m_oApplyMgr:CheckApplyExpire()
end

function COrg:CheckMaintain()
    local iDayMorning = self.m_oBaseMgr:GetDayMorning()
    if iDayMorning >= get_morningdayno() then
        return
    end

    if self:GetMemberCnt() <= 0 and self:GetXueTuCnt() <= 0 then
        local oOrgMgr = global.oOrgMgr
        oOrgMgr:DeleteNormalOrg(self)
        return
    end 

    self:DayMaintain()
    local oOrg = global.oOrgMgr:GetNormalOrg(self:OrgID())
    if not oOrg or is_release(self) then return end

    if get_weekday() == 1 then
        local iWeekMorning = self.m_oBaseMgr:GetWeekMorning()
        if iWeekMorning >= get_morningweekno() then
            return
        end
        self:WeekMaintain()
    end
    safe_call(self.CheckOrgApply, self)
end

-- 5点维护，增加繁荣度等
function COrg:DayMaintain()
    self.m_oBaseMgr:SetDayMorning()

    local sub_formula = res["daobiao"]["org"]["others"][1]["fan_hua_down_formula"]
    local iSubBoom = formula_string(sub_formula, {org_lv=self:GetLevel()})
    self:AddBoom(-math.floor(iSubBoom))

    local add_formula = res["daobiao"]["org"]["others"][1]["fan_hua_up_formula"]
    local iAddBoom = formula_string(add_formula, {yes_huoyu=self:GetDayTotHuoYue()})
    self:AddBoom(math.floor(iAddBoom))
    self.m_oMemberMgr:ClearDayHuoYue()

    -- 维护消耗
    local maintain_formula = res["daobiao"]["org"]["others"][1]["daily_maintain_consume"]
    local iSubCash = formula_string(maintain_formula, {org_lv=self:GetLevel()})
    self:AddCash(-iSubCash)

    -- 记录荒芜天数
    if self:GetBoom() < 200 then
        self.m_oBaseMgr:AddHwDay(1)
        local iDayCnt = self.m_oBaseMgr:GetHwDay()
        self:SendMail4KeepHwDay(iDayCnt)
        if iDayCnt >= 21 then
            local oOrgMgr = global.oOrgMgr
            oOrgMgr:DismissNormalOrg(self:OrgID())
            return
        end
    else
        self.m_oBaseMgr:ClearHwDay()
    end

    self.m_oAchieveMgr:HandleEvent(orgdefines.ORG_ACH_TYPE.BOOM_VAL, {iVal=self:GetBoom()})
    self.m_oAchieveMgr:HandleEvent(orgdefines.ORG_ACH_TYPE.BOOM_MORE_DAY, {iBoom=self:GetBoom()})

    -- 刷新精英
    self:CheckElite()
    self:CheckXueTu2Mem()

    -- 记录此刻的帮派等级
    self.m_oBoonMgr:SetDayOrgLevel(self:GetLevel())
    local iShopStatus = self.m_oBuildMgr:GetShopStatus(self:GetLeaderID())
    self:SendOrgFlagInfo({sign_status=0,shop_status=iShopStatus})

    -- 记录log
    local mLog = self:LogData()
    mLog["sub_boom"] = iSubBoom
    mLog["add_boom"] = iAddBoom
    mLog["sub_cash"] = iSubCash
    mLog["now_boom"] = self:GetBoom()
    mLog["now_cash"] = self:GetCash()
    record.log_db("org", "new_day_log", mLog)
end

function COrg:WeekMaintain()
    self:WeekBoonMaintain()
    self:WeekPrestigeMaintain()
    self:SendOrgFlagInfo({bonus_status=0})
    self:SendOrgFlagInfo({pos_status=0}, self:GetManagerMember())
end

function COrg:WeekBoonMaintain()
    -- 福利相关的数据
    self.m_oBoonMgr:WeekMaintain()

    self.m_oBaseMgr:WeekMaintain()
    self.m_oMemberMgr:ClearWeekHuoYue()
end

function COrg:WeekPrestigeMaintain()
    local sub_formula = res["daobiao"]["org"]["others"][1]["week_prestige"]
    local iSub = math.floor(formula_string(sub_formula, {prestige=self:GetPrestige()})) 
    if iSub > 0 then
        local sMsg = global.oOrgMgr:GetOrgText(1171, {amount=iSub})
        self:AddPrestige(-iSub, "周结算", {chat_msg=sMsg})
    end  
end

-- 周一0点刷新客卿职位
function COrg:CheckStrongest()
    if get_weekday() == 1 then
        -- TODO
    end
end

-- 执剑使
function COrg:CheckMostPoint()
    -- TODO
end

-- 每天5点刷新精英
function COrg:CheckElite()
    local iCnt = 0
    local lElite = self.m_oMemberMgr:GetElite()

    local oWorldMgr = global.oWorldMgr
    local oOrgMgr = global.oOrgMgr
    self.m_oMemberMgr:ClearElite()
    for i,v in ipairs(self.m_oMemberMgr:GetHisOfferMemList()) do
        local iPid = v[1]
        local oMem = self.m_oMemberMgr:GetMember(iPid)
        if oMem then
            iCnt = iCnt + 1
            self.m_oMemberMgr:SetElite(iPid)
            if not table_in_list(lElite, iPid) then
                local sMsg = oOrgMgr:GetOrgText(1115, {role=oMem:GetName()})
                oOrgMgr:SendMsg2Org(self:OrgID(), sMsg)
                local sMsg = oOrgMgr:GetOrgText(1160, {role=oMem:GetName()})
                self:AddLog(0, sMsg)

                local oPlayer = oWorldMgr:GetOnlinePlayerByPid(iPid)
                if oPlayer then
                    self:CheckEliteTitle(oPlayer)
                end
            end
        end

        if iCnt >= self:GetEliteMaxNum() then
            break
        end
    end

    for _, iPid in ipairs(lElite) do
        if not self.m_oMemberMgr:IsElite(iPid) then
            local oPlayer = oWorldMgr:GetOnlinePlayerByPid(iPid)
            if oPlayer then
                self:CheckEliteTitle(oPlayer)
            end
        end
    end
end

-- 自动清理：2天内没有上线，自动清理
function COrg:CheckClearXuetu()
    local iOrgId = self:OrgID()
    for iPid,oXueTu in pairs(self.m_oMemberMgr:GetXueTuMap()) do
        local lastOutTime = oXueTu:GetOnlineTime()
        if lastOutTime > 0 and get_time() - lastOutTime > orgdefines.ORG_DEL_XUETU_TIME then
            -- self.m_oMemberMgr:RemoveXueTu(iPid)
            global.oOrgMgr:LeaveOrg(iPid, iOrgId, "自动清理学徒")
            global.oOrgMgr:SendMail2Player(iPid, 3017)
        end
    end
end

function COrg:GetEliteMaxNum()
    local mData = res["daobiao"]["org"]["positionlimit"][self:GetLevel()]
    return mData["jingying"]
end

function COrg:OrgID()
    return self.m_iID
end

function COrg:ShowID()
    return self:GetData("showid", self:OrgID())
end

function COrg:GetName()
    return self:GetData("name")
end

function COrg:GetAim()
    return self.m_oBaseMgr:GetAim()
end

function COrg:SetAim(aim)
    self.m_oBaseMgr:SetAim(aim)
end

function COrg:GetSetAimCD()
    local iCD = global.oOrgMgr:GetOtherConfig("aim_cd") * 3600
    local iTime = self.m_oBaseMgr:GetAimTime()
    return math.max(0, iTime + iCD - get_time())
end

function COrg:GetSetMailCD()
    local iCD = global.oOrgMgr:GetOtherConfig("mail_cd") * 3600
    local iTime = self.m_oBaseMgr:GetMailTime()
    return math.max(0, iTime + iCD - get_time())
end

function COrg:AddCash(iVal, iPid)
    if iVal > 0 then
        local iAddCash = math.min(iVal, self:GetMaxCash() - self:GetCash())
        local sMsg
        local oOrgMgr = global.oOrgMgr
        if iAddCash > 0 then
            self.m_oBaseMgr:AddCash(iAddCash)
            self.m_oAchieveMgr:HandleEvent(orgdefines.ORG_ACH_TYPE.CASH_CNT, {iVal=iAddCash})
            self.m_oBoonMgr:AddCash(iPid, iVal)
        end
        if iAddCash < iVal then
            sMsg = oOrgMgr:GetOrgText(1121)
            if self.m_bNotiyMaxCash then
                self.m_bNotiyMaxCash = false
                oOrgMgr:SendMsg2Org(self:OrgID(), oOrgMgr:GetOrgText(1120))
            end     
        end
        local oWorldMgr = global.oWorldMgr
        local oPlayer = oWorldMgr:GetOnlinePlayerByPid(iPid)
        if sMsg and oPlayer then
            oPlayer:NotifyMessage(sMsg)
        end
    else
        self.m_oBaseMgr:AddCash(iVal)
        self.m_bNotiyMaxCash = true
    end
end

function COrg:GetMaxCash()
    local iNum = res["daobiao"]["org"]["others"][1]["init_cash"]
    return iNum + self.m_oBuildMgr:GetMaxCash()
end

function COrg:GetPrestige()
    return self.m_oBaseMgr:GetPrestige()
end

function COrg:RewardPrestigeByPlayer(iPid, iVal, sReason, mArgs)
    self:AddPrestige(iVal, sReason, mArgs)
    local oPlayer = global.oWorldMgr:GetOnlinePlayerByPid(iPid)
    if oPlayer then
        oPlayer:NotifyMessage(global.oOrgMgr:GetOrgText(1167, {amount=iVal}))
    end
end

function COrg:AddPrestige(iVal, sReason, mArgs)
    self.m_oBaseMgr:AddPrestige(iVal)
    if mArgs and mArgs.chat_msg then
        global.oOrgMgr:SendMsg2Org(self:OrgID(), mArgs.chat_msg)
    end
    global.oRankMgr:PushDataToOrgPrestige(self)
end

function COrg:AddBoom(iVal)
    self.m_oBaseMgr:AddBoom(iVal)
end

function COrg:GetLevel()
    return self.m_oBuildMgr:GetBuildHomeLevel() or 1
end

function COrg:GetMemIdsByPosition(iPos)
    return self.m_oMemberMgr:GetMemIdsByPosition(iPos)
end

function COrg:GetMemIdsByHonor(iHonor)
    return self.m_oMemberMgr:GetMemIdsByHonor(iHonor)
end

function COrg:GetChatStatus(iPid)
    local oMem = self:GetMemberFromAll(iPid)
    if oMem and oMem:IsChatBan() then
        return 1
    end
    return 0
end

function COrg:GetLeaderID()
    return self.m_oMemberMgr:GetLeader()
end

function COrg:IsLeader(pid)
    return self.m_oMemberMgr:IsLeader(pid)
end

function COrg:SetLeader(pid)
    self.m_oMemberMgr:SetLeader(pid)
    self:CheckPositionTitle(pid)
    global.oRankMgr:PushDataToMengzhuOrg(self)
    global.oRankMgr:PushDataToOrgPrestige(self)
end

function COrg:GetLeader()
    return self.m_oMemberMgr:GetMember(self:GetLeaderID())
end

function COrg:GetLeaderName()
    local iLeader = self:GetLeaderID()
    local oMemInfo = self.m_oMemberMgr:GetMember(iLeader)
    return oMemInfo:GetName()
end

function COrg:GetLeaderSchool()
    local iLeader = self:GetLeaderID()
    local oMemInfo = self.m_oMemberMgr:GetMember(iLeader)
    return oMemInfo:GetSchool()
end

function COrg:AddApply(oPlayer, iType)
    if not oPlayer then return end

    local oOrgMgr = global.oOrgMgr
    if self:IsAutoJoinXT() and oOrgMgr:IsBeXueTu(oPlayer:GetGrade()) then
        local iFlag = oOrgMgr:AddForceMember(self:OrgID(), oPlayer)
        if iFlag then return end
    end

    self.m_oApplyMgr:AddApply(oPlayer, iType)
    oOrgMgr:AddPlayerApply(oPlayer:GetPid(), self:OrgID())
    if self.m_oApplyMgr:GetApplyCnt() == 1 then
        self:GS2COrgApplyFlag()
    end
end

function COrg:GetApplyCnt()
    return self.m_oApplyMgr:GetApplyCnt()
end

function COrg:RemoveApply(pid)
    self.m_oApplyMgr:RemoveApply(pid)
    global.oOrgMgr:RemovePlayerApply(pid, self:OrgID())
    if self.m_oApplyMgr:GetApplyCnt() == 0 then
        self:GS2COrgApplyFlag()
    end
end

function COrg:GetApplyInfo(pid)
    return self.m_oApplyMgr:GetApplyInfo(pid)
end

function COrg:GetApplyListInfo()
    return self.m_oApplyMgr:GetApplyListInfo()
end

function COrg:HasApply(pid)
    if self.m_oApplyMgr:GetApplyInfo(pid) then
        return 1
    else
        return 0
    end
end

-- function COrg:AcceptMember(pid)
--     local meminfo = self.m_oApplyMgr:GetApplyInfo(pid)
--     self:AddMember(meminfo)
--     self:RemoveApply(pid)
-- end

function COrg:AcceptMember(oMemInfo)
    local oOrgMgr = global.oOrgMgr 
    if oOrgMgr:GetPlayerOrgId(oMemInfo:GetPid()) then
        return false
    end

    if not oOrgMgr:IsBeXueTu(oMemInfo:GetGrade()) and self:GetMemberCnt() < self:GetMaxMemberCnt() then
        self:AddMember(oMemInfo)
        -- self:CheckPositionTitle(oMemInfo:GetPid())
        self:RemoveApply(oMemInfo:GetPid())
        self:PushOrgListToVersion(true)
        return true
    end
    if self:GetXueTuCnt() < self:GetMaxXuetuCnt() then
        self:AddXueTu(oMemInfo)
        -- self:CheckPositionTitle(oMemInfo:GetPid())
        self:RemoveApply(oMemInfo:GetPid())
        self:PushOrgListToVersion(true)
        if self:GetXueTuCnt() >= self:GetMaxXuetuCnt() then
            self.m_oBaseMgr:SetData("auto_join", 0)
        end
        return true
    end
    return false
end

function COrg:IsXueTu2Mem(oXueTu)
    if not oXueTu then return end

    if oXueTu:GetGrade() < 45 then
        return false
    end
    if self:GetHisOffer(oXueTu:GetPid()) < 100 then
        return false
    end
    return true
end

function COrg:AddMember(oMemInfo)
    self.m_oMemberMgr:AddMember(oMemInfo)
    self.m_oAchieveMgr:HandleEvent(orgdefines.ORG_ACH_TYPE.MEMBER_CNT, {iVal=self:GetMemberCnt()})
    self.m_oAchieveMgr:HandleEvent(orgdefines.ORG_ACH_TYPE.MEM_GRADE_CNT, 
        {pid=oMemInfo:GetPid(), level=oMemInfo:GetGrade()})
end

function COrg:OnAddMember(oMemInfo, bXueTu)
    local oHuodong = global.oHuodongMgr:GetHuodong("kaifudianli")
    if oHuodong then
        oHuodong:OnOrgCnt(self)
    end
end

function COrg:RemoveMember(pid)
    if self:IsMember(pid) then
        self.m_oMemberMgr:RemoveMember(pid)
    end
    if self:IsXueTu(pid) then
        self.m_oMemberMgr:RemoveXueTu(pid)
    end

    local oOrgMgr = global.oOrgMgr
    oOrgMgr:SetPlayerOrgId(pid, nil)
    self:OnRemoveMember(pid)
    self:PushOrgListToVersion(true)
end

function COrg:OnRemoveMember(iPid)
    local oHuodongMgr = global.oHuodongMgr
    local oMengzhu = oHuodongMgr:GetHuodong("mengzhu")
    if oMengzhu then
        oMengzhu:OnLeaveOrg(self, iPid)
    end
    local oOrgTask = oHuodongMgr:GetHuodong("orgtask")
    if oOrgTask then
        oOrgTask:OnLeaveOrg(self, iPid)
    end
end

function COrg:GetMemberFromAll(iPid)
    local oMem = self:GetMember(iPid)
    if not oMem then
        oMem = self:GetXueTu(iPid)
    end 
    return oMem
end

function COrg:IsMember(pid)
    if self:GetMember(pid) then return true end

    return false
end

function COrg:GetMember(pid)
    return self.m_oMemberMgr:GetMember(pid)
end

function COrg:AddXueTu(oMemInfo)
    self.m_oMemberMgr:AddXueTu(oMemInfo)
end

function COrg:IsXueTu(pid)
    if self:GetXueTu(pid) then return true end

    return false
end

function COrg:GetXueTu(pid)
    return self.m_oMemberMgr:GetXueTu(pid)
end

function COrg:GetMemberCnt()
    return self.m_oMemberMgr:GetMemberCnt() + self:GetTest("membercnt", 0)
end

function COrg:GetMaxMemberCnt()
    local mData = res["daobiao"]["org"]["positionlimit"][self:GetLevel()]
    return mData["formal"] + self.m_oBuildMgr:GetMemberCnt()
end

function COrg:GetOnlineMemberCnt()
     return self.m_oMemberMgr:GetOnlineMemberCnt()
 end

function COrg:GetXueTuCnt()
    return self.m_oMemberMgr:GetXueTuCnt() + self:GetTest("xuetucnt", 0)
end

function COrg:GetMaxXuetuCnt()
    local mData = res["daobiao"]["org"]["positionlimit"][self:GetLevel()]
    return mData["xuetu"] + self.m_oBuildMgr:GetXueTuCnt()
end

function COrg:GetOnlineXuetuCnt()
    return self.m_oMemberMgr:GetOnlineXuetuCnt()
end

function COrg:GetCash()
    return self.m_oBaseMgr:GetCash()
end

function COrg:GetBoom()
    return self.m_oBaseMgr:GetBoom()
end

function COrg:GetLastWeekHuoYue()
    return self.m_oBaseMgr:GetLastWeekHuoYue()
end

function COrg:SyncMemberData(pid, mData)
    self.m_oMemberMgr:SyncMemberData(pid, mData)
    local grade = mData["grade"]
    if grade then
        self.m_oAchieveMgr:HandleEvent(orgdefines.ORG_ACH_TYPE.MEM_GRADE_CNT, {pid=pid, level=grade})
    end
    if mData.name and self:GetLeaderID() == pid then
        -- global.oOrgMgr:UpdateCacheInfo(self, pid)
        self:PushOrgListToVersion(true)
        global.oRankMgr:PushDataToOrgPrestige(self)
    end
    if mData["logout_time"] then
        self:PushOrgMember2Version(pid, gamedefines.VERSION_OP_TYPE.UPDATE, true)
    else
        self:PushOrgMember2Version(pid, gamedefines.VERSION_OP_TYPE.UPDATE)
    end
end

function COrg:SyncApplyData(iPid, mData)
    self.m_oApplyMgr:SyncApplyData(iPid, mData)
end

function COrg:SetPosition(pid, iPos)
    self.m_oMemberMgr:SetPosition(pid, iPos)
    local oWorldMgr = global.oWorldMgr
    local oPlayer = oWorldMgr:GetOnlinePlayerByPid(pid)
    if oPlayer then
        self:GS2COrgFlagInfo(oPlayer)
        self:CheckPositionTitle(pid)
    end
end

function COrg:RemovePosition(pid)
    self.m_oMemberMgr:RemovePostion(pid)
end

function COrg:GetPositionCnt(iPos)
    return self.m_oMemberMgr:GetPositionCnt(iPos)
end

function COrg:GetPosMaxCnt(iPos)
    local mData = res["daobiao"]["org"]["positionlimit"][self:GetLevel()]
    if iPos == orgdefines.ORG_POSITION.LEADER then
        return mData["leader"]
    elseif iPos == orgdefines.ORG_POSITION.DEPUTY then
        return mData["viceleader"]
    elseif iPos == orgdefines.ORG_POSITION.ELDER then
        return mData["elder"]
    elseif iPos == orgdefines.ORG_POSITION.CARTER then
        return mData["chefu"]
    elseif iPos == orgdefines.ORG_POSITION.FAIRY then
        return mData["baby"]
    elseif iPos == orgdefines.ORG_POSITION.XUETU then
        return mData["xuetu"]
    elseif iPos == orgdefines.ORG_POSITION.MEMBER then
        return mData["formal"]
    end
    return  0
end

function COrg:GetPosition(iPid)
    return self.m_oMemberMgr:GetPosition(iPid)
end

function COrg:GetOrgHonor(iPid)
    return self.m_oMemberMgr:GetOrgHonor(iPid)
end

function COrg:AddMemberHuoYue(iPid, iHuoYue)
    self.m_oMemberMgr:AddMemberHuoYue(iPid, iHuoYue)
    self.m_oBaseMgr:AddHuoYue(iHuoYue)
    self.m_oBoonMgr:AddHuoYue(iPid, iHuoYue)
    self:PushOrgMember2Version(iPid, gamedefines.VERSION_OP_TYPE.UPDATE)
end

function COrg:GetDayTotHuoYue()
    return self.m_oMemberMgr:GetDayTotHuoYue()
end

function COrg:AddOrgOffer(iPid, iOffer)
    self.m_oMemberMgr:AddHisOffer(iPid, iOffer)
    self:PushOrgMember2Version(iPid, gamedefines.VERSION_OP_TYPE.UPDATE)
end

function COrg:GetHisOffer(iPid)
    return self.m_oMemberMgr:GetHisOffer(iPid)
end

function COrg:PackOrgListInfo()
    local mNet = {}
    mNet.orgid = self:OrgID()
    mNet.showid = self:ShowID()
    mNet.name = self:GetName()
    mNet.level = self:GetLevel()
    mNet.leaderschool = self:GetLeaderSchool()
    mNet.leaderid = self:GetLeaderID()
    mNet.leadername = self:GetLeaderName()
    mNet.memcnt = self:GetMemberCnt()
    mNet.maxcnt = self:GetMaxMemberCnt()
    return mNet
end

function COrg:PackOrgMainInfo(iPid)
    local mNet = self:PackOrgSampleInfo(iPid)
    mNet.aim = self:GetAim()
    mNet.historys = self.m_oLogMgr:PackHistoryListInfo()
    mNet.info = self.m_oMemberMgr:PackSampleMemInfo(iPid)
    local oPlayer = global.oWorldMgr:GetOnlinePlayerByPid(iPid)
    if oPlayer then
        mNet.left_mail_cnt = self:GetLeftMailCnt(oPlayer)
    end
    return mNet
end

function COrg:PackMaskOrgMainInfo(mNet)
    mNet = net.Mask("GS2COrgMainInfo", mNet)
    return mNet
end

function COrg:ChangeOrgMainInfo(oPlayer, m)
    local mNet = net.Mask("GS2COrgMainInfo", m)
    oPlayer:Send("GS2COrgMainInfo", mNet)
end

function COrg:PackOrgSampleInfo(iPid)
    local mNet = {}
    mNet.orgid = self:OrgID()
    mNet.showid = self:ShowID()
    mNet.name = self:GetName()
    mNet.level = self:GetLevel()
    mNet.leaderid = self:GetLeaderID()
    mNet.leadername = self:GetLeaderName()
    mNet.leaderschool = self:GetLeaderSchool()
    mNet.membercnt = self:GetMemberCnt()
    mNet.maxmembercnt = self:GetMaxMemberCnt()
    mNet.onlinemem = self:GetOnlineMemberCnt()
    mNet.xuetucnt = self:GetXueTuCnt()
    mNet.maxxuetucnt = self:GetMaxXuetuCnt()
    mNet.onlinexuetu = self:GetOnlineXuetuCnt()
    mNet.cash = self:GetCash()
    mNet.boom = self:GetBoom()
    if self:HasApplyLeader() then
        mNet.applypid = self:GetApplyLeader()
        mNet.applyname = self.m_oMemberMgr:GetApplyLeaderName()
        mNet.applyschool = self.m_oMemberMgr:GetApplyLeaderSchool()
        mNet.applylefttime = self.m_oMemberMgr:GetApplyLeftTime()
    else
        -- 给默认值
        mNet.applypid = 0
        mNet.applyname = nil
        mNet.applyschool = 0
        mNet.applylefttime = 0
    end
    mNet.canapplyleader = self:CanApplyLeader(iPid)
    mNet.left_mail_cd = self:GetSetMailCD()
    mNet.left_aim_cd = self:GetSetAimCD()
    return mNet
end

function COrg:PackApplyLeaderInfo(iPid)
    local mNet = {}
    if self:HasApplyLeader() then
        mNet.applypid = self:GetApplyLeader()
        mNet.applyname = self.m_oMemberMgr:GetApplyLeaderName()
        mNet.applyschool = self.m_oMemberMgr:GetApplyLeaderSchool()
        mNet.applylefttime = self.m_oMemberMgr:GetApplyLeftTime()
    end
    mNet.canapplyleader = self:CanApplyLeader(iPid)
    return mNet
end

function COrg:CanApplyLeader(iPid)
    if self:HasApplyLeader() or self:IsXueTu(iPid) then
        return 0
    end
    local iLeader = self:GetLeaderID()
    local oMem = self.m_oMemberMgr:GetMember(iLeader)
    local lastOutTime = oMem:GetOnlineTime()
    local iTime = res["daobiao"]["org"]["others"][1]["leader_offline_time"]
    if lastOutTime > 0 and get_time() - lastOutTime > iTime then
        return 1
    end
    return 0
end

function COrg:PackOrgMemList(pid)
    return self.m_oMemberMgr:PackOrgMemList()
end

function COrg:PackOrgApplyInfo()
    return self.m_oApplyMgr:PackApplyInfo()
end

function COrg:HasApplyLeader()
    local pid = self:GetApplyLeader()
    if pid and pid ~= 0 then
        return true
    end
    return false
end

function COrg:GetApplyLeader()
    return self.m_oMemberMgr:GetApplyLeader()
end

function COrg:ApplyLeader(pid)
   self.m_oMemberMgr:ApplyLeader(pid)
   self:_CheckApplyLeader()
   self:GS2COrgApplyLeaderFlag()
end

function COrg:RemoveApplyLeader()
    self.m_oMemberMgr:RemoveApplyLeader()
    self:DelTimeCb("_CheckApplyLeader")
end

-- function COrg:AgreeApplyLeader(pid)
--     self.m_oMemberMgr:AgreeApplyLeader(pid)
-- end

-- function COrg:HasAgreeLeader(pid)
--     self.m_oMemberMgr:HasAgree(pid)
-- end

function COrg:HasDealJoinAuth(iPid)
    local position = self:GetPosition(iPid)
    local mData = res["daobiao"]["org"]["positionauthority"][position]
    if not mData then return false end

    return mData["agree_reject_join"] == 1
end

function COrg:HasKickAuth(iPid, iKickPid)
    local position = self:GetPosition(iPid)
    local iPos = self:GetPosition(iKickPid)
    local mData = res["daobiao"]["org"]["positionauthority"][position]
    if not mData then return false end

    local ret = extend.Array.find(mData["del_pos"], iPos)
    if not ret then return false end

    return  true
end

function COrg:HasBanChatAuth(iPid, iBanPid)
    local position = self:GetPosition(iPid)
    local iPos = self:GetPosition(iBanPid)
    local mData = res["daobiao"]["org"]["positionauthority"][position]
    if not mData then return false end

    local ret = extend.Array.find(mData["ban_talk"], iPos)
    if not ret then return false end

    return  true
end

function COrg:HasUpdateAimAuth(iPid)
    local position = self:GetPosition(iPid)
    local mData = res["daobiao"]["org"]["positionauthority"][position]
    if not mData then return false end

    return mData["edit_aim"] == 1
end

function COrg:HasSetPosAuth(iPid, iPos)
    local position = self:GetPosition(iPid)
    local mData = res["daobiao"]["org"]["positionauthority"][position]
    if not mData then return false end

    if position >= iPos then return false end

    local ret = extend.Array.find(mData["authorize_pos"], iPos)
    if not ret then return false end

    return  true
end

function COrg:HasXueTu2MemAuth(iPid)
    local position = self:GetPosition(iPid)
    local mData = res["daobiao"]["org"]["positionauthority"][position]
    if not mData then return false end

    return mData["to_formal"] == 1
end

function COrg:HasUpGradeBuildAuth(iPid)
    local position = self:GetPosition(iPid)
    local mData = res["daobiao"]["org"]["positionauthority"][position]
    if not mData then return false end

    return mData["upgrade_building"] == 1
end

function COrg:HasSetAutoJoinAuth(iPid)
    local position = self:GetPosition(iPid)
    local mData = res["daobiao"]["org"]["positionauthority"][position]
    if not mData then return false end

    return mData["set_auto_join"] == 1 
end

function COrg:HasDelApplyListAuth(iPid)
    local position = self:GetPosition(iPid)
    local mData = res["daobiao"]["org"]["positionauthority"][position]
    if not mData then return false end

    return mData["clear_apply_list"] == 1 
end

function COrg:HasSendMailAuth(iPid)
    local position = self:GetPosition(iPid)
    local mData = res["daobiao"]["org"]["positionauthority"][position]
    if not mData then return false end

    return mData["send_mail"] == 1 
end

function COrg:CheckXueTu2Mem()
    for _, v in pairs(self.m_oMemberMgr:GetXueTuSortMap()) do
        if self:GetMemberCnt() >= self:GetMaxMemberCnt() then
            break
        end
        local oXueTu = self.m_oMemberMgr:GetXueTu(v[1])
        if self:IsXueTu2Mem(oXueTu) then
            self:ChangeXueTu2Mem(v[1])
        end
    end
end

function COrg:ChangeXueTu2Mem(iPid)
    if self:GetMemberCnt()  < self:GetMaxMemberCnt() then
        local mLog = self:LogData()
        mLog["pid"] = iPid
        record.log_db("org", "xuetu_to_member", mLog)

        local oXueTu = self:GetXueTu(iPid)
        self.m_oMemberMgr:ChangeXueTu2Mem(iPid)
        self.m_oAchieveMgr:HandleEvent(orgdefines.ORG_ACH_TYPE.MEMBER_CNT, {iVal=self:GetMemberCnt()})
        self:PushOrgMember2Version(iPid, gamedefines.VERSION_OP_TYPE.UPDATE)
        self:CheckPositionTitle(iPid)
        self:PushOrgListToVersion(true)
        self:OnAddMember(oXueTu, true)
        global.oTitleMgr:OnChangeOrgPos(iPid)
        local oPlayer = global.oWorldMgr:GetOnlinePlayerByPid(iPid)
        if oPlayer then
            oPlayer:PropChange("org_pos")
        end
    end
end

function COrg:SendMail4ChangeLeader(iOldPid, iNewPid)
    local oldMem = self.m_oMemberMgr:GetMember(iOldPid)
    local newMem = self.m_oMemberMgr:GetMember(iNewPid)
    if not oldMem or not newMem then return end

    local oMailMgr = global.oMailMgr
    local mData, name = oMailMgr:GetMailInfo(3001)
    if not mData then return end

    local mInfo = table_copy(mData)
    local oToolMgr = global.oToolMgr
    mInfo.context = oToolMgr:FormatColorString(mInfo.context, {ybzname=oldMem:GetName(), jczname=newMem:GetName()})
    for pid,_ in pairs(self.m_oMemberMgr:GetMemberMap()) do
        oMailMgr:SendMail(0, name, pid, mInfo, 0)
    end
end

function COrg:SendMail4ApplyLeader(iOldPid, iApplyPid)

    local oldMem = self.m_oMemberMgr:GetMember(iOldPid)
    local newMem = self.m_oMemberMgr:GetMember(iApplyPid)
    if not oldMem or not newMem then return end

    local oMailMgr = global.oMailMgr
    local mData, name = oMailMgr:GetMailInfo(3002)
    if not mData then return end

    local mInfo = table_copy(mData)
    local oToolMgr = global.oToolMgr
    mInfo.context = oToolMgr:FormatColorString(mInfo.context, {ybzname=oldMem:GetName(), zjzname=newMem:GetName()})
    for pid,_ in pairs(self.m_oMemberMgr:GetMemberMap()) do
        oMailMgr:SendMail(0, name, pid, mInfo, 0)
    end
end

function COrg:SendMail4ApplyLeaderFail(iApplyPid)
    local oMem = self.m_oMemberMgr:GetMember(iApplyPid)
    if not oMem then return end

    local oMailMgr = global.oMailMgr
    local mData, name = oMailMgr:GetMailInfo(3003)
    if not mData then return end

    local mInfo = table_copy(mData)
    local oToolMgr = global.oToolMgr
    mInfo.context = oToolMgr:FormatColorString(mInfo.context, {zjzname=oMem:GetName()})
    for pid,_ in pairs(self.m_oMemberMgr:GetMemberMap()) do
        oMailMgr:SendMail(0, name, pid, mInfo, 0)
    end
end

function COrg:SendMail4ApplyLeaderSuccess(iApplyPid)
    local oMem = self.m_oMemberMgr:GetMember(iApplyPid)
    if not oMem then return end

    local oMailMgr = global.oMailMgr
    local mData, name = oMailMgr:GetMailInfo(3004)
    if not mData then return end

    local mInfo = table_copy(mData)
    local oToolMgr = global.oToolMgr
    mInfo.context = oToolMgr:FormatColorString(mInfo.context, {zjzname=oMem:GetName()})
    for pid,_ in pairs(self.m_oMemberMgr:GetMemberMap()) do
        oMailMgr:SendMail(0, name, pid, mInfo, 0)
    end
end

function COrg:SendMail4GotStrongest(iPid)
    local oMem = self.m_oMemberMgr:GetMember(iPid)
    if not oMem then return end

    local oMailMgr = global.oMailMgr
    local mData, name = oMailMgr:GetMailInfo(3005)
    if not mData then return end

    local mInfo = table_copy(mData)
    local oToolMgr = global.oToolMgr
    mInfo.context = oToolMgr:FormatColorString(mInfo.context, {kqhdzname=oMem:GetName()})
    for pid,_ in pairs(self.m_oMemberMgr:GetMemberMap()) do
        oMailMgr:SendMail(0, name, pid, mInfo, 0)
    end
end

function COrg:SendMail4GotMostPoint(iPid)
    local oMem = self.m_oMemberMgr:GetMember(iPid)
    if not oMem then return end

    local oMailMgr = global.oMailMgr
    local mData, name = oMailMgr:GetMailInfo(3006)
    if not mData then return end

    local mInfo = table_copy(mData)
    local oToolMgr = global.oToolMgr
    mInfo.context = oToolMgr:FormatColorString(mInfo.context, {kqhdzname=oMem:GetName()})
    for pid,_ in pairs(self.m_oMemberMgr:GetMemberMap()) do
        oMailMgr:SendMail(0, name, pid, mInfo, 0)
    end
end

function COrg:SendMail4KeepHwDay(iDay)
    local mMail = {[7]=3012, [14]=3013}
    local iMail = mMail[iDay]
    if not iMail then return end

    local oMailMgr = global.oMailMgr
    local mData, name = oMailMgr:GetMailInfo(iMail)
    if not mData then return end
    oMailMgr:SendMail(0, name, self:GetLeaderID(), mData, 0)
end

function COrg:SendMail4DismissOrg()
    local oMailMgr = global.oMailMgr
    local mData, name = oMailMgr:GetMailInfo(3014)
    if not mData then return end

    for iPid,_ in pairs(self.m_oMemberMgr:GetMemberMap()) do
        oMailMgr:SendMail(0, name, iPid, mData, 0)
    end
end

function COrg:GetRecommendFriend(iPid, iGrade, iMaxCnt, mExclude)
    local iCnt = 0
    local mRecommend = {}
    for pid, oMember in pairs(self.m_oMemberMgr:GetMemberMap()) do
        if iCnt >= iMaxCnt then break end

        if pid ~= iPid and not mExclude[pid] and math.abs(oMember:GetGrade() - iGrade) < 5 then
            mRecommend[pid] = true
            iCnt = iCnt + 1
        end
    end
    for pid, oXueTu in pairs(self.m_oMemberMgr:GetXueTuMap()) do
        if iCnt >= iMaxCnt then break end

        if pid ~= iPid and not mExclude[pid] and math.abs(oXueTu:GetGrade() - iGrade) < 5 then
            mRecommend[pid] = true
            iCnt = iCnt + 1
        end
    end
    return mRecommend
end

function COrg:AddLog(iPid, sMsg)
    -- if not self:IsMember(iPid) and not self:IsXueTu(iPid) then
    --     return
    -- end
    self.m_oLogMgr:AddHistory(iPid, sMsg)
end

function COrg:GetManagerMember()
    local lPos = {orgdefines.ORG_POSITION.LEADER, orgdefines.ORG_POSITION.DEPUTY, orgdefines.ORG_POSITION.ELDER}
    local lMemID = self.m_oMemberMgr:GetMemIdsBylPos(lPos)

    local mTarget = {}
    for _,iMid in ipairs(lMemID) do
        mTarget[iMid] = true
    end
    return mTarget
end

function COrg:PackOrgFlag(m)
    local mNet = {}
    mNet.info = net.Mask("OrgFlagInfo", m)
    return mNet
end

function COrg:SendOrgFlagInfo(m, mTarget)
    local oNotifyMgr = global.oNotifyMgr
    if mTarget then
        oNotifyMgr:SendOrgFlag2Targets(self:OrgID(), self:PackOrgFlag(m), mTarget)
    else
        oNotifyMgr:SendOrgFlag(self:OrgID(), self:PackOrgFlag(m))
    end
end

function COrg:GS2COrgApplyLeaderFlag()
    local oNotifyMgr = global.oNotifyMgr
    local mNet = self:PackOrgFlag({apply_leader_pid = self:GetApplyLeader()})
    oNotifyMgr:SendOrgFlag(self:OrgID(), mNet)
end

function COrg:GS2COrgApplyFlag()
    local mNet = {}
    if self.m_oApplyMgr:GetApplyCnt() > 0 then
        mNet.has_apply = 1
    else
        mNet.has_apply = 0
    end
    local mTarget = self:GetManagerMember()
    local oNotifyMgr = global.oNotifyMgr
    oNotifyMgr:SendOrgFlag2Targets(self:OrgID(), self:PackOrgFlag(mNet), mTarget)
end

function COrg:GS2COrgFlagInfo(oPlayer)
    local has_apply = 0
    if self:GetApplyCnt() > 0  and self:HasDealJoinAuth(oPlayer:GetPid()) then
        has_apply = 1
    end

    local mNet = {}
    mNet.has_apply = has_apply
    mNet.apply_leader_pid = self:GetApplyLeader()
    mNet.sign_status = self.m_oBoonMgr:GetSignStatus(oPlayer)
    mNet.bonus_status = self.m_oBoonMgr:GetBonusStatus(oPlayer:GetPid())
    mNet.pos_status = self.m_oBoonMgr:GetPosBonusStatus(oPlayer:GetPid())
    mNet.shop_status = self.m_oBuildMgr:GetShopStatus(oPlayer:GetPid())
    oPlayer:Send("GS2COrgFlag", self:PackOrgFlag(mNet))
end

function COrg:GS2COrgInitFlagInfo(oPlayer)
    local mNet = {}
    mNet.has_apply = 0
    mNet.apply_leader_pid = 0
    mNet.sign_status = 0
    mNet.bonus_status = 0
    mNet.pos_status = 0
    oPlayer:Send("GS2COrgFlag", self:PackOrgFlag(mNet))
end

function COrg:CheckPositionTitle(iPid)
    local oTitleMgr = global.oTitleMgr
    oTitleMgr:CheckOrgPositionTitle(iPid, self:GetPosition(iPid), self:GetName())
end

function COrg:CheckEliteTitle(oPlayer)
    local iTid = 1013
    local oTitleMgr = global.oTitleMgr
    if self.m_oMemberMgr:IsElite(oPlayer:GetPid()) then
        if oPlayer:GetTitle(iTid) then return end

        local mData = oTitleMgr:GetTitleDataByTid(iTid)
        if not mData then return end

        local sName = string.format(mData.name, self:GetName())
        oTitleMgr:AddTitle(oPlayer:GetPid(), iTid, sName)
    else
        if oPlayer:GetTitle(iTid) then
            oTitleMgr:RemoveOneTitle(oPlayer:GetPid(), iTid)
        end
    end
end

function COrg:ClearOrgTitle(iPid)
    local oTitleMgr = global.oTitleMgr
    local lTitles = {}
    local iTit = oTitleMgr:GetOrgTitleByPos(self:GetPosition(iPid))
    if iTit then
        table.insert(lTitles, iTit)
    end

    if self.m_oMemberMgr:IsElite(iPid) then
        table.insert(lTitles, 1013)
    end
    oTitleMgr:RemoveTitles(iPid, lTitles)
end

function COrg:GS2CGetOnlineMember(oPlayer, bAll)
    local mNet = {}
    local oWorldMgr = global.oWorldMgr
    for _, oMem in pairs(self.m_oMemberMgr:GetMemberMap()) do
        local oOther = oWorldMgr:GetOnlinePlayerByPid(oMem:GetPid())
        if oOther and oPlayer:GetPid() ~= oOther:GetPid() then
            table.insert(mNet, oOther:PackSimpleInfo())
        end
    end

    if bAll then
        for _, oMem in pairs(self.m_oMemberMgr:GetXueTuMap()) do
            local oOther = oWorldMgr:GetOnlinePlayerByPid(oMem:GetPid())
            if oOther and oPlayer:GetPid() ~= oOther:GetPid() then
                table.insert(mNet, oOther:PackSimpleInfo())
            end
        end
    end
    oPlayer:Send("GS2CGetOnlineMember", {infos=mNet})
end

function COrg:GiveLeader2Other(oPlayer, iTarPid)
    -- 禅让帮主
    if not self:IsLeader(oPlayer:GetPid()) then return end

    local oMem = self:GetMember(iTarPid)
    if not oMem then return end

    local mLog = self:LogData()
    mLog["old_leader"] = oPlayer:GetPid() 
    mLog["new_leader"] = iTarPid
    mLog["reason"] = "禅让"
    record.log_db("org", "transfer_leader", mLog)

    local iOldPos = self:GetPosition(iTarPid)
    self:RemovePosition(iTarPid)
    self:RemovePosition(oPlayer:GetPid())
    self:SetLeader(iTarPid)
    self:SetPosition(oPlayer:GetPid(), iOldPos)
    self:SendMail4ChangeLeader(oPlayer:GetPid(), iTarPid)
    oPlayer:Send("GS2CSetPositionResult", {pid=iTarPid, position=orgdefines.ORG_POSITION.LEADER})
    oPlayer:Send("GS2CSetPositionResult", {pid=oPlayer:GetPid(), position=iOldPos})

    local oOrgMgr = global.oOrgMgr
    local sMsg = oOrgMgr:GetOrgText(1112, {role={oPlayer:GetName(), oMem:GetName()}})
    oOrgMgr:SendMsg2Org(self:OrgID(), sMsg)
    self:GS2COrgFlagInfo(oPlayer)
    oPlayer:PropChange("org_pos")

    local oWorldMgr = global.oWorldMgr
    local oTarget = oWorldMgr:GetOnlinePlayerByPid(iTarPid)
    if oTarget then
        self:GS2COrgFlagInfo(oTarget)
        oTarget:PropChange("org_pos")
        oTarget:Send("GS2CSetPositionResult", {pid=iTarPid, position=orgdefines.ORG_POSITION.LEADER})
        oTarget:Send("GS2CSetPositionResult", {pid=oPlayer:GetPid(), position=iOldPos})
    end
    self:PushOrgMember2Version(oPlayer:GetPid(), gamedefines.VERSION_OP_TYPE.UPDATE)
    self:PushOrgMember2Version(iTarPid, gamedefines.VERSION_OP_TYPE.UPDATE)
    oPlayer:NotifyMessage(oOrgMgr:GetOrgText(1153))
    self:PushOrgListToVersion(true)
    global.oTitleMgr:OnChangeOrgPos(iTarPid)
    global.oTitleMgr:OnChangeOrgPos(oPlayer:GetPid())
end

function COrg:SetMemPosition(oPlayer, iTarPid, iPos)
    if not self:HasSetPosAuth(oPlayer:GetPid(), iPos)  then return end

    local oOrgMgr = global.oOrgMgr
    local oMem = self:GetMember(iTarPid)
    if not oMem then
        oPlayer:NotifyMessage(oOrgMgr:GetOrgText(1128))
        return
    end

    if iPos ~= orgdefines.ORG_POSITION.MEMBER  and self:GetPositionCnt(iPos)  >= self:GetPosMaxCnt(iPos) then
        oPlayer:NotifyMessage(oOrgMgr:GetOrgText(1050))
        return
    end
    
    local mLog = self:LogData()
    mLog["seter"] = oPlayer:GetPid()
    mLog["targetid"] = iTarPid
    mLog["old_pos"] = self:GetPosition(iTarPid)
    mLog["new_pos"] = iPos
    record.log_db("org", "set_position", mLog)

    self:RemovePosition(iTarPid)
    self:SetPosition(iTarPid, iPos)
    oPlayer:Send("GS2CSetPositionResult", {pid=iTarPid, position=iPos})
    self:PushOrgMember2Version(iTarPid, gamedefines.VERSION_OP_TYPE.UPDATE)
    oPlayer:NotifyMessage(oOrgMgr:GetOrgText(1153))

    if iPos ~= orgdefines.ORG_POSITION.MEMBER then
        local mData = res["daobiao"]["org"]["positionid"][iPos]
        local oMem = self:GetMember(iTarPid)
        local sMsg = oOrgMgr:GetOrgText(1111, {role=oMem:GetName(), position=mData["name"]})
        oOrgMgr:SendMsg2Org(self:OrgID(), sMsg)
    end

    local oWorldMgr = global.oWorldMgr
    local oTarget = oWorldMgr:GetOnlinePlayerByPid(iTarPid)
    if oTarget then
        self:GS2COrgFlagInfo(oTarget)
        oTarget:Send("GS2CSetPositionResult", {pid=iTarPid, position=iPos})
        oTarget:PropChange("org_pos")
        global.oTitleMgr:OnChangeOrgPos(iTarPid)
    end
end

function COrg:GS2CGetBuildInfo(oPlayer)
    self.m_oBuildMgr:GS2CGetBuildInfo(oPlayer)
end

function COrg:UpGradeBuild(oPlayer, iBid)
    if not self:HasUpGradeBuildAuth(oPlayer:GetPid()) then return end

    local oOrgMgr = global.oOrgMgr
    local oNowBuild = self.m_oBuildMgr:GetHasBuilding()
    if oNowBuild then
        local sMsg
        if oNowBuild:Level() > 0 then
            sMsg = oOrgMgr:GetOrgText(1084, {build=oNowBuild:GetBuildData()["name"]})
        else
            sMsg = oOrgMgr:GetOrgText(1133, {build=oNowBuild:GetNextLevelData()["name"]})
        end
        oPlayer:NotifyMessage(sMsg)
        return
    end

    local level = self.m_oBuildMgr:GetBuildLevelByBid(iBid) + 1
    local bRet = self:CheckUpGrade(oPlayer, iBid, level)
    if not bRet then return end

    local mData = self.m_oBuildMgr:GetBuildLevelData(iBid, level)
    local iVal = mData["cost_cash"]
    if iVal > self:GetCash() then return end

    local mLog = self:LogData()
    mLog["pid"] = oPlayer:GetPid()
    mLog["name"] = oPlayer:GetName()
    mLog["buildid"] = iBid
    mLog["old_level"] = level - 1
    mLog["old_cash"] = self:GetCash()
    mLog["cost_item"] = 0
    mLog["cost_cnt"] = 0

    local mCost = mData["cost_item"]
    if mCost.id then
        if oPlayer:GetItemAmount(mCost.id) < mCost.cnt then
            oPlayer:NotifyMessage("消耗物品不足")
            return
        end
        mLog["cost_item"] = mCost.id
        mLog["cost_cnt"] = mCost.cnt
        oPlayer:RemoveItemAmount(mCost.id, mCost.cnt, "帮派升级消耗")
    end

    self:AddCash(-iVal, oPlayer:GetPid())
    mLog["now_cash"] = self:GetCash()
    record.log_db("org", "upgrade_build", mLog)    

    self:GS2COrgInfoChange(oPlayer:GetPid(), {cash=self:GetCash()})
    self.m_oBuildMgr:UpGradeBuild(oPlayer, iBid)
end

function COrg:CheckUpGrade(oPlayer, iBid, iLevel)
    local mData = self.m_oBuildMgr:GetBuildLevelData(iBid, iLevel)
    if not mData then return end

    local oOrgMgr = global.oOrgMgr
    local oWorldMgr = global.oWorldMgr
    if self:GetCash() < mData["upgrade_con1"] then
        oPlayer:NotifyMessage(oOrgMgr:GetOrgText(1092))
        return   
    end

    local oHome = self.m_oBuildMgr:GetBuildHome()
    if iBid == oHome:BuildID() then
        if oWorldMgr:GetServerGrade() < mData["upgrade_con2"] then
            oPlayer:NotifyMessage(oOrgMgr:GetOrgText(1107, {level=mData["upgrade_con2"]}))
            return
        end
    else
        if oHome:Level() < mData["upgrade_con2"] then
            local mBuild = self.m_oBuildMgr:GetBuildLevelData(oHome:BuildID(), 1)
            oPlayer:NotifyMessage(oOrgMgr:GetOrgText(1172, {build=mBuild["name"],level=mData["upgrade_con2"]}))
            return 
        end
    end
    for _,v in pairs(mData["upgrade_con3"]) do
        local iLevel = self.m_oBuildMgr:GetBuildLevelByBid(v.id)
        if iLevel < v.lv then
            local mBuild = self.m_oBuildMgr:GetBuildLevelData(v.id, 1)
            oPlayer:NotifyMessage(oOrgMgr:GetOrgText(1172, {build=mBuild["name"],level=v.lv}))
            return
        end
    end 

    return true
end

function COrg:BuildUpGradeSuccess(iBid, iLevel)
    self.m_oAchieveMgr:HandleEvent(orgdefines.ORG_ACH_TYPE.BUILD_LEVEL, {iLevel=iLevel, iBid=iBid})

    local oHome = self.m_oBuildMgr:GetBuildHome()
    if iBid == oHome:BuildID() then
        self:OnUpOrgGrade()
    end

    local iMin = self.m_oBuildMgr:GetMinBuildLevel()
    if iMin >= iLevel then
        self.m_oAchieveMgr:HandleEvent(orgdefines.ORG_ACH_TYPE.ALL_BUILD_LEVEL, {iVal=iLevel})
    end

    local oOrgMgr = global.oOrgMgr
    local oBuild = self:GetBuildById(iBid)
    if oBuild then
        local mData = oBuild:GetBuildData()
        local sDesc = mData["updes"]
        local sMsg = oOrgMgr:GetOrgText(2001, {build=mData["name"], level=iLevel})
        sMsg = sMsg..","..sDesc
        self:AddLog(0, sMsg)

        local oNotifyMgr = global.oNotifyMgr
        oNotifyMgr:SendGS2Org(self:OrgID(), "GS2CGetBuildInfo", {infos={oBuild:PackBuildInfo()}})
    end
end

function COrg:TriggerChangeLevel()
    local oHuodong = global.oHuodongMgr:GetHuodong("kaifudianli")
    if oHuodong then
        oHuodong:OnOrgLevel(self)
    end
end

function COrg:GetBoonSignRatio()
    local oBuild = self.m_oBuildMgr:GetBuildFane()
    if not oBuild then return 0 end

    return oBuild:GetBoonSignRatio()
end

function COrg:GetBoonBousRatio()
    local oBuild = self.m_oBuildMgr:GetBuildFane()
    if not oBuild then return 0 end

    return oBuild:GetBoonBousRatio()
end

function COrg:GetBoonPosRatio()
    local oBuild = self.m_oBuildMgr:GetBuildFane()
    if not oBuild then return 0 end

    return oBuild:GetBoonPosRatio()
end

function COrg:GetBuildById(iBid)
    return self.m_oBuildMgr:GetBuildById(iBid)
end

function COrg:QuickBuild(oPlayer, iBid, iQuick)
    self.m_oBuildMgr:QuickBuild(oPlayer, iBid, iQuick)
end

function COrg:GS2CGetShopInfo(oPlayer)
    self.m_oBuildMgr:GS2CGetShopInfo(oPlayer)
end

function COrg:BuyItem(oPlayer, iItem, iCnt)
    self.m_oBuildMgr:BuyItem(oPlayer, iItem, iCnt)
end

function COrg:GS2CGetBoonInfo(oPlayer)
    self.m_oBoonMgr:GS2CGetBoonInfo(oPlayer)
end

function COrg:DoSign(oPlayer, sMsg)
    self.m_oBoonMgr:DoSign(oPlayer, sMsg)
end

function COrg:ReceiveBonus(oPlayer)
    self.m_oBoonMgr:ReceiveBonus(oPlayer)
end

function COrg:ReceivePosBonus(oPlayer)
    self.m_oBoonMgr:ReceivePosBonus(oPlayer)
end

function COrg:GS2CGetAchieveInfo(oPlayer)
    self.m_oAchieveMgr:GS2CGetAchieveInfo(oPlayer)
end

function COrg:ReceiveAchieve(oPlayer, iAch)
    self.m_oAchieveMgr:ReceiveAchieve(oPlayer, iAch)
end

function COrg:CreateOrgScene()
    local oSceneMgr = global.oSceneMgr
    local mMap = res["daobiao"]["org"]["scene"][5010]
    local oScene = oSceneMgr:CreateVirtualScene({
        map_id = mMap.map_id,
        url = {"org", "scene", 5010}
        })
    self.m_iSceneID = oScene:GetSceneId()
    self:InitOrgNpc()
    self:InitOrgEffect()
end

function COrg:InitOrgNpc()
    local iScene = self:GetOrgSceneID()
    local oSceneMgr = global.oSceneMgr
    local oScene = oSceneMgr:GetScene(iScene)
    if not oScene then return end

    local mGlobalData = res["daobiao"]["global_npc"] or {}
    for npctype, mConfig in pairs(mGlobalData) do
        if mConfig.mapid ~= oScene:MapId() then goto continue end

        local oNpc = loadnpc.NewOrgNpc(npctype, self:OrgID())
        self:AddOrgNpc(oNpc)

        ::continue::
    end
end

function COrg:InitOrgEffect()
    local iScene = self:GetOrgSceneID()
    local oSceneMgr = global.oSceneMgr
    local oScene = oSceneMgr:GetScene(iScene)
    if not oScene then return end

    local mSEffects = res["daobiao"]["org"]["scene_effect"]
    for iEffectType, mEffInfo in pairs(mSEffects) do
        local mCreateInfo = {
            name = mEffInfo.name,
            type = iEffectType,
            pos_info = {
                x = mEffInfo.x,
                y = mEffInfo.y,
                z = mEffInfo.z,
            },
        }
        local oEffect = effectobj.TouchNewSceneEffect(mEffInfo.effect_id, mCreateInfo)
        self.m_mSceneEffect[iEffectType] = oEffect
        oScene:EnterEffect(oEffect)
    end
end

function COrg:AddOrgNpc(oNpc)
    local iScene = self:GetOrgSceneID()
    local oSceneMgr = global.oSceneMgr
    local oScene = oSceneMgr:GetScene(iScene)
    local oNpcMgr = global.oNpcMgr
    if not oScene then return end

    oNpcMgr:AddObject(oNpc)
    oNpc:SetScene(oScene:GetSceneId())
    oScene:EnterNpc(oNpc)
    self.m_mNpcId[oNpc:ID()] = oNpc:Type()
end

function COrg:DeleteOrgNpc(iNpcId)
    self.m_mNpcId[iNpcId] = nil
    local oNpcMgr = global.oNpcMgr
    oNpcMgr:RemoveSceneNpc(iNpcId)
end

function COrg:GetOrgNpc(iNpcId)
    local oNpcMgr = global.oNpcMgr
    return oNpcMgr:GetObject(iNpcId)
end

function COrg:GetZhongGuan()
    for iNpcId, iNpcType in pairs(self.m_mNpcId) do
        if iNpcType == 5281 then
            return self:GetOrgNpc(iNpcId)
        end
    end
end

function COrg:GetOrgSceneID()
    -- if not self.m_iSceneID then
        -- self:CreateOrgScene()
    -- end
    return self.m_iSceneID
end

function COrg:EnterOrgScene(oPlayer)
    local iScene = self:GetOrgSceneID()
    local oSceneMgr = global.oSceneMgr
    local oScene = oSceneMgr:GetScene(iScene)
    if not oScene then return end

    local oNowScene = oPlayer.m_oActiveCtrl:GetNowScene()
    if oNowScene:GetSceneId() == iScene then return end
    
    if not oNowScene:ValidLeave(oPlayer,oScene) then
        return
    end
    if not oScene:ValidEnter(oPlayer) then
        return 
    end
    global.oSceneMgr:DoTransfer(oPlayer, iScene)
    return true
end

function COrg:ChatBan(oPlayer, iBanId, iFlag)
    local oOrgMgr = global.oOrgMgr 
    if not self:HasBanChatAuth(oPlayer:GetPid(), iBanId) then
        oPlayer:NotifyMessage(oOrgMgr:GetOrgText(1057)) 
        return
    end

    local oMem = self:GetMemberFromAll(iBanId)
    if not oMem then
        oPlayer:NotifyMessage(oOrgMgr:GetOrgText(1128)) 
        return 
    end

    if iFlag == 1 then
        if not oMem:IsChatBan() then
            oMem:SetChatBan()
            oPlayer:NotifyMessage(oOrgMgr:GetOrgText(1139, {role=oMem:GetName()}))
            local sMsg = oOrgMgr:GetOrgText(1136, {role=oMem:GetName()})
            oOrgMgr:SendMsg2Org(self:OrgID(), sMsg)
        else
            oPlayer:NotifyMessage(oOrgMgr:GetOrgText(1135))    
        end
    else
        if oMem:IsChatBan() then
            oMem:SetChatBan(0)
            oPlayer:NotifyMessage(oOrgMgr:GetOrgText(1140, {role=oMem:GetName()}))
            local sMsg = oOrgMgr:GetOrgText(1137, {role=oMem:GetName()})
            oOrgMgr:SendMsg2Org(self:OrgID(), sMsg)
        else
            oPlayer:NotifyMessage(oOrgMgr:GetOrgText(1141))
        end
    end
    
    oPlayer:Send("GS2CChatBan", {binid=iBanId, flag=iFlag})
end

function COrg:GS2COrgInfoChange(iPid, m)
    local oWorldMgr = global.oWorldMgr
    local oPlayer = oWorldMgr:GetOnlinePlayerByPid(iPid)
    if not oPlayer or not m then return end

    oPlayer:Send("GS2COrgInfoChange", {info=net.Mask("OrgBaseInfo", m)})
end

function COrg:GetOnlineMembers()
    return self.m_oMemberMgr:GetOnlineMembers()
end

function COrg:GetOnlineXuetu()
    return self.m_oMemberMgr:GetOnlineXuetu()
end

function COrg:LogData()
    local mLog = {}
    mLog["org_id"] = self:OrgID()
    mLog["leader"] = self:GetLeaderID() or 0
    mLog["org_name"] = self:GetName()
    mLog["org_lv"] = self:GetLevel()
    return mLog
end

function COrg:GS2CNextPageLog(oPlayer, iLastId)
   return self.m_oLogMgr:GS2CNextPageLog(oPlayer, iLastId)
end

function COrg:IsFull(bAll)
    if self:GetMemberCnt() < self:GetMaxMemberCnt() then
        return false
    end
    if bAll and self:GetXueTuCnt() < self:GetMaxXuetuCnt() then
        return false
    end
    return true
end

function COrg:IsMultiApply(oPlayer)
    local iRatio = 0
    if oPlayer:GetGrade() >= 35 then
        iRatio = self:GetMemberCnt() / self:GetMaxMemberCnt()
    else
        iRatio = (self:GetMemberCnt() + self:GetXueTuCnt()) / (self:GetMaxMemberCnt() + self:GetMaxXuetuCnt())
    end
    return iRatio < 0.9
end

function COrg:SetTest(sKey, value)
    self.m_mTest[sKey] = value
end

function COrg:GetTest(sKey, vDefault)
    return self.m_mTest[sKey] or vDefault
end

function COrg:SavePlayerMerge(iPid)
    local oPlayer = global.oWorldMgr:GetOnlinePlayerByPid(iPid)
    if oPlayer then
        self:AddSaveMerge(oPlayer)
    else
        local iOrgID = self:OrgID()
        global.oWorldMgr:LoadProfile(iPid, function(oProfile)
            local oOrg = global.oOrgMgr:GetNormalOrg(iOrgID)
            if not oProfile or not oOrg then return end
            
            oOrg:AddSaveMerge(oProfile)
        end)
    end
end

function COrg:CanLeaveOrg(oPlayer)
    local oHuodong = global.oHuodongMgr:GetHuodong("orgwar")
    if oHuodong and oHuodong:InHuodongTime() then
        oHuodong:Notify(oPlayer:GetPid(), 1019)
        return false
    end
    return true
end

function COrg:CanKickMember(oPlayer, iKickPid)
    local oHuodong = global.oHuodongMgr:GetHuodong("orgwar")
    if oHuodong and oHuodong:InHuodongTime() then
        oHuodong:Notify(oPlayer:GetPid(), 1018)
        return false
    end
    return true
end

function COrg:PushOrgListToVersion(bForce)
    if not self.m_bUpdate and not bForce then return end

    self.m_bUpdate = false
    if not self:GetLeader() then
        global.oOrgMgr:PushOrgListToVersion(gamedefines.VERSION_OP_TYPE.DELETE, self:OrgID(), {})
        return
    end   
    local mInfo = self:PackOrgListInfo()
    global.oOrgMgr:PushOrgListToVersion(gamedefines.VERSION_OP_TYPE.UPDATE, self:OrgID(), mInfo)
end

function COrg:CreateOrgMemberVersion()
    local mData = self.m_oMemberMgr:PackOrgMemberMap()
    local oVersionMgr = global.oVersionMgr
    oVersionMgr:CreateVersionObj(oVersionMgr:GetOrgMemberType(self:OrgID()), "orgmember", mData)
end

function COrg:SetSyncMember(iPid, b)
    self.m_mSyncMember[iPid] = b
end

function COrg:SycnOrgMember2Version()
    local lPid = table_key_list(self.m_mSyncMember)
    for _, iPid in pairs(lPid or {}) do
        self:PushOrgMember2Version(iPid, gamedefines.VERSION_OP_TYPE.UPDATE)
    end
end

function COrg:PushOrgMember2Version(iPid, iOpType, bLogout)
    local mInfo = {}
    if iOpType ~= gamedefines.VERSION_OP_TYPE.DELETE then
        mInfo = self.m_oMemberMgr:PackMemberInfo(iPid, bLogout)
    end 
    local oVersionMgr = global.oVersionMgr
    self:SetSyncMember(iPid, nil)
    oVersionMgr:PushDataToVersion(oVersionMgr:GetOrgMemberType(self:OrgID()), iOpType, iPid, mInfo)
end

function COrg:IsAutoJoinXT()
    return self:GetAutoJoin() > 0
end

function COrg:GetAutoJoin()
    return self.m_oBaseMgr:GetData("auto_join", 0)
end

function COrg:SetAutoJoin(oPlayer, iFlag)
    local oOrgMgr = global.oOrgMgr
    if not self:HasSetAutoJoinAuth(oPlayer:GetPid()) then
        oPlayer:NotifyMessage(oOrgMgr:GetOrgText(1146))
        return
    end
    if iFlag == 1 and self:GetXueTuCnt() >= self:GetMaxXuetuCnt() then
        oPlayer:NotifyMessage(oOrgMgr:GetOrgText(1149))
        return 
    end
    self.m_oBaseMgr:SetData("auto_join", iFlag)
    oPlayer:Send("GS2CSetAutoJoin", {auto_join = iFlag})
    oPlayer:NotifyMessage(oOrgMgr:GetOrgText(1150))
end

function COrg:ClearApplyList(oPlayer)
    local oOrgMgr = global.oOrgMgr
    if not self:HasDelApplyListAuth(oPlayer:GetPid()) then
        oPlayer:NotifyMessage(oOrgMgr:GetOrgText(1146))
        return
    end
    self.m_oApplyMgr:ClearApplyInfo()
    oPlayer:Send("GS2COrgApplyJoinInfo", {infos=self:PackOrgApplyInfo()})    
end

function COrg:SendOrgMail2Member(oPlayer, sContent)
    local iPid = oPlayer:GetPid()
    local oOrgMgr = global.oOrgMgr

    if not sContent or #sContent <= 0 then return end
    if not self:HasSendMailAuth(iPid) then return end

    local iLeftTime = self:GetSetMailCD()
    if iLeftTime > 0 then
        local iHour, iMins, iSec = global.oToolMgr:ConvertSeconds(iLeftTime)
        if iSec > 0 then
            iMins = iMins + 1
        end
        oPlayer:NotifyMessage(oOrgMgr:GetOrgText(1181, {HH=iHour, MM=iMins})) 
        return
    end


    local iTimes = oOrgMgr:GetOtherConfig("mail_times")
    if oPlayer.m_oTodayMorning:Query("org_mail_cnt", 0) >= iTimes then
        oPlayer:NotifyMessage(oOrgMgr:GetOrgText(1174, {amount=iTimes}))    
        return             
    end
    local iCost = oOrgMgr:GetOtherConfig("mail_cost_energy")
    if oPlayer:GetEnergy() < iCost then
        oPlayer:NotifyMessage(oOrgMgr:GetOrgText(1163))
        return
    end

    local oMailMgr = global.oMailMgr
    local mData, _ = oMailMgr:GetMailInfo(3018)
    if not mData then return end

    oPlayer.m_oTodayMorning:Add("org_mail_cnt", 1)
    oPlayer:AddEnergy(-iCost, "帮派通告")
    local mInfo = table_copy(mData)
    mInfo.context = sContent
    local iPos = self:GetPosition(iPid)
    local sPosition = res["daobiao"]["org"]["positionid"][iPos]["name"]
    local sName = oOrgMgr:GetOrgText(1157, {position=sPosition, role=oPlayer:GetName()})
    self:SendMail2Member(true, iPid, sName, mInfo)
    oPlayer:NotifyMessage(oOrgMgr:GetOrgText(1164))

    self.m_oBaseMgr:SetMailTime()
    local mNet = {left_mail_cnt=self:GetLeftMailCnt(oPlayer), left_mail_cd=self:GetSetMailCD()}
    self:ChangeOrgMainInfo(oPlayer, mNet)

    local mLog = oPlayer:LogData()
    mLog["org_id"] = self:OrgID()
    record.log_db("org", "org_mail", mLog)
end

function COrg:GetLeftMailCnt(oPlayer)
    local iTimes = global.oOrgMgr:GetOtherConfig("mail_times")
    return math.max(0, iTimes-oPlayer.m_oTodayMorning:Query("org_mail_cnt", 0))
end

function COrg:SendMail2Member(bAll, iSender, sName, mMail)
    local lPlayers = table_key_list(self.m_oMemberMgr:GetMemberMap())
    if bAll then
        for iPid,_ in pairs(self.m_oMemberMgr:GetXueTuMap()) do
            table.insert(lPlayers, iPid)
        end
    end

    local func = function (iPid)
        global.oMailMgr:SendMail(iSender, sName, iPid, mMail, 0)
    end
    self.m_iMail = self.m_iMail + 1
    local sKey = string.format("SendMail2Member_%s", self.m_iMail)
    global.oToolMgr:ExecuteList(lPlayers, 100, 500, 0, sKey, func)
end

function COrg:OnChangeName()
    self:PushOrgListToVersion(true)
    self:SyncOrgTitle()
    global.oRankMgr:PushDataToOrgPrestige(self)

    local mReplace = {role=self:GetLeaderName(), bpname=self:GetName()}
    local sLog = global.oOrgMgr:GetOrgText(1177, mReplace)
    self:AddLog(self:GetLeaderID(), sLog)

    local oPlayer = global.oWorldMgr:GetOnlinePlayerByPid(self:GetLeaderID())
    local sMsg = global.oOrgMgr:GetOrgText(1178, mReplace)
    global.oOrgMgr:SendMsg2Org(self:OrgID(), sMsg, oPlayer)
end

function COrg:SyncOrgTitle()
    local lPlayers = self.m_oMemberMgr:GetOnlinePlayers()
    local func = function (iPid)
        global.oTitleMgr:SyncOrgTitle(iPid)
    end
    global.oToolMgr:ExecuteList(lPlayers, 50, 500, 0, "sync_org_title", func)
end

function COrg:OnUpOrgGrade()
    self:TriggerChangeLevel()
    self:PushOrgListToVersion(true)        
    self.m_oAchieveMgr:HandleEvent(orgdefines.ORG_ACH_TYPE.ORG_LEVEL, {iVal=self:GetLevel()})
    global.oRankMgr:PushDataToOrgPrestige(self)

    local lPlayers = self.m_oMemberMgr:GetOnlinePlayers()
    local func = function (iPid)
        local o = global.oWorldMgr:GetOnlinePlayerByPid(iPid)
        if o then
            o:RefreshCulSkillUpperLevel()
        end
    end
    global.oToolMgr:ExecuteList(lPlayers, 100, 500, 0, "sync_culskill", func) 
end


