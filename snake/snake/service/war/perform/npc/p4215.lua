
--import module

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
    local func = function(oVictim, oAttack)
        OnDead(oVictim, oAttack)
    end
    oAction:AddFunction("OnDead", self.m_ID, func)
end

function OnDead(oVictim,oAttack)
    if not oVictim:IsDead() then
        return 
    end
    local mFriend = oVictim:GetFriendList() 
    if #mFriend<=0 then
        return
    end
    global.oActionMgr:DoAddHp(oVictim, oVictim:GetMaxHp())
    local oWar = oVictim:GetWar()
    if oWar then
        local mCmd = {
                war_id = oWar:GetWarId(),
                speeks = {
                    {
                        wid = oVictim:GetWid(),
                        content = "官人，你快醒醒啊。",
                    },
                },
                block_ms = 0,
                block_action = 0,
            }
        oWar:SendAll("GS2CWarriorSeqSpeek", mCmd)
    end
end
