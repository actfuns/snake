
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
    return true
end

-- 增加指定魔法值
function CWarItem:Action(oAction, oVictim, mArgs, iPid)
    local iMp = 0
    local sFormula = mArgs["mp"]
    if type(sFormula) == "number" then
        iMp = sFormula
    else
        local mEnv = {level=oVictim:GetGrade()}
        iMp = formula_string(sFormula, mEnv)
    end

    iMp = iMp + iMp * oAction:Query("usedrug_add_ratio", 0) / 100
    iMp = math.floor(iMp * (oVictim:QueryAttr("res_drug") + 100) / 100)
    iMp = math.max(iMp, 1) 
    global.oActionMgr:DoAddMp(oVictim, iMp)

    if oAction and oAction:GetWid() ~= oVictim:GetWid() then
        local iReflectMp = math.floor(iMp * oAction:Query("use_drug_reflect_self", 0) / 100)
        if iReflectMp > 0 then
            global.oActionMgr:DoAddMp(oAction, iReflectMp)
        end
    end

    return true
end
