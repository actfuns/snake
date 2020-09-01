local global = require "global"
local skynet = require "skynet"
local extend = require "base.extend"

local buffbase = import(service_path("buff/buffbase"))
local gamedefines = import(lualib_path("public.gamedefines"))

function NewBuff(...)
    local o = CBuff:New(...)
    return o
end

CBuff = {}
CBuff.__index = CBuff
inherit(CBuff, buffbase.CBuff)

function CBuff:OnBoutEnd(oAction,oBuffMgr)
    if not oAction or oAction:IsDead() then return end
    local oWar = oAction:GetWar()
    if not oWar then return end

    local oAttack = oWar:GetWarrior(self:ActionWid())
    local iGrade = oAttack and oAttack:GetGrade() or 60
    local iLimit = iGrade * 15
    local iCurHp = oAction:GetHp()
    local iHp = iCurHp*math.random(5,10)/100 + self:PerformLevel()*50
    iHp = iHp - (iHp * oAction:Query("res_poison_ratio", 0) / 100)
    iHp = math.floor(math.min(iLimit, iHp))
    if iCurHp <= iHp then
        oAction:SetBoutArgs("poison_die", 1)
    end
    global.oActionMgr:DoSubHp(oAction, iHp, oAttack)

    if not oAction:IsPlayerLike() or oAction:GetAura() <= 0 then return end

    if math.random(100) <= (self:GetAttr("aura_ratio") or 0) then
        if oAttack and oAttack:IsPlayerLike() and oAttack:IsAlive() and oAttack:GetData("school") == gamedefines.PLAYER_SCHOOL.YAOCHI then
            oAction:AddAura(-1)
            oAttack:AddAura(1)
        end
    end
end
