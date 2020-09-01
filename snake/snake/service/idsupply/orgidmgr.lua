--import module
local global = require "global"
local skynet = require "skynet"
local interactive = require "base.interactive"

local datactrl = import(lualib_path("public.datactrl"))
local gamedb = import(lualib_path("public.gamedb"))

function NewOrgIdMgr(...)
    local o = COrgIdMgr:New(...)
    return o
end

COrgIdMgr = {}
COrgIdMgr.__index = COrgIdMgr
inherit(COrgIdMgr, datactrl.CDataCtrl)

function COrgIdMgr:New()
    local o = super(COrgIdMgr).New(self)
    return o
end

function COrgIdMgr:Load(m)
    m = m or {}
    self:SetData("nowid", m.now_id or 1000)
end

function COrgIdMgr:Save()
    local m = {}
    m.now_id = self:GetData("nowid")
    return m
end

function COrgIdMgr:LoadDb()
    local mInfo = {
        module = "idcounter",
        cmd = "LoadOrgIdCounter",
    }
    gamedb.LoadDb("idcounter", "common", "DbOperate", mInfo,
    function (mRecord, mData)
        if not self:IsLoaded() then
            self:Load(mData.data)
            self:OnLoaded()
        end
    end)
end

function COrgIdMgr:SaveDb()
    if not self:IsLoaded() then return end
    if self:IsDirty() then
        local mInfo = {
            module = "idcounter",
            cmd = "SaveOrgIdCounter",
            data = {data = self:Save()},
        }
        gamedb.SaveDb("idcounter", "common", "DbOperate", mInfo)
        self:UnDirty()
    end
end

function COrgIdMgr:GenOrgId()
    local id = self:GetData("nowid", 1000) + 1
    self:SetData("nowid", id)
    self:SaveDb()
    return id
end
