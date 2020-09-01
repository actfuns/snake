
local global = require "global"
local skynet = require "skynet"
local interactive = require "base.interactive"
local net = require "base.net"

local loadai = import(service_path("ai.loadai"))
local gamedefines = import(lualib_path("public.gamedefines"))
local CWarrior = import(service_path("warrior.warrior")).CWarrior


function NewRoPartnerWarrior(...)
    return CRoPartnerWarrior:New(...)
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

function StatusHelperFunc.school(o)
    return o:GetData("school", 0)
end

function StatusHelperFunc.grade(o)
    return o:GetData("grade", 0)
end


CRoPartnerWarrior = {}
CRoPartnerWarrior.__index = CRoPartnerWarrior 
inherit(CRoPartnerWarrior, CWarrior)

function CRoPartnerWarrior:New(iWid)
    local o = super(CRoPartnerWarrior).New(self, iWid)
    o.m_iType = gamedefines.WAR_WARRIOR_TYPE.ROPARTNER_TYPE
    return o
end

function CRoPartnerWarrior:GetSimpleWarriorInfo()
    return {
        wid = self:GetWid(),
        pos = self:GetPos(),
        status = self:GetSimpleStatus(),
        buff_list = self:PackBuffList(),
        status_list = self:PackStatusList()
    }
end

function CRoPartnerWarrior:InitAIType()
    local iAIType = self:GetData("aitype")
    if iAIType then
        self:SetAIType(iAIType)
    else
        local iSchool = self:GetSchool()
        local iAIType = 200 + iSchool
        self:SetAIType(iAIType)
    end
end

function CRoPartnerWarrior:GetSimpleStatus(m)
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

function CRoPartnerWarrior:StatusChange(...)
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

function CRoPartnerWarrior:GetOwner()
    return self.m_mData["owner"]
end

function CRoPartnerWarrior:GetPid()
    return tonumber(self.m_mData["pid"])
end

function CRoPartnerWarrior:GetSchool()
    return self:GetData("school")
end

function CRoPartnerWarrior:CheckChangeCmd(mCmd, sType)
    local mAICmd = mCmd
    if sType == "use" then
        local iAIType = self:GetAIType()
        local oAIObj = loadai.GetAI(iAIType)
        local mRet = oAIObj:Command(self, true)
        if mRet and type(mRet) == "table" then
            mAICmd = mRet
        end
    end

    local mCheckCmd = super(CRoPartnerWarrior).CheckChangeCmd(self, mAICmd, sType)
    return mCheckCmd and mCheckCmd or mAICmd
end


