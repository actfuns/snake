local global = require "global"
local npcobj = import(service_path("npc/npcobj"))

CNpc = {}
CNpc.__index = CNpc
inherit(CNpc, npcobj.CGlobalNpc)

function CNpc:New(npctype)
    local o = super(CNpc).New(self,npctype)
    return o
end

function NewGlobalNpc(npctype)
    local o = CNpc:New(npctype)
    return o
end

function CNpc:do_look(oPlayer)
    if not global.oToolMgr:IsSysOpen("ENGAGE_SYS", oPlayer, true) then
        super(CNpc).do_look(self, oPlayer)
        return 
    end

    local sText, sOptions, lOptions = global.oMarryMgr:GetNpcOptions(oPlayer)
    sText = sText or self:GetText(oPlayer)
    sText = sText .. sOptions
    local npcid = self:ID()
    self:SayRespond(oPlayer:GetPid(), sText, nil, function(oPlayer, mData)
        local oNpc = global.oNpcMgr:GetObject(npcid)
        if oNpc then
            oNpc:OnClickNpcOptions(oPlayer, mData, lOptions)
        end
    end)
end

function CNpc:OnClickNpcOptions(oPlayer, mData, lOptions)
    if not lOptions then return end

    if not global.oToolMgr:IsSysOpen("ENGAGE_SYS", oPlayer) then return end
    
    local iAnswer = mData.answer
    assert(iAnswer <= #lOptions, string.format("n5229 click option error %s, %s", iAnswer, #lOptions))
    global.oMarryMgr:DoOptionFunc(oPlayer, lOptions[iAnswer])
end
