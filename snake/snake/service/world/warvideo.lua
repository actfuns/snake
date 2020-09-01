--战斗录像
local global = require "global"
local extend = require "base.extend"
local res = require "base.res"
local interactive = require "base.interactive"

local gamedefines = import(lualib_path("public.gamedefines"))
local datactrl = import(lualib_path("public.datactrl"))
local gamedb = import(lualib_path("public.gamedb"))

function NewWarVideoMgr(...)
    return CWarVideoMgr:New(...)
end

CWarVideoMgr = {}
CWarVideoMgr.__index = CWarVideoMgr
inherit(CWarVideoMgr,logic_base_cls())

function CWarVideoMgr:New()
    local o = super(CWarVideoMgr).New(self)
    o.m_mList = {}
    o:Schedule()
    return o
end

function CWarVideoMgr:Schedule()
    local f2
    f2 = function ()
        self:DelTimeCb("_CheckClean")
        self:AddTimeCb("_CheckClean",5 * 60 * 1000,f2)
        self:_CheckClean()
    end
    f2()
end

function CWarVideoMgr:_CheckClean()
    local mClean = {}
    for iVideoId,oVideo in pairs(self.m_mList) do
        if not oVideo:IsActive() then
            mClean[iVideoId] = true
        end
    end
    for iVideoId,_ in pairs(mClean) do
        self:RemoveVideo(iVideoId)
    end
end

function CWarVideoMgr:OnCloseGS()
    for _,oVideo in pairs(self.m_mList) do
        if oVideo:IsDirty() then
            oVideo:SaveDb()
        end
    end
end

function CWarVideoMgr:NewWarVideo(iVideoId)
    local oVideo = CVideo:New(iVideoId)
    self.m_mList[iVideoId] = oVideo
    return oVideo
end

function CWarVideoMgr:AddWarVideo(mVideoData, func)
    router.Request("cs", ".idsupply", "common", "GenWarVideoId", {}, function (mRecord, mData)
        local iVideoId = mData.id
        if not iVideoId then
            record.error("create warvideo error GenWarVideoId nil")
            return
        end
        self:_AddWarVideo2(mVideoData, func, iVideoId)
    end)
end

function CWarVideoMgr:_AddWarVideo2(mVideoData, func, iVideoId)
    local oWorldMgr = global.oWorldMgr
    local oVideo = CVideo:New(iVideoId,mVideoData)
    oVideo:OnLoaded()
    oVideo:Dirty()
    oVideo:SaveDb()
    self.m_mList[iVideoId] = oVideo
    func(oVideo)
end

function CWarVideoMgr:GetVideo(iVideoId)
    return self.m_mList[iVideoId]
end

function CWarVideoMgr:RemoveVideo(iVideoId)
    local oVideo = self.m_mList[iVideoId]
    self.m_mList[iVideoId] = nil
    if oVideo then
        baseobj_delay_release(oVideo)
    end
end

function CWarVideoMgr:TryStartVideo(iPid, oVideo, iCamp)
    local oWorldMgr = global.oWorldMgr
    local oPlayer = oWorldMgr:GetOnlinePlayerByPid(iPid)
    if not oPlayer then
        return
    end
    if not oVideo then
        return
    end
    oVideo:StartVideo(oPlayer, iCamp)
end

function CWarVideoMgr:StartVideo(oPlayer,iVideoId, iCamp)
    local iPid = oPlayer:GetPid()
    if oPlayer.m_oActiveCtrl:GetNowWar() then
        return
    end
    local oVideo = self.m_mList[iVideoId]
    if not oVideo then
        self:LoadVideo(iVideoId, function(oVideo)
            self:TryStartVideo(iPid, oVideo, iCamp)
        end)
    else
        oVideo:StartVideo(oPlayer, iCamp)
    end
end

function CWarVideoMgr:LoadVideo(iVideoId,fCallback)
    local o = self:GetVideo(iVideoId)
    if o then
        o:WaitLoaded(fCallback)
    else
        o = self:NewWarVideo(iVideoId)
        o:WaitLoaded(fCallback)
        local mInfo = {
            module = "warvideodb",
            cmd = "LoadWarVideo",
            cond = {video_id=iVideoId},
        }
        gamedb.LoadDb(iVideoId, "common", "DbOperate", mInfo, function (mRecord,mData)
            local o = self:GetVideo(iVideoId)
            assert(o and not o:IsLoaded(), string.format("LoadWarVideo fail %s",iVideoId))
            if not mData.success then
                o:OnLoadedFail()
                self:RemoveVideo(iVideoId)
            else
                local m = mData.data
                o:Load(m)
                o:OnLoaded()
            end
        end)
    end
end

CVideo = {}
CVideo.__index = CVideo
inherit(CVideo,datactrl.CDataCtrl)

function CVideo:New(iWarVideoId,mVideoData)
    local o = super(CVideo).New(self)
    o.m_iLastTime = get_time()
    o.m_iVideoID = iWarVideoId
    o.m_mData = mVideoData
    o.m_mObservers = {}
    return o
end

function CVideo:Save()
    local mData = {}
    mData.video_id = self.m_iVideoID or 1
    mData.video_data = table_deep_copy(self.m_mData) or {}
    return mData
end

function CVideo:Load(mData)
    mData = mData or {}
    self.m_iVideoID = mData.video_id
    self.m_mData = mData.video_data
end

function CVideo:SaveDb()
    local mInfo = {
        module = "warvideodb",
        cmd = "SaveWarVideo",
        cond = {video_id = self:GetVideoId()},
        data = {data = self:Save()},
    }
    gamedb.SaveDb(self:GetVideoId(), "common", "DbOperate", mInfo)
    self:UnDirty()
end

function CVideo:LoadedExec()
    super(CVideo).LoadedExec(self)
    self:SetLastTime()
end

function CVideo:WaitLoaded(func)
    super(CVideo).WaitLoaded(self, func)
    if self:IsLoaded() then
        self:SetLastTime()
    end
end

function CVideo:SetLastTime()
    self.m_iLastTime = get_time()
end

function CVideo:GetLastTime()
    return self.m_iLastTime
end

function CVideo:IsActive()
    local iNowTime = get_time()
    if iNowTime - self:GetLastTime() <= 5 * 60 then
        return true
    end
    if #self.m_mObservers > 0 then
        return true
    end
    return false
end

function CVideo:GetVideoId()
    return self.m_iVideoID
end

function CVideo:GetWarType()
    return (self.m_mData and self.m_mData.type) or 0
end

function CVideo:AddObserver(iPid,iWarId)
    self.m_mObservers[iPid] = iWarId
end

function CVideo:RemoveObserver(iPid)
    self.m_mObservers[iPid] = nil
end

function CVideo:StartVideo(oPlayer, iCamp)
    if oPlayer.m_oActiveCtrl:GetNowWar() then
        return
    end
    local oWarMgr = global.oWarMgr
    local iPid = oPlayer:GetPid()
    local mArgs = {
        video_data = self.m_mData,
    }
    local oWar = oWarMgr:CreateWar(
        gamedefines.WAR_TYPE.WAR_VIDEO_TYPE, 
        gamedefines.GAME_SYS_TYPE.SYS_TYPE_NONE, mArgs)
    local iWarId = oWar:GetWarId()

    local mArgs = {
--        observer_video = 1,
--        war_video = 1,
        camp_id = iCamp,
        war_id = iWarId,
    }

    if oPlayer:IsSingle() then
        oWarMgr:ObserverEnterWar(oPlayer, iWarId, mArgs)
    elseif oPlayer:IsTeamLeader() then
        oWarMgr:TeamObserverEnterWar(oPlayer, iWarId, mArgs)
    else
        return
    end

    local fWarEndCallback = function (mArgs)
        self:WarEndCallback(iWarId,iPid,mArgs)
    end
    oWarMgr:SetCallback(iWarId,fWarEndCallback)
    oWarMgr:StartWar(iWarId)

    self:AddObserver(iPid,iWarId)
end

function CVideo:WarEndCallback(iWar,iPid,mArgs)
    self:RemoveObserver(iPid)
end
