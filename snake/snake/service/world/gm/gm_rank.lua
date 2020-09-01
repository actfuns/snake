local global = require "global"
local interactive = require "base.interactive"

Commands = {}       --指令函数
Helpers = {}        --帮助信息
Opens = {}          --对外开放

Helpers.ranknewday = {
    "排行榜0点刷新",
    "ranknewday",
    "ranknewday",
}
function Commands.ranknewday(oMaster)
    global.oRankMgr:NewHour(get_daytime({}))
end

Helpers.ranknewweek = {
    "排行榜周一0点刷新",
    "ranknewweek",
    "ranknewweek",
}
function Commands.ranknewweek(oMaster)
    global.oRankMgr:NewHour(get_wdaytime({}))
end

Helpers.ranknewhour = {
    "刷新",
    "ranknewhour",
    "ranknewhour",
}
function Commands.ranknewhour(oMaster, iHour)
    global.oRankMgr:NewHour(get_hourtime({hour = iHour}))
end
