
local global = require "global"
local skynet = require "skynet"
local interactive = require "base.interactive"
local net = require "base.net"
local playersend = require "base.playersend"
local geometry = require "base.geometry"
local record = require "public.record"
local extend = require "base.extend"

local shareobj = import(lualib_path("base.shareobj"))
local gamedefines = import(lualib_path("public.gamedefines"))
local CEntity = import(service_path("entityobj")).CEntity

local tinsert = table.insert


function NewPlayerEntity(...)
    return CPlayerEntity:New(...)
end


BlockHelperFunc = {}

function BlockHelperFunc.name(oEntity)
    return oEntity:GetName()
end

function BlockHelperFunc.model_info(oEntity)
    return oEntity:GetModelInfo()
end

function BlockHelperFunc.icon(oEntity)
    return oEntity:GetIcon()
end

function BlockHelperFunc.war_tag(oEntity)
    return oEntity:GetWarTag()
end

function BlockHelperFunc.followers(oEntity)
    return oEntity:GetFollowersInfo()
end

function BlockHelperFunc.title_info(oEntity)
    return oEntity:GetTitleInfo()
end

function BlockHelperFunc.show_id(oEntity)
    return oEntity:GetShowId()
end

function BlockHelperFunc.dance_tag(oEntity)
    return oEntity:InDance()
end

function BlockHelperFunc.touxian_tag(oEntity)
    return oEntity:GetTouxian()
end

function BlockHelperFunc.action(oEntity)
    return oEntity:GetActionInfo()
end

function BlockHelperFunc.org_id(oEntity)
    return oEntity:GetOrgId()
end

function BlockHelperFunc.fly_height(oEntity)
    return oEntity:GetFlyHeight()
end

function BlockHelperFunc.state(oEntity)
    return oEntity:GetState()
end

function BlockHelperFunc.engage_pid(oEntity)
    return oEntity:GetEngagePid()
end

function BlockHelperFunc.treasureconvoy_tag(oEntity)
    return oEntity:GetTreasureConvoyTag()
end

CPlayerEntity = {}
CPlayerEntity.__index = CPlayerEntity
inherit(CPlayerEntity, CEntity)

function CPlayerEntity:New(iEid, iPid)
    local o = super(CPlayerEntity).New(self, iEid)
    o.m_iType = gamedefines.SCENE_ENTITY_TYPE.PLAYER_TYPE
    o.m_iPid = iPid
    o.m_mPosQueue = {}
    o.m_oPlayerShareObj = CScenePlayerShareObj:New()
    o.m_oPlayerShareObj:Init()

    o.m_mAoiAction = {}
    o.m_mTeamAoiAction = {}
    o.m_bCollectAoiAction = false

    o.m_mCachePosQueue = nil
    o.m_bCachePosQueue = false

    return o
end

function CPlayerEntity:Release()
    baseobj_safe_release(self.m_oPlayerShareObj)
    super(CPlayerEntity).Release(self)
end

function CPlayerEntity:SetAoiAction(iClass, iOther, iType)
    local mELEvent
    if iClass == 0 then
        mELEvent = self.m_mAoiAction
    elseif iClass == 1 then
        mELEvent = self.m_mTeamAoiAction
    else
        assert(false, string.format("CPlayerEntity SetAoiAction failed %s", iClass))
    end

    local l = mELEvent[iOther]
    if not l then
        l = {}
        mELEvent[iOther] = l
    end
    local iLen = #l
    if l[iLen]~=iType then
        l[iLen+1]=iType
    end

    if not self.m_bCollectAoiAction then
        self.m_bCollectAoiAction = true
        local iSceneId = self:GetSceneId()
        local iEid = self:GetEid()
        self:AddTimeCb("PopAoiAction", 200, function ()
            local oSceneMgr = global.oSceneMgr
            local oScene = oSceneMgr:GetScene(iSceneId)
            if oScene then
                local oEntity = oScene:GetEntity(iEid)
                if oEntity then
                    oEntity.m_bCollectAoiAction = false
                    oEntity:HandleAoiAction(1)
                    oEntity:HandleAoiAction(0)
                    oEntity:ClrAoiAction()
                end
            end
        end)
    end
end

function CPlayerEntity:ClrAoiAction()
    for k, _ in pairs(self.m_mAoiAction) do
        self.m_mAoiAction[k] = nil
    end
    for k, _ in pairs(self.m_mTeamAoiAction) do
        self.m_mTeamAoiAction[k] = nil
    end
end

function CPlayerEntity:HandleAoiAction(iClass)
    local mELEvent
    if iClass == 0 then
        mELEvent = self.m_mAoiAction
    elseif iClass == 1 then
        mELEvent = self.m_mTeamAoiAction
    else
        assert(false, string.format("CPlayerEntity HandleAoiAction failed %s", iClass))
    end

    if next(mELEvent) then
        for k, v in pairs(mELEvent) do
            local ii = 0
            for _, i in ipairs(v) do
                ii = ii + i
            end
            if ii == 1 then
                self:OnClientEnter(iClass, k)
            elseif ii == -1 then
                self:OnClientLeave(iClass, k)
            end
        end
    end
end

function CPlayerEntity:GetPid()
    return self.m_iPid
end

function CPlayerEntity:GetShowId()
    return self:GetData("show_id")
end

function CPlayerEntity:GetFollowersInfo()
    return self:GetData("followers")
end

function CPlayerEntity:GetTitleInfo()
    return self:GetData("title_info")
end

function CPlayerEntity:GetTouxian()
    return self:GetData("touxian_tag")
end

function CPlayerEntity:GetOrgId()
    return self:GetData("org_id")
end

function CPlayerEntity:GetState()
    return self:GetData("state")
end

function CPlayerEntity:GetFlyHeight()
    return self:GetData("fly_height")
end

function CPlayerEntity:GetEngagePid()
    return self:GetData("engage_pid")
end

function CPlayerEntity:GetTreasureConvoyTag()
    return self:GetData("treasureconvoy_tag")
end

function CPlayerEntity:IsLeader()
    local oScene = self:GetScene()
    local oTeamEntity = oScene:GetTeamByPid(self:GetPid())
    if oTeamEntity then
        return oTeamEntity:IsLeader(self:GetPid())
    end
    return false
end

function CPlayerEntity:GetTeam()
    local oScene = self:GetScene()
    return oScene:GetTeamByPid(self:GetPid())
end

function CPlayerEntity:GetTeamInfo()
    local oScene = self:GetScene()
    local oTeamEntity = oScene:GetTeamByPid(self:GetPid())
    if oTeamEntity then
        return {
            data = oTeamEntity:GetTeamSortMember(),
            team_id = oTeamEntity:GetTeamId(),
        }
    end
end

function CPlayerEntity:Send(sMessage, mData)
    if self:InWar() then
        return
    end
    playersend.Send(self:GetPid(), sMessage, mData)
end

function CPlayerEntity:Disconnected()
end

function CPlayerEntity:EnterWar()
    self:DelTimeCb("__SyncPosQueue")
    self:SetData("war_tag",1)
    self:BlockChange("war_tag")
end

function CPlayerEntity:LeaveWar()
    self:SetData("war_tag",0)
    self:BlockChange("war_tag")
end

function CPlayerEntity:SendRaw(sData)
    if self:InWar() then
        return
    end
    playersend.SendRaw(self:GetPid(),sData)
end

function CPlayerEntity:ReEnter()
    local oScene = self:GetScene()
    local mPos = self:GetPos()
    self:Send("GS2CEnterScene", {
        scene_id = self:GetSceneId(),
        eid = self:GetEid(),
        pos_info = {
            v = geometry.Cover(self:GetSpeed()),
            x = geometry.Cover(mPos.x),
            y = geometry.Cover(mPos.y),
            face_x = geometry.Cover(mPos.face_x),
            face_y = geometry.Cover(mPos.face_y),
        }
    })

    local oScene = self:GetScene()
    local iPid = self:GetPid()
    local oTeam = oScene:GetTeamByPid(iPid)
    if oTeam and oTeam:IsLeader(iPid) then
        self:SendAoi("GS2CSceneCreateTeam", {
            scene_id = oTeam:GetSceneId(),
            team_id = oTeam:GetTeamId(),
            pid_list = oTeam:GetTeamSortMember(),
        },true)
    end

    for _, k in ipairs(self:GetView()) do
        local o = self:GetEntity(k)
        if o then
            self:EnterAoi(o)
        end
    end
end

function CPlayerEntity:GetAoiInfo()
    local mPos = self:GetPos()
    local m = {
        pid = self:GetPid(),
        pos_info = {
            v = geometry.Cover(self:GetSpeed()),
            x = geometry.Cover(mPos.x),
            y = geometry.Cover(mPos.y),
            face_x = geometry.Cover(mPos.face_x),
            face_y = geometry.Cover(mPos.face_y),
        },
        block = self:BlockInfo(),
    }
    return m
end

function CPlayerEntity:BlockInfo(m)
    local mRet = {}
    if not m then
        m = BlockHelperFunc
    end
    for k, _ in pairs(m) do
        local f = assert(BlockHelperFunc[k], string.format("BlockInfo fail f get %s", k))
        mRet[k] = f(self)
    end
    return net.Mask("base.PlayerAoiBlock", mRet)
end

function CPlayerEntity:BlockChange(...)
    local l = table.pack(...)
    self:SetAoiChange(l)
end

function CPlayerEntity:ClientBlockChange(m)
    local mBlock = self:BlockInfo(m)
    self:SendAoi("GS2CSyncAoi", {
        scene_id = self:GetSceneId(),
        eid = self:GetEid(),
        type = self:Type(),
        aoi_player_block = mBlock,
    })
end

function CPlayerEntity:EnterAoi(oMarker)
    if self:GetEid() == oMarker:GetEid() then
        return
    end
    self:OnEnterAoi(oMarker)
end

function CPlayerEntity:LeaveAoi(oMarker)
    if self:GetEid() == oMarker:GetEid() then
        return
    end
    self:OnLeaveAoi(oMarker)
end

function CPlayerEntity:OnEnterAoi(oMarker)
    if self:GetEid() == oMarker:GetEid() then
        return
    end
    if oMarker:IsPlayer() and oMarker:IsLeader() then
            local oTeam = oMarker:GetTeam()
            if oTeam then
                self:SetAoiAction(1, oTeam:GetTeamId(), 1)
            end
    end
    self:SetAoiAction(0, oMarker:GetEid(), 1)
end

function CPlayerEntity:OnLeaveAoi(oMarker)
    if self:GetEid() == oMarker:GetEid() then
        return
    end
    if oMarker:IsPlayer() and oMarker:IsLeader() then
            local oTeam = oMarker:GetTeam()
            if oTeam then
                self:SetAoiAction(1, oTeam:GetTeamId(), -1)
            end
    end
    self:SetAoiAction(0, oMarker:GetEid(), -1)
end

function CPlayerEntity:PackEnterAoiInfo()
    return playersend.PackData("GS2CEnterAoi",{
            scene_id = self:GetSceneId(),
            eid = self:GetEid(),
            type = self:Type(),
            aoi_player = self:GetAoiInfo(),
        })
end


function CPlayerEntity:OnClientEnter(iType, id)
    local oScene = self:GetScene()
    local oMarker
    if iType == 0 then
        oMarker = oScene:GetEntity(id)
    elseif iType == 1 then
        oMarker = oScene:GetTeamByTeamId(id)
    end

    if not oMarker then
        return
    end

    if oMarker:IsTeam() then
        local mNet = {
            scene_id = oMarker:GetSceneId(),
            team_id = oMarker:GetTeamId(),
            pid_list = oMarker:GetTeamSortMember(),
        }
        self:Send("GS2CSceneCreateTeam", mNet)
    else
        self:SendRaw(oMarker:GetEnterAoiInfoPack())
    end
end

function CPlayerEntity:OnClientLeave(iType, id)
    if iType == 0 then
        local oScene = self:GetScene()
        local oMarker = oScene:GetEntity(id)
        if oMarker then
            self:SendRaw(oMarker:GetLeaveAoiInfoPack())
        else
            self:Send("GS2CLeaveAoi", {
                scene_id = self:GetSceneId(),
                eid = id,
            })
        end
    elseif iType == 1 then
        local mNet = {
            scene_id = self:GetSceneId(),
            team_id = id,
        }
        self:Send("GS2CSceneRemoveTeam", mNet)
    end
end

function CPlayerEntity:ClrCacheSyncPosQueue()
    self.m_bCachePosQueue = false
    self.m_mCachePosQueue = nil
    self:DelTimeCb("DoSyncPosQueue")
end

function CPlayerEntity:CacheSyncPosQueue(mQ)
    if not self:GetTeam() or self:IsLeader() then
        self.m_mCachePosQueue = mQ
        if not self.m_bCachePosQueue then
            self.m_bCachePosQueue = true
            local iSceneId = self:GetSceneId()
            local iEid = self:GetEid()
            self:AddTimeCb("DoSyncPosQueue", 500, function ()
                local oSceneMgr = global.oSceneMgr
                local oScene = oSceneMgr:GetScene(iSceneId)
                if oScene then
                    local oEntity = oScene:GetEntity(iEid)
                    if oEntity then
                        if not oEntity:GetTeam() or oEntity:IsLeader() then
                            safe_call(oEntity.SyncPosQueue, oEntity, oEntity.m_mCachePosQueue)
                        end
                        oEntity:ClrCacheSyncPosQueue()
                    end
                end
            end)
        end
    end
end

function CPlayerEntity:SyncPosQueue(mQ)
    --[[
    local iCheck = self:ValidWalk(mQ)
    if iCheck ~= 0 then
        local mNow = gamedefines.CoverPos(self:GetPos())
        local sDebug = string.format(" %d %s %s",self.m_iScene,extend.Table.serialize(mNow),extend.Table.serialize(mQ))
        record.error(string.format("err SyncPosQueue %s %s %s",self:GetPid(),iCheck,sDebug))
        self:DelTimeCb("__SyncPosQueue")
        local mPos = self:GetPos()
        self:Send("GS2CTrunBackPos",{
            scene_id = self:GetSceneId(),
            eid = self:GetEid(),
            pos_info = gamedefines.CoverPos(self:GetPos()),
            })

        return
    end
    ]]

    local mPos = table.remove(mQ, #mQ)
    if mPos then
        self:SendAoi("GS2CSyncPosQueue", {
                scene_id = self:GetSceneId(),
                eid = self:GetEid(),
                poslist = {mPos,},
            })

        self.m_mPosQueue = {}
        self:__SyncPosQueue(mPos)
    end
end

function CPlayerEntity:ValidWalk(mQ)
    local iMQLen = #mQ
    if iMQLen < 1 then
        return 1
    end

    if iMQLen > 4 then
        return 4
    end
    if self.m_TestIgnoreWalk then
        return 0
    end
    local iSpeed = (self:GetSpeed()*2)^2
    local iHalfScreen = gamedefines.CHECK_SCREEN ^2
    local iMinSize = 10^2
    -- 大于半个屏幕或者小于直线距离时间的1/2
    -- 如果是客户的寻路最后一段,则
    local mNow = gamedefines.CoverPos(self:GetPos())
    local mFirst = mQ[1]["pos"]
    local iLen = (mFirst["x"]-mNow["x"])^2+(mFirst["y"]-mNow["y"])^2
    if iLen > iHalfScreen then
        return 5
    end

    for i=1,iMQLen do
        local mInfoPos1 = mQ[i]
        local mInfoPos2 = mQ[i+1]
        if mInfoPos2 then
            local mP1 = mInfoPos1["pos"]
            local mP2 = mInfoPos2["pos"]
            local iLen = (mP1["x"]-mP2["x"])^2+(mP1["y"]-mP2["y"])^2
            if iLen > iHalfScreen then
                return 3
            end
            if not (i+1 == iMQLen and iLen>iMinSize) and  iLen/iSpeed > mInfoPos1["time"]^2 then
                return 2
            end
            if mInfoPos1["time"] > 2000 or mInfoPos1["time"] < 100 then
                return 6
            end
        end
    end
    return 0
end

function CPlayerEntity:__SyncPosQueue(mCurInfo)
    self:DelTimeCb("__SyncPosQueue")
    local mCurPos = gamedefines.RecoverPos(mCurInfo["pos"])
    self:SyncNewPos(mCurPos)
    local iT = mCurInfo["time"]
    local iPid = self.m_iPid
    local iScene = self:GetSceneId()
    local f = function()
        local oScene = global.oSceneMgr:GetScene(iScene)
        if not oScene then
            return
        end
        local oPlayer = oScene:GetPlayerEntity(iPid)
        if oPlayer then
            local mPos = table.remove(oPlayer.m_mPosQueue,1)
            if mPos then
                oPlayer:__SyncPosQueue(mPos)
            end
        end
    end
    if iT and iT > 0 then
        self:AddTimeCb("__SyncPosQueue", iT, f)
    end
end

function CPlayerEntity:SyncNewPos(mCurPos)
    local oScene = self:GetScene()
    local oTeamEntity = oScene:GetTeamByPid(self:GetPid())
    if oTeamEntity then
        if oTeamEntity:IsLeader(self:GetPid()) then
            local mMem = oTeamEntity:GetTeamMember()
            for k, _ in pairs(mMem) do
                    local o = oScene:GetPlayerEntity(k)
                    if o then
                        o:SetPos({
                            x = mCurPos.x,
                            y = mCurPos.y,
                            face_x = mCurPos.face_x,
                            face_y = mCurPos.face_y,
                        })
                        o:SetSpeed(mCurPos.v)
                    end
            end
        end
    else
        self:SetPos({
            x = mCurPos.x,
            y = mCurPos.y,
            face_x = mCurPos.face_x,
            face_y = mCurPos.face_y,
        })
        self:SetSpeed(mCurPos.v)
    end
end

function CPlayerEntity:SetPlayerPos(mCurPos)
    local oScene = self:GetScene()
    local iScene = oScene:GetSceneId()

    self:SyncNewPos(mCurPos)

    self:SendAoi("GS2CTrunBackPos",{
        scene_id = iScene,
        eid = self:GetEid(),
        pos_info = gamedefines.CoverPos(self:GetPos()),
    })
    self:Send("GS2CTrunBackPos",{
        scene_id = iScene,
        eid = self:GetEid(),
        pos_info = gamedefines.CoverPos(self:GetPos()),
    })
end

function CPlayerEntity:SetPos(mPos)
    super(CPlayerEntity).SetPos(self, mPos)
    local mData = {
        pos_info = mPos,
    }
    self.m_oPlayerShareObj:UpdateData(mData)
    self:ClrCacheSyncPosQueue()
end

function CPlayerEntity:UpdateShareData(mPos)
    local mData = {
        pos_info = mPos,
    }
    self.m_oPlayerShareObj:UpdateData(mData)
end

function CPlayerEntity:SyncInfo(mArgs)
    local lAttrName = {
        "name", "icon", "model_info", 
        "followers", "title_info", "show_id",
        "dance_tag","touxian_tag","org_id",
        "state","fly_height", "engage_pid", 
        "treasureconvoy_tag",
    }
    for _, sAttr in ipairs(lAttrName) do
        if mArgs[sAttr] then
            self:SetData(sAttr, mArgs[sAttr])
            self:BlockChange(sAttr)
        end
    end
    if mArgs["walk_speed"] then
        self:SetSpeed(mArgs["walk_speed"])
    end
end

function CPlayerEntity:AddWaterWalk(iStartTime, iEndTime, mStartPos, mEndPos)
    self:AddAction(gamedefines.ENTITY_ACTION_TYPE.WATER_WALK, {
        start_time=iStartTime,
        end_time=iEndTime,
        start_pos = gamedefines.CoverPos(mStartPos),
        end_pos = gamedefines.CoverPos(mEndPos),
    })
    self:BlockChange("action")
    -- if not self:GetTeamInfo() or self:IsLeader() then
    --     self:SyncNewPos(mEndPos)
    -- end

    local iSceneId = self.m_iScene
    local iEid = self:GetEid()
    local f1
    f1 = function ()
        local oSceneMgr = global.oSceneMgr
        local oEntity = oSceneMgr:GetEntity(iSceneId, iEid)
        if oEntity then
            oEntity:_RemoveWaterWalk()
        end
    end
    self:DelTimeCb("_RemoveWaterWalk")
    local iDelay = math.max(1, (iEndTime - get_time())*1000)
    self:AddTimeCb("_RemoveWaterWalk", iDelay, f1)
end

function CPlayerEntity:_RemoveWaterWalk()
    self:DelAction(gamedefines.ENTITY_ACTION_TYPE.WATER_WALK)
end

function CPlayerEntity:GetScenePlayerReaderCopy()
    return self.m_oPlayerShareObj:GenReaderCopy()
end


CScenePlayerShareObj = {}
CScenePlayerShareObj.__index = CScenePlayerShareObj
inherit(CScenePlayerShareObj, shareobj.CShareWriter)

function CScenePlayerShareObj:New()
    local o = super(CScenePlayerShareObj).New(self)
    o.m_mPos = {}
    return o
end

function CScenePlayerShareObj:UpdateData(mData)
    self.m_mPos = mData.pos_info or self.m_mPos
    self:Update()
end

function CScenePlayerShareObj:Pack()
    local m = {}
    m.pos_info = self.m_mPos
    return m
end
