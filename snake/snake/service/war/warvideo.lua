--import module

local interactive = require "base.interactive"

local gamedefines = import(lualib_path("public.gamedefines"))
local basewar = import(service_path("warobj"))

CWarVideo = {}
CWarVideo.__index = CWarVideo
inherit(CWarVideo, basewar.CWar)

function NewWar(...)
    local o = CWarVideo:New(...)
    return o
end

function CWarVideo:New(id)
    local o = super(CWarVideo).New(self,id)
    o.m_mBoutCmd = {}
    o.m_mClientPacket = {}
    o.m_mBoutCmd = {}
    o.m_iBoutEnd = 0
    return o
end

function CWarVideo:Init(iWarType, mData)
    self.m_iWarType = iWarType
    mData = mData or {}
    local mVideo = mData.video_data or {}
    self.m_mBoutCmd = mVideo.bout_cmd or self.m_mBoutCmd
    self.m_mClientPacket = mVideo.client_packet or self.m_mClientPacket
    self.m_mBoutTime = mVideo.bout_time or self.m_mBoutTime
    self.m_iBoutEnd = mVideo.bout_end or self.m_iBoutEnd
    self.m_iBout = 0
end

function CWarVideo:IsBoutEnd()
    if self.m_iBout < self.m_iBoutEnd then
        return false
    end
    return true
end

function CWarVideo:GetBoutStartTime(iBout)
    iBout = iBout or self.m_iBout
    iBout = tostring(iBout)
    return self.m_mBoutTime[iBout] or 0
end

function CWarVideo:GetBoutClientPacketData(iBout)
    iBout = iBout or self.m_iBout
    iBout = tostring(iBout)
    return self.m_mClientPacket[iBout] or {}
end

function CWarVideo:GetBoutCmd(iBout)
    iBout = tostring(iBout)
    local mBoutCmd = self.m_mBoutCmd[iBout] or {}
    return mBoutCmd
end

function CWarVideo:WarStart()
    local mClientPacketData = self:GetBoutClientPacketData(self.m_iBout)
    self:BoutPlay(mClientPacketData)
end

--按记录时间播放一回合数据,暂时这样处理
function CWarVideo:BoutPlay(mClientPacketData)
    local iVideo = self:GetWarId()
    self:DelTimeCb("BoutPlay")
    mClientPacketData = mClientPacketData or {}
    local iMaxSecs = 0
    for iSecs,mClientPacket in pairs(mClientPacketData) do
        iSecs = tonumber(iSecs)
        if iMaxSecs < iSecs then
            iMaxSecs = iSecs
        end
        if iSecs <= 0 then
            self:TrueBoutPlay(mClientPacket,iSecs)
        else
            local sKey = string.format("TrueBoutPlay%s",iSecs)
            self:AddTimeCb(sKey,iSecs*1000,function ( ... )
                local oVideo = global.oWarMgr:GetWar(iVideo)
                if oVideo then
                    oVideo:TrueBoutPlay(mClientPacket,iSecs)
                end
            end)
        end
    end
    if self:IsBoutEnd() then
        return
    end
    local iTime = self:GetBoutStartTime()
    if iTime <= 0 then
        self:BoutStart()
    else
        self:AddTimeCb("BoutStart",iTime,function ()
            local oVideo = global.oWarMgr:GetWar(iVideo)
            if oVideo then
                oVideo:BoutStart()
            end
        end)
    end
end

function CWarVideo:TrueBoutPlay(mClientPacket,iSecs)
    local sKey = string.format("TrueBoutPlay%s",iSecs)
    self:DelTimeCb(sKey)
    if #mClientPacket <= 0 then
        return
    end
    for _,mPacketInfo in ipairs(mClientPacket) do
        local sMessage,mData = table.unpack(mPacketInfo)
        for _,o in pairs(self.m_mObservers) do
            o:Send(sMessage,mData)
        end
    end
end

function CWarVideo:BoutProcess()
    self:DelTimeCb("BoutStart")
    self:DelTimeCb("BoutProcess")

    local iVideo = self:GetWarId()
    local mClientPacketData = self:GetBoutClientPacketData(self.m_iBout)
    local iSecs = 0
    self:BoutPlay(mClientPacketData,iSecs)
    local iTime = self:GetBoutStartTime()
    if self:IsBoutEnd() then
        self:AddTimeCb("WarEnd",iTime,function ()
            local oVideo = global.oWarMgr:GetWar(iVideo)
            if oVideo then
                oVideo:WarEnd()
            end
        end)
    end
end

function CWarVideo:BoutStart()
    self:DelTimeCb("BoutPlay")
    self:DelTimeCb("BoutStart")
    self.m_iBout = self.m_iBout + 1
    
    self:PlayBoutCmd()
end

--玩家操作过程
function CWarVideo:PlayBoutCmd()
    local iBout = self.m_iBout
    local mBoutCmd = self:GetBoutCmd(iBout)
    local iMaxSecs = 0
    local iVideo = self:GetWarId()
    for iSecs,mClientPacket in pairs(mBoutCmd) do
        iSecs = tonumber(iSecs)
        if iMaxSecs <= iSecs then
            iMaxSecs = iSecs
        end
        local sKey = string.format("PlayBoutCmd%s",iSecs)
        self:AddTimeCb(sKey,iSecs * 1000,function ()
            local oVideo = global.oWarMgr:GetWar(iVideo)
            if oVideo then
                oVideo:TruePlayBoutCmd(mClientPacket,iSecs)
            end
        end)
    end
    if iMaxSecs <= 0 then
        self:BoutProcess()
    else
        self:AddTimeCb("BoutProcess",iMaxSecs * 1000,function ()
            local oVideo = global.oWarMgr:GetWar(iVideo)
            if oVideo then
                oVideo:BoutProcess()
            end
        end)
    end
end

function CWarVideo:TruePlayBoutCmd(mClientPacket,iSecs)
    local sKey = string.format("PlayBoutCmd%s",iSecs)
    self:DelTimeCb(sKey)
    for _,mPacketInfo in pairs(mClientPacket) do
        local sMessage,mData = table.unpack(mPacketInfo)
        for iPid, o in pairs(self.m_mObservers) do
            o:Send(sMessage,mData)
        end
    end
end

function CWarVideo:WarEnd()
    self:DelTimeCb("WarEnd")
    local l = table_key_list(self.m_mObservers)
    for _, iPid in ipairs(l) do
        self:LeaveObserver(iPid)
    end
    local mArgs = {
    }

    interactive.Send(".world", "war", "RemoteEvent", {event = "remote_end_warvideo", data = {
        war_id = self:GetWarId(),
        war_info = mArgs,
    }})
end
