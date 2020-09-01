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

function CBuff:Init(iBout, mArgs)
    super(CBuff).Init(self, iBout, mArgs)
    self.m_iAllBout = iBout
end


function CBuff:OnNewBout(oAction, oBuffMgr)
    if not oAction or not oAction:IsDead() then
        return
    end

    if self.m_iAllBout - self:Bout() == 1 then
        local iMaxHp = oAction:GetMaxHp()
        local iHp = math.floor(iMaxHp * 0.5)
        global.oActionMgr:DoAddHp(oAction, iHp)
        oAction.m_oBuffMgr:RemoveBuff(self)
    end
end