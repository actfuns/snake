--import module
local global = require "global"

local npcobj = import(service_path("org/orgnpc"))


function NewOrgNpc(npctype, orgid)
    local o = COrgNpc:New(npctype, orgid)
    return o
end

COrgNpc = {}
COrgNpc.__index = COrgNpc
inherit(COrgNpc, npcobj.COrgNpc)

function COrgNpc:New(type, orgid)
    local o = super(COrgNpc).New(self, type, orgid)
    return o
end

function COrgNpc:do_look(oPlayer)
    if self:OrgID() ~= oPlayer:GetOrgID() then
        oPlayer:NotifyMessage("不是本帮成员")
        return
    end
    local pid = oPlayer:GetPid()
    local sText  = self:GetText(oPlayer)
    sText = string.format("%s&Q%sQ%s", sText, "珍宝阁", "路过")
    local npcid = self:ID()
    self:SayRespond(pid,sText,nil, function (oPlayer, mData)
        local oNpcMgr = global.oNpcMgr
        local oNpc = oNpcMgr:GetObject(npcid)
        if oNpc then
            oNpc:Respond(oPlayer, mData)
        end
    end)
end

function COrgNpc:Respond(oPlayer,mData)
    local iAnswer = mData["answer"]
    if iAnswer == 1 then
        local oOrg = oPlayer:GetOrg()
        if not oOrg then return end

        local iBid = 102
        local oShop = oOrg:GetBuildById(iBid)
        if not oShop then
            oPlayer:NotifyMessage(global.oOrgMgr:GetOrgText(4007))
        else
            oPlayer:Send("GS2COpenOrgBuild", {bid = iBid})
        end
    end
end