local global = require "global"
local res = require "base.res"

Commands = {}       --指令函数
Helpers = {}        --帮助信息
Opens = {}          --对外开放


Opens.mapnpc = true
Helpers.mapnpc = {
    "跳转到npc",
    "mapnpc 常驻npc编号",
    "mapnpc npctype",
}
function Commands.mapnpc(oMaster, iNpcType)
    local oNpcMgr = global.oNpcMgr
    local oGlobalNpc = oNpcMgr:GetGlobalNpc(iNpcType)
    if not oGlobalNpc then
        global.oNotifyMgr:Notify(oMaster:GetPid(), "无此npc")
        return
    end
    local iMapId = oGlobalNpc:MapId()
    local iX = oGlobalNpc.m_mPosInfo["x"]
    local iY = oGlobalNpc.m_mPosInfo["y"]
    local oSceneMgr = global.oSceneMgr
    local oScene = oSceneMgr:SelectDurableScene(iMapId)
    local mPos = {x = iX, y = iY}
    global.oSceneMgr:DoTransfer(oMaster, oScene:GetSceneId(), mPos)
end

Opens.map = true
Helpers.map = {
    "跳到固定地图",
    "map 固定场景编号 X坐标 Y坐标",
    "map 101000 100 100",
}
function Commands.map(oMaster, iMapId, x, y)
    local oNowScene = oMaster.m_oActiveCtrl:GetNowScene()
    if not iMapId or iMapId <= 0 then
        local mNowPos = oMaster.m_oActiveCtrl:GetNowPos()
        oMaster:NotifyMessage(string.format("当前坐标 %d(%d),%f,%f", oNowScene:MapId(), oNowScene:GetSceneId(), mNowPos.x, mNowPos.y))
        return
    end
    -- if oNowScene:MapId() == iMapId then
    --     return
    -- end
    local oSceneMgr = global.oSceneMgr
    local oScene = oSceneMgr:SelectDurableScene(iMapId)
    if not x or not y or x <= 0 or y <= 0 then
        x, y = global.oSceneMgr:RandomPos2(iMapId)
    end
    local mPos = {x = x, y = y}
    global.oSceneMgr:DoTransfer(oMaster, oScene:GetSceneId(), mPos)
end

function _GetRandPos(oScene)
    return global.oSceneMgr:RandomPos2(oScene:MapId())
end

function _ReEnterPos(oMaster, rX, rY)
    local mPos = {x = rX, y = rY}
    local oNowScene = oMaster.m_oActiveCtrl:GetNowScene()
    global.oSceneMgr:DoTransfer(oMaster, oNowScene:GetSceneId(), mPos)
end

function Commands.jumpscene(oMaster, iSceneId, x, y)
    local oNowScene = oMaster.m_oActiveCtrl:GetNowScene()
    if not iSceneId or iSceneId <= 0 then
        local mNowPos = oMaster.m_oActiveCtrl:GetNowPos()
        oMaster:NotifyMessage(string.format("当前场景坐标 %d(%d),%f,%f", oNowScene:MapId(), oNowScene:GetSceneId(), mNowPos.x, mNowPos.y))
        return
    end
    if not x or not y or x <= 0 or y <= 0 then
        x, y = _GetRandPos(oScene)
    end
    if oNowScene:GetSceneId() == iSceneId then
        _ReEnterPos(oMaster, x, y)
        return
    end
    local oScene = global.oSceneMgr:GetScene(iSceneId)
    if not oScene then
        oMaster:NotifyMessage("该场景不存在")
        return
    end
    local mPos = {x = x, y = y}
    global.oSceneMgr:DoTransfer(oMaster, oScene:GetSceneId(), mPos)
end

function Commands.repos(oMaster, x, y)
    if not x or not y then
        global.oSceneMgr:ReEnterScene(oMaster)
    else
        _ReEnterPos(oMaster, x, y)
    end
end

Opens.getpos = true
Helpers.getpos = {
    "查看当前位置信息",
    "getpos",
    "getpos",
}
function Commands.getpos(oMaster)
    local oNowScene = oMaster.m_oActiveCtrl:GetNowScene()
    local mNowScene = oMaster.m_oActiveCtrl.m_mNowSceneInfo or {}
    if oNowScene then
        local sMsg = string.format("场景编号%s, 地图编号%s,场景名字%s,x-%s,y-%s",
        oNowScene:GetSceneId(),
        oNowScene:MapId(),
        oNowScene:GetName(),
        mNowScene.now_pos.x,
        mNowScene.now_pos.y)
        local oNotifyMgr = global.oNotifyMgr
        oNotifyMgr:Notify(oMaster:GetPid(), sMsg)
    end
end

Opens.visualeffect = false
Helpers.visualeffect = {
    "设置特效可见",
    "visualeffect effectId 不填(通知当前状态)0/1/-1(默认)",
    "visualeffect 5 1",
}
function Commands.visualeffect(oMaster, iEffectId, iTag)
    if not iGlobalNpcType then
        oMaster:NotifyMessage("请输入特效id")
        return
    end
    local mSceneEffectData = global.oSceneMgr:GetEffectData(iEffectId)
    if not mSceneEffectData then
        oMaster:NotifyMessage("该特效id不存在")
        return
    end
    if not iTag then
        local iSetVisible = oMaster.m_oActiveCtrl.m_oVisualMgr:GetSceneEffectVisible(oMaster, iEffectId) or 0
        oMaster:NotifyMessage("当前可见性:" .. iSetVisible)
        return
    elseif iTag == -1 then
        local mSceneEffectData = global.oSceneMgr:GetEffectData(iEffectId)
        if not mSceneEffectData then
            oMaster:NotifyMessage("无该特效")
            return
        end
        iTag = mSceneEffectData.visible or 0
        oMaster:NotifyMessage("默认可见性:" .. iTag)
    end
    oMaster.m_oActiveCtrl.m_oVisualMgr:SetSceneEffectVisible(oMaster, {iEffectId}, iTag == 1)
end


Helpers.visualnpc = {
    "设置npc可见",
    "visualnpc global_npc_type 不填(通知当前状态)0/1/-1(默认)",
    "visualnpc 5269 1",
}
function Commands.visualnpc(oMaster, iGlobalNpcType, iTag)
    if not iGlobalNpcType then
        oMaster:NotifyMessage("请输入常驻npctype")
        return
    end
    if iGlobalNpcType < 0 then
        local mAllGlobalNpcs = global.oNpcMgr:GetAllGlobalNpcs()
        if not iTag then
            oMaster:NotifyMessage("请输入0/1/-1更改可见性")
            return
        end
        if iTag == -1 then
            for iNpctype, _ in pairs(mAllGlobalNpcs) do
                local mGlobalNpcData = global.oNpcMgr:GetGlobalNpcData(iNpctype)
                iTag = mGlobalNpcData.visible or 0
                oMaster.m_oActiveCtrl.m_oVisualMgr:SetNpcVisible(oMaster, {iNpctype}, iTag == 1)
            end
        else
            oMaster.m_oActiveCtrl.m_oVisualMgr:SetNpcVisible(oMaster, table_key_list(mAllGlobalNpcs), iTag == 1)
        end
        return
    end
    local mGlobalNpcData = global.oNpcMgr:GetGlobalNpcData(iGlobalNpcType)
    if not mGlobalNpcData then
        oMaster:NotifyMessage("该常驻npc的id不存在")
        return
    end
    if not iTag then
        local iSetVisible = oMaster.m_oActiveCtrl.m_oVisualMgr:GetNpcVisible(oMaster, iGlobalNpcType) or 0
        oMaster:NotifyMessage("当前可见性:" .. iSetVisible)
        return
    elseif iTag == -1 then
        local mGlobalNpcData = global.oNpcMgr:GetGlobalNpcData(iGlobalNpcType)
        if not mGlobalNpcData then
            oMaster:NotifyMessage("无该npc")
            return
        end
        iTag = mGlobalNpcData.visible or 0
        oMaster:NotifyMessage("默认可见性:" .. iTag)
    end
    oMaster.m_oActiveCtrl.m_oVisualMgr:SetNpcVisible(oMaster, {iGlobalNpcType}, iTag == 1)
end

Helpers.npcappears = {
    "视觉上npc形象更变",
    "npcappears global_npc_type 'figureid,dialogid,title(-号表示无)'(不填的项还原)",
    "npcappears 5201 '1001,5234,-'",
}
function Commands.npcappears(oMaster, iGlobalNpcType, sArgs)
    if not iGlobalNpcType then
        return true
    end
    local sFigureId, sGlobalDiaId, sTitle = table.unpack(split_string(sArgs or "", ","))
    local iFigureId = tonumber(sFigureId)
    local iGlobalDiaId = tonumber(sGlobalDiaId)
    if sTitle == "" then
        sTitle = nil
    elseif sTitle == "-" then
        sTitle = ""
    end
    oMaster.m_oActiveCtrl.m_oVisualMgr:SetMyGlobalNpc(iGlobalNpcType, iFigureId, iGlobalDiaId, sTitle)
    oMaster.m_oActiveCtrl.m_oVisualMgr:SyncMyGlobalNpc(oMaster, iGlobalNpcType)
end

Opens.showscenestat = true
Helpers.showscenestat = {
    "场景详细信息",
    "showscenestat",
    "showscenestat",
}
function Commands.showscenestat(oMaster)
    local oSceneMgr = global.oSceneMgr
    local iTotal = 0
    local lStat = {"\n",}
    for id, oScene in pairs(oSceneMgr.m_mScenes) do
        local iCount = table_count(oScene.m_mPlayers)
        table.insert(lStat, 
            string.format("场景ID:%s, 场景名:%s, 场景服务:%s, 地图ID:%s, 场景人数:%s",
                id,
                oScene:GetName(),
                oScene:GetRemoteAddr(),
                oScene:MapId(),
                iCount
            )
        )
        iTotal = iTotal + iCount
    end
    table.insert(lStat, string.format("服内总人数:%s", iTotal))

    oMaster:Send("GS2CGMMessage", {
        msg = table.concat(lStat, "\n"),
    })
end

Opens.reloadgnpc = true
Helpers.reloadgnpc = {
    "重新载入常驻npc",
    "reloadgnpc",
    "reloadgnpc",
}
function Commands.reloadgnpc(oMaster)
    global.oNpcMgr:ReloadGlobalNpcs()
    oMaster:NotifyMessage("服务器重载常驻npc完成")
end

function Commands.choosemap(oMaster)
    local oSceneMgr = global.oSceneMgr
    local lSceneIds = {}
    for mapid, ids in pairs(oSceneMgr.m_mDurableScenes) do
        if mapid == 101000 then
            for _, id in ipairs(ids) do
                table.insert(lSceneIds, id)
            end
        end
    end
    local iSceneId = lSceneIds[math.random(1, #lSceneIds)]
    local oScene = oSceneMgr:GetScene(iSceneId)
    local iX, iY = oSceneMgr:RandomPos2(oScene:MapId())
    local mPos = {
        x = iX,
        y = iY,
        z = 0,
        face_x = 0,
        face_y = 0,
        face_z = 0,
    }
    oSceneMgr:EnterScene(oMaster,iSceneId,{pos = mPos})
end
