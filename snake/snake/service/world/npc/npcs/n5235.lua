--import module

local global = require "global"
local npcobj = import(service_path("npc/npcobj"))
local handlenpc = import(service_path("npc/handlenpc"))
local gamedefines = import(lualib_path("public.gamedefines"))

CNpc = {}
CNpc.__index = CNpc
inherit(CNpc,npcobj.CGlobalNpc)

function NewGlobalNpc(npctype)
    local o = CNpc:New(npctype)
    return o
end

function CNpc:New(npctype)
    local o = super(CNpc).New(self, npctype)
    return o
end

-- function CNpc:do_look(oPlayer)
--     local oToolMgr = global.oToolMgr
--     local oHuodongMgr = global.oHuodongMgr
--     local oHuodong = oHuodongMgr:GetHuodong("arena")
--     if not oHuodong then
--         return
--     end
--     local iPid = oPlayer:GetPid()
--     local sText = oHuodong:GetTextData(1002)
--     local fCallBack = function (oPlayer,mData)
--         local iAnswer = mData["answer"]
--         if iAnswer == 1 then
--             self:OpenArenaUI(oPlayer)
--         else
--             sText = oHuodong:GetTextData(1014)
--             oHuodong:SayText(iPid, self, sText)
--         end
--     end
--     self:SayRespond(iPid,sText,nil,fCallBack)
-- end

function CNpc:OpenArenaUI(oPlayer)
    oPlayer:Send("GS2COpenArenaUI", {})
end
