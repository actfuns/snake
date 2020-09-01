-- ./excel/log/friend.xlsx
return {

    ["add_friend"] = {
        explain = "添加好友",
        log_format = {["channel"] = {["id"] = "channel", ["desc"] = "渠道"}, ["degree"] = {["id"] = "degree", ["desc"] = "好友度"}, ["fid"] = {["id"] = "fid", ["desc"] = "好友id"}, ["grade"] = {["id"] = "grade", ["desc"] = "等级"}, ["name"] = {["id"] = "name", ["desc"] = "玩家名字"}, ["pid"] = {["id"] = "pid", ["desc"] = "玩家id"}, ["show_id"] = {["id"] = "show_id", ["desc"] = "显示id"}},
        subtype = "add_friend",
    },

    ["degree"] = {
        explain = "好友度变动",
        log_format = {["channel"] = {["id"] = "channel", ["desc"] = "渠道"}, ["degree_add"] = {["id"] = "degree_add", ["desc"] = "新增好友度"}, ["degree_now"] = {["id"] = "degree_now", ["desc"] = "现好友度"}, ["degree_old"] = {["id"] = "degree_old", ["desc"] = "原好友度"}, ["fid"] = {["id"] = "fid", ["desc"] = "好友id"}, ["grade"] = {["id"] = "grade", ["desc"] = "等级"}, ["name"] = {["id"] = "name", ["desc"] = "玩家名字"}, ["pid"] = {["id"] = "pid", ["desc"] = "玩家id"}, ["show_id"] = {["id"] = "show_id", ["desc"] = "显示id"}},
        subtype = "degree",
    },

    ["shield"] = {
        explain = "屏蔽操作",
        log_format = {["channel"] = {["id"] = "channel", ["desc"] = "渠道"}, ["fid"] = {["id"] = "fid", ["desc"] = "好友id"}, ["grade"] = {["id"] = "grade", ["desc"] = "等级"}, ["name"] = {["id"] = "name", ["desc"] = "玩家名字"}, ["op"] = {["id"] = "op", ["desc"] = "操作"}, ["pid"] = {["id"] = "pid", ["desc"] = "玩家id"}, ["show_id"] = {["id"] = "show_id", ["desc"] = "显示id"}},
        subtype = "shield",
    },

    ["del_friend"] = {
        explain = "删除好友",
        log_format = {["channel"] = {["id"] = "channel", ["desc"] = "渠道"}, ["fid"] = {["id"] = "fid", ["desc"] = "好友id"}, ["grade"] = {["id"] = "grade", ["desc"] = "等级"}, ["name"] = {["id"] = "name", ["desc"] = "玩家名字"}, ["pid"] = {["id"] = "pid", ["desc"] = "玩家id"}, ["show_id"] = {["id"] = "show_id", ["desc"] = "显示id"}},
        subtype = "del_friend",
    },

    ["engage"] = {
        explain = "订婚",
        log_format = {["channel"] = {["id"] = "channel", ["desc"] = "渠道"}, ["engage_pid"] = {["id"] = "engage_pid", ["desc"] = "订婚PID"}, ["grade"] = {["id"] = "grade", ["desc"] = "等级"}, ["name"] = {["id"] = "name", ["desc"] = "玩家名字"}, ["pid"] = {["id"] = "pid", ["desc"] = "玩家id"}, ["show_id"] = {["id"] = "show_id", ["desc"] = "显示id"}, ["type"] = {["id"] = "type", ["desc"] = "类型"}},
        subtype = "engage",
    },

    ["dissolve_engage"] = {
        explain = "取消订婚",
        log_format = {["channel"] = {["id"] = "channel", ["desc"] = "渠道"}, ["engage_pid"] = {["id"] = "engage_pid", ["desc"] = "订婚PID"}, ["grade"] = {["id"] = "grade", ["desc"] = "等级"}, ["name"] = {["id"] = "name", ["desc"] = "玩家名字"}, ["pid"] = {["id"] = "pid", ["desc"] = "玩家id"}, ["show_id"] = {["id"] = "show_id", ["desc"] = "显示id"}, ["silver"] = {["id"] = "silver", ["desc"] = "花费银币"}, ["type"] = {["id"] = "type", ["desc"] = "类型"}},
        subtype = "dissolve_engage",
    },

    ["flower"] = {
        explain = "魅力变动",
        log_format = {["channel"] = {["id"] = "channel", ["desc"] = "渠道"}, ["fid"] = {["id"] = "fid", ["desc"] = "好友id"}, ["flower_add"] = {["id"] = "flower_add", ["desc"] = "新增魅力值"}, ["flower_now"] = {["id"] = "flower_now", ["desc"] = "现魅力值"}, ["grade"] = {["id"] = "grade", ["desc"] = "等级"}, ["name"] = {["id"] = "name", ["desc"] = "玩家名字"}, ["pid"] = {["id"] = "pid", ["desc"] = "玩家id"}, ["show_id"] = {["id"] = "show_id", ["desc"] = "显示id"}},
        subtype = "flower",
    },

}
