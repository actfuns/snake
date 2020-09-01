-- 场景为虚场景，需要动态平衡，防止一个场景人太多
-- TODO 【优化】活动进行中的玩家，若出现场景人数太少的情况，考虑进行动态合并（玩家移动场景，多余场景回收），策划方案要求仅处理人数低于容纳值一半的场景，进行合并

local global = require "global"
local res = require "base.res"
local gamedefines = import(lualib_path("public.gamedefines"))
local hfdmdefines = import(service_path("huodong.hfdm.defines"))

function GetSceneData(iSceneIdx)
    return table_get_depth(res, {"daobiao", "huodong", "hfdm", "scene", iSceneIdx})
end

function GetNpcConfigs()
    return table_get_depth(res, {"daobiao", "huodong", "hfdm", "npc"})
end

function GetHuodong()
    return global.oHuodongMgr:GetHuodong("hfdm")
end

function GetSceneCtrl()
    local oHuodong = GetHuodong()
    if oHuodong then
        return oHuodong.m_oSceneCtrl
    end
end

function GetRoom(iRoomNo)
    local oSceneCtrl = GetSceneCtrl()
    if oSceneCtrl then
        return oSceneCtrl:GetRoomByNo(iRoomNo)
    end
end

function NewRoom(iIdx, iRoomNo)
    return CRoom:New(iIdx, iRoomNo)
end

CSceneCtrl = {}
CSceneCtrl.__index = CSceneCtrl
inherit(CSceneCtrl, logic_base_cls())
-- 一起开题，一起公布答案，发奖走独立心跳

function CSceneCtrl:New(sHuodongName)
    local o = super(CSceneCtrl).New(self)
    o.m_sHuodongName = sHuodongName
    -- {iRoomNo = <CRoom>}
    o.m_mRooms = {} -- 房间场景依次活动时间相位平移
    -- {iPid = iRoomNo}
    o.m_mPlayerRegRoom = {} -- 索引玩家所在房间
    return o
end

function CSceneCtrl:CreateRoom()
    local iIdx = 1001
    local iRoomNo = table_count(self.m_mRooms) + 1
    local oRoom = NewRoom(iIdx, iRoomNo)
    self.m_mRooms[iRoomNo] = oRoom
    return oRoom
end

function CSceneCtrl:GetPlayerRoomsInfo()
    return self.m_mPlayerRegRoom
end

function CSceneCtrl:GetPlayerInRoom(iPid)
    return self.m_mPlayerRegRoom[iPid]
end

function CSceneCtrl:RegPlayerRoom(iPid, iRoomNo)
    self.m_mPlayerRegRoom[iPid] = iRoomNo
end

function CSceneCtrl:UnRegPlayerRoom(iPid)
    self.m_mPlayerRegRoom[iPid] = nil
end

function CSceneCtrl:GetRoomByNo(iRoomNo)
    return self.m_mRooms[iRoomNo]
end

function CSceneCtrl:GetAbleRoom(iPid)
    local iRegRoomNo = self.m_mPlayerRegRoom[iPid]
    if iRegRoomNo then
        return self.m_mRooms[iRegRoomNo]
    end
    local oHitRoom
    local iHitPlayerCnt = 0
    for iRoomNo, oRoom in pairs(self.m_mRooms) do
        -- TODO 考虑算法优化
        local iPlayerCnt = oRoom:GetOnlineCnt()
        if iPlayerCnt == 0 then
            if not oHitRoom then -- 只有没找到房间才放到无人的房间
                oHitRoom = oRoom
            end
        elseif iPlayerCnt < hfdmdefines.MAX_ROOM_PLAYER_CNT then
            if iHitPlayerCnt == 0 or iPlayerCnt < iHitPlayerCnt then
                oHitRoom = oRoom
                iHitPlayerCnt = iPlayerCnt
            end
        end
        ::continue::
    end
    if oHitRoom then
        return oHitRoom
    end
    return self:CreateRoom()
end

function CSceneCtrl:InRoom(oPlayer)
    local iPid = oPlayer:GetPid()
    local iRoomNo = self.m_mPlayerRegRoom[iPid]
    local oRoom = self:GetRoomByNo(iRoomNo)
    if not oRoom then
        return
    end
    local oNowScene = oPlayer.m_oActiveCtrl:GetNowScene()
    if oRoom:GetSceneId() ~= oNowScene:GetSceneId() then
        return
    end
    return oRoom
end

function CSceneCtrl:LeaveRoom(oPlayer)
    local oRoom = self:InRoom(oPlayer)
    if not oRoom then
        return
    end
    global.oSceneMgr:EnterDurableScene(oPlayer)
    return true
end

-- function CSceneCtrl:TickAllRooms(sTickKey, iTickPhase)
--     local sTickRoomsKey = "tick_rooms_" .. sTickKey
--     if not iTickPhase then iTickPhase = 0 end -- 相位
--     self:DelTimeCb(sTickRoomsKey)
--     self:AddTimeCb(sTickRoomsKey, hfdmdefines.DEAL_TICK_MS, function()
--         local oSceneCtrl = GetSceneCtrl()
--         if oSceneCtrl then
--             oSceneCtrl:DoTickRooms(sTickKey, iTickPhase)
--         end
--     end)
-- end

-- function CSceneCtrl:DoTickRooms(sTickKey, iTickPhase)
--     -- 泛型的function和dealList
--     local iStartRoomNo = self.m_iTickRoomsCnt * iTickPhase
--     local iEndRoomNo = iStartRoomNo + self.m_iTickRoomsCnt - 1
--     for iNo = iStartRoomNo, iEndRoomNo do
--         local oRoom = self.m_m
--     end
-- end

function CSceneCtrl:RecycleAllRooms()
    -- TODO 可能需要心跳分片，一个场景里人可能很多
    for _, iRoomNo in pairs(table_key_list(self.m_mRooms)) do
        self:RemoveRoom(iRoomNo)
    end
    -- self.m_mPlayerRegRoom = {}
end

function CSceneCtrl:RemoveRoom(iRoomNo)
    local oRoom = self.m_mRooms[iRoomNo]
    if oRoom then
        oRoom:RemoveScene()
        baseobj_delay_release(oRoom)
    end
    self.m_mRooms[iRoomNo] = nil
end

---------------------------------
CRoom = {}
CRoom.__index = CRoom
inherit(CRoom, logic_base_cls())

function CRoom:New(iIdx, iRoomNo)
    local o = super(CRoom).New(self)
    o.m_mHDNpcs = {}
    o:Init(iIdx, iRoomNo)
    return o
end

function CRoom:Init(iIdx, iRoomNo)
    self:InitScene(iIdx, iRoomNo)
    self:InitNpc()
end

function CRoom:InitNpc()
    local oHuodong = GetHuodong()
    local mNpcConfigs = GetNpcConfigs()
    local iSceneId = self.m_iScene
    local oScene = global.oSceneMgr:GetScene(iSceneId)
    local iSceneMap = oScene:MapId()
    for npctype, mInfo in pairs(mNpcConfigs) do
        if mInfo.mapid == iSceneMap then
            local oHDNpc = oHuodong:CreateTempNpc(npctype)
            self.m_mHDNpcs[oHDNpc:ID()] = npctype
            oHuodong:Npc_Enter_Scene(oHDNpc, iSceneId)
        end
    end
end

function CRoom:InitScene(iIdx, iRoomNo)
    local mInfo = GetSceneData(iIdx)
    local mData ={
        map_id = mInfo.map_id,
        team_allowed = mInfo.team_allowed,
        deny_fly = mInfo.deny_fly,
        is_durable = mInfo.is_durable == 1,
        has_anlei = mInfo.has_anlei == 1,
        url = {"huodong", "hfdm", "scene", iIdx},
    }
    if iRoomNo > 1 then
        mData.scene_name = mInfo.scene_name .. "-" .. iRoomNo
    else
        mData.scene_name = mInfo.scene_name
    end
    local oScene = global.oSceneMgr:CreateVirtualScene(mData)
    oScene.m_sType = "virtual"
    oScene.m_HDName = self.m_sHuodongName
    oScene.m_iIdx = iIdx

    local funcEnter = function(iEvent, mData)
        local oRoom = GetRoom(iRoomNo)
        if oRoom then
            oRoom:OnEnterRoom(mData, false)
        end
    end
    oScene:AddEvent(self, gamedefines.EVENT.PLAYER_ENTER_SCENE, funcEnter)
    local funcReEnter = function(iEvent, mData)
        local oRoom = GetRoom(iRoomNo)
        if oRoom then
            oRoom:OnEnterRoom(mData, true)
        end
    end
    oScene:AddEvent(self, gamedefines.EVENT.PLAYER_REENTER_SCENE, funcReEnter)
    local funcLeave = function(iEvent, mData)
        local oRoom = GetRoom(iRoomNo)
        if oRoom then
            oRoom:OnLeaveRoom(mData)
        end
    end
    oScene:AddEvent(self, gamedefines.EVENT.PLAYER_LEAVE_SCENE, funcLeave)

    local iSceneId = oScene:GetSceneId()
    self.m_iScene = iSceneId
    -- {players={pid:0/1}, ...}
    self.m_mPlayers = {}
    self.m_iOnlineCnt = 0
    self.m_iRoomNo = iRoomNo
end

function CRoom:GetSceneId()
    return self.m_iScene
end

function CRoom:EnterScene(oPlayer, mPos)
    global.oSceneMgr:DoTransfer(oPlayer, self.m_iScene, mPos)
end

function CRoom:RemoveScene()
    local oHuodong = GetHuodong()
    for npcid, npctype in pairs(self.m_mHDNpcs) do
        local oNpc = oHuodong:GetNpcObj(npcid)
        if oNpc then
            oHuodong:RemoveTempNpc(oNpc)
        end
    end
    local iSceneId = self.m_iScene
    local oScene = global.oSceneMgr:GetScene(iSceneId)
    local oSceneCtrl = GetSceneCtrl()
    if oSceneCtrl then
        for iPid,_ in pairs(oScene.m_mPlayers) do
            local oPlayer = global.oWorldMgr:GetOnlinePlayerByPid(iPid)
            if oPlayer then
                oSceneCtrl:LeaveRoom(oPlayer)
                -- local oHuodong = GetHuodong()
                -- if oHuodong then
                --     oHuodong:OnLeaveRoom(oPlayer)
                -- end
            end
            oSceneCtrl:UnRegPlayerRoom(iPid)
        end
    end
    -- oScene:ReleasePlayer()
    -- oScene:ReleaseNpc()
    -- oScene:ReleaseEffect()
    global.oSceneMgr:RemoveVirtualScene(iSceneId)
end

function CRoom:OnEnterRoom(mData, bReEnter)
    local oPlayer = mData.player
    if not bReEnter then
        local iFromSceneId = mData.from_scene
        local oScene = mData.scene
        if oScene:GetSceneId() == iFromSceneId then
            bReEnter = true
        end
    end
    if not bReEnter then
        local iPid = oPlayer:GetPid()
        self:RecSceneAddPlayer(iPid)
        local oSceneCtrl = GetSceneCtrl()
        if oSceneCtrl then
            oSceneCtrl:RegPlayerRoom(iPid, self.m_iRoomNo)
        end
    end
    local oHuodong = GetHuodong()
    if oHuodong then
        oHuodong:OnEnterRoom(oPlayer, bReEnter, oScene, iFromSceneId)
    end
end

function CRoom:RecSceneAddPlayer(iPid)
    if self.m_mPlayers[iPid] ~= 1 then
        self.m_mPlayers[iPid] = 1
        self.m_iOnlineCnt = self.m_iOnlineCnt + 1
    end
end

function CRoom:OnLeaveRoom(mData)
    local oPlayer, oScene, iNewScene, bLogout = mData.player, mData.scene, mData.new_scene, mData.logout
    if oScene:GetSceneId() == iNewScene then
        return
    end
    local iPid = oPlayer:GetPid()
    self:RecSceneSubPlayer(iPid)
    local oSceneCtrl = GetSceneCtrl()
    if oSceneCtrl then
        oSceneCtrl:UnRegPlayerRoom(iPid)
    end
    local oHuodong = GetHuodong()
    if oHuodong then
        oHuodong:OnLeaveRoom(oPlayer, oScene, iNewScene, bLogout)
    end
end

function CRoom:RecSceneSubPlayer(iPid)
    if self.m_mPlayers[iPid] == 1 then
        self.m_mPlayers[iPid] = 0
        self.m_iOnlineCnt = self.m_iOnlineCnt - 1
    end
end

function CRoom:GetOnlineCnt()
    return self.m_iOnlineCnt or 0
end
