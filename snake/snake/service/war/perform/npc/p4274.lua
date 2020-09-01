--import module

local global = require "global"
local skynet = require "skynet"
local extend = require "base.extend"

local gamedefines = import(lualib_path("public.gamedefines"))
local pfobj = import(service_path("perform/pfobj"))

local KILL_BUFF = {215,216,217,218,219}

--衰弱1
function NewCPerform(...)
    local o = CPerform:New(...)
    return o
end

CPerform = {}
CPerform.__index = CPerform
inherit(CPerform, pfobj.CPerform)

function CPerform:TruePerform(oAttack,oVictim,iRatio)
    local iBuff = extend.Random.random_choice(KILL_BUFF)
    oVictim.m_oBuffMgr:AddBuff(iBuff, 99, {bForce=true})
    if oVictim:IsDead() then
        return
    end
    for _,iBuff in ipairs(KILL_BUFF) do
        if not oVictim.m_oBuffMgr:HasBuff(iBuff) then
            return
        end
    end
    global.oActionMgr:DoSubHp(oVictim,oVictim:GetMaxHp(),oAttack)
    if oVictim:IsDead() then
        for _,iBuff in ipairs(KILL_BUFF) do
            local oBuff = oVictim.m_oBuffMgr:HasBuff(iBuff)
            if oBuff then
                oVictim.m_oBuffMgr:RemoveBuff(oBuff,oVictim)
            end
        end
        local mFriend = oAttack:GetFriendList()
        for _,oWarrior in ipairs(mFriend) do
            if oWarrior:GetPerform(4276) then
                oWarrior:GS2CTriggerPassiveSkill(4276)
                global.oActionMgr:DoAddHp(oWarrior,oWarrior:GetMaxHp())
            end
        end
    end
end

