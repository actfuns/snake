local global = require "global"

local gamedefines = import(lualib_path("public.gamedefines"))
local versionbase = import(service_path("versionbase"))


function NewVersionObj(...)
    return CVersion:New(...)
end

CVersion = {}
CVersion.__index = CVersion
inherit(CVersion, versionbase.CVersion)

function CVersion:Init()
    super(CVersion).Init(self)
    self.m_iVersionNum = 30
end

function CVersion:Create(mInfo)
    self.m_mSourceInfo = mInfo
end

function CVersion:CheckAutoCommit()
    local mVersion = self.m_mVersionInfo[self.m_iVersion]
    if table_count(mVersion or {}) >= 30 then
        self:Commit()
    end
end

function CVersion:PackOrgMember(mData)
    local iVersion = mData['version'] or 0

    local mNet = {}
    mNet.infos = {}
    if not self:IsValid(iVersion) then
        for _, mInfo in pairs(self.m_mSourceInfo) do
            table.insert(mNet.infos, mInfo)
        end
    else
        local mVersion = self:GetVersionInfo(iVersion)
        for iPid, iType in pairs(mVersion) do
            local mInfo = self.m_mSourceInfo[iPid]
            if mInfo then
                local m = table_copy(mInfo)
                m.optype = iType
                table.insert(mNet.infos, m)
            end
        end
        mNet.update = 1
    end
    return mNet
end
