--import module

local global = require "global"
local skynet = require "skynet"
local interactive = require "base.interactive"
local res = require "base.res"
local geometry = require "base.geometry"
local extend = require "base.extend"
local record = require "public.record"

local idpool = import(lualib_path("base.idpool"))
local gamedefines = import(lualib_path("public.gamedefines"))


function NewSceneMgr(...)
    local o = CSceneMgr:New(...)
    return o
end

function NewScene(...)
    local o = CScene:New(...)
    return o
end

function NewAnLeiCtrl(...)
    local o = CAnLeiCtrl:New(...)
    return o
end


CSceneMgr = {}
CSceneMgr.__index = CSceneMgr
inherit(CSceneMgr, logic_base_cls())

function CSceneMgr:New(lSceneRemote)
    local o = super(CSceneMgr).New(self)
    o.m_iDispatchId = 0
    o.m_iSelectHash = 1
    o.m_lSceneRemote = lSceneRemote
    o.m_mScenes = {}
    o.m_mDurableScenes = {}

    return o
end

function CSceneMgr:Release()
    for _, v in pairs(self.m_mScenes) do
        baseobj_safe_release(v)
    end
    self.m_mScenes = {}
    super(CSceneMgr).Release(self)
end

function CSceneMgr:DispatchSceneId()
    self.m_iDispatchId = self.m_iDispatchId + 1
    return self.m_iDispatchId
end

function CSceneMgr:RandomPos(iMapId)
    local iMapRes = res["daobiao"]["map"][iMapId]["resource_id"]
    assert(iMapRes, string.format("RandomPos err map:%d", iMapId))
    local mPosList = res["map"]["npc_area"][iMapRes]
    assert(mPosList and next(mPosList), string.format("RandomPos err npc_area, map:%d", iMapId))
    local mPos = extend.Random.random_choice(mPosList)
    return table.unpack(mPos)
end

--不靠近传送点的npc区域
function CSceneMgr:RandomPos2(iMapId)
    local iMapRes = res["daobiao"]["map"][iMapId]["resource_id"]
    assert(iMapRes, string.format("RandomPos err map:%d", iMapId))
    local mPosList = res["map"]["new_npc_area"][iMapRes]
    assert(mPosList and next(mPosList), string.format("RandomPos err npc_area, map:%d", iMapId))
    local mPos = extend.Random.random_choice(mPosList)
    return table.unpack(mPos)
end

function CSceneMgr:IsInLeiTai(iScene, iX, iY)
    local oScene = self:GetScene(iScene)
    assert(oScene, string.format("IsInLeiTai err: %s %s %s", iScene, iX, iY))
    local iMapId = oScene:MapId()

    local iMapRes = res["daobiao"]["map"][iMapId]["resource_id"]
    assert(iMapRes, string.format("RandomPos err %d", iMapId))
    if not res["map"]["leitai"][iMapRes] then
        return false
    end
    local mLeiTai = res["map"]["leitai"][iMapRes]

    local iYIdx = math.floor(iY / 0.32)
    iYIdx = mLeiTai["len"] - iYIdx
    local iXIdx = math.floor(iX / 0.32)
    if not mLeiTai["leitaidata"][iYIdx] or not mLeiTai["leitaidata"][iYIdx][iXIdx] then
        return false
    else
        return true
    end
end

function CSceneMgr:IsInDance(iScene, iX, iY)
    local oScene = self:GetScene(iScene)
    assert(oScene, string.format("IsInDance err: %s %s %s", iScene, iX, iY))
    local iMapId = oScene:MapId()

    local iMapRes = res["daobiao"]["map"][iMapId]["resource_id"]
    assert(iMapRes, string.format("RandomPos err %d", iMapId))
    if not res["map"]["dance"][iMapRes] then
        return false
    end
    local mDance = res["map"]["dance"][iMapRes]

    local iYIdx = math.floor(iY / 0.32)
    iYIdx = mDance["len"] - iYIdx
    local iXIdx = math.floor(iX / 0.32)
    if not mDance["dancedata"][iYIdx] or not mDance["dancedata"][iYIdx][iXIdx] then
        return false
    else
        return true
    end
end

function CSceneMgr:RandomDance()
    local iMapId = 101000
    local iMapRes = res["daobiao"]["map"][iMapId]["resource_id"]
    assert(iMapRes, string.format("RandomPos err %d", iMapId))
    local mPosList = res["map"]["dancepos"][iMapRes]
    local mPos = extend.Random.random_choice(mPosList)
    local x,y =  table.unpack(mPos)
    return iMapId,x,y
end

function CSceneMgr:SelectRemoteScene()
    local iSel = self.m_iSelectHash
    if iSel >= #self.m_lSceneRemote then
        self.m_iSelectHash = 1
    else
        self.m_iSelectHash = iSel + 1
    end
    return self.m_lSceneRemote[iSel]
end

function CSceneMgr:SelectDurableScene(iMapId)
    local m = self.m_mDurableScenes[iMapId]
    local iTargetId
    if m then
        --iTargetId = m[math.random(#m)]
        iTargetId = m[1]
    end
    if iTargetId then
        return self:GetScene(iTargetId)
    end
end

function CSceneMgr:CreateScene(mInfo)
    local id = self:DispatchSceneId()
    local oScene = NewScene(id, mInfo)
    oScene:ConfirmRemote()
    self.m_mScenes[id] = oScene

    if oScene:IsDurable() then
        local iMapId = oScene:MapId()
        local m = self.m_mDurableScenes[iMapId]
        if not m then
            self.m_mDurableScenes[iMapId] = {}
            m = self.m_mDurableScenes[iMapId]
        end
        table.insert(m, oScene:GetSceneId())
    end
    record.log_db("scene","create",{id = tostring(oScene:GetSceneId()),mapid = tostring(oScene:MapId())})
    return oScene
end

function CSceneMgr:CreateVirtualScene(mInfo)
    assert (not mInfo.is_durable, "virtual scene cann't be durable")

    local id = self:DispatchSceneId()
    local oScene = NewScene(id, mInfo)
    oScene.m_sType = "virtual"
    oScene:ConfirmRemote()
    self.m_mScenes[id] = oScene
    record.log_db("scene","create",{id = tostring(oScene:GetSceneId()),mapid = tostring(oScene:MapId())})
    return oScene
end

function CSceneMgr:GetScene(id)
    return self.m_mScenes[id]
end

function CSceneMgr:RemoveScene(id)
    local oScene = self.m_mScenes[id]
    if oScene then
        oScene:ReleasePlayer()
        record.log_db("scene","remove",{id = tostring(oScene:GetSceneId()),mapid = tostring(oScene:MapId())})
        baseobj_delay_release(oScene)
        self.m_mScenes[id] = nil
    end
end

function CSceneMgr:RemoveVirtualScene(id)
    local oScene = self.m_mScenes[id]
    if oScene and oScene.m_sType == "virtual" then
        self:RemoveScene(id)
    end
end

function CSceneMgr:GetSceneListByMap(iMapId)
    local mScene = self.m_mDurableScenes[iMapId] or {}
    local mSceneObj = {}
    for _,iScene in pairs(mScene) do
        local oScene = self:GetScene(iScene)
        table.insert(mSceneObj,oScene)
    end
    return mSceneObj
end

function CSceneMgr:GetSceneName(iMapId)
    local mScene = self.m_mDurableScenes[iMapId] or {}
    for _,iScene in pairs(mScene) do
        local oScene = self:GetScene(iScene)
        return oScene:GetName()
    end
end

function CSceneMgr:OnEnterWar(oPlayer)
    local oNowScene = oPlayer.m_oActiveCtrl:GetNowScene()
    if oNowScene then
        oNowScene:NotifyEnterWar(oPlayer)
    end
    oPlayer:FireEnterWarScene()
end

function CSceneMgr:NpcJumpScene(nowscid, entityid, targetsc, targetpos)
    local oNewScene = self:GetScene(targetsc)
    assert(oNewScene, string.format("NpcJumpScene target error %d", targetsc))
    local oNowScene = self:GetScene(nowscid)
    assert(oNowScene, string.format("NpcJumpScene nowscene error %d", nowscid))

    local oNpcMgr = global.oNpcMgr
    local nid = oNowScene:GetNpcidByEid(entityid)
    local oNpc = oNpcMgr:GetObject(nid)
    oNowScene:RemoveSceneNpc(oNpc.m_ID)
    oNpc.m_mPosInfo = targetpos
    oNpc:SetScene(targetsc)
    oNewScene:EnterNpc(oNpc)
end

function CSceneMgr:OnNpcMoveEnd(nowscid, entityid)
    local oNowScene = self:GetScene(nowscid)
    assert(oNowScene, string.format("NpcJumpScene nowscene error %d", nowscid))

    local oNpcMgr = global.oNpcMgr
    local nid = oNowScene:GetNpcidByEid(entityid)
    local oNpc = oNpcMgr:GetObject(nid)
    oNpc:OnNpcMoveEnd()
end

function CSceneMgr:OnLeaveWar(oPlayer)
    local oNowScene = oPlayer.m_oActiveCtrl:GetNowScene()
    if oNowScene then
        oNowScene:NotifyLeaveWar(oPlayer)
    end
end

function CSceneMgr:NpcEnterWar(oNpc)
    if not oNpc.m_Scene then
        return
    end
    local oScene = self:GetScene(oNpc.m_Scene)
    if oScene then
        oScene:NpcEnterWar(oNpc)
    end
end

function CSceneMgr:NpcLeaveWar(oNpc)
    if not oNpc.m_Scene then
        return
    end
    local oScene = self:GetScene(oNpc.m_Scene)
    if oScene then
        oScene:NpcLeaveWar(oNpc)
    end
end

function CSceneMgr:OnDisconnected(oPlayer)
    local oNowScene = oPlayer.m_oActiveCtrl:GetNowScene()
    if oNowScene then
        oNowScene:NotifyDisconnected(oPlayer)
    end
end

function CSceneMgr:OnLogout(oPlayer)
    self:LeaveScene(oPlayer, true)
end

function CSceneMgr:OnLogin(oPlayer, bReEnter)
    if bReEnter then
        self:ReEnterScene(oPlayer)
    else
        --lxldebug test
        self:EnterDurableScene(oPlayer)
    end
end

function CSceneMgr:ReEnterScene(oPlayer)
    local oNowScene = oPlayer.m_oActiveCtrl:GetNowScene()
    if oNowScene then
        oNowScene:ReEnterPlayer(oPlayer)
    else
        self:EnterDurableScene(oPlayer)
    end
    return {errcode = gamedefines.ERRCODE.ok}
end

-- -- 这个接口在有当前场景情况下不会LeaveScene
-- function CSceneMgr:ReEnterSceneXY(oPlayer, rX, rY)
--     local oNowScene = oPlayer.m_oActiveCtrl:GetNowScene()
--     if oNowScene then
--         oNowScene:ReEnterXYPlayer(oPlayer, rX, rY)
--     else
--         self:EnterDurableScene(oPlayer)
--     end
--     return {errcode = gamedefines.ERRCODE.ok}
-- end

function CSceneMgr:EnterDurableScene(oPlayer)
    local mDurableInfo = oPlayer.m_oActiveCtrl:GetDurableSceneInfo()
    local iMapId = mDurableInfo.map_id
    local mPos = mDurableInfo.pos
    local oScene = self:SelectDurableScene(iMapId)
    self:EnterScene(oPlayer, oScene:GetSceneId(), {pos = mPos})
end

function CSceneMgr:TeamEnterDurableScene(oPlayer)
    local mDurableInfo = oPlayer.m_oActiveCtrl:GetDurableSceneInfo()
    local iMapId = mDurableInfo.map_id
    local mPos = mDurableInfo.pos
    local oScene = self:SelectDurableScene(iMapId)
    self:TeamEnterScene(oPlayer, oScene:GetSceneId(), {pos = mPos})
end

function CSceneMgr:LeaveScene(oPlayer, bLogout)
    local oNowScene = oPlayer.m_oActiveCtrl:GetNowScene()
    if not oNowScene then
        return
    end
    if oPlayer.m_iGodEyes then
        local oScene = self:GetScene(oPlayer.m_iGodEyes)
        if oScene then
            oScene:LeaveGMPlayer(oPlayer)
        end
    end
    oNowScene:LeavePlayer(oPlayer, bLogout)
end

function CSceneMgr:TeamEnterScene(oPlayer,iScene,mInfo)
    local oTeam = oPlayer:HasTeam()
    if not oTeam or not oTeam:IsTeamMember(oPlayer:GetPid()) then
        record.error(debug.traceback())
    end
    local oWorldMgr = global.oWorldMgr
    local oNewScene = self:GetScene(iScene)
    assert(oNewScene, string.format("EnterScene error %d", iScene))
    local oNowScene = oPlayer.m_oActiveCtrl:GetNowScene()
    local iFromSceneId = oNowScene:GetSceneId()

    local mMem = oPlayer:GetTeamMember()
    local mPlayer = {}
    for _,pid in ipairs(mMem) do
        local oMemPlayer = oWorldMgr:GetOnlinePlayerByPid(pid)
        safe_call(function ()
            if oMemPlayer then
                local oMemScene = oMemPlayer.m_oActiveCtrl:GetNowScene()
                if oMemScene and oNowScene and oMemScene ~= oNowScene then
                    record.warning("mem sc not equal to leader sc: %s, %s %s, %s %s",
                        oPlayer:TeamID(), oPlayer:GetPid(), oNowScene:GetSceneId(), pid, oMemScene:GetSceneId())
                end
            end
        end)
        table.insert(mPlayer,oMemPlayer)
    end

    self:RemoveSceneTeam(oPlayer, oPlayer:TeamID())

    for _,oMemPlayer in pairs(mPlayer) do
        local oMemScene = oMemPlayer.m_oActiveCtrl:GetNowScene()
        if oMemScene then
            oMemScene:LeavePlayer(oMemPlayer, false, iScene)
        end
        oNewScene:EnterPlayer(oMemPlayer, mInfo.pos, iFromSceneId)
    end

    self:CreateSceneTeam(oPlayer)

    return {errcode = gamedefines.ERRCODE.ok}
end

function CSceneMgr:EnterScene(oPlayer, iScene, mInfo)
    local oTeam = oPlayer:HasTeam()
    if oTeam and oTeam:IsTeamMember(oPlayer:GetPid()) then
        record.error(debug.traceback())
    end

    local oNewScene = self:GetScene(iScene)
    assert(oNewScene, string.format("EnterScene error %d", iScene))
    local oNowScene = oPlayer.m_oActiveCtrl:GetNowScene()
    local iFromSceneId

    if oNowScene then
        iFromSceneId = oNowScene:GetSceneId()
        oNowScene:LeavePlayer(oPlayer, false, iScene)
    end
    oNewScene:EnterPlayer(oPlayer, mInfo.pos, iFromSceneId)

    return {errcode = gamedefines.ERRCODE.ok}
end

function CSceneMgr:GMEnterScene(oPlayer, iScene, mInfo)
    local oNewScene = self:GetScene(iScene)
    assert(oNewScene, string.format("EnterScene error %d", iScene))
    local iNowScene = oPlayer.m_iGodEyes
    local oNowScene
    if iNowScene then
        oNowScene = self:GetScene(iNowScene)
    end
    if oNowScene then
        oNowScene:LeaveGMPlayer(oPlayer)
    end
    oNewScene:EnterGMPlayer(oPlayer, mInfo.pos)
    return {errcode = gamedefines.ERRCODE.ok}
end

function CSceneMgr:DoTransfer(oPlayer, iScene, mPos)
    local oScene = self:GetScene(iScene)
    if oScene then
        if not mPos then
            local iX, iY = self:GetFlyData(oScene:MapId())
            mPos = {x = iX, y = iY}
        end
        local mNowPos = oPlayer.m_oActiveCtrl:GetNowPos()
        local mNewPos = {
            x = mPos.x,
            y = mPos.y,
            z = mNowPos.z,
            face_x = mNowPos.face_x,
            face_y = mNowPos.face_y,
            face_z=mNowPos.face_z
        }
        if oPlayer:IsTeamLeader() then
            self:TeamEnterScene(oPlayer,iScene, {pos = mNewPos})
        elseif oPlayer:IsSingle() then
            self:EnterScene(oPlayer, iScene, {pos = mNewPos})
        end
    end
end

function CSceneMgr:ChangeMap(oPlayer, iMapId, mPosInfo)
    local oNowScene = oPlayer.m_oActiveCtrl:GetNowScene()
    local iNewX,iNewY = self:GetFlyData(iMapId)
    if mPosInfo then
        iNewX, iNewY = mPosInfo.x, mPosInfo.y
    end
    local oScene = self:SelectDurableScene(iMapId)
    if not oScene then return end

    if not oNowScene:ValidLeave(oPlayer,oScene) then
        return
    end
    if not oScene:ValidEnter(oPlayer) then
        return
    end
    self:DoTransfer(oPlayer, oScene:GetSceneId(), {x=iNewX, y=iNewY})
    return true
end

function CSceneMgr:ClickTrapMineMap(oPlayer, iMapId)
    local oNowScene = oPlayer.m_oActiveCtrl:GetNowScene()
    if oNowScene:MapId() == iMapId then
        return
    end
    local oScene = self:SelectDurableScene(iMapId)
    if not oNowScene:ValidLeave(oPlayer,oScene) then
        return
    end
    if not oScene:ValidEnter(oPlayer) then
        return
    end
    if not oScene:HasAnLei() then
        return
    end
    if oScene then
        self:DoTransfer(oPlayer, oScene:GetSceneId())
    end
end

function CSceneMgr:TransferScene(oPlayer, iTransferId)
    local oNowScene = oPlayer.m_oActiveCtrl:GetNowScene()
    if not oNowScene then
        return
    end
    local lTransfers = oNowScene:GetTransfers()
    if not lTransfers then
        return
    end
    local m = lTransfers[iTransferId]
    if not m or not next(m) then
        return
    end
    local iX, iY, iTargetMapIndex, iTargetX, iTargetY = m.x, m.y, m.target_scene, m.target_x, m.target_y
    oNowScene:QueryRemote("player_pos", {pid = oPlayer:GetPid()}, function (mRecord, mData)
        local m = mData.data
        if not m then
            return
        end
        local mMapInfo = res["daobiao"]["scene"][iTargetMapIndex]
        if not mMapInfo then
            return
        end

        local iRemoteScene = m.scene_id
        local iRemotePid = m.pid
        local mRemotePos = m.pos_info
        local oWorldMgr = global.oWorldMgr
        local oPlayer = oWorldMgr:GetOnlinePlayerByPid(iRemotePid)
        local oNowScene = oPlayer.m_oActiveCtrl:GetNowScene()
        if not oNowScene or oNowScene:GetSceneId() ~= iRemoteScene or oNowScene:MapId() == mMapInfo.map_id then
            return
        end
        if ((mRemotePos.x - iX) ^ 2 + (mRemotePos.y - iY) ^ 2) > 12 ^ 2 then
            return
        end
        local oScene = self:SelectDurableScene(mMapInfo.map_id)
        if not oNowScene:ValidLeave(oPlayer,oScene) then
            return
        end
        if not oScene:ValidEnter(oPlayer) then
            return
        end
        if oScene then
            if not is_release(self) then
                local mPos = {x = iTargetX, y = iTargetY }
                self:DoTransfer(oPlayer, oScene:GetSceneId(), mPos)
            end
        end
    end)
end

function CSceneMgr:TransToLeader(oPlayer,iLeader)
    local oWorldMgr = global.oWorldMgr
    local oLeader = oWorldMgr:GetOnlinePlayerByPid(iLeader)
    if not oLeader then
        return
    end
    local oLeaderNowScene = oLeader.m_oActiveCtrl:GetNowScene()
    if not oLeaderNowScene then
        return
    end

    local iScene = oLeaderNowScene:GetSceneId()
    local oNowScene = oPlayer.m_oActiveCtrl:GetNowScene()
    local mLeaderNowPos = oLeader.m_oActiveCtrl:GetNowPos()
    if oNowScene:GetSceneId() == iScene then
        local iPid = oPlayer:GetPid()
        local mData = {
            x = mLeaderNowPos.x,
            y = mLeaderNowPos.y,
            face_x = mLeaderNowPos.face_x,
            face_y = mLeaderNowPos.face_y
        }
        oLeaderNowScene:SetPlayerPos(iPid,mData)
    else
        self:EnterScene(oPlayer, iScene, {pos=mLeaderNowPos})
    end
end

function CSceneMgr:QueryPos(pid,func)
    local oWorldMgr = global.oWorldMgr
    local oLeader = oWorldMgr:GetOnlinePlayerByPid(pid)
    if not oLeader then
        return
    end
    local oNowScene = oLeader.m_oActiveCtrl:GetNowScene()
    if  not oNowScene then
        return
    end
    oNowScene:QueryRemote("player_pos",{pid=pid},function (mRecord,mData)
        local m = mData.data
        if not m then
            return
        end
        func(m)
    end)
end

function CSceneMgr:FindMapScene(oPlayer, iMapId)
    local oScene
    local sVirtual = table_get_depth(res, {"daobiao", "map", iMapId, "virtual_game"})
    if not sVirtual or sVirtual == "" then
        oScene = self:SelectDurableScene(iMapId)
    else
        oScene = oPlayer:GetVirtualScene(iMapId,sVirtual)
    end
    return oScene
end

function CSceneMgr:TryTransTargetScene(oPlayer, oScene, oNowScene)
    if not oNowScene:ValidLeave(oPlayer,oScene) then
        return
    end
    if not oScene:ValidEnter(oPlayer) then
        return
    end
    self:DoTransfer(oPlayer, oScene:GetSceneId())
    return true
end

function CSceneMgr:SendAutoFindPath(oPlayer, iMapId, iX, iY, npcid, iAutoType, iFuncType, iCallBackSessionIdx)
    local mNet = {}
    mNet["map_id"] = iMapId
    mNet["pos_x"] = math.floor(geometry.Cover(iX))
    mNet["pos_y"] = math.floor(geometry.Cover(iY))
    mNet["npcid"] = npcid
    mNet["autotype"] = iAutoType
    mNet["functype"] = iFuncType -- 功能type，主要为前端解析，服务于不同玩法
    mNet["callback_sessionidx"] = iCallBackSessionIdx
    oPlayer:Send("GS2CAutoFindPath", mNet)
end

function CSceneMgr:TargetSceneAutoFindPath(oPlayer, oScene, iX, iY, npcid, iAutoType, iFuncType, iCallBackSessionIdx)
    iAutoType = iAutoType or 1
    if oPlayer:IsFixed() then
        return
    end
    if not oPlayer:IsSingle() and not oPlayer:IsTeamLeader() then
        return
    end
    local oNowScene = oPlayer.m_oActiveCtrl:GetNowScene()
    if iAutoType == 1 and oScene ~= oNowScene then
        if not self:TryTransTargetScene(oPlayer, oScene, oNowScene) then
            return
        end
    end
    local iMapId = oScene:MapId()
    self:SendAutoFindPath(oPlayer, iMapId, iX, iY, npcid, iAutoType, iFuncType, iCallBackSessionIdx)
    return true
end

function CSceneMgr:SceneAutoFindPath(pid, iMapId, iX, iY, npcid, iAutoType, iFuncType, iCallBackSessionIdx)
    local oWorldMgr = global.oWorldMgr
    local oPlayer = oWorldMgr:GetOnlinePlayerByPid(pid)
    if not oPlayer then
        return
    end
    iAutoType = iAutoType or 1
    if oPlayer:IsFixed() then
        return
    end
    if not oPlayer:IsSingle() and not oPlayer:IsTeamLeader() then
        return
    end
    local oNowScene = oPlayer.m_oActiveCtrl:GetNowScene()
    local iNowMapId = oNowScene:MapId()
    if iAutoType == 1 and iNowMapId ~= iMapId then
        local oScene = self:FindMapScene(oPlayer, iMapId)
        if not oScene then
            return
        end
        if not self:TryTransTargetScene(oPlayer, oScene, oNowScene) then
            return
        end
    end
    self:SendAutoFindPath(oPlayer, iMapId, iX, iY, npcid, iAutoType, iFuncType, iCallBackSessionIdx)
    return true
end

function CSceneMgr:GetFlyData(iMapId)
    local res = require "base.res"
    local mData = assert(res["daobiao"]["map"][iMapId], string.format("GetFlyData fail %d", iMapId))
    local iX,iY = table.unpack(mData["fly_pos"])
    iX = iX or 10
    iY = iY or 10
    return iX,iY
end

function CSceneMgr:RemoteEvent(sEvent, mData)
    local oWorldMgr = global.oWorldMgr
    if sEvent == "player_enter_scene" then
        local iPid = mData.pid
        local oScenePlayerShareObj = mData.scene_player_share
        local oPlayer = oWorldMgr:GetOnlinePlayerByPid(iPid)
        if oPlayer then
            oPlayer.m_oActiveCtrl:SetSceneShareObj(oScenePlayerShareObj)
        end
    elseif sEvent == "player_leave_scene" then
        local iPid = mData.pid
        local iSceneId = mData.scene_id
        local iEid = mData.eid
        local oPlayer = oWorldMgr:GetOnlinePlayerByPid(iPid)
        if oPlayer then
            local oScene = oPlayer.m_oActiveCtrl:GetNowScene()
            if oScene and iSceneId == oScene:GetSceneId() then
                oPlayer.m_oActiveCtrl:ClearSceneShareObj()
            end
        end
        local oScene = self:GetScene(iSceneId)
        if oScene and iEid then
            oScene.m_oIDPool:Free(iEid)
        end
    elseif sEvent == "team_leave_scene" then
        local iSceneId = mData.scene_id
        local iEid = mData.eid
        local oScene = self:GetScene(iSceneId)
        if oScene and iEid then
            oScene.m_oIDPool:Free(iEid)
        end
    elseif sEvent == "npc_leave_scene" then
        local iSceneId = mData.scene_id
        local iEid = mData.eid
        local oScene = self:GetScene(iSceneId)
        if oScene and iEid then
            oScene.m_oIDPool:Free(iEid)
        end
    end

    return true
end

function CSceneMgr:CreateSceneTeam(oPlayer)
    local oNowScene = oPlayer.m_oActiveCtrl:GetNowScene()
    if not oNowScene then
        return
    end
    oNowScene:CreateSceneTeam(oPlayer)
end

function CSceneMgr:RemoveSceneTeam(oPlayer, iTeamId)
    local oNowScene = oPlayer.m_oActiveCtrl:GetNowScene()
    if not oNowScene then
        return
    end
    oNowScene:RemoveSceneTeam(oPlayer, iTeamId)
end

function CSceneMgr:SyncSceneTeam(oPlayer)
    local oNowScene = oPlayer.m_oActiveCtrl:GetNowScene()
    if not oNowScene then
        return
    end
    oNowScene:SyncSceneTeam(oPlayer)
end

function CSceneMgr:GetEffectData(iSceneEffectId)
    -- TODO 读表返回场景特效显示默认配置
    return {}
end

function GetWaterWalkConfigData()
    local res = require "base.res"
    return table_get_depth(res, {"daobiao", "water_walk"}) or {}
end

local WATERWALK_ERR = {
    NO_WALK_ID = 1,       -- 踩水id无配置
    MAP_DIFFERENT = 2,    -- 场景不对
    POS_OUT_RANGE = 3,    -- 当前超出范围
    IS_WATER_WALKING = 4, -- 正在踩水
    NOT_LEADER = 5,       -- 非队长操作
}

function CSceneMgr:PlayerStartWaterWalk(oPlayer, iWaterWalkId)
    if oPlayer:IsSingle() then
        local bSucc, iErr = self:CanSinglePlayerStartWaterWalk(oPlayer, iWaterWalkId)
        if not bSucc then
            return
        end
        self:SinglePlayerStartWaterWalk(oPlayer, iWaterWalkId)
        return
    end
    local oTeam = oPlayer:HasTeam()
    if oTeam and oTeam:IsLeader(oPlayer:GetPid()) then
        local mMems = {}
        for _, iMem in ipairs(oTeam:GetTeamMember()) do
            local oMem = global.oWorldMgr:GetOnlinePlayerByPid(iMem)
            if oMem then
                mMems[iMem] = oMem
                local bSucc, iErr = self:CanSinglePlayerStartWaterWalk(oMem, iWaterWalkId)
                if not bSucc then
                    return
                end
            end
        end
        for iMem, oMem in pairs(mMems) do
            if oMem then
                self:SinglePlayerStartWaterWalk(oMem, iWaterWalkId)
            end
        end
        return
    end
end

function CSceneMgr:CanSinglePlayerStartWaterWalk(oPlayer, iWaterWalkId)
    local mWaterWalkData = GetWaterWalkConfigData()
    local mWConfig = mWaterWalkData[iWaterWalkId]
    if not mWConfig then
        return false, WATERWALK_ERR.NO_WALK_ID
    end
    local oScene = oPlayer.m_oActiveCtrl:GetNowScene()
    if oScene:MapId() ~= mWConfig.map then
        return false, WATERWALK_ERR.MAP_DIFFERENT
    end
    local mCurPos = oPlayer.m_oActiveCtrl:GetNowPos()
    if math.abs(mCurPos.x - mWConfig.start_x) > mWConfig.radius
        or math.abs(mCurPos.y - mWConfig.start_y) > mWConfig.radius then
        return false, WATERWALK_ERR.POS_OUT_RANGE
    end
    return true
end

function CSceneMgr:SinglePlayerStartWaterWalk(oPlayer, iWaterWalkId)
    local mWaterWalkData = GetWaterWalkConfigData()
    local mWConfig = mWaterWalkData[iWaterWalkId]
    assert(mWConfig, "check water_walk not configed, id:" .. iWaterWalkId)
    local mCurPos = oPlayer.m_oActiveCtrl:GetNowPos()
    local mStartPos = table_deep_copy(mCurPos)
    mStartPos.x = mWConfig.start_x
    mStartPos.y = mWConfig.start_y
    local mEndPos = table_deep_copy(mCurPos)
    mEndPos.x = mWConfig.dest_x
    mEndPos.y = mWConfig.dest_y
    local iCostTime = math.max(mWConfig.cost_time or 1, 1)
    local iNow = get_time()
    local oScene = oPlayer.m_oActiveCtrl:GetNowScene()
    oScene:PlayerAddWaterWalk(oPlayer, iNow, iNow + iCostTime / 1000, mStartPos, mEndPos)
    oPlayer:Send("GS2CWaterWalkSuccess",{})
end

function CSceneMgr:XunLuoChange(oPlayer, iType)
    local bStop = (iType == 0)
    if bStop then
        oPlayer.m_oTaskCtrl.m_oAnLeiCtrl:OnStopXunLuo()
    end
end

CScene = {}
CScene.__index = CScene
inherit(CScene, logic_base_cls())

function CScene:New(id, mInfo)
    local o = super(CScene).New(self)
    o.m_iSceneId = id
    o.m_iRemoteAddr = nil
    o.m_iMapId = mInfo.map_id
    o.m_bIsDurable = mInfo.is_durable
    o.m_bHasAnLei = mInfo.has_anlei
    o.m_lUrl = mInfo.url
    o.m_sSceneName = mInfo.scene_name
    o.m_oIDPool =  idpool.CIDPool:New(2)

    o.m_mPlayers = {}
    o.m_mNpc = {}
    o.m_mNpcEntity = {}
    o.m_mEffect = {}
    o.m_mEffectEntity = {}
    o.m_Callback={}
    o.m_mGMPlayers = {}

    if o.m_bHasAnLei then
        o.m_oAnLeiCtrl = NewAnLeiCtrl(id)
    end
    o:Init()
    return o
end

function CScene:Init()
    local iTime = 30*1000
    local oSceneMgr = global.oSceneMgr
    local iSceneId = self:GetSceneId()
    local fCallBack
    fCallBack = function ()
        self:DelTimeCb("_IDPoolProduce")
        local oScene = oSceneMgr:GetScene(iSceneId)
        if oScene then
            oScene.m_oIDPool:Produce()
        end
        self:AddTimeCb("_IDPoolProduce",iTime,fCallBack)
    end
    fCallBack()
end

function CScene:Release()
    self:ReleaseNpc()
    self:ReleaseEffect()
    baseobj_safe_release(self.m_oIDPool)

    self.m_mNpc = {}
    self.m_mNpcEntity = {}
    self.m_mEffect = {}
    self.m_mEffectEntity = {}
    self.m_Callback = {}

    interactive.Send(self.m_iRemoteAddr, "scene", "RemoveRemote", {scene_id = self.m_iSceneId})
    super(CScene).Release(self)
end

function CScene:ReleasePlayer()
    local oWorldMgr = global.oWorldMgr
    local oSceneMgr = global.oSceneMgr
    if not self:IsDurable() then
        for iPid,_ in pairs(self.m_mPlayers) do
            local oPlayer = oWorldMgr:GetOnlinePlayerByPid(iPid)
            if not oPlayer then
                goto continue
            end
            if oPlayer:IsSingle() then
                oSceneMgr:EnterDurableScene(oPlayer)
            elseif oPlayer:IsTeamLeader() then
                oSceneMgr:TeamEnterDurableScene(oPlayer)
            end
            ::continue::
        end
    end
    self.m_mPlayers = {}
end

function CScene:ReleaseNpc()
    local oNpcMgr = global.oNpcMgr
    for iNpc, _ in pairs(self.m_mNpc) do
        local oNpc = oNpcMgr:GetObject(iNpc)
        if oNpc then
            oNpcMgr:RemoveObject(iNpc)
            baseobj_safe_release(oNpc)
        end
    end
    self.m_mNpc = {}
end

function CScene:ReleaseEffect()
    for _, iEffect in pairs(table_key_list(self.m_mEffect)) do
        self:RemoveSceneEffect(iEffect)
    end
    self.m_mEffect = {}
end

function CScene:GetAllPlayerIds()
    return table_key_list(self.m_mPlayers)
end

function CScene:HasAnLei()
    return self.m_bHasAnLei
end

function CScene:GetTeamAllowed()
    local mInfo = self:GetTableInfo()
    return mInfo.team_allowed or 1
end

function CScene:IsTeamAllowed()
    local mInfo = self:GetTableInfo()
    if mInfo.team_allowed and mInfo.team_allowed ~= 1 then
        return false
    end
    return true
end

function CScene:IsDenyFly(oPlayer,iMapId)
    local sKey = "customfly"
    if self:HasCallback(sKey) then
        local bResult = self:Callback(sKey,{player = oPlayer,map = iMapId})
        return bResult
    end

    local mInfo = self:GetTableInfo()
    local iDenyFly = mInfo["deny_fly"] or 0
    local bFlag = iDenyFly ~= 0
    if bFlag then
        local sMsg = "此场景插翅难飞,仅能通过活动NPC处离开"
        global.oNotifyMgr:Notify(oPlayer:GetPid(), sMsg)
    end
    return bFlag
end

function CScene:GetNpcidByEid(iEid)
    return self.m_mNpcEntity[iEid]
end

function CScene:GetSceneId()
    return self.m_iSceneId
end

function CScene:GetTableInfo()
    return table_get_depth(res["daobiao"], self.m_lUrl)
end

function CScene:GetName()
    if self.m_sSceneName then
        return self.m_sSceneName
    end
    local mData = self:GetTableInfo()
    return mData["scene_name"]
end

function CScene:GetTransfers()
    if self:IsDurable() then
        local mMapInfo = res["daobiao"]["map"][self:MapId()]
        return mMapInfo["transfers"]
    end
end

function CScene:GetVirtualGame()
    local iMapId = self:MapId()
    return table_get_depth(res, {"daobiao", "map", iMapId, "virtual_game"})
end

function CScene:DispatchEntityId()
    local iEid = self.m_oIDPool:Gain()
    return iEid
end

function CScene:MapId()
    return self.m_iMapId
end

function CScene:IsDurable()
    return self.m_bIsDurable
end

function CScene:IsVirtual()
    return self.m_sType == "virtual"
end

function CScene:ValidJJC()
    local mInfo = self:GetTableInfo()
    local v = mInfo["jjc"] or 1
    return v == 1
end

function CScene:IsForbidTitleOp()
    local mInfo = self:GetTableInfo()
    local v = mInfo["forbid_title_op"] or 0
    return v == 1
end

function CScene:IsForbidFlyHorse()
    local mInfo = self:GetTableInfo()
    local v = mInfo["forbid_fly_horse"] or 0
    return v == 1
end

function CScene:ConfirmRemote()
    local oSceneMgr = global.oSceneMgr
    local iRemoteAddr = oSceneMgr:SelectRemoteScene()
    self.m_iRemoteAddr = iRemoteAddr
    interactive.Send(iRemoteAddr, "scene", "ConfirmRemote", {scene_id = self.m_iSceneId, map_id = self.m_iMapId})
end

function CScene:GetRemoteAddr()
    return self.m_iRemoteAddr
end

function CScene:ValidLeave(oPlayer,oScene)
    local iMapid = 0
    if oScene then
        iMapid = oScene:MapId()
    end
    if self:IsDenyFly(oPlayer,iMapid) then
        return false
    end
    return true
end

function CScene:ValidEnter(oPlayer)
    return true
end

function CScene:LeavePlayer(oPlayer, bLogout, iNewScene)
    if self:IsDurable() and bLogout then
        local mPos = oPlayer.m_oActiveCtrl:GetNowPos()
        oPlayer.m_oActiveCtrl:SetDurableSceneInfo(self.m_iMapId, mPos)
    end
    local iPid = oPlayer:GetPid()
    oPlayer.m_oActiveCtrl:ClearNowSceneInfo()
    self.m_mPlayers[iPid] = nil
    interactive.Send(self.m_iRemoteAddr, "scene", "LeavePlayer", {scene_id = self.m_iSceneId, pid = iPid})
    oPlayer:SyncTeamSceneInfo()

    self:TriggerEvent(gamedefines.EVENT.PLAYER_LEAVE_SCENE, {player = oPlayer, scene = self, logout=bLogout, new_scene=iNewScene})

    oPlayer.m_iTeamAllowed = nil
    if oPlayer:HasTeam() then
        local oTeamMgr = global.oTeamMgr
        oTeamMgr:UpdatePlayer(oPlayer)
    end
    if self:HasAnLei() then
        self.m_oAnLeiCtrl:Del(iPid)
    end
    -- if oPlayer.m_oTaskCtrl.m_oAnLeiCtrl:ValidTriggerAnlei(self.m_iMapId) then
    --     oPlayer.m_oTaskCtrl.m_oAnLeiCtrl:DelPos(iPid) -- stop? 可以交给UpdatePos去做，虽然不可能是重进场
    -- end
    return true
end

function CScene:LeaveGMPlayer(oPlayer)
    local iPid = oPlayer:GetPid()
    if self.m_mGMPlayers[iPid] then
        self.m_mGMPlayers[iPid] = nil
        local mData = {
            scene_id = self.m_iSceneId,
            pid = iPid,
        }
        interactive.Send(self.m_iRemoteAddr, "scene", "LeaveGMPlayer", mData)
    end
end

function CScene:OnSyncPos(oPlayer, mCurPosInfo)
    local mPos = gamedefines.RecoverPos(mCurPosInfo)
    oPlayer.m_oActiveCtrl:SetNowSceneInfo({
        now_scene = self.m_iSceneId,
        now_pos = mPos,
    })
    if self:IsDurable() then
        oPlayer.m_oActiveCtrl:SetDurableSceneInfo(self.m_iMapId, mPos)
    end
    if self:HasAnLei() then
        self.m_oAnLeiCtrl:Update(oPlayer:GetPid(), {x = mCurPosInfo.x, y = mCurPosInfo.y}, {})
    end
    global.oTaskMgr:UpdatePosForAnlei(oPlayer, self.m_iMapId, {x = mCurPosInfo.x,y = mCurPosInfo.y}, {})
end

function CScene:SyncPlayerInfo(oPlayer, mArgs)
    local iEid = self.m_mPlayers[oPlayer:GetPid()]
    if iEid then
        interactive.Send(self.m_iRemoteAddr, "scene", "SyncPlayerInfo", {scene_id = self.m_iSceneId, eid = iEid, args = mArgs})
    end
end

function CScene:EnterPlayer(oPlayer, mPos, iFromSceneId)
    local oOldScene = oPlayer.m_oActiveCtrl:GetNowScene()
    if oOldScene and oOldScene:GetSceneId() == self.m_iSceneId then
        record.error(debug.traceback())
    end
    oPlayer.m_oActiveCtrl:SetNowSceneInfo({
        now_scene = self.m_iSceneId,
        now_pos = mPos,
    })
    if self:IsDurable() then
        oPlayer.m_oActiveCtrl:SetDurableSceneInfo(self.m_iMapId, mPos)
    end
    oPlayer.m_iTeamAllowed = self:GetTeamAllowed()
    if oPlayer:HasTeam() then
        local oTeamMgr = global.oTeamMgr
        oTeamMgr:UpdatePlayer(oPlayer)
    end

    local iEid = self:DispatchEntityId()
    self.m_mPlayers[oPlayer:GetPid()] = iEid
    oPlayer:Send("GS2CShowScene", {scene_id = self.m_iSceneId, scene_name = self:GetName(), map_id = self:MapId(), x=math.floor(geometry.Cover(mPos.x)), y=math.floor(geometry.Cover(mPos.y))})

    local iPid = oPlayer:GetPid()
    local mData = {
        scene_id = self.m_iSceneId,
        eid = iEid,
        data = oPlayer:PackSceneInfo(),
        pid = iPid,
        pos = mPos,
        walk_speed = oPlayer:GetWalkSpeed(),
    }
    interactive.Send(self.m_iRemoteAddr, "scene", "EnterPlayer", mData)
    oPlayer:SyncTeamSceneInfo()

    if self:HasAnLei() then
        self.m_oAnLeiCtrl:Add(oPlayer:GetPid(), {x = mPos.x, y = mPos.y})
    end
    global.oTaskMgr:ResetPosForAnlei(oPlayer)
    self:TriggerEvent(gamedefines.EVENT.PLAYER_ENTER_SCENE, {player = oPlayer, scene = self, from_scene = iFromSceneId})

    return true
end

function CScene:EnterGMPlayer(oPlayer, mPos)
    local iEid = self:DispatchEntityId()
    self.m_mGMPlayers[oPlayer:GetPid()] = iEid
    local mNet = {
        scene_id = self.m_iSceneId,
        scene_name = self:GetName(),
        map_id = self:MapId(),
        x = math.floor(geometry.Cover(mPos.x)),
        y = math.floor(geometry.Cover(mPos.y)),
    }
    oPlayer:Send("GS2CShowScene", mNet)

    local mData = {
        scene_id = self.m_iSceneId,
        eid = iEid,
        data = oPlayer:PackSceneInfo(),
        pid = oPlayer:GetPid(),
        pos = mPos,
        walk_speed = oPlayer:GetWalkSpeed(),
    }
    interactive.Send(self.m_iRemoteAddr, "scene", "EnterGMPlayer", mData)
end

function CScene:ReEnterPlayer(oPlayer)
    local mNowPos = oPlayer.m_oActiveCtrl:GetNowPos()
    oPlayer:Send("GS2CShowScene", {scene_id = self.m_iSceneId, scene_name = self:GetName(), map_id = self:MapId(), x=math.floor(geometry.Cover(mNowPos.x)), y=math.floor(geometry.Cover(mNowPos.y))})
    interactive.Send(self.m_iRemoteAddr, "scene", "ReEnterPlayer", {scene_id = self.m_iSceneId, pid = oPlayer:GetPid()})
    self:TriggerEvent(gamedefines.EVENT.PLAYER_REENTER_SCENE, {player = oPlayer, scene = self})
    return true
end

-- function CScene:ReEnterXYPlayer(oPlayer, rX, rY)
--     oPlayer:Send("GS2CShowScene", {scene_id = self.m_iSceneId, scene_name = self:GetName(), map_id = self:MapId(), x = math.floor(geometry.Cover(rX)), y = math.floor(geometry.Cover(rY))})
--     -- interactive.Send(self.m_iRemoteAddr, "scene", "ReEnterPlayerXY", {scene_id = self.m_iSceneId, pid = oPlayer:GetPid(), x = rX, y = rY})
--     interactive.Send(self.m_iRemoteAddr, "scene", "Forward", {pid = oPlayer:GetPid(), scene_id = self.m_iSceneId, cmd = sCmd, data = mData})
--     self:TriggerEvent(gamedefines.EVENT.PLAYER_REENTER_SCENE, {player = oPlayer, scene = self})
--     return true
-- end

function CScene:NotifyDisconnected(oPlayer)
    interactive.Send(self.m_iRemoteAddr, "scene", "NotifyDisconnected", {scene_id = self.m_iSceneId, pid = oPlayer:GetPid()})
    return true
end

function CScene:SendCurrentChat(pid, mData)
    interactive.Send(self.m_iRemoteAddr, "scene", "SceneAoiChat", {scene_id = self.m_iSceneId, pid = pid, net = mData})
    return true
end

function CScene:NotifyEnterWar(oPlayer)
    interactive.Send(self.m_iRemoteAddr, "scene", "NotifyEnterWar", {scene_id = self.m_iSceneId, pid = oPlayer:GetPid()})
    return true
end

function CScene:NotifyLeaveWar(oPlayer)
    interactive.Send(self.m_iRemoteAddr, "scene", "NotifyLeaveWar", {scene_id = self.m_iSceneId, pid = oPlayer:GetPid()})
    return true
end

function CScene:Forward(sCmd, iPid, mData)
    interactive.Send(self.m_iRemoteAddr, "scene", "Forward", {pid = iPid, scene_id = self.m_iSceneId, cmd = sCmd, data = mData})
    return true
end

function CScene:QueryRemote(sType, mData, func)
    interactive.Request(self.m_iRemoteAddr, "scene", "Query", {scene_id = self.m_iSceneId, type = sType, data = mData}, func)
end

function CScene:SetPlayerPos(iPid, mData)
    interactive.Send(self.m_iRemoteAddr, "scene", "SetPlayerPos", {pid = iPid, scene_id = self.m_iSceneId, data = mData})
end

function CScene:EnterNpc(oNpc)
    local iEid = self:DispatchEntityId()
    self.m_mNpc[oNpc.m_ID] = iEid
    self.m_mNpcEntity[iEid] = oNpc.m_ID
    local mData = oNpc:PackSceneInfo()
    local mPos = oNpc:PosInfo()
    interactive.Send(self.m_iRemoteAddr, "scene", "EnterNpc", {scene_id = self.m_iSceneId, eid = iEid,pos=mPos,data=mData})
end

function CScene:RemoveSceneNpc(npcid)
    local iEid = self.m_mNpc[npcid]
    assert(iEid,string.format("RemoveSceneNpc npcid err:%d",npcid))
    self.m_mNpc[npcid] = nil
    self.m_mNpcEntity[iEid] = nil
    interactive.Send(self.m_iRemoteAddr,"scene","RemoveSceneNpc",{scene_id = self.m_iSceneId,eid=iEid})
end

function CScene:SyncNpcInfo(oNpc,mArgs)
    local iEid = self.m_mNpc[oNpc.m_ID]
    if iEid then
        interactive.Send(self.m_iRemoteAddr, "scene", "SyncNpcInfo", {scene_id = self.m_iSceneId, eid = iEid, args = mArgs})
    end
end

function CScene:EnterEffect(oSceneEffect)
    local iEid = self:DispatchEntityId()
    local iObjId = oSceneEffect:ID()
    local iEffId = oSceneEffect:EffectId()
    self.m_mEffect[iObjId] = iEid
    self.m_mEffectEntity[iEid] = iObjId
    local mData = oSceneEffect:PackSceneInfo()
    local mPos = oSceneEffect:PosInfo()
    interactive.Send(self.m_iRemoteAddr, "scene", "EnterEffect", {scene_id = self.m_iSceneId, eid = iEid, effect_id = iEffId, pos = mPos, data = mData})
end

function CScene:RemoveSceneEffect(iObjId)
    local iEid = self.m_mEffect[iObjId]
    assert(iEid, string.format("RemoveSceneEffect iObjId err:%d", iObjId))
    self.m_mEffect[iObjId] = nil
    self.m_mEffectEntity[iEid] = nil
    interactive.Send(self.m_iRemoteAddr, "scene", "RemoveSceneEffect", {scene_id = self.m_iSceneId, eid = iEid})
end

function CScene:NpcEnterWar(oNpc)
    local iEid = self.m_mNpc[oNpc.m_ID]
    if iEid then
        interactive.Send(self.m_iRemoteAddr, "scene", "NpcEnterWar", {scene_id = self.m_iSceneId, eid = iEid})
    end
end

function CScene:NpcLeaveWar(oNpc)
    local iEid = self.m_mNpc[oNpc.m_ID]
    if iEid then
        interactive.Send(self.m_iRemoteAddr, "scene", "NpcLeaveWar", {scene_id = self.m_iSceneId, eid = iEid})
    end
end

function CScene:CreateSceneTeam(oPlayer)
    local iEid = self:DispatchEntityId()
    local iTeamID = oPlayer:TeamID()
    local mMem = oPlayer:SceneTeamMember()
    local mShort = oPlayer:SceneTeamShort()
    interactive.Send(self.m_iRemoteAddr,"scene","CreateSceneTeam",{
        scene_id = self.m_iSceneId, team_id = iTeamID, eid = iEid,
        mem = mMem, short = mShort
    })
end

function CScene:RemoveSceneTeam(oPlayer,iTeamId)
   interactive.Send(self.m_iRemoteAddr,"scene","RemoveSceneTeam",{scene_id = self.m_iSceneId,team_id = iTeamId})
end

function CScene:SyncSceneTeam(oPlayer)
    local iTeamID = oPlayer:TeamID()
    if not iTeamID then
        return
    end
    local mMem = oPlayer:SceneTeamMember()
    local mShort = oPlayer:SceneTeamShort()

    interactive.Send(self.m_iRemoteAddr,"scene","UpdateSceneTeam",{
        scene_id = self.m_iSceneId,team_id = iTeamID,
        mem = mMem, short = mShort
    })
end

function CScene:SceneAoiEffect(oPlayer, iEffect)
    interactive.Send(self.m_iRemoteAddr, "scene", "SceneAoiEffect", {scene_id = self.m_iSceneId, pid = oPlayer:GetPid(), net = {effect = iEffect}})
end

function CScene:PlayerAddWaterWalk(oPlayer, iStartTime, iEndTime, mStartPos, mEndPos)
    interactive.Send(self.m_iRemoteAddr, "scene", "PlayerAddWaterWalk", {scene_id = self.m_iSceneId, pid = oPlayer:GetPid(), start_time = iStartTime, end_time = iEndTime, start_pos = mStartPos, end_pos = mEndPos})
end

function CScene:SetCallback(sKey, fCallback)
    self.m_Callback[sKey] = fCallback
end

function CScene:Callback(sKey, mInfo)
    local fCallback = self.m_Callback[sKey]
    if fCallback then
        local mData = fCallback(mInfo)
        return mData
    end
end

function CScene:HasCallback(sKey)
    return self.m_Callback[sKey]
end

function CScene:BroadcastMessage(sMessage, mData, mExclude)
    local mNet = {
        message = sMessage,
        data = mData,
        exclude = mExclude,
        scene_id = self:GetSceneId(),
    }
    interactive.Send(self.m_iRemoteAddr, "scene", "BroadcastMessage", mNet)
end


CAnLeiCtrl = {}
CAnLeiCtrl.__index = CAnLeiCtrl
inherit(CAnLeiCtrl, logic_base_cls())

function CAnLeiCtrl:New(iScene)
    local o = super(CAnLeiCtrl).New(self)
    o.m_iSceneId = iScene
    o.m_mPlayerInfo = {}
    return o
end

function CAnLeiCtrl:Update(iPid, mPosInfo, mExtra)
    mExtra = mExtra or {}
    local iTime = get_time()
    local m = self.m_mPlayerInfo[iPid]
    if m then
        if m.x ~= mPosInfo.x or m.y ~= mPosInfo.y then
            m.x = mPosInfo.x
            m.y = mPosInfo.y
            m.time = iTime
        end
    end
end

function CAnLeiCtrl:Add(iPid, mPosInfo)
    local iTime = get_time()
    self.m_mPlayerInfo[iPid] = {x = mPosInfo.x, y = mPosInfo.y, time = iTime, no_trigger_cnt = 0}

    local iScene = self.m_iSceneId
    local sFlag = string.format("CheckTriggerAnLei%d", iPid)
    local f1
    f1 = function ()
        local oSceneMgr = global.oSceneMgr
        local oScene = oSceneMgr:GetScene(iScene)
        local oAnLeiCtrl = oScene.m_oAnLeiCtrl
        if oAnLeiCtrl then
            oAnLeiCtrl:DelTimeCb(sFlag)
            oAnLeiCtrl:AddTimeCb(sFlag, 5*1000, f1)
            oAnLeiCtrl:CheckTriggerAnLei(iPid)
        end
    end
    self:DelTimeCb(sFlag)
    self:AddTimeCb(sFlag, 5*1000, f1)
end

function CAnLeiCtrl:Del(iPid)
    self.m_mPlayerInfo[iPid] = nil
    local sFlag = string.format("CheckTriggerAnLei%d", iPid)
    self:DelTimeCb(sFlag)
end

function CAnLeiCtrl:CheckTriggerAnLei(iPid)
    local oWorldMgr = global.oWorldMgr
    local oPlayer = oWorldMgr:GetOnlinePlayerByPid(iPid)
    local iTime = get_time()
    if oPlayer and (oPlayer:IsSingle() or oPlayer:IsTeamLeader()) then
        local m = self.m_mPlayerInfo[iPid]
        if m and (iTime - m.time <= 3) then
            local iRan = 50
            if m.no_trigger_cnt >=1 then
                iRan = 100
            end
            if math.random(1, 100) <= iRan then
                m.no_trigger_cnt = 0
                self:TriggerAnLei(oPlayer)
            else
                m.no_trigger_cnt = m.no_trigger_cnt + 1
            end
        end
    end
end

function CAnLeiCtrl:TriggerAnLei(oPlayer)
    local oHuodongMgr = global.oHuodongMgr
    local oTrapMine = oHuodongMgr:GetHuodong("trapmine")
    local oSceneMgr = global.oSceneMgr
    local oScene = oSceneMgr:GetScene(self.m_iSceneId)
    if oTrapMine and oScene then
        oTrapMine:Trigger(oPlayer, oScene:MapId())
    end
end
