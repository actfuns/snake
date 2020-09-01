--import module
local global = require "global"
local skynet = require "skynet"
local net = require "base.net"
local interactive = require "base.interactive"
local res = require "base.res"
local record = require "public.record"
local router = require "base.router"
local playersend = require "base.playersend"

local playerobj = import(service_path("playerobj"))
local gamedb = import(lualib_path("public.gamedb"))
local gamedefines = import(lualib_path("public.gamedefines"))


function NewPlayer(...)
    local o = CPlayer:New(...)
    return o
end


CPlayer = {}
CPlayer.__index = CPlayer
inherit(CPlayer, playerobj.CPlayer)

function CPlayer:New(mConn, mRole)
    local o = super(CPlayer).New(self, mConn, mRole)
    o.m_bSaveSuccess = true
    return o
end

function CPlayer:OnLogin(bReEnter)
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
    oProfile:OnLogin(self,bReEnter)
    oFriend:OnLogin(self,bReEnter)
    oPrivacy:OnLogin(self,bReEnter)
    oWanfaCtrl:OnLogin(self,bReEnter)
    oJJCCtrl:OnLogin(self,bReEnter)
    self.m_oWingCtrl:OnLogin(self,bReEnter)
    global.oScoreCache:RemoveExclude(self:GetPid())

    self:GS2CLoginRole()
    self.m_fHeartBeatTime = get_time()

    oWorldMgr:OnLogin(self, bReEnter)

    self:OnLoginEnterScene(bReEnter)

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

    local oInterfaceMgr = global.oInterfaceMgr
    oInterfaceMgr:OnLogin(self, bReEnter)

    local oHuodongMgr = global.oHuodongMgr
    oHuodongMgr:OnLogin(self,bReEnter)

    self:RegisterClientUpdate()
    self:SyncRoleData2DataCenter()

    if not bReEnter then
        -- global.oPayMgr:DealUntreatedOrder(self)
        -- global.oMergerMgr:OnLogin(self)
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
    end, 120*1000)
end


function CPlayer:SaveModuleDb(mSave, sModule)
    if self.m_lAllSave then
        table.insert(self.m_lAllSave, {mSave, sModule})
        return
    end
    if (self.m_iForbidSaveTime or 0) > get_time() then
        return
    end

    local iPid = self:GetPid()
    local sServerKey = self:GetNowServer()
    if global.oServerMgr:IsConnect(sServerKey) then
        self:RemoteSaveModuleDb(mSave)
        if sModule then
            self[sModule]:UnDirty()
        else
            self:UnDirty()
        end
    else
        gamedb.SaveDb2File(iPid, mSave)
        self.m_bSaveSuccess = false
        record.warning(string.format("Player SaveModuleDb error PID:%s, Module:%s SK:%s", iPid, sModule, sServerKey))
    end
end

function CPlayer:RemoteSaveModuleDb(mSave)
    local sServerKey = self:GetNowServer()
    local iPid = self:GetPid()
    router.Send(sServerKey, ".world", "kuafu_gs", "KS2GSSaveModule", {
        pid = iPid,
        module_save = mSave,
    })
end

function CPlayer:SaveOfflineDb()
end

function CPlayer:SetForbidSaveTime(iTime)
    self.m_iForbidSaveTime = iTime
end

function CPlayer:GetAllSaveData()
    self.m_lAllSave = {}
    self:SaveDb(true)
    if not next(self.m_lAllSave) then
        self.m_lAllSave = nil
        return nil
    end

    local lAllSave = self.m_lAllSave
    self.m_lAllSave = nil
    return lAllSave
end

function CPlayer:OnScoreChange(iScore)
end

function CPlayer:GetOrgStatus()
    return 0
end

function CPlayer:OnLogout()
    self.m_mTempItemCtrl:OnLogout()
    self.m_oTaskCtrl:OnLogout()
    self.m_oSummonCtrl:OnLogout(self)
    local oWarMgr = global.oWarMgr
    oWarMgr:OnLogout(self)

    local oTeam = self:HasTeam()
    if oTeam then
        oTeam:Leave(self:GetPid())
    end
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
    -- local oProfile = self:GetProfile()
    -- oProfile:OnLogout(self)
    -- local oFriend = self:GetFriend()
    -- oFriend:OnLogout(self)
    -- local oJJCCtrl = self:GetJJC()
    -- oJJCCtrl:OnLogout(self)
    -- local oChallenge = self:GetChallenge()
    -- oChallenge:OnLogout(self)
    -- local oWanfaCtrl = self:GetWanfaCtrl()
    -- oWanfaCtrl:OnLogout(self)
    local oInterfaceMgr = global.oInterfaceMgr
    oInterfaceMgr:OnLogout(self)
    local oWorldMgr = global.oWorldMgr
    oWorldMgr:SetPlayerByShowId(self:GetShowId(), nil)

    self:UnRegisterClientUpdate()

    self.m_oActiveCtrl:SetDisconnectTime()
    --self:DoSave()
end

function CPlayer:LoginEnd(bReEnter)
    super(CPlayer).LoginEnd(self, bReEnter)
    self:DoSucessLogin2GS()
    self:DoHeartBeat2GS()
end

function CPlayer:DoHeartBeat2GS()
    local iPid = self:GetPid()
    local f
    f = function ()
        local oPlayer = global.oWorldMgr:GetOnlinePlayerByPid(iPid)
        if oPlayer then
            local iSecond = gamedefines.KS_PLAYER_HT_INTERVAL
            oPlayer:DelTimeCb("_DoHeartBeat2GS")
            oPlayer:AddTimeCb("_DoHeartBeat2GS", iSecond*1000, f)
            oPlayer:_DoHeartBeat2GS()
        end
    end
    f()
end

function CPlayer:_DoHeartBeat2GS()
    local iPid = self:GetPid()
    local oWorldMgr = global.oWorldMgr
    oWorldMgr:KS2GSRemoteEvent(self:GetNowServer(), "player_heart_beat", {
        pid = iPid,
        info = oWorldMgr:GetPlayerInfo(iPid),
    })
end

function CPlayer:DoSucessLogin2GS()
    local iPid = self:GetPid()
    local oWorldMgr = global.oWorldMgr
    oWorldMgr:KS2GSRemoteEvent(self:GetNowServer(), "player_login_ks", {
        pid = iPid,
    })
end

function CPlayer:GetServerGrade()
    local iPid = self:GetPid()
    return global.oWorldMgr:GetPlayerServerGrade(iPid)
end

function CPlayer:OnLoginEnterScene(bReEnter)
    local sHdName = global.oWorldMgr:GetJoinGame(self:GetPid())
    local oHuodongMgr = global.oHuodongMgr
    local oHuodong = oHuodongMgr:GetHuodong(sHdName)
    if oHuodong and not bReEnter then
        oHuodong:JoinKSGame(self)
    else
        local oSceneMgr = global.oSceneMgr
        oSceneMgr:OnLogin(self, bReEnter)
    end
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
        global.oWorldMgr:TryBackGS(self)
    end
end

