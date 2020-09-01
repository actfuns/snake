--import module

local global = require "global"
local skynet = require "skynet"

local gamedefines = import(lualib_path("public.gamedefines"))
local pfobj = import(service_path("perform/pfobj"))

--超级连击
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

function ChangeCmd(oAction, mCmd,iPerform,sType)
    if sType == "order" then
        return mCmd
    end
    local oWar = oAction:GetWar()
    if not oWar then 
        return mCmd 
    end
    local sCmd = mCmd.cmd
    local mCmdData = mCmd.data
    if sCmd ~= "normal_attack" then
        return mCmd
    end
    if not oAction:GetPerform(iPerform) then
        return mCmd
    end
    if math.random(100)<30 then
        return mCmd
    end
    local iSelectWid = mCmdData.select_wid
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
        oAction:GS2CTriggerPassiveSkill(iPerform)
        for i=1 ,4 do
            if oSelect:IsDead() then
                break
            end
            if oAction:IsDead() then
                break
            end
            global.oActionMgr:WarNormalAttack(oAction, oSelect)
            if math.random(100)>75 then
                break
            end
        end
    end
    oAction.m_bAction = true
    mCmd =  {}
    mCmd.cmd = ""
    mCmd.data = {}
    return mCmd
end