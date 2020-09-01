--import module

local global = require "global"
local skynet = require "skynet"

local aibase = import(service_path("ai/aibase"))

function NewAI(...)
    local o = CAI:New(...)
    return o
end

--召唤兽AI

CAI = {}
CAI.__index = CAI
inherit(CAI, aibase.CAI)

function CAI:New(iAI)
    local o = super(CAI).New(self,iAI)
    return o
end

function CAI:ValidCommand(oAction)
    local bValid = super(CAI).ValidCommand(self, oAction)
    return bValid and oAction:IsSummonLike()
end

function CAI:GetNormalAttackTarget(oAction)
    local lTarget = oAction:GetEnemyList(false)
    local oTargetMgr = global.oTargetMgr
    if math.random(100) <= 80 then
        return oTargetMgr:HpMin(oAction, lTarget)
    else
        return oTargetMgr:Random(oAction, lTarget)
    end
end

