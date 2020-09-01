--import module
local global = require "global"
local skynet = require "skynet"
local interactive = require "base.interactive"
local record = require "public.record"
local cjson = require "cjson"
local res = require "base.res"
local router = require "base.router"
local playersend = require "base.playersend"

local serverinfo = import(lualib_path("public.serverinfo"))
local datactrl = import(lualib_path("public.datactrl"))
local defines = import(service_path("defines"))
local gamedb = import(lualib_path("public.gamedb"))
local gamedefines = import(lualib_path("public.gamedefines"))


function NewChatMgr(...)
    local o = CChatMgr:New(...)
    return o
end

CChatMgr = {}
CChatMgr.__index = CChatMgr
inherit(CChatMgr, datactrl.CDataCtrl)
CChatMgr.m_sTableName = "chatinfo"

function CChatMgr:New()
    local o = super(CChatMgr).New(self)
    o:Init()
    return o
end

function CChatMgr:Init()
    self.m_mForbidInfo = {}             -- {id:forbidinfo}
    self.m_mPlayerInfo = {}             -- {pid:{infoid:times}}
end

function CChatMgr:ConfigSaveFunc()
    if is_ks_server() then return end

    self:ApplySave(function ()
        local oChatMgr = global.oChatMgr
        oChatMgr:_CheckSaveDb()
    end)
end

function CChatMgr:_CheckSaveDb()
    assert(not is_release(self), "_CheckSaveDb fail")
    assert(self:IsLoaded(), ".chat CChatMgr save fail: is loading")
    if not self:IsDirty() then return end
    
    self:SaveDb()
end

function CChatMgr:SaveDb()
    if is_ks_server() then return end

    local mInfo = {
        module = "globaldb",
        cmd = "SaveGlobal",
        cond = {name = self.m_sTableName},
        data = {data = self:Save()},
    }
    gamedb.SaveDb("chat", "common", "DbOperate", mInfo)
    self:UnDirty()
end

function CChatMgr:LoadDb()
    if is_ks_server() then 
        self:InitForbinInfo()
        return 
    end

    local mInfo = {
        module = "globaldb",
        cmd = "LoadGlobal",
        cond = {name = self.m_sTableName},
    }
    gamedb.LoadDb("chat", "common", "DbOperate", mInfo,
    function(mRecord, mData)
        self:Load(mData.data)
        self:OnLoaded()
        self:InitForbinInfo()
    end)
end

function CChatMgr:Load(mData)
    if not mData then return end

    self.m_mPlayerInfo = mData.playerforbin
end

function CChatMgr:Save()
    local mData = {}
    mData.playerforbin = self.m_mPlayerInfo
    return mData
end

function CChatMgr:InitForbinInfo()
    router.Request("cs", ".backendinfo", "common", "GetForbinInfo", {}, function (mRecord, mData)
        self:_InitForbinInfo(mData.data)
    end)
end

function CChatMgr:_InitForbinInfo(mData)
    for _, m in pairs(mData) do
        self:UpdateForbinInfo(m, true)
    end
end

function CChatMgr:UpdateForbinInfo(mInfo, bInit)
    local iForbin = mInfo.id
    if not iForbin then return end

    local oForbin = self.m_mForbidInfo[iForbin]
    if oForbin then
        oForbin:Init(mInfo)
    else
        oForbin = NewForbinInfo(mInfo)
        self.m_mForbidInfo[iForbin] = oForbin
    end
    if not bInit then
        self:BroadCast("GS2CAddForbinInfo", {forbids={oForbin:PackNetInfo()}})
    end
end

function CChatMgr:RemoveForbinInfo(id)
    local oForbin = self.m_mForbidInfo[id]
    if oForbin then
        oForbin:Release()
        self.m_mForbidInfo[id] = nil
        self:BroadCast("GS2CRemoveForbinInfo", {forbids={id}})
    end
end

function CChatMgr:CheckForbinWord(sMsg)
    for iForbin, oForbin in pairs(self.m_mForbidInfo) do
        if not oForbin:IsForbin() then
            goto continue
        end
        for _,sWord in pairs(oForbin:GetWordList()) do
            if string.match(sMsg, sWord) then
                return iForbin
            end
        end
        ::continue::
    end
    return nil
end

function CChatMgr:AddForbinCount(iPid, iForbin, iCnt)
    local mForbin = self.m_mPlayerInfo[iPid]
    if not mForbin then
        mForbin = {}
        self.m_mPlayerInfo[iPid] = mForbin        
    end
    mForbin[iForbin] = (mForbin[iForbin] or 0) + iCnt
    self:Dirty()
end

function CChatMgr:GetForbinCount(iPid, iForbin)
    local mForbin = self.m_mPlayerInfo[iPid]
    if not mForbin then return 0 end

    return mForbin[iForbin] or 0
end

function CChatMgr:ClearForbinCount(iPid, iForbin)
    local mForbin = self.m_mPlayerInfo[iPid]
    if not mForbin then return end

    mForbin[iForbin] = nil
    self:Dirty()
end

function CChatMgr:CheckChatMsg(iPid, iChannel, sMsg, iForbin)
    return self:HandleChatForbin_new(iPid, iChannel, sMsg, iForbin)
end

function CChatMgr:HandleChatMsg(iPid, iChannel, sMsg)
    self:HandleChatForbin(iPid, iChannel, sMsg)
end

function CChatMgr:HandleChatForbin(iPid, iChannel, sMsg)
    if not sMsg or #sMsg <= 0 then return end

    local iForbin = self:CheckForbinWord(sMsg)
    if not iForbin then return end

    local oForbin = self.m_mForbidInfo[iForbin]
    if not oForbin then return end

    self:AddForbinCount(iPid, iForbin, 1)
    local iCnt = self:GetForbinCount(iPid, iForbin)
    if oForbin:GetLimitCount() > iCnt then return end

    local iPunishType = oForbin:GetPunishType()
    local iPunishTime = oForbin:GetPunishTime() * 3600
    self:PunishPlayer(iPid, iPunishType, iPunishTime, iForbin, sMsg)    
    self:ClearForbinCount(iPid, iForbin)
    return true
end

function CChatMgr:HandleChatForbin_new(iPid, iChannel, sMsg, iForbin)
    if not sMsg or #sMsg <= 0 then return end
    if not iForbin or iForbin <= 0 then return end

    local oForbin = self.m_mForbidInfo[iForbin]
    if not oForbin or not oForbin:IsForbin() then return end

    self:AddForbinCount(iPid, iForbin, 1)
    local iCnt = self:GetForbinCount(iPid, iForbin)
    if oForbin:GetLimitCount() > iCnt then return end

    local iPunishType = oForbin:GetPunishType()
    local iPunishTime = oForbin:GetPunishTime() * 3600
    self:PunishPlayer(iPid, iPunishType, iPunishTime, iForbin, sMsg)    
    self:ClearForbinCount(iPid, iForbin)
    return true
end

function CChatMgr:PunishPlayer(iPid, iType, iTime, iForbin, sMsg)
    if iType == defines.BAN_CHAT then
        interactive.Send(".world", "chat", "BanChatPlayer", {
            pid = iPid, 
            time = iTime, 
            forbin = iForbin,
            msg = sMsg
        })
    else
        record.warning(".chat CChatMgr:PunishPlayer not find type %s", iType)
    end
end

function CChatMgr:CloseGS()
    self:SaveDb()
end

function CChatMgr:MergeFrom(mFromData)
    if not mFromData then
        return false ,"chatinfo no merge_from_data"
    end
    self:Dirty()
    table_combine(self.m_mPlayerInfo, mFromData.playerforbin)
    return true
end

function CChatMgr:OnLogin(iPid, bReEnter)
    local lNetInfo = {}
    for _,oForbin in pairs(self.m_mForbidInfo) do
        table.insert(lNetInfo, oForbin:PackNetInfo())
    end
    playersend.Send(iPid, "GS2CAllForbinInfo", {forbids=lNetInfo})
end

function CChatMgr:BroadCast(sMessage, mNet)
    local mData = {
        message = sMessage,
        id = 1,
        type = gamedefines.BROADCAST_TYPE.WORLD_TYPE,
        data = mNet,
        exclude = {},
    }
    interactive.Send(".broadcast", "channel", "SendChannel", mData)
end

-------------------违禁处罚信息-------------------------
function NewForbinInfo(...)
    local o = CForbinInfo:New(...)
    return o
end


CForbinInfo = {}
CForbinInfo.__index = CForbinInfo

function CForbinInfo:New(mInfo)
    local o = setmetatable({}, self)
    o:Init(mInfo)
    return o
end

function CForbinInfo:Init(mInfo)
    self.m_ID = mInfo.id
    self.m_sWords = mInfo.words
    self.m_lWord = split_string(self.m_sWords, "|")
    self.m_iStatus = mInfo.status or 0
    self.m_iPunishType = mInfo.punishtype
    self.m_iPunishTime = mInfo.punishtime
    self.m_iLimit = mInfo.limit or 20
end

function CForbinInfo:Release()
    release(self)
end

function CForbinInfo:ID()
    return self.m_ID
end

function CForbinInfo:GetWordList()
    return self.m_lWord or {}
end

function CForbinInfo:GetLimitCount()
    return self.m_iLimit
end

function CForbinInfo:IsForbin()
    if self.m_iStatus > 0 then return true end

    return false
end

function CForbinInfo:GetPunishType()
    return self.m_iPunishType
end

function CForbinInfo:GetPunishTime()
    return self.m_iPunishTime
end

function CForbinInfo:PackNetInfo()
    return {
        id = self.m_ID,
        words = self.m_sWords,
    }
end







