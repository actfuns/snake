--import module

local global = require "global"
local skynet = require "skynet"
local record = require "public.record"

Cmds = {}

Cmds.login = import(service_path("netcmd.login"))
Cmds.scene = import(service_path("netcmd.scene"))
Cmds.other = import(service_path("netcmd.other"))
Cmds.item = import(service_path("netcmd.item"))
Cmds.war = import(service_path("netcmd.war"))
Cmds.player = import(service_path("netcmd.player"))
Cmds.npc = import(service_path("netcmd.npc"))
Cmds.openui = import(service_path("netcmd.openui"))
Cmds.warehouse =import(service_path("netcmd.warehouse"))
Cmds.team = import(service_path("netcmd/team"))
Cmds.chat = import(service_path("netcmd/chat"))
Cmds.task = import(service_path("netcmd/task"))
Cmds.skill = import(service_path("netcmd/skill"))
Cmds.summon = import(service_path("netcmd.summon"))
Cmds.store = import(service_path("netcmd.store"))
Cmds.mail = import(service_path("netcmd.mail"))
Cmds.test = import(service_path("netcmd.test"))
Cmds.partner = import(service_path("netcmd.partner"))
Cmds.org = import(service_path("netcmd.org"))
Cmds.friend = import(service_path("netcmd.friend"))
Cmds.newbieguide = import(service_path("netcmd.newbieguide"))
Cmds.title = import(service_path("netcmd.title"))
Cmds.rank = import(service_path("netcmd.rank"))
Cmds.formation = import(service_path("netcmd.formation"))
Cmds.jjc = import(service_path("netcmd.jjc"))
Cmds.touxian = import(service_path("netcmd.touxian"))
Cmds.guild = import(service_path("netcmd.guild"))
Cmds.stall = import(service_path("netcmd.stall"))
Cmds.huodong = import(service_path("netcmd.huodong"))
Cmds.redpacket = import(service_path("netcmd.redpacket"))
Cmds.ride = import(service_path("netcmd.ride"))
Cmds.auction = import(service_path("netcmd.auction"))
Cmds.state = import(service_path("netcmd.state"))
Cmds.tempitem = import(service_path("netcmd.tempitem"))
Cmds.recovery = import(service_path("netcmd.recovery"))
Cmds.bulletbarrage = import(service_path("netcmd.bulletbarrage"))
Cmds.vigor = import(service_path("netcmd.vigor"))
Cmds.shop = import(service_path("netcmd.shop"))
Cmds.engage = import(service_path("netcmd.engage"))
Cmds.marry = import(service_path("netcmd.marry"))
Cmds.fabao = import(service_path("netcmd.fabao"))
Cmds.artifact = import(service_path("netcmd.artifact"))
Cmds.wing = import(service_path("netcmd.wing"))
Cmds.mentoring = import(service_path("netcmd.mentoring"))
Cmds.kuafu = import(service_path("netcmd.kuafu"))


function Invoke(sModule, sCmd, fd, mData)
    local m = Cmds[sModule]
    if m then
        local f = m[sCmd]
        if f then
            local oWorldMgr = global.oWorldMgr
            local oPlayer = oWorldMgr:GetOnlinePlayerByFd(fd)
            if oPlayer then
                return f(oPlayer, mData)
            end
        else
            record.error(string.format("Invoke fail %s %s %s %s", MY_SERVICE_NAME, MY_ADDR, sModule, sCmd))
        end
    else
        record.error(string.format("Invoke fail %s %s %s %s", MY_SERVICE_NAME, MY_ADDR, sModule, sCmd))
    end
end
