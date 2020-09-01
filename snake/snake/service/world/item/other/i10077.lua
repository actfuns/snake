local global  = require "global"
local itembase = import(service_path("item/other/otherbase"))

function NewItem(sid)
    local o = CItem:New(sid)
    return o
end

CItem = {}
CItem.__index = CItem
inherit(CItem, itembase.CItem)

function CItem:New(sid)
    local o = super(CItem).New(self,sid)
    return o
end

function CItem:TrueUse(oPlayer)
    if is_ks_server() then
        oPlayer:NotifyMessage("跨服不能使用")
        return
    end

    local oHD =global.oHuodongMgr:GetHuodong("orgtask")
    oHD:FindOrgZhongGuan(oPlayer,2)
end