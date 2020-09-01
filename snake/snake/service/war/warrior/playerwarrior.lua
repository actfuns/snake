
local global = require "global"
local skynet = require "skynet"
local interactive = require "base.interactive"
local net = require "base.net"
local res = require "base.res"
local record = require "public.record"
local playersend = require "base.playersend"

local gamedefines = import(lualib_path("public.gamedefines"))
local CWarrior = import(service_path("warrior.warrior")).CWarrior

function NewPlayerWarrior(...)
    return CPlayerWarrior:New(...)
end

function OnCalYaoShenDamageRatio(oAttack, oVictim, oPerform)
    if oAttack:GetData("school") ~= gamedefines.PLAYER_SCHOOL.YAOSHEN then
        return 0
    end
    if oPerform and oPerform:AttackType() ~= gamedefines.WAR_PERFORM_TYPE.PHY then
        return 0
    end
    return oAttack:GetAura() * global.oActionMgr:GetWarConfig("aura_yaoshen")
end

function OnYaoChiAddAura(oAction)
    if oAction:GetData("school") == gamedefines.PLAYER_SCHOOL.YAOCHI then
        if not oAction:IsDead() and oAction.m_oBuffMgr:HasBuff(129) and math.random(100) <= 20 then
            -- 杏黄旗buff
            oAction:AddAura(1)
        end
    end
end


StatusHelperFunc = {}

function StatusHelperFunc.hp(o)
    return o:GetHp()
end

function StatusHelperFunc.mp(o)
    return o:GetMp()
end

function StatusHelperFunc.max_hp(o)
    return o:GetMaxHp()
end

function StatusHelperFunc.max_mp(o)
    return o:GetMaxMp()
end

function StatusHelperFunc.model_info(o)
    return o:GetModelInfo()
end

function StatusHelperFunc.name(o)
    return o:GetName()
end

function StatusHelperFunc.aura(o)
    return o:GetAura()
end

function StatusHelperFunc.status(o)
    return o.m_oStatus:Get()
end

function StatusHelperFunc.auto_perform(o)
    return o:GetAutoPerform()
end

function StatusHelperFunc.is_auto(o)
    return o:GetAutoFight()
end

function StatusHelperFunc.max_sp(o)
    return o:GetMaxSp()
end

function StatusHelperFunc.sp(o)
    return o:GetSP()
end

function StatusHelperFunc.item_use_cnt1(o)
    return o:GetUseDrugCnt(1)
end

function StatusHelperFunc.item_use_cnt2(o)
    return o:GetUseDrugCnt(2)
end

function StatusHelperFunc.cmd(o)
    local oWar = o:GetWar()
    return oWar:GetBoutCmd(o:GetWid()) and 1 or 0
end

function StatusHelperFunc.school(o)
    return o:GetData("school", 0)
end

function StatusHelperFunc.grade(o)
    return o:GetData("grade", 0)
end

function StatusHelperFunc.zhenqi(o)
    return o:GetZhenQi()
end

CPlayerWarrior = {}
CPlayerWarrior.__index = CPlayerWarrior
inherit(CPlayerWarrior, CWarrior)

function CPlayerWarrior:New(iWid, iPid)
    local o = super(CPlayerWarrior).New(self, iWid)
    o.m_iType = gamedefines.WAR_WARRIOR_TYPE.PLAYER_TYPE
    o.m_iAIType = gamedefines.AI_TYPE.AUTOPERFORM
    o.m_mSummonAutoPf = {}
    o.m_iPid = iPid
    o.m_iSP = 50
    o.m_mUpdateInfo = {}
    o.m_iUseDrug1Cnt = 0
    o.m_iUseDrug2Cnt = 0
    return o
end

function CPlayerWarrior:Init(mInit)
    super(CPlayerWarrior).Init(self, mInit)
    if self:GetTestData("wardebug") then
        local oWar = self:GetWar()
        oWar:AddDebugPlayer(self)
    end

    self:InitAutoPerform()
    self:InitAutoFight()
    self:DoAfterInit()
    self:SetAppoint(mInit.data.appoint)
end

function CPlayerWarrior:Leave()
    super(CPlayerWarrior).Leave(self)
    self:UpdateUpdateInfo()
end

function CPlayerWarrior:GetPid()
    return self.m_iPid
end

function CPlayerWarrior:GetSchool()
    return self:GetData("school")
end

function CPlayerWarrior:GetCouplePid()
    return self:GetData("couple_pid")
end

function CPlayerWarrior:GetCoupleDegree()
    return self:GetData("couple_degree") or 0
end

function CPlayerWarrior:Send(sMessage, mData)
    playersend.Send(self.m_iPid, sMessage, mData)
end

function CPlayerWarrior:SetAppoint(iAppoint)
    local oWarMgr = global.oWarMgr
    local oWar = oWarMgr:GetWar(self:GetWarId())
    if not oWar then return end
    local oCamp = oWar:GetCampObj(self:GetCampId())
    if oCamp and not oCamp.m_Appoint and iAppoint == 1 then
        oCamp.m_Appoint=self.m_iPid
    end
end

function CPlayerWarrior:IsAppoint()
    local oWarMgr = global.oWarMgr
    local oWar = oWarMgr:GetWar(self:GetWarId())
    if not oWar then return 0 end
    local oCamp = oWar:GetCampObj(self:GetCampId())
    if oCamp and oCamp.m_Appoint and oCamp.m_Appoint == self.m_iPid then
        return 1
    else
        return 0
    end
end

function CPlayerWarrior:GetAppointOP()
    local oWarMgr = global.oWarMgr
    local oWar = oWarMgr:GetWar(self:GetWarId())
    if not oWar then return 0 end
    local oCamp = oWar:GetCampObj(self:GetCampId())
    return oCamp:GetAppointOP(self.m_iPid)
end

function CPlayerWarrior:Disconnected()
end

function CPlayerWarrior:SendRaw(sData)
    playersend.SendRaw(self.m_iPid, sData)
end

function CPlayerWarrior:Notify(sMsg, iType, iFlag)
    iType = iType or 1
    iFlag = iFlag or 0
    playersend.Send(self.m_iPid,"GS2CWarNotify",{
        cmd = sMsg,
        type = iType,
        flag = iFlag,
    })
end

function CPlayerWarrior:ReEnter()
    local oWar = self:GetWar()
    self:Send("GS2CWarAddWarrior", {
        war_id = self:GetWarId(),
        camp_id = self:GetCampId(),
        type = self:Type(),
        warrior = self:GetSimpleWarriorInfo(),
    })
    oWar:GS2CAddAllWarriors(self)

    oWar:SendAll("GS2CWarCampFmtInfo", {
        war_id = oWar:GetWarId(),
        fmt_id1 = oWar.m_lCamps[1]:GetFmtId(),
        fmt_grade1 = oWar.m_lCamps[1]:GetFmtGrade(),
        fmt_id2 = oWar.m_lCamps[2]:GetFmtId(),
        fmt_grade2 = oWar.m_lCamps[2]:GetFmtGrade(),
    })

    local iStatus, iStatusTime = oWar.m_oBoutStatus:Get()
    if iStatus == gamedefines.WAR_BOUT_STATUS.OPERATE then
        self:Send("GS2CWarBoutStart", {
            war_id = oWar:GetWarId(),
            bout_id = oWar.m_iBout,
            left_time = math.max(0, math.floor((iStatusTime + oWar:GetOperateTime() - get_msecond())/1000)),
        })
    elseif iStatus == gamedefines.WAR_BOUT_STATUS.ANIMATION then
        self:Send("GS2CWarBoutEnd", {
            war_id = oWar:GetWarId(),
        })
        self:Send("GS2CWarStatus", {
            war_id = oWar:GetWarId(),
            bout = oWar:CurBout(),
            left_time = math.max(0, math.floor((iStatusTime + oWar:GetOperateTime() - get_msecond())/1000)),
        })
    end
    self:Send("GS2CPlayerWarriorEnter",{
        war_id = self.m_iWarId,
        wid = self:GetWid(),
        sum_list = table_key_list(self:Query("summon",{}))
    })

    local iCamp = self:GetCampId()
    if oWar and oWar.m_Appoint and oWar.m_Appoint[iCamp] and #oWar.m_Appoint[iCamp]>0 then
        local mExclude = oWar:GetWarCommandExclude(iCamp)
        local lCmds = oWar.m_Appoint[iCamp]
        local mNet = {war_id = oWar.m_iWarId,op = 1,lcmd = lCmds}
        oWar:SendAll("GS2CWarCommand",mNet,mExclude)
    end
end

function CPlayerWarrior:GetSimpleWarriorInfo()
    return {
        wid = self:GetWid(),
        pid = self:GetPid(),
        pos = self:GetPos(),
        status = self:GetSimpleStatus(),
        pflist = self:PackActivePerform(),
        appoint = self:IsAppoint(),
        appointop = self:GetAppointOP(),
        buff_list = self:PackBuffList(),
        status_list = self:PackStatusList(),
    }
end

function CPlayerWarrior:GetSimpleStatus(m)
    local mRet = {}
    if not m then
        m = StatusHelperFunc
    end
    for k, _ in pairs(m) do
        local f = assert(StatusHelperFunc[k], string.format("GetSimpleStatus fail f get %s", k))
        mRet[k] = f(self)
    end
    return net.Mask("base.WarriorStatus", mRet)
end

function CPlayerWarrior:StatusChange(...)
    local l = table.pack(...)
    local m = {}
    for _, v in ipairs(l) do
        m[v] = true
    end
    local mStatus = self:GetSimpleStatus(m)
    self:SendAll("GS2CWarWarriorStatus", {
        war_id = self:GetWarId(),
        wid = self:GetWid(),
        type = self:Type(),
        status = mStatus,
    })
end

function CPlayerWarrior:GetMaxSp()
    return self.m_iTestMaxSP or 150
end

function CPlayerWarrior:GetSP()
    return self.m_iSP
end

function CPlayerWarrior:AddSP(iSP)
    self.m_iSP = math.min(self.m_iSP + iSP, self:GetMaxSp())
    self.m_iSP = math.max(0, self.m_iSP)
    self:StatusChange("sp")
end

function CPlayerWarrior:GetZhenQi()
    return self:GetData("zhenqi", 0)
end

function CPlayerWarrior:GetZhenQiConfig()
    local mData = res["daobiao"]["fabao"]["config"][1]
    return mData
end

function CPlayerWarrior:GetMaxZhenQi()
    return self:GetZhenQiConfig()["zhenqi_limit"]
end

function CPlayerWarrior:GetAddBoutZhenQi()
    return self:GetZhenQiConfig()["zhenqi_bout"]
end

function CPlayerWarrior:AddZhenQi(iVal)
    local iMax = self:GetMaxZhenQi()
    local iTrueVal = self:GetZhenQi()  
    if iVal > 0 and iTrueVal >= iMax then return end

    iTrueVal = math.min(iTrueVal + iVal, iMax)
    iTrueVal = math.max(0, iTrueVal)
    self:SetData("zhenqi", iTrueVal)
    self:StatusChange("zhenqi")
end

function CPlayerWarrior:OnSubHp(iSubHp, iOldhp, bAddSp, oAttack)
    super(CPlayerWarrior).OnSubHp(self, iSubHp, iOldhp, bAddSp, oAttack)

    self:CheckYaoShenAddAura(iSubHp, iOldhp)

    if self:IsDead() then
        local iPreSP = self.m_iSP
        self:SetData("presp",iPreSP)
        self.m_iSP = 0
        self:StatusChange("sp")
        return
    end
    if not bAddSp then return end

    local iSP
    local iRatio = (iSubHp * 100 ) // self:GetMaxHp()
    if iRatio >=3 and iRatio < 10 then
        iSP = 3
    elseif iRatio>= 10 and iRatio < 20 then
        iSP = 10
    elseif iRatio >= 20 and iRatio < 30 then
        iSP = 15
    elseif iRatio >= 30 and iRatio < 50 then
        iSP = 25
    elseif iRatio >= 50 and iRatio < 80 then
        iSP = 40
    elseif iRatio >= 80 then
        iSP = 55
    end
    if not iSP then
        return
    end
    iSP = math.floor(self:Query("sp_add_ratio", 0)*iSP/100 + iSP)
    iSP = iSP + self:Query("sp_add_ext", 0)
    self:AddSP(iSP)
end

function CPlayerWarrior:GetAura()
    return self:GetExtData("aura",0)
end

function CPlayerWarrior:AddAura(iAura)
    iAura = iAura or 1
    local v = self:GetExtData("aura",0)
    v = v + iAura
    self:SetExtData("aura",math.max(0, math.min(v, 3)))
    self:StatusChange("aura")

    -- TODO liuzla
    local oWar = self:GetWar()
    oWar:AddDebugMsg(string.format("#B%s#n灵气变化, 变化数值%d,　剩余灵气%d", 
        self:GetName(),
        iAura,
        self:GetAura()
    ))
end

function CPlayerWarrior:GetFriendProtector()
    return self:GetData("protectors",{})
end

function CPlayerWarrior:GetGuard()
    local oGuard = super(CPlayerWarrior).GetGuard(self)
    if oGuard then return oGuard end

    oGuard = self:GetCoupleGuard()
    if oGuard then return oGuard, true end

    return self:GetFriendGuard()
end

function CPlayerWarrior:GetCoupleGuard()
    local iCouplePid = self:GetCouplePid()
    if not iCouplePid then return end

    local oWar = self:GetWar()
    local oCouple = oWar:GetPlayerWarrior(iCouplePid)
    if oCouple and oCouple:IsAlive() and self:HasKey("engage_protect") 
        and oCouple:QueryBoutArgs("engage_protect_cnt", 0) < 2 then

        self:GS2CTriggerPassiveSkill(8501)
        return oCouple 
    end
end

function CPlayerWarrior:GetFriendGuard()
    if self:GetHp() / self:GetMaxHp() * 100 > 50 then return end

    local oWar = self:GetWar()
    local mProtect = self:GetFriendProtector()
    for pid, iRatio in pairs(mProtect) do
        local oGuard = oWar:GetPlayerWarrior(pid)
        if not oGuard or (oGuard:GetHp() / oGuard:GetMaxHp() * 100 < 50) then
            goto continue
        end
        oWar:AddDebugMsg(string.format("好友保护概率#B%s#n", iRatio))
        if math.random(10000) <= iRatio then
            return oGuard
        end
        ::continue::
    end
end

function CPlayerWarrior:SetTestData(k, v)
    super(CPlayerWarrior).SetTestData(self, k, v)
    local oWar = self:GetWar()
    if not oWar then
        return
    end
    if k == "wardebug" then
        if v then
            oWar:AddDebugPlayer(self)
        else
            oWar:DelDebugPlayer(self)
        end
    end
end

function CPlayerWarrior:GetDefaultPerform()
    local iSchool = self:GetSchool()
    if iSchool then
        local mData = res["daobiao"]["auto_perform"][iSchool]
        assert(mData, string.format("GetDefaultPerform school err: %d", iSchool))
        local pfid = mData["pfid"]
        assert(pfid, string.format("GetDefaultPerform pfid err: %d", iSchool))
        return pfid
    else
        return 101
    end
end

function CPlayerWarrior:IsOpenFight()
    return self.m_iAutoFight
end

function CPlayerWarrior:SetAutoFight(auto)
    self.m_iAutoFight = auto
    self:StatusChange("is_auto")
end

function CPlayerWarrior:GetAutoFight()
    local iFlag = self:IsOpenFight() and 1 or 0
    return iFlag
end

function CPlayerWarrior:SetAutoPerform(iAutoPf)
    self:SetData("auto_perform",iAutoPf)
    self:StatusChange("auto_perform")
    if iAutoPf then
        self:SetAutoFight(true)
    else
        self:SetAutoFight(nil)
    end
end

function CPlayerWarrior:GetAutoPerform()
    return self:GetData("auto_perform")
end

function CPlayerWarrior:RecordSummAutoPf(iSummid, iPf)
    self.m_mSummonAutoPf[iSummid] = iPf
end

function CPlayerWarrior:GetSummAutoPf()
    return self.m_mSummonAutoPf
end

function CPlayerWarrior:InitAutoPerform()
    local iAutoPf = self:GetAutoPerform()
    if not iAutoPf then
        iAutoPf = self:GetDefaultPerform()
        self:SetData("auto_perform",iAutoPf)
    end    
end

function CPlayerWarrior:InitAutoFight()
    local oWar = self:GetWar()
    if not oWar then return end

    local iAutoStart = oWar:GetAutoStart()
    if iAutoStart == gamedefines.WAR_AUTO_TYPE.FORBID_AUTO then 
        self.m_iAutoFight = nil
    elseif iAutoStart == gamedefines.WAR_AUTO_TYPE.START_AUTO then
        self.m_iAutoFight = 1
    else
        if self:GetData("auto_fight") == 1 then
            self.m_iAutoFight = 1
        else
            self.m_iAutoFight = nil
        end
    end
end

function CPlayerWarrior:StartAutoFight(iAIType)
    local iWid = self:GetWid()
    local mAction = {}
    mAction[iWid] = 1
    local iAutoPf = self:GetAutoPerform()
    if not iAutoPf then
        iAutoPf = self:GetDefaultPerform()
        self:SetAutoPerform(iAutoPf)
    end
    self:SetAutoFight(true)

    local oWar = self:GetWar()
    local iSumWid = self:Query("curr_sum")
    if oWar and iSumWid then
        local oSummon = oWar:GetWarrior(iSumWid)
        if oSummon then
            mAction[iSumWid] = 1
            oSummon:StartAutoFight()
        end
    end

    if iAIType and iAIType > 0 then
        self:SetAIType(iAIType)
    end

    for iWid,_ in pairs(mAction) do
        if not oWar:GetBoutCmd(iWid) then
            local oAction = oWar:GetWarrior(iWid)
            oAction:AICommand()
        end
    end
end

function CPlayerWarrior:CancleAutoFight()
    self:SetAutoFight(nil)
    local oWar = self:GetWar()
    local iSumWid = self:Query("curr_sum")
    if oWar and iSumWid then
        local oSummon = oWar:GetWarrior(iSumWid)
        if oSummon then
            oSummon:CancleAutoFight()
        end
    end
end

function CPlayerWarrior:CheckYaoShenAddAura(iDamage, iOldHp)
    if iDamage <= 0 then return end
    if self:GetData("school") ~= gamedefines.PLAYER_SCHOOL.YAOSHEN then return end

    iDamage = math.max(0, math.min(iOldHp - self:GetHp(), iDamage))
    local iCnt = self:Query("damage_cnt", 0) + iDamage
    local iRatio = global.oActionMgr:GetWarConfig("yaoshen_aura_hp_ratio")
    -- 100保底 
    local iHp = math.max(math.floor(self:GetMaxHp() * iRatio / 100), 100)
    local iAura = iCnt // iHp
    if iAura > 0 then
        self:AddAura(iAura)
        iCnt = iCnt - iHp * iAura
    end
    self:Set("damage_cnt", iCnt)
end

function CPlayerWarrior:DoAfterInit()
    if self:GetData("school") == gamedefines.PLAYER_SCHOOL.YAOCHI then
        self:AddFunction("OnNewBout", 1, OnYaoChiAddAura)
    end

    if self:GetData("school") == gamedefines.PLAYER_SCHOOL.YAOSHEN then
        self:AddFunction("OnCalDamageResultRatio", 1, OnCalYaoShenDamageRatio)
    end
end

function CPlayerWarrior:GetUpdateInfo()
    return self.m_mUpdateInfo
end

function CPlayerWarrior:SetUpdateInfo(iType,id,mInfo)
    if iType == gamedefines.WAR_WARRIOR_TYPE.SUMMON_TYPE or iType == gamedefines.WAR_WARRIOR_TYPE.PARTNER_TYPE then
        if not self.m_mUpdateInfo[iType] then
            self.m_mUpdateInfo[iType] = {}
        end
        self.m_mUpdateInfo[iType][id]=mInfo
    end
end

function CPlayerWarrior:UpdateUpdateInfo()
    local mInfo = {hp = math.floor(self:GetData("hp")),mp = math.floor(self:GetData("mp"))}
    self.m_mUpdateInfo[self.m_iType]={}
    self.m_mUpdateInfo[self.m_iType][self.m_iPid] = mInfo
end

function CPlayerWarrior:AddUseDrugCnt(iType, iVal)
    if iType == 1 then
        self.m_iUseDrug1Cnt = self.m_iUseDrug1Cnt + iVal
        self:StatusChange("item_use_cnt1")    
    elseif iType == 2 then
        self.m_iUseDrug2Cnt = self.m_iUseDrug2Cnt + iVal
        self:StatusChange("item_use_cnt2")
    end
end

function CPlayerWarrior:GetUseDrugCnt(iType)
    if iType == 1 then
        return self.m_iUseDrug1Cnt
    elseif iType == 2 then
        return self.m_iUseDrug2Cnt
    end
    return 0
end

function CPlayerWarrior:NewBout()
    local oWar = self:GetWar()
    if not oWar then return end
    
    if self:QueryBoutArgs("buff_sp_add", 0) == 0 and self.m_oBuffMgr:HasClassBuff(gamedefines.BUFF_TYPE.CLASS_ABNORMAL) then
        self:AddBoutArgs("buff_sp_add", 1)
        self:AddSP(5)
    end
    if oWar:CurBout() > 0 then
        self:AddZhenQi(self:GetAddBoutZhenQi())
    end
    super(CPlayerWarrior).NewBout(self)
end

function CPlayerWarrior:RefreshPerformCD(...)
    local lPerform = table.pack(...)
    local lResult = {}
    for _, iPerform in ipairs(lPerform) do
        local oPerform = self:GetPerform(iPerform)
        if oPerform and oPerform:IsActive() then
            local mUnit = {
                pf_id = iPerform,
                cd = oPerform:GetData("CD"),
            }
            table.insert(lResult, mUnit)
        end
    end
    local mNet = {
        wid = self:GetWid(),
        war_id = self.m_iWarId,
        pflist = lResult,
    }
    self:Send("GS2CRefreshPerformCD", mNet)
end

