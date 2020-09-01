local global = require "global"
local skynet = require "skynet"

local gamedefines = import(lualib_path("public.gamedefines"))
local pfobj = import(service_path("perform/pfobj"))

--超级追击
function NewCPerform(...)
    local o = CPerform:New(...)
    return o
end

CPerform = {}
CPerform.__index = CPerform
inherit(CPerform, pfobj.CPerform)

function CPerform:CalWarrior(oAction, oPerformMgr)
    local iPerform = self:Type()
    local func = function(oAction, mCmd,sType)
        local mCmd = ChangeCmd(oAction, mCmd,iPerform,sType)
        return mCmd
    end
    oPerformMgr:AddFunction("ChangeCmd", self.m_ID, func)
end

function ChooseOneEnemy(oAction)
    local oSelect
    local lVictim = oAction:GetEnemyList()
    for i,v in ipairs(lVictim) do
        oSelect = lVictim[math.random(#lVictim)]
        if oSelect and not oSelect:IsDead() and not oSelect:IsVisible(oAction) then
            break
        end
    end
    return oSelect
end

function PursueAttack(oAction, oSelect)
    local oSelect = oSelect or ChooseOneEnemy(oAction)
    if oSelect then
        if oAction:IsDead() then return end
        local iTimes = oAction:GetExtData("p4295", 0)
        if iTimes >= 6 then return end
        oAction:SetExtData("p4295", iTimes + 1 )
        global.oActionMgr:WarNormalAttack(oAction, oSelect)
        if oSelect:IsDead() then
            PursueAttack(oAction)
        end
    end
end

function ChangeCmd(oAction, mCmd,iPerform,sType)
    local oWar = oAction:GetWar()
    local oPerform = oAction:GetPerform(iPerform)
    if sType == "order" or not oWar or mCmd.cmd ~= "normal_attack" or not oPerform then
        return mCmd
    end

    local iSelectWid = mCmd.data.select_wid
    local oSelect = oWar:GetWarrior(iSelectWid)
    if not oSelect or oSelect:IsDead() or not oSelect:IsVisible(oAction) then
        local lVictim = oAction:GetEnemyList()
        if #lVictim <= 0 then
            oSelect = nil
        else
            oSelect = lVictim[math.random(#lVictim)]
        end
    end

    if oSelect and not oSelect:IsDead() then
        PursueAttack(oAction, oSelect)
    end
    oAction:SetExtData("p4295", nil)
    oAction.m_bAction = true
    mCmd =  {}
    mCmd.cmd = ""
    mCmd.data = {}
    return mCmd
end