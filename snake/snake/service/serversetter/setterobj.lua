--import module

local global = require "global"
local skynet = require "skynet"
local interactive = require "base.interactive"
local record = require "public.record"
local httpuse = require "public.httpuse"
local router = require "base.router"
local serverdefines = require "public.serverdefines"
local res = require "base.res"
local cjson = require "cjson"

local ipoperate = import(lualib_path("public.ipoperate"))
local gamedefines = import(lualib_path("public.gamedefines"))
local datactrl = import(lualib_path("public.datactrl"))
local serverinfo = import(lualib_path("public.serverinfo"))
local channelinfo = import(lualib_path("public.channelinfo"))
local gamedb = import(lualib_path("public.gamedb"))

function NewSetterMgr(...)
    local o = CSetterMgr:New(...)
    return o
end

CSetterMgr = {}
CSetterMgr.__index = CSetterMgr
CSetterMgr.c_sDbKey = "svrsetter"
inherit(CSetterMgr, datactrl.CDataCtrl)

function CSetterMgr:New()
    local o = super(CSetterMgr).New(self)
    o.m_mServerSettings = {}
    o.m_mAreaName = {}
    o.m_iNoticeVer = 0
    o.m_iNoticeId = 0
    o.m_mNotices = {}
    o.m_iWhiteAccountId = 0
    o.m_iSetterVer = 1              -- 1 start, not save db
    o.m_mWhiteAccounts = {}
    o.m_iBlackIpId = 0
    o.m_mBlackIp = {}               -- {id=ip, } 
    o.m_iBlackAccountId = 0
    o.m_mBlackAccount = {}          -- {id={account="", channel=0}}
    o.m_mShenheInfo = {}
    o.m_mLinkServers = {}

    o.m_lPubNoticeCache = nil
    o.m_mServerStatus = {}
    return o
end

function CSetterMgr:Save()
    local mData = {}
    mData.srv = self.m_mServerSettings
    mData.area_name = self.m_mAreaName
    mData.notice_ver = self.m_iNoticeVer
    mData.notice_id = self.m_iNoticeId
    mData.notice = self.m_mNotices
    mData.white_account_id = self.m_iWhiteAccountId
    mData.white_account = self.m_mWhiteAccounts
    mData.black_ip_id = self.m_iBlackIpId
    mData.black_ip = self.m_mBlackIp
    mData.black_account_id = self.m_iBlackAccountId
    mData.black_account = self.m_mBlackAccount
    mData.shenhe_info = self.m_mShenheInfo
    return mData
end

function CSetterMgr:Load(mData)
    mData = mData or {}
    self.m_mServerSettings = mData.srv or {}
    self.m_mAreaName = mData.area_name or {}
    self.m_iNoticeVer = mData.notice_ver or 0
    self.m_iNoticeId = mData.notice_id or 0
    self.m_mNotices = mData.notice or {}
    self.m_iWhiteAccountId = mData.white_account_id or 0
    self.m_mWhiteAccounts = mData.white_account or {}
    self.m_iBlackIpId = mData.black_ip_id or 0
    self.m_mBlackIp = mData.black_ip or {}
    self.m_iBlackAccountId = mData.black_account_id or 0
    self.m_mBlackAccount = mData.black_account or {}
    self.m_mShenheInfo = mData.shenhe_info or {}
    self:InitLinkServers()
end

function CSetterMgr:InitLinkServers()
    local mLinkServers = {}
    for k, v in pairs(self:GetAllServerSetting()) do
        local sLink = v["link_server"]
        if not sLink then
            sLink = k
        end
        local m = mLinkServers[sLink]
        if not m then
            m = {}
            mLinkServers[sLink] = m
        end
        m[k] = 1
    end
    self.m_mLinkServers = mLinkServers
end

function CSetterMgr:GetLinkServers(sServerKey)
    return self.m_mLinkServers[sServerKey] or {}
end

function CSetterMgr:LoadDb()
    if self:IsLoaded() then return end
    local mInfo = {
        module = "globaldb",
        cmd = "LoadGlobal",
        cond = {name = self.c_sDbKey},
    }
    gamedb.LoadDb("serversetter", "common", "DbOperate", mInfo,
        function (mRecord, mData)
            if not self:IsLoaded() then
                self:Load(mData.data)
                self:OnLoaded()
            end
        end)
end

function CSetterMgr:SaveDb()
    if not self:IsLoaded() then return end
    if self:IsDirty() then
        local mInfo = {
            module = "globaldb",
            cmd = "SaveGlobal",
            cond = {name = self.c_sDbKey},
            data = {data = self:Save()},
        }
        gamedb.SaveDb("serversetter", "common", "DbOperate", mInfo)
        self:UnDirty()
    end
end

function CSetterMgr:CheckServerMatch(sServerKey, iPlatform, iChannel, sCpsChannel, lArea)
    local mSetting = self:GetServerSetting(sServerKey)
    local sServerKey = mSetting["link_server"] or sServerKey
    if not self:IsMatchedArea(sServerKey, lArea) then
        return false
    end
    if not self:IsMatchedPlatform(sServerKey, iPlatform) then
        return false
    end
    return true
end

function CSetterMgr:IsMatchedArea(sServerKey, lArea)
    local mSetting = self:GetServerSetting(sServerKey)
    for _, iArea in ipairs(lArea) do
        if table_in_list(mSetting.area, iArea) then
            return true
        end
    end
    return false
end

function CSetterMgr:IsMatchedPlatform(sServerKey, iPlatform)
    local mSetting = self:GetServerSetting(sServerKey)
    return table_in_list(mSetting.platforms, iPlatform)
end

function CSetterMgr:GetVisibleServers(mArgs)
    local iChannel = mArgs.channel
    local iPlatform = mArgs.platform
    local sCpsChannel = mArgs.cps
    local lArea = mArgs.area or {}
    local sKey = mArgs.ckey
    local sName = mArgs.cname
    local sIP = mArgs.ip
    local sAccount = mArgs.account

    --TODO 对某个包的特殊处理,包下架后可以删除,主要让包不能进服务器
    if not mArgs.startver and not sKey and not sName then
        return {["h7d-fake"] = self:GetServerInfo("h7d-fake")}
    end

    local sStartVer = self:TransVer(mArgs.startver)
    local mServers = {}
    local bIsWhiteIP = ipoperate.is_white_ip(sIP) or self:IsWhiteListAccount(sAccount, iChannel)
    local lShenhes = self:GetShenhe(sKey, sName, sStartVer)
    if lShenhes then
        for _, k in ipairs(lShenhes) do
            local mServer = self:GetServerInfo(k)
            if (mServer.is_neifu ~= 1 or bIsWhiteIP) then
                mServers[k] = mServer
            end
        end
    else
        for sServerKey, _ in pairs(self:GetAllServerSetting()) do
            if not self:CheckServerMatch(sServerKey, iPlatform, iChannel, sCpsChannel, lArea) then
                goto continue
            end
            local mServer = self:GetServerInfo(sServerKey)
            if mServer.is_show ~= 1 then
                goto continue
            end
            if mServer.is_neifu ~= 1 or bIsWhiteIP then
                mServers[sServerKey] = mServer
            end
            ::continue::
        end
    end
    return mServers
end

function CSetterMgr:GetClientServerList(mArgs)
    local iChannel = mArgs.channel
    local iPlatform = mArgs.platform
    local sCpsChannel = mArgs.cps
    local iVer = mArgs.version or 0
    local sCname = mArgs.cname

    local mRet = {}
    mRet["ports"] = split_string(GS_GATEWAY_PORTS, ",", tonumber)
    mRet["serverInfoList"] = {}
    local iNowTime = get_time()
    local lRecommemd = {}
    local mServers = self:GetVisibleServers(mArgs)
    for sServerKey, mServer in pairs(mServers) do
        local sLinkServer = mServer["link_server"] or sServerKey
        local mServer = self:GetServerInfo(sServerKey)
        local mData = {
            id = sServerKey,
            index = mServer["index"],
            new = mServer["is_new"],
            state = global.oStatusMgr:GetRunState(sLinkServer),
            name = mServer["name"],
            ip = mServer["ip"],
            -- platform = mServer["platforms"],
            area = mServer["area"],
            desc = mServer["desc"],
            linkserver = sLinkServer,
        }
        local iOpenTime = mServer["open_time"]
        if iOpenTime and iOpenTime > iNowTime then
            mData["refreshtime"] = iOpenTime - iNowTime
            mData["opentime"] = iOpenTime
        end
        table.insert(mRet["serverInfoList"], mData)
        local iRecommend = mServer["recommend"]
        if iRecommend and iRecommend > 0 then
            table.insert(lRecommemd, sServerKey)
        end
        ::continue::
    end
    mRet["RecommendServerList"] = lRecommemd
    if serverinfo.is_h7d_server() then
        mRet["AreaName"] = self.m_mAreaName
    end
    mRet = table_combine(mRet, self:GetClientNotice(iVer, iPlatform, iChannel, sCname))
    return mRet
end

function CSetterMgr:GetServerInfo(sServerKey)
    local mSetting = self:GetServerSetting(sServerKey)
    local mConfig = serverinfo.get_gs_info(mSetting["link_server"] or sServerKey) or {}
    local mData = {
        id = sServerKey,
        ip = mConfig.client_host,
        name = mSetting.name,
        -- platforms = tostring(mConfig.desc),
        index = mSetting.index,
        start_time = mSetting.start_time,
        open_time = mSetting.open_time,
        run_state = mSetting.run_state,
        is_new = mSetting.is_new,
        is_show = mSetting.is_show,
        recommend = mSetting.recommend,
        area = mSetting.area,
        desc = mSetting.desc,
        link_server = mSetting.link_server,
        is_neifu = mSetting.is_neifu,
    }
    return mData
end

function CSetterMgr:GetServerList()
    local lRet = {}
    for gs_key, info in pairs(self:GetAllServerSetting()) do
        table.insert(lRet, self:GetServerInfo(gs_key))
    end
    return lRet
end

function CSetterMgr:MakeDefaultSetting()
    local mSettings = {}
    local iCnt = 0
    local iTime = os.time({year=2017, month=11, day=11})
    for _, gs_key in ipairs(serverinfo.get_gs_key_list()) do
        local mInfo = serverinfo.get_gs_info(gs_key)
        iCnt = iCnt + 1
        local mElement = {
            ["index"] = iCnt,
            ["start_time"] = iTime,
            ["open_time"] = iTime,
            ["run_state"] = 1,
            ["is_new"] = 0,
            ["recommend"] = 1,
            ["area"] = {1},
            ["name"] = mInfo["name"],
            ["ip"] = mInfo["client_host"],
            ["link_server"] = gs_key,
            ["is_show"] = 1,
            ["desc"] = "维护中，请您耐心等待",
            ["platforms"] = {gamedefines.PLATFORM.android, gamedefines.PLATFORM.pc, gamedefines.PLATFORM.ios},
            ["queue_num"] = 4000,
            ["online_limit"] = 5000,
            ["is_neifu"] = 0,
        }
        mSettings[gs_key] = mElement
    end
    return mSettings
end

function CSetterMgr:GetAllServerSetting()
    if serverinfo.is_h7d_server() then
        local mSetting = self.m_mServerSettings
        local bMerger = serverinfo.is_h7d_merger()
        if bMerger or not mSetting or not next(mSetting) then
            if not self.m_mDefaultSettings then
                self.m_mDefaultSettings = self:MakeDefaultSetting()
            end
            mSetting = self.m_mDefaultSettings
        end
        return mSetting
    else
        return res["daobiao"]["serverinfo"][get_server_cluster()] or {}
    end
end

function CSetterMgr:GetServerSetting(sServer)
    local mSettingInfo = self:GetAllServerSetting()
    if not mSettingInfo then
        record.warning("not find server setting error 1 %s", sServer) 
        return {} 
    end
    if not mSettingInfo[sServer] then
        record.warning("not find server setting error 2 %s", sServer) 
        return {}  
    end
    return mSettingInfo[sServer]
end

function CSetterMgr:FormatStr2Second(sTime)
    local Y = string.sub(sTime, 1, 4)
    local m = string.sub(sTime, 6, 7)
    local d = string.sub(sTime, 9, 10)
    local H = string.sub(sTime, 12, 13)
    local M = string.sub(sTime, 15, 16)
    local S = string.sub(sTime, 18, 19)
    return os.time({year=Y, month=m, day=d, hour=H, min=M, sec=S})
end

mPlatformMap = {
    [1] = gamedefines.PLATFORM.android,
    [2] = gamedefines.PLATFORM.pc,
    [3] = gamedefines.PLATFORM.ios,
}

function CSetterMgr:TransPlatform(lPlatform)
    if not lPlatform then
        return
    end
    local ret = {}
    for _, iPlat in ipairs(lPlatform) do
        local iRet = mPlatformMap[iPlat]
        if iRet then
            table.insert(ret, iRet)
        end
    end
    return ret
end

function CSetterMgr:SaveOrUpdateServer(mArgs)
    self:Dirty()
    local mData = mArgs["data"] or {}
    for _, info in pairs(mData) do
        local sServerKey = info["id"]
        local mSettingInfo = self.m_mServerSettings[sServerKey]
        if not mSettingInfo then
            mSettingInfo = {}
            self.m_mServerSettings[sServerKey] = mSettingInfo
        end
        local sStartTime = info.openAtStr or mSettingInfo.start2str
        local iStartTime = self:FormatStr2Second(sStartTime)
        local sOpenTime = info.openTime or mSettingInfo.open2str
        local iOpenIime = self:FormatStr2Second(sOpenTime)
        mSettingInfo.index = info.serverIndex or mSettingInfo.serverindex
        mSettingInfo.start_time = iStartTime
        mSettingInfo.start2str = sStartTime
        mSettingInfo.open_time = iOpenIime
        mSettingInfo.open2str = sOpenTime
        mSettingInfo.run_state = info.runStat or mSettingInfo.run_state
        mSettingInfo.is_new = info.isNewServer or mSettingInfo.is_new
        mSettingInfo.recommend = info.recommend or mSettingInfo.recommend
        mSettingInfo.area = self:GetAreaList(info.areas) or mSettingInfo.area  -- 分区
        mSettingInfo.name = info.name or mSettingInfo.name
        mSettingInfo.ip = info.ip or mSettingInfo.ip
        mSettingInfo.link_server = info.linkServer or mSettingInfo.link_server
        mSettingInfo.is_show = info.isShow or mSettingInfo.is_show
        mSettingInfo.desc = info.desc or mSettingInfo.desc
        mSettingInfo.platforms = self:TransPlatform(info.platforms) or mSettingInfo.platforms
        mSettingInfo.queue_num = info.queStartNum or mSettingInfo.queue_num
        mSettingInfo.online_limit = info.onlineMaxLimit or mSettingInfo.online_limit
        mSettingInfo.is_neifu = info.isNeiFu or mSettingInfo.is_neifu
    end
    self:SaveDb()
    self:InitLinkServers()
    self:DispatchSetterVer()
end

function CSetterMgr:DeleteServer(ids)
    self:Dirty()
    for _, sServerKey in ipairs(split_string(ids, ",")) do
        self.m_mServerSettings[sServerKey] = nil
    end
    self:SaveDb()
    self:InitLinkServers()
    self:DispatchSetterVer()
end

function CSetterMgr:GetAreaList(mArea)
    self:Dirty()
    local lAreas = {}
    local mAreaName = self.m_mAreaName
    for _, m in ipairs(mArea) do
        mAreaName[m["id"]] = m["name"]
        table.insert(lAreas, m["id"])
    end
    return lAreas
end

function CSetterMgr:GetShenhe(sKey, sName, sVer)
    local l = self.m_mShenheInfo[sKey]
    if l and l[sName] then
        return l[sName][sVer]
    end
    return nil
end

function CSetterMgr:SaveOrUpdateShenhe(mData)
    self:Dirty()
    for k, l in pairs(mData) do
        local mInfo = {}
        for _, m in ipairs(l) do
            local sName = m["name"]
            local sVer = self:TransVer(m["ver"])
            local lServers = m["servers"]
            local mVers = mInfo[sName]
            if not mVers then
                mVers = {}
                mInfo[sName] = mVers
            end
            if type(lServers) == "table" then
                mVers[sVer] = lServers    
            end
        end
        self.m_mShenheInfo[k] = mInfo
    end
end

function CSetterMgr:TransVer(sVer)
    return string.gsub(sVer, "%.", "-")
end

function CSetterMgr:GetWhiteAccountList()
    -- self:Dirty()
    local lRet = {}
    for id, m in pairs(self.m_mWhiteAccounts) do
        table.insert(lRet, {
            id = tonumber(id), 
            account = m.account, 
            channel = m.channel,
            pid = m.pid,
            name = m.name,
            time = m.time,
        })
    end
    return lRet
end

function CSetterMgr:DispatchWhiteAccountID()
    self:Dirty()
    self.m_iWhiteAccountId = self.m_iWhiteAccountId + 1
    self:SaveDb()
    return self.m_iWhiteAccountId
end

function CSetterMgr:SaveWhiteAccount(mData)
    self:Dirty()
    local iId = self:DispatchWhiteAccountID()
    self.m_mWhiteAccounts[tostring(iId)] = {
        account = mData.account,
        channel = tonumber(mData.channel),
        pid = mData.pid,
        name = mData.name,
        time = get_time()
    }
    self:DispatchSetterVer()
    self:SaveDb()
end

function CSetterMgr:DeleteWhiteAccount(ids)
    self:Dirty()
    for _, id in ipairs(ids) do
        self.m_mWhiteAccounts[tostring(id)] = nil
    end
    self:DispatchSetterVer()
    self:SaveDb()
end

function CSetterMgr:IsWhiteListAccount(sAccount, iChannel)
    local mWhiteList = self.m_mWhiteAccounts or {}
    for _, mData in pairs(mWhiteList) do
        if mData.account == sAccount and mData.channel == iChannel then
            return true
        end
    end
    return false
end

function CSetterMgr:GetClientNotice(iVer, iPlatform, iChannel, sCps)
    local iVer = iVer or 0
    local iCurVer = self:GetNoticeVersion()
    local mRet = {notice_version=iCurVer, infoList={}}
    if iVer >= iCurVer then
        return mRet
    end 
    mRet.infoList = self:GetPublisNoticeList(iPlatform, iChannel, sCps)
    return mRet
end

function CSetterMgr:DispatchNoticeId()
    self:Dirty()
    self.m_iNoticeId = self.m_iNoticeId + 1
    self:SaveDb()
    return self.m_iNoticeId
end

function CSetterMgr:DispatchNoticeVer()
    self:Dirty()
    self.m_iNoticeVer = self.m_iNoticeVer + 1
    self:SaveDb()
    return self.m_iNoticeVer
end

function CSetterMgr:GetNoticeVersion()
    return self.m_iNoticeVer
end

function CSetterMgr:GeneratePubNoticeCache()
    local lNotice = {}
    for id, info in pairs(self.m_mNotices) do
        if info.state ~= 0 then
            table.insert(lNotice, {id, info.pubtime or 0})
        end
    end
    table.sort(lNotice, function (a, b)
        if a[2] == b[2] then
            return false
        end
        return a[2] > b[2]
    end)
    self.m_lPubNoticeCache = lNotice 
end

function CSetterMgr:GetPublisNoticeList(iPlatform, iChannel, sCps)
    if not self.m_lPubNoticeCache then
        self:GeneratePubNoticeCache()
    end

    local lRet = {}
    for _, lCache in pairs(self.m_lPubNoticeCache) do
        local mInfo = self.m_mNotices[lCache[1]]
        if mInfo and self:CheckNotice(mInfo, iPlatform, iChannel, sCps) then
            table.insert(lRet, {title=mInfo.title, content=mInfo.content}) 
        end
    end
    return lRet
end

function CSetterMgr:GetNoticeList()
    local lRet = {}
    for _, info in pairs(self.m_mNotices) do
        table.insert(lRet, info) 
    end
    return lRet
end

function CSetterMgr:ValidNoticeInfo(mInfo)
    local lPlatform = mInfo.platform
    local lChannel = mInfo.channel
    local lCps = mInfo.cps
    if lPlatform and type(lPlatform) ~= "table" then
        record.warning("save or update notice platform err")
        return false
    end 
    if lChannel and type(lChannel) ~= "table" then
        record.warning("save or update notice channel err")
        return false
    end 
    if lCps and type(lCps) ~= "table" then
        record.warning("save or update notice cps err")
        return false
    end
    if not mInfo.title or not mInfo.content then
        record.warning("save or update notice info err")
        return false
    end
    return true
end

function CSetterMgr:CheckNotice(mInfo, iPlatform, iChannel, sCps)
    if mInfo.state == 0 then
        return false
    end
    if mInfo.platform and table_count(mInfo.platform) > 0 and not table_in_list(mInfo.platform, iPlatform) then
        return false
    end
    if mInfo.channel and table_count(mInfo.channel) > 0 and not table_in_list(mInfo.channel, iChannel) then
        return false
    end
    if mInfo.cps and table_count(mInfo.cps) > 0 and not table_in_list(mInfo.cps, sCps) then
        return false
    end
    return true
end

function CSetterMgr:SaveOrUpdateNotice(mData)
    if not self:ValidNoticeInfo(mData) then return end

    local id = mData["id"] 
    if not id or id <= 0 then
        mData["id"] = tostring(self:DispatchNoticeId())
        self.m_mNotices[mData["id"]] = mData
    else
        self.m_mNotices[tostring(mData["id"])] = mData
        self:DispatchNoticeVer()
        self:GeneratePubNoticeCache()
    end
    self:Dirty()
    self:SaveDb()
end

function CSetterMgr:DeleteNotice(ids)
    self:Dirty()
    for _, id in pairs(ids) do
        self.m_mNotices[tostring(id)] = nil
    end
    self:DispatchNoticeVer()
    self:GeneratePubNoticeCache()
    self:SaveDb()
end

function CSetterMgr:PublishNotice(ids)
    self:Dirty()
    for _, id in pairs(ids) do
        id = tostring(id)
        if self.m_mNotices[id] then
            self.m_mNotices[id].state = 1
            self.m_mNotices[id].pubtime = get_time()
        end
    end
    self:DispatchNoticeVer()
    self:GeneratePubNoticeCache()
    self:SaveDb()
end

function CSetterMgr:GetChannelList()
    local res = require "base.res"
    local lRet = {}
    local mChannelInfo = channelinfo.get_channel_info()
    for sKey, mData in pairs(mChannelInfo) do
        table.insert(lRet, {
            id = sKey, 
            relatedId = sKey, 
            description = mData["name"], 
            platforms = "0"
        })
    end
    if not is_production_env() then
        table.insert(lRet, {id = 0, relatedId = 0, description = "测试", platforms = "0"})
    end
    return lRet
end

function CSetterMgr:DispatchSetterVer()
    self.m_iSetterVer = self.m_iSetterVer + 1
    self:PushSetting2GS()
end

function CSetterMgr:DispatchBlackIpId()
    self:Dirty()
    self.m_iBlackIpId = self.m_iBlackIpId + 1
    self:SaveDb()
    return self.m_iBlackIpId
end

function CSetterMgr:DispatchBlackAccountId()
    self:Dirty()
    self.m_iBlackAccountId = self.m_iBlackAccountId + 1
    self:SaveDb()
    return self.m_iBlackAccountId
end

function CSetterMgr:GetBlackIpList()
    local lRet = {}
    for id, sIP in pairs(self.m_mBlackIp) do
        table.insert(lRet, {id = tonumber(id), ip = sIP})
    end
    return lRet
end

function CSetterMgr:SaveBlackIp(mData)
    self:Dirty()
    local sIP = mData["ip"]
    local id = self:DispatchBlackIpId()
    self.m_mBlackIp[tostring(id)] = sIP
    self:DispatchSetterVer()
    self:SaveDb()
end

function CSetterMgr:DeleteBlackIp(ids)
    self:Dirty()
    for _, id in pairs(ids) do
        self.m_mBlackIp[tostring(id)] = nil
    end
    self:DispatchSetterVer()
    self:SaveDb()
end

function CSetterMgr:GetBlackAccountList()
    local lRet = {}
    for pid, mInfo in pairs(self.m_mBlackAccount) do
        table.insert(lRet, {
            id = pid,
            account = mInfo.account,
            channel = mInfo.channel,
            name = mInfo.name or "",
            time = mInfo.time or get_time(),
        })
    end
    return lRet
end

function CSetterMgr:SaveBlackAccount(mArgs)
    local iPid = mArgs.pid
    local mInfo = {
        module = "roleinfodb",
        cmd = "FindOne",
        cond = {pid = iPid},
    }
    gamedb.LoadDb("serversetter", "common", "DbOperate", mInfo, function (mRecord, mData)
        self:_SaveBlackAccount(mData.data)
    end)

end

function CSetterMgr:_SaveBlackAccount(mInfo)
    local iPid = mInfo.pid
    if not iPid then
        record.warning("CSetterMgr:_SaveBlackAccount error not find pid") 
        return
    end 

    local sAccount = mInfo.account
    local iChannel = mInfo.channel
    local sName = mInfo.name
    local id = self:DispatchBlackAccountId()
    self.m_mBlackAccount[iPid] = {
        account = mInfo.account,
        channel = mInfo.channel,
        name = mInfo.name,
        time = get_time()
    }
    self:DispatchSetterVer()
    self:SaveDb()
end

function CSetterMgr:DeleteBlackAccount(ids)
    self:Dirty()
    for _, id in pairs(ids) do
        self.m_mBlackAccount[id] = nil
    end
    self:DispatchSetterVer()
    self:SaveDb()
end

function CSetterMgr:PackWhiteAccountList()
    local lRet = {}
    for id, m in pairs(self.m_mWhiteAccounts) do
        table.insert(lRet, {account=m.account, channel=m.channel})
    end
    return lRet
end

function CSetterMgr:PackIpBlacklist()
    local mRet = {}
    for _, sIP in pairs(self.m_mBlackIp) do
        mRet[sIP] = 1
    end
    return mRet
end

function CSetterMgr:PackAccountBlacklist()
    local lRet = {}
    for id, m in pairs(self.m_mBlackAccount) do
        table.insert(lRet, {account=m.account, channel=m.channel})
    end
    return lRet
end

function CSetterMgr:GetSetterConfig(sServerKey, iVer)
    local mData = {version = self.m_iSetterVer}
    if iVer == self.m_iSetterVer then
        return mData
    end
    mData["whitelist"] = self:PackWhiteAccountList()
    mData["black_ip"] = self:PackIpBlacklist()
    mData["black_account"] = self:PackAccountBlacklist()
    mData["server_info"] = self:GetServerSetting(sServerKey)
    mData["link_server"] = self:GetLinkServers(sServerKey)
    return mData
end

function CSetterMgr:PushSetting2GS()
    for _, sServerKey in pairs(serverinfo.get_gs_key_list()) do
        local mData = {errcode = 0, data = self:GetSetterConfig(sServerKey, 0)}
        router.Send(get_server_tag(sServerKey), ".login", "common", "CSSetSetterConfig", mData)
    end
end

function CSetterMgr:SetServerStatus(mData)
    for sKey, mInfo in pairs(mData or {}) do
        self.m_mServerStatus[sKey] = mInfo
    end
end

function CSetterMgr:PackServerStatus(mExt)
    local mResult = {}
    for sKey, mInfo in pairs(self.m_mServerStatus) do
        mResult[sKey] = mInfo or {}
        mResult[sKey]["heartbeat"] = mExt[sKey] or 0
        mResult["whitelist"] = self:PackWhiteAccountList()
    end
    return mResult
end
