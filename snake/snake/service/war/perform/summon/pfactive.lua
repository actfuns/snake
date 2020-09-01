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

function CPerform:New(pfid)
    local o = super(CPerform).New(self,pfid)
    return o
end

--作用人数
function CPerform:CalRange(oAction)
    if not oAction then return 1 end

    local mInfo = self:GetPerformData()
    local mRange = mInfo["range"] or {}
    local sRange = "1"
    for _,mData in pairs(mRange) do
        local iGrade = mData["grade"]
        if oAction:GetGrade() < iGrade then break end

        sRange = mData["range"]
    end

    local iRange = tonumber(sRange)
    if iRange then return iRange end
        
    local mEnv = self:RangeEnv()
    return math.floor(formula_string(sRange,mEnv))
end

function CPerform:MaxRange(oAttack, oVictim)
    local iRange = self:CalRange(oAttack)

    local mFunc = oAttack:GetFunction("MaxRange")
    for _,fCallback in pairs(mFunc) do
        iRange = iRange + fCallback(oAttack, oVictim, self)
    end
    return iRange
end
