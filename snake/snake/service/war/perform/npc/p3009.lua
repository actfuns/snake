
--import module

local global = require "global"
local skynet = require "skynet"

local gamedefines = import(lualib_path("public.gamedefines"))
local pfobj = import(service_path("perform/pfobj"))


function NewCPerform(...)
    local o = CPerform:New(...)
    return o
end

--天地无极

CPerform = {}
CPerform.__index = CPerform
inherit(CPerform, pfobj.CPerform)

function CPerform:TruePerform(oAttack,oVictim,iRatio)
    super(CPerform).TruePerform(self, oAttack, oVictim, iRatio)
   
    if oVictim then 
        local sExtArg = self:ExtArg()
        local mEnv = {max_mp = oVictim:GetMaxMp()}
        local mExtArg = formula_string(sExtArg, mEnv)
        
        oVictim:SubMp(mExtArg.sub_mp or 0)
    end
end

