--import module
local global = require "global"

local npcobj = import(service_path("npc/npcobj"))


function NewOrgNpc(npctype, orgid)
    local o = COrgNpc:New(npctype, orgid)
    return o
end

COrgNpc = {}
COrgNpc.__index = COrgNpc
inherit(COrgNpc, npcobj.CNpc)

function COrgNpc:New(type, orgid)
    local o = super(COrgNpc).New(self, type)
    o.m_iOrgId = orgid
    o:Init()
    return o
end

function COrgNpc:ClassType()
    return "org"
end

function COrgNpc:Init()
    local mData = self:GetData()
    self.m_sName = mData["name"]
    self.m_sTitle = mData["title"]
    self.m_iMapid = mData["mapid"]

    local iFigureId = mData["figureid"]
    self.m_iFigureId = iFigureId
    local mModel = global.oToolMgr:GetFigureModelData(iFigureId)
    self.m_mModel = mModel

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

function COrgNpc:OrgID()
    return self.m_iOrgId
end

function COrgNpc:NpcID()
    local mData = self:GetData()
    return mData["id"] or 0
end

function COrgNpc:GetData()
    local res = require "base.res"
    local mData = res["daobiao"]["global_npc"][self:Type()]
    assert(mData, "global_npc no config:" .. self:Type())
    return mData
end

function COrgNpc:do_look(oPlayer)
    local sText = self:GetText(oPlayer)
    self:Say(oPlayer:GetPid(), sText)
end

function COrgNpc:GetText(oPlayer)
    if not self.m_iDialog then return "" end

    local res = require "base.res"
    local mDialog = res["daobiao"]["dialog_npc"][self.m_iDialog]
    if not mDialog then
        return ""
    end
    local iNo = math.random(3)
    local sKey = string.format("dialogContent%d",iNo)
    local sDialog = mDialog[sKey]
    return sDialog
end

function COrgNpc:IsZhongGuan()
    return false
end

function COrgNpc:PackSceneInfo()
    local mInfo =  super(COrgNpc).PackSceneInfo(self)
    return mInfo
end