local global = require "global"

local datactrl = import(lualib_path("public.datactrl"))

SYS_SETTING = {
    MUSIC = 1,
    AUDIO = 2,
    VOICE = 3,
    PICTURE = 4,
}

MARKER_SETTING = {
    [0] = 50,   -- 默认
    [100] = 10, -- 最低画质
    [200] = 25, -- 中等
    [300] = 50, -- 最高
}

function NewSysConfigMgr(pid)
    return CSysConfigMgr:New(pid)
end

CSysConfigMgr = {}
CSysConfigMgr.__index = CSysConfigMgr
inherit(CSysConfigMgr, datactrl.CDataCtrl)

function CSysConfigMgr:New(pid)
    local o = super(CSysConfigMgr).New(self, {pid = pid})
    o.m_iOnOff = 0
    o.m_mValues = {}
    return o
end

function CSysConfigMgr:ChangeOnOff(iOnOff)
    self:Dirty()
    self.m_iOnOff = iOnOff
end

function CSysConfigMgr:ChangeValues(lValueInfos)
    self:Dirty()
    for _, mValueInfo in ipairs(lValueInfos) do
        self.m_mValues[mValueInfo.id] = mValueInfo.value
    end
end

function CSysConfigMgr:ChangeFriendValues(iOnOff)
    local iRefuseToggle = (iOnOff >> 6) & 0x01
    local iVerifyToggle = (iOnOff >> 7) & 0x01
    local iStrangerMsgToggle = (iOnOff >> 8) & 0x01
    
    local oPlayer = global.oWorldMgr:GetOnlinePlayerByPid(self:GetInfo("pid"))
    if oPlayer then
        local oFriend = oPlayer:GetFriend()
        oFriend:ChangeFriendSysConfig(iRefuseToggle, iVerifyToggle, iStrangerMsgToggle)
    end
end

function CSysConfigMgr:PackValuesInfo()
    local lInfos = {}
    for iId, iValue in pairs(self.m_mValues) do
        table.insert(lInfos, {id = iId, value = iValue})
    end
    return lInfos
end

function CSysConfigMgr:PackConfigNetData()
    local mNet = {
        on_off = self.m_iOnOff,
        values = self:PackValuesInfo(),
    }
    return mNet
end

function CSysConfigMgr:CallChangeConfig(iOnOff, lValueInfos)
    if iOnOff then
        self:ChangeOnOff(iOnOff)
        self:ChangeFriendValues(iOnOff)
    end
    if lValueInfos then
        local iOldPicture = self.m_mValues[SYS_SETTING.PICTURE]
        self:ChangeValues(lValueInfos)
        if iOldPicture ~= self.m_mValues[SYS_SETTING.PICTURE] then
            local oPlayer = global.oWorldMgr:GetOnlinePlayerByPid(self:GetInfo("pid"))
            if oPlayer then
                oPlayer:SyncSceneInfo({marker_limit=self:GetMarkerCountSetting()})
            end
        end
    end
end

function CSysConfigMgr:Save()
    return {
        on_off = self.m_iOnOff,
        values = table_to_db_key(self.m_mValues),
    }
end

function CSysConfigMgr:Load(mData)
    self.m_iOnOff = mData.on_off or 0
    self.m_mValues = table_to_int_key(mData.values or {})
end

function CSysConfigMgr:OnLogin(oPlayer, bReEnter)
    local mNet = self:PackConfigNetData()
    oPlayer:Send("GS2CSysConfig", mNet)
end

function CSysConfigMgr:GetMarkerCountSetting()
    return MARKER_SETTING[self.m_mValues[SYS_SETTING.PICTURE] or 0] or 60
end
