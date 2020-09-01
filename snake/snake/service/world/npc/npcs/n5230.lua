--import module

local global = require "global"
local res = require "base.res"
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
    local mRes = res["daobiao"]["ranse"]["text"]
    local sDesc = mRes[5001]["text"]
    local sMenu2 = mRes[6101]["text"]
    local sMenu3 = mRes[6201]["text"]
    local lText = {sDesc, sMenu2, sMenu3}
    if global.oToolMgr:IsSysOpen("SHIZHUANG",oPlayer, true) then
        table.insert(lText, mRes[6206]["text"])
    end
    local sText = table.concat(lText, "&Q")
    local npcid = self:ID()
    local pid = oPlayer:GetPid()
    self:SayRespond(pid,sText,nil, function (oPlayer, mData)
        local oNpcMgr = global.oNpcMgr
        local oNpc = oNpcMgr:GetObject(npcid)
        if oNpc then
            oNpc:Respond(oPlayer, mData)
        end
    end)
end

function CNpc:Respond(oPlayer,mData)
    local sMsg = res["daobiao"]["ranse"]["text"][3005]["text"]
    local LIMIT_RANSE_GRADE = res["daobiao"]["open"]["RANSE"]["p_level"]
    local sSySMsg = string.gsub(sMsg,"#level",LIMIT_RANSE_GRADE)
    local iAnswer = mData["answer"]
    local mNet = {}
    if iAnswer == 1 then
        if not global.oToolMgr:IsSysOpen("RANSE",oPlayer,nil,{plevel_tips = sSySMsg}) then 
            return
        end
        mNet.type = gamedefines.RANSE_TYPE.CLOTHES
        mNet.color = oPlayer.m_oBaseCtrl.m_oWaiGuan:GetCurClothes()
        oPlayer:Send("GS2COpenRanSe",mNet)
   elseif iAnswer == 2 then
        if not global.oToolMgr:IsSysOpen("RANSE",oPlayer,nil,{plevel_tips = sSySMsg}) then 
            return
        end
        mNet.type = gamedefines.RANSE_TYPE.SUMMON
        oPlayer:Send("GS2COpenRanSe",mNet)
    elseif iAnswer == 3 then
        if not global.oToolMgr:IsSysOpen("SHIZHUANG",oPlayer) then   
            return
        end
        oPlayer:Send("GS2COpenRanSe", {type = gamedefines.RANSE_TYPE.SHIZHUANG})
    end
end


function NewGlobalNpc(npctype)
    local o = CNpc:New(npctype)
    return o
end
