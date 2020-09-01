--import module
local global = require "global"
local skynet = require "skynet"
local geometry = require "base.geometry"
local interactive = require "base.interactive"
local netproto = require "base.netproto"
local playersend = require "base.playersend"

local gamedefines = import(lualib_path("public.gamedefines"))

ForwardNetcmds = {}

function ForwardNetcmds.C2GSSyncPosQueue(oPlayer, mData)
    local iScene = mData.scene_id
    local iEid = mData.eid
    if oPlayer:GetEid() ~= iEid then
        return
    end
    oPlayer:CacheSyncPosQueue(mData["poslist"] or {})
end

function ConfirmRemote(mRecord, mData)
    local iScene = mData.scene_id
    local iMap = mData.map_id
    local oSceneMgr = global.oSceneMgr
    oSceneMgr:ConfirmRemote(iScene,iMap)
end

function RemoveRemote(mRecord, mData)
    local iScene = mData.scene_id
    local oSceneMgr = global.oSceneMgr
    oSceneMgr:RemoveScene(iScene)
end

function CreateSceneTeam(mRecord, mData)
    local iScene = mData.scene_id
    local iTeam = mData.team_id
    local iEid = mData.eid
    local mMem = mData.mem
    local mShort = mData.short
    local oSceneMgr = global.oSceneMgr
    local oScene = oSceneMgr:GetScene(iScene)
    assert(oScene, string.format("CreateSceneTeam error scene: %d %d", iScene, iTeam))
    oScene:CreateSceneTeam(iEid, iTeam, mMem, mShort)
end

function RemoveSceneTeam(mRecord, mData)
    local iScene = mData.scene_id
    local iTeam = mData.team_id
    local oSceneMgr = global.oSceneMgr
    local oScene = oSceneMgr:GetScene(iScene)
    assert(oScene, string.format("RemoveSceneTeam error scene: %d %d", iScene, iTeam))
    oScene:RemoveSceneTeam(iTeam)
end

function UpdateSceneTeam(mRecord, mData)
    local iScene = mData.scene_id
    local iTeam = mData.team_id
    local mMem = mData.mem
    local mShort = mData.short
    local oSceneMgr = global.oSceneMgr
    local oScene = oSceneMgr:GetScene(iScene)
    assert(oScene, string.format("UpdateSceneTeam error scene: %d %d", iScene, iTeam))
    oScene:UpdateSceneTeam(iTeam, mMem, mShort)
end

function EnterPlayer(mRecord, mData)
    local iScene = mData.scene_id
    local mPos = mData.pos
    local iPid = mData.pid
    local iEid = mData.eid
    local mInfo = mData.data
    local iSpeed = mData.walk_speed
    local oSceneMgr = global.oSceneMgr
    local oScene = oSceneMgr:GetScene(iScene)
    assert(oScene, string.format("EnterPlayer error scene: %d %d %d", iScene, iPid, iEid))
    playersend.ReplacePlayerMail(iPid)
    oScene:EnterPlayer(iPid, iEid, mPos, mInfo, iSpeed)
end

function EnterGMPlayer(mRecord, mData)
    local iScene = mData.scene_id
    local mPos = mData.pos
    local iPid = mData.pid
    local iEid = mData.eid
    local mInfo = mData.data
    local iSpeed = mData.walk_speed
    local oSceneMgr = global.oSceneMgr
    local oScene = oSceneMgr:GetScene(iScene)
    assert(oScene, string.format("EnterPlayer error scene: %d %d %d", iScene, iPid, iEid))
    playersend.ReplacePlayerMail(iPid)
    oScene:EnterGMPlayer(iPid, iEid, mPos, mInfo, iSpeed)
end

function SyncPlayerInfo(mRecord,mData)
    local iScene = mData.scene_id
    local mArgs = mData.args
    local iEid = mData.eid
    local oSceneMgr = global.oSceneMgr
    local oScene = oSceneMgr:GetScene(iScene)
    assert(oScene,string.format("SyncPlayerInfo err scene,%d",iScene))
    local oPlayerEntity = oScene:GetEntity(iEid)
    assert(oPlayerEntity,string.format("SyncPlayerInfo err %d",iEid))
    if oPlayerEntity:IsPlayer() then
        oPlayerEntity:SyncInfo(mArgs)
    end
end

function LeavePlayer(mRecord, mData)
    local iScene = mData.scene_id
    local iPid = mData.pid
    local oSceneMgr = global.oSceneMgr
    local oScene = oSceneMgr:GetScene(iScene)
    if oScene then
        oScene:LeavePlayer(iPid)
    end
end

function LeaveGMPlayer(mRecord, mData)
    local iScene = mData.scene_id
    local iPid = mData.pid
    local oSceneMgr = global.oSceneMgr
    local oScene = oSceneMgr:GetScene(iScene)
    if oScene then
        oScene:LeaveGMPlayer(iPid)
    end
end

function ReEnterPlayer(mRecord, mData)
    local iScene = mData.scene_id
    local iPid = mData.pid
    local oSceneMgr = global.oSceneMgr
    local oScene = oSceneMgr:GetScene(iScene)
    assert(oScene, string.format("ReEnterPlayer error scene: %d %d", iScene, iPid))
    playersend.ReplacePlayerMail(iPid)
    oScene:ReEnterPlayer(iPid)
end

function NotifyDisconnected(mRecord, mData)
    local iScene = mData.scene_id
    local iPid = mData.pid
    local oSceneMgr = global.oSceneMgr
    local oScene = oSceneMgr:GetScene(iScene)
    if oScene then
        local oPlayerEntity = oScene:GetPlayerEntity(iPid)
        if oPlayerEntity then
            oPlayerEntity:Disconnected()
        end
    end
end

function NotifyEnterWar(mRecord, mData)
    local iScene = mData.scene_id
    local iPid = mData.pid
    local oSceneMgr = global.oSceneMgr
    local oScene = oSceneMgr:GetScene(iScene)
    if oScene then
        local oPlayerEntity = oScene:GetPlayerEntity(iPid)
        if oPlayerEntity then
            oPlayerEntity:EnterWar()
        end
    end
end

function NotifyLeaveWar(mRecord, mData)
    local iScene = mData.scene_id
    local iPid = mData.pid
    local oSceneMgr = global.oSceneMgr
    local oScene = oSceneMgr:GetScene(iScene)
    if oScene then
        local oPlayerEntity = oScene:GetPlayerEntity(iPid)
        if oPlayerEntity then
            oPlayerEntity:LeaveWar()
        end
    end
end

function NpcEnterWar(mRecord, mData)
    local iScene = mData.scene_id
    local iEid = mData.eid
    local oSceneMgr = global.oSceneMgr
    local oScene = oSceneMgr:GetScene(iScene)
    if oScene then
        local oNpcEntity = oScene:GetEntity(iEid)
        if oNpcEntity then
            oNpcEntity:EnterWar()
        end
    end
end

function NpcLeaveWar(mRecord, mData)
    local iScene = mData.scene_id
    local iEid = mData.eid
    local oSceneMgr = global.oSceneMgr
    local oScene = oSceneMgr:GetScene(iScene)
    if oScene then
        local oNpcEntity = oScene:GetEntity(iEid)
        if oNpcEntity then
            oNpcEntity:LeaveWar()
        end
    end
end

function Forward(mRecord, mData)
    local iPid = mData.pid
    local iRouteScene = mData.scene_id
    local sCmd = mData.cmd
    local m = netproto.ProtobufFunc("default", sCmd, mData.data)

    local oSceneMgr = global.oSceneMgr
    local oScene = oSceneMgr:GetScene(iRouteScene)
    if oScene then
        local oPlayerEntity = oScene:GetPlayerEntity(iPid)
        if oPlayerEntity then
            local func = ForwardNetcmds[sCmd]
            if func then
                func(oPlayerEntity, m)
            end
        end
    end
end

function Query(mRecord, mData)
    local oSceneMgr = global.oSceneMgr
    local sType = mData.type
    local iScene = mData.scene_id
    local m = mData.data

    local oScene = oSceneMgr:GetScene(iScene)
    if not oScene then
        interactive.Response(mRecord.source, mRecord.session, {})
        return
    end

    if sType == "player_pos" then
        local iPid = m.pid
        local oPlayerEntity = oScene:GetPlayerEntity(iPid)
        if oPlayerEntity then
            interactive.Response(mRecord.source, mRecord.session, {
                data = {
                    scene_id = iScene,
                    pid = iPid,
                    pos_info = oPlayerEntity:GetPos(),
                }
            })
            return
        end
    elseif sType == "all_players" then
        local lPids = oScene:GetAllPlayers()
        interactive.Response(mRecord.source, mRecord.session, {
            data = {
                pids = lPids,
            },
        })
    elseif sType == "aoiview_players" then
        local iPid = m.pid
        local oPlayerEntity = oScene:GetPlayerEntity(iPid)
        if oPlayerEntity then
            local lAoi = oPlayerEntity:GetAoi()
            local lPid = {} 
            for _, o in ipairs(lAoi) do
                table.insert(lPid, o:GetPid())
            end
            interactive.Response(mRecord.source, mRecord.session, {
                data = {
                    scene_id = iScene,
                    pid = iPid,
                    lpid = lPid,
                }
            })
            return
        end
    end
end

function SetPlayerPos(mRecord,mData)
    local iScene = mData.scene_id
    local iPid = mData.pid
    local m = mData.data
    local mPos = {
        x = m.x,
        y = m.y,
        face_x = m.face_x,
        face_y = m.face_y,
    }
    local oSceneMgr = global.oSceneMgr
    local oScene = oSceneMgr:GetScene(iScene)
    if oScene then
        local oPlayerEntity = oScene:GetPlayerEntity(iPid)
        if oPlayerEntity then
            oPlayerEntity:SetPlayerPos(mPos)
        end
    end
end

function EnterNpc(mRecord,mData)
   local iScene = mData.scene_id
   local mPos = mData.pos
   local mInfo = mData.data
   local iEid = mData.eid
   local oSceneMgr = global.oSceneMgr
   local oScene = oSceneMgr:GetScene(iScene)
   assert(oScene,string.format("EnterNpc error scene:%d %d %d",iScene,iEid,mInfo.npctype))
   oScene:EnterNpc(iEid,mPos,mInfo)
end

function SyncNpcInfo(mRecord,mData)
    local iScene = mData.scene_id
    local mArgs = mData.args
    local iEid = mData.eid
    local oSceneMgr = global.oSceneMgr
    local oScene = oSceneMgr:GetScene(iScene)
    assert(oScene,string.format("SyncNpcInfo err scene,%d",iScene))
    local oNpcEntity = oScene:GetEntity(iEid)
    assert(oNpcEntity,string.format("SyncNpcInfo err %d",iEid))
    if oNpcEntity:IsNpc() then
        oNpcEntity:SyncInfo(mArgs)
    end
end

function RemoveSceneNpc(mRecord,mData)
    local iScene = mData.scene_id
    local iEid = mData.eid
    local oSceneMgr = global.oSceneMgr
    local oScene = oSceneMgr:GetScene(iScene)
    assert(oScene,string.format("RemoveSceneNpc error scene %d %d",iScene,iEid))
    oScene:RemoveSceneNpc(iEid)
end

function EnterEffect(mRecord, mData)
   local iScene = mData.scene_id
   local mPos = mData.pos
   local iEffId = mData.effect_id
   local mInfo = mData.data
   local iEid = mData.eid
   local oSceneMgr = global.oSceneMgr
   local oScene = oSceneMgr:GetScene(iScene)
   assert(oScene,string.format("EnterEffect error scene:%d %d %d", iScene, iEid, iEffId))
   oScene:EnterEffect(iEid, iEffId, mPos, mInfo)
end

function RemoveSceneEffect(mRecord, mData)
    local iScene = mData.scene_id
    local iEid = mData.eid
    local oSceneMgr = global.oSceneMgr
    local oScene = oSceneMgr:GetScene(iScene)
    assert(oScene,string.format("RemoveSceneEffect error scene %d %d", iScene, iEid))
    oScene:RemoveSceneEffect(iEid)
end

function SceneAoiChat(mRecord, mData)
    local iScene = mData.scene_id
    local iPid = mData.pid
    local mNet = mData.net

    local oSceneMgr = global.oSceneMgr
    local oScene = oSceneMgr:GetScene(iScene)
    if oScene then
        if iPid~=0 then
            local oPlayerEntity = oScene:GetPlayerEntity(iPid)
            if oPlayerEntity then
                oPlayerEntity:SendAoi("GS2CChat", mNet, true)
            end
        else
            local plist = oScene:GetAllPlayers()
            for _,pid in ipairs(plist) do
                local oPlayerEntity = oScene:GetPlayerEntity(pid)
                if oPlayerEntity then
                    local sData = playersend.PackData("GS2CChat", mNet)
                    playersend.SendRaw(oPlayerEntity.m_iPid, sData)
                end
            end
        end
    end
end

function SceneAoiEffect(mRecord, mData)
    local iScene = mData.scene_id
    local iPid = mData.pid
    local mNet = mData.net

    local oSceneMgr = global.oSceneMgr
    local oScene = oSceneMgr:GetScene(iScene)
    if oScene then
        local oPlayerEntity = oScene:GetPlayerEntity(iPid)
        if oPlayerEntity then
            oPlayerEntity:SendAoi("GS2CSceneEffect", mNet, true)
        end
    end
end

function PlayerAddWaterWalk(mRecord, mData)
    local iScene = mData.scene_id
    local iPid = mData.pid
    local iStartTime = mData.start_time
    local iEndTime = mData.end_time
    local mStartPos = mData.start_pos
    local mEndPos = mData.end_pos

    local oSceneMgr = global.oSceneMgr
    local oScene = oSceneMgr:GetScene(iScene)
    if oScene then
        local oPlayerEntity = oScene:GetPlayerEntity(iPid)
        if oPlayerEntity then
            oPlayerEntity:AddWaterWalk(iStartTime, iEndTime, mStartPos, mEndPos)
        end
    end
end

function BroadcastMessage(mRecord, mData)
    local sMessage = mData.message
    local mInfo = mData.data
    local mExclude = mData.exclude
    local iScene = mData.scene_id
    local oScene = global.oSceneMgr:GetScene(iScene)
    if oScene then
        oScene:BroadcastMessage(sMessage, mInfo, mExclude)
    end
end
