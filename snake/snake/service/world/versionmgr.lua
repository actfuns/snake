local global = require "global"
local interactive = require "base.interactive"
local record = require "public.record"

local gamedefines = import(lualib_path("public.gamedefines"))

function NewVersionMgr(...)
    return CVersionMgr:New(...)
end

CVersionMgr = {}
CVersionMgr.__index = CVersionMgr
inherit(CVersionMgr, logic_base_cls())

function CVersionMgr:New(...)
    local o = super(CVersionMgr).New(self)
    return o
end

function CVersionMgr:CreateVersionObj(sVerType, sModule, mInfo)
    interactive.Send(".version", "common", "CreateVersionObj", {
        ver_type = sVerType,
        module_name = sModule,
        data = mInfo,
    })
end

function CVersionMgr:PushDataToVersion(sVerType, iOpType, key, mInfo)
    interactive.Send(".version", "common", "PushDataToVersion", {
        ver_type = sVerType,
        op_type = iOpType,
        info_key = key,
        info = mInfo    
    })
end

function CVersionMgr:CommitVersion(sVerType)
    interactive.Send(".version", "common", "CommitVersion", {
        ver_type = sVerType,
    })
end

function CVersionMgr:DeleteVersion(sVerType)
    interactive.Send(".version", "common", "DeleteVersion", {
        ver_type = sVerType,
    })
end

function CVersionMgr:Forward(sVerType, iPid, sCmd, mArgs)
    interactive.Send(".version", "common", "Forward", {
        ver_type = sVerType,  
        pid = iPid,
        cmd = sCmd,
        data = mArgs,
    })
end

function CVersionMgr:C2GSOrgList(oPlayer, iVersion)
    local iPid = oPlayer:GetPid()
    local mFriends = oPlayer:GetFriend():GetFriends()
    local lApplyOrg = global.oOrgMgr:GetApplyOrgList(oPlayer:GetPid())
    local mArgs = {
        pid = oPlayer:GetPid(),
        friends = table_key_list(mFriends),
        version = iVersion,
        applylist = lApplyOrg 
    }
    self:Forward(self:GetOrgListType(), iPid, "C2GSOrgList", mArgs)
end

function CVersionMgr:C2GSOrgMemberList(oPlayer, iVersion)
    local iPid = oPlayer:GetPid()
    local mArgs = {
        version = iVersion,
    }
    self:Forward(self:GetOrgMemberType(oPlayer:GetOrgID()), iPid, "C2GSOrgMemberList", {})
end

function CVersionMgr:GetOrgListType()
    return "orglist"
end

function CVersionMgr:GetOrgMemberType(iOrg)
    return "orgmember"..iOrg
end
