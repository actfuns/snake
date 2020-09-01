--import module
local global = require "global"
local record = require "public.record"

local npcnet = import(service_path("netcmd/npc"))

CNpc = {}
CNpc.__index = CNpc
inherit(CNpc,logic_base_cls())

function CNpc:New(type)
    local o = super(CNpc).New(self)
    o.m_iType = type
    o:InitObject()
    return o
end

function CNpc:ClassType()
    return "base"
end

function CNpc:InitObject()
    local oNpcMgr = global.oNpcMgr
    local id = oNpcMgr:DispatchId()
    self.m_ID = id
    -- oNpcMgr:AddObject(self)的操作放到外面由各个调用模块自己调用
end

function CNpc:ID()
    return self.m_ID
end

function CNpc:NpcID()
    return 0
end

function CNpc:Release()
    super(CNpc).Release(self)
end

function CNpc:GetScene()
    return self.m_Scene
end

function CNpc:SetScene(iScene)
    self.m_Scene = iScene
end

function CNpc:PreDoLook(oPlayer)
end

function CNpc:do_look(oPlayer)
    local sText = self:GetText(oPlayer)
    -- 前端在C2GSClickNpc逻辑中需要永远有Say的下行，否则无法对全局npc的任务显示菜单
    self:Say(oPlayer.m_iPid,sText)
end

function CNpc:PackSayInfo(pid, sText, mMenuArgs, iMenuType, bIsLv2, iTime)
    local mNet = {}
    mNet["npcid"] = self.m_ID
    mNet["model_info"] = self:ModelInfo()
    if self.m_mChangeModel then
        mNet["model_info"] = self.m_mChangeModel
    end
    if mNet.model_info then
        mNet.model_info.horse = nil
    end
    mNet["name"] = self:Name()
    mNet["text"] = sText
    mNet["type"] = iMenuType
    mNet["lv2"] = bIsLv2 and 1 or nil
    if mMenuArgs then
        for sKey, xValue in pairs(mMenuArgs) do
            mNet[sKey] = xValue
        end
    end
    -- 覆盖
    if iTime then
        mNet["time"] = iTime
    end
    return mNet
end

function CNpc:Say(pid,sText, mMenuArgs, iMenuType, bIsLv2, iTime)
    local mNet = self:PackSayInfo(pid, sText, mMenuArgs, iMenuType, bIsLv2, iTime)
    local oWorldMgr = global.oWorldMgr
    local oPlayer = oWorldMgr:GetOnlinePlayerByPid(pid)
    if oPlayer then
        oPlayer:Send("GS2CNpcSay",mNet)
    end
end

function CNpc:TeamSay(pid,sText, mMenuArgs, iMenuType, bIsLv2, iTime)
    local mNet = self:PackSayInfo(pid, sText, mMenuArgs, iMenuType, bIsLv2, iTime)
    local oWorldMgr = global.oWorldMgr
    local oPlayer = oWorldMgr:GetOnlinePlayerByPid(pid)
    if not oPlayer then return end

    if oPlayer:IsTeamLeader() then
        local lMember = oPlayer:GetTeamMember()
        for _, iMember in ipairs(lMember or {}) do
            local oMember = oWorldMgr:GetOnlinePlayerByPid(iMember)
            if oMember then
                oMember:Send("GS2CNpcSay", mNet)
            end
        end
    else
        oPlayer:Send("GS2CNpcSay",mNet)
    end
end

function CNpc:GetMap()
    local oScene = global.oSceneMgr:GetScene(self:GetScene())
    if not oScene then
        return
    end
    return oScene:MapId()
end

function CNpc:IsSameMap(oScene)
    if oScene and oScene:MapId() == self:GetMap() then
        return true
    end
end

function CNpc:IsNearPos(mPos)
    if not mPos then
        return false
    end
    local mNpcPos = self:PosInfo()
    if not mNpcPos then
        return false
    end
    if math.abs(mPos.x - mNpcPos.x) > 9 then
        return false
    end
    if math.abs(mPos.y - mNpcPos.y) > 9 then
        return false
    end
    return true
end

function CNpc:IsPlayerNear(oPlayer)
    local oNowScene = oPlayer:GetNowScene()
    local mNowPos = oPlayer:GetNowPos()
    if not self:IsSameMap(oNowScene) then
        return 1
    end
    if not self:IsNearPos(mNowPos) then
        return 2
    end
    return 0
end

function _IsNpcNear(oPlayer, npcid)
    local oNpc = global.oNpcMgr:GetObject(npcid)
    if not oNpc then
        return false
    end
    local ret = oNpc:IsPlayerNear(oPlayer)
    if ret and ret ~= 0 then
        if not is_production_env() then
            global.oNotifyMgr:Notify(oPlayer:GetPid(), "距离过远")
        end
        -- 客户端同步位置bug临时处理
        if ret ~= 2 then
            return false
        else
            local oScene = oPlayer:GetNowScene()
            local iPMap = oScene and oScene:MapId() or 0
            record.warning("npc %s is not nearby %d %s, %d %s", oNpc:Name(),
                iPMap, serialize_table(oPlayer:GetNowPos()), oNpc:GetMap(), serialize_table(oNpc:PosInfo()))
        end
    end
    return true
end

function CNpc:ParseResCb(pid, fResCb, bNoPosCheck)
    if bNoPosCheck then
        if fResCb then
            return function(oPlayer, mData)
                return fResCb(oPlayer, mData)
            end
        end
    else
        local npcid = self:ID()
        return function(oPlayer, mData)
            if not _IsNpcNear(oPlayer, npcid) then
                return false
            end
            if fResCb then
                return fResCb(oPlayer, mData)
            else
                return true
            end
        end
    end
end

--需要客户端回应
function CNpc:SayRespond(pid,sText,fResCb,fCallBack, mMenuArgs, iMenuType, bIsLv2, iTime, bNoPosCheck)
    local mNet = self:PackSayInfo(pid, sText, mMenuArgs, iMenuType, bIsLv2, iTime)
    local oCbMgr = global.oCbMgr
    local fCheckableResCb = self:ParseResCb(pid, fResCb, bNoPosCheck)
    oCbMgr:SetCallBack(pid,"GS2CNpcSay",mNet,fCheckableResCb,fCallBack)
end

function CNpc:TeamSayRespond(pid,sText,fResCb,fCallBack, mMenuArgs, iMenuType, bIsLv2, iTime, bNoPosCheck)
    local oPlayer = global.oWorldMgr:GetOnlinePlayerByPid(pid)
    if not oPlayer then return end

    local mNet = self:PackSayInfo(pid, sText, mMenuArgs, iMenuType, bIsLv2, iTime)
    local oCbMgr = global.oCbMgr
    oCbMgr:SetCallBack(pid,"GS2CNpcSay",mNet,fResCb,fCallBack)

    if oPlayer:IsTeamLeader() then
        local lMember = oPlayer:GetTeamMember()
        for _, iMember in ipairs(lMember or {}) do
            local oMember = global.oWorldMgr:GetOnlinePlayerByPid(iMember)
            if oMember then
                oMember:Send("GS2CNpcSay", mNet)
            end
        end
    end
end

function CNpc:Name()
    return self.m_sName
end

function CNpc:Type()
    return self.m_iType
end

function CNpc:Shape()
    local iShape = self.m_mModel.shape
    if not iShape then
        local iFigureId = self:GetFigureId()
        if iFigureId then
            return global.oToolMgr:GetFigureShape(iFigureId)
        end
    end
end

function CNpc:GetFigureId()
    return self.m_iFigureId or self.m_mModel.figure
end

function CNpc:SetChangeModelInfo(mModel)
    self.m_mChangeModel = mModel
end

function CNpc:ClearChangeModelInfo()
    self.m_mChangeModel = nil
end

function CNpc:ModelInfo()
    return self.m_mModel
end

function CNpc:PosInfo()
    return self.m_mPosInfo
end

function CNpc:MapId()
    return self.m_iMapid
end

function CNpc:GetText(oPlayer)
    return ""
end

function CNpc:InWar()
    if not self.m_WarID then
        return
    end
    local oWarMgr = global.oWarMgr
    return oWarMgr:GetWar(self.m_WarID)
end

function CNpc:SetNowWar(warid)
    self.m_WarID = warid
end

function CNpc:ClearNowWar()
    self.m_WarID = nil
end

function CNpc:GetXunLuoID()
    return self.m_iXunLuoID
end

function CNpc:SetXunLuoID(xunluoid)
    self.m_iXunLuoID = xunluoid
end

function CNpc:GetMoveAIInfo(iScene)
    if self.m_iXunLuoID then
        return {
            aitype = "xunluo",
            aiargs = {
                xunluoid = self.m_iXunLuoID,
            },
        }
    end
end

function CNpc:GetTitle()
    return self.m_sTitle or ""
end

-- function CNpc:GetVisible()
--     return self.m_iVisible or 0
-- end

function CNpc:GetGhostEye()
    return self.m_iGhostEye or 0
end

function CNpc:OnNpcMoveEnd()
    -- body
end

function CNpc:PackSceneInfo()
    local mInfo = {
        npctype  = self.m_iType,
        npcid = self.m_ID,
        name = self:Name(),
        model_info = self:ModelInfo(),
        moveai_info = self:GetMoveAIInfo(self.m_Scene),
        title = self:GetTitle(),
        func_group = self.m_sFuncGroup,
        class_type = self:ClassType(),
    }
    return mInfo
end

--同步信息去场景
function CNpc:SyncSceneInfo(mInfo)
    local iScene = self.m_Scene
    local oSceneMgr = global.oSceneMgr
    local oScene = oSceneMgr:GetScene(iScene)
    if oScene then
        oScene:SyncNpcInfo(self,mInfo)
    end
end

function CNpc:SpeekMsg(sMsg, iSec)
    local oScene = global.oSceneMgr:GetScene(self.m_Scene)
    if oScene then
        local mNet = {
            npcid = self.m_ID,
            msg = sMsg,
            timeout = iSec,
        }
        oScene:BroadcastMessage("GS2CNpcBubbleTalk", mNet, {})
    end
end

---------------------------------------------

CGlobalNpc = {}
CGlobalNpc.__index = CGlobalNpc
inherit(CGlobalNpc, CNpc)

function CGlobalNpc:New(type)
    local o = super(CGlobalNpc).New(self, type)
    o:Init()
    return o
end

function CGlobalNpc:ClassType()
    return "global"
end

function CGlobalNpc:Init()
    local mData = self:GetData()
    self.m_sName = mData["name"]
    self.m_sTitle = mData["title"]
    self.m_iMapid = mData["mapid"]
    -- self.m_iVisible = mData["visible"] -- 默认可见性

    local iFigureId = mData["figureid"]
    self.m_iFigureId = iFigureId
    local mModel = global.oToolMgr:GetFigureModelData(iFigureId)
    -- 可以支持CNpc:GetData重载，可能子类会设置其他造型属性(暂不实现)
    self.m_mModel = mModel
    self.m_mChangeModel = nil

    self.m_iDialog = mData["dialogId"]
    local mPosInfo = {
            x = mData["x"],
            y = mData["y"],
            z = mData["z"],
            face_x = mData["face_x"] or 0,
            face_y = mData["face_y"] or 0,
            face_z = mData["face_z"] or 0
    }
    self.m_mPosInfo = mPosInfo

    local iXunluoId = mData["xunluo_id"]
    if iXunluoId and iXunluoId > 0 then
        self:SetXunLuoID(iXunluoId)
    end
end

function CGlobalNpc:NpcID()
    local mData = self:GetData()
    return mData["id"] or 0
end

function CGlobalNpc:GetData()
    local res = require "base.res"
    local npctype = self:Type()
    local mData = res["daobiao"]["global_npc"][npctype]
    assert(mData, "global_npc no config:" .. npctype)
    return mData
end

function CGlobalNpc:GetRegOptions()
    local mData = self:GetData()
    local mOptions = mData.menu_options
    return mOptions
end

function CGlobalNpc:GetMenuOptionData()
    local res = require "base.res"
    return res["daobiao"]["npc_menu_option"]
end

-- 靠近特写
function CGlobalNpc:TouchCloseup(oPlayer)
    local mData = self:GetData()
    local iCloseup = mData.closeup
    if not iCloseup or iCloseup == 0 then
        return
    end
    local npctype = self:Type()
    if not oPlayer:HasSeenNpc(npctype) then
        oPlayer:RecSeenNpc(npctype)
        oPlayer:Send("GS2CShowNpcCloseup", {npctype = npctype})
    end
end

function CGlobalNpc:PreDoLook(oPlayer)
    self:TouchCloseup(oPlayer)
end

function CGlobalNpc:do_look(oPlayer)
    local npctype = self:Type()
    if oPlayer.m_oActiveCtrl.m_oVisualMgr:GetNpcVisible(oPlayer, npctype) == 0 then
        return
    end
    super(CGlobalNpc).do_look(self, oPlayer)
end

function CGlobalNpc:GetText(oPlayer)
    local npctype = self:Type()
    local iDialog
    local mMyGlobalNpc = oPlayer.m_oActiveCtrl.m_oVisualMgr:GetMyGlobalNpc(npctype)
    if mMyGlobalNpc then
        iDialog = mMyGlobalNpc.dialog
    end
    if not iDialog then
        iDialog = self.m_iDialog
    end
    if not iDialog then
        return ""
    end
    local res = require "base.res"
    local mDialog = res["daobiao"]["dialog_npc"][iDialog]
    if not mDialog then
        return ""
    end
    local iNo = math.random(3)
    local sKey = string.format("dialogContent%d",iNo)
    local sDialog = mDialog[sKey]
    return sDialog
end

---------------------------------
function NewNpc(npctype)
    local o = CNpc:New(npctype)
    return o
end

function NewGlobalNpc(npctype)
    local o = CGlobalNpc:New(npctype)
    return o
end
