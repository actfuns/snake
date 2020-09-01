--import module
local global = require "global"
local skynet = require "skynet"
local interactive = require "base.interactive"

local gamedefines = import(lualib_path("public.gamedefines"))
local moveaiobj = import(service_path("moveai.moveaiobj"))

function NewMoveAI(...)
    local o = CMigrate:New(...)
    return o
end

CMigrate = {}
CMigrate.__index = CMigrate
inherit(CMigrate, moveaiobj.CMoveAI)

function CMigrate:New()
    local o = super(CMigrate).New(self)
    return o
end

function CMigrate:Init(entityobj, mArgs)
    self.m_iStep = 1
    self.m_iSceneID = entityobj:GetSceneId()
    self.m_iEntityID = entityobj:GetEid()

    self.m_iNextScene = mArgs.nextsc
    self.m_mNextPos = mArgs.nextpos

    self.m_lRouteLine = mArgs.routeline
    self.m_iInterval = mArgs.interval

    self:DelTimeCb("Start")
    self:AddTimeCb("Start", 500, function()
        self:Start()
    end)
end

function CMigrate:Start()
    self:IntervalMove()
end

function CMigrate:IntervalMove()
    local sKey = "migrate"
    self:DelTimeCb(sKey)
    if not self:MoveNext() then
        return
    end
    local iSceneID, iEntityID = self.m_iSceneID, self.m_iEntityID
    local f = function ()
        IntervalMove(iSceneID, iEntityID)
    end
    self:AddTimeCb(sKey, self.m_iInterval * 1000, f)
end

function CMigrate:MoveNext()
    if self.m_iStep >= #self.m_lRouteLine then
        if self.m_iNextScene then
            interactive.Send(".world", "scene", "NpcJumpScene",  {
                targetsc = self.m_iNextScene,
                targetpos = self.m_mNextPos,
                nowscid = self.m_iSceneID,
                entityid = self.m_iEntityID,
            })
        else
            interactive.Send(".world", "scene", "NpcMoveEnd",  {
                nowscid = self.m_iSceneID,
                entityid = self.m_iEntityID,
            })
        end
        return false
    end
    self.m_iStep = self.m_iStep + 1
    local mNextPos = self.m_lRouteLine[self.m_iStep]
    local oSceneMgr = global.oSceneMgr
    local oScene = oSceneMgr:GetScene(self.m_iSceneID)
    assert(oScene, string.format("Migrate MoveNext error scene: %d", self.m_iSceneID))
    local oEntity = oScene:GetEntity(self.m_iEntityID)
    assert(oEntity, string.format("Migrate MoveNext error entity: %d", self.m_iEntityID))

    local mNowPos = oEntity:GetPos()
    local mPos = {
        x = mNextPos.x,
        y = mNextPos.y,
        face_x = mNextPos.face_x or mNowPos.face_x,
        face_y = mNextPos.face_y or mNowPos.face_y,
    }
    oEntity:SyncPos(mPos)
    return true
end

function IntervalMove(iSceneID, iEntityID)
    local oSceneMgr = global.oSceneMgr
    local oScene = oSceneMgr:GetScene(iSceneID)
    if not oScene then return end

    local oEntity = oScene:GetEntity(iEntityID)
    if not oEntity then return end

    oEntity.m_oMoveAI:IntervalMove()
end

