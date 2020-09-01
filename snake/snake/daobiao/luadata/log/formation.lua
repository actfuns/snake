-- ./excel/log/formation.xlsx
return {

    ["add_fmt"] = {
        explain = "添加阵法",
        log_format = {["channel"] = {["id"] = "channel", ["desc"] = "渠道"}, ["fmt_id"] = {["id"] = "fmt_id", ["desc"] = "阵法ID"}, ["grade"] = {["id"] = "grade", ["desc"] = "等级"}, ["name"] = {["id"] = "name", ["desc"] = "玩家名字"}, ["pid"] = {["id"] = "pid", ["desc"] = "玩家id"}, ["show_id"] = {["id"] = "show_id", ["desc"] = "显示id"}},
        subtype = "add_fmt",
    },

    ["fmt_exp"] = {
        explain = "阵法经验",
        log_format = {["channel"] = {["id"] = "channel", ["desc"] = "渠道"}, ["exp_add"] = {["id"] = "exp_add", ["desc"] = "新加经验"}, ["exp_now"] = {["id"] = "exp_now", ["desc"] = "现经验"}, ["exp_old"] = {["id"] = "exp_old", ["desc"] = "原经验"}, ["fmt_id"] = {["id"] = "fmt_id", ["desc"] = "阵法ID"}, ["grade"] = {["id"] = "grade", ["desc"] = "等级"}, ["grade_now"] = {["id"] = "grade_now", ["desc"] = "现等级"}, ["grade_old"] = {["id"] = "grade_old", ["desc"] = "原等级"}, ["name"] = {["id"] = "name", ["desc"] = "玩家名字"}, ["pid"] = {["id"] = "pid", ["desc"] = "玩家id"}, ["show_id"] = {["id"] = "show_id", ["desc"] = "显示id"}},
        subtype = "fmt_exp",
    },

    ["fmt_set"] = {
        explain = "设置当前阵法",
        log_format = {["channel"] = {["id"] = "channel", ["desc"] = "渠道"}, ["fmt_now"] = {["id"] = "fmt_now", ["desc"] = "现阵法"}, ["fmt_old"] = {["id"] = "fmt_old", ["desc"] = "原阵法"}, ["grade"] = {["id"] = "grade", ["desc"] = "等级"}, ["name"] = {["id"] = "name", ["desc"] = "玩家名字"}, ["pid"] = {["id"] = "pid", ["desc"] = "玩家id"}, ["show_id"] = {["id"] = "show_id", ["desc"] = "显示id"}},
        subtype = "fmt_set",
    },

    ["fmt_fastup"] = {
        explain = "便捷阵法升级",
        log_format = {["channel"] = {["id"] = "channel", ["desc"] = "渠道"}, ["cost"] = {["id"] = "cost", ["desc"] = "道具花费"}, ["exp_add"] = {["id"] = "exp_add", ["desc"] = "新加经验"}, ["fmt_id"] = {["id"] = "fmt_id", ["desc"] = "阵法ID"}, ["grade"] = {["id"] = "grade", ["desc"] = "等级"}, ["name"] = {["id"] = "name", ["desc"] = "玩家名字"}, ["pid"] = {["id"] = "pid", ["desc"] = "玩家id"}, ["show_id"] = {["id"] = "show_id", ["desc"] = "显示id"}},
        subtype = "fmt_fastup",
    },

}
