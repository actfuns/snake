--import module
local global = require "global"
local schedulebase=import(service_path("schedule/s1032"))


function NewSchedule(id)
    return CSchedule:New(id)
end

CSchedule = {}
CSchedule.__index = CSchedule
inherit(CSchedule,schedulebase.CSchedule)

function CSchedule:GetFubenId()
    return 20002
end
