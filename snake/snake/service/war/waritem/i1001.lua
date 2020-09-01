
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
    if oVictim:HasKey("disable_cure") then
        if oPlayer then
            oPlayer:Notify("无法进行治疗")
        end
        return false
    end
    return true
end

--　增加指定HP
function CWarItem:Action(oAction, oVictim, mArgs, iPid)
    local sFormula = mArgs["hp"]
    local iLevel = mArgs["level"] or 0
    local bDelDeBuff = mArgs["deldebuff"]
    local bDelSeal = mArgs["delseal"]
    if not sFormula then return false end

    local iHp = 0
    if type(sFormula) == "number" then
        iHp = sFormula
    else
        local mEnv = {level=oVictim:GetGrade()}
        iHp = formula_string(sFormula, mEnv)
    end

    local oWar = oAction:GetWar()
    if oWar then
        oWar:AddDebugMsg(string.format("#B%s#n原始加血%d, 当前抗药性%d%%",
            oVictim:GetName(),
            iHp,
            oVictim:QueryAttr("res_drug")
        ))
    end

    local iAddRatio = oAction:Query("usedrug_add_ratio", 0) + oAction:Query("use_cure_drug_add_ratio", 0) + oVictim:Query("cure_drug_add_ratio", 0)
    iHp = iHp + iHp * iAddRatio / 100
    iHp = math.floor(iHp * (oVictim:QueryAttr("res_drug") + 100) / 100)
    iHp = math.max(iHp, 1) 
    local oActionMgr = global.oActionMgr
    oActionMgr:DoAddHp(oVictim, iHp)

    if oAction and oAction:GetWid() ~= oVictim:GetWid() then
        local iReflectHp = math.floor(iHp * oAction:Query("use_drug_reflect_self", 0) / 100)
        if iReflectHp > 0 then
            oActionMgr:DoAddHp(oAction, iReflectHp)
        end
    end

    if oWar then
        oWar:AddDebugMsg(string.format("#B%s#n最终加血%d", oVictim:GetName(), iHp))
    end

    if bDelDeBuff then
        local oBuffMgr = oVictim.m_oBuffMgr
        oBuffMgr:RemoveClassBuff(gamedefines.BUFF_TYPE.CLASS_ABNORMAL, "封印")
    end
    if bDelSeal then
        local oBuffMgr = oVictim.m_oBuffMgr
        oBuffMgr:RemoveClassBuffInclude(gamedefines.BUFF_TYPE.CLASS_ABNORMAL, {["封印"]=1})
    end
    return true
end
