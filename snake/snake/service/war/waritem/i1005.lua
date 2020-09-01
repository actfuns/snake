
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
    if not oVictim then return false end
    
    if not oVictim:IsDead() then
        if oPlayer then
            oPlayer:Notify("目标未死亡不需要复活")
        end
        return false
    end 
    if oVictim:HasKey("revive_disable") then
        if oPlayer then
            oPlayer:Notify("有鬼魂技能不能被复活")
        end
        return false
    end
    return true
end

-- 复活
function CWarItem:Action(oAction, oVictim, mArgs, iPid)
    local sFormula = mArgs["hp"]
    local bDelDeBuff = mArgs["deldebuff"]

    local iHp = 0
    if type(sFormula) == "number" then
        iHp = sFormula
    else
        local mEnv = {level=oVictim:GetGrade()}
        iHp = formula_string(sFormula, mEnv)
    end

    iHp = iHp + iHp * oAction:Query("usedrug_add_ratio", 0) / 100
    iHp = math.floor(iHp)
    local oActionMgr = global.oActionMgr
    oActionMgr:DoAddHp(oVictim, iHp)

    if oAction and oAction:GetWid() ~= oVictim:GetWid() then
        local iReflectHp = math.floor(iHp * oAction:Query("use_drug_reflect_self", 0) / 100)
        if iReflectHp > 0 then
            oActionMgr:DoAddHp(oAction, iReflectHp)
        end
    end
    return true
end
