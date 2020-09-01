-- ./excel/log/gm.xlsx
return {

    ["gmop"] = {
        log_format = {["arg"] = {["id"] = "arg", ["desc"] = "参数"}, ["cmd"] = {["id"] = "cmd", ["desc"] = "操作"}, ["name"] = {["id"] = "name", ["desc"] = "gm玩家名字"}, ["pid"] = {["id"] = "pid", ["desc"] = "gm玩家id"}},
        subtype = "gmop",
    },

    ["fixbug"] = {
        log_format = {["channel"] = {["id"] = "channel", ["desc"] = "渠道"}, ["grade"] = {["id"] = "grade", ["desc"] = "等级"}, ["info"] = {["id"] = "info", ["desc"] = "信息"}, ["name"] = {["id"] = "name", ["desc"] = "玩家名字"}, ["pid"] = {["id"] = "pid", ["desc"] = "玩家id"}, ["show_id"] = {["id"] = "show_id", ["desc"] = "显示id"}},
        subtype = "fixbug",
    },

}
