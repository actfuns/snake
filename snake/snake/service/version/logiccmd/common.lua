--import module
local global = require "global"
local skynet = require "skynet"
local interactive = require "base.interactive"
local extend = require "base.extend"
local netproto = require "base.netproto"
local playersend = require "base.playersend"

local gamedefines = import(lualib_path("public.gamedefines"))

ForwardNetcmds = {}

function ForwardNetcmds.C2GSOrgList(sVerType, iPid, mData)
    local oVersionMgr = global.oVersionMgr
    local oVersion = oVersionMgr:GetVersionObj(sVerType)
    assert(oVersion, string.format("not find orglist version"))

    local mNet = oVersion:PackOrgList(mData)
    playersend.Send(iPid, "GS2COrgList", mNet)
end

function ForwardNetcmds.C2GSOrgMemberList(sVerType, iPid, mData)
    local oVersionMgr = global.oVersionMgr
    local oVersion = oVersionMgr:GetVersionObj(sVerType)
    assert(oVersion, string.format("not find orgmember version %s", sVerType))

    local mNet = oVersion:PackOrgMember(mData)
    playersend.Send(iPid, "GS2COrgMemberInfo", mNet)
end

function Forward(mRecord, mData)
    local sVerType = mData["ver_type"]
    local iPid = mData["pid"]
    local sCmd = mData["cmd"]
    local mArgs = mData["data"]
    local func = ForwardNetcmds[sCmd]
    assert(func, string.format("version service common not find forward %s", sCmd))

    if func then
        func(sVerType, iPid, mArgs)
    end
end

function PushDataToVersion(mRecord, mData)
    local sVerType = mData["ver_type"]
    local opType = mData["op_type"]
    local mInfo = mData["info"]
    local infoKey = mData["info_key"]
    local oVersionMgr = global.oVersionMgr
    local oVersion = oVersionMgr:GetVersionObj(sVerType)    
    if not oVersion then return end

    if opType == gamedefines.VERSION_OP_TYPE.ADD then
        oVersion:Add(infoKey, mInfo)
    elseif opType == gamedefines.VERSION_OP_TYPE.DELETE then
        oVersion:Delete(infoKey)
    elseif opType == gamedefines.VERSION_OP_TYPE.UPDATE then
        oVersion:Update(infoKey, mInfo)
    end
end

function CreateVersionObj(mRecord, mData)
    local sVerKey = mData["ver_type"]
    local sModule = mData["module_name"]
    local mInfo = mData["data"]
    
    local oVersionMgr = global.oVersionMgr
    local oVersion = oVersionMgr:CreateVersionObj(sVerKey, sModule, mInfo)
end

function CommitVersion(mRecord, mData)
    local sVerKey = mData["ver_type"]
    local oVersionMgr = global.oVersionMgr
    local oVersion = oVersionMgr:GetVersionObj(sVerKey)    
    if not oVersion then return end    

    oVersion:Commit()
end

function DeleteVersion(mRecord, mData)
    local sVerKey = mData["ver_type"]
    global.oVersionMgr:DeleteVersionObj(sVerKey)
end
