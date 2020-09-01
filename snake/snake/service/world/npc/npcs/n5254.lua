--import module

local global = require "global"
local npcobj = import(service_path("npc/npcobj"))
local handlenpc = import(service_path("npc/handlenpc"))
local gamedefines = import(lualib_path("public.gamedefines"))

CNpc = {}
CNpc.__index = CNpc
inherit(CNpc,npcobj.CGlobalNpc)

function CNpc:New(npctype)
    local o = super(CNpc).New(self, npctype)
    return o
end

function CNpc:do_look(oPlayer)
    local pid = oPlayer:GetPid()
    local sText  = "我发现了一个神奇的地方，你要和我一起去看看么"
    local sMenu1 = "六道传说"
    local sMenu2 = "便捷组队"
    local sMenu3 = self:GetMenu3Text(oPlayer)
    if sMenu3 then
        sText = string.format("%s&Q%s&Q%s&Q%s", sText,sMenu1,sMenu2,sMenu3)
    else
        sText = string.format("%s&Q%s&Q%s", sText,sMenu1,sMenu2)
    end
    local npcid = self:ID()
    self:SayRespond(pid,sText,nil, function (oPlayer, mData)
        local oNpcMgr = global.oNpcMgr
        local oNpc = oNpcMgr:GetObject(npcid)
        if oNpc then
            oNpc:Respond(oPlayer, mData)
        end
    end)
end

function CNpc:GetMenu3Text(oPlayer)
    local bWhite = global.oServerMgr:IsWhiteListAccount(oPlayer:GetAccount(), oPlayer:GetChannel())
    if not bWhite and not global.oToolMgr:IsSysOpen("KS_SYS", oPlayer, true) then
        return
    end

    if is_ks_server() then
        return "退出跨服"
    end
    return "进入跨服"
end

function CNpc:Respond(oPlayer,mData)
    local iAnswer = mData["answer"]
    if iAnswer ==1 then 
        oPlayer:Send("GS2COpenFBChoice",{flag = 2})
    elseif iAnswer == 2 then
        oPlayer:Send("GS2COpenTeamAutoMatchUI",{auto_target=1200})
    elseif iAnswer == 3 then
        if is_ks_server() then
            global.oWorldMgr:TryBackGS(oPlayer)
        else
            local sKsServer = global.oKuaFuMgr:GetKuaFuServer("fuben_ks")
            global.oKuaFuMgr:TryEnterKS(oPlayer, sKsServer, {})
        end
    end
end

function NewGlobalNpc(npctype)
    local o = CNpc:New(npctype)
    return o
end
