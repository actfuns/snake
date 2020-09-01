local global = require "global"
local extend = require "base.extend"

local datactrl = import(lualib_path("public.datactrl"))
local mailobj = import(service_path("mail.mailobj"))

function NewSysMailCache(...)
    return CSysMailCache:New(...)
end

CSysMailCache = {}
CSysMailCache.__index = CSysMailCache
inherit(CSysMailCache, datactrl.CDataCtrl)

function CSysMailCache:New()
    local o = super(CSysMailCache).New(self)
    o:Init()
    return o
end

function CSysMailCache:Init()
    self.m_mSysMails = {}
    self:SetData("version", 0)
end

function CSysMailCache:Load(mData)
    if not mData then return end

    self:SetData("version", mData.version or 0)
    for sMailId, info in pairs(mData.mails or {}) do
        local iMail = tonumber(sMailId)
        local oMail = NewMailCacheObj(iMail)
        oMail:Load(info)
        if not oMail:IsExpire() then
            self.m_mSysMails[iMail] = oMail
        else
            baseobj_delay_release(oMail)
        end
    end
end

function CSysMailCache:Save()
    local mData = {}
    mData.version = self:GetData("version")
    local mMails = {}
    for iMail, oMail in pairs(self.m_mSysMails) do
        mMails[db_key(iMail)] = oMail:Save()
    end
    mData.mails = mMails
    return mData
end

function CSysMailCache:MergeFrom(mData)
    self:Dirty()
    self:SetData("version", math.max(self:GetData("version"), mData.version))
    self.m_mSysMails = {}
    return true
end

function CSysMailCache:GetNewVersion()
    local iVer = self:GetData("version", 0) + 1
    self:SetData("version", iVer)
    return iVer
end

function CSysMailCache:CheckValid()
    local lVersion = {}
    for iVer, oMail in pairs(self.m_mSysMails) do
        if oMail:IsExpire() then
            table.insert(lVersion, iVer)
        end
    end
    if #lVersion <= 0 then return end

    self:Dirty()
    for _, iVer in pairs(lVersion) do
        local oMail = self.m_mSysMails[iVer]
        self.m_mSysMails[iVer] = nil
        baseobj_delay_release(oMail)
    end
end

function CSysMailCache:CreateMailCacheObj(iVer, mData)
    local oMail = NewMailCacheObj(iVer)
    oMail:Create(mData)
    return oMail
end

function CSysMailCache:AddSysMail(mData)
    self:Dirty()

    -- 都是按version顺序
    local iVer = self:GetNewVersion()
    local oMail = self:CreateMailCacheObj(iVer, mData)
    self.m_mSysMails[iVer] = oMail
end

function CSysMailCache:CheckOnlinePlayerMail()
    local mPids = {}
    for iPid, _ in pairs(global.oWorldMgr:GetOnlinePlayerList()) do
        mPids[iPid] = true
    end
    self:_CheckOnlinePlayer(mPids)
end

function CSysMailCache:_CheckOnlinePlayer(mPids)
    self:DelTimeCb("_CheckOnlinePlayer")
    if not next(mPids) then return end

    local lCheckPid = {}
    local oWorldMgr = global.oWorldMgr
    for iPid, _ in pairs(mPids) do
        local oPlayer = oWorldMgr:GetOnlinePlayerByPid(iPid)
        if oPlayer then
            table.insert(lCheckPid, iPid)
            self:LoginCheckSysMail(oPlayer)
        end

        -- 100封大概0.015 
        if #lCheckPid >= 400 then break end
    end
    for _, iPid in pairs(lCheckPid) do
        mPids[iPid] = nil
    end

    self:AddTimeCb("_CheckOnlinePlayer", 1 * 1000, function ()
        self:_CheckOnlinePlayer(mPids)
    end)
end


function CSysMailCache:LoginCheckSysMail(oPlayer)
    local oMailBox = oPlayer:GetMailBox()
    local iSysVersion = self:GetData("version")
    local iCurVersion = oMailBox:GetSysVersion()
    if iCurVersion >= iSysVersion then return end

    self:CheckValid()
    oMailBox:SetSysVersion(iSysVersion)
    for i = iCurVersion + 1, iSysVersion do
        local oMail = self.m_mSysMails[i]
        if oMail and oMail:IsValid(oPlayer) then
            oMail:SendSysMail(oPlayer:GetPid())
        end
    end
end

-- 具体对象，不做定时发送
function NewMailCacheObj(...)
    return CMailCacheObj:New(...)
end

CMailCacheObj = {}
CMailCacheObj.__index = CMailCacheObj
inherit(CMailCacheObj, datactrl.CDataCtrl)

function CMailCacheObj:New(iMailId)
    local o = super(CMailCacheObj).New(self, {mailid=iMailId})
    o:Init()
    return o
end

function CMailCacheObj:Init()
    self.m_iStartTime = 0
    self.m_iEndTime = 0
    self.m_lChannels = {}
    self.m_bAllChannel = false
    self.m_lPlatforms = {}
    self.m_bPlatforms = false
    self.m_iMinGrade = 0
    self.m_iMaxGrade = 0
    self.m_iCreateTime = 0

    self.m_sTitle = ""
    self.m_sContext = ""
    self.m_lItem = {}
    self.m_lSummon = {}
end

function CMailCacheObj:Create(mData)
    self.m_iStartTime = mData["start_time"] or 0
    self.m_iEndTime = mData["end_time"] or 0
    self.m_bAllChannel = mData["all_channel"]
    self.m_lChannels = mData["channels"] or {}
    self.m_bPlatforms = mData["all_platform"]
    self.m_lPlatforms = mData["platforms"] or {}
    self.m_iMinGrade = mData["min_grade"] or 0
    self.m_iMaxGrade = mData["max_grade"] or 0
    self.m_iKeepTime = mData["keeptime"] or 0

    self.m_sTitle = mData["title"]
    self.m_sContext = mData["context"]
    self.m_lItem = mData["items"]
    self.m_lSummon = mData["summons"]
    self.m_iCreateTime = get_time()
    self.m_iStartCreateTime = mData["start_create_time"]
    self.m_iEndCreateTime = mData["end_create_time"]

    self:CheckValid()
end

function CMailCacheObj:CheckValid()
    local oItemLoader = global.oItemLoader
    for _, info in pairs(self.m_lItem) do
        local oItem = oItemLoader:GetItem(info.sid)
        assert(oItem, string.format("CMailCacheObj:CheckValid err:%s", info.sid))
    end
    
    local loadsummon = import(service_path("summon.loadsummon"))
    for _, info in pairs(self.m_lSummon) do
        local oSummon = loadsummon.GetSummon(info.sid)
        assert(oSummon, string.format("CMailCacheObj:CheckValid err:%s", info.sid)) 
    end
end

function CMailCacheObj:GetMailInfo()
    local mData = {}
    mData["createtime"] = get_time()
    mData["title"] = self.m_sTitle
    mData["context"] = self.m_sContext
    if self.m_iKeepTime and self.m_iKeepTime > 0 then
        mData["keeptime"] =  self.m_iKeepTime*24*3600
    else
        mData["keeptime"] = self.m_iEndTime - self.m_iStartTime    
    end
    mData["readtodel"] = 0
    mData["autoextract"] = 1
    mData["icon"] = "h7_mail_unopened"
    mData["openicon"] = "h7_mail_opened"
    return mData
end

function CMailCacheObj:Save()
    local mData = {}
    mData["start_time"] = self.m_iStartTime
    mData["end_time"] = self.m_iEndTime
    mData["all_channel"] = self.m_bAllChannel
    mData["channels"] = self.m_lChannels
    mData["all_platform"] = self.m_bPlatforms
    mData["platforms"] = self.m_lPlatforms
    mData["min_grade"] = self.m_iMinGrade
    mData["max_grade"] = self.m_iMaxGrade
    mData["keeptime"] = self.m_iKeepTime
    mData["title"] = self.m_sTitle
    mData["context"] = self.m_sContext
    mData["items"] = self.m_lItem
    mData["summons"] = self.m_lSummon
    mData["createtime"] = self.m_iCreateTime
    mData["start_create_time"] = self.m_iStartCreateTime
    mData["end_create_time"] = self.m_iEndCreateTime
    return mData
end

function CMailCacheObj:Load(mData)
    if not mData then return end
    self.m_iStartTime = mData["start_time"]
    self.m_iEndTime = mData["end_time"]
    self.m_bAllChannel = mData["all_channel"]
    self.m_lChannels = mData["channels"]
    self.m_bPlatforms = mData["all_platform"]
    self.m_lPlatforms = mData["platforms"]
    self.m_iMinGrade = mData["min_grade"]
    self.m_iMaxGrade = mData["max_grade"]
    self.m_iCreateTime = mData["createtime"] or get_time()
    self.m_iKeepTime = mData["keeptime"] or 0

    self.m_sTitle = mData["title"]
    self.m_sContext = mData["context"]
    self.m_lItem = mData["items"]
    self.m_lSummon = mData["summons"]
    self.m_iStartCreateTime = mData["start_create_time"]
    self.m_iEndCreateTime = mData["end_create_time"]
end

function CMailCacheObj:IsExpire()
    return self.m_iEndTime < get_time()
end

function CMailCacheObj:IsValid(oPlayer)
    if not oPlayer then return false end

    -- local iTime = 0
    -- if self.m_iCreateTime then
    --     iTime = self.m_iCreateTime
    -- end
    -- if oPlayer.m_iCreateTime > iTime then
    --     return false
    -- end
    local iRoleCreateTime = oPlayer.m_iCreateTime
    if self.m_iStartCreateTime and self.m_iStartCreateTime > iRoleCreateTime then
        return false
    end
    if self.m_iEndCreateTime and self.m_iEndCreateTime < iRoleCreateTime then
        return false
    end

    if not self.m_bAllChannel and type(self.m_lChannels) == "table" then
        if not table_in_list(self.m_lChannels, oPlayer:GetChannel()) then
            return false
        end
    end 

    if not self.m_bPlatforms and type(self.m_lPlatforms) == "table"  then
        if not table_in_list(self.m_lPlatforms, oPlayer:GetFakePlatform()) then
            return false
        end
    end 

    if self.m_iMinGrade > oPlayer:GetGrade() then
        return false
    end
    if self.m_iMaxGrade > 0 and self.m_iMaxGrade < oPlayer:GetGrade() then
        return false
    end
    return true
end

function CMailCacheObj:SendSysMail(iPid)
    local mItems = {}
    local mSummons = {}
    for _, info in ipairs(self.m_lItem) do
        local oItem = global.oItemLoader:ExtCreate(info.sid)
        if oItem:SID() < 10000 then
            oItem:SetData("Value", info.amount or 0)
        else
            oItem:SetAmount(info.amount or 0)
            if info.bind and info.bind > 0 then
                oItem:Bind(iPid)
            end
        end
        table.insert(mItems, oItem)
    end
    local loadsummon = import(service_path("summon.loadsummon"))
    for _, info in ipairs(self.m_lSummon) do
        local oSummon = loadsummon.CreateSummon(info.sid)
        table.insert(mSummons, oSummon)
    end

    local oMailMgr = global.oMailMgr
    oMailMgr:SendMail(0, "系统", iPid, self:GetMailInfo(), 0, mItems, mSummons)
end
