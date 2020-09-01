-- ./excel/log/title.xlsx
return {

    ["add"] = {
        explain = "增加头衔",
        log_format = {["pid"] = {["id"] = "pid", ["desc"] = "玩家id"}, ["title"] = {["id"] = "title", ["desc"] = "头衔id"}},
        subtype = "add",
    },

    ["del"] = {
        explain = "删除头衔",
        log_format = {["pid"] = {["id"] = "pid", ["desc"] = "玩家id"}, ["title"] = {["id"] = "title", ["desc"] = "头衔id"}},
        subtype = "del",
    },

    ["offlineadd"] = {
        explain = "离线增加头衔",
        log_format = {["pid"] = {["id"] = "pid", ["desc"] = "玩家id"}, ["title"] = {["id"] = "title", ["desc"] = "头衔id"}},
        subtype = "offlineadd",
    },

    ["failadd"] = {
        explain = "增加头衔失败",
        log_format = {["pid"] = {["id"] = "pid", ["desc"] = "玩家id"}, ["title"] = {["id"] = "title", ["desc"] = "头衔id"}},
        subtype = "failadd",
    },

}
