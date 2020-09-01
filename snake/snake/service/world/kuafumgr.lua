local global = require "global"
local interactive = require "base.interactive"
local extend = require "base.extend"
local res = require "base.res"
local record = require "public.record" 
local router = require "base.router"
local serverdefines = require "public.serverdefines"

local gamedefines = import(lualib_path("public.gamedefines"))
local serverinfo = import(lualib_path("public.serverinfo"))
local datactrl = import(lualib_path("public.datactrl"))
local gamedb = import(lualib_path("public.gamedb"))


STATUS_TYPE_NONE = 0
STATUS_TYPE_PRE_ENTER = 1
STATUS_TYPE_SUCCESS_ENTER = 2
STATUS_TYPE_PRE_BACK = 3  -- 暂时没用
STATUS_TYPE_SUCCESS_BACK = 4


function NewKuaFuMgr(...)
    return CKuaFuMgr:New(...)
end

CKuaFuMgr = {}
CKuaFuMgr.__index = CKuaFuMgr
inherit(CKuaFuMgr, datactrl.CDataCtrl)

function CKuaFuMgr:New()
    local o = super(CKuaFuMgr).New(self)
    o:Init()
    return o
end

function CKuaFuMgr:Init()
    self.m_mKuaFuObj = {}
    self.m_lPort = nil
end

function CKuaFuMgr:Release()
    for _,oKuaFu in pairs(self.m_mKuaFuObj) do
        baseobj_safe_release(oKuaFu)
    end
    self.m_mKuaFuObj = {}
end

function CKuaFuMgr:LoadDB()
    local mInfo = {
        module = "kuafudb",
        cmd = "LoadAllKuaFuInfo",
        cond = {},
    }
    gamedb.LoadDb("kuafu", "common", "DbOperate", mInfo,
    function(mRecord, mData)
        self:Load(mData.data)
        self:OnLoaded()
    end)
end

function CKuaFuMgr:Load(mData)
    if not mData then return end

    for _,m in pairs(mData) do
        local iPid = m.pid
        local oKuaFu = NewKuaFuObj(iPid)
        oKuaFu:Load(m.info)
        self.m_mKuaFuObj[iPid] = oKuaFu
    end
end

function CKuaFuMgr:AddKuaFuObj(oKuaFu)
    self.m_mKuaFuObj[oKuaFu:GetPid()] = oKuaFu
    oKuaFu:Schedule()
    self:UpdateKuaFuDB(oKuaFu)
end

function CKuaFuMgr:GetKuaFuObj(iPid)
    return self.m_mKuaFuObj[iPid]
end

function CKuaFuMgr:RemoveKuaFuObj(iPid)
    local oKuaFu = self.m_mKuaFuObj[iPid]
    self.m_mKuaFuObj[iPid] = nil
    if oKuaFu then
        self:ClearKuaFuDb(oKuaFu)
        baseobj_delay_release(oKuaFu)    
    end
end

function CKuaFuMgr:ClearKuaFuDb(oKuaFu)
    local mCmd = {
        module = "kuafudb",
        cmd = "RemoveKuaFu",
        cond = {pid = oKuaFu:GetPid()},
    }
    gamedb.SaveDb("kuafu", "common", "DbOperate", mCmd)
end

function CKuaFuMgr:UpdateKuaFuDB(oKuaFu)
    local mCmd = {
        module = "kuafudb",
        cmd = "UpdateKuaFu",
        cond = {pid = oKuaFu:GetPid()},
        data = {data = oKuaFu:Save()},
    }
    gamedb.SaveDb("kuafu", "common", "DbOperate", mCmd)
end

function CKuaFuMgr:CreateKuaFuObj(iPid, sKuaFuKey, mInfo)
    local oKuaFu = NewKuaFuObj(iPid)
    oKuaFu:Create(sKuaFuKey, mInfo)
    return oKuaFu
end

function CKuaFuMgr:RandomKSPort()
    if not self.m_lPort then
        local sPorts = serverdefines.get_ks_gateway_ports()
        self.m_lPort = split_string(sPorts, ",", tonumber)
    end
    return extend.Random.random_choice(self.m_lPort)
end

function CKuaFuMgr:GetKuaFuServer(sHdName)
    return "ks101"
end

function CKuaFuMgr:RemoteConfirm(iPid, sKuaFuKey, mInfo, func)
    self:Request2KS(sKuaFuKey, "GS2KSRemoteConfirm", {
        info = mInfo,
        pid = iPid
    }, func)
end

function CKuaFuMgr:TryEnterKS(oPlayer, sKuaKey, mInfo)
    local bWhite = global.oServerMgr:IsWhiteListAccount(oPlayer:GetAccount(), oPlayer:GetChannel())
    if not bWhite and not global.oToolMgr:IsSysOpen("KS_SYS", oPlayer) then
        return
    end
    if oPlayer:HasTeam() then
        oPlayer:NotifyMessage("组队跨服还未开放，敬请期待")
        return
    end
    if not global.oWorldMgr:IsOpenLogin() and not bWhite then
        oPlayer:NotifyMessage("跨服暂时无法登录")
        return
    end
    if not global.oServerMgr:IsConnect(sKuaKey) then
        oPlayer:NotifyMessage("跨服暂时无法连通")
        return
    end
    if global.oServerMgr:GetOnlineNum(sKuaKey) >= 4000 then
        oPlayer:NotifyMessage("跨服处于繁忙状态， 请稍后再试")
        return
    end
    
    local iPid = oPlayer:GetPid()
    local sHost = self:GetKSHost(sKuaKey)
    if not sHost then
        record.warning(string.format("CKuaFuMgr:TryEnterKS error PID:%s KS:%s", iPid, sKuaKey))
        return
    end

    self:RemoteConfirm(iPid, sKuaKey, mInfo, function (mRecord, mData)
        self:_TryEnterKS2(iPid, sKuaKey, mInfo, mData)
    end)
end

function CKuaFuMgr:_TryEnterKS2(iPid, sKuaKey, mInfo, mData)
    local oPlayer = global.oWorldMgr:GetOnlinePlayerByPid(iPid)
    if not oPlayer then return end

    if mData.errcode == 1 then
        oPlayer:NotifyMessage("跨服已关闭, 请稍后再试")
    elseif mData.errcode == 2 then
        oPlayer:NotifyMessage("跨服正在维护中，请稍后再试")
    elseif mData.errcode == 0 then
        local sToken = oPlayer:GetRoleToken()
        oPlayer:OnLogout()
        oPlayer:DoSave()
        safe_call(self._TryEnterKS3, self, oPlayer, sKuaKey, mInfo)
        oPlayer:Disconnect()
        global.oWorldMgr:ReleasePlayer(oPlayer, sToken)
    else
        record.info("try enter ks %s errcode:%s", sKuaKey, mData.errcode)
    end
end

function CKuaFuMgr:_TryEnterKS3(oPlayer, sKuaKey, mInfo)
    local iPid = oPlayer:GetPid()
    local sHost = self:GetKSHost(sKuaKey)
    local oKuaFu = self:CreateKuaFuObj(iPid, sKuaKey, mInfo)
    self:AddKuaFuObj(oKuaFu)
    oKuaFu:SetStatus(STATUS_TYPE_PRE_ENTER)

    oPlayer:Send("GS2CTryEnterKS", {
        host = sHost,
        port = self:RandomKSPort(),
        pid = iPid,
        gs_host = serverinfo.get_client_host(),
    })

    global.oWorldMgr:LogKSInfo("ks_info", {
        iPid = iPid,
        action = "enter_ks",
        ks = sKuaKey,
        info = {ks=sKuaKey, data=mInfo},
    })
end

function CKuaFuMgr:GetKSHost(sKuaKey)
    if get_server_cluster() == "dev" then
        return MY_SERVER_LOCAL_IP    
    else
        local sKey = string.format("%s_%s", get_server_cluster(), sKuaKey)
        local sHost = serverinfo.get_ks_host(sKey)
        return sHost
    end
end

function CKuaFuMgr:Send2KS(sKuaKey, sCmd, mArgs)
    router.Send(sKuaKey, ".world", "kuafu_ks", sCmd, mArgs)
end

function CKuaFuMgr:Request2KS(sKuaKey, sCmd, mArgs, func)
    router.Request(sKuaKey, ".world", "kuafu_ks", sCmd, mArgs, func)
end

---------------------ks remote event----------------------------------
function CKuaFuMgr:RemoteEvent(sEvent, sKuaKey, mData)
    if sEvent == "leave_player" then
        local iPid = mData.pid
        self:LeavePlayer(iPid, sKuaKey)
    elseif sEvent == "player_heart_beat" then
        local iPid = mData.pid
        local mInfo = mData.info
        self:HandlePlayerHeartBeat(iPid, sKuaKey, mInfo)
    elseif sEvent == "player_login_ks" then
        self:HandleSuccessKS(mData)   
    elseif sEvent == "huodong_start" then
        self:HandleStartKSHuodong(sKuaKey, mData)
    elseif sEvent == "huodong_end" then
        self:HandleEndKSHuodong(sKuaKey, mData)
    end
end

function CKuaFuMgr:HandleSuccessKS(mData)
    local iPid = mData.pid
    local oKuaFu = self:GetKuaFuObj(iPid)
    if not oKuaFu then
        record.warning(string.format("CKuaFuMgr:HandleSuccessKS PID(%s) kuafu obj not exist", iPid))
        return
    end

    local iStatus = oKuaFu:GetStatus()
    if iStatus == STATUS_TYPE_PRE_ENTER then
        oKuaFu:SetEnterTime()
        oKuaFu:SetStatus(STATUS_TYPE_SUCCESS_ENTER)
    elseif iStatus == STATUS_TYPE_SUCCESS_ENTER then
        -- 
    else
        record.warning(string.format("CKuaFuMgr:HandleSuccessKS PID(%s) kuafu obj status(%s) error", iPid, iStatus))
    end

    global.oWorldMgr:LogKSInfo("ks_info", {
        iPid = iPid,
        action = "login_ks_end",
        info = {status=iStatus},
    })
end

function CKuaFuMgr:HandlePlayerHeartBeat(iPid, sKuaKey, mInfo)
    local oKuaFu = self:GetKuaFuObj(iPid)
    local oWorldMgr = global.oWorldMgr
    local oPlayer = oWorldMgr:GetOnlinePlayerByPid(iPid)
    if not oKuaFu then
        oKuaFu = self:CreateKuaFuObj(iPid, sKuaKey, mInfo)
        self:AddKuaFuObj(oKuaFu)
        oKuaFu:SetStatus(STATUS_TYPE_SUCCESS_ENTER)
        record.warning(string.format("CKuaFuMgr:HandlePlayerHeartBeat KS(%s) PID(%s) kuafu obj not exist", sKuaKey, iPid))
    end

    oKuaFu:HandleHeartBeat()
    local iStatus = oKuaFu:GetStatus()    
    if table_in_list({STATUS_TYPE_NONE, STATUS_TYPE_PRE_ENTER, STATUS_TYPE_SUCCESS_ENTER}, iStatus) then
        if oPlayer then
            self:HandleSamePlayer(oPlayer)
        end
    elseif iStatus == STATUS_TYPE_SUCCESS_BACK then
        local iNowTime = get_time()
        local iBackTime = oKuaFu:GetBackTime()
        if iNowTime > iBackTime + 3 then
            record.warning(string.format("CKuaFuMgr:HandlePlayerHeartBeat KS(%s) PID(%s) has stauts STATUS_TYPE_SUCCESS_BACK Now(%s) Back(%s)", sKuaKey, iPid, iNowTime, iBackTime))
            self:Send2KS(sKuaKey, "GS2KSLogoutPlayer", {
                pid = iPid,
                code = 1,
            })   
        end
    else
        record.warning(string.format("CKuaFuMgr:HandlePlayerHeartBeat KS(%s) PID(%s) status not handle", sKuaKey, iPid))
    end
end

function CKuaFuMgr:HandleSamePlayer(oPlayer, bKickKS)
    local iPid = oPlayer:GetPid()
    local oKuaFu = self:GetKuaFuObj()
    if not oKuaFu then return end

    local sKuaKey = oKuaFu:GetKuaFuKey()
    if oPlayer:IsForceLogin() or bKickKS then
        self:Send2KS(sKuaKey, "GS2KSLogoutPlayer", {
            pid = iPid,
            code = 1,
        })
    else
        record.warning(string.format("CKuaFuMgr:HandlePlayerHeartBeat KS(%s) has online player(%s)", sKuaKey, iPid))
        global.oWorldMgr:ForceLogout(iPid)
    end
end

function CKuaFuMgr:LeavePlayer(iPid, sKuaKey)
    local oKuaFu = self:GetKuaFuObj(iPid)
    if oKuaFu then
        self:RemoveKuaFuObj(iPid)
    else
        record.warning(string.format("CKuaFuMgr:LeavePlayer KS(%s) leave player(%s) error", sKuaKey, iPid))
    end

    global.oWorldMgr:LogKSInfo("ks_info", {
        iPid = iPid,
        action = "leave_ks",
        info = {ks=sKuaKey},
    })
end

function CKuaFuMgr:HandleStartKSHuodong(sKuaKey, mData)
    local sHdName = mData.hd_name
    local mInfo = mData.hd_info
    local oHuodong = global.oHuodongMgr:GetHuodong(sHdName)
    if not oHuodong then
        record.warning(string.format("CKuaFuMgr:HandleEndKSHuodong KS(%s) not huodong(%s) error", sKuaKey, sHdName)) 
        return
    end
    oHuodong:OnStartKSHuodong(sKuaKey, mInfo)

    global.oWorldMgr:LogKSInfo("ks_huodong", {
        hdname = sHdName,
        action = "ks_hd_start",
        info = mInfo,
    })
end

function CKuaFuMgr:HandleEndKSHuodong(sKuaKey, mData)
    local sHdName = mData.hd_name
    local oHuodongMgr = global.oHuodongMgr
    local oHuodong = oHuodongMgr:GetHuodong(sHdName)
    if not oHuodong then
        record.warning(string.format("CKuaFuMgr:HandleEndKSHuodong KS(%s) not huodong(%s) error", sKuaKey, sHdName)) 
        return
    end
    oHuodong:OnEndKSHuodong(sKuaKey)

    global.oWorldMgr:LogKSInfo("ks_huodong", {
        action = "ks_hd_end",
        hdname = sHdName,
        info = {},
    })
end

---------------------ks remote event end-----------------------

function CKuaFuMgr:RemoteLoadOffline(sKey, iPid, endfunc)
    global.oWorldMgr:LoadOfflineBlock(sKey, iPid, function (obj)
        if obj then
            endfunc(obj:Save())
        else
            endfunc()
        end
    end)
end

function CKuaFuMgr:SavePlayerAllInfo(mData)
    local iPid = mData.pid
    local oPlayer = global.oWorldMgr:GetOnlinePlayerByPid(iPid)
    if oPlayer then
        return {errcode = 1}
    end

    local lAllSave = mData.all_save
    for _, lSave in ipairs(lAllSave) do
        local mSave, sModule = table.unpack(lSave)
        gamedb.SaveDb(iPid, "common", "DbOperate", mSave)
    end
    local oKuaFuObj = self:GetKuaFuObj(iPid)
    if oKuaFuObj then
        oKuaFuObj:SetStatus(STATUS_TYPE_SUCCESS_BACK)
        oKuaFuObj:SetBackTime()
    end
    local iOnlineCnt = global.oWorldMgr:GetOnlinePlayerCnt()
    if iOnlineCnt >= gamedefines.QUEUE_CNT then
        record.warning(string.format("CKuaFuMgr:BackGS online player have %s", iOnlineCnt))        
    end
    return {errcode = 0}
end

function CKuaFuMgr:SavePlayerModuleInfo(mData)
    local iPid = mData.pid
    local oPlayer = global.oWorldMgr:GetOnlinePlayerByPid(iPid)
    if oPlayer then
        self:HandleSamePlayer(oPlayer)
        record.warning(string.format("CKuaFuMgr:SavePlayerModuleInfo exist same player PID(%s)", iPid))
        return        
    end

    local mSave = mData.module_save
    gamedb.SaveDb(iPid, "common", "DbOperate", mSave)
end

--------------------KuaFu------------------------------
function NewKuaFuObj(...)
    return CKuaFuObj:New(...)
end

CKuaFuObj = {}
CKuaFuObj.__index = CKuaFuObj
inherit(CKuaFuObj, logic_base_cls())

function CKuaFuObj:New(iPid)
    local o = super(CKuaFuObj).New(self)
    o:Init(iPid)
    return o
end

function CKuaFuObj:Init(iPid)
    self.m_iPid = iPid
    self.m_iStatus = STATUS_TYPE_PRE_ENTER
    self.m_sKuaFuKey = ""
    self.m_mInfo = {}
    self.m_iHeartBeatTime = 0
    self.m_iEnterTime = 0
    self.m_iCheckCnt = 0
    self.m_iBackTime = 0
end

function CKuaFuObj:Create(sKuaFuKey, mInfo)
    self.m_sKuaFuKey = sKuaFuKey
    self.m_mInfo = mInfo
end

function CKuaFuObj:Load(mData)
    if not mData then return end

    self.m_iStatus = mData.status
    self.m_sKuaFuKey = mData.kuafukey
    self.m_mInfo = mData.info
    self.m_iEnterTime = mData.entertime
end

function CKuaFuObj:Save()
    return {
        status = self.m_iStatus,
        kuafukey = self.m_sKuaFuKey,
        info = self.m_mInfo,
        entertime = self.m_iEnterTime,
    }
end

function CKuaFuObj:GetPid()
    return self.m_iPid
end

function CKuaFuObj:GetKuaFuKey()
    return self.m_sKuaFuKey
end

function CKuaFuObj:GetInfo()
    return self.m_mInfo
end

function CKuaFuObj:SetEnterTime()
    self.m_iEnterTime = get_time()
end

function CKuaFuObj:SetBackTime()
    self.m_iBackTime = get_time()
end

function CKuaFuObj:GetBackTime()
    return self.m_iBackTime or 0
end

function CKuaFuObj:SetStatus(iStatus)
    self.m_iStatus = iStatus
    global.oKuaFuMgr:UpdateKuaFuDB(self)
end

function CKuaFuObj:GetStatus()
    return self.m_iStatus
end

function CKuaFuObj:HandleHeartBeat()
    self.m_iHeartBeatTime = get_time()
end

function CKuaFuObj:IsActive()
    local iNowTime = get_time()
    local iSecond = gamedefines.KS_PLAYER_HT_INTERVAL * 3
    if iNowTime - self.m_iHeartBeatTime <= iSecond then
        return true
    end
    return false
end

function CKuaFuObj:Schedule()
    self:CheckHeartBeat()    
end

function CKuaFuObj:CheckHeartBeat()
    local iPid = self:GetPid()
    local iSecond = 15*60

    local f
    f = function ()
        local oKuaFuObj = global.oKuaFuMgr:GetKuaFuObj(iPid)
        if oKuaFuObj then
            oKuaFuObj:DelTimeCb("_CheckHeartBeat")
            oKuaFuObj:AddTimeCb("_CheckHeartBeat", iSecond*1000, f)
            oKuaFuObj:_CheckHeartBeat()
        end
    end
    self:AddTimeCb("_CheckHeartBeat", iSecond*1000, f)
end

function CKuaFuObj:_CheckHeartBeat()
    local iNowTime = get_time()

    local iSecond = (self.m_iCheckCnt + 1) * 60 * 60
    if iNowTime - self.m_iHeartBeatTime >= iSecond then
        self.m_iCheckCnt = self.m_iCheckCnt + 1
        record.warning(string.format("CKuaFuObj:_CheckHeartBeat error PID:%s KS:%s stauts:%s", self:GetPid(), self:GetKuaFuKey(), self:GetStatus()))
    end 
end

