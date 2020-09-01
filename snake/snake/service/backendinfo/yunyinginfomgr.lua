local global = require "global"
local extend = require "base.extend"
local res = require "base.res"
local interactive = require "base.interactive"
local net = require "base.net"
local record = require "public.record"
local router = require "base.router"

local gamedefines = import(lualib_path("public.gamedefines"))
local gamedb = import(lualib_path("public.gamedb"))
local datactrl = import(lualib_path("public.datactrl"))
local serverinfo = import(lualib_path("public.serverinfo"))

function NewYunYingInfoMgr(...)
    return CYunYingInfoMgr:New(...)
end

CYunYingInfoMgr = {}
CYunYingInfoMgr.__index = CYunYingInfoMgr
CYunYingInfoMgr.m_sDbKey = "yunyingctrl"
inherit(CYunYingInfoMgr, datactrl.CDataCtrl)

function CYunYingInfoMgr:New()
    local o = super(CYunYingInfoMgr).New(self)
    return o
end

function CYunYingInfoMgr:SendInfoToGS(mSendData)
    local lServerKeyList = serverinfo.get_gs_key_list()
    for _, sServerKey in ipairs(lServerKeyList) do
        local sServerTag = get_server_tag(sServerKey)
        router.Request(sServerTag, ".world", "gmtools", "Forward", mSendData, function(mRecord, mData)
        end)
    end
end

function CYunYingInfoMgr:SetSysSwitchInfo(mData)
    mData = self:UnPackSysSwitchInfoFromBS(mData)
    for iChannel, mChannelInfo in pairs(mData) do
        if not self.m_mSysSwitch[iChannel] then
            self.m_mSysSwitch[iChannel] = {}
        end
        for iType, iState in pairs(mChannelInfo) do
            self.m_mSysSwitch[iChannel][iType] = iState
        end
    end
    self.m_mSwitchChange = mData
    self:SaveDb()
    local mSendData = {}
    mSendData.cmd = "SetSysSwitchInfo"
    mSendData.data = self:GetAllSysSwitchInfo()
    self:SendInfoToGS(mSendData)
end

function CYunYingInfoMgr:GetAllSysSwitchInfo()
    local mData = {}
    mData.switch = self.m_mSysSwitch
    mData.switch_change = self.m_mSwitchChange
    return mData
end

function CYunYingInfoMgr:UnPackSysSwitchInfoFromBS(mInfo)
    local mData = {}
    for sChannel, mChannel in pairs(mInfo) do
        local iChannel = tonumber(sChannel)
        mData[iChannel] = {}
        for sType, iState in pairs(mChannel) do
            mData[iChannel][tonumber(sType)] = iState
        end
    end
    return mData
end

function CYunYingInfoMgr:PackSysSwitchInfoToBS()
    local mData = {}
    for iChannel, mChannel in pairs(self.m_mSysSwitch) do
        local sChannel = tostring(iChannel)
        mData[sChannel] = {}
        for _, iType in pairs(gamedefines.CHANNEL_SYS_SWITCH) do
            mData[sChannel][tostring(iType)] = mChannel[iType] or 1
        end
    end
    return { ["sys_switch"]= mData}
end

function CYunYingInfoMgr:SetCustServInfo(mData)
    local iKey = mData.channel * 10 + mData.platform
    self.m_mCustServInfo[iKey] = mData.official_info
    if channel == 0 and platform == 0 then
        for iKey, mInfo in pairs(self.m_mCustServInfo) do
            mInfo = mData.official_info
        end
    elseif channel == 0 then
        for iKey, mInfo in pairs(self.m_mCustServInfo) do
            if iKey % 10 == mData.platform then
                mInfo = mData.official_info
            end
        end
    elseif platform == 0 then
        for iKey, mInfo in pairs(self.m_mCustServInfo) do
            if iKey // 10 == channel then
                mInfo = mData.official_info
            end
        end
    end
    self.m_mInfoChange = mData
    self:SaveDb()
    local mSendData = {}
    mSendData.cmd = "SetCustServInfo"
    mSendData.data = self:GetAllCustomerServiceInfo()
    self:SendInfoToGS(mSendData)
end

function CYunYingInfoMgr:GetAllCustomerServiceInfo()
    local mData = {}
    mData.info_change = self.m_mInfoChange
    mData.custserv_info = self.m_mCustServInfo
    return mData
end

function CYunYingInfoMgr:GetAllInfo()
    local mData = self:GetAllCustomerServiceInfo()
    table_combine(mData, self:GetAllSysSwitchInfo())
    return mData
end

function CYunYingInfoMgr:Save()
    local mData = {}
    mData.sysswitch = self.m_mSysSwitch
    mData.custservinfo = self.m_mCustServInfo
    return mData
end

function CYunYingInfoMgr:Load(mData)
    mData = mData or {}
    self.m_mSysSwitch = mData.sysswitch or {}
    self.m_mCustServInfo = mData.custservinfo or {}
end

function CYunYingInfoMgr:SaveDb()
    local mInfo = {
        module = "globaldb",
        cmd = "SaveGlobal",
        cond = {name = self.m_sDbKey},
        data = {data = self:Save()},
    }
    gamedb.SaveDb("yunyingctrl", "common", "DbOperate", mInfo)
end

function CYunYingInfoMgr:LoadDb()
    local mInfo = {
        module = "globaldb",
        cmd = "LoadGlobal",
        cond = {name = self.m_sDbKey},
    }
    gamedb.LoadDb("yunyingctrl", "common", "DbOperate", mInfo, 
        function(mRecord, mData)
            self:Load(mData.data)
        end)
end
