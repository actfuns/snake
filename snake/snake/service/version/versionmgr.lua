local global = require "global"

local gamedefines = import(lualib_path("public.gamedefines"))

function NewVersionMgr(...)
    return CVersionMgr:New(...)
end

CVersionMgr = {}
CVersionMgr.__index = CVersionMgr
inherit(CVersionMgr, logic_base_cls())

function CVersionMgr:New()
    local o = super(CVersionMgr).New(self)
    o:Init()
    return o
end

function CVersionMgr:Init()
    self.m_mVersionObj = {}
end

function CVersionMgr:GetVersionObj(sType)
    return self.m_mVersionObj[sType]
end

function CVersionMgr:CreateVersionObj(sVerType, sModule, mInfo)
    local sPath = string.format("common/%s", sModule)
    local oModule = import(service_path(sPath))
    assert(oModule, string.format("create version error not find module:%s", sModule))

    local oVersion = oModule.NewVersionObj(sVerType)
    oVersion:Create(mInfo)
    assert(oVersion, string.format("create version error :%s", sModule))
    self.m_mVersionObj[sVerType] = oVersion
    return oVersion
end

function CVersionMgr:DeleteVersionObj(sVerType)
    local oVersion = self.m_mVersionObj[sVerType]
    if oVersion then
        baseobj_delay_release(oVersion)
    end
    self.m_mVersionObj[sVerType] = nil
end

