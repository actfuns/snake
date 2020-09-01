--import module

local global = require "global"
local skynet = require "skynet"

local gamedefines = import(lualib_path("public.gamedefines"))
local pfobj = import(service_path("perform/pfobj"))


function NewCPerform(...)
    local o = CPerform:New(...)
    return o
end

--究极反击

CPerform = {}
CPerform.__index = CPerform
inherit(CPerform, pfobj.CPerform)

function CPerform:CalWarrior(oAction, oPerformMgr)
    local func = function(oVictim, oAction, oPerform, iDamage, mArgs)
        OnReceiveDamage(oVictim, oAction, oPerform, iDamage, mArgs)
    end
    oPerformMgr:AddFunction("OnReceiveDamage", self.m_ID, func)
end

function OnReceiveDamage(oVictim, oAttack, oPerform, iDamage, mArgs)
    if not oVictim or oVictim:IsDead() then return end
    if iDamage <= 0 then return end

    local oWar = oVictim:GetWar()
    if not oWar then return end

    if not oAttack then return end

    local bNormalAttack = mArgs and mArgs.normal_attack == 1
   
    if oPerform then
        if oPerform:IsGroupPerform() then return end
    else
        if not bNormalAttack then return end
    end 

    if oAttack and oAttack:Query("sneak", 0) == 1 then return end

    --必定暴击
    oVictim:AddBoutArgs("mag_critical_ratio", 10000)
    oVictim:AddBoutArgs("phy_critical_ratio", 10000)

    local mNet = {
        war_id = oWar:GetWarId(),
        speeks = {
            {
                content = "凭你也敢伤我！",
                wid = oVictim:GetWid(),
            },
        },
        block_ms = 0,
        block_action = 0,
    }
    oWar:SendAll("GS2CWarriorSeqSpeek", mNet)

    oVictim:SetBoutArgs("beat_back", 1)
    local lPerform = oVictim:GetActivePerformList()
    if #lPerform > 0 then
        local oPerform = oVictim:GetPerform(lPerform[math.random(#lPerform)])
        oPerform:Perform(oVictim, {oAttack})
    else
        if oPerform and not oPerform:IsNearAction() then
            global.oActionMgr:WarNormalAttack(oVictim, oAttack, {bNotBack=true})
        else
            global.oActionMgr:WarNormalAttack(oVictim, oAttack, {bNotBack=true, perform_time=700})
        end
    end
    oVictim:SetBoutArgs("beat_back", nil)
end
