--import module

local global = require "global"
local skynet = require "skynet"
local interactive = require "base.interactive"


function C2GSSyncPosQueue(oPlayer, mData)
    local oScene = oPlayer.m_oActiveCtrl:GetNowScene()
    assert(oScene, string.format("C2GSSyncPos err no scene: pid %d scene %s", oPlayer:GetPid(), oPlayer.m_oActiveCtrl.m_mNowSceneInfo and oPlayer.m_oActiveCtrl.m_mNowSceneInfo.now_scene))
    local poslist = mData["poslist"]
    if #poslist < 1 then return end

    if oPlayer.m_iGodEyes == mData.scene_id then
        oScene:Forward("C2GSSyncPosQueue", oPlayer:GetPid(), mData)
    else
        if oScene:GetSceneId() ~= mData.scene_id then
            return
        end

        oScene:OnSyncPos(oPlayer, poslist[1]["pos"])
        oScene:Forward("C2GSSyncPosQueue", oPlayer:GetPid(), mData)
    end
end

function C2GSTransfer(oPlayer, mData)
    local oSceneMgr = global.oSceneMgr
    local oNotifyMgr = global.oNotifyMgr
    local oScene = oPlayer.m_oActiveCtrl:GetNowScene()
    local oTeam = oPlayer:HasTeam()
    local pid = oPlayer.m_iPid
    if oTeam and not oTeam:IsLeader(pid) and oTeam:IsTeamMember(pid) then
        oNotifyMgr:Notify(pid,"您在队伍中，不能操作")
        return
    end
    if oScene:GetSceneId() == mData.scene_id then
        oSceneMgr:TransferScene(oPlayer, mData.transfer_id)
    end
end

function C2GSClickWorldMap(oPlayer, mData)
    local oSceneMgr = global.oSceneMgr
    local oNotifyMgr = global.oNotifyMgr
    local oScene = oPlayer.m_oActiveCtrl:GetNowScene()
    local oTeam = oPlayer:HasTeam()
    local pid = oPlayer.m_iPid
    if oTeam and not oTeam:IsLeader(pid) and oTeam:IsTeamMember(pid) then
        oNotifyMgr:Notify(pid,"您在队伍中，不能操作")
        return
    end
    if oPlayer:IsFixed() then
        return
    end
    if oScene:GetSceneId() == mData.scene_id then
        oSceneMgr:ChangeMap(oPlayer,mData.map_id)
    end
end

function C2GSClickTrapMineMap(oPlayer, mData)
    local oNotifyMgr = global.oNotifyMgr
    local oSceneMgr = global.oSceneMgr
    local oNotifyMgr = global.oNotifyMgr
    local oScene = oPlayer.m_oActiveCtrl:GetNowScene()
    local oTeam = oPlayer:HasTeam()
    local pid = oPlayer.m_iPid
    if oTeam and not oTeam:IsLeader(pid) and oTeam:IsTeamMember(pid) then
        oNotifyMgr:Notify(pid,"您在队伍中，不能操作")
        return
    end
    if oPlayer:IsFixed() then
        return
    end
    if oScene:GetSceneId() == mData.scene_id then
        oSceneMgr:ClickTrapMineMap(oPlayer, mData.map_id)
    end
end

function C2GSStartWaterWalk(oPlayer, mData)
    global.oSceneMgr:PlayerStartWaterWalk(oPlayer, mData.walkid)
end
