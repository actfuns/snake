-- ./excel/log/mentoring.xlsx
return {

    ["build"] = {
        explain = "建立师徒关系",
        log_format = {["action"] = {["id"] = "action", ["desc"] = "操作类型"}, ["apprentice_id"] = {["id"] = "apprentice_id", ["desc"] = "徒弟id"}, ["mentor"] = {["id"] = "mentor", ["desc"] = "师傅id"}},
        subtype = "build",
    },

    ["growup"] = {
        explain = "出师",
        log_format = {["action"] = {["id"] = "action", ["desc"] = "操作类型"}, ["apprentice_id"] = {["id"] = "apprentice_id", ["desc"] = "徒弟id"}, ["mentor"] = {["id"] = "mentor", ["desc"] = "师傅id"}},
        subtype = "growup",
    },

    ["dismiss"] = {
        explain = "解散关系",
        log_format = {["action"] = {["id"] = "action", ["desc"] = "操作类型"}, ["apprentice_id"] = {["id"] = "apprentice_id", ["desc"] = "徒弟id"}, ["mentor"] = {["id"] = "mentor", ["desc"] = "师傅id"}},
        subtype = "dismiss",
    },

}
