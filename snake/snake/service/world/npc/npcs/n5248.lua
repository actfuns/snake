--import module

local global = require "global"
local npcobj = import(service_path("npc/npcobj"))
local handlenpc = import(service_path("npc/handlenpc"))
local gamedefines = import(lualib_path("public.gamedefines"))

local HDLIST = {"liumai","biwu","threebiwu","singlewar","singlewar_ks", "treasureconvoy"}

CNpc = {}
CNpc.__index = CNpc
inherit(CNpc,npcobj.CGlobalNpc)

function CNpc:New(npctype)
    local o = super(CNpc).New(self, npctype)
    return o
end

function CNpc:do_look(oPlayer)
    local pid = oPlayer:GetPid()
    local sText  = self:GetText(oPlayer)
    local menulist = {}
    for index,hdname in pairs(HDLIST) do
        local hdobj = global.oHuodongMgr:GetHuodong(hdname)
        if hdobj and hdobj:ValidShow(oPlayer) then
            sText = sText .. "Q" .. hdobj:GetNPCMenu()
            table.insert(menulist,index)
        end
    end
    sText = sText .. "Q没事路过"
    local npcid = self:ID()
    self:SayRespond(pid,sText,nil, function (oPlayer, mData)
        local oNpcMgr = global.oNpcMgr
        local oNpc = oNpcMgr:GetObject(npcid)
        if oNpc then
            oNpc:Respond(oPlayer, mData,menulist)
        end
    end)
end

function CNpc:Respond(oPlayer,mData,menulist)
    local iAnswer = mData["answer"]
    iAnswer = menulist[iAnswer]
    local hdname = HDLIST[iAnswer]
    if not hdname then
        return
    end
    local hdobj = global.oHuodongMgr:GetHuodong(hdname)
    if hdobj then
        hdobj:JoinGame(oPlayer,self)
    end
end

function CNpc:GetText(oPlayer)
    local hdobj = global.oHuodongMgr:GetHuodong("singlewar")
    if hdobj and hdobj:ValidShow(oPlayer) then
        return hdobj:GetTextData(1001)
    end
    return super(CNpc).GetText(self, oPlayer)
end

function CNpc:OpenHDSchedule(oPlayer)
    for _, sHuodong in pairs(HDLIST) do
        local oHuodong = global.oHuodongMgr:GetHuodong(sHuodong)
        if oHuodong and oHuodong:ValidShow(oPlayer) then
            oHuodong:OpenHDSchedule(oPlayer:GetPid())
            break
        end
    end
end

function NewGlobalNpc(npctype)
    local o = CNpc:New(npctype)
    return o
end
