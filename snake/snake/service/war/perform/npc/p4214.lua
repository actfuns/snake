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

function CPerform:CalWarrior(oAction, oPerformMgr)
    local iLevel = self:Level()
    local func = function(oAction)
        OnNewBout(oAction,iLevel)
    end
    oPerformMgr:AddFunction("OnNewBout", self.m_ID, func)
    local func = function (oVictim, oAttack, oPerform, iDamage)
        OnImmuneDamage(oVictim, oAttack, oPerform, iDamage)
    end
    oAction:AddFunction("OnImmuneDamage", self.m_ID, func)
end


function OnNewBout(oAction,iLevel)
    if not ValidTrigger(oAction) then return end
    local oBuffMgr = oAction.m_oBuffMgr
    local oWar = oAction:GetWar()
    if not oWar then return end
    local iBout = oWar.m_iBout
    if iBout %2 == 0 then
        oBuffMgr:AddBuff(174,1,{level = iLevel,action_wid = oAction:GetWid(),})
        local mCmd = {
            war_id = oWar:GetWarId(),
            speeks = {
                {
                    wid = oAction:GetWid(),
                    content = "姐姐，我来守护你",
                },
            },
            block_ms = 0,
            block_action = 0,
        }
        oWar:SendAll("GS2CWarriorSeqSpeek", mCmd)
    end
end

function ValidTrigger(oAction)
    local mFriend = oAction:GetFriendList()
    for _,oVictim in pairs(mFriend) do
        if oVictim:GetPerform(4213) and oAction ~= oVictim then
            return true
        end
    end
    return false
end

function OnImmuneDamage(oVictim, oAttack, oPerform, iDamage)
    if not ValidTrigger(oVictim) then return end
    local oWar = oVictim:GetWar()
    if not oWar then return end
    local iBout = oWar.m_iBout
    if iBout %2 == 1 then
        local oActionMgr = global.oActionMgr
        oActionMgr:DoAddHp(oVictim, iDamage)    
        oVictim:SetBoutArgs("immune_damage", 1)
    end
end
