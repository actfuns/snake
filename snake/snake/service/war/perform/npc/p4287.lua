local global = require "global"
local skynet = require "skynet"
local res = require "base.res"
local extend = require "base.extend"
local net = require "base.net"

local gamedefines = import(lualib_path("public.gamedefines"))
local pfobj = import(service_path("perform/pfobj"))

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
        CallMonster(oAttack,iPerform)
    end
    oPerformMgr:AddFunction("OnBoutEnd", self.m_ID, func)
end

function CallMonster(oAction,iPerform)
    if oAction:IsDead() then return end
    local mFriend = oAction:GetFriendList()
    local iLimitCnt = 4
    local iCurCnt = 0
    for _,oWarrior in pairs(mFriend) do
        if oWarrior:GetData("nianshou",0) == 1 then
            iCurCnt = iCurCnt +1
        end
   end
   if iCurCnt>=iLimitCnt then
        return 
    end
    local oWar = oAction:GetWar()
    local oPerform = oAction:GetPerform(iPerform)
    if not oPerform then
        return 
    end
    oPerform:PerformOnce(oAction,{})
    
    local mAllMonsterInfo = oAction:GetData("all_monster", {})

    if next(mAllMonsterInfo) then
        local lMonster = table_key_list(mAllMonsterInfo)
        lMonster = extend.Random.random_size(lMonster,2)
        for _,iMonster in pairs(lMonster) do
            local mMonster = table_copy(mAllMonsterInfo[iMonster]) 
            local oWarrior = oWar:AddNpcWarrior(2, mMonster, nil, 0, true)
            oWarrior:SetData("nianshou",1)
        end
    end
end