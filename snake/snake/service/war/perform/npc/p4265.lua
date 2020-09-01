--import module

local global = require "global"
local skynet = require "skynet"
local extend = require "base.extend"

local gamedefines = import(lualib_path("public.gamedefines"))
local pfobj = import(service_path("perform/pfobj"))


function NewCPerform(...)
    local o = CPerform:New(...)
    return o
end

--点化2

CPerform = {}
CPerform.__index = CPerform
inherit(CPerform, pfobj.CPerform)

function CPerform:CalWarrior(oWarrior,oPerformMgr)
    local iPerform = self:Type()
    local func = function(oAttack)
        OnNewBout(iPerform, oAttack)
    end
    oPerformMgr:AddFunction("OnNewBout", self.m_ID, func)
end

function OnNewBout(iPerform,oAttack)
    if not oAttack or oAttack:IsDead() then 
        return 
    end
    local oWar  = oAttack:GetWar()
    if not oWar then 
        return 
    end
    local oPerform = oAttack:GetPerform(iPerform)
    if not oPerform then 
        return 
    end
    local mFriend = oAttack:GetFriendList()
    mFriend = extend.Random.random_size(mFriend)
    local lWarrior ={}
    for _,oWarrior in ipairs(mFriend) do
        local iType = oWarrior:GetData("type")
        if (iType == 10021  or iType == 10022) and not oWarrior.m_oBuffMgr:HasBuff(210) then
            table.insert(lWarrior,oWarrior)
        end
    end
    if next(lWarrior) then
        local oWarrior = extend.Random.random_choice(lWarrior)
        oAttack:GS2CTriggerPassiveSkill(iPerform)
        oWarrior.m_oBuffMgr:AddBuff(210,1,{})
        --print("4265",oWarrior:GetName())
        local sContent = string.format("记住这无敌的感觉，%s",oWarrior:GetName())
        local mCmd = {
            war_id = oWarrior:GetWarId(),
            wid = oAttack:GetWid(),
            content = sContent,
        }
        oWar:SendAll("GS2CWarriorSpeek", mCmd)
    end
end