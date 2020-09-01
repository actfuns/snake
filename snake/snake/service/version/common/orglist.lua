local global = require "global"

local gamedefines = import(lualib_path("public.gamedefines"))
local versionbase = import(service_path("versionbase"))


function NewVersionObj(...)
    return CVersion:New(...)
end

CVersion = {}
CVersion.__index = CVersion
inherit(CVersion, versionbase.CVersion)

function CVersion:Create(mInfo)
    self.m_mSourceInfo = mInfo
end

function CVersion:PackOrgList(mData)
    local iPid = mData["pid"]
    local iVersion = mData['version'] or 0
    local lFriend = mData['friends'] or {}
    local lApplyOrg = mData['applylist'] or {}

    local mNet = {}
    mNet.infos = {}
    mNet.version = self.m_iVersion
    mNet.left_time = mData["left_time"]
    if not self:IsValid(iVersion) then
        for iOrg, _ in  pairs(self.m_mSourceInfo) do
            local m = self:PackOrgInfo(iPid, lFriend, iOrg, lApplyOrg)
            if m then
                table.insert(mNet.infos, m)    
            end
        end
    else
        local mVersion = self:GetVersionInfo(iVersion)
        for iOrg, iType in pairs(mVersion) do
            local m = self:PackOrgInfo(iPid, lFriend, iOrg, lApplyOrg, iType)
            if m then
                table.insert(mNet.infos, m)
            end
        end
        mNet.update = 1
    end
    return mNet
end

function CVersion:PackOrgInfo(iPid, lFriend, iOrg, lApplyOrg, iType)
    if iType == gamedefines.VERSION_OP_TYPE.DELETE then
        return {orgid=iOrg, optype=iType}
    end
    
    local mInfo = self.m_mSourceInfo[iOrg]
    if not mInfo then return end

    local mNet = table_copy(mInfo)
    mNet.optype = iType
    if table_in_list(lApplyOrg, iOrg) then
        mNet.hasapply = 1    
    end
    if table_in_list(lFriend or {}, mInfo.leaderid) then
        mNet.isfriend = 1
    end
    return mNet
end


