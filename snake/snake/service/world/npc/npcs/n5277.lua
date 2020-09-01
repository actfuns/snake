local global = require "global"
local npcobj = import(service_path("npc/npcobj"))

function NewGlobalNpc(npctype)
    local o = CNpc:New(npctype)
    return o
end

CNpc = {}
CNpc.__index = CNpc
inherit(CNpc, npcobj.CGlobalNpc)


function CNpc:New(npctype)
    local o = super(CNpc).New(self, npctype)
    return o
end

function CNpc:do_look(oPlayer)
    local oToolMgr = global.oToolMgr
    local oHuodong = global.oHuodongMgr:GetHuodong("festivalgift")
    if not oHuodong then return end
    local bIsFestival, iText = oHuodong:ValidGetFestivalGift(oPlayer)
    if iText then
        local sText = oHuodong:GetHuodongTextData(oPlayer,iText)
        local pid = oPlayer:GetPid()
        local npcid = self:ID()
        self:SayRespond(pid, sText, nil ,function(oPlayer, mData)
            local oNpc = global.oNpcMgr:GetObject(npcid)
            if oNpc then
                oNpc:OnClickNpcOptions(oPlayer, mData)
            end
        end)
    end
end


function CNpc:OnClickNpcOptions(oPlayer, mData)
    local iAnswer = mData.answer
    local oHuodong = global.oHuodongMgr:GetHuodong("festivalgift")
    local bIsFestival, _ = oHuodong:ValidGetFestivalGift(oPlayer)
    if not oHuodong then return end
    if bIsFestival and iAnswer == 1 then
        oHuodong:GetFestivalGift(oPlayer)
    elseif not bIsFestival and iAnswer == 1 then
        local sText = oHuodong:GetNextFestivalDialog()
        self:SayRespond(oPlayer:GetPid(), sText, nil, function(oPlayer, mData)
            local oNpc = global.oNpcMgr:GetObject(npcid)
            if oNpc then
                oNpc:OnClickNpcOptions(oPlayer,mData)
            end
        end)
    end
end

