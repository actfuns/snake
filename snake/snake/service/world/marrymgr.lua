local global = require "global"
local skynet = require "skynet"
local interactive = require "base.interactive"
local res = require "base.res"
local record = require "public.record"

local gamedefines = import(lualib_path("public.gamedefines"))
local defines = import(service_path("offline.defines"))
local datactrl = import(lualib_path("public.datactrl"))
local gamedb = import(lualib_path("public.gamedb"))
local ops = import(service_path("marry.option"))
local mdefines = import(service_path("marry.defines"))
local divorce = import(service_path("marry.divorceobj"))
local npcxt = import(service_path("marry.npcxt"))
local analylog = import(lualib_path("public.analylog"))


function NewMarryMgr(...)
    return CMarryMgr:New(...)
end

local STATUS_NONE = 0
local STATUS_PAY_HALF = 1
local STATUS_PAY_ALL = 2
local STATUS_WEDDING = 3


CMarryMgr = {}
CMarryMgr.__index = CMarryMgr
CMarryMgr.m_sTableName = "marryinfo"
inherit(CMarryMgr, datactrl.CDataCtrl)

function CMarryMgr:New()
    local o = super(CMarryMgr).New(self)
    o:Init()
    return o
end

function CMarryMgr:Init()
    self.m_iMarryNo = 0
    self.m_oDivorce = {}

    self.m_iMarryStatus = STATUS_NONE
    self.m_iMarryApply = mdefines.MARRY_APPLY_NONE
    self.m_iMarryTime = 0
    self.m_iMarryType = 0
    self.m_mMarryPlayer = {}
    self.m_iWeddingTime = 0
    self.m_iScene = 0
    self.m_mPackWedding = {}
    self.m_mWeddingEnd = {}

    self.m_iDivorce = 0
    self.m_oPid2Divorce = {}
    self.m_mNpcXT = {}
    self.m_iNpcCntXT = 0
    self.m_mTest = {}
end

function CMarryMgr:Save()
    local mData = {}
    mData.marryno = self.m_iMarryNo
    mData.marryplayer = self.m_mMarryPlayer

    local lDivorce = {}
    for k, oDivorce in pairs(self.m_oDivorce) do
        table.insert(lDivorce, oDivorce:Save())
    end
    mData.divorceinfo = lDivorce
    mData.npccntxt = self:GetTotolNpcCntXT()
    return mData
end

function CMarryMgr:GetTotolNpcCntXT()
    local iCnt = self.m_iNpcCntXT
    iCnt = iCnt + table_count(self.m_mNpcXT)
    if self.m_iMarryType > 0 then
        iCnt = iCnt + self:GetSendCntXT(self.m_iMarryType) or 0
    end
    return iCnt
end

function CMarryMgr:Load(mData)
    if not mData then return end

    self.m_mMarryPlayer = mData.marryplayer or {}
    self.m_iMarryNo = mData.marryno or 0
    for _, m in pairs(mData.divorceinfo or {}) do
        if m.status ~= 0 then
            local oDivorce = divorce.NewDivorceObj()
            oDivorce:Load(m)
            self:AddDivorce(oDivorce)
        end
    end
    self.m_iNpcCntXT = mData.npccntxt or 0
end

function CMarryMgr:AfterLoad()
    self:CheckDivorce()
    self:RefreshMarryXT(mdefines.MARRY_XT_CNT_MOMENT)
    local func = function(iEvent, mData)
        self:OnEnterScene(mData.player, mData.scene)
    end
    local lScenes = global.oSceneMgr:GetSceneListByMap(mdefines.MARRY_MAPID)
    for _, oScene in pairs(lScenes) do
        oScene:AddEvent(self, gamedefines.EVENT.PLAYER_ENTER_SCENE, func)
    end
    global.oWorldMgr:AddEvent(self, gamedefines.EVENT.WORLD_SERVER_START_END, function (iEvent, mArgs)
        self:DoRebackPay()
        self:ResetMarryInfo()
    end)
end

function CMarryMgr:ConfigSaveFunc()
    self:ApplySave(function ()
        local oMarryMgr = global.oMarryMgr
        oMarryMgr:_CheckSaveDb()
    end)
end

function CMarryMgr:_CheckSaveDb()
    assert(not is_release(self), "_CheckSaveDb fail")
    assert(self:IsLoaded(), "marrymgr save fail: is loading")
    if not self:IsDirty() then return end
    
    self:SaveDb()
end

function CMarryMgr:SaveDb()
    local mInfo = {
        module = "globaldb",
        cmd = "SaveGlobal",
        cond = {name = self.m_sTableName},
        data = {data = self:Save()},
    }
    gamedb.SaveDb("marry", "common", "DbOperate", mInfo)
    self:UnDirty()
end

function CMarryMgr:LoadDb()
    local mInfo = {
        module = "globaldb",
        cmd = "LoadGlobal",
        cond = {name = self.m_sTableName},
    }
    gamedb.LoadDb("marry", "common", "DbOperate", mInfo,
    function(mRecord, mData)
        self:Load(mData.data)
        self:OnLoaded()
    end)
end

function CMarryMgr:DispatchMarryNo()
    self:Dirty()
    self.m_iMarryNo = self.m_iMarryNo + 1
    return self.m_iMarryNo
end

function CMarryMgr:DispatchDivorceNo()
    self.m_iDivorce = self.m_iDivorce + 1
    return self.m_iDivorce
end

function CMarryMgr:MergeFrom(mFromData)
    if not mFromData then return true end

    if mFromData.marryplayer then
        table_combine(self.m_mMarryPlayer, mFromData.marryplayer)   
    end

    for _, m in pairs(mFromData.divorceinfo or {}) do
        if m.status ~= 0 then
            local oDivorce = divorce.NewDivorceObj()
            oDivorce:Load(m)
            self:AddDivorce(oDivorce)
        end
    end
    
    self.m_iNpcCntXT = self.m_iNpcCntXT + (mFromData.npccntxt or 0)
    self:Dirty()
    return true
end

function CMarryMgr:OnLogin(oPlayer, bReEnter)
    if not bReEnter then
        self:CheckMarryDate(oPlayer)
    end

    self:OnEnterScene(oPlayer, oPlayer:GetNowScene())
    self:CheckOnLogin(oPlayer)
end

function CMarryMgr:CheckOnLogin(oPlayer)
    if self:IsMarry(oPlayer:GetPid()) then
        local iStatus = self:GetMarryStatus()
        if iStatus == STATUS_PAY_ALL or iStatus == STATUS_PAY_HALF then 
            local iPay = self.m_mMarryPlayer[oPlayer:GetPid()]
            local iSecond = self.m_iMarryTime + self:GetApplySeconds() - get_time()
            if iPay > 0 then
                self:GS2CMarryPayUI(oPlayer, iSecond, iStatus)
            else
                self:GS2CMarryConfirmUI(oPlayer, iSecond, iStatus)
            end
        end
    else
        self:CheckMarryPic(oPlayer)    
    end
end

function CMarryMgr:OnEnterScene(oPlayer, oScene)
    if not oScene or self.m_iScene ~= oScene:GetSceneId() then return end

    if self:GetMarryStatus() == STATUS_WEDDING then
        oPlayer:Send("GS2CMarryWedding", self:PackMarryWedding())
    end
end

function CMarryMgr:NewHour(mNow)
    local iHour = mNow.date.hour
    if iHour == 4 then
        self:CheckDivorce()
    end
end

function CMarryMgr:CheckDivorce()
    local lDivorce = table_key_list(self.m_oDivorce)
    for _,id in pairs(lDivorce) do
        local oDivorce = self:GetDivorceById(id)
        if oDivorce then
            oDivorce:CheckTimeCb()
        end
    end
end

function CMarryMgr:GetNpcOptions(oPlayer)
    local sText, lOptions = self:_GetNpcOptions2(oPlayer)
    local sOptions = ops.GetOptionsText(lOptions)
    return sText, sOptions, lOptions
end

function CMarryMgr:_GetNpcOptions2(oPlayer)
    local iStatus = oPlayer.m_oMarryCtrl:GetMarryStatus()
    if iStatus == mdefines.MARRY_STATUS.NONE then
        return nil, {ops.OPTION.ENGAGE, ops.OPTION.ENGAGE_INS, ops.OPTION.MARRY_INS}
    elseif iStatus == mdefines.MARRY_STATUS.ENGAGE then
        if global.oToolMgr:IsSysOpen("MARRY_SYS", oPlayer, true) then
            return nil, {ops.OPTION.MARRY, ops.OPTION.MARRY_INS, ops.OPTION.DIS_ENGAGE, ops.OPTION.DIS_ENGAGE_INS}
        else
            return nil, {ops.OPTION.DIS_ENGAGE, ops.OPTION.DIS_ENGAGE_INS}
        end
        
    elseif iStatus == mdefines.MARRY_STATUS.MARRY then
        return self:_GetMarryOptions(oPlayer)
    end
end

function CMarryMgr:_GetMarryOptions(oPlayer)
    local oDivorce = self:GetDivorceByPid(oPlayer:GetPid())

    local sText, lOptions = nil, {}
    if not oDivorce then
        sText = self:GetText(2031) 
        lOptions ={ops.OPTION.DIVORCE, ops.OPTION.FORCE_DIVORCE, ops.OPTION.DIVORCE_INS}
    else
        if oDivorce:Type() == mdefines.DIVORCE_TYPE.NOMAL then
            sText, lOptions = self:GetNomalDivorceOptions(oPlayer, oDivorce)
        else
            sText, lOptions = self:GetForceDivorceOptions(oPlayer, oDivorce)
        end
    end
    return sText, lOptions
end

function CMarryMgr:GetForceDivorceOptions(oPlayer, oDivorce)
    local sText, lOptions = nil, {}
    if oDivorce:Pid1() == oPlayer:GetPid() then
        if oDivorce:GetStatus() == mdefines.DIVORCE_STATUS.SUBMIT then
            sText = self:GetText(2026)
            lOptions = {ops.OPTION.DIVORCE_CON1, ops.OPTION.DIVORCE_CANCEL, ops.OPTION.DIVORCE_INS} 
        elseif oDivorce:GetStatus() == mdefines.DIVORCE_STATUS.CONFIRM then
            sText = self:GetText(2032)
            lOptions = {ops.OPTION.FORCE_DIVORCE_CON, ops.OPTION.DIVORCE_CANCEL, ops.OPTION.DIVORCE_INS}      
        end
    elseif oDivorce:Pid2() == oPlayer:GetPid() then
        if oDivorce:GetStatus() == mdefines.DIVORCE_STATUS.SUBMIT then
            local iCnt = self:GetLeftRefuseDivorceCnt(oPlayer)
            sText = self:GetText(2027, {count=math.max(iCnt, 0)})
            lOptions = {ops.OPTION.DIVORCE_REFUSE, ops.OPTION.DIVORCE_AGREE, ops.OPTION.DIVORCE_INS} 
            if iCnt <= 0 then
                lOptions = {ops.OPTION.DIVORCE_REFUSE2, ops.OPTION.DIVORCE_AGREE, ops.OPTION.DIVORCE_INS} 
            end
        elseif oDivorce:GetStatus() == mdefines.DIVORCE_STATUS.CONFIRM then
            sText = self:GetText(2033)
            lOptions = {ops.OPTION.DIVORCE_REFUSE2, ops.OPTION.DIVORCE_AGREE, ops.OPTION.DIVORCE_INS} 
        end
    end
    return sText, lOptions
end

function CMarryMgr:GetNomalDivorceOptions(oPlayer, oDivorce)
    local sText, lOptions = nil, {}
    if oDivorce:GetStatus() == mdefines.DIVORCE_STATUS.SUBMIT then
        sText = self:GetText(2031)
        lOptions = {ops.OPTION.DIVORCE_CON1, ops.OPTION.DIVORCE_CANCEL, ops.OPTION.DIVORCE_INS}
    elseif oDivorce:GetStatus() == mdefines.DIVORCE_STATUS.CONFIRM then
        sText = self:GetText(2031)
        lOptions ={ops.OPTION.DIVORCE_CON2, ops.OPTION.DIVORCE_CANCEL, ops.OPTION.DIVORCE_INS}
    end
    return sText, lOptions    
end

function CMarryMgr:DoOptionFunc(oPlayer, iFunc)
    local sfunc = ops.GetFunc(iFunc)
    assert(ops[sfunc], string.format("marry option error not func %s %s", iFunc, sfunc))
    ops[sfunc](oPlayer)
end

function CMarryMgr:ValidMarry(oPlayer)
    local oTeam = oPlayer:HasTeam()
    if not oTeam or not oPlayer:IsTeamLeader() or table_count(oTeam:AllMember()) ~= 2 then 
        return false, self:GetText(2034)
    end

    local oTarget = self:GetTeamOther(oPlayer)
    if not oTarget then
        return false, self:GetText(2034) 
    end

    local iMarryStatus = mdefines.MARRY_STATUS.MARRY
    if oPlayer.m_oMarryCtrl:GetMarryStatus() == iMarryStatus then
        return false, self:GetText(2035, {role=oPlayer:GetName()})
    end
    if oTarget.m_oMarryCtrl:GetMarryStatus() == iMarryStatus then
        return false, self:GetText(2035, {role=oTarget:GetName()})
    end

    if oPlayer:GetSex() == oTarget:GetSex() then
        return false, self:GetText(2036)
    end

    local iLimitGrade = self:GetLimitGrade()
    if oPlayer:GetGrade() < iLimitGrade then
        return false, self:GetText(2037, {role=oPlayer:GetName()})
    end
    if oTarget:GetGrade() < iLimitGrade then
        return false, self:GetText(2037, {role=oTarget:GetName()})
    end

    local iDegree = self:GetLimitDegree()
    if oPlayer:GetFriend():GetFriendDegree(oTarget:GetPid()) < iDegree 
        or oTarget:GetFriend():GetFriendDegree(oPlayer:GetPid()) < iDegree then
        return false, self:GetText(2038)
    end 

    if oPlayer:GetCouplePid() ~= oTarget:GetPid() then
        if oTarget:GetSex() == gamedefines.SEX_TYPE.SEX_MALE then
            return false, self:GetText(2039, {role=oTarget:GetName()})
        else
            return false, self:GetText(2040, {role=oTarget:GetName()})
        end
    end    

    local iLeft = self:GetLeftSecond()
    if iLeft > 0 then
        local oPlayer1, oPlayer2 = self:GetMarryPlayer()
        local sName1 = oPlayer1 and oPlayer1:GetName() or ""
        local sName2 = oPlayer2 and oPlayer2:GetName() or ""
        return false, self:GetText(2041, {role={sName1, sName2}, MM=iLeft//60, SS=iLeft%60})
    end
    return true
end

function CMarryMgr:GetTeamOther(oPlayer)
    local oTeam = oPlayer:HasTeam()
    if not oTeam then return end

    local lMemPid = oTeam:GetMemberPid()
    if #lMemPid ~= 2 then return end

    for _,iPid in pairs(lMemPid) do
        if iPid ~= oPlayer:GetPid() then
            return global.oWorldMgr:GetOnlinePlayerByPid(iPid)
        end
    end
end

function CMarryMgr:DoApplyMarry(oPlayer)
    local bRet, sMsg = self:ValidMarry(oPlayer)
    if not bRet then
        oPlayer:NotifyMessage(sMsg)
        return 
    end

    local oTarget = self:GetTeamOther(oPlayer)
    if not oTarget then return end

    local iSecond = self:GetApplySeconds()
    self:GS2CMarryPayUI(oPlayer, iSecond)
end

function CMarryMgr:PayForMarry(oPlayer, iFlag)
    local bRet, sMsg = self:ValidMarry(oPlayer)
    if not bRet then
        oPlayer:NotifyMessage(sMsg)
        return 
    end

    local oTarget = self:GetTeamOther(oPlayer)
    if not oTarget then return end

    local iStatus = STATUS_PAY_ALL
    local iSilver = self:GetMarrySilver()
    if iFlag <= 0 then
        iStatus = STATUS_PAY_HALF
        iSilver = math.floor(iSilver / 2)
    end

    if not oPlayer:ValidSilver(iSilver) then return end

    local iPid = oPlayer:GetPid()
    oPlayer:ResumeSilver(iSilver, "结婚支付")
    self:SetMarryInfo(oPlayer, oTarget)
    self:SetMarryStatus(iStatus)
    self.m_mMarryPlayer[iPid] = iSilver
    oPlayer:NotifyMessage(self:GetText(2043))
    local iSecond = self:GetApplySeconds()
    self:GS2CMarryPayUI(oPlayer, iSecond, iStatus)
    self:GS2CMarryConfirmUI(oTarget, iSecond, iStatus)

    self:DelTimeCb("_ResetMarryInfo")
    self:AddTimeCb("_ResetMarryInfo", iSecond * 1000, function ()
        self:DoMarryConfirmTimeOut(iPid)
    end)
end

function CMarryMgr:DoMarryConfirmTimeOut(iPid)
    self:DelTimeCb("_ResetMarryInfo")
    local oPlayer = global.oWorldMgr:GetOnlinePlayerByPid(iPid)
    self:DoRebackPay()
    if oPlayer then
        oPlayer:NotifyMessage(self:GetText(2064))
        self:GS2CMarryCancel(oPlayer)
    end
    local iOther = self:GetOtherMarryPid(iPid)
    local oOther = global.oWorldMgr:GetOnlinePlayerByPid(iOther)
    if oOther then
        oOther:NotifyMessage(self:GetText(2072)) 
        self:GS2CMarryCancel(oOther)       
    end
    self:ResetMarryInfo()
end

function CMarryMgr:DoRebackPay()
    for iPid, iPay in pairs(self.m_mMarryPlayer) do
        if iPay > 0 then
            local oPlayer = global.oWorldMgr:GetOnlinePlayerByPid(iPid)
            if oPlayer then
                oPlayer:RewardSilver(iPay, "结婚退还", {cancel_tip=true, cancel_chat=true})
            else
                local oPubMgr = global.oPubMgr
                oPubMgr:OnlineExecute(iPid, "RewardSilver", {iPay, "结婚退还"})
            end
        end
    end
end

function CMarryMgr:DoConfirmMarry(oPlayer, iFlag)
    local iStatus = self:GetMarryStatus()
    if iStatus ~= STATUS_PAY_ALL and iStatus ~= STATUS_PAY_HALF then return end
    local iPid = oPlayer:GetPid()
    local iPay = self.m_mMarryPlayer[iPid]
    if not iPay then return end

    local iOther, iOtherPay = self:GetOtherMarryPid(iPid)
    local oOther = global.oWorldMgr:GetOnlinePlayerByPid(iOther)
    if not oOther or iOtherPay <= 0 then return end

    if iFlag > 0 then
        if iStatus == STATUS_PAY_HALF then
            local iSilver = math.floor(self:GetMarrySilver() / 2)
            if not oPlayer:ValidSilver(iSilver) then return end

            oPlayer:ResumeSilver(iSilver, "确认结婚")
        end
        self:DoMarry(oOther, oPlayer)
        oPlayer:NotifyMessage(self:GetText(2073))
    else
        self:DoRebackPay()
        self:ResetMarryInfo()
        oPlayer:NotifyMessage(self:GetText(2065, {role=oOther:GetName()}))
        oOther:NotifyMessage(self:GetText(2066, {role=oPlayer:GetName()}))
        self:GS2CMarryCancel(oOther)
    end
end

function CMarryMgr:GS2CMarryPayUI(oPlayer, iSecond, iStatus)
    oPlayer:Send("GS2CMarryPayUI", {seconds=iSecond, status=iStatus})    
end

function CMarryMgr:GS2CMarryCancel(oPlayer)
    oPlayer:Send("GS2CMarryCancel", {})    
end

function CMarryMgr:GS2CMarryConfirmUI(oPlayer, iSecond, iStatus)
    oPlayer:Send("GS2CMarryConfirmUI", {seconds=iSecond, status=iStatus})    
end

function CMarryMgr:SetMarryInfo(oPlayer, oTarget)
    self.m_iMarryTime = get_time()
    self.m_iMarryType = oPlayer:GetEngageType()
    self.m_mMarryPlayer[oPlayer:GetPid()] = 0
    self.m_mMarryPlayer[oTarget:GetPid()] = 0
    self:Dirty()
end

function CMarryMgr:ResetMarryInfo()
    self:DelTimeCb("_ApplyMarryTimeOut")
    self:DelTimeCb("_ResetMarryInfo")
    self:DelTimeCb("_DoMarryWeddingEnd")

    self.m_iMarryStatus = STATUS_NONE
    self.m_iMarryApply = mdefines.MARRY_APPLY_NONE
    self.m_iMarryTime = 0
    self.m_iMarryType = 0
    self.m_mMarryPlayer = {}
    self.m_iWeddingTime = 0
    self.m_iScene = 0
    self.m_mPackWedding = {}
    self.m_mWeddingEnd = {}
    self:Dirty()
end

function CMarryMgr:GetLeftSecond()
    return self.m_iMarryTime + self:GetMarrySeconds() - get_time()
end

function CMarryMgr:GetMarryPlayer()
    local lPids = table_key_list(self.m_mMarryPlayer) 
    
    local oPlayer1 = global.oWorldMgr:GetOnlinePlayerByPid(lPids[1])
    local oPlayer2 = global.oWorldMgr:GetOnlinePlayerByPid(lPids[2])
    return oPlayer1, oPlayer2
end

function CMarryMgr:DoMarry(oPlayer, oTarget)
    self:DelTimeCb("_ApplyMarryTimeOut")
    self:DelTimeCb("_ResetMarryInfo")
    assert(oPlayer:GetCouplePid() == oTarget:GetPid(), 
        string.format("domarry error %s, %s", oPlayer:GetCouplePid(), oTarget:GetPid()))
    assert(oTarget:GetCouplePid() == oPlayer:GetPid(), 
        string.format("domarry error2 %s, %s", oTarget:GetCouplePid(), oPlayer:GetPid())) 

    local oTeam = oPlayer:HasTeam()
    if oTeam:AutoMatching() then
        interactive.Send(".autoteam", "team", "CancleTeamAutoMatch", {
            targetid = oTeam:GetTargetID(),
            teamid = oTeam:TeamID(),
        })
        oPlayer:NotifyMessage(self:GetText(1022))
    end
    
    self:OnSuccessMarry(oPlayer, oTarget)
    self:SendMarryReward(oPlayer, oTarget)
    self:SendMarryMsg(oPlayer, oTarget)
    self:ShowMarryWedding(oPlayer, oTarget)
end

function CMarryMgr:OnSuccessMarry(oPlayer, oTarget)
    local iMarryNo = self:DispatchMarryNo()
    oPlayer.m_oMarryCtrl:SetMarryRelation(iMarryNo)
    oTarget.m_oMarryCtrl:SetMarryRelation(iMarryNo)

    local oFriend = oPlayer:GetFriend()
    oFriend:ResetRelation(oTarget:GetPid(), defines.RELATION_ENGAGE)
    oFriend:SetRelation(oTarget:GetPid(), defines.RELATION_COUPLE)

    local oTarFriend = oTarget:GetFriend()
    oTarFriend:ResetRelation(oPlayer:GetPid(), defines.RELATION_ENGAGE)
    oTarFriend:SetRelation(oPlayer:GetPid(), defines.RELATION_COUPLE)

    local iTid = global.oEngageMgr:GetTitleBySex(oPlayer:GetSex())
    global.oTitleMgr:RemoveOneTitle(oPlayer:GetPid(), iTid)
    global.oTitleMgr:AddTitle(oPlayer:GetPid(), self:GetTitleBySex(oPlayer:GetSex()))

    local iTid = global.oEngageMgr:GetTitleBySex(oTarget:GetSex())
    global.oTitleMgr:RemoveOneTitle(oTarget:GetPid(), iTid)
    global.oTitleMgr:AddTitle(oTarget:GetPid(), self:GetTitleBySex(oTarget:GetSex()))

    for _,iSk in pairs(self:GetMarrySkills()) do
        oPlayer.m_oSkillCtrl:AddMarsySkill(iSk)
        oTarget.m_oSkillCtrl:AddMarsySkill(iSk)    
    end
    oPlayer.m_oSkillCtrl:GS2CMarrySkill(oPlayer)
    oPlayer:PropChange("engage_info")
    oTarget.m_oSkillCtrl:GS2CMarrySkill(oTarget)
    oTarget:PropChange("engage_info")
    self:SendShiZhuang(oPlayer)
    self:SendShiZhuang(oTarget)

    local iMarryType = oPlayer.m_oMarryCtrl:GetEngageType()
    self:LogData(oPlayer, "marry", {marry_type=iMarryType})
    self:LogData(oTarget, "marry", {marry_type=iMarryType})

    local iMale, iFemale, sMale, sFemale
    if oPlayer:GetSex() == gamedefines.SEX_TYPE.SEX_MALE then
        iMale, iFemale = oPlayer:GetPid(), oTarget:GetPid() 
        sMale, sFemale = oPlayer:GetName(), oTarget:GetName()
    else
        iFemale, iMale = oPlayer:GetPid(), oTarget:GetPid() 
        sFemale, sMale = oPlayer:GetName(), oTarget:GetName()
    end
    analylog.LogMarryInfo(oPlayer, iMale, sMale, iFemale, sFemale, iMarryType, 3)
end

function CMarryMgr:SendShiZhuang(oPlayer)
    local iRoleType = oPlayer.m_oBaseCtrl:GetRoleType()
    local iSZ = self:GetMarryShiZhuang(oPlayer.m_oMarryCtrl:GetEngageType(), iRoleType)
    assert(iSZ, string.format("shizhuang not find sKey RoleType:%s", iRoleType))
    local oWaiGuan = oPlayer.m_oBaseCtrl.m_oWaiGuan
    oWaiGuan:SetShiZhuangByID(iSZ, {opentime=mdefines.SZ_OPEN_TIME})
    oWaiGuan:SetCurSZ(iSZ)
    oWaiGuan:GS2CRefreshShiZhuang(iSZ)
    oPlayer:SyncModelInfo()
end

function CMarryMgr:SendMarryMsg(oPlayer, oTarget, iMarryNo)
    local iMarryNo = oPlayer.m_oMarryCtrl:GetMarryNo()
    local sHorse = self:GetText(2052, {role={oPlayer:GetName(), oTarget:GetName()}, count=iMarryNo})
    global.oChatMgr:HandleSysChat(sHorse, gamedefines.SYS_CHANNEL_TAG.RUMOUR_TAG, 1)
end

function CMarryMgr:SendMarryReward(oPlayer, oTarget)
    local iMarryTime = oPlayer.m_oMarryCtrl:GetMarryTime()
    local iMarryNo = oPlayer.m_oMarryCtrl:GetMarryNo()
    local sDate = get_time_format_str(iMarryTime, "%Y年%m月%d日")
    local iType = oPlayer.m_oMarryCtrl:GetEngageType()

    local oItem1 = global.oItemLoader:Create(mdefines.MARRY_ITEM_XT)
    oItem1:SetAmount(self:GetMarryCntXT(iType))
    local oItem2 = global.oItemLoader:Create(mdefines.MARRY_ITEM_XT)
    oItem2:SetAmount(self:GetMarryCntXT(iType))
    self:SendMail(oPlayer:GetPid(), 4009, {role=oTarget:GetName(), date=sDate, count=iMarryNo}, {oItem1})
    self:SendMail(oTarget:GetPid(), 4009, {role=oPlayer:GetName(), date=sDate, count=iMarryNo}, {oItem2})

    local oItem1 = global.oItemLoader:Create(mdefines.MARRY_ITEM_YH)
    oItem1:SetAmount(self:GetMarryCntYH(iType))
    local oItem2 = global.oItemLoader:Create(mdefines.MARRY_ITEM_YH)
    oItem2:SetAmount(self:GetMarryCntYH(iType))
    self:SendMail(oPlayer:GetPid(), 4010, {role=oTarget:GetName()}, {oItem1})
    self:SendMail(oTarget:GetPid(), 4010, {role=oPlayer:GetName()}, {oItem2})

    local lFriend1 = oPlayer:GetFriend():GetBothFriends()
    local lExtPid = {oPlayer:GetPid(), oTarget:GetPid()}
    local mReplace1 = {role={oPlayer:GetName(), oTarget:GetName()}, date=sDate, count=iMarryNo}
    global.oToolMgr:ExecuteList(lFriend1, 50, 500, 0, "SendMarryReward1", function (iPid)
        self:SendFriendMail(iPid, mReplace1, lExtPid)
    end)

    local lFriend2 = oTarget:GetFriend():GetBothFriends()
    local mReplace2 = {role={oTarget:GetName(), oPlayer:GetName()}, date=sDate, count=iMarryNo}
    global.oToolMgr:ExecuteList(lFriend2, 50, 500, 0, "SendMarryReward2", function (iPid)
        self:SendFriendMail(iPid, mReplace2, lExtPid)        
    end)
end

function CMarryMgr:SendFriendMail(iPid, mReplace, lExtPid)
    if table_in_list(lExtPid, iPid) then return end

    self:SendMail(iPid, 4011, mReplace)
end

------------------------婚礼--------------------------------
function CMarryMgr:ShowMarryWedding(oPlayer, oTarget)
    local oScene = oPlayer:GetNowScene()
    assert(oScene:MapId() == mdefines.MARRY_MAPID, string.format("ShowMarryWedding map error"))
    self.m_iWeddingTime = get_time()
    self.m_iScene = oScene:GetSceneId()
    self:SetPackMarryWedding(oPlayer, oTarget)
    self:SetMarryStatus(STATUS_WEDDING)

    local mNet = self:PackMarryWedding()
    oScene:BroadcastMessage("GS2CMarryWedding", mNet, {})

    local iType = oPlayer.m_oMarryCtrl:GetEngageType()
    self:AddTimeCb("_DoMarryWeddingEnd", self:GetWeddingSecond(iType) * 1000 + 1500, function ()
        global.oMarryMgr:_DoMarryWeddingEnd()
    end)
end

function CMarryMgr:SetPackMarryWedding(oPlayer, oTarget)
    self.m_mPackWedding = {
        marry_no = oPlayer.m_oMarryCtrl:GetMarryNo(),
        player1 = self:PackPlayer(oPlayer),
        player2 = self:PackPlayer(oTarget),    
        marry_type = oPlayer.m_oMarryCtrl:GetEngageType(),    
        wedding_time = self.m_iWeddingTime,    
    }
end

function CMarryMgr:PackPlayer(oPlayer)
    return {
        pid = oPlayer:GetPid(),
        name = oPlayer:GetName(),
        grade = oPlayer:GetGrade(),
        school = oPlayer:GetSchool(),
        sex = oPlayer:GetSex(),
        model_info = oPlayer:GetModelInfo(),
    }
end

function CMarryMgr:PackMarryWedding()
    local mNet = table_copy(self.m_mPackWedding)
    mNet.wedding_sec = get_time() - self.m_iWeddingTime
    return mNet 
end

function CMarryMgr:DoMarryWeddingEnd(oPlayer)
    local iPid = oPlayer:GetPid()
    if not self.m_mMarryPlayer[iPid] then return end

    self.m_mWeddingEnd[iPid] = true
    if table_count(self.m_mWeddingEnd) >= 2 then
        self:_DoMarryWeddingEnd()        
    end
end

function CMarryMgr:_DoMarryWeddingEnd()
    local oScene = self:GetScene(self.m_iScene)
    if oScene then
        oScene:BroadcastMessage("GS2CMarryWeddingEnd", {}, {})
    end
    self:DoFinishMarry()
end

function CMarryMgr:DoFinishMarry()
    local iCnt = self:GetSendCntXT(self.m_iMarryType)
    self.m_iNpcCntXT = self.m_iNpcCntXT + iCnt

    local oScene = self:GetScene(self.m_iScene)
    if oScene then
        oScene:BroadcastMessage("GS2CSysChat", {content = self:GetText(2056)}, {})
    end
    local oNpc = global.oNpcMgr:GetGlobalNpc(5229)
    if oNpc then
        oNpc:SpeekMsg(self:GetText(2056), 3)
    end 
    self:RefreshMarryXT(mdefines.MARRY_XT_CNT_MOMENT - table_count(self.m_mNpcXT), self.m_iScene)
    self:ResetMarryInfo()
end

--------------------------撒喜糖--------------------------------
function CMarryMgr:RefreshMarryXT(iCnt, iScene)
    if self.m_iNpcCntXT <= 0 or iCnt <= 0 then return end

    local oScene = self:GetScene(iScene)
    for i = 1, iCnt do 
        if self.m_iNpcCntXT <= 0 then break end

        self.m_iNpcCntXT = self.m_iNpcCntXT - 1
        local oNpc = self:CreateNpcXT()
        self.m_mNpcXT[oNpc:ID()] = oNpc
        global.oNpcMgr:AddObject(oNpc)
        oNpc:SetScene(oScene:GetSceneId())
        oScene:EnterNpc(oNpc)
    end
end

function CMarryMgr:TruePickMarryXT(oPlayer, iNpc, mData)
    if not mData or mData.answer ~= 1 then
        oPlayer:NotifyMessage(self:GetText(2076))
        return
    end
    local oNpc = self.m_mNpcXT[iNpc]
    if not oNpc then 
        oPlayer:NotifyMessage(self:GetText(2054))
        return 
    end

    oPlayer.m_oTodayMorning:Add("pick_marry_xt", 1)
    oPlayer:RewardItems(mdefines.MARRY_ITEM_XT, 1, "拾喜糖", {cancel_chat=true, cancel_tip=true})
    local iScene = oNpc:GetScene()
    self:RemoveNpcXT(oNpc:ID())
    oPlayer:NotifyMessage(self:GetText(2055))
    self:RefreshMarryXT(1, iScene)
    self:Dirty()
end

function CMarryMgr:PickMarryXT(oPlayer, oNpc)
    if not oNpc then return end
    if not self.m_mNpcXT[oNpc:ID()] then return end

    local iPickCnt = oPlayer.m_oTodayMorning:Query("pick_marry_xt", 0)
    if iPickCnt >= self:GetPickCntXT() then
        oPlayer:NotifyMessage(self:GetText(2050, {count=iPickCnt}))
        return
    end

    local mNet = {
        msg = self:GetText(2053),
        sec = mdefines.PICK_XT_PRO_SEC,
    }
    local iNpc = oNpc:ID()
    global.oCbMgr:SetCallBack(oPlayer:GetPid(), "GS2CShowProgressBar", mNet, nil, function(o, mData)
        self:TruePickMarryXT(o, iNpc, mData)
    end)
end

function CMarryMgr:RandomNpcPos()
    return math.random(490, 570)/10, math.random(240, 275)/10
end

function CMarryMgr:CreateNpcXT()
    local iX, iY = self:RandomNpcPos()
    local mArgs = {
        name = "喜糖",
        map_id = mdefines.MARRY_MAPID,
        model_info = global.oToolMgr:GetFigureModelData(mdefines.MARRY_XT_NPC),
        pos_info = {x=iX, y=iY, face_y=math.random(360)},
    }
    local oNpc = npcxt.NewNpcXT(mArgs)
    return oNpc
end

function CMarryMgr:RemoveNpcXT(iNpc)
    local oNpc = self.m_mNpcXT[iNpc]
    if not oNpc then return end

    local iScene = oNpc.m_Scene
    local oScene = self:GetScene(iScene)
    if oScene then
        oScene:RemoveSceneNpc(iNpc)
    end
    self.m_mNpcXT[iNpc] = nil
    global.oNpcMgr:RemoveObject(iNpc)
    baseobj_delay_release(oNpc)
end

function CMarryMgr:CancelMarry(oPlayer)
    local iPid = oPlayer:GetPid()
    local iPay = self.m_mMarryPlayer[iPid]
    if not iPay then return end

    local iOther, iOtherPay = self:GetOtherMarryPid(iPid)
    local oOther = global.oWorldMgr:GetOnlinePlayerByPid(iOther)
    if oOther then
        self:GS2CMarryCancel(oOther)
        oOther:NotifyMessage(self:GetText(2067, {role=oPlayer:GetName()}))
    end
    self:DoRebackPay()
    oPlayer:NotifyMessage(self:GetText(2074))
    self:GS2CMarryCancel(oPlayer)
    self:ResetMarryInfo()
end

function CMarryMgr:SetMarryPic(oPlayer, sUrl)
    if oPlayer.m_oMarryCtrl:GetMarryStatus() ~= mdefines.MARRY_STATUS.MARRY then return end

    oPlayer.m_oMarryCtrl:SetMarryPic(sUrl)
end

-------------------- 离婚申请 --------------------
function CMarryMgr:DoApplyDivorce(oPlayer)
    local bRet, sMsg = self:ValidDivorce(oPlayer)
    if not bRet then
        oPlayer:NotifyMessage(sMsg)
        return
    end

    local oTarget = self:GetTeamOther(oPlayer)
    local oDivorce = divorce.NewDivorceObj()
    oDivorce:Create(mdefines.DIVORCE_TYPE.NOMAL, oPlayer:GetPid(), oTarget:GetPid())
    self:AddDivorce(oDivorce)

    local mData = self:PackDivoreConfirm(oTarget)
    local fConfirm = function (o, m)
        self:DoApplyDivorce2(o, m.answer)
    end
    
    local oCbMgr = global.oCbMgr
    local iSession = oCbMgr:SetCallBack(oPlayer:GetPid(), "GS2CConfirmUI", mData, nil, fConfirm)
    oDivorce:SetSession(oPlayer:GetPid(), iSession)

    local mData = self:PackDivoreConfirm(oPlayer)
    local iSession = oCbMgr:SetCallBack(oTarget:GetPid(), "GS2CConfirmUI", mData, nil, fConfirm)
    oDivorce:SetSession(oTarget:GetPid(), iSession)
    oDivorce:SetApplyTimeCB(self:GetDivorceConfirm(), true)    
end

function CMarryMgr:DoApplyDivorce2(oPlayer, iAnswer)
    local iPid = oPlayer:GetPid()
    local oDivorce = self:GetDivorceByPid(iPid)
    if not oDivorce then return end

    local iTarget = oDivorce:OtherPid(iPid)
    local oTarget = global.oWorldMgr:GetOnlinePlayerByPid(iTarget)
    if not oTarget then return end

    if iAnswer == 1 then
        local mData = {}
        mData["sContent"] = self:GetText(2004)
        mData["time"] = self:GetDivorceConfirm()
        local iSession = global.oCbMgr:SetCallBack(oPlayer:GetPid(), "GS2CConfirmUI", mData, nil, function (o, m)
            -- pass
        end)
        oDivorce:SetSession(iPid, iSession)
        
        local mData = {}    
        mData["sContent"] = self:GetText(2005)
        mData["sConfirm"] = self:GetText(2007)
        mData["sCancle"] = self:GetText(2006)
        mData["time"] = self:GetDivorceConfirm()
        mData["close_btn"] = 1
        global.oCbMgr:SetCallBack(oTarget:GetPid(), "GS2CConfirmUI", mData, nil, function (o, m)
            self:DoApplyDivorce3(o, m.answer)
        end)
        oDivorce:SetApplyTimeCB(self:GetDivorceConfirm(), true)
    else
        self:DelDivorce(oDivorce)
        oTarget:NotifyMessage(self:GetText(2008, {role=oPlayer:GetName()}))
        local iSession = oDivorce:GetSession(oTarget:GetPid())
        self:GS2CCloseConfirmUI(oTarget, iSession)
    end
end

function CMarryMgr:DoApplyDivorce3(oPlayer, iAnswer)
    local iPid = oPlayer:GetPid()
    local oDivorce = self:GetDivorceByPid(iPid)
    if not oDivorce then return end

    local iTarget = oDivorce:OtherPid(iPid)
    local oTarget = global.oWorldMgr:GetOnlinePlayerByPid(iTarget)
    if not oTarget then return end
    
    if iAnswer == 1 then
        oDivorce:SetStatus(mdefines.DIVORCE_STATUS.SUBMIT)
        oDivorce:RemoveApplyTimeCB()
        local iSession = oDivorce:GetSession(oTarget:GetPid())
        self:GS2CCloseConfirmUI(oTarget, iSession)
    else
        self:DelDivorce(oDivorce)
        oTarget:NotifyMessage(self:GetText(2008, {role=oPlayer:GetName()}))
        local iSession = oDivorce:GetSession(oTarget:GetPid())
        self:GS2CCloseConfirmUI(oTarget, iSession)
    end
end

function CMarryMgr:DoApplyDivorceTimeOut(iDid, bRemove)
    local oDivorce = self:GetDivorceById(iDid)
    if not oDivorce then return end

    local iPid1 = oDivorce:Pid1()
    local oPlayer1 = global.oWorldMgr:GetOnlinePlayerByPid(iPid1)
    if oPlayer1 then
        oPlayer1:NotifyMessage(self:GetText(2009))
        local iSession = oDivorce:GetSession(iPid1)
        self:GS2CCloseConfirmUI(oPlayer1, iSession)
    end

    local iPid2 = oDivorce:Pid2()
    local oPlayer2 = global.oWorldMgr:GetOnlinePlayerByPid(iPid2)
    if oPlayer2 then
        oPlayer2:NotifyMessage(self:GetText(2009))
        local iSession = oDivorce:GetSession(iPid2)
        self:GS2CCloseConfirmUI(oPlayer2, iSession)
    end
    if bRemove then
        self:DelDivorce(oDivorce)
    end
end

function CMarryMgr:PackDivoreConfirm(oPlayer)
    local mData = {}
    mData["sContent"] = self:GetText(2003, {role=oPlayer:GetName()})
    mData["sConfirm"] = self:GetText(2007)
    mData["sCancle"] = self:GetText(2006)
    mData["time"] = self:GetDivorceConfirm()
    mData["default"] = 0                -- 默认按钮内容, 1-sConfirm 0-sCancle
    mData["extend_close"] = 0           -- 框外点击关闭 1-close
    mData["close_btn"] = 1              -- 0表示X按钮不发协议
    return mData
end

function CMarryMgr:ValidDivorce(oPlayer)
    local oTeam = oPlayer:HasTeam()
    local oTarget = self:GetTeamOther(oPlayer)
    if not oTeam or not oPlayer:IsTeamLeader() or not oTarget then 
        return false, self:GetText(2001)
    end
    if table_count(oTeam:AllMember()) ~= 2 then
        return false, self:GetText(2075)
    end

    local iMarryStatus = mdefines.MARRY_STATUS.MARRY
    if oPlayer.m_oMarryCtrl:GetMarryStatus() ~= iMarryStatus then
        return false, self:GetText(2001)
    end

    if oPlayer:GetCouplePid() ~= oTarget:GetPid() or oTarget:GetCouplePid() ~= oPlayer:GetPid() then
        return false, self:GetText(2001)
    end

    local iMarryTime = oPlayer.m_oMarryCtrl:GetMarryTime()
    if iMarryTime + self:GetDivorceSecond() > get_time() then
        return false, self:GetText(2002)
    end
    return true
end

----------------------确认离婚申请(提交期)--------------------------
function CMarryMgr:DoDivorceConfirm1(oPlayer)
    local iPid = oPlayer:GetPid()
    local oDivorce = self:GetDivorceByPid(iPid)
    if not oDivorce then return end

    if oDivorce:GetStatus() ~= mdefines.DIVORCE_STATUS.SUBMIT then return end

    local iApplyTime = oDivorce:GetApplyTime()
    local iTime = self:GetDivorceSumbitTime()
    local iLeftTime = iApplyTime + iTime - get_time()
    local iHour, iDay = 0, 0
    if iLeftTime > 0 then
        iHour = math.ceil(iLeftTime // 3600)
        iDay = math.floor(iHour/24)
        iHour = (iDay<=0) and math.max(1, iHour%24) or iHour%24
    end
    oPlayer:NotifyMessage(self:GetText(2010, {count={iDay, iHour}})) 
end

-----------------------取消离婚申请-------------------------
function CMarryMgr:DoDivorceCancel(oPlayer)
    local iPid = oPlayer:GetPid()
    local oDivorce = self:GetDivorceByPid(iPid)
    if not oDivorce then return end

    local mData = {}    
    mData["sContent"] = self:GetText(2011)
    mData["sConfirm"] = self:GetText(2012)
    mData["sCancle"] = self:GetText(2006)
    mData["time"] = self:GetDivorceConfirm()
    mData["close_btn"] = 1
    global.oCbMgr:SetCallBack(oPlayer:GetPid(), "GS2CConfirmUI", mData, nil, function (o, m)
        self:_DoDivorceCancel(o, m.answer)
    end)
end

function CMarryMgr:_DoDivorceCancel(oPlayer, iAnswer)
    local iPid = oPlayer:GetPid()
    local oDivorce = self:GetDivorceByPid(iPid)
    if not oDivorce then return end

    if iAnswer == 1 then
        self:DelDivorce(oDivorce)
        oPlayer:NotifyMessage(self:GetText(2013, {role=oPlayer:GetCoupleName()}))
        self:SendMail(oPlayer:GetCouplePid(), 4013)
    end   
end

----------------------确认离婚申请(确认期)--------------------------
function CMarryMgr:DoDivorceConfirm2(oPlayer)
    local bRet, sMsg = self:ValidDivorce(oPlayer)
    if not bRet then
        oPlayer:NotifyMessage(sMsg)
        return
    end    

    local oTarget = self:GetTeamOther(oPlayer)
    local oDivorce = self:GetDivorceByPid(oPlayer:GetPid())
    if not oDivorce then return end

    if oDivorce:GetStatus() ~= mdefines.DIVORCE_STATUS.CONFIRM then
        self:DelDivorce(oDivorce)
        record.warning(string.format("DoDivorceConfirm2 error PID:%s", oPlayer:GetPid()))
        return
    end 

    local mData = {}
    mData["sContent"] = self:GetText(2014)
    mData["sConfirm"] = self:GetText(2007)
    mData["sCancle"] = self:GetText(2006)
    mData["time"] = self:GetDivorceConfirm()
    mData["close_btn"] = 1

    local iTime = get_time()
    local fConfirm = function (o, m)
        self:DoDivorceConfirm22(o, m.answer, iTime)
    end
    
    local oCbMgr = global.oCbMgr
    local iSession1 = oCbMgr:SetCallBack(oPlayer:GetPid(), "GS2CConfirmUI", mData, nil, fConfirm)
    oDivorce:SetSession(oPlayer:GetPid(), iSession1)

    local iSession2 = oCbMgr:SetCallBack(oTarget:GetPid(), "GS2CConfirmUI", mData, nil, fConfirm)
    oDivorce:SetSession(oTarget:GetPid(), iSession2)
    -- oDivorce:SetApplyTimeCB(self:GetDivorceConfirm())    
end

function CMarryMgr:DoDivorceConfirm22(oPlayer, iAnswer, iTime)
    local oDivorce = self:GetDivorceByPid(oPlayer:GetPid())
    if not oDivorce then return end

    oDivorce:RemoveApplyTimeCB()    
    local iPid = oPlayer:GetPid()
    local iTarget = oDivorce:OtherPid(iPid)
    local oTarget = global.oWorldMgr:GetOnlinePlayerByPid(iTarget)
    if not oTarget then return end

    if iAnswer == 1 then
        local mData = {}
        mData["sContent"] = self:GetText(2016)
        mData["time"] = self:GetDivorceConfirm()
        local iSession = global.oCbMgr:SetCallBack(oPlayer:GetPid(), "GS2CConfirmUI", mData, nil, function (o, m)
            -- pass
        end)
        oDivorce:SetSession(iPid, iSession)
        
        local mData = {}    
        mData["sContent"] = self:GetText(2017)
        mData["sConfirm"] = self:GetText(2007)
        mData["sCancle"] = self:GetText(2006)
        mData["time"] = self:GetDivorceConfirm()
        mData["close_btn"] = 1
        local iSession = global.oCbMgr:SetCallBack(oTarget:GetPid(), "GS2CConfirmUI", mData, nil, function (o, m)
            self:DoDivorceConfirm23(o, m.answer)
        end)
        oDivorce:SetSession(iTarget, iSession)
        oDivorce:SetApplyTimeCB(self:GetDivorceConfirm())
    else
        if get_time() - iTime >= self:GetDivorceConfirm() then
            self:DoApplyDivorceTimeOut(oDivorce:DID())
        else
            oTarget:NotifyMessage(self:GetText(2015, {role=oPlayer:GetName()}))    
        end
        local iSession = oDivorce:GetSession(oTarget:GetPid())
        self:GS2CCloseConfirmUI(oTarget, iSession)
        global.oCbMgr:RemoveCallBack(iSession)
    end
end

function CMarryMgr:DoDivorceConfirm23(oPlayer, iAnswer)
    local oDivorce = self:GetDivorceByPid(oPlayer:GetPid())
    if not oDivorce then return end

    oDivorce:RemoveApplyTimeCB()
    local iPid = oPlayer:GetPid()
    local iTarget = oDivorce:OtherPid(iPid)
    local oTarget = global.oWorldMgr:GetOnlinePlayerByPid(iTarget)
    if not oTarget then return end

    if iAnswer == 1 then
        local iSession = oDivorce:GetSession(oTarget:GetPid())
        self:GS2CCloseConfirmUI(oTarget, iSession)
        self:LogDivorceInfo(oPlayer)
        self:OnSuccessDivorce(oPlayer)
        self:OnSuccessDivorce(oTarget)
        self:DelDivorce(oDivorce)
    else
        oTarget:NotifyMessage(self:GetText(2015, {role=oPlayer:GetName()}))
        local iSession = oDivorce:GetSession(oTarget:GetPid())
        self:GS2CCloseConfirmUI(oTarget, iSession)
    end    
end

function CMarryMgr:LogDivorceInfo(oPlayer)
    if oPlayer:GetCouplePid() <= 0 then return end

    local iMale, iFemale, sMale, sFemale
    if oPlayer:GetSex() == gamedefines.SEX_TYPE.SEX_MALE then
        iMale, iFemale = oPlayer:GetPid(), oPlayer:GetCouplePid()
        sMale, sFemale = oPlayer:GetName(), oPlayer:GetCoupleName()
    else
        iFemale, iMale = oPlayer:GetPid(), oPlayer:GetCouplePid()
        sFemale, sMale = oPlayer:GetName(), oPlayer:GetCoupleName()
    end
    local iMarryType = oPlayer:GetEngageType()
    analylog.LogMarryInfo(oPlayer, iMale, sMale, iFemale, sFemale, iMarryType, 4)
end

function CMarryMgr:OnSuccessDivorce(oPlayer, bForce)
    local oFriend = oPlayer:GetFriend()
    oFriend:ResetRelation(oPlayer:GetCouplePid(), defines.RELATION_COUPLE)

    local iTitle = self:GetTitleBySex(oPlayer:GetSex())
    global.oTitleMgr:RemoveOneTitle(oPlayer:GetPid(), iTitle)

    local mSkill = oPlayer.m_oSkillCtrl:GetMarrySkills()
    for iSk,_ in pairs(mSkill or {}) do
        oPlayer.m_oSkillCtrl:RemoveMarrySkill(iSk)
    end
    oPlayer.m_oSkillCtrl:GS2CMarrySkill(oPlayer)
    
    oFriend:ClearFriendDegree(oPlayer:GetCouplePid())
    oPlayer.m_oMarryCtrl:ResetRelation()
    oPlayer:PropChange("engage_info")

    oPlayer:NotifyMessage(self:GetText(2019))
    oPlayer:Send("GS2CSuccessDivorce", {})
    self:LogData(oPlayer, "divorce", {operate=(bForce and 1 or 0)})
    oPlayer:SyncSceneInfo({engage_pid=0})
end

function CMarryMgr:GS2CCloseConfirmUI(oPlayer, iSession)
    oPlayer:Send("GS2CCloseConfirmUI", {sessionidx=iSession})
end

----------------------强制离婚--------------------------
function CMarryMgr:DoForceDivorce(oPlayer)
    local bRet, sMsg = self:ValidForceDivorce(oPlayer)
    if not bRet then
        oPlayer:NotifyMessage(sMsg)
        return
    end

    local mData = {}    
    mData["sContent"] = self:GetText(2022)
    mData["sConfirm"] = self:GetText(2024)
    mData["sCancle"] = self:GetText(2023)
    mData["time"] = self:GetForceConfirmTime()
    mData["close_btn"] = 1
    global.oCbMgr:SetCallBack(oPlayer:GetPid(), "GS2CConfirmUI", mData, nil, function (o, m)
        self:_DoForceDivorce(o, m.answer)
    end)
end

function CMarryMgr:_DoForceDivorce(oPlayer, iAnswer)
    if iAnswer ~= 1 then return end

    if not self:ValidForceDivorce(oPlayer) then return end

    local iSilver = self:GetForceDivorceSilver()
    if not oPlayer:ValidSilver(iSilver) then
        -- TODO
        return 
    end

    oPlayer:ResumeSilver(iSilver, "强制离婚")
    local iTarget = oPlayer:GetCouplePid()
    local oDivorce = divorce.NewDivorceObj()
    oDivorce:Create(mdefines.DIVORCE_TYPE.FORCE, oPlayer:GetPid(), iTarget)
    self:AddDivorce(oDivorce)
    oDivorce:SetStatus(mdefines.DIVORCE_STATUS.SUBMIT)
    oPlayer.m_oMarryCtrl:SetForceDivorceTime()

    local iTime = get_time()
    local oTarget = global.oWorldMgr:GetOnlinePlayerByPid(iTarget)
    local sName = oPlayer:GetName()
    if oTarget then
        self:_DoForceDivorce2(oTarget, iTime, sName)                
    else
        global.oPubMgr:OnlineExecute(iTarget, "DoForceDivorce", {iTime, sName})
    end
    oPlayer:NotifyMessage(self:GetText(2025))
end

function CMarryMgr:_DoForceDivorce2(oPlayer, iTime, sCouple)
    local oMailMgr = global.oMailMgr
    local iCnt = self:GetLeftRefuseDivorceCnt(oPlayer)
    
    local iMail = 4016
    if iCnt > 0 then iMail = 4015 end
    
    local mData, sName = oMailMgr:GetMailInfo(iMail) 
    if mData then
        local oToolMgr = global.oToolMgr
        local sDate = get_time_format_str(iTime + self:GetDivorceSumbitTime(), "%Y年%m月%d日 %H:%M:%S")
        local mInfo = table_copy(mData)
        mInfo.context = oToolMgr:FormatColorString(mInfo.context, {role=sCouple, count=iCnt, date=sDate})
        mInfo.createtime = iTime
        oMailMgr:SendMail(0, sName, oPlayer:GetPid(), mInfo, 0)
    end
end

function CMarryMgr:ValidForceDivorce(oPlayer)
    if self:GetDivorceByPid(oPlayer:GetPid()) then 
        return false, self:GetText(2021)
    end

    local iMarryStatus = mdefines.MARRY_STATUS.MARRY
    if oPlayer.m_oMarryCtrl:GetMarryStatus() ~= iMarryStatus then
        return false, self:GetText(2021)
    end

    local iMarryTime = oPlayer.m_oMarryCtrl:GetMarryTime()
    if iMarryTime + self:GetDivorceSecond() > get_time() then
        return false, self:GetText(2002)
    end

    local iForceTime = oPlayer.m_oMarryCtrl:GetForceDivorceTime()
    local iLeftTime = iForceTime + self:GetForceDivorceTime() - get_time()
    if iLeftTime > 0 then
        return false, self:GetText(2020, {count=math.ceil(iLeftTime/60)})
    end
    return true
end

----------------------同意离婚(强制离婚)--------------------------
function CMarryMgr:DoAgreeDivorce(oPlayer)
    local oDivorce = self:GetDivorceByPid(oPlayer:GetPid())
    if not oDivorce then return end

    if oDivorce:Pid2() ~= oPlayer:GetPid() then return end

    if oDivorce:Type() ~= mdefines.DIVORCE_TYPE.FORCE then
        oPlayer:NotifyMessage(self:GetText(2021))
        return
    end

    local iTarget = oPlayer:GetCouplePid()
    self:DelDivorce(oDivorce)
    self:LogDivorceInfo(oPlayer)
    self:OnSuccessDivorce(oPlayer, true)

    local oTarget = global.oWorldMgr:GetOnlinePlayerByPid(iTarget)
    if oTarget then
        self:OnSuccessDivorce(oTarget, true)
    else
        global.oPubMgr:OnlineExecute(iTarget, "OnSuccessDivorce", {})
    end
    self:SendMail(iTarget, 4018, {role=oPlayer:GetName()})
end

----------------------拒绝离婚(强制离婚)--------------------------
function CMarryMgr:DoRefuseDivorce(oPlayer)
    local oDivorce = self:GetDivorceByPid(oPlayer:GetPid())
    if not oDivorce then return end

    if oDivorce:GetStatus() ~= mdefines.DIVORCE_STATUS.SUBMIT then
        oPlayer:NotifyMessage(self:GetText(2029))
        return
    end

    local iCnt = self:GetLeftRefuseDivorceCnt(oPlayer)
    if iCnt <= 0 then
        oPlayer:NotifyMessage(self:GetText(2028))
        return
    end

    oPlayer.m_oMarryCtrl:AddResDivorceCnt(1)
    self:DelDivorce(oDivorce)
    oPlayer:NotifyMessage(self:GetText(2030))

    local iPid = oPlayer:GetCouplePid()
    self:SendMail(iPid, 4017, {role=oPlayer:GetName()})
end

----------------------确认离婚(强制离婚)--------------------------
function CMarryMgr:DoForceDivorceConFirm(oPlayer)
    local oDivorce = self:GetDivorceByPid(oPlayer:GetPid())
    if not oDivorce then return end

    if oDivorce:Pid1() ~= oPlayer:GetPid() then return end

    if oDivorce:Type() ~= mdefines.DIVORCE_TYPE.FORCE then
        oPlayer:NotifyMessage(self:GetText(2021))
        return
    end
    if oDivorce:GetStatus() ~= mdefines.DIVORCE_STATUS.CONFIRM then
        oPlayer:NotifyMessage(self:GetText(2021))
        return
    end

    local mData = {}    
    mData["sContent"] = self:GetText(2014) 
    mData["sConfirm"] = self:GetText(2007)
    mData["sCancle"] = self:GetText(2006)
    mData["time"] = self:GetDivorceConfirm()
    mData["close_btn"] = 1
    global.oCbMgr:SetCallBack(oPlayer:GetPid(), "GS2CConfirmUI", mData, nil, function (o, m)
        self:_DoForceDivorceConFirm(o, m.answer)
    end)
end

function CMarryMgr:_DoForceDivorceConFirm(oPlayer, iAnswer)
    if iAnswer ~= 1 then return end

    local oDivorce = self:GetDivorceByPid(oPlayer:GetPid())
    if not oDivorce then return end

    if oDivorce:GetStatus() ~= mdefines.DIVORCE_STATUS.CONFIRM then
        oPlayer:NotifyMessage(self:GetText(2021))
        return
    end

    local iTarget = oPlayer:GetCouplePid()
    self:DelDivorce(oDivorce)
    self:LogDivorceInfo(oPlayer)
    self:OnSuccessDivorce(oPlayer)

    local oTarget = global.oWorldMgr:GetOnlinePlayerByPid(iTarget)
    if oTarget then
        self:OnSuccessDivorce(oTarget)
    else
        global.oPubMgr:OnlineExecute(iTarget, "OnSuccessDivorce", {})
    end
end

----------------------离婚timeout--------------------------
function CMarryMgr:DoDivorceConfirmTimeOut(iDid)
    local oDivorce = self:GetDivorceById(iDid)
    if not oDivorce then return end

    if oDivorce:Type() == mdefines.DIVORCE_TYPE.NOMAL then
        self:SendMail(oDivorce:Pid1(), 4014)
        self:SendMail(oDivorce:Pid2(), 4014)
    else
        local iPid1 = oDivorce:Pid1()
        local iPid2 = oDivorce:Pid2()
        self:SendMail(iPid1, 4019)
        global.oWorldMgr:LoadProfile(iPid1, function (oProfile)
            if oProfile then
                global.oMarryMgr:SendMail(iPid2, 4020, {role=oProfile:GetName()})
            end
        end)

    end
    self:DelDivorce(oDivorce)    
end

function CMarryMgr:SendMail(iPid, iMail, mReplace, items)
    local oMailMgr = global.oMailMgr
    local mData, sName = oMailMgr:GetMailInfo(iMail)
    if not mData then return end

    local mInfo = table_copy(mData)
    if mReplace then
        mInfo.context = global.oToolMgr:FormatColorString(mInfo.context, mReplace)
    end
    oMailMgr:SendMail(0, sName, iPid, mInfo, 0, items)
end

function CMarryMgr:AddDivorce(oDivorce)
    self.m_oDivorce[oDivorce:DID()] = oDivorce
    self.m_oPid2Divorce[oDivorce:Pid1()] = oDivorce
    self.m_oPid2Divorce[oDivorce:Pid2()] = oDivorce
    oDivorce:CheckTimeCb()

    self:Dirty()
end

function CMarryMgr:DelDivorce(oDivorce)
    self.m_oDivorce[oDivorce:DID()] = nil
    self.m_oPid2Divorce[oDivorce:Pid1()] = nil
    self.m_oPid2Divorce[oDivorce:Pid2()] = nil
    baseobj_delay_release(oDivorce)
    self:Dirty()
end

function CMarryMgr:GetDivorceById(iId)
    return self.m_oDivorce[iId]
end

function CMarryMgr:GetDivorceByPid(iPid)
    return self.m_oPid2Divorce[iPid]
end

function CMarryMgr:GetOtherMarryPid(iPid)
    if not self.m_mMarryPlayer[iPid] then return end

    for pid,iPay in pairs(self.m_mMarryPlayer) do
        if pid ~= iPid then
            return pid, iPay
        end
    end
end

function CMarryMgr:IsMarry(iPid)
    return self.m_mMarryPlayer[iPid]
end

function CMarryMgr:SetMarryStatus(iStatus)
    self.m_iMarryStatus = iStatus
end

function CMarryMgr:GetMarryStatus()
    return self.m_iMarryStatus
end

function CMarryMgr:GetLeftRefuseDivorceCnt(oPlayer)
    return self:GetResForceDivorceCnt() - oPlayer.m_oMarryCtrl:GetResDivorceCnt()
end

function CMarryMgr:GetScene(iScene)
    if iScene then
        return global.oSceneMgr:GetScene(iScene)
    end
    return global.oSceneMgr:GetSceneListByMap(mdefines.MARRY_MAPID)[1]
end

function CMarryMgr:PresentPlayerXT(oPlayer, iTarget, iAmount, sContent)
    if iAmount <= 0 then return end

    local iPid = oPlayer:GetPid()
    global.oWorldMgr:LoadProfile(iTarget, function (oProfile)
        if oProfile then
            self:_PresentPlayerXT(iPid, oProfile, iAmount, sContent)
        end
    end)
end

function CMarryMgr:_PresentPlayerXT(iPid, oProfile, iAmount, sContent)
    local oPlayer = global.oWorldMgr:GetOnlinePlayerByPid(iPid)
    if not oPlayer then return end

    if oPlayer.m_oItemCtrl:GetUnBindItemAmount(mdefines.MARRY_ITEM_XT) < iAmount then
        oPlayer:NotifyMessage(self:GetText(2051))              
        return 
    end

    local iRecCnt = oProfile:QueryTodayMorning("receive_marry_xt", 0)
    local iCanRec = self:GetReceiveCntXT()
    if iRecCnt >= iCanRec then
        oPlayer:NotifyMessage(self:GetText(2049, {role=oProfile:GetName(), count=iCanRec}))
        return
    end
    if iAmount + iRecCnt > iCanRec then
        oPlayer:NotifyMessage(self:GetText(2048, {role = oProfile:GetName(), count = {iRecCnt, iCanRec-iRecCnt}}))
        return
    end

    local oMailMgr = global.oMailMgr
    local mData, _ = oMailMgr:GetMailInfo(4021)
    local mInfo = table_copy(mData)
    mInfo.context = sContent or mInfo.context
    local oItem = global.oItemLoader:Create(mdefines.MARRY_ITEM_XT)
    oItem:SetAmount(iAmount)
    oItem:Bind(oProfile:GetPid())
    oPlayer.m_oItemCtrl:RemoveUnBindItemAmount(mdefines.MARRY_ITEM_XT, iAmount, "赠送喜糖")    
    oMailMgr:SendMail(oPlayer:GetPid(), oPlayer:GetName(), oProfile:GetPid(), mInfo, 0, {oItem})
    oProfile:AddTodayMorning("receive_marry_xt", iAmount)
end

function CMarryMgr:CheckMarryDate(oPlayer)
    local iMarryTime = oPlayer.m_oMarryCtrl:GetMarryTime()
    if not oPlayer or iMarryTime <= 0 then return end

    local m1 = get_timetbl()
    local m2 = get_timetbl(iMarryTime)
    local iYear = m1.date.year - m2.date.year
    if iYear <= 0 then return end
    
    if m1.date.month < m2.date.month or m1.date.day < m2.date.day then
        iYear = iYear - 1
    end

    local iModNo = oPlayer.m_oMarryCtrl:GetModNo()
    if iYear <= iModNo then return end

    local iTime = get_str2timestamp(string.format("%d-%d-%d", m2.date.year+iYear, m2.date.month, m2.date.day)) 
    oPlayer.m_oMarryCtrl:SetModNo(iYear)
    self:SendMarryDateMail(oPlayer, iYear, iTime)
end

function CMarryMgr:SendMarryDateMail(oPlayer, iYear, iTime)
    local oItem = global.oItemLoader:Create(mdefines.MARRY_ITEM_XT)
    oItem:SetAmount(self:GetMarryDateXTAmount())

    local sRole = oPlayer.m_oMarryCtrl:GetCoupleName()
    local iMarryNo = oPlayer.m_oMarryCtrl:GetMarryNo()

    local oMailMgr = global.oMailMgr
    local mData, sName = oMailMgr:GetMailInfo(4012)
    local mInfo = table_copy(mData)
    mInfo.createtime = iTime
    mInfo.context = global.oToolMgr:FormatColorString(mInfo.context, {role=sRole, count={iMarryNo, iYear}})
    oMailMgr:SendMail(0, sName, oPlayer:GetPid(), mInfo, 0, {oItem})
end

function CMarryMgr:CheckMarryPic(oPlayer)
    local iPid = oPlayer:GetPid()
    if self:IsMarry(iPid) then return end
    if oPlayer.m_oMarryCtrl:GetMarryStatus() ~= mdefines.MARRY_STATUS.MARRY then return end
    if oPlayer.m_oMarryCtrl:GetMarryPic() then return end

    local iCouplePid = oPlayer.m_oMarryCtrl:GetCouplePid()
    if not iCouplePid or iCouplePid <= 0 then return end

    global.oWorldMgr:LoadProfile(iCouplePid, function (oProfile)
        if oProfile then
            self:SendMarryPicInfo(iPid, oProfile)
        end
    end)
end

function CMarryMgr:SendMarryPicInfo(iPid, oProfile)
    local oPlayer = global.oWorldMgr:GetOnlinePlayerByPid(iPid)
    if not oPlayer then return end

    local mNet = {}
    mNet.marry_no = oPlayer.m_oMarryCtrl:GetMarryNo()
    mNet.player1 = self:PackPlayer(oPlayer)
    mNet.player2 = {
        pid = oProfile:GetPid(),
        name = oProfile:GetName(),
        grade = oProfile:GetGrade(),
        school = oProfile:GetSchool(),
        sex = (oPlayer:GetSex()==gamedefines.SEX_TYPE.SEX_MALE) and gamedefines.SEX_TYPE.SEX_MALE or gamedefines.SEX_TYPE.SEX_FEMALE,
        model_info = oProfile:GetModelInfo(),
    }
    mNet.marry_type = oPlayer.m_oMarryCtrl:GetEngageType()
    mNet.wedding_time = 0
    oPlayer:Send("GS2CMarryWedding", mNet)
end

function CMarryMgr:TeamShowWedding(oPlayer)
    local oTeam = oPlayer:HasTeam()
    if not oTeam then return end

    for _,iPid in pairs(oTeam:GetMemberPid()) do
        local oMember = global.oWorldMgr:GetOnlinePlayerByPid(iPid)
        if oMember then
            oMember:Send("GS2CTeamShowWedding", {})
        end
    end
end

-----------------------------------
function CMarryMgr:LogData(oPlayer, sSubType, mLog)
    mLog = mLog or {}
    mLog = table_combine(mLog, oPlayer:LogData())
    record.log_db("marry", sSubType, mLog)
end

function CMarryMgr:GetText(iText, mReplace)
    return global.oToolMgr:GetSystemText({"engage"}, iText, mReplace)
end

function CMarryMgr:GetConfigValue(sKey)
    if self.m_mTest[sKey] then
        return self.m_mTest[sKey]
    end
    local mData = res["daobiao"]["engage"]["config"][1]
    return mData[sKey]
end

function CMarryMgr:GetTitleBySex(iSex)
    return mdefines.MARRY_TITLE_ID[iSex]
end

function CMarryMgr:GetMarrySkills()
    return self:GetConfigValue("marry_skill")
end

function CMarryMgr:GetLimitGrade()
    local mData = res["daobiao"]["open"]["MARRY_SYS"]
    return mData["p_level"] 
end

function CMarryMgr:GetLimitDegree()
    return self:GetConfigValue("marry_friend_degree")
end

function CMarryMgr:GetMarrySeconds()
    return self:GetConfigValue("marry_time")
end

function CMarryMgr:GetMarrySilver()
    return self:GetConfigValue("marry_silver")
end

function CMarryMgr:GetApplySeconds()
    return self:GetConfigValue("marry_apply_time")
end

function CMarryMgr:GetDivorceConfirm()
    return self:GetConfigValue("divorce_confirm_ui")
end

function CMarryMgr:GetDivorceSecond()
    return self:GetConfigValue("can_divorce_time")*24*3600
end

function CMarryMgr:GetDivorceConfirmTime()
    return self:GetConfigValue("divorce_confirm_time") 
end

function CMarryMgr:GetDivorceSumbitTime()
    return self:GetConfigValue("divorce_submit_time")
end

function CMarryMgr:GetForceDivorceTime()
    return self:GetConfigValue("force_divorce_inv")
end

function CMarryMgr:GetForceDivorceSilver()
    return self:GetConfigValue("force_divorce_silver")
end

function CMarryMgr:GetForceConfirmTime()
    return self:GetConfigValue("force_divorce_ui")
end

function CMarryMgr:GetResForceDivorceCnt()
    return self:GetConfigValue("refuse_divorce_cnt")
end

function CMarryMgr:GetMarryCntXT(iType)
    local mData = res["daobiao"]["engage"]["engagetype"][iType]
    return mData["xt_cnt"]
end

function CMarryMgr:GetMarryCntYH(iType)
    local mData = res["daobiao"]["engage"]["engagetype"][iType]
    return mData["yh_cnt"]
end

function CMarryMgr:GetMarryShiZhuang(iType, iRoleType)
    local mData = res["daobiao"]["engage"]["engagetype"][iType]
    for _,m in pairs(mData["marry_sz"]) do
        if m.role == iRoleType then
            return m.sz
        end
    end
end

function CMarryMgr:GetReceiveCntXT()
    return self:GetConfigValue("rec_xt_cnt")
end

function CMarryMgr:GetPickCntXT()
    return self:GetConfigValue("pick_xt_cnt")
end

function CMarryMgr:GetSendCntXT(iType)
    local mData = res["daobiao"]["engage"]["engagetype"][iType]
    return mData["send_xt_cnt"]
end

function CMarryMgr:GetWeddingSecond(iType)
    local mData = res["daobiao"]["engage"]["engagetype"][iType]
    return mData["wedding_sec"]
end

function CMarryMgr:GetMarryDateXTAmount()
    return self:GetConfigValue("mod_xt_cnt")
end

