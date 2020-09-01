local global = require "global"
local httpuse = require "public.httpuse"
local record = require "public.record"
local md5 = require "md5"

local urldefines = import(lualib_path("public.urldefines"))

function NewGamePushMgr(...)
    local o = CGamePushMgr:New(...)
    o:Init()
    return o
end

CGamePushMgr = {}
CGamePushMgr.__index = CGamePushMgr
inherit(CGamePushMgr, logic_base_cls())

function CGamePushMgr:New()
    local o = super(CGamePushMgr).New(self)
    o.m_mData = {}
    return o
end

function CGamePushMgr:Init()
    self:SetData("access_id", 2100264708)
    self:SetData("secret_key", "99d5acd008bb9115275f99f0f22a9b23")
end

function CGamePushMgr:SetData(k, v)
    self.m_mData[k] = v
end

function CGamePushMgr:GetData(k, default)
    return self.m_mData[k] or default
end

function CGamePushMgr:Push(pid, sTitle, sText)
    local host = urldefines.get_out_host()
    local url = urldefines.get_xg_url("single_account")
    local mParam = {}
    mParam.access_id = self:GetData("access_id")    -- 应用唯一标识符
    mParam.timestamp = get_time()                   -- 请求时间戳
    mParam.account = get_server_cluster()..tostring(pid)
    mParam.message_type = 1
    mParam.message = httpuse.mkcontent_json({
        title = sTitle,
        content = sText,
        builder_id = 0,
    })
    local sSign = self:Sign(host, url, mParam)
    mParam.sign = sSign
    local mHeader = {}
    mHeader["Content-type"] = "application/x-www-form-urlencoded"
    local func = function (body, header)
        self:PushResult(pid, body)
    end
    httpuse.post(host, url, httpuse.mkcontent_kv(mParam), func, mHeader)
end

function CGamePushMgr:Sign(host, url, mParam)
    local sStr = "POSTopenapi.xg.qq.com"..string.sub(url, string.len("/xgpush/"))
    local lKey = table_key_list(mParam)
    table.sort(lKey)
    for _, sKey in ipairs(lKey) do
        sStr = sStr..sKey.."="..mParam[sKey]
    end
    local secret_key = self:GetData("secret_key")
    sStr = sStr..secret_key
    return md5.sumhexa(sStr)
end

function CGamePushMgr:PushResult(pid, sBody)
    local mBody = httpuse.content_json(sBody)
    if not mBody or mBody.ret_code ~= 0 then
        record.error(string.format("XGPush err %s %s", pid, sBody))
    end
end

