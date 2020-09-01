-- ./excel/log/recovery.xlsx
return {

    ["delitem1"] = {
        explain = "物品回收",
        log_format = {["iteminfo"] = {["id"] = "iteminfo", ["desc"] = "物品信息"}, ["pid"] = {["id"] = "pid", ["desc"] = "玩家id"}},
        subtype = "delitem1",
    },

    ["delitem2"] = {
        explain = "物品顶掉",
        log_format = {["iteminfo"] = {["id"] = "iteminfo", ["desc"] = "物品信息"}, ["pid"] = {["id"] = "pid", ["desc"] = "玩家id"}},
        subtype = "delitem2",
    },

    ["delitem3"] = {
        explain = "物品过期",
        log_format = {["iteminfo"] = {["id"] = "iteminfo", ["desc"] = "物品信息"}, ["pid"] = {["id"] = "pid", ["desc"] = "玩家id"}},
        subtype = "delitem3",
    },

    ["additem"] = {
        explain = "增加物品",
        log_format = {["iteminfo"] = {["id"] = "iteminfo", ["desc"] = "物品信息"}, ["pid"] = {["id"] = "pid", ["desc"] = "玩家id"}},
        subtype = "additem",
    },

    ["delsum1"] = {
        explain = "宠物回收",
        log_format = {["pid"] = {["id"] = "pid", ["desc"] = "玩家id"}, ["suminfo"] = {["id"] = "suminfo", ["desc"] = "宠物信息"}},
        subtype = "delsum1",
    },

    ["delsum2"] = {
        explain = "宠物顶掉",
        log_format = {["pid"] = {["id"] = "pid", ["desc"] = "玩家id"}, ["suminfo"] = {["id"] = "suminfo", ["desc"] = "宠物信息"}},
        subtype = "delsum2",
    },

    ["delsum3"] = {
        explain = "宠物过期",
        log_format = {["pid"] = {["id"] = "pid", ["desc"] = "玩家id"}, ["suminfo"] = {["id"] = "suminfo", ["desc"] = "宠物信息"}},
        subtype = "delsum3",
    },

    ["addsum"] = {
        explain = "增加宠物",
        log_format = {["pid"] = {["id"] = "pid", ["desc"] = "玩家id"}, ["suminfo"] = {["id"] = "suminfo", ["desc"] = "宠物信息"}},
        subtype = "addsum",
    },

}
