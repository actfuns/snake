--import module

local global = require "global"
local skynet = require "skynet"

local gamedefines = import(lualib_path("public.gamedefines"))
local CHANNEL_TYPE = gamedefines.CHANNEL_TYPE

function C2GSChat(oPlayer, mData)
    local sMsg = mData.cmd
    local iType = mData.type
    local iForbid = mData.forbid or 0

    local oChatMgr = global.oChatMgr
    oChatMgr:HandlePlayerChat(oPlayer, iType, sMsg, iForbid)
end

function C2GSChuanYin(oPlayer, mData)
    local oChatMgr = global.oChatMgr
    oChatMgr:HandleChuanYin(oPlayer, mData["type"], mData["cmd"])
end

function C2GSMatchTeamChat(oPlayer, mData)
    local iType = mData.type
    local sMsg = mData.cmd

    local oChatMgr = global.oChatMgr
    oChatMgr:HandleMatchTeamChat(oPlayer, sMsg, iType, mData.mingrade, mData.maxgrade, mData.ismatch)    
end


