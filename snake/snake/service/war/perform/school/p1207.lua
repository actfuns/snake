local global = require "global"
local skynet = require "skynet"

local gamedefines = import(lualib_path("public.gamedefines"))
local pfobj = import(service_path("perform/pfobj"))

function NewCPerform(...)
    local o = CPerform:New(...)
    return o
end

CPerform = {}
CPerform.__index = CPerform
inherit(CPerform, pfobj.CPerform)

function CPerform:New(pfid)
    local o = super(CPerform).New(self,pfid)
    return o
end

function CPerform:SelfValidCast(oAttack, oVictim)
    if oAttack:GetWid() == oVictim:GetWid() then
        return false
    end
    local iGhost = oVictim:GetKey("ghost")
    if iGhost and iGhost <= 3 then
        return false
    end
    if oVictim and oVictim:IsDead() then
        if oAttack and oAttack:IsPlayer() then
            oAttack:Notify("目标已倒地，技能无法施放")
        end
        return false
    end

    return true
end

function CPerform:TargetList(oAttack)
    local mRet = super(CPerform).TargetList(self, oAttack)
    local mResult = {}
    for _, oWarrior in ipairs(mRet) do
        if oWarrior:GetWid() == oAttack:GetWid() then
            goto continue
        end
        if oWarrior:HasKey("ghost") and oWarrior:GetKey("ghost") <= 3 then
            goto continue
        end
        table.insert(mResult, oWarrior)
        ::continue::
    end
    return mResult
end

function CPerform:TruePerform(oAttack, oVictim, iDamageRatio)
    if not oVictim or oVictim:IsDead() then return end

    local iHp = oVictim:GetMaxHp() - oVictim:GetHp()
    if iHp < 0 then return end

    local oActionMgr = global.oActionMgr
    oActionMgr:DoAddHp(oVictim, iHp)

    local oBuffMgr = oAttack.m_oBuffMgr
    local iBuffID = 138
    local oBuff = oBuffMgr:HasBuff(iBuffID)
    if oBuff then
        local mAttrs = oBuff:AttrRatioList()
        for _,str in pairs(mAttrs) do
            local key, value = string.match(str,"(.+)=(.+)")
            value = oBuff:CalAttrValue(value)
            local iOld = oBuffMgr:GetAttrBaseRatioByBuff(key, iBuffID)
            value = (100 + iOld) * (100 + value) / 100 - 100
            oBuffMgr:SetAttrBaseRatio(key, iBuffID, value)
        end
    else
        oBuffMgr:AddBuff(iBuffID, 99, {level = self:Level()})
    end
end

function CPerform:NeedVictimTime()
    return false
end

