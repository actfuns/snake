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
    local func = function(oWarrior)
        OnNewBout(oWarrior)
    end
    oAction:AddFunction("OnNewBout", self.m_ID, func)
end

function OnNewBout(oWarrior)
    local mFriend = oWarrior:GetFriendList()
    local oTarget 
    for _,oFriend in pairs(mFriend) do
        if oFriend:GetName()=="许仙" then
            oTarget = oFriend
            break
        end
    end
    if not oTarget then return end
    local oWar = oWarrior:GetWar()
    local oPfobj = oWarrior:GetPerform(3005)
    if not oWar or not oPfobj then
        return
    end
    local lVictim = {oTarget}
    local iSkill = oPfobj.m_ID
    oWarrior:SendAll("GS2CWarSkill", {
        war_id = oWarrior:GetWarId(),
        action_wlist = {oWarrior:GetWid(),},
        select_wlist = list_generate(lVictim, function (v)
            return v:GetWid()
        end),
        skill_id = iSkill,
        magic_id = 1,
    })
    local mTime = oPfobj:PerformMagicTime(oWarrior)
    oWar:AddAnimationTime(mTime[1])
    oWar:AddDebugMsg(string.format("#B%s#n使用#B%s#n", oWarrior:GetName(), oPfobj:Name() ))

    local oGHBuff = oTarget.m_oBuffMgr:HasBuff(176)
    if oGHBuff then
        oGHBuff:AddGanHua(oTarget,-1)
    else
         local oDHBuff = oTarget.m_oBuffMgr:HasBuff(177)
        if not oDHBuff then
            oTarget.m_oBuffMgr:AddBuff(177,99,{point = 1})
        else
            oDHBuff:AddDianHua(oTarget,1)
        end       
    end
    local mCmd = {
        war_id = oWar:GetWarId(),
        speeks = {
            {
                wid = oWarrior:GetWid(),
                content = "前尘尽忘，入我佛门。",
            },
        },
        block_ms = 0,
        block_action = 0,
    }
    oWar:SendAll("GS2CWarriorSeqSpeek", mCmd)
end
