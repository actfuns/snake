--import module
local global = require "global"
local res = require "base.res"
local extend = require "base.extend"

local gamedefines = import(lualib_path("public.gamedefines"))
local friendobj = import(service_path("friendobj"))


function NewFriendMgr(...)
    local o = CFriendMgr:New(...)
    return o
end

CFriendMgr = {}
CFriendMgr.__index = CFriendMgr
inherit(CFriendMgr, friendobj.CFriendMgr)

function CFriendMgr:New()
    local o = super(CFriendMgr).New(self)
    return o
end

function CFriendMgr:StartRecommend(oPlayer)
    -- ks recommend　服务器没起
end

function CFriendMgr:QueryFriendProfile(oPlayer, lList)
    local oWorldMgr = global.oWorldMgr
    local iPid = oPlayer:GetPid()
    local sServerKey = oWorldMgr:GetServerKey(iPid)
    for _,v in pairs(lList) do
        oWorldMgr:SetServerKey(v, sServerKey)
    end
    super(CFriendMgr).QueryFriendProfile(self, oPlayer, lList)
end
