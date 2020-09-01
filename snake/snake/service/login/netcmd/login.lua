--import module

local global = require "global"
local skynet = require "skynet"
local interactive = require "base.interactive"

local gamedefines = import(lualib_path("public.gamedefines"))

function C2GSQueryLogin(oConn,mData)
    local oGateMgr = global.oGateMgr
    if oGateMgr:IsMaintain() then
        oConn:Send("GS2CLoginError", {pid = 0, errcode = gamedefines.ERRCODE.in_maintain})
        return
    end
    oConn:QueryLogin(mData)
end

function C2GSGMLoginPid(oConn, mData)
    local oGateMgr = global.oGateMgr
    if oGateMgr:IsMaintain() then
        oConn:Send("GS2CLoginError", {pid = 0, errcode = gamedefines.ERRCODE.in_maintain})
        return
    end
    oConn:GMLoginPid(mData)
end

function C2GSLoginAccount(oConn, mData)
    local oGateMgr = global.oGateMgr
    if oGateMgr:IsMaintain() then
        oConn:Send("GS2CLoginError", {pid = 0, errcode = gamedefines.ERRCODE.in_maintain})
        return
    end
    oConn:LoginAccount(mData)
end

function C2GSLoginRole(oConn, mData)
    local oGateMgr = global.oGateMgr
    if not oGateMgr:IsOpen() then
        if oGateMgr:IsPreCreateRole() then
            oConn:PreCreateRoleAnnounce(1107)
            return
        elseif not oGateMgr:ValidPlayerLogin(oConn:GetAccount(), oConn:GetChannel(), oConn.m_sIP) then
            oConn:Send("GS2CLoginError", {pid = 0, errcode = gamedefines.ERRCODE.in_maintain})
            return
        end
    end
    oConn:LoginRole(mData)
end

function C2GSCreateRole(oConn, mData)
    local oGateMgr = global.oGateMgr
    if not oGateMgr:IsMaintain() then
        if not oGateMgr:IsPreCreateRole() and not oGateMgr:ValidPlayerLogin(oConn:GetAccount(), oConn:GetChannel(), oConn.m_sIP) then
            oConn:Send("GS2CLoginError", {pid = 0, errcode = gamedefines.ERRCODE.in_maintain, cmd = ""})
            return
        end
    end
    
    oConn:CreateRole(mData)
end

function C2GSQuitLoginQueue(oConn, mData)
    local oGateMgr = global.oGateMgr
    if not oGateMgr:IsOpen() then
        return
    end
    oConn:QuitLoginQueue(mData)
end

function C2GSGetLoginWaitInfo(oConn, mData)
    local pid = oConn:GetLoginPendingRole()
    if not pid then
        return
    end
    local oLoginQueueMgr = global.oLoginQueueMgr
    oLoginQueueMgr:GS2CLoginPendingUI(pid)
end

function C2GSReLoginRole(oConn, mData)
    oConn:ReLoginRole(mData)
end

function C2GSSetInviteCode(oConn, mData)
    local sInviteCode = mData.invite_code
    global.oInviteCodeMgr:SetInviteCode(oConn, sInviteCode)
end

function C2GSKSLoginRole(oConn, mData)
    oConn:KSLoginRole(mData)
end

function C2GSBackLoginRole(oConn, mData)
    oConn:BackLoginRole(mData)
end