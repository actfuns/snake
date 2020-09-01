-- ./excel/log/kuafu.xlsx
return {

    ["ks_hd_start"] = {
        explain = "KS活动开启",
        log_format = {["data"] = {["id"] = "data", ["desc"] = "信息"}, ["hdname"] = {["id"] = "hdname", ["desc"] = "活动名字"}, ["ks"] = {["id"] = "ks", ["desc"] = "服务器ID"}},
        subtype = "ks_hd_start",
    },

    ["ks_hd_end"] = {
        explain = "KS活动结束",
        log_format = {["hdname"] = {["id"] = "hdname", ["desc"] = "活动名字"}, ["ks"] = {["id"] = "ks", ["desc"] = "服务器ID"}},
        subtype = "ks_hd_end",
    },

    ["ks_mail"] = {
        explain = "跨服邮寄",
        log_format = {["info"] = {["id"] = "info", ["desc"] = "邮件信息"}, ["pid"] = {["id"] = "pid", ["desc"] = "玩家ID"}},
        subtype = "ks_mail",
    },

    ["ks_addgoldcoin"] = {
        explain = "跨服元宝",
        log_format = {["goldcoin"] = {["id"] = "goldcoin", ["desc"] = "元宝"}, ["pid"] = {["id"] = "pid", ["desc"] = ""}, ["reason"] = {["id"] = "reason", ["desc"] = "原因"}},
        subtype = "ks_addgoldcoin",
    },

    ["ks_addrpgoldcoin"] = {
        explain = "跨服绑定元宝",
        log_format = {["pid"] = {["id"] = "pid", ["desc"] = ""}, ["reason"] = {["id"] = "reason", ["desc"] = "原因"}, ["rpgoldcoin"] = {["id"] = "rpgoldcoin", ["desc"] = "元宝"}},
        subtype = "ks_addrpgoldcoin",
    },

    ["ks_info"] = {
        explain = "跨服信息",
        log_format = {["action"] = {["id"] = "action", ["desc"] = "行为"}, ["info"] = {["id"] = "info", ["desc"] = "信息"}, ["pid"] = {["id"] = "pid", ["desc"] = "玩家ID"}},
        subtype = "ks_info",
    },

    ["ks_huodong"] = {
        explain = "跨服活动",
        log_format = {["action"] = {["id"] = "action", ["desc"] = "行为"}, ["hdname"] = {["id"] = "hdname", ["desc"] = "活动名字"}, ["info"] = {["id"] = "info", ["desc"] = "信息"}, ["pid"] = {["id"] = "pid", ["desc"] = "玩家ID"}},
        subtype = "ks_huodong",
    },

}
