--import module
local res = require "base.res"
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
    local sText  = res["daobiao"]["dialog_npc"][self.m_iDialog]["dialogContent1"]

    if global.oToolMgr:IsSysOpen("RECOVERY",oPlayer,true) then    
        local sMenu1 = "找回丢失的装备"
        local sMenu2 = "找回丢失的宠物"
        sText = string.format("%s&Q%s&Q%s", sText,sMenu1,sMenu2)
    end
    local npcid = self:ID()
    self:SayRespond(pid,sText,nil, function (oPlayer, mData)
        local oNpcMgr = global.oNpcMgr
        local oNpc = oNpcMgr:GetObject(npcid)
        if oNpc then
            oNpc:Respond1(oPlayer, mData)
        end
    end)
end

function CNpc:Respond1(oPlayer,mData)
    local iAnswer = mData["answer"]
    if iAnswer == 1 then 
        oPlayer.m_mRecoveryCtrl:OpenRecoveryItem()
    elseif iAnswer == 2 then
        oPlayer.m_mRecoveryCtrl:OpenRecoverySum()
    end
end


function NewGlobalNpc(npctype)
    local o = CNpc:New(npctype)
    return o
end