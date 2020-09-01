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

function CPerform:TruePerform(oAction, oVictim, iRatio)
    if oAction:IsDead() then return end

    local oWar = oAction:GetWar()
    if not oWar then return end

    local lMonster = oWar:GetWarriorList(2)
    local iHas = 0
    local mAllMonsterInfo = oAction:GetData("all_monster", {})
    for _, oWarrior in ipairs(lMonster) do
        if mAllMonsterInfo[oWarrior:GetTypeSid()] then
            iHas = iHas + 1
        end
    end
    local iSize = math.min(2, math.max(0, 4 - iHas))
    if iSize <= 0 then return end

    local iBoss = oAction:GetWid()
    local lMonsterList = table_key_list(mAllMonsterInfo)
    local lChoose = extend.Random.random_size(lMonsterList, iSize)
    for _, iMonster in pairs(lChoose) do
        local mMonster = table_deep_copy(mAllMonsterInfo[iMonster])
        local oWarrior = oWar:AddNpcWarrior(2, mMonster, nil, 0, true)
        
        if math.floor(oWarrior:GetTypeSid() / 10000) ~= 2 then
            goto continue
        end

        local iNpcType = math.floor(oWarrior:GetTypeSid() % 10)
        if iNpcType == 1 then       --蜀山
        elseif iNpcType == 2 then   --金山
            local func = function(oAction, oAttack)
                OnDeadJinshan(oAction, oAttack, iBoss)
            end
            oWarrior:AddFunction("OnDead", 100008, func)
        elseif iNpcType == 3 then   --太初
            local func = function(oAction, oAttack)
                OnDeadTaichu(oAction, oAttack, iBoss)
            end
            oWarrior:AddFunction("OnDead", 100008, func)
        elseif iNpcType == 4 then   --瑶池
            OnAddYaochi(oWarrior, iBoss)
        elseif iNpcType == 5 then   --青城
            local func = function(oAction, oAttack)
                OnDeadQingcheng(oAction, oAttack, iBoss)
            end
            oWarrior:AddFunction("OnDead", 100008, func)
        elseif iNpcType == 6 then   --妖神
        end
        ::continue::
    end
end

function OnDeadJinshan(oAction, oAttack, iBoss)
    local oWar = oAction:GetWar()
    if not oWar then return end

    local oWarrior = oWar:GetWarrior(iBoss)
    if not oWarrior or oWarrior:IsDead() then
        return
    end

    oWarrior.m_oBuffMgr:AddBuff(224, 3, {})
end

function OnDeadTaichu(oAction, oAttack, iBoss)
    local oWar = oAction:GetWar()
    if not oWar then return end

    local oWarrior = oWar:GetWarrior(iBoss)
    if not oWarrior or oWarrior:IsDead() then
        return
    end

    oWarrior.m_oBuffMgr:AddBuff(223, 99, {})
end

function OnAddYaochi(oAction, iBoss)
    local oWar = oAction:GetWar()
    if not oWar then return end

    local oWarrior = oWar:GetWarrior(iBoss)
    if not oWarrior or oWarrior:IsDead() then
        return
    end

    oWarrior.m_oBuffMgr:AddBuff(225, 99, {})
end

function OnDeadQingcheng(oAction, oAttack, iBoss)
    local oWar = oAction:GetWar()
    if not oWar then return end

    local oPerform = oAction:GetPerform(3026)
    if not oPerform then return end

    local lEnemy = oWar:GetWarriorList(1)
    local oEnemy = lEnemy[math.random(#lEnemy)]
    if not oEnemy then return end

    global.oActionMgr:Perform(oAction, oEnemy, 3026)
end


