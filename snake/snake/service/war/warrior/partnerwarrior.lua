
local global = require "global"
local skynet = require "skynet"
local interactive = require "base.interactive"
local net = require "base.net"
local playersend = require "base.playersend"

local gamedefines = import(lualib_path("public.gamedefines"))
local loadai = import(service_path("ai.loadai"))
local CWarrior = import(service_path("warrior.warrior")).CWarrior


function NewPartnerWarrior(...)
    return CPartnerWarrior:New(...)
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


CPartnerWarrior = {}
CPartnerWarrior.__index = CPartnerWarrior 
inherit(CPartnerWarrior, CWarrior)

function CPartnerWarrior:New(iWid, iOwner, iPid)
    local o = super(CPartnerWarrior).New(self, iWid)
    o.m_iType = gamedefines.WAR_WARRIOR_TYPE.PARTNER_TYPE
    o.m_iOwner = iOwner
    o.m_iPid = iPid
    return o
end

function CPartnerWarrior:InitAIType()
    local iAIType = self:GetData("aitype")
    if iAIType then
        self:SetAIType(iAIType)
    else
        local iSchool = self:GetSchool()
        local iAIType = 200 + iSchool
        self:SetAIType(iAIType)
    end
end

function CPartnerWarrior:Leave()
    super(CPartnerWarrior).Leave(self)

    local iOwner = self:GetOwner()
    local oWar = self:GetWar()
    if oWar then
        local oPlayerWarrior = oWar:GetPlayerWarrior(iOwner)
        if oPlayerWarrior then
            local iPartnerID = self:GetData("pid")
            local mInfo = {hp = self:GetData("hp"),mp = self:GetData("mp")}
            oPlayerWarrior:SetUpdateInfo(self.m_iType, iPartnerID,mInfo)
        end
    end
end

function CPartnerWarrior:GetPid()
    return self.m_iPid
end

function CPartnerWarrior:GetOwner()
    return self.m_iOwner
end

function CPartnerWarrior:Send(sMessage, mData)
    playersend.Send(self.m_iPid, sMessage, mData)
end

function CPartnerWarrior:SendRaw(sData)
    playersend.SendRaw(self.m_iPid, sData)
end

function CPartnerWarrior:GetSimpleWarriorInfo()
    return {
        wid = self:GetWid(),
        pid = self:GetPid(),
        pos = self:GetPos(),
        status = self:GetSimpleStatus(),
        buff_list = self:PackBuffList(),
        status_list = self:PackStatusList(),
    }
end

function CPartnerWarrior:GetSimpleStatus(m)
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

function CPartnerWarrior:StatusChange(...)
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

function CPartnerWarrior:GetOwnerWarrior()
    local iOwner = self:GetOwner()
end

function CPartnerWarrior:GetSchool()
    return self:GetData("school")
end

function CPartnerWarrior:CheckChangeCmd(mCmd, sType)
    local mAICmd = mCmd
    if sType == "use" then
        local iAIType = self:GetAIType()
        local oAIObj = loadai.GetAI(iAIType)
        local mRet = oAIObj:Command(self, true)
        if mRet and type(mRet) == "table" then
            mAICmd = mRet
        end
    end

    local mCheckCmd = super(CPartnerWarrior).CheckChangeCmd(self, mAICmd, sType)
    return mCheckCmd and mCheckCmd or mAICmd
end


