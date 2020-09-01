--import module

local global = require "global"
local skynet = require "skynet"
local record = require "public.record"

local gamedefines = import(lualib_path("public.gamedefines"))
local pfobj = import(service_path("perform/pfobj"))


function NewCPerform(...)
    local o = CPerform:New(...)
    return o
end

CPerform = {}
CPerform.__index = CPerform
inherit(CPerform, pfobj.CPerform)

function CPerform:New(id)
    local o = super(CPerform).New(self,id)
    o.m_iFloor=1
    return o
end

--作用人数
function CPerform:Range()
    local iFloor = self.m_iFloor or 0
    if iFloor <=0 then
        record.warning(string.format("range error %s %s",self:Type(),iFloor))
        iFloor = 1
    end
    if iFloor>4 then
        record.warning(string.format("range error %s %s",self:Type(),iFloor))
        iFloor = 4
    end
    return iFloor
end

--AI检查能否使用招式
function CPerform:AICheckValidPerform(oAttack)
    local iFloor = self.m_iFloor or 0
    if iFloor<=0 or iFloor>4 then
        return false
    end
    return super(CPerform).AICheckValidPerform(self, oAttack)
end