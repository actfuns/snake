local res = require "base.res"

local ExtendSchedule={
    [1017] = true,
    [1008] = true,
    [1022] = true,
    [1030] = true,
    [1032] = true,
    [1033] = true,
    [1037] = true,
}

function CreateSchedule(id)
    local mConfig = res["daobiao"]["schedule"]["schedule"][id]
    if not mConfig then
        assert(nil,string.format("CreateSchedule %s",id))
    end
    local oModule
    if ExtendSchedule[id] then
        local sPath = string.format("schedule/s%d",id)
        oModule = import(service_path(sPath))
    else
        oModule = import(service_path("schedule.scheduleobj"))
    end
    assert(oModule,string.format("NewState err:%d",id))
    local oSchedule = oModule.NewSchedule(id)
    return oSchedule
end

function LoadSchedule(id, data)
    if not res["daobiao"]["schedule"]["schedule"][id] then
        return
    end
    local oSchedule = CreateSchedule(id)
    oSchedule:Load(data)
    return oSchedule
end

function GetScheduleIdByName(sName)
    local mRes = res["daobiao"]["schedule"]["schedule"]
    for k,v in pairs(mRes) do
        if v.flag == sName then
            return k
        end
    end
end
