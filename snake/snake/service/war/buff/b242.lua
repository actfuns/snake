--import module

local global = require "global"
local skynet = require "skynet"

local buffbase = import(service_path("buff/buffbase"))
local gamedefines = import(lualib_path("public.gamedefines"))

function NewBuff(...)
    local o = CBuff:New(...)
    return o
end

CBuff = {}
CBuff.__index = CBuff
inherit(CBuff, buffbase.CBuff)

function CBuff:CalInit(oWarrior, oBuffMgr)
    local iBuffID = self.m_ID
    local func = function(oAct,iMP,bAdd)
        return OnMpChange(oAct,iMP,bAdd,iBuffID)
    end
    oBuffMgr:AddFunction("OnMpChange", self.m_ID, func)
end

function CBuff:OnRemove(oAction, oBuffMgr)
    super(CBuff).OnRemove(self, oAction, oBuffMgr)
    oBuffMgr:RemoveFunction("OnMpChange", self.m_ID)
end

function OnMpChange( oWarrior,iMP,bAdd,iBuffID)
    if bAdd and iMP >0 then
        return iMP
    end
    if not oWarrior or oWarrior:IsDead() then
        return iMP
    end
    local oBuff = oWarrior.m_oBuffMgr:HasBuff(iBuffID)
    if not oBuff then
        return iMP
    end
    local iRatio = oBuff:GetAttr("fabao_mp_ratio")
    iMP = math.floor(iMP*(100-iRatio)/100)
    return iMP
end