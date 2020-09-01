local global = require "global"

local gamedefines = import(lualib_path("public.gamedefines"))

function NewVersionObj(...)
    return CVersion:New(...)
end

CVersion = {}
CVersion.__index = CVersion
inherit(CVersion, logic_base_cls())

function CVersion:New(sType)
    local o = super(CVersion).New(self)
    o.m_sType = sType
    o:Init()
    return o
end

function CVersion:Init()
    self.m_iVersion = 1
    self.m_iMinVersion = 1
    self.m_iVersionNum = 30
    self.m_mVersionInfo = {}        -- 保存最后一个指令
    self.m_mSourceInfo = {}         -- 元数据
end

function CVersion:Create(mInfo)
end

function CVersion:Add(key, mInfo)
    self.m_mSourceInfo[key] = mInfo
    self:UpdateVersion(key, gamedefines.VERSION_OP_TYPE.ADD)
end

function CVersion:Delete(key)
    self.m_mSourceInfo[key] = nil
    self:UpdateVersion(key, gamedefines.VERSION_OP_TYPE.DELETE)
end

function CVersion:Update(key, mInfo)
    self.m_mSourceInfo[key] = mInfo
    self:UpdateVersion(key, gamedefines.VERSION_OP_TYPE.UPDATE)
end

function CVersion:UpdateVersion(key, iType)
    local mVersion = self.m_mVersionInfo[self.m_iVersion]
    if not mVersion then
        mVersion = {}
        self.m_mVersionInfo[self.m_iVersion] = mVersion
    end
    mVersion[key] = iType
    self:CheckAutoCommit()
end

function CVersion:CheckAutoCommit()
end

function CVersion:Commit()
    self.m_iVersion = self.m_iVersion + 1
    if self.m_iVersion - self.m_iMinVersion >= self.m_iVersionNum then
        self.m_mVersionInfo[self.m_iMinVersion] = nil
        self.m_iMinVersion = self.m_iMinVersion + 1
    end
end

function CVersion:GetVersionInfo(iVersion)
    local mVersion = {}
    for iVer = iVersion, self.m_iVersion do
        for key, iType in pairs(self.m_mVersionInfo[iVer] or {}) do
            mVersion[key] = iType
        end
    end
    return mVersion
end

function CVersion:IsValid(iVersion)
    return iVersion >= self.m_iMinVersion
end
