local global = require "global"
local skynet = require "skynet"
local interactive =  require "base.interactive"

local itembase = import(service_path("item/other/otherbase"))

CItem = {}
CItem.__index = CItem
inherit(CItem,itembase.CItem)

function CItem:New(sid)
    local o = super(CItem).New(self,sid)
    return o
end

function NewItem(sid)
    local o = CItem:New(sid)
    return o
end

function CItem:TrueUse(who, target, iAmount, mArgs)
    local sReason = "test"
    self:AddAmount(-self:GetAmount(),sReason)
    local iRandom = math.random(100)
    if iRandom < 30 then
        who:RewardExp(100,sReason)
    elseif iRandom < 60 then
        who:RewardSilver(100,sReason)
    end
    return true
end
