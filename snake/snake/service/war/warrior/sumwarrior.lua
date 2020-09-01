
local global = require "global"
local skynet = require "skynet"
local interactive = require "base.interactive"
local net = require "base.net"
local res = require "base.res"

local gamedefines = import(lualib_path("public.gamedefines"))
local CWarrior = import(service_path("warrior.warrior")).CWarrior

function NewSummonWarrior(...)
    return CSummonWarrior:New(...)
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

function StatusHelperFunc.auto_perform(o)
    return o:GetAutoPerform()
end

function StatusHelperFunc.is_auto(o)
    return o:GetAutoFight()
end

function StatusHelperFunc.cmd(o)
    local oWar = o:GetWar()
    return oWar:GetBoutCmd(o:GetWid()) and 1 or 0
end

function StatusHelperFunc.grade(o)
    return o:GetData("grade", 0)
end


CSummonWarrior = {}
CSummonWarrior.__index = CSummonWarrior
inherit(CSummonWarrior, CWarrior)

function CSummonWarrior:New(iWid)
    local o = super(CSummonWarrior).New(self, iWid)
    o.m_iType = gamedefines.WAR_WARRIOR_TYPE.SUMMON_TYPE
    o.m_iAIType = gamedefines.AI_TYPE.AUTOPERFORM
    return o
end

function CSummonWarrior:Init(mInit)
    super(CSummonWarrior).Init(self, mInit)

    self:InitAutoPerform()
    self:InitAutoFight()
end

function CSummonWarrior:Leave()
    super(CSummonWarrior).Leave(self)
    local iOwner = self:GetData("owner")
    local oWar = self:GetWar()
    if oWar then
        local oPlayerWarrior = oWar:GetWarrior(iOwner)
        if oPlayerWarrior and oPlayerWarrior:IsPlayer() then
            local iPid
            if oPlayerWarrior:IsPlayer() then
                iPid = oPlayerWarrior:GetPid()
            end
            local iSumid = self:GetData("sum_id")
            local mInfo = {hp = self:GetData("hp"),mp = self:GetData("mp"),pid=iPid}
            oPlayerWarrior:SetUpdateInfo(self.m_iType, iSumid,mInfo)
        end
    end
end

function CSummonWarrior:GetSimpleWarriorInfo()
    return {
        wid = self:GetWid(),
        pos = self:GetPos(),
        pflist = self:PackActivePerform(),
        owner = self:GetData("owner"),
        sum_id = self:GetData("sum_id"),
        status = self:GetSimpleStatus(),
        buff_list = self:PackBuffList(),
        status_list = self:PackStatusList(),
    }
end

function CSummonWarrior:GetSimpleStatus(m)
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

function CSummonWarrior:StatusChange(...)
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

function CSummonWarrior:GetDefaultPerform()
    local f
    f = function (pf1, pf2)
        local oPerform1 = self:GetPerform(pf1)
        local oPerform2 = self:GetPerform(pf2)
        if oPerform1:IsGroupPerform() ~= oPerform2:IsGroupPerform() then
            return oPerform1:IsGroupPerform()
        end
        if oPerform1:Level() ~= oPerform2:Level() then
            return oPerform1:Level() > oPerform2:Level()
        end
        if pf1 ~= pf2 then
            return pf1 > pf2
        end
        return false
    end

    local lPerformList = self:GetActivePerformList()
    if next(lPerformList) then
        table.sort(lPerformList, f)
        return lPerformList[1]
    else
        return 101
    end
end

function CSummonWarrior:IsOpenFight()
    return self.m_iAutoFight
end

function CSummonWarrior:SetAutoFight(auto)
    self.m_iAutoFight = auto
    self:StatusChange("is_auto")
end

function CSummonWarrior:GetAutoFight()
    return self:IsOpenFight() and 1 or 0
end

function CSummonWarrior:SetAutoPerform(iAutoPf)
    self:SetData("auto_perform",iAutoPf)
    self:StatusChange("auto_perform")
    local oWar = self:GetWar()
    if oWar then
        local iOwnerWid = self:GetData("owner")
        local oOwner = oWar:GetWarrior(iOwnerWid)
        if oOwner then
            local iSummid = self:GetData("sum_id")
            oOwner:RecordSummAutoPf(iSummid, iAutoPf)
        end
    end
    if iAutoPf then
        self:SetAutoFight(true)
    else
        self:SetAutoFight(nil)
    end
end

function CSummonWarrior:GetAutoPerform()
    return self:GetData("auto_perform")
end

function CSummonWarrior:InitAutoPerform()
    local iAutoPf = self:GetAutoPerform()
    if not iAutoPf then
        iAutoPf = self:GetDefaultPerform()
        self:SetData("auto_perform", iAutoPf)
    end
end

function CSummonWarrior:InitAutoFight()
    local oWar = self:GetWar()
    if not oWar then return end

    local iAutoStart = oWar:GetAutoStart()
    if iAutoStart == gamedefines.WAR_AUTO_TYPE.FORBID_AUTO then 
        self.m_iAutoFight = nil
    elseif iAutoStart == gamedefines.WAR_AUTO_TYPE.START_AUTO then
        self.m_iAutoFight = 1
    else
        local iOwner = self:GetOwnerWid()
        local oOwner = oWar:GetWarrior(iOwner)
        if not oOwner then return end

        if oOwner:GetData("auto_fight") == 1 then
            self.m_iAutoFight = 1
        else
            self.m_iAutoFight = nil
        end
    end
end

function CSummonWarrior:StartAutoFight()
    local iAutoPf = self:GetAutoPerform()
    if not iAutoPf then
        iAutoPf = self:GetDefaultPerform()
        self:SetAutoPerform(iAutoPf)
    end
    self:SetAutoFight(true)
end

function CSummonWarrior:CancleAutoFight()
    self:SetAutoFight(nil)
end

function CSummonWarrior:GetOwnerWid()
    return self:GetData("owner")
end

function CSummonWarrior:Notify(sMsg)
    local oWar = self:GetWar()
    local iOwner = self:GetOwnerWid()
    local oOwner = oWar:GetWarrior(iOwner)
    if oOwner then
        oOwner:Notify(sMsg)
    end
end

function CSummonWarrior:GetOwner()
    local oWar = self:GetWar()
    local iOwner = self:GetOwnerWid()
    local oOwner = oWar:GetWarrior(iOwner)
    if oOwner then
        return oOwner:GetPid()
    else
        return nil 
    end
end

function CSummonWarrior:RefreshPerformCD(...)
    local iOwner = self:GetOwnerWid()
    local oOwner = oWar:GetWarrior(iOwner)
    if not oOwner then return end

    local lPerform = table.pack(...)
    local lResult = {}
    for _, iPerform in ipairs(lPerform) do
        local oPerform = self:GetPerform(iPerform)
        if oPerform and oPerform:IsActive() then
            local mUnit = {
                pf_id = iPerform,
                cd = oPerform:GetData("CD"),
            }
            table.insert(lResult, mUnit)
        end
    end
    local mNet = {
        wid = self:GetWid(),
        war_id = self.m_iWarId,
        pflist = lResult,
    }
    oOwner:Send("GS2CRefreshPerformCD", mNet)
end

function CSummonWarrior:CheckChangeCmd(mCmd, sType)
    mCmd = self:CheckSummonEscape(mCmd, sType)
    local mNewCmd = super(CSummonWarrior).CheckChangeCmd(self, mCmd, sType)
    if mNewCmd then
        return mNewCmd
    end
    return mCmd
end

function CSummonWarrior:CheckSummonEscape(mCmd, sType)
    if self:HasKey("not_auto_escape") then return mCmd end
    if sType ~= "use" then return mCmd end

    local sCmd = mCmd["cmd"]
    local iRatio = self:GetEscapeRatio(sCmd)
    if math.random(100) <= iRatio then
        mCmd["cmd"] = "escape"
        mCmd["data"] = {action_wid = self:GetWid()}
    end
    return mCmd
end

function CSummonWarrior:GetEscapeRatio(sCmd)
    local mEscape = table_get_depth(res, {"daobiao", "summon", "escape"})
    local iRate = self:GetHp() / self:GetMaxHp() * 100

    local iRatio = 0
    for _,v in pairs(mEscape) do
        if table_in_list(v.war_cmd, sCmd) and iRate <= v.hp_rate then
            iRatio = v.escape_ratio
        end
    end
    return iRatio
end
