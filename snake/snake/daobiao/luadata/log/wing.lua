-- ./excel/log/wing.xlsx
return {

    ["add_exp"] = {
        explain = "翅膀升星",
        log_format = {["add_exp"] = {["id"] = "add_exp", ["desc"] = "增加经验"}, ["channel"] = {["id"] = "channel", ["desc"] = "渠道"}, ["grade"] = {["id"] = "grade", ["desc"] = "等级"}, ["name"] = {["id"] = "name", ["desc"] = "玩家名字"}, ["now_exp"] = {["id"] = "now_exp", ["desc"] = "当前经验"}, ["now_star"] = {["id"] = "now_star", ["desc"] = "现星级"}, ["old_star"] = {["id"] = "old_star", ["desc"] = "原翅膀星级"}, ["pid"] = {["id"] = "pid", ["desc"] = "玩家id"}, ["reason"] = {["id"] = "reason", ["desc"] = "原因"}, ["show_id"] = {["id"] = "show_id", ["desc"] = "显示id"}},
        subtype = "add_exp",
    },

    ["add_level"] = {
        explain = "翅膀升阶",
        log_format = {["add_level"] = {["id"] = "add_level", ["desc"] = "增加等阶"}, ["channel"] = {["id"] = "channel", ["desc"] = "渠道"}, ["grade"] = {["id"] = "grade", ["desc"] = "等级"}, ["name"] = {["id"] = "name", ["desc"] = "玩家名字"}, ["now_level"] = {["id"] = "now_level", ["desc"] = "当前翅膀等阶"}, ["old_level"] = {["id"] = "old_level", ["desc"] = "原翅膀等阶"}, ["pid"] = {["id"] = "pid", ["desc"] = "玩家id"}, ["reason"] = {["id"] = "reason", ["desc"] = "原因"}, ["show_id"] = {["id"] = "show_id", ["desc"] = "显示id"}},
        subtype = "add_level",
    },

    ["show_wing"] = {
        explain = "翅膀显示",
        log_format = {["channel"] = {["id"] = "channel", ["desc"] = "渠道"}, ["grade"] = {["id"] = "grade", ["desc"] = "等级"}, ["name"] = {["id"] = "name", ["desc"] = "玩家名字"}, ["pid"] = {["id"] = "pid", ["desc"] = "玩家id"}, ["show_id"] = {["id"] = "show_id", ["desc"] = "显示id"}, ["show_wing"] = {["id"] = "show_wing", ["desc"] = "翅膀id"}},
        subtype = "show_wing",
    },

    ["time_wing"] = {
        explain = "翅膀延期",
        log_format = {["channel"] = {["id"] = "channel", ["desc"] = "渠道"}, ["expire"] = {["id"] = "expire", ["desc"] = "过期时间"}, ["grade"] = {["id"] = "grade", ["desc"] = "等级"}, ["name"] = {["id"] = "name", ["desc"] = "玩家名字"}, ["pid"] = {["id"] = "pid", ["desc"] = "玩家id"}, ["show_id"] = {["id"] = "show_id", ["desc"] = "显示id"}, ["wing"] = {["id"] = "wing", ["desc"] = "唤醒翅膀"}},
        subtype = "time_wing",
    },

}
