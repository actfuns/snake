local global = require "global"
local extend = require "base.extend"

local firstboutskillaction = import(service_path("action/firstboutskill"))
local gamedefines = import(lualib_path("public.gamedefines"))

function NewWarAction(...)
    local o = CWarAction:New(...)
    return o
end

CWarAction = {}
CWarAction.__index = CWarAction
inherit(CWarAction, firstboutskillaction.CWarAction)

function CWarAction:GetSkillChange()
    return {[11089] = 1107}
end

function CWarAction:GetActionId()
    return 100003
end
