
local global = require "global"
local skynet = require "skynet"

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

function CWarItem:CheckAction(oAction, oVictim, mArgs, iPid)
    local oWar = oAction:GetWar()
    local oPlayer = oWar:GetPlayerWarrior(iPid)
    if not oVictim or oVictim:IsDead() then
        if oPlayer then
            oPlayer:Notify("目标死亡无法使用该物品")
        end
        return false
    end

    if not oVictim:IsPlayer() then return false end
        
    return true
end

-- 增加指定怒气
function CWarItem:Action(oAction, oVictim, mArgs, iPid)
    local iSp = mArgs["sp"] or 0
    local iQuality = mArgs["quality"] or 0
    oVictim:AddSP(iSp)
    local oBuffMgr = oVictim.m_oBuffMgr
    if not oBuffMgr:HasBuff(135) then
        oBuffMgr:AddBuff(135, 99, {quality=iQuality})
    end
    return true
end