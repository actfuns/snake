--import module
local skynet = require "skynet"

local basectrl = import(service_path("playerctrl.basectrl"))
local activectrl = import(service_path("playerctrl.activectrl"))
local itemctrl = import(service_path("playerctrl.itemctrl"))
local timectrl = import(service_path("playerctrl.timectrl"))
local taskctrl = import(service_path("playerctrl.taskctrl"))
local warehousectrl = import(service_path("playerctrl.warehousectrl"))
local skillctrl = import(service_path("playerctrl.skillctrl"))
local summonctrl = import(service_path("playerctrl.summonctrl"))
local schedulectrl = import(service_path("playerctrl.schedulectrl"))
local statectrl = import(service_path("playerctrl.statectrl"))
local partnerctrl = import(service_path("playerctrl.partnerctrl"))
local titlectrl = import(service_path("playerctrl.titlectrl"))
local touxianctrl = import(service_path("playerctrl.touxianctrl"))
local achievectrl = import(service_path("playerctrl.achievectrl"))
local ridectrl = import(service_path("playerctrl.ridectrl"))
local promotectrl = import(service_path("playerctrl.promotectrl"))
local tempitemctrl = import(service_path("playerctrl.tempitemctrl"))
local recoveryctrl = import(service_path("playerctrl.recoveryctrl"))
local storectrl = import(service_path("playerctrl.storectrl"))
local equipctrl = import(service_path("playerctrl.equipctrl"))
local summonckctrl = import(service_path("playerctrl.summonckctrl"))
local fabaoctrl = import(service_path("playerctrl.fabaoctrl"))
local artifactctrl = import(service_path("playerctrl.artifactctrl"))
local wingctrl = import(service_path("playerctrl.wingctrl"))
local marryctrl = import(service_path("playerctrl.marryctrl"))


function NewBaseCtrl(...)
    return basectrl.CPlayerBaseCtrl:New(...)
end

function NewActiveCtrl(...)
    return activectrl.CPlayerActiveCtrl:New(...)
end

function NewItemCtrl( ... )
    return itemctrl.CItemCtrl:New(...)
end

function NewWHCtrl( ... )
    return warehousectrl.CWareHouseCtrl:New(...)
end

function NewTimeCtrl( ... )
    return timectrl.CTimeCtrl:New(...)
end

function NewTodayCtrl(...)
    return timectrl.CToday:New(...)
end

function NewTodayMorningCtrl(...)
    return timectrl.CTodayMorning:New(...)
end

function NewWeekCtrl(...)
    return timectrl.CThisWeek:New(...)
end

function NewWeekMorningCtrl( ... )
    return timectrl.CThisWeekMorning:New(...)
end

function NewThisTempCtrl( ... )
    return timectrl.CThisTemp:New(...)
end

function NewSeveralDayCtrl( ... )
    return timectrl.CSeveralDay:New(...)
end

function NewTaskCtrl( ... )
    return taskctrl.CTaskCtrl:New(...)
end

function NewSkillCtrl( ... )
    return skillctrl.CSkillCtrl:New(...)
end

function NewSummonCtrl( ... )
    return summonctrl.CSummonCtrl:New(...)
end

function NewScheduleCtrl( ... )
    return schedulectrl.CScheduleCtrl:New(...)
end

function NewStateCtrl( ... )
    return statectrl.CStateCtrl:New(...)
end

function NewPartnerCtrl( ... )
    return partnerctrl.CPartnerCtrl:New(...)
end

function NewTitleCtrl( ... )
    return titlectrl.CTitleCtrl:New(...)
end

function NewTouxianCtrl( ... )
    return touxianctrl.CTouxianCtrl:New(...)
end

function NewAchieveCtrl( ... )
    return achievectrl.CAchieveCtrl:New(...)
end

function NewRideCtrl( ... )
    return ridectrl.CRideCtrl:New(...)
end

function NewPromoteCtrl( ... )
    return promotectrl.CPromoteCtrl:New(...)
end

function NewTempItemCtrl( ... )
    return tempitemctrl.CTempItemCtrl:New(...)
end

function NewRecoveryCtrl( ... )
    return recoveryctrl.CRecoveryCtrl:New(...)
end

function NewStoreCtrl( ... )
    return storectrl.CStoreCtrl:New(...) 
end

function NewEquipCtrl( ... )
    return equipctrl.CEquipCtrl:New(...)
end

function NewSummonCkCtrl( ... )
    return summonckctrl.CSummCkCtrl:New(...)
end

function NewFaBaoCtrl( ... )
    return fabaoctrl.CFaBaoCtrl:New(...)
end

function NewArtifactCtrl(...)
    return artifactctrl.CArtifactCtrl:New(...)
end

function NewWingCtrl(...)
    return wingctrl.CWingCtrl:New(...)
end

function NewMarryCtrl( ... )
    return marryctrl.CMarryCtrl:New(...)
end

