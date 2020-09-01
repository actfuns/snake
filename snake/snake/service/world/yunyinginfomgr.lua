local global = require "global"
local router = require "base.router"

function NewYunYingInfoMgr(...)
    return CYunYingInfoMgr:New(...)
end

-- 以渠道和服务器为单位
-- 客服反馈，客服公告的运营开关；客服公告的消息；运营精彩推荐的信息；
CYunYingInfoMgr = {}
CYunYingInfoMgr.__index = CYunYingInfoMgr
CYunYingInfoMgr.m_mTempName = "运营后台控制"
inherit(CYunYingInfoMgr, logic_base_cls())

function CYunYingInfoMgr:New()
    local o = super(CYunYingInfoMgr).New(self)
    o:Init()
    return o
end

function CYunYingInfoMgr:Init()
    self.m_mCustServInfo = {}
    self.m_mSysSwitch = {}
    self:GetInfoFromCS()
end

function CYunYingInfoMgr:GetInfoFromCS()
    router.Request("cs", ".backendinfo", "common", "GetYunYingChannelAllInfo", nil , function(mRecord, mData)
        self:_InitInfo(mData.data)
    end)
end

function CYunYingInfoMgr:_InitInfo(mInfo)
    self.m_mSysSwitch = mInfo.switch or self.m_mSysSwitch
    self.m_mCustServInfo = mInfo.custserv_info or self.m_mCustServInfo
end

function CYunYingInfoMgr:GetSysSwitchInfo(oPlayer)
    return self.m_mSysSwitch[oPlayer:GetChannel()]
end

function CYunYingInfoMgr:GS2CSysSwitchInfo(oPlayer)
    local iChannel = oPlayer:GetChannel()
    local mAllSysSwitch = self:GetSysSwitchInfo(oPlayer)
    if not mAllSysSwitch then return end
    local mNet = {}
    mNet.syslist = {}
    for iType, iState in pairs(mAllSysSwitch) do
        table.insert(mNet.syslist, {systype = iType, channel = iChannel, state = iState})
    end
    oPlayer:Send("GS2CSysSwitch", mNet)
end

function CYunYingInfoMgr:SetSysSwitchInfo(mInfo)
    self:_InitInfo(mInfo)
    local mLastChange = mInfo.switch_change
    local mNet = {}
    mNet.syslist = {}
    for iChannel, mChannelChange in pairs(mLastChange) do
        for iType, iState in pairs(mChannelChange) do
            table.insert(mNet.syslist, {systype = iType, channel = iChannel, state = iState })
        end
    end
    global.oNotifyMgr:WorldBroadcast("GS2CSysSwitch", mNet)
end

function CYunYingInfoMgr:SetCustServInfo(mInfo)
    self:_InitInfo(mInfo)
    local mLastChange = mInfo.info_change
    local mNet = {}
    mNet.channel = mLastChange.channel
    mNet.platform = mLastChange.platform
    mNet.official_info = mLastChange.official_info
    global.oNotifyMgr:WorldBroadcast("GS2CCustServInfo", mNet)
end

function CYunYingInfoMgr:GetCustServInfo(oPlayer)
    local iChannel = oPlayer:GetChannel()
    local iPlatform = oPlayer:GetPlatform()
    return self.m_mCustServInfo[iChannel * 10 + iPlatform] or self.m_mCustServInfo[iChannel * 10] or 
               self.m_mCustServInfo[iPlatform] or self.m_mCustServInfo[0]
end

function CYunYingInfoMgr:GS2CCustServInfo(oPlayer)
    if not global.oToolMgr:IsSysOpen("FEEDBACKINFO", nil, true) then return end
    local mInfo = self:GetCustServInfo(oPlayer)
    local mNet = {
        channel = oPlayer:GetChannel(),
        platform = oPlayer:GetPlatform(),
        official_info = mInfo,
    }
    if mInfo then
        oPlayer:Send("GS2CCustServInfo", mNet)
    end
end

function CYunYingInfoMgr:OnLogin(oPlayer, bReEnter)
    self:GS2CSysSwitchInfo(oPlayer)
    self:GS2CCustServInfo(oPlayer)
end
