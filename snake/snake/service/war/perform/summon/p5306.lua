--import module

local global = require "global"
local skynet = require "skynet"

local gamedefines = import(lualib_path("public.gamedefines"))
local pfobj = import(service_path("perform/summon/pfactive"))


function NewCPerform(...)
    local o = CPerform:New(...)
    return o
end


-- 冰天雪地
CPerform = {}
CPerform.__index = CPerform
inherit(CPerform, pfobj.CPerform)

function CPerform:New(pfid)
    local o = super(CPerform).New(self,pfid)
    return o
end

function CPerform:TruePerform(oAttack, oVictim, iDamageRatio)
    super(CPerform).TruePerform(self, oAttack, oVictim, iDamageRatio)

    if not oVictim then return end

    local sExtArgs = self:ExtArg()
    local mExtAtgs = formula_string(sExtArgs, {attack_grade=oAttack:GetGrade(), victim_grade=oVictim:GetGrade()})
    local iSubMp = mExtAtgs["sub_mp"] or 0
    global.oActionMgr:DoAddMp(oVictim, -iSubMp)
    if oAttack:IsSummon() and oVictim:IsNpcLike() and self:GetTempData("p5306", 0) <= 0 then
        local iAddMp = mExtAtgs["add_mp"] or 0
        local iOwnerWid = oAttack:GetOwnerWid()
        local oOwner = oAttack:GetWarrior(iOwnerWid)
        if oOwner and not oOwner:IsDead() then
            global.oActionMgr:DoAddMp(oOwner, iAddMp)
        end
    end
    self:SetTempData("p5306", 1)
end
