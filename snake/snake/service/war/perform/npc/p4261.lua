--import module

local global = require "global"
local skynet = require "skynet"
local extend = require "base.extend"

local gamedefines = import(lualib_path("public.gamedefines"))
local pfobj = import(service_path("perform/pfobj"))

--复仇
function NewCPerform(...)
    local o = CPerform:New(...)
    return o
end

CPerform = {}
CPerform.__index = CPerform
inherit(CPerform, pfobj.CPerform)

function CPerform:CalWarrior(oWarrior,oPerformMgr)
    local func = function(oVictim, oAttack)
        OnDead(oVictim, oAttack)
    end
    oPerformMgr:AddFunction("OnDead", self.m_ID, func)
end

function OnDead(oVictim, oAttack)
    if not oVictim or not oVictim:IsDead() then
        return
    end
    local oWar = oVictim:GetWar()
    if not oWar then
        return
    end
    local mFriend = oVictim:GetFriendList()
    mFriend = extend.Random.random_size(mFriend,#mFriend)
    for _,oWarrior in ipairs(mFriend) do
        local iType = oWarrior:GetData("type")
        if (iType == 10108  or iType == 10109) and not oWarrior.m_oBuffMgr:HasBuff(207) then
            oWarrior.m_oBuffMgr:AddBuff(207,99,{})
            --print("AddBuff",207)
            if iType == 10109 then
                local mCmd = {
                    war_id = oWarrior:GetWarId(),
                    wid = oWarrior:GetWid(),
                    content = "接受追随者的复仇吧",
                }
                oWar:SendAll("GS2CWarriorSpeek", mCmd)
            end
            break
        end
    end
end
