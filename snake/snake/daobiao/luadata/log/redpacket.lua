-- ./excel/log/redpacket.xlsx
return {

    ["sendrb"] = {
        explain = "发放红包",
        log_format = {["pid"] = {["id"] = "pid", ["desc"] = "玩家id"}, ["rbinfo"] = {["id"] = "rbinfo", ["desc"] = "物品信息"}},
        subtype = "sendrb",
    },

    ["robrb"] = {
        explain = "抢红包",
        log_format = {["pid"] = {["id"] = "pid", ["desc"] = "玩家id"}, ["rbinfo"] = {["id"] = "rbinfo", ["desc"] = "物品信息"}},
        subtype = "robrb",
    },

    ["delrb"] = {
        explain = "删除红包",
        log_format = {["pid"] = {["id"] = "pid", ["desc"] = "玩家id"}, ["rbinfo"] = {["id"] = "rbinfo", ["desc"] = "物品信息"}},
        subtype = "delrb",
    },

}
