
local global = require "global"
local skynet = require "skynet"
local interactive = require "base.interactive"
local net = require "base.net"

local gamedefines = import(lualib_path("public.gamedefines"))
local CWarrior = import(service_path("warrior.warrior")).CWarrior

function NewNpcWarrior(...)
    return CNpcWarrior:New(...)
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

function StatusHelperFunc.title(o)
    return o:GetTitle()
end

CNpcWarrior = {}
CNpcWarrior.__index = CNpcWarrior
inherit(CNpcWarrior, CWarrior)

function CNpcWarrior:New(iWid)
    local o = super(CNpcWarrior).New(self, iWid)
    o.m_iType = gamedefines.WAR_WARRIOR_TYPE.NPC_TYPE
    return o
end

function CNpcWarrior:IsBoss()
    return self:GetData("is_boss")
end

function CNpcWarrior:GetSimpleWarriorInfo()
    return {
        wid = self:GetWid(),
        pos = self:GetPos(),
        status = self:GetSimpleStatus(),
        buff_list = self:PackBuffList(),
        specail_id = self:GetSpecialID(),
        status_list = self:PackStatusList()
    }
end

function CNpcWarrior:GetSimpleStatus(m)
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

function CNpcWarrior:StatusChange(...)
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

function CNpcWarrior:OnSubHp(iSub, iOldHp, bAddSp, oAttack)
    super(CNpcWarrior).OnSubHp(self, iSub, iOldHp, bAddSp, oAttack)
    local oWar = self:GetWar()
    if oWar and self.m_mSubHpToPercentEv then
        local iCurHp = self:GetHp()
        local iMaxHp = self:GetMaxHp()
        -- local iOldHp = iCurHp + iSub
        -- if iOldHp > iMaxHp then
        --     iOldHp = iMaxHp
        -- end

        local mPercentList = table_key_list(self.m_mSubHpToPercentEv)
        -- 降序
        table.sort(mPercentList, function(a,b) return a>b end)
        for _, iPercent in pairs(mPercentList) do
            -- 更低的百分比关心点不用检查了
            if (100 * iCurHp / iMaxHp) >= iPercent then
                break
            elseif (100 * iOldHp / iMaxHp) > iPercent then
                local iMonsterIdx = self:GetTypeSid()
                oWar:TriggerEvent(gamedefines.EVENT.WAR_MONSTER_HP_SUB_TO_PERCENT, {war = oWar, monster = iMonsterIdx, percent = iPercent})
            end
        end
    end
end

-- 这个注册很特殊，不用AddFunction
function CNpcWarrior:RegSubHpToPercent(iPercent)
    table_set_depth(self, {"m_mSubHpToPercentEv"}, iPercent, 1)
end

function CNpcWarrior:GetSpecialID()
    return self:GetData("specialnpc",0)
end
