--import module

local global = require "global"
local skynet = require "skynet"
local playersend = require "base.playersend"
local interactive = require "base.interactive"
local record = require "public.record"
local net = require "base.net"

local bigpacket = import(lualib_path("public.bigpacket"))
local tinsert = table.insert

function NewProxy(...)
    local o = CProxy:New(...)
    return o
end

CProxy = {}
CProxy.__index = CProxy
inherit(CProxy, logic_base_cls())

function CProxy:New()
    local o = super(CProxy).New(self)
    return o
end

function CProxy:Init()
end

function CProxy:DoAddSend(mMail, sMessage, mData)
    if type(mData) ~= "table" then
        record.error("sMessage: "..sMessage.." err mData not table")
        return
    end
    local succ = safe_call(self.DoAddSend2,self,mMail,sMessage,mData)
    if not succ then
        record.error("sMessage: "..sMessage.."  mData: "..ConvertTblToStr(mData))
    end
end

function CProxy:DoAddSend2(mMail, sMessage, mData)
    local iGate = mMail.gate
    local iFd = mMail.fd
    if not iGate or not iFd then return end

    local sEncode = playersend.PackData(sMessage,mData)
    net.SendRaw(mMail,sEncode)
end

function CProxy:DoAddSendList(mMail, lData)
    local iGate = mMail.gate
    local iFd = mMail.fd
    if not iGate or not iFd then return end

    for _,info in pairs(lData) do
        if info.message and info.data then
            self:DoAddSend(mMail,info.message,info.data)
        end
    end
end

function CProxy:DoAddSendRaw(mMail, sEncode)
    if type(sEncode) ~= "string" then return end
    local iGate = mMail.gate
    local iFd = mMail.fd
    if not iGate or not iFd then return end
    net.SendRaw(mMail,sEncode)
end

function CProxy:DoAddSendRawList(mMail, lData)
    if not lData then return end
    local iGate = mMail.gate
    local iFd = mMail.fd
    if not iGate or not iFd then return end
    net.SendRawList(mMail,lData)
end