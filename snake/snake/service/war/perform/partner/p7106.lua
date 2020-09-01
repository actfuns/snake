--import module

local global = require "global"
local skynet = require "skynet"
local pfobj = import(service_path("perform/pfobj"))

function NewCPerform(...)
    local o = CPerform:New(...)
    return o
end

--西湖情缘

CPerform = {}
CPerform.__index = CPerform
inherit(CPerform, pfobj.CPerform)

function CPerform:CalWarrior(oAction, oPerformMgr)
    local iPerform = self:Type()
    local func = function(oAttack)
        OnWarStart(iPerform, oAttack)
    end
    oPerformMgr:AddFunction("OnWarStart", self.m_ID, func)
end

function OnWarStart(iPerform, oAttack)
    local oPerform = oAttack:GetPerform(iPerform)
    if not oPerform then return end

    local bAdd = false
    for _, oWarrior in pairs(oAttack:GetFriendList(true)) do
        if oWarrior:IsPartnerLike() and oWarrior:GetData("type") == 10005 and oWarrior:GetName() == "白素贞" then
            bAdd = true
        end
    end

    if bAdd then
        local sExtArg = oPerform:ExtArg()
        local mEnv = oPerform:SkillFormulaEnv(oAttack)
        local mExtArg = formula_string(sExtArg, mEnv)
       
        for _, sKey in pairs({"phy_attack", "phy_defense", "mag_attack", "mag_defense"}) do 
            if mExtArg[sKey] then
                local iVal = math.floor(mExtArg[sKey] * oAttack:GetBaseAttr(sKey) / 100)
                oAttack.m_oPerformMgr:AddAttrAddValue(sKey, iPerform, iVal)
            end
        end 

        if mExtArg.speed_ratio then
            oAttack.m_oPerformMgr:AddAttrAddValue("speed_ratio", iPerform, mExtArg.speed_ratio)
        end

        if mExtArg.hp then
            local iMaxHp = oAttack:GetMaxHp()
            iMaxHp = math.floor(iMaxHp + iMaxHp * mExtArg.hp / 100)
            local iHp = oAttack:GetHp()
            iHp = math.min(math.floor(iHp + iHp * mExtArg.hp / 100), iMaxHp)

            oAttack:SetData("max_hp", iMaxHp)
            oAttack:SetData("hp", iHp)
            oAttack:StatusChange("hp", "max_hp")
        end

        if mExtArg.mp then
            local iMaxMp = oAttack:GetMaxMp()
            iMaxMp = math.floor(iMaxMp + iMaxMp * mExtArg.mp / 100)
            local iMp = oAttack:GetMp()
            iMp = math.min(math.floor(iMp + iMp * mExtArg.mp / 100), iMaxMp)

            oAttack:SetData("max_mp", iMaxMp)
            oAttack:SetData("mp", iMp)
            oAttack:StatusChange("mp", "max_mp")
        end
    end
end

