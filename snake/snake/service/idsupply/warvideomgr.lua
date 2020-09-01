--import module
local global = require "global"
local skynet = require "skynet"
local interactive = require "base.interactive"

local datactrl = import(lualib_path("public.datactrl"))
local gamedb = import(lualib_path("public.gamedb"))

function NewWarVideoIdMgr(...)
    local o = CWarVideoIdMgr:New(...)
    return o
end

CWarVideoIdMgr = {}
CWarVideoIdMgr.__index = CWarVideoIdMgr
inherit(CWarVideoIdMgr, datactrl.CDataCtrl)

function CWarVideoIdMgr:New()
    local o = super(CWarVideoIdMgr).New(self)
    return o
end

function CWarVideoIdMgr:Load(m)
    m = m or {}
    self:SetData("nowid", m.now_id or 0)
end

function CWarVideoIdMgr:Save()
    local m = {}
    m.now_id = self:GetData("nowid")
    return m
end

function CWarVideoIdMgr:LoadDb()
    local mInfo = {
        module = "idcounter",
        cmd = "LoadWarVideoIdCounter",
    }
    gamedb.LoadDb("idcounter", "common", "DbOperate", mInfo,
    function (mRecord, mData)
        if not self:IsLoaded() then
            self:Load(mData.data)
            self:OnLoaded()
        end
    end)
end

function CWarVideoIdMgr:SaveDb()
    if not self:IsLoaded() then return end
    if self:IsDirty() then
        local mInfo = {
            module = "idcounter",
            cmd = "SaveWarVideoIdCounter",
            data = {data = self:Save()},
        }
        gamedb.SaveDb("idcounter", "common", "DbOperate", mInfo)
        self:UnDirty()
    end
end

function CWarVideoIdMgr:GenWarVideoId()
    local id = self:GetData("nowid", 0) + 1
    self:SetData("nowid", id)
    self:SaveDb()
    return id
end
