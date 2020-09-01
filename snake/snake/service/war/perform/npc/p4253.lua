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

-- 防御
function CPerform:CalWarrior(oAction, oPerformMgr)
    local iPerform = self:Type()
    local func = function (oAction, mCmd, sType)
        return ChangeCmd(oAction, mCmd, sType, iPerform)
    end
    oPerformMgr:AddFunction("ChangeCmd",self.m_ID, func)
end

function ChangeCmd(oAction, mCmd, sType, iPerform)
    return {
        cmd = "defense",
        data = {
            action_wid = oAction:GetWid(),
        }
    }
end
