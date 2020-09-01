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

--火鸦自爆

function CPerform:CalWarrior(oWarrior,oPerformMgr)
    local iPerform = self:Type()
    local func = function(oAttack)
        OnBoutEnd10101(iPerform, oAttack)
    end
    oPerformMgr:AddFunction("OnBoutEnd", self.m_ID, func)
end

function OnBoutEnd10101(iPerform, oAttack)
    if not oAttack or oAttack:IsDead() then 
        return 
    end
    local oWar  = oAttack:GetWar()
    if not oWar then 
        return 
    end

    local mFriend = oAttack:GetFriendList()
    local lDelWarrior = {}
    for _,oWarrior in pairs(mFriend) do
        if oWarrior:GetData("type") == 10101 then
            table.insert(lDelWarrior, oWarrior:GetWid())
        end
    end
    for _, iWid in pairs(lDelWarrior) do
        local oWarrior = oWar:GetWarrior(iWid)
        if not oWarrior or oWarrior:IsDead() then
            goto continue
        end
        local oPerform = oWarrior:GetPerform(iPerform)
        if not oPerform then
            goto continue
        end
        local mEnemy = oWarrior:GetEnemyList()
        if #mEnemy <= 0 then
            goto continue
        end
        global.oActionMgr:Perform(oWarrior,mEnemy[1],iPerform)
        oWar:KickOutWarrior(oWarrior)
        --print("OnBoutEnd10101-3025")
        ::continue::
    end
end
