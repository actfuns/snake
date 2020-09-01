local global = require "global"
local skynet = require "skynet"

local gamedefines = import(lualib_path("public.gamedefines"))
local pfobj = import(service_path("perform/pfobj"))

--魔新转生
function NewCPerform(...)
    local o = CPerform:New(...)
    return o
end

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

function OnNewBout(iPerform, oAttack) 
    if not oAttack or oAttack:IsDead() then return end
    
    local oPerform = oAttack:GetPerform(iPerform)
    if not oPerform then return end

    local lNoBuffFriend = {}
    local lFriend = oAttack:GetFriendList()
    for _, oWarrior in pairs(lFriend) do
        if not oWarrior.m_oBuffMgr:HasBuff(249) then
            table.insert(lNoBuffFriend, oWarrior)
        end
    end

    if #lNoBuffFriend > 0 then
        local oWarrior = lNoBuffFriend[math.random(#lNoBuffFriend)]
        if oWarrior then
            oWarrior.m_oBuffMgr:AddBuff(249, 3, {})
        end
    end
end

function CPerform:AICheckResume(oAttack)
    local iCurBout = oAttack:CurBout()
    if iCurBout % 2 == 1 then
        return super(CPerform).AICheckResume(self, oAttack)
    end
    return false
end