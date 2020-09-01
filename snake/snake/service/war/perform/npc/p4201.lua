--import module

local global = require "global"
local skynet = require "skynet"

local gamedefines = import(lualib_path("public.gamedefines"))
local pfobj = import(service_path("perform/pfobj"))


function NewCPerform(...)
    local o = CPerform:New(...)
    return o
end

--遗失之弓

CPerform = {}
CPerform.__index = CPerform
inherit(CPerform, pfobj.CPerform)

function CPerform:CalWarrior(oAction, oPerformMgr)
    local func = function(oVictim, oAttack)
        OnDead(oVictim, oAttack)
    end
    oPerformMgr:AddFunction("OnDead", self.m_ID, func)
end

function OnDead(oVictim, oAttack)
    local oWar = oVictim:GetWar()
    if not oWar then return end

    local oPerform = oVictim:GetPerform(3002)
    if not oPerform then return end
   
    local lFriend = oVictim:GetFriendList(true)
    local lResult = {}
    for _, oWarrior in ipairs(lFriend) do
        if oWarrior:IsAlive() and oWarrior:GetPerform(4202) then
            table.insert(lResult, oWarrior)
        end
    end
    if #lResult <= 0 then return end
    local mPerform = {
        lv = oPerform:Level(),
        ratio = oPerform:GetPerformPriority(),
        ai_target = oPerform:GetAITarget(),
    }
    local oAccept = lResult[math.random(1,#lResult)]
    oAccept:SetPerform(oPerform:Type(), mPerform)

    oWar:SendAll("GS2CWarriorSeqSpeek", {
        war_id = oAccept:GetWarId(),
        speeks = {
            {
                wid = oAccept:GetWid(),
                content = "将军的意志由我继承",
            },
        },
        block_ms = 0,
        block_action = 0,
    })
end


