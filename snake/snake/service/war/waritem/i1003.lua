-- 捕捉袋

local global = require "global"
local skynet = require "skynet"
local interactive = require "base.interactive"

local gamedefines = import(lualib_path("public.gamedefines"))
local waritem = import(service_path("waritem/waritembase"))


function NewWarItem(...)
    local o = CWarItem:New(...)
    return o
end

CWarItem = {}
CWarItem.__index = CWarItem
inherit(CWarItem, waritem.CWarItem)

function CWarItem:New(id)
    local o = super(CWarItem).New(self, id)
    return o
end

function CWarItem:RateSucc(iCurValue, lValues, lSuccRates)
    local iSuccRate = lSuccRates[#lSuccRates]
    for idx, iValue in ipairs(lValues) do
        if iCurValue > iValue then
            iSuccRate = lSuccRates[idx]
            break
        end
    end
    return math.random(100) <= iSuccRate
end

function CWarItem:CheckAction(oAction, oVictim, mArgs, iPid)
    -- 玩家、宠物均可使用
    if oVictim:IsDead() then return false end
    if not oVictim:IsNpc() then return false end
    if oAction:GetCampId() == oVictim:GetCampId() then return false end
    
    return true
end

function CWarItem:Action(oAction, oVictim, mArgs)
    -- 玩家、宠物均可使用
    -- if oVictim:IsDead() then return false end
    -- if not oVictim:IsNpc() then return false end
    -- if oAction:GetCampId() == oVictim:GetCampId() then return false end

    local iCurHp = oVictim:GetHp()
    local iMaxHp = oVictim:GetMaxHp()
    local iCurHpRate = iCurHp * 100 / iMaxHp
    local bSucc = true
    local lHpRates = mArgs.hp_rates
    if lHpRates then
        local lSuccRates = mArgs.succ_rates
        bSucc = self:RateSucc(iCurHpRate, lHpRates, lSuccRates)
    end
    local iWarId = oAction:GetWarId()
    -- 广播
    oAction:SendAll("GS2CWarCapture", {
        war_id = iWarId,
        wid = oVictim:GetWid(),
        succ = bSucc and 1 or 0,
    })
    local iVictimTypeSid = oVictim:GetTypeSid()
    if bSucc then
        local oWar = oVictim:GetWar()
        oWar:KickOutWarrior(oVictim)
    end
    if oAction:IsPlayer() then
        -- 回调
        interactive.Send(".world", "war", "OnWarCapture", {
            warid = iWarId,
            target_type = iVictimTypeSid,
            pid = oAction:GetPid(),
            succ = bSucc,
        })
    end
    return true
end
