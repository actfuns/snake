--import module

local global = require "global"
local skynet = require "skynet"
local record = require "public.record"

Cmds = {}

Cmds.playerdb = import(service_path("common.playerdb"))
Cmds.offlinedb = import(service_path("common.offlinedb"))
Cmds.worlddb = import(service_path("common.worlddb"))
Cmds.idcounter = import(service_path("common.idcounter"))
Cmds.namecounter = import(service_path("common.namecounter"))
Cmds.orgdb = import(service_path("common.orgdb"))
Cmds.orgreadydb = import(service_path("common.orgreadydb"))
Cmds.rankdb = import(service_path("common.rankdb"))
Cmds.huodongdb = import(service_path("common.huodongdb"))
Cmds.globaldb = import(service_path("common.globaldb"))
Cmds.guild = import(service_path("common.guild"))
Cmds.showid = import(service_path("common.showid"))
Cmds.stalldb = import(service_path("common.stalldb"))
Cmds.warvideodb = import(service_path("common.warvideodb"))
Cmds.pricedb = import(service_path("common.pricedb"))
Cmds.bulletbarragedb = import(service_path("common.bulletbarragedb"))
Cmds.auctiondb = import(service_path("common.auctiondb"))
Cmds.invitecodedb = import(service_path("common.invitecodedb"))
Cmds.cbtpaydb = import(service_path("common.cbtpaydb"))
Cmds.roleinfodb = import(service_path("common.roleinfodb"))
Cmds.feedbackdb = import(service_path("common.feedbackdb"))
Cmds.kuafudb = import(service_path("common.kuafudb"))


function Invoke(sModule, sCmd, mCond, mData)
    local m = Cmds[sModule]
    if m then
        local f = m[sCmd]
        if f then
            return f(mCond, mData)
        end
    end
    record.error(string.format("Invoke fail %s common %s %s", MY_SERVICE_NAME, sModule, sCmd))
end
