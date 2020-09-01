local global = require "global"
local net = require "base.net"

local gamedefines = import(lualib_path("public.gamedefines"))
local CWarrior = import(service_path("warrior.warrior")).CWarrior

function NewRoPlayerWarrior(...)
    return CRoPlayerWarrior:New(...)
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

function StatusHelperFunc.aura(o)
    return o:GetAura()
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


CRoPlayerWarrior = {}
CRoPlayerWarrior.__index = CRoPlayerWarrior
inherit(CRoPlayerWarrior, CWarrior)

function CRoPlayerWarrior:New(iWid, iPid)
    local o = super(CRoPlayerWarrior).New(self, iWid)
    o.m_iType = gamedefines.WAR_WARRIOR_TYPE.ROPLAYER_TYPE
    o.m_iSP = 50
    return o
end

function CRoPlayerWarrior:InitAIType()
    local iAIType = self:GetData("aitype")
    if iAIType then
        self:SetAIType(iAIType)
    else
        local iSchool = self:GetSchool()
        local iAIType = 200 + iSchool
        self:SetAIType(iAIType)
    end
end

function CRoPlayerWarrior:GetSimpleWarriorInfo()
    return {
        wid = self:GetWid(),
        pos = self:GetPos(),
        status = self:GetSimpleStatus(),
        buff_list = self:PackBuffList(),
        status_list = self:PackStatusList()
    }
end

function CRoPlayerWarrior:GetSimpleStatus(m)
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

function CRoPlayerWarrior:StatusChange(...)
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

function CRoPlayerWarrior:GetMaxSp()
    return 150
end

function CRoPlayerWarrior:GetSP()
    return self.m_iSP
end

function CRoPlayerWarrior:AddSP(iSP)
    self.m_iSP = math.min(self.m_iSP + iSP, self:GetMaxSp())
    self.m_iSP = math.max(0, self.m_iSP)
end

function CRoPlayerWarrior:OnSubHp(iSubHp, iOldHp, bAddSp, oAttack)
    super(CRoPlayerWarrior).OnSubHp(self, iSubHp, iOldHp, bAddSp, oAttack)
    if self:IsDead() then
        self.m_iSP = 0
        return
    end
    if not bAddSp then return end

    local iSP
    local iRatio = (iSubHp * 100 ) // self:GetMaxHp()
    if iRatio >=3 and iRatio < 10 then
        iSP = 3
    elseif iRatio>= 10 and iRatio < 20 then
        iSP = 10
    elseif iRatio >= 20 and iRatio < 30 then
        iSP = 15
    elseif iRatio >= 30 and iRatio < 50 then
        iSP = 25
    elseif iRatio >= 50 and iRatio < 80 then
        iSP = 40
    elseif iRatio >= 80 then
        iSP = 55
    end
    if not iSP then
        return
    end
    self:AddSP(iSP)
end

function CRoPlayerWarrior:GetAura()
    return self:GetExtData("aura",0)
end

function CRoPlayerWarrior:AddAura(iAura)
    iAura = iAura or 1
    local v = self:GetExtData("aura",0)
    if v >= 3 then
        return
    end
    v = v + iAura
    self:SetExtData("aura",v)
    self:StatusChange("aura")
end

function CRoPlayerWarrior:GetFriendProtector()
    return self:GetData("protectors",{})
end

function CRoPlayerWarrior:GetGuard()
    local oGuard = super(CRoPlayerWarrior).GetGuard(self)
    if oGuard then return oGuard end

    -- local oWar = self:GetWar()
    -- local mProtect = self:GetFriendProtector()
    -- for pid, iRatio in pairs(mProtect) do
    --     if math.random(10000) <= iRatio then
    --         return oWar:GetPlayerWarrior(pid)
    --     end
    -- end
end

function CRoPlayerWarrior:GetPid()
    return self.m_mData["pid"]
end

function CRoPlayerWarrior:GetSchool()
    return self:GetData("school")
end

function CRoPlayerWarrior:IsOpenFight()
    return 1
end

function CRoPlayerWarrior:Notify(sMsg)
end
