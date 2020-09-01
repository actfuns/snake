-- ./excel/log/artifact.xlsx
return {

    ["add_exp"] = {
        explain = "神器升级",
        log_format = {["add_exp"] = {["id"] = "add_exp", ["desc"] = "增加经验"}, ["channel"] = {["id"] = "channel", ["desc"] = "渠道"}, ["grade"] = {["id"] = "grade", ["desc"] = "等级"}, ["name"] = {["id"] = "name", ["desc"] = "玩家名字"}, ["now_exp"] = {["id"] = "now_exp", ["desc"] = "当前经验"}, ["now_grade"] = {["id"] = "now_grade", ["desc"] = "玩家现等级"}, ["old_grade"] = {["id"] = "old_grade", ["desc"] = "原神器等级"}, ["pid"] = {["id"] = "pid", ["desc"] = "玩家id"}, ["reason"] = {["id"] = "reason", ["desc"] = "原因"}, ["show_id"] = {["id"] = "show_id", ["desc"] = "显示id"}},
        subtype = "add_exp",
    },

    ["strength"] = {
        explain = "神器强化",
        log_format = {["add_exp"] = {["id"] = "add_exp", ["desc"] = "增加强化经验"}, ["channel"] = {["id"] = "channel", ["desc"] = "渠道"}, ["grade"] = {["id"] = "grade", ["desc"] = "等级"}, ["name"] = {["id"] = "name", ["desc"] = "玩家名字"}, ["now_exp"] = {["id"] = "now_exp", ["desc"] = "当前强化经验"}, ["now_grade"] = {["id"] = "now_grade", ["desc"] = "当前强化等级"}, ["old_grade"] = {["id"] = "old_grade", ["desc"] = "原强化等级"}, ["pid"] = {["id"] = "pid", ["desc"] = "玩家id"}, ["reason"] = {["id"] = "reason", ["desc"] = "原因"}, ["show_id"] = {["id"] = "show_id", ["desc"] = "显示id"}},
        subtype = "strength",
    },

    ["wakeup_spirit"] = {
        explain = "器灵唤醒",
        log_format = {["channel"] = {["id"] = "channel", ["desc"] = "渠道"}, ["grade"] = {["id"] = "grade", ["desc"] = "等级"}, ["name"] = {["id"] = "name", ["desc"] = "玩家名字"}, ["pid"] = {["id"] = "pid", ["desc"] = "玩家id"}, ["show_id"] = {["id"] = "show_id", ["desc"] = "显示id"}, ["skill"] = {["id"] = "skill", ["desc"] = "初始技能"}, ["wakeup_spirit"] = {["id"] = "wakeup_spirit", ["desc"] = "唤醒器灵"}},
        subtype = "wakeup_spirit",
    },

    ["follow_spirit"] = {
        explain = "器灵跟随",
        log_format = {["channel"] = {["id"] = "channel", ["desc"] = "渠道"}, ["follow_spirit"] = {["id"] = "follow_spirit", ["desc"] = "跟随器灵"}, ["grade"] = {["id"] = "grade", ["desc"] = "等级"}, ["name"] = {["id"] = "name", ["desc"] = "玩家名字"}, ["pid"] = {["id"] = "pid", ["desc"] = "玩家id"}, ["show_id"] = {["id"] = "show_id", ["desc"] = "显示id"}},
        subtype = "follow_spirit",
    },

    ["fight_spirit"] = {
        explain = "器灵参战",
        log_format = {["channel"] = {["id"] = "channel", ["desc"] = "渠道"}, ["fight_spirit"] = {["id"] = "fight_spirit", ["desc"] = "跟随器灵"}, ["grade"] = {["id"] = "grade", ["desc"] = "等级"}, ["name"] = {["id"] = "name", ["desc"] = "玩家名字"}, ["pid"] = {["id"] = "pid", ["desc"] = "玩家id"}, ["show_id"] = {["id"] = "show_id", ["desc"] = "显示id"}},
        subtype = "fight_spirit",
    },

    ["skill"] = {
        explain = "器灵技能",
        log_format = {["bak_skill"] = {["id"] = "bak_skill", ["desc"] = "缓存技能"}, ["channel"] = {["id"] = "channel", ["desc"] = "渠道"}, ["grade"] = {["id"] = "grade", ["desc"] = "等级"}, ["name"] = {["id"] = "name", ["desc"] = "玩家名字"}, ["pid"] = {["id"] = "pid", ["desc"] = "玩家id"}, ["show_id"] = {["id"] = "show_id", ["desc"] = "显示id"}, ["skill"] = {["id"] = "skill", ["desc"] = "拥有技能"}, ["spirit"] = {["id"] = "spirit", ["desc"] = "器灵"}},
        subtype = "skill",
    },

}
