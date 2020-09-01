local global = require "global"
local interactive = require "base.interactive"

local serverflag = import(lualib_path("public.serverflag"))
local gamedefines = import(lualib_path("public.gamedefines"))
local gamedb = import(lualib_path("public.gamedb"))


INVITECODE_TABLE = {
    ["E95ED9F2BD69DB37"] = 1,
}

function NewInviteCodeMgr()
    local o = CInviteCodeMgr:New()
    return o
end

CInviteCodeMgr = {}
CInviteCodeMgr.__index = CInviteCodeMgr
inherit(CInviteCodeMgr, logic_base_cls())

function CInviteCodeMgr:New()
    local o = super(CInviteCodeMgr).New(self)
    return o
end

function CInviteCodeMgr:CheckInviteCode(iChannel, sAccount, endfunc)
    if self:NeedInviteCode(iChannel, sAccount) then
        self:_CheckInviteCode1(iChannel, sAccount, endfunc)
    else
        endfunc(0)
    end
end

function CInviteCodeMgr:NeedInviteCode()
    return serverflag.is_open_invite()
end

function CInviteCodeMgr:_CheckInviteCode1(iChannel, sAccount, endfunc)
    local mInfo = {
        module = "invitecodedb",
        cmd = "GetAcountInviteCode",
        cond = {
            channel = iChannel,
            account = sAccount
        },
    }
    gamedb.LoadDb("invitecode", "common", "DbOperate", mInfo,
    function (mRecord, mData)
        global.oInviteCodeMgr:_CheckInviteCode2(mData, endfunc)
    end)
end

function CInviteCodeMgr:_CheckInviteCode2(mData, endfunc)
    local sInviteCode = mData.invitecode
    if not sInviteCode then
        endfunc(1)
        return
    end
    endfunc(0)
end

function CInviteCodeMgr:SetInviteCode(oConn, sInviteCode)
    if oConn.m_oStatus:Get() ~= gamedefines.LOGIN_CONNECTION_STATUS.in_login_account then
        global.oGateMgr:KickConnection(self.m_iHandle)
        return
    end
    local iChannel = oConn:GetChannel()
    local sAccount = oConn:GetAccount()
    local iHandle = oConn:GetNetHandle()

    sInviteCode = string.upper(sInviteCode)
    if not INVITECODE_TABLE[sInviteCode] then
        oConn:Send("GS2CSetInviteCodeResult",{errcode = 1, msg = "邀请码不存在"})
        return
    end

    local mInfo = {
        module = "invitecodedb",
        cmd = "InsertAccountInviteCode",
        data = {
            channel = iChannel,
            account = sAccount,
            invitecode = sInviteCode,
            create_time = get_time()
        },
    }
    gamedb.SaveDb("invitecode", "common", "DbOperate", mInfo)
    oConn:Send("GS2CSetInviteCodeResult",{errcode = 0, msg = "账号已激活"})
    global.oGateMgr:KickConnection(iHandle)
end
