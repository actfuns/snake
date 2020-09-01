--import module

local global = require "global"
local npcobj = import(service_path("npc/npcobj"))

CNpc = {}
CNpc.__index = CNpc
inherit(CNpc,npcobj.CGlobalNpc)

function CNpc:New(npctype)
    local o = super(CNpc).New(self,npctype)
    return o
end

function CNpc:do_look(oPlayer)
    super(CNpc).do_look(self, oPlayer)
    -- self:DoLookShop(oPlayer)
end

function CNpc:DoLookShop(oPlayer)
    local mOptions = self:GetRegOptions()
    if mOptions and next(mOptions) then
        local sText = self:GetText(oPlayer)
        local npcid = self:ID()
        self:SayRespond(oPlayer:GetPid(), sText .. "&Q商店", nil, function(oPlayer, mData)
            local oNpc = global.oNpcMgr:GetObject(npcid)
            if oNpc then
                oNpc:OnClickNpcOptions(oPlayer, mData)
            end
        end)
    else
        self:OpenMyShop(oPlayer)
    end
end

function CNpc:OnClickNpcOptions(oPlayer, mData)
    if mData.answer == 1 then
        self:OpenMyShop(oPlayer)
    end
end

function CNpc:OpenMyShop(oPlayer)
    local oUIMgr = global.oUIMgr
    oUIMgr:GS2COpenShop(oPlayer, 101)
end

function NewGlobalNpc(npctype)
    local o = CNpc:New(npctype)
    return o
end
