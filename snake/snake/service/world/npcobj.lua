--import module

local global = require "global"
local loadnpc = import(service_path("npc/loadnpc"))

function NewNpcMgr()
    local oMgr = CNpcMgr:New()
    return oMgr
end


CNpcMgr = {}
CNpcMgr.__index = CNpcMgr
inherit(CNpcMgr,logic_base_cls())

function CNpcMgr:New()
    local o = super(CNpcMgr).New(self)
    o.m_mObject = {}
    o.m_mGlobalList = {}
    o.m_mTempList = {}
    o.m_iDispatchId = 0
    return o
end

function CNpcMgr:DispatchId()
    self.m_iDispatchId = self.m_iDispatchId + 1
    return self.m_iDispatchId
end

function CNpcMgr:NewGlobalNpc(npctype)
    local oNpc = loadnpc.NewGlobalNpc(npctype)
    local iNpcid = oNpc:ID()
    self.m_mGlobalList[npctype] = iNpcid
    self:AddObject(oNpc)
    return oNpc
end

function CNpcMgr:AddObject(oNpc)
    local iNpcid = oNpc:ID()
    self.m_mObject[iNpcid] = oNpc
end

function CNpcMgr:RemoveObject(npcid)
    self.m_mObject[npcid] = nil
end

function CNpcMgr:GetObject(npcid)
    return self.m_mObject[npcid]
end

function CNpcMgr:GetGlobalNpc(npctype)
    local iNpcid = self.m_mGlobalList[npctype]
    if iNpcid then
        return self:GetObject(iNpcid)
    end
    return nil
end

function CNpcMgr:GetAllGlobalNpcs()
    return self.m_mGlobalList
end

function CNpcMgr:GetTempGlobalNpc(npctype)
    local oNpc = self.m_mTempList[npctype]
    return oNpc
end

function CNpcMgr:TouchTempGlobalNpc(npctype)
    local oNpc = self.m_mTempList[npctype]
    if not oNpc then
        oNpc = loadnpc.NewGlobalNpc(npctype)
    end
    self.m_mTempList[npctype] = oNpc
    return oNpc
end

function CNpcMgr:DetachTempGlobalNpc(npctype)
    local oNpc = self.m_mTempList[npctype]
    if not oNpc then
        return
    end
    self.m_mTempList[npctype] = nil
    return oNpc
end

function CNpcMgr:RemoveSceneNpc(npcid)
    local oNpc = self:GetObject(npcid)
    if not oNpc then
        return
    end
    local iScene = oNpc.m_Scene
    local oSceneMgr = global.oSceneMgr
    local oScene = oSceneMgr:GetScene(iScene)
    if oScene then
        oScene:RemoveSceneNpc(npcid)
        self:RemoveObject(npcid)
    end
end

--初始化
function CNpcMgr:LoadInit()
    local extend = require "base.extend"
    local res = require "base.res"
    local mGlobalData = res["daobiao"]["global_npc"] or {}
    for npctype,mData in pairs(mGlobalData) do
        local mConfig = self:GetGlobalNpcData(npctype)
        if not mConfig then
            goto continue
        end
        if is_ks_server() and not (mConfig.is_ks_npc == 1) then
            goto continue
        end

        local iMapid = mConfig.mapid
        local oSceneMgr = global.oSceneMgr
        local mScene = oSceneMgr:GetSceneListByMap(iMapid)
        for _,oScene in pairs(mScene) do
            local oNpc = self:NewGlobalNpc(npctype)
            oNpc:SetScene(oScene:GetSceneId())
            oScene:EnterNpc(oNpc)
        end
        ::continue::
    end
end

function CNpcMgr:ReloadGlobalNpcs()
    for npctype, npcid in pairs(self.m_mGlobalList) do
        self:RemoveSceneNpc(npcid)
    end
    self.m_mGlobalList = {}
    self:LoadInit()
end

function CNpcMgr:GetGlobalNpcData(iNpcType)
    assert(iNpcType)
    local res = require "base.res"
    return table_get_depth(res, {"daobiao", "global_npc", iNpcType})
end

VG_NPC_ERR = {
    NO_GLOBAL_DATA = 1,
    NO_ORG = 2,
    NO_ORG_NPC = 3,
}

-- @return: oNpc, iErrCode
function CNpcMgr:GetVirtualGlobalNpc(oPlayer, npctype)
    local res = require "base.res"
    local mGlobalData = self:GetGlobalNpcData(npctype)
    if not mGlobalData then
        return nil, VG_NPC_ERR.NO_GLOBAL_DATA
    end
    local iMap = mGlobalData.mapid
    local sVirtual = table_get_depth(res, {"daobiao", "map", iMap, "virtual_game"})
    if sVirtual == "org" then
        local oOrg = oPlayer:GetOrg()
        if oOrg then
            for iNpcId, iNpcType in pairs(oOrg.m_mNpcId) do
                if iNpcType == npctype then
                    return oOrg:GetOrgNpc(iNpcId)
                end
            end
            return nil, VG_NPC_ERR.NO_ORG_NPC
        else
            return nil, VG_NPC_ERR.NO_ORG
        end
    end
end

function CNpcMgr:NotifyErrFindNpcPath(oPlayer, iNpcType, iErr)
    if iErr == VG_NPC_ERR.NO_GLOBAL_DATA then
        oPlayer:NotifyMessage("没有这个npc")
    elseif iErr == VG_NPC_ERR.NO_ORG then
        oPlayer:NotifyMessage("你还没有加入帮派")
    elseif iErr == VG_NPC_ERR.NO_ORG_NPC then
        oPlayer:NotifyMessage("帮派没有这个npc")
    end
end

function CNpcMgr:FindPathToNpc(oPlayer, iNpcType, bSilent)
    local oNpc = self:GetGlobalNpc(iNpcType)
    local iErr
    if not oNpc then
        oNpc, iErr = self:GetVirtualGlobalNpc(oPlayer, iNpcType)
    end
    if oNpc then
        self:GotoNpcAutoPath(oPlayer, oNpc)
    else
        if iErr and not bSilent then
            self:NotifyErrFindNpcPath(oPlayer, iNpcType, iErr)
        end
    end
end

function CNpcMgr:GotoNpcAutoPath(oPlayer, oNpc, iAutoType)
    local iScene = oNpc:GetScene()
    local iMap = oNpc:MapId()
    local oScene = global.oSceneMgr:GetScene(iScene)
    local mPosInfo = oNpc:PosInfo()
    local iX = mPosInfo.x
    local iY = mPosInfo.y
    if oScene and not oScene:IsDurable() then
        return global.oSceneMgr:TargetSceneAutoFindPath(oPlayer, oScene, iX, iY, oNpc:ID(), iAutoType)
    end
    if iMap then
        return global.oSceneMgr:SceneAutoFindPath(oPlayer:GetPid(), iMap, iX, iY, oNpc:ID(), iAutoType)
    end
    return false
end

function CNpcMgr:OnClickNpc(oPlayer, oNpc)
    if not oPlayer:IsSingle() and not oPlayer:IsTeamLeader() then
        return
    end
    local oNowWar = oPlayer.m_oActiveCtrl:GetNowWar()
    if oNowWar then
        -- record.warning("OnClickNpc when in war, maybe proto dupl. pid:%d,npcid:%d", oPlayer:GetPid(), npcid)
        return
    end
    oNpc:PreDoLook(oPlayer)
    oNpc:do_look(oPlayer)
end

