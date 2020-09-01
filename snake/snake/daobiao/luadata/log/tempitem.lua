-- ./excel/log/item.xlsx
return {

    ["failadd"] = {
        explain = "进入背包失败",
        log_format = {["iteminfo"] = {["id"] = "iteminfo", ["desc"] = "物品信息"}, ["pid"] = {["id"] = "pid", ["desc"] = "玩家id"}},
        subtype = "failadd",
    },

    ["delnotactive"] = {
        explain = "清除过期道具",
        log_format = {["iteminfo"] = {["id"] = "iteminfo", ["desc"] = "物品信息"}, ["pid"] = {["id"] = "pid", ["desc"] = "玩家id"}},
        subtype = "delnotactive",
    },

}
