--import module

local global = require "global"
local skynet = require "skynet"
local interactive = require "base.interactive"
local res = require "base.res"
local router = require "base.router"
local record = require "public.record" 

local gamedefines = import(lualib_path("public.gamedefines"))
local worldobj = import(service_path("worldobj"))
local playerobj = import(service_path("kuafu.playerobj"))
local serverinfo = import(lualib_path("public.serverinfo"))
local handleteam = import(service_path("team.handleteam"))


function NewWorldMgr(...)
    local o = CWorldMgr:New(...)
    return o
end

CWorldMgr = {}
CWorldMgr.__index = CWorldMgr
inherit(CWorldMgr, worldobj.CWorldMgr)

function CWorldMgr:New()
    local o = super(CWorldMgr).New(self)
    o.m_mPid2Info = {}
    o.m_mPid2ServerKey = {}
    o.m_mHuodong = {}
    return o
end

function CWorldMgr:CloseGS2()
    local mLeavePlayer = {}
    local f = function(iPid)
        mLeavePlayer[iPid] = nil
        local iRet = table_count(mLeavePlayer)
        record.info("close ks ret player:"..iRet)
        if iRet <= 0 then
            super(CWorldMgr).CloseGS2(self)
        end
    end

    for _, o in pairs(self.m_mOnlinePlayers) do
        mLeavePlayer[o:GetPid()] = 1
        self:TryBackGS(o, f)
    end

    if table_count(mLeavePlayer) <= 0 then
        record.info("close ks without player")
        super(CWorldMgr).CloseGS2(self)
    end
end

function CWorldMgr:NewHour(mNow)
    local iHour = mNow.date.hour
    local iDay = mNow.date.wday
    if iHour == 5 then
        skynet.send(".rt_monitor", "lua", "DayCommandMonitor")
    end

    local oYibaoMgr = global.oYibaoMgr
    if oYibaoMgr then
        safe_call(oYibaoMgr.NewHour, oYibaoMgr, mNow)
    end
    local oHuodongMgr  = global.oHuodongMgr
    safe_call(oHuodongMgr.NewHour, oHuodongMgr, mNow)

    local oTeamMgr = global.oTeamMgr
    safe_call(oTeamMgr.NewHour, oTeamMgr, mNow)

    self:PlayerNewHour(mNow, function ()
    end)
end

function CWorldMgr:SetServerKey(iPid, sServerKey)
    self.m_mPid2ServerKey[iPid] = sServerKey
end

function CWorldMgr:GetServerKey(iPid)
    return self.m_mPid2ServerKey[iPid]
end

function CWorldMgr:SetPlayerInfo(iPid, mInfo)
    self.m_mPid2Info[iPid] = mInfo
end

function CWorldMgr:GetPlayerInfo(iPid)
    return self.m_mPid2Info[iPid]
end

function CWorldMgr:GetJoinGame(iPid)
    local mInfo = self:GetPlayerInfo(iPid) or {}
    return mInfo.hdname
end

function CWorldMgr:CreatePlayer(mConn, mRole)
    return playerobj.NewPlayer(mConn, mRole)
end

function CWorldMgr:GetShowIdByPid(iPid)
end

function CWorldMgr:RemoteGSConfirm(iPid, sGSKey, mInfo, endfunc)
    if not self:IsOpen() or self:IsClose() then
        endfunc({errcode = 1})
        return
    end
    interactive.Request(".login", "login", "GetGateOpenStatus", nil,
    function(mRecord, mData)
        self:RemoteGSConfirm1(iPid, sGSKey, mInfo, endfunc, mData)
    end)
end

function CWorldMgr:RemoteGSConfirm1(iPid, sGSKey, mInfo, endfunc, mData)
    if mData and mData.open_status < 3 then
        endfunc({errcode = 2})
        return
    end

    self:SetPlayerInfo(iPid, mInfo or {})
    self:SetServerKey(iPid, sGSKey)

    self:LogKSInfo("ks_info", {
        pid = iPid,
        action = "enter_confirm",
        info = {gs_key=sGSKey, data=mInfo},
    })

    endfunc({errcode = 0})
end

function CWorldMgr:ConfigSaveFunc()
end

function CWorldMgr:OnServerStartEnd()
    global.oHuodongMgr:OnServerStartEnd()

    router.Send("bs", ".backend", "common", "RegisterGS2BS", {serverkey=get_server_key()})
    self:TriggerEvent(gamedefines.EVENT.WORLD_SERVER_START_END, {})
end

function CWorldMgr:KS2GSRemoteEvent(sServerKey, sEvent, mArgs)
    router.Send(sServerKey, ".world", "kuafu_gs", "KS2GSRemoteEvent", {
        event = sEvent,
        args = mArgs,
    })
end

function CWorldMgr:CheckLogin(iPid)
    if not self:GetPlayerInfo(iPid) then
        record.warning("ks login while ks not prepare:"..iPid)
        return false
    end
    -- local sHdName = self:GetJoinGame(iPid)
    -- local oHuodongMgr = global.oHuodongMgr
    -- local oHuodong = oHuodongMgr:GetHuodong(sHdName)
    -- if oHuodong and not oHuodong:IsKSGameStart() then
    --     return false
    -- end
    return true
end

function CWorldMgr:Login(mRecord, mConn, mRole)
    local iPid = mRole.pid
    if not self:CheckLogin(iPid) then
        interactive.Send(mRecord.source, "login", "LoginResult", {pid = iPid, handle = mConn.handle, token = mRole.role_token, errcode = gamedefines.ERRCODE.not_start_ks})
        self:Logout(iPid)
        return
    end

    self:_Login(mRecord, mConn, mRole)
    self:LogKSInfo("ks_info", {
        pid = iPid,
        action = "ks_login",
        info = {}
    })
end

function CWorldMgr:Logout(iPid)
    super(CWorldMgr).Logout(self, iPid)
    self:CleanAllOffline(iPid)
    self:SetPlayerInfo(iPid, nil)
    local sServerKey = self:GetServerKey(iPid)
    self:KS2GSRemoteEvent(sServerKey, "leave_player", {pid=iPid})

    self:LogKSInfo("ks_info", {
        pid = iPid,
        action = "ks_logout",
        info = {}
    })
end

function CWorldMgr:ForceLogout(iPid)
    local sServerKey = self:GetServerKey(iPid)
    if not sServerKey then
        record.warning(string.format("CWorldMgr:ForceLogout Pid:%s not serverkey", iPid))    
        return
    end

    super(CWorldMgr).ForceLogout(self, iPid)
    self:CleanAllOffline(iPid)
    self:SetPlayerInfo(iPid, nil)
    self:KS2GSRemoteEvent(sServerKey, "leave_player", {pid=iPid})

    self:LogKSInfo("ks_info", {
        pid = iPid,
        action = "ks_forcelogout",
        info = {}
    })
end

function CWorldMgr:CleanAllOffline(iPid)
    local lOfflineKey = {"Profile", "Friend", "MailBox", "JJC", "Challenge", "WanfaCtrl", "Privacy", "FeedBack"}
    for _,sKey in pairs(lOfflineKey) do
        self:CleanOfflineBlock(sKey, iPid)
    end
end

function CWorldMgr:HandleLogoutPlayer(iPid, iCode)
    record.warning(string.format("CWorldMgr:HandleLogoutPlayer Pid:%s Code:%s", iPid, iCode))
    self:ForceLogout(iPid)
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
        self:KS2GSLoadOffline(sKey, iPid, function (mRecord,mData)
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

function CWorldMgr:KS2GSLoadOffline(sKey, iPid, fCallBack)
    local sServerKey = self:GetServerKey(iPid)
    assert(sServerKey, string.format("KS2GSLoadOffline error not find server"))
    router.Request(sServerKey, ".world", "kuafu_gs", "KS2GSLoadOffline", {
        pid = iPid,
        key = sKey,
    }, fCallBack)
end

function CWorldMgr:GetPlayerServerGrade(iPid)
    local sServerKey = self:GetServerKey(iPid)
    local iServerGrade = global.oServerMgr:GetServerGrade(sServerKey)
    return iServerGrade > 0 and iServerGrade or self:GetServerGrade()
end

function CWorldMgr:GetBackHost(sServerKey)
    if get_server_cluster() == "dev" then
        return MY_SERVER_LOCAL_IP    
    else
        local sKey = string.format("%s_%s", get_server_cluster(), sServerKey)
        local sHost = serverinfo.get_client_host(sKey)
        return sHost        
    end
end

function CWorldMgr:ValidBackGS(iPid)
    local sKey = self:GetServerKey(iPid)
    if not sKey then
        return false
    end
    local sHost = self:GetBackHost(sKey)
    if not sHost then
        record.warning(string.format("server key %s not host", sKey))
        return false
    end
    if not self.m_mOnlinePlayers[iPid] then
        record.warning(string.format("not player obj: %s, %s", iPid, sKey))
        return false
    end
    return true
end

function CWorldMgr:TryBackGS(oPlayer, endfunc)
    local iPid = oPlayer:GetPid()
    if not self:ValidBackGS(iPid) then
        return
    end

    local sServerKey = self:GetServerKey(iPid)
    if not global.oServerMgr:IsConnect(sServerKey) then
        oPlayer:NotifyMessage("服务器暂时无法连通")
        return
    end
    
    if oPlayer:HasTeam() then
        handleteam.LeaveTeam(oPlayer)
    end

    oPlayer:OnLogout()
    local lAllSave = oPlayer:GetAllSaveData()
    if not lAllSave or not next(lAllSave) then
        record.warning("can't get save data:"..iPid)
        return
    end

    local sHost = self:GetBackHost(sServerKey)
    local mArgs = {pid = iPid, all_save = lAllSave}
    oPlayer:SetForbidSaveTime(get_time() + 20)

    self:LogKSInfo("ks_info", {pid = iPid, action = "pre_back_gs", info = {},})
    router.Request(sServerKey, ".world", "kuafu_gs", "KS2GSSaveAll", mArgs,
    function(mRecord, mData)
        if mData.errcode == 0 then
            self:TryBackGS2(iPid, sServerKey, sHost)
            if endfunc then endfunc(iPid) end
        else
            record.warning(string.format("trybackgs: %s, %s, %s", iPid, sKey, mData.errcode))
        end
    end)
end

function CWorldMgr:TryBackGS2(iPid, sServerTag, sHost)
    local oPlayer = self.m_mOnlinePlayers[iPid]
    if not oPlayer then
        record.warning(string.format("trybackgs2 not player: %s", iPid))
        return
    end

    self:CleanAllOffline(iPid)
    self:SetPlayerInfo(iPid, nil)
    self:KS2GSRemoteEvent(sServerTag, "leave_player", {pid=iPid})

    local sToken = oPlayer:GetRoleToken()
    oPlayer:Send("GS2CTryBackGS", {host = sHost})
    self:LogKSInfo("ks_info", {pid = iPid, action = "back_gs", info = {},})
    oPlayer:Disconnect()
    oPlayer:CancelSave()
    self:ReleasePlayer(oPlayer, sToken)
end

function CWorldMgr:OnStartHuodong(sHdName, mInfo)
    self.m_mHuodong[sHdName] = mInfo

    local mNet = {
        hd_name = sHdName,
        hd_info = mInfo
    }
    for _,sServerKey in pairs(get_gs_tag_list()) do
        self:KS2GSRemoteEvent(sServerKey, "huodong_start", mNet)
    end
    self:LogKSInfo("ks_huodong", {
        action = "hd_start",
        hdname = sHdName,
        info = mInfo,
    })
end

function CWorldMgr:OnEndHuodong(sHdName)
    self.m_mHuodong[sHdName] = nil
    for _,sServerKey in pairs(get_gs_tag_list()) do
        self:KS2GSRemoteEvent(sServerKey, "huodong_end", {hd_name=sHdName})
    end

    self:LogKSInfo("ks_huodong", {
        action = "hd_end",
        hdname = sHdName,
        info = {}
    })
end

function CWorldMgr:LogKSInfo(sType, mInfo)
    print("liuzla-deubug--KS----", sType, mInfo)
    -- record.log_db("kuafu", sType, mInfo)
end
