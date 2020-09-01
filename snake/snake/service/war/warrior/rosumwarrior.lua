
local global = require "global"
local skynet = require "skynet"
local interactive = require "base.interactive"
local net = require "base.net"

local gamedefines = import(lualib_path("public.gamedefines"))
local CWarrior = import(service_path("warrior.warrior")).CWarrior

function NewRoSummonWarrior(...)
    return CRoSummonWarrior:New(...)
end

StatusHelperFunc = {}

function StatusHelperFunc.hp(o)
    return o:GetHp()
end

function StatusHelperFunc.mp(o)
    return o:GetMp()
end

function StatusHelperFunc.max_hp(o)
    return o:GetMaxHp()
end

function StatusHelperFunc.max_mp(o)
    return o:GetMaxMp()
end

function StatusHelperFunc.model_info(o)
    return o:GetModelInfo()
end

function StatusHelperFunc.name(o)
    return o:GetName()
end

function StatusHelperFunc.status(o)
    return o.m_oStatus:Get()
end

function StatusHelperFunc.grade(o)
    return o:GetData("grade", 0)
end


CRoSummonWarrior = {}
CRoSummonWarrior.__index = CRoSummonWarrior
inherit(CRoSummonWarrior, CWarrior)

function CRoSummonWarrior:New(iWid)
    local o = super(CRoSummonWarrior).New(self, iWid)
    o.m_iType = gamedefines.WAR_WARRIOR_TYPE.ROSUMMON_TYPE
    o.m_iAIType = gamedefines.AI_TYPE.SUMMON_AI
    return o
end

function CRoSummonWarrior:GetSimpleWarriorInfo()
    return {
        wid = self:GetWid(),
        pos = self:GetPos(),
        status = self:GetSimpleStatus(),
        buff_list = self:PackBuffList(),
        status_list = self:PackStatusList(),
    }
end

function CRoSummonWarrior:GetSimpleStatus(m)
    local mRet = {}
    if not m then
        m = StatusHelperFunc
    end
    for k, _ in pairs(m) do
        local f = assert(StatusHelperFunc[k], string.format("GetSimpleStatus fail f get %s", k))
        mRet[k] = f(self)
    end
    return net.Mask("base.WarriorStatus", mRet)
end

function CRoSummonWarrior:StatusChange(...)
    local l = table.pack(...)
    local m = {}
    for _, v in ipairs(l) do
        m[v] = true
    end
    local mStatus = self:GetSimpleStatus(m)
    self:SendAll("GS2CWarWarriorStatus", {
        war_id = self:GetWarId(),
        wid = self:GetWid(),
        type = self:Type(),
        status = mStatus,
    })
end
