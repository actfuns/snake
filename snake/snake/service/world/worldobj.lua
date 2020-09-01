--import module

local global = require "global"
local skynet = require "skynet"
local interactive = require "base.interactive"
local res = require "base.res"
local net = require "base.net"
local record = require "public.record"
local router = require "base.router"
local lsum = require "lsum"

local gamedefines = import(lualib_path("public.gamedefines"))
local playerobj = import(service_path("playerobj"))
local connectionobj = import(service_path("connectionobj"))
local offline = import(service_path("offline.init"))
local datactrl = import(lualib_path("public.datactrl"))
local sysmailcache = import(service_path("mail.sysmailcache"))
local analy = import(lualib_path("public.dataanaly"))
local gamedb = import(lualib_path("public.gamedb"))
local kuafumgr = import(service_path("kuafumgr"))
local serverinfo = import(lualib_path("public.serverinfo"))


function NewWorldMgr(...)
    local o = CWorldMgr:New(...)
    return o
end

CWorldMgr = {}
CWorldMgr.__index = CWorldMgr
inherit(CWorldMgr, datactrl.CDataCtrl)

function CWorldMgr:New()
    local o = super(CWorldMgr).New(self)
    o.m_bIsOpen = true
    o.m_bClose = false
    o.m_mOnlinePlayers = {}
    o.m_mLoginPlayers = {}
    o.m_mShowIdPlayers = {}
    o.m_mOnlineCount = {}
    o.m_mOnlinePlatCount = {}

    o.m_mOfflineProfiles = {}
    o.m_mOfflineFriends = {}
    o.m_mMailBoxs = {}
    o.m_mOfflineJJCs = {}
    o.m_mOfflineChallenges = {}
    o.m_mWanfaCtrls = {}
    o.m_mPrivacyCtrls = {}
    o.m_mFeedBackCtrls = {}

    o.m_mConnections = {}

    o.m_mPlayerPropChange = {}
    o.m_mSummonPropChange = {}
    o.m_mPartnerPropChange = {}
    o.m_oSysMailCache = sysmailcache.NewSysMailCache()
    o.m_mRecordPlayerAnaly = {}
    o.m_mPlayerNotify = {}

    o.m_iGlobalItemId = 0
    o.m_iGlobalSummonId = 0
    o.m_iGlobalPartnerId = 0
    o.m_iGlobalProxyId = 0
    o.m_iGlobalOrgShowId = 0
    o.m_iServerGrade = 45
    o.m_iOpenDays = 0
    o.m_iOpenStatus = 0

    -- o.m_iGlobalOrgId = 0
    return o
end

function CWorldMgr:Release()
    for _, v in ipairs({self.m_mOnlinePlayers, self.m_mLoginPlayers}) do
        for _, v2 in pairs(v) do
            baseobj_safe_release(v)
        end
    end
    for _, v in pairs(self.m_mConnections) do
        baseobj_safe_release(v)
    end
    self.m_mOnlinePlayers = {}
    self.m_mLoginPlayers = {}
    self.m_mShowIdPlayers = {}
    self.m_mConnections = {}

    for _, v in ipairs({
        self.m_mOfflineProfiles,
        self.m_mOfflineFriends,
        self.m_mMailBoxs,
        self.m_mOfflineJJCs,
        self.m_mOfflineChallenges,
        self.m_mWanfaCtrls,
        self.m_mPrivacyCtrls,
        self.m_mFeedBackCtrls,
        }) do
        for _, v2 in pairs(v) do
            baseobj_safe_release(v)
        end
    end
    self.m_mOfflineProfiles = {}
    self.m_mOfflineFriends = {}
    self.m_mMailBoxs = {}
    self.m_mOfflineJJCs = {}
    self.m_mOfflineChallenges = {}
    self.m_mWanfaCtrls = {}
    self.m_mPrivacyCtrls = {}
    self.m_mFeedBackCtrls = {}
    baseobj_safe_release(self.m_oSysMailCache)
    super(CWorldMgr).Release(self)
end

function CWorldMgr:Load(m)
    m = m or {}
    self.m_iServerGrade = m.server_grade or 45
    self.m_iOpenDays = m.open_days or 0
    self.m_oSysMailCache:Load(m.sysmails)
    -- self.m_iGlobalWarVideoId = m.war_video_id or 0
    self.m_iGlobalOrgShowId = m.orgid or 0
    -- self.m_iGlobalOrgId = m.org_real_id or 0
    global.oMergerMgr:Load(m.merger)
end

function CWorldMgr:Save()
    local m = {}
    m.server_grade = self.m_iServerGrade
    m.open_days = self.m_iOpenDays
    m.sysmails = self.m_oSysMailCache:Save()
    -- m.war_video_id = self.m_iGlobalWarVideoId
    m.orgid = self.m_iGlobalOrgShowId
    -- m.org_real_id = self.m_iGlobalOrgId
    m.merger = global.oMergerMgr:Save()
    return m
end

function CWorldMgr:MergeFrom(mData)
    self:Dirty()
    local iOrgShowId = mData.org_showid
    local mFromData = mData.from_data

    self.m_iGlobalOrgShowId = iOrgShowId
    self.m_oSysMailCache:MergeFrom(mFromData.sysmails)

    return global.oMergerMgr:MergeFrom(mData)
end

function CWorldMgr:UnDirty()
    super(CWorldMgr).UnDirty(self)
    self.m_oSysMailCache:UnDirty()
    global.oMergerMgr:UnDirty()
end

function CWorldMgr:IsDirty()
    local bDirty = super(CWorldMgr).IsDirty(self)
    if bDirty then
        return true
    end
    local bMailDirty = self.m_oSysMailCache:IsDirty()
    if bMailDirty then
        return true
    end
    return global.oMergerMgr:IsDirty()
end

function CWorldMgr:SetServerGrade(i)
    self.m_iServerGrade = i
    self:Dirty()
end

function CWorldMgr:GetServerGrade()
    return self.m_iServerGrade
end

function CWorldMgr:GetServerGradeLimit()
    return self.m_iServerGrade + 5
end

function CWorldMgr:SetOpenDays(i)
    self.m_iOpenDays = i
    self:Dirty()
end

function CWorldMgr:GetOpenDays()
    return self.m_iOpenDays
end

function CWorldMgr:OnLogin(oPlayer, bReEnter)
    oPlayer:Send("GS2CServerGradeInfo", {
        server_grade = oPlayer:GetServerGrade(),
        days = self:GetUpGradeLeftDays(),
        server_type = get_server_type(),
    })
end

function CWorldMgr:GetConnection(iHandle)
    return self.m_mConnections[iHandle]
end

function CWorldMgr:DelConnection(iHandle, sReason)
    local oConnection = self.m_mConnections[iHandle]
    if oConnection then
        local iPid = oConnection:GetOwnerPid()
        self.m_mConnections[iHandle] = nil
        oConnection:Disconnected()
        baseobj_delay_release(oConnection)
        record.log_db("player", "delconnection", {pid=iPid, reason=sReason})
    end
end

function CWorldMgr:FindPlayerAnywayByPid(pid)
    local obj
    for _, m in ipairs({self.m_mLoginPlayers, self.m_mOnlinePlayers}) do
        obj = m[pid]
        if obj then
            break
        end
    end
    return obj
end

function CWorldMgr:FindPlayerAnywayByFd(iHandle)
    local oConnection = self:GetConnection(iHandle)
    if oConnection then
        local iPid = oConnection:GetOwnerPid()
        return self:FindPlayerAnywayByPid(iPid)
    end
end

function CWorldMgr:GetOnlinePlayerByFd(iHandle)
    local oConnection = self:GetConnection(iHandle)
    if oConnection then
        local iPid = oConnection:GetOwnerPid()
        return self.m_mOnlinePlayers[iPid]
    end
end

function CWorldMgr:GetOnlinePlayerByPid(iPid)
    return self.m_mOnlinePlayers[iPid]
end

function CWorldMgr:SetPlayerByShowId(iShowId, oPlayer)
    self.m_mShowIdPlayers[iShowId] = oPlayer
end

function CWorldMgr:GetOnlinePlayerByShowId(iShowId)
    return self.m_mShowIdPlayers[iShowId]
end

function CWorldMgr:IsLogining(iPid)
    if self.m_mLoginPlayers[iPid] then
        return true
    end
    return false
end

function CWorldMgr:GetLoginingPlayerByPid(iPid)
    return self.m_mLoginPlayers[iPid]
end

function CWorldMgr:GetLoginingPlayerList()
    return self.m_mLoginPlayers
end

function CWorldMgr:IsOnline(iPid)
    local oPlayer = self:GetOnlinePlayerByPid(iPid)
    if not oPlayer then
        return false
    end
    return true
end

-- @return: <dict>{pid:oPlayer, ...}
function CWorldMgr:GetOnlinePlayerList()    
    return self.m_mOnlinePlayers
end

function CWorldMgr:GetOnlinePlayerCnt()
    return table_count(self.m_mOnlinePlayers)
end

function CWorldMgr:KickConnection(iHandle)
    local oConnection = self:GetConnection(iHandle)
    if oConnection then
        skynet.send(oConnection.m_iGateAddr, "text", "kick", oConnection.m_iHandle)
        self:DelConnection(iHandle, "server_kick")
    end
end

function CWorldMgr:Logout(iPid)
    local oPlayer = self.m_mLoginPlayers[iPid]
    if oPlayer then
        local sToken = oPlayer:GetRoleToken()
        self.m_mLoginPlayers[iPid] = nil
        baseobj_delay_release(oPlayer)
        self:LogoutNotifyGate(iPid, sToken)
        return
    end

    oPlayer = self.m_mOnlinePlayers[iPid]
    if oPlayer then
        local sToken = oPlayer:GetRoleToken()
        oPlayer:OnLogout()
        oPlayer:DoSave()
        oPlayer:Disconnect()
        self:ReleasePlayer(oPlayer, sToken)
    end
end

function CWorldMgr:ReleasePlayer(oPlayer, sToken)
    local iPid = oPlayer:GetPid()
    self.m_mOnlinePlayers[iPid] = nil
    self:CalOnlineCount(oPlayer, true) 
    baseobj_delay_release(oPlayer)
    self:LogoutNotifyGate(iPid, sToken)
end

function CWorldMgr:ForceLogout(iPid)
    local oPlayer = self.m_mLoginPlayers[iPid]
    if oPlayer then
        local sToken = oPlayer:GetRoleToken()
        self.m_mLoginPlayers[iPid] = nil
        baseobj_delay_release(oPlayer)
        self:LogoutNotifyGate(iPid, sToken)
        return
    end

    oPlayer = self.m_mOnlinePlayers[iPid]
    if oPlayer then
        local sToken = oPlayer:GetRoleToken()
        oPlayer:Disconnect()
        self:ReleasePlayer(oPlayer, sToken)
    end
end

function CWorldMgr:LogoutNotifyGate(pid, sToken)
    interactive.Send(".login", "login", "OnLogout", {pid = pid, token = sToken})
end

function CWorldMgr:Login(mRecord, mConn, mRole)
    local iForceLogin = mRole.forcelogin
    if iForceLogin <= 0 then
        self:Login2(mRecord, mConn, mRole)
    else
        -- 存在KS的时候直接登录
        self:Login3(mRecord, mConn, mRole)
    end
end

function CWorldMgr:Login2(mRecord, mConn, mRole)
    local iPid = mRole.pid
    local oKuaFu = global.oKuaFuMgr:GetKuaFuObj(iPid)
    if oKuaFu then
        self:LoginKS(mRecord, mConn, mRole)
    else
        self:_Login(mRecord, mConn, mRole)
    end
end

function CWorldMgr:LoginKS(mRecord, mConn, mRole)
    local iPid = mRole.pid
    local oKuaFuMgr = global.oKuaFuMgr
    local oKuaFu = oKuaFuMgr:GetKuaFuObj(iPid)
    if not oKuaFu then return end

    local iStatus = oKuaFu:GetStatus()
    local sKey = oKuaFu:GetKuaFuKey()
    if iStatus == kuafumgr.STATUS_TYPE_SUCCESS_BACK then
        global.oKuaFuMgr:Send2KS(sKey, "GS2KSLogoutPlayer", {
            pid = iPid,
            code = 2,
        })   
        self:_Login(mRecord, mConn, mRole)
        return
    end

    interactive.Send(mRecord.source, "login", "LoginResult", {pid = iPid, handle = mConn.handle, token = mRole.role_token, errcode = gamedefines.ERRCODE.login_ks})
    local mMailAddr = {gate = mConn.gate, fd = mConn.handle}
    if not global.oServerMgr:IsConnect(sKey) then
        -- 通知客户端不能连接
        self:_LoginKS(iPid, mMailAddr, 1)
    else
        local mInfo = oKuaFu:GetInfo()
        global.oKuaFuMgr:RemoteConfirm(iPid, sKey, mInfo, function (mr, md)
            self:_LoginKS(iPid, mMailAddr)
        end)
    end
end

function CWorldMgr:_LoginKS(iPid, mMailAddr, iErrCode)
    local oKuaFuMgr = global.oKuaFuMgr
    local oKuaFu = oKuaFuMgr:GetKuaFuObj(iPid)
    if not oKuaFu then return end

    local sKey = oKuaFu:GetKuaFuKey()
    local sHost = oKuaFuMgr:GetKSHost(sKey)
    local iPort = oKuaFuMgr:RandomKSPort()
    if not sHost then
        record.warning(string.format("CWorldMgr:Login2 error PID:%s KS:%s", iPid, sKey))
    end

    net.Send(mMailAddr, "GS2CTryEnterKS", {
        host = sHost, 
        port = iPort,
        pid = iPid,
        errcode = iErrCode,
        gs_host = serverinfo.get_client_host(),
    })

    local oPlayer = self.m_mLoginPlayers[iPid] or self.m_mOnlinePlayers[iPid]
    if oPlayer then
        self:Logout(iPid)    
    end
end

function CWorldMgr:Login3(mRecord, mConn, mRole)
    local iPid = mRole.pid
    local oKuaFuMgr = global.oKuaFuMgr
    local oKuaFu = oKuaFuMgr:GetKuaFuObj(iPid)
    if oKuaFu then
        record.warning(string.format("CWorldMgr:Login3 error PID:%s KS:%s", iPid, oKuaFu:GetKuaFuKey()))
        self:LogKSInfo("ks_info", {pid=iPid, ks=oKuaFu:GetKuaFuKey(), action="login_force"})
        global.oKuaFuMgr:Send2KS(oKuaFu:GetKuaFuKey(), "GS2KSLogoutPlayer", {
            pid = iPid,
            code = 3,
        })   
    end
    self:_Login(mRecord, mConn, mRole)
end

function CWorldMgr:_Login(mRecord, mConn, mRole)
    local pid = mRole.pid
    if self.m_mLoginPlayers[pid] then
        interactive.Send(mRecord.source, "login", "LoginResult", {pid = pid, handle = mConn.handle, token = mRole.role_token, errcode = gamedefines.ERRCODE.in_login})
        return
    end

    global.oScoreCache:AddExclude(pid)
    local oPlayer = self.m_mOnlinePlayers[pid]
    if oPlayer then
        local oOldConn = oPlayer:GetConn()
        if oOldConn and oOldConn.m_iHandle ~= mConn.handle then
            oOldConn:Send("GS2CLoginError", {pid = pid, errcode = gamedefines.ERRCODE.reenter})
            self:KickConnection(oOldConn.m_iHandle)
        end

        local oConnection = connectionobj.NewConnection(mConn, pid)
        self.m_mConnections[mConn.handle] = oConnection
        oConnection:Forward()

        oPlayer:ReInitRoleInfo(mConn, mRole)
        oPlayer:OnLogin(true)
        interactive.Send(mRecord.source, "login", "LoginResult", {pid = pid, handle = mConn.handle, token = mRole.role_token, errcode = gamedefines.ERRCODE.ok})
        return
    else
        local oPlayer = self:CreatePlayer(mConn, mRole)
        self.m_mLoginPlayers[oPlayer:GetPid()] = oPlayer
        self:SetServerKey(pid, mRole.now_server)

        local oConnection = connectionobj.NewConnection(mConn, pid)
        self.m_mConnections[mConn.handle] = oConnection
        oConnection:Forward()

        local mInfo = {
            module = "playerdb",
            cmd = "GetPlayer",
            cond = {pid = pid},
        }
        gamedb.LoadGameDb(self:GetServerKey(pid), pid, "common", "DbOperate", mInfo, function (mRecord, mData)
            if not is_release(self) then
                self:_LoginRole1(mRecord, mData)
            end
        end)
        return
    end
end

function CWorldMgr:_LoginRole1(mRecord, mData)
    local pid = mData.pid
    local m = mData.data
    local oPlayer = self.m_mLoginPlayers[pid]
    if not oPlayer then
        return
    end

    if not m then
        self.m_mLoginPlayers[pid] = nil
        local iHandle = oPlayer:GetNetHandle()
        interactive.Send(".login", "login", "LoginResult", {pid = pid, handle = iHandle, token = oPlayer:GetRoleToken(), errcode = gamedefines.ERRCODE.not_exist_player})
        return
    end

    local mInfo = {
        module = "playerdb",
        cmd = "LoadPlayerMain",
        cond = {pid = pid},
    }
    gamedb.LoadGameDb(self:GetServerKey(pid), pid, "common", "DbOperate", mInfo, function (mRecord, mData)
        if not is_release(self) then
            self:_LoginRole2(mRecord, mData)
        end
    end)
end

function CWorldMgr:_LoginRole2(mRecord, mData)
    local pid = mData.pid
    local m = mData.data
    local oPlayer = self.m_mLoginPlayers[pid]
    if not oPlayer then
        return
    end
    oPlayer:Load(m)
    self:_LoginLoadModule(pid)
end

function CWorldMgr:OnLoginFail(pid)
    local oPlayer = self.m_mLoginPlayers[pid]
    if not oPlayer then
        return
    end
    local iHandle = oPlayer:GetNetHandle()
    interactive.Send(".login", "login", "LoginResult", {pid = pid, handle = iHandle, token = oPlayer:GetRoleToken(), errcode = gamedefines.ERRCODE.script_error})
    self.m_mLoginPlayers[pid] = nil
    baseobj_delay_release(oPlayer)
    record.warning("loginfail maybe script error" .. pid)
end

local lLoginLoadInfo = {
    {"LoadPlayerBase", "m_oBaseCtrl"},
    {"LoadPlayerActive", "m_oActiveCtrl"},
    {"LoadPlayerItem", "m_oItemCtrl"},
    {"LoadPlayerTask", "m_oTaskCtrl"},
    {"LoadPlayerWareHouse", "m_oWHCtrl"},
    {"LoadSkillInfo", "m_oSkillCtrl"},
    {"LoadPlayerTimeInfo", "m_oTimeCtrl"},
    {"LoadPlayerSummon", "m_oSummonCtrl"},
    {"LoadPlayerSchedule", "m_oScheduleCtrl"},
    {"LoadPlayerState", "m_oStateCtrl"},
    {"LoadPlayerPartner", "m_oPartnerCtrl"},
    {"LoadPlayerTitle", "m_oTitleCtrl"},
    {"LoadPlayerTouxian", "m_oTouxianCtrl"},
    {"LoadPlayerAchieve", "m_oAchieveCtrl"},
    {"LoadPlayerRide", "m_oRideCtrl"},
    {"LoadPlayerTempItem","m_mTempItemCtrl"},
    {"LoadPlayerRecovery","m_mRecoveryCtrl"},
    {"LoadPlayerEquip","m_oEquipCtrl"},
    {"LoadPlayerStore","m_oStoreCtrl"},
    {"LoadPlayerSummonCk","m_oSummCkCtrl"},
    {"LoadPlayerFaBao", "m_oFaBaoCtrl"},
    {"LoadPlayerArtifact","m_oArtifactCtrl"},
    {"LoadPlayerWing","m_oWingCtrl"},
    {"LoadPlayerMarryInfo", "m_oMarryCtrl"},
}

function CWorldMgr:_LoginLoadModule(pid, idx)
    idx = idx or 1
    if idx > #lLoginLoadInfo then
        self:_LoginLoadOfflines(pid)
        return
    end
    local sLoadFunc, rFunc = table.unpack(lLoginLoadInfo[idx])
    local mInfo = {
        module = "playerdb",
        cmd = sLoadFunc,
        cond = {pid = pid},
    }
    gamedb.LoadGameDb(self:GetServerKey(pid), pid, "common", "DbOperate", mInfo, function (mRecord, mData)
        self:_LoginLoadModuleCB(rFunc, mRecord, mData)
        if not is_release(self) then
            self:_LoginLoadModule(pid, idx+1)
        end
    end)
end

function CWorldMgr:_LoginLoadModuleCB(rFunc, mRecord, mData)
    local pid = mData.pid
    local m = mData.data
    local oPlayer = self.m_mLoginPlayers[pid]
    if not oPlayer then
        return
    end
    if type(rFunc) == "string" then
        if oPlayer[rFunc] then
            oPlayer[rFunc]:Load(m)
        else
            self[rFunc](oPlayer, m)
        end
    else
        rFunc(oPlayer, m)
    end
end

function CWorldMgr:_LoginLoadOfflines(pid)
    local mFunc = {"LoadProfile","LoadFriend","LoadMailBox","LoadJJC","LoadChallenge","LoadWanfaCtrl", "LoadPrivacy", "LoadFeedBack"}
    local mLoad = {}
    for _,sFunc in pairs(mFunc) do
        if self[sFunc] then
            self[sFunc](self,pid,function(o)
                mLoad[sFunc] = 1
                if table_count(mLoad) >= #mFunc then
                    self:LoadEnd(pid)
                end
            end)
        end
    end
end

function CWorldMgr:LoadEnd(pid)
    local oPlayer = self.m_mLoginPlayers[pid]
    if not oPlayer then
        return
    end
    self.m_mLoginPlayers[pid] = nil
    self.m_mOnlinePlayers[pid] = oPlayer
    local iShowId = oPlayer:GetShowId()
    self:SetPlayerByShowId(iShowId, oPlayer)
    oPlayer:OnLoaded()

    self:CalOnlineCount(oPlayer)
    oPlayer:OnLogin(false)
    interactive.Send(".login", "login", "LoginResult", {pid = pid, handle = oPlayer:GetNetHandle(), token = oPlayer:GetRoleToken(), errcode = gamedefines.ERRCODE.ok})

    self:GetShowIdByPid(pid)
end

function CWorldMgr:GetShowIdByPid(iPid)
    router.Request("cs", ".idsupply", "common", "GetShowIdByPid", {
        pid = iPid,
        set = 1
    }, function (mRecord, mData)
        local oShowIdMgr = global.oShowIdMgr
        oShowIdMgr:SetShowId(iPid, mData.show_id)
    end)
end

function CWorldMgr:GetOfflineMap(sKey)
    if sKey == "Profile" then
        return self.m_mOfflineProfiles
    elseif sKey == "Friend" then
        return self.m_mOfflineFriends
    elseif sKey == "MailBox" then
        return self.m_mMailBoxs
    elseif sKey == "JJC" then
        return self.m_mOfflineJJCs
    elseif sKey == "Challenge" then
        return self.m_mOfflineChallenges
    elseif sKey == "WanfaCtrl" then
        return self.m_mWanfaCtrls
    elseif sKey == "Privacy" then
        return self.m_mPrivacyCtrls
    elseif sKey == "FeedBack" then
        return self.m_mFeedBackCtrls
    end
    assert(false, string.format("CWorldMgr GetOfflineMap fail %s", sKey))
end

function CWorldMgr:GetOfflineObject(sKey, iPid)
    if sKey == "Profile" then
        return self.m_mOfflineProfiles[iPid]
    elseif sKey == "Friend" then
        return self.m_mOfflineFriends[iPid]
    elseif sKey == "MailBox" then
        return self.m_mMailBoxs[iPid]
    elseif sKey == "JJC" then
        return self.m_mOfflineJJCs[iPid]
    elseif sKey == "Challenge" then
        return self.m_mOfflineChallenges[iPid]
    elseif sKey == "WanfaCtrl" then
        return self.m_mWanfaCtrls[iPid]
    elseif sKey == "Privacy" then
        return self.m_mPrivacyCtrls[iPid]
    elseif sKey == "FeedBack" then
        return self.m_mFeedBackCtrls[iPid]
    end
    assert(false, string.format("CWorldMgr GetOfflineObject fail %s %d", sKey, iPid))
end

function CWorldMgr:SetOfflineObject(sKey, iPid, o)
    if sKey == "Profile" then
        self.m_mOfflineProfiles[iPid] = o
        return
    elseif sKey == "Friend" then
        self.m_mOfflineFriends[iPid] = o
        return
    elseif sKey == "MailBox" then
        self.m_mMailBoxs[iPid] = o
        return
    elseif sKey == "JJC" then
        self.m_mOfflineJJCs[iPid] = o
        return
    elseif sKey == "Challenge" then
        self.m_mOfflineChallenges[iPid] = o
        return
    elseif sKey == "WanfaCtrl" then
        self.m_mWanfaCtrls[iPid] = o
        return
    elseif sKey == "Privacy" then
        self.m_mPrivacyCtrls[iPid] = o
        return
    elseif sKey == "FeedBack" then
        self.m_mFeedBackCtrls[iPid] = o
        return
    end
    assert(false, string.format("CWorldMgr SetOfflineObject fail %s %d", sKey, iPid))
end

function CWorldMgr:DelOfflineObject(sKey, iPid)
    local o
    if sKey == "Profile" then
        o = self.m_mOfflineProfiles[iPid]
        self.m_mOfflineProfiles[iPid] = nil
    elseif sKey == "Friend" then
        o = self.m_mOfflineFriends[iPid]
        self.m_mOfflineFriends[iPid] = nil
    elseif sKey == "MailBox" then
        o = self.m_mMailBoxs[iPid]
        self.m_mMailBoxs[iPid] = nil
    elseif sKey == "JJC" then
        o = self.m_mOfflineJJCs[iPid]
        self.m_mOfflineJJCs[iPid] = nil
    elseif sKey == "Challenge" then
        o = self.m_mOfflineChallenges[iPid]
        self.m_mOfflineChallenges[iPid] = nil
    elseif sKey == "WanfaCtrl" then
        o = self.m_mWanfaCtrls[iPid]
        self.m_mWanfaCtrls[iPid] = nil
    elseif sKey == "Privacy" then
        o = self.m_mPrivacyCtrls[iPid]
        self.m_mPrivacyCtrls[iPid] = nil
    elseif sKey == "FeedBack" then
        o = self.m_mFeedBackCtrls[iPid]
        self.m_mFeedBackCtrls[iPid] = nil
    end
    if o then
        baseobj_delay_release(o)
    end
end

function CWorldMgr:NewOfflineObject(sKey, iPid)
    if sKey == "Profile" then
        return offline.NewProfileCtrl(iPid)
    elseif sKey == "Friend" then
        return offline.NewFriendCtrl(iPid)
    elseif sKey == "MailBox" then
        return offline.NewMailBox(iPid)
    elseif sKey == "JJC" then
        return offline.NewJJCCtrl(iPid)
    elseif sKey == "Challenge" then
        return offline.NewChallengeCtrl(iPid)
    elseif sKey == "WanfaCtrl" then
        return offline.NewWanfaCtrl(iPid)
    elseif sKey == "Privacy" then
        return offline.NewPrivacyCtrl(iPid)
    elseif sKey == "FeedBack" then
        return offline.NewFeedBackCtrl(iPid)
    end
    assert(false, string.format("CWorldMgr NewOfflineObject fail %s %d", sKey, iPid))
end

function CWorldMgr:LoadOfflineBlock(sKey, iPid, func)
    if type(iPid) == "table" then
        record.error(debug.traceback())
    end
    local o = self:GetOfflineObject(sKey, iPid)
    if o then
        o:WaitLoaded(func)
    else
        o = self:NewOfflineObject(sKey, iPid)
        self:SetOfflineObject(sKey, iPid, o)
        o:WaitLoaded(func)
        local mInfo = {
            module = "offlinedb",
            cmd = o:GetLoadDbFlag(),
            cond = {pid=iPid},
        }
        local sServerKey = self:GetServerKey(iPid)
        gamedb.LoadGameDb(sServerKey, iPid, "common", "DbOperate", mInfo, function (mRecord,mData)
            local o = self:GetOfflineObject(sKey, iPid)
            assert(o and not o:IsLoaded(), string.format("LoadOfflineBlock fail %s %d", sKey, iPid))

            if not mData.success then
                o:OnLoadedFail()
                self:DelOfflineObject(sKey, iPid)
            else
                local m = mData.data
                o:Load(m)
                o:OnLoaded()
                o:Schedule()
            end
        end)
    end
end

function CWorldMgr:CleanOfflineBlock(sKey, iPid)
    local o = self:GetOfflineObject(sKey, iPid)
    if o then
        o:OnLogout()
    end
    self:DelOfflineObject(sKey, iPid)
end

function CWorldMgr:LoadProfile(iPid, func)
    self:LoadOfflineBlock("Profile", iPid, func)
end

function CWorldMgr:LoadFriend(iPid, func)
    self:LoadOfflineBlock("Friend", iPid, func)
end

function CWorldMgr:LoadMailBox(iPid, func)
    self:LoadOfflineBlock("MailBox", iPid, func)
end

function CWorldMgr:LoadJJC(iPid, func)
    self:LoadOfflineBlock("JJC", iPid, func)
end

function CWorldMgr:LoadChallenge(iPid, func)
    self:LoadOfflineBlock("Challenge", iPid, func)
end

function CWorldMgr:LoadWanfaCtrl(iPid, func)
    self:LoadOfflineBlock("WanfaCtrl", iPid, func)
end

function CWorldMgr:LoadPrivacy(iPid, func)
    self:LoadOfflineBlock("Privacy", iPid, func)
end

function CWorldMgr:LoadFeedBack(iPid, func)
    self:LoadOfflineBlock("FeedBack", iPid, func)
end

function CWorldMgr:GetProfile(iPid)
    return self:GetOfflineObject("Profile", iPid)
end

function CWorldMgr:GetFriend(iPid)
    return self:GetOfflineObject("Friend", iPid)
end

function CWorldMgr:GetMailBox(iPid)
    return self:GetOfflineObject("MailBox", iPid)
end

function CWorldMgr:GetJJC(iPid)
    return self:GetOfflineObject("JJC", iPid)
end

function CWorldMgr:GetChallenge(iPid)
    return self:GetOfflineObject("Challenge", iPid)
end

function CWorldMgr:GetWanfaCtrl(iPid)
    return self:GetOfflineObject("WanfaCtrl", iPid)
end

function CWorldMgr:GetPrivacy(iPid)
    return self:GetOfflineObject("Privacy", iPid)
end

function CWorldMgr:GetFeedBack(iPid)
    return self:GetOfflineObject("FeedBack", iPid)
end

function CWorldMgr:Schedule()
    self:_CheckOnline()

    local nextbl
    local f1
    f1 = function ()
        local ti = get_time()
        local nowtbl = nextbl
        nextbl = get_timetbl(nowtbl.time + 3600)
        local delay = math.max(nextbl.time - ti, 1)
        self:DelTimeCb("NewHour")
        self:AddTimeCb("NewHour", delay * 1000, f1)
        self:NewHour(nowtbl)
    end
    local ti = get_time()
    nextbl = get_hourtime({factor=1,hour=1,time=ti})
    local delay = math.max(nextbl.time - ti, 1)
    self:DelTimeCb("NewHour")
    self:AddTimeCb("NewHour", delay * 1000, f1)
end

function CWorldMgr:_CheckOnline()
    local iInterval = 3 * 60
    local iNextTime = iInterval - get_time() % iInterval
    if iNextTime <= 0 then
        iNextTime = iInterval
    end

    local f2
    f2 = function ()
        self:DelTimeCb("_CheckOnline")
        self:AddTimeCb("_CheckOnline", iInterval * 1000, f2)
        self:CheckOnline2()
    end
    self:AddTimeCb("_CheckOnline", iNextTime * 1000, f2)
end

function CWorldMgr:CheckOnline2()
    for platform,info in pairs(self.m_mOnlineCount) do
        for channel,iCnt in pairs(info) do
            analy.log_data("OnlinePlayer", {server = get_server_key(), plat = platform,
                                            app_channel = channel, online_num = iCnt})
        end
    end
end

function CWorldMgr:ConfigSaveFunc()
    self:ApplySave(function ()
        local oWorldMgr = global.oWorldMgr
        oWorldMgr:_CheckSaveDb()
    end)
end

function CWorldMgr:_CheckSaveDb()
    assert(not is_release(self), "_CheckSaveDb fail")
    self:SaveDb()
end

function CWorldMgr:SaveDb()
    if self:IsDirty() then
        local mInfo = {
            module = "worlddb",
            cmd = "SaveWorld",
            cond = {server_id = get_server_tag()},
            data = {data = self:Save()},
        }
        gamedb.SaveDb("world", "common", "DbOperate", mInfo)
        self:UnDirty()
    end
end

function CWorldMgr:CheckUpGrade()
    local lServerGrade = res["daobiao"]["servergrade"]
    local iTargetGrade = 0
    for _, v in ipairs(lServerGrade) do
        if self:GetOpenDays() < v.days then
            break
        end
        if v.server_grade > iTargetGrade then
            iTargetGrade = v.server_grade
        end
    end
    local iOldGrade = self:GetServerGrade()
    if iTargetGrade ~= iOldGrade then
        self:SetServerGrade(iTargetGrade)
        local iLeftDays = self:GetUpGradeLeftDays()

        local mData = {
            message = "GS2CServerGradeInfo",
            type = gamedefines.BROADCAST_TYPE.WORLD_TYPE,
            id = 1,
            data = {
                server_grade = iTargetGrade,
                days = iLeftDays,
            },
        }
        interactive.Send(".broadcast", "channel", "SendChannel", mData)
        self:OnUpServerGrade(iTargetGrade, iOldGrade)
    end
end

function CWorldMgr:OnUpServerGrade(iGrade, iOldGrade)
    local oGuild = global.oGuild
    if oGuild then
        oGuild:OnUpServerGrade(iGrade, iOldGrade)
    end
end

function CWorldMgr:GetUpGradeLeftDays()
    local lServerGrade = res["daobiao"]["servergrade"]
    local iRet = 0
    local iOpenDays = self.m_iOpenDays
    for _, v in ipairs(lServerGrade) do
        if v.days > iOpenDays then
            iRet = v.days - iOpenDays
            break
        end
    end
    return iRet
end

function CWorldMgr:NewHour(mNow)
    local iHour = mNow.date.hour
    local iDay = mNow.date.wday
    if iHour == 0 then
        self:SetOpenDays(self:GetOpenDays() + 1)
        self:CheckUpGrade()
    elseif iHour == 5 then
        skynet.send(".rt_monitor", "lua", "DayCommandMonitor")
    elseif iHour == 6 then
        interactive.Send(".recommend","friend","ClearAllCache", {})
    end

    local oRankMgr = global.oRankMgr
    if oRankMgr then
        safe_call(oRankMgr.NewHour, oRankMgr, mNow)
    end

    local oGuild = global.oGuild
    if oGuild then
        safe_call(oGuild.NewHour, oGuild, mNow)
    end

    local oOrgMgr = global.oOrgMgr
    safe_call(oOrgMgr.NewHour, oOrgMgr, mNow)

    local oJJCMgr = global.oJJCMgr
    if oJJCMgr then
        safe_call(oJJCMgr.NewHour, oJJCMgr, mNow)
    end

    local oChallengeMgr = global.oChallengeMgr
    if oChallengeMgr then
        safe_call(oChallengeMgr.NewHour, oChallengeMgr, mNow)
    end

    local oYibaoMgr = global.oYibaoMgr
    if oYibaoMgr then
        safe_call(oYibaoMgr.NewHour, oYibaoMgr, mNow)
    end
    local oHuodongMgr  = global.oHuodongMgr
    safe_call(oHuodongMgr.NewHour, oHuodongMgr, mNow)

    local oYunYingMgr = global.oYunYingMgr
    safe_call(oYunYingMgr.NewHour, oYunYingMgr, mNow)    

    local oTeamMgr = global.oTeamMgr
    safe_call(oTeamMgr.NewHour, oTeamMgr, mNow)

    local oMarryMgr = global.oMarryMgr
    safe_call(oMarryMgr.NewHour, oMarryMgr, mNow)    

    local oHotTopicMgr = global.oHotTopicMgr
    safe_call(oHotTopicMgr.NewHour, oHotTopicMgr, mNow)
    
    self:PlayerNewHour(mNow, function ()
    end)
end

function CWorldMgr:PlayerNewHour(mNow, func)
    local lPids = table_key_list(self.m_mOnlinePlayers)
    global.oToolMgr:ExecuteList(lPids, 1000, 1000, 0, "PlayerNewHour", function(pid)
        self:_PlayerNewHourOne(pid, mNow)
    end, func)
end

function CWorldMgr:_PlayerNewHourOne(pid, mNow)
    local oPlayer = self:GetOnlinePlayerByPid(pid)
    if oPlayer then
        oPlayer:NewHour(mNow)
    end
end

function CWorldMgr:IsOpen()
    return self.m_bIsOpen
end

function CWorldMgr:SetOpen(b)
    self.m_bIsOpen = b
end

function CWorldMgr:CloseGS()
    if not self:IsOpen() then
        return
    end

    self:SetOpen(false)

    interactive.Send(".login", "login", "ReadyCloseGS", {})
    self:DelTimeCb("CloseGS2")
    self:AddTimeCb("CloseGS2", 4*1000, function ()
        if not is_release(self) then
            self:CloseGS2()
        end
    end)

    local oNotifyMgr = global.oNotifyMgr
    oNotifyMgr:SendSysChat("周知：服务器将进行维护，4秒后将直接下线", 0, 1)
end

function CWorldMgr:CloseGS2()
    save_all()

    local l = {}
    for _, o in pairs(self.m_mOnlinePlayers) do
        o:Send("GS2CMaintainUI", {})
        table.insert(l, o:GetPid())
    end
    for _, v in ipairs(l) do
        self:Logout(v)
    end

    local lOfflineModules = {
        "m_mOfflineProfiles",
        "m_mOfflineFriends",
        "m_mMailBoxs",
        "m_mOfflineJJCs",
        "m_mOfflineChallenges",
        "m_mWanfaCtrls",
        "m_mPrivacyCtrls",
        "m_mFeedBackCtrls",
    }

    for _, sModule in ipairs(lOfflineModules) do
        for _, o in pairs(self[sModule]) do
            if o and o:IsLoaded() then
                o:OnLogout()
            end
        end
    end

    local oVideoMgr = global.oVideoMgr
    if oVideoMgr then
        oVideoMgr:OnCloseGS()
    end

    local oBulletBarrageMgr = global.oBulletBarrageMgr
    if oBulletBarrageMgr then
        oBulletBarrageMgr:OnCloseGS()
    end

    interactive.Send(".rank", "dictator", "CloseGS", {})
    interactive.Send(".recommend", "dictator", "CloseGS", {})
    interactive.Send(".chat", "dictator", "CloseGS", {})

    self.m_bClose = true
    self:DelTimeCb("CloseGS3")
    self:AddTimeCb("CloseGS3", 4*1000, function ()
        if not is_release(self) then
            self:CloseGS3()
        end
    end)
end

function CWorldMgr:CloseGS3()
    os.exit()
end

function CWorldMgr:IsClose()
    return self.m_bClose
end

function CWorldMgr:SetPlayerPropChange(iPid, l)
    local mNow = self.m_mPlayerPropChange[iPid]
    if not mNow then
        mNow = {}
        self.m_mPlayerPropChange[iPid] = mNow
    end
    for _, v in ipairs(l) do
        mNow[v] = true
    end
end

function CWorldMgr:SetSummonPropChange(iPid, summonid, l)
    local mSummons = self.m_mSummonPropChange[iPid]
    if not mSummons then
        mSummons = {}
        self.m_mSummonPropChange[iPid] = mSummons
    end
    local mProps = mSummons[summonid]
    if not mProps then
        mProps = {}
        self.m_mSummonPropChange[iPid][summonid] = mProps
    end
    for _, v in ipairs(l) do
        mProps[v] = true
    end
end

function CWorldMgr:SetPartnerPropChange(iPid, partnerid, l)
    local mPartners = self.m_mPartnerPropChange[iPid]
    if not mPartners then
        mPartners = {}
        self.m_mPartnerPropChange[iPid] = mPartners
    end
    local mProps = mPartners[partnerid]
    if not mProps then
        mProps = {}
        self.m_mPartnerPropChange[iPid][partnerid] = mProps
    end
    for _, v in ipairs(l) do
        mProps[v] = true
    end
end

function CWorldMgr:SetRewardNotify(iPid, mMessage)
    local mNotify = self.m_mPlayerNotify[iPid] or {}
    for sKey, iAdd in pairs(mMessage) do
        local iVal = mNotify[sKey] or 0
        iVal = iVal + iAdd
        mNotify[sKey] = iVal
    end
    self.m_mPlayerNotify[iPid] = mNotify
end

function CWorldMgr:SendPlayerPropChange()
    if next(self.m_mPlayerPropChange) then
        local mPlayerPropChange = self.m_mPlayerPropChange
        self.m_mPlayerPropChange = {}
        for k, v in pairs(mPlayerPropChange) do
            local oPlayer = self:GetOnlinePlayerByPid(k)
            if oPlayer and next(v) then
                safe_call(oPlayer.ClientPropChange, oPlayer, v)
            end
        end
    end
end

function CWorldMgr:SendSummonPropChange()
    if next(self.m_mSummonPropChange) then
        local mData = self.m_mSummonPropChange
        self.m_mSummonPropChange = {}
        for k, mSummons in pairs(mData) do
            local oPlayer = self:GetOnlinePlayerByPid(k)
            if oPlayer and next(mSummons) then
                for k, v in pairs(mSummons) do
                    local oSummon = oPlayer.m_oSummonCtrl:GetSummon(k)
                    if oSummon and next(v) then
                        safe_call(oSummon.ClientPropChange, oSummon, oPlayer, v)
                    end
                end
            end
        end
    end
end

function CWorldMgr:SendPartnerPropChange()
    if next(self.m_mPartnerPropChange) then
        local mData = self.m_mPartnerPropChange
        self.m_mPartnerPropChange = {}
        for pid, mPartners in pairs(mData) do
            local oPlayer = self:GetOnlinePlayerByPid(pid)
            if oPlayer and next(mPartners) then
                for partnerid, v in pairs(mPartners) do
                    local oPartner = oPlayer.m_oPartnerCtrl:GetPartner(partnerid)
                    if oPartner and next(v) then
                        safe_call(oPartner.ClientPropChange, oPartner, oPlayer, v)
                    end
                end
            end
        end
    end
end

function CWorldMgr:RecordPlayerAnalyInfo(iPid)
    self.m_mRecordPlayerAnaly[iPid] = true
end

function CWorldMgr:ClearPlayerAnalyInfo()
    if next(self.m_mRecordPlayerAnaly) then
        local mRecord = self.m_mRecordPlayerAnaly
        self.m_mRecordPlayerAnaly = {}
        for iPid, _ in pairs(mRecord) do
            local oPlayer = self:GetOnlinePlayerByPid(iPid)
            if oPlayer then
                safe_call(oPlayer.ClearAnalyContent, oPlayer)
            end
        end
    end
end

function CWorldMgr:SendRewardNotify()
    local lNotifyOrder = {"exp", "silver", "gold"}
    local mTipName = {exp="#n#cur_6", silver="#n#cur_4", gold="#n#cur_3"}
    if next(self.m_mPlayerNotify) then
        local mData = self.m_mPlayerNotify
        self.m_mPlayerNotify = {}
        for iPid, mNotify in pairs(mData) do
            local oPlayer = self:GetOnlinePlayerByPid(iPid)
            if not oPlayer then goto continue end
            local lMsg = {}
            for _, sKey in pairs(lNotifyOrder) do
                if mNotify[sKey] and mNotify[sKey] > 0 then
                    local sTip = mTipName[sKey]
                    table.insert(lMsg, "#G"..mNotify[sKey]..sTip)
                end
            end
            if #lMsg > 0 then
                oPlayer:NotifyMessage("获得" .. table.concat(lMsg, ","))
            end
            ::continue::
        end
    end
end

function CWorldMgr:WorldDispatchFinishHook()
    self:SendPlayerPropChange()
    self:SendSummonPropChange()
    self:SendPartnerPropChange()
    safe_call(self.ClearPlayerAnalyInfo, self)
    safe_call(self.SendRewardNotify, self)
end

function CWorldMgr:DispatchItemID()
    self.m_iGlobalItemId =  self.m_iGlobalItemId + 1
    return self.m_iGlobalItemId
end

function CWorldMgr:DispatchSummonID()
    self.m_iGlobalSummonId = self.m_iGlobalSummonId + 1
    return self.m_iGlobalSummonId
end

function CWorldMgr:DispatchPartnerID()
    self.m_iGlobalPartnerId = self.m_iGlobalPartnerId + 1
    return self.m_iGlobalPartnerId
end

function CWorldMgr:DispatchProxyID()
    self.m_iGlobalProxyId = self.m_iGlobalProxyId  + 1
    return self.m_iGlobalProxyId
end

function CWorldMgr:DispatchOrgShowId()
    self.m_iGlobalOrgShowId = self.m_iGlobalOrgShowId + 1
    self:Dirty()
    self:SaveDb()
    return self.m_iGlobalOrgShowId
end

-- function CWorldMgr:DispatchOrgId()
--     self.m_iGlobalOrgId = self.m_iGlobalOrgId + 1
--     self:Dirty()
--     self:SaveDb()
--     local sValue = string.format("%d%d", self.m_iGlobalOrgId, get_server_id())
--     local iOrgId = tonumber(sValue)
--     assert(iOrgId, "dispatch org id error")
--     return iOrgId
-- end

function CWorldMgr:OnServerStartEnd()
    self:CheckUpGrade()

    global.oMergerMgr:OnServerStartEnd()
    
    interactive.Send(".login", "login", "SetGateOpenStatus", {status = 3})
    global.oHuodongMgr:OnServerStartEnd()

    router.Send("bs", ".backend", "common", "RegisterGS2BS", {serverkey=get_server_key()})
    global.oBackendMgr:OnServerStartEnd()

    global.oHotTopicMgr:OnServerStartEnd()
    self:TriggerEvent(gamedefines.EVENT.WORLD_SERVER_START_END, {})
end

function CWorldMgr:CalOnlineCount(oPlayer, bSub)
    if not oPlayer then return end

    local iPlatform = oPlayer:GetPlatform()
    local iChannel = oPlayer:GetChannel()
    if not iPlatform or not iChannel then return end

    local mPlatform = self.m_mOnlineCount[iPlatform]
    if not mPlatform then
        mPlatform = {}
        self.m_mOnlineCount[iPlatform] = mPlatform
    end

    local iChannelCount = mPlatform[iChannel] or 0
    local iPlatCount = self.m_mOnlinePlatCount[iPlatform] or 0
    if not bSub then
        mPlatform[iChannel] = iChannelCount + 1
        self.m_mOnlinePlatCount[iPlatform] = iPlatCount + 1
    else
        mPlatform[iChannel] = math.max(0, iChannelCount - 1)
        self.m_mOnlinePlatCount[iPlatform] = math.max(0, iPlatCount - 1)
    end
end

function CWorldMgr:ConfiglSumDaoBiao()
    local mInitProp = table_copy(res["daobiao"]["roleprop"][1])
    lsum.lsum_roleprop(mInitProp)

    local mInitPointMacro = {}
    local mInitPointValue = {}
    local mPoint = res["daobiao"]["point"]
    local mAdd = {"mag_attack_add","mag_defense_add","max_hp_add","phy_attack_add","phy_defense_add","speed_add"}
    for _,mUnit in pairs(mPoint) do
        local sMacro = mUnit.macro
        table.insert(mInitPointMacro,sMacro)
        for sAdd,v in pairs(mUnit) do
            if table_in_list(mAdd,sAdd) then
                mInitPointValue[sMacro.."_"..sAdd] = v
            end
        end
    end

    lsum.lsum_pointmacro(mInitPointMacro)
    lsum.lsum_pointvalue(mInitPointValue)
end

function CWorldMgr:SetOpenStatus(iStatus)
    print ("world SetOpenStatus:", iStatus)
    self.m_iOpenStatus = iStatus
end

function CWorldMgr:IsOpenLogin()
    return self.m_iOpenStatus == 3
end

function CWorldMgr:SetServerKey(iPid, sServerKey)
end

function CWorldMgr:GetServerKey(iPid)
end

function CWorldMgr:CreatePlayer(mConn, mRole)
    return playerobj.NewPlayer(mConn, mRole)
end

function CWorldMgr:LogKSInfo(sType, mInfo)
    print("liuzla-deubug--GS----", sType, mInfo)
    -- record.log_db("kuafu", sType, mInfo)
end


