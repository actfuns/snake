--import module
local global = require "global"
local geometry = require "base.geometry"

local npcobj = import(service_path("npc/npcobj"))

CClientNpc = {}
CClientNpc.__index = CClientNpc
inherit(CClientNpc,npcobj.CNpc)

function CClientNpc:New(mArgs)
    local o = super(CClientNpc).New(self)
    o:Init(mArgs)
    return o
end

function CClientNpc:ClassType()
    return "client"
end

function CClientNpc:Init(mArgs)
    -- self:InitObject()
    local mArgs = mArgs or {}

    self.m_iTaskid = mArgs["taskid"]
    self.m_iOwner = mArgs["owner"]
    self.m_iType = mArgs["type"]
    self.m_sName = mArgs["name"] or ""
    self.m_sTitle = mArgs["title"] or ""
    self.m_iMapid = mArgs["map_id"] or 0
    self.m_mModel = mArgs["model_info"] or {}
    self.m_mPosInfo = mArgs["pos_info"] or {}
    self.m_sFuncGroup = mArgs["func_group"]
    self.m_iNoTurnFace = mArgs["no_turnface"]

    self.m_iEvent = mArgs["event"] or 0
    self.m_iReUse = mArgs["reuse"]

    if mArgs["dialogId"] ~= 0 then
        self.m_iDialog = mArgs["dialogId"]
    end

    local iXunluoId = mArgs["xunluo_id"]
    if iXunluoId and iXunluoId > 0 then
        self:SetXunLuoID(iXunluoId)
    end

    self.m_iGhostEye = mArgs["ghost_eye"]
    self.m_iLifeEnd = mArgs["life_end"]

    self.m_mMirrorInfo = mArgs["mirrorinfo"]
end

function CClientNpc:Save()
    local data = {}
    data["taskid"] = self.m_iTaskid
    data["owner"] = self.m_iOwner
    data["type"] = self.m_iType
    data["func_group"] = self.m_sFuncGroup
    data["name"] = self.m_sName
    data["title"] = self.m_sTitle
    data["map_id"] = self.m_iMapid
    data["model_info"] = self.m_mModel
    data["pos_info"] = self.m_mPosInfo
    data["no_turnface"] = self.m_iNoTurnFace
    data["dialogId"] = self.m_iDialog

    data["reuse"]  = self.m_iReUse
    data["event"] = self.m_iEvent

    data["xunluo_id"] = self:GetXunLuoID()

    data["ghost_eye"] = self.m_iGhostEye
    data["life_end"] = self.m_iLifeEnd

    data["mirrorinfo"] = self.m_mMirrorInfo
    return data
end

function CClientNpc:PackInfo()
    local mData        = {
            npctype    = self.m_iType,
            npcid      = self.m_ID,
            name       = self.m_sName,
            title      = self.m_sTitle,
            map_id     = self.m_iMapid,
            pos_info   = self:PackPos(),
            model_info = self.m_mModel,
            xunluoid   = self:GetXunLuoID(),
            ghost_eye  = self.m_iGhostEye,
            func_group = self.m_sFuncGroup,
            no_turnface = self.m_iNoTurnFace,
    }
    return mData
end

function CClientNpc:SaveMirrorInfo(mData)
    self.m_sName = mData.name
    self.m_mModel = mData.model_info
    self.m_mMirrorInfo = mData
end

function CClientNpc:GetMirrorInfo()
    return self.m_mMirrorInfo
end

function CClientNpc:GetEvent()
    if 0 == self.m_iEvent then
        return nil
    end
    return self.m_iEvent
end

function CClientNpc:SetEvent(iEvent)
    self.m_iEvent = iEvent
end

function CClientNpc:GetMap()
    return self:MapId()
end

function CClientNpc:SetPos(mPosInfo)
    self.m_mPosInfo = mPosInfo
end

function CClientNpc:GetPos()
    return self.m_mPosInfo
end

function CClientNpc:PackPos()
    local mPos = self:GetPos()
    if not mPos then
        return
    end
    local pos_info = {
            x = math.floor(geometry.Cover(mPos.x)),
            y = math.floor(geometry.Cover(mPos.y)),
            z = math.floor(geometry.Cover(mPos.z)),
            face_x = math.floor(geometry.Cover(mPos.face_x)),
            face_y = math.floor(geometry.Cover(mPos.face_y)),
            face_z = math.floor(geometry.Cover(mPos.face_z)),
        }
     return pos_info
end

function CClientNpc:IsSameMap(oScene)
    if oScene and oScene:MapId() == self:MapId() then
        return true
    end
end

function CClientNpc:IsNoTurnFace()
    return self.m_iNoTurnFace == 1
end

-- PS. 不需要do_look来处理task，因为任务选项的点击上行的是C2GSTaskEvent
-- function CClientNpc:do_look(oPlayer)
--     local taskid = self.m_iTaskid
--     if taskid then
--         global.oTaskHandler:DoClickTaskNpc(oPlayer, self.m_ID, taskid)
--     else
--         super(CClientNpc).do_look(self, oPlayer)
--     end
-- end

function CClientNpc:GetOwnedTask()
    local iOwner = self.m_iOwner
    local iTaskid = self.m_iTaskid
    local oPlayer = global.oWorldMgr:GetOnlinePlayerByPid(iOwner)
    if not oPlayer then
        return nil
    end
    local oTask = global.oTaskMgr:GetUserTask(oPlayer, iTaskid, true)
    return oTask
end

function CClientNpc:SetLifeTime(iEndTime)
    self.m_iLifeEnd = iEndTime
    return self:TouchLifeTime()
end

function CClientNpc:CheckTimeCb()
    self:TouchLifeTime()
end

-- @return: <bool>alive
function CClientNpc:TouchLifeTime()
    self:DelTimeCb("life_end")
    local iEndTime = self.m_iLifeEnd
    if iEndTime then
        local iLeftTime = iEndTime - get_time()
        if iLeftTime <= 0 then
            self:LifeEnd()
            return false
        end
        if iLeftTime > 1 * 24 * 3600 then return true end
        -- TODO 需要改为cron
        assert(iLeftTime<=10*24*3600, string.format("clientnpc lefttime too huge until crontab, taskid:%s, owner:%s, livetime:%d", self.m_iTaskid, self.m_iOwner, iLeftTime))
        local npcid = self:ID()
        self:AddTimeCb("life_end", iLeftTime * 1000, function()
            local oNpc = global.oNpcMgr:GetObject(npcid)
            if oNpc then
                oNpc:LifeEnd()
            end
        end)
    end
    return true
end

function CClientNpc:LifeEnd()
    -- mSrc.type -> taskobj : mSrc.func
end

---------------------------

CFollowNpc = {}
CFollowNpc.__index = CFollowNpc
inherit(CFollowNpc, CClientNpc)

function CFollowNpc:ClassType()
    return "client_follow"
end

function CFollowNpc:LifeEnd()
    -- get mSrc, release
    local oTask = self:GetOwnedTask()
    if not oTask then
        return
    end
    oTask:RemoveFollowNpc(self)
end

function CFollowNpc:GetPos()
    return nil
end

function CFollowNpc:IsPlayerNear(oPlayer)
    return 0
end

function CFollowNpc:Init(mArgs)
    super(CFollowNpc).Init(self, mArgs)
    -- local oPlayer = global.oWorldMgr:GetOnlinePlayerByPid(self.m_iOwner)
    -- if oPlayer then
    --     self.m_sTitle = oPlayer:GetName()
    -- end
end

function CFollowNpc:FollowerInfo()
    local sTitle = self.m_sTitle
    local oPlayer = global.oWorldMgr:GetOnlinePlayerByPid(self.m_iOwner)
    if oPlayer then
        sTitle = oPlayer:GetName()
    end
    return {
        name = self.m_sName,
        model_info = self.m_mModel,
        title = sTitle,
        type = "n",
    }
end

---------------------------

function CheckLifeEndTime(mArgs)
    local iEndTime = mArgs.life_end
    if iEndTime and iEndTime <= get_time() then
        return false
    end
    return true
end

function NewClientNpc(mArgs)
    local o = CClientNpc:New(mArgs)
    return o
end

function NewFollowNpc(mArgs)
    local o = CFollowNpc:New(mArgs)
    return o
end

function TouchNewClientNpc(mArgs)
    if not CheckLifeEndTime(mArgs) then
        return nil
    end
    local o = NewClientNpc(mArgs)
    o:TouchLifeTime()
    return o
end

function TouchNewFollowNpc(mArgs)
    if not CheckLifeEndTime(mArgs) then
        return nil
    end
    local o = NewFollowNpc(mArgs)
    o:TouchLifeTime()
    return o
end
