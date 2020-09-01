-- ./excel/log/ride.xlsx
return {

    ["activate_ride"] = {
        explain = "激活坐骑",
        log_format = {["channel"] = {["id"] = "channel", ["desc"] = "渠道"}, ["cost"] = {["id"] = "cost", ["desc"] = "消耗"}, ["grade"] = {["id"] = "grade", ["desc"] = "等级"}, ["name"] = {["id"] = "name", ["desc"] = "玩家名字"}, ["pid"] = {["id"] = "pid", ["desc"] = "玩家id"}, ["ride_id"] = {["id"] = "ride_id", ["desc"] = "坐骑ID"}, ["show_id"] = {["id"] = "show_id", ["desc"] = "显示id"}},
        subtype = "activate_ride",
    },

    ["upgrade_ride"] = {
        explain = "坐骑升级",
        log_format = {["channel"] = {["id"] = "channel", ["desc"] = "渠道"}, ["cost"] = {["id"] = "cost", ["desc"] = "消耗"}, ["grade"] = {["id"] = "grade", ["desc"] = "等级"}, ["name"] = {["id"] = "name", ["desc"] = "玩家名字"}, ["pid"] = {["id"] = "pid", ["desc"] = "玩家id"}, ["ridelv"] = {["id"] = "ridelv", ["desc"] = "坐骑等级"}, ["show_id"] = {["id"] = "show_id", ["desc"] = "显示id"}},
        subtype = "upgrade_ride",
    },

    ["buy_time_ride"] = {
        explain = "续费",
        log_format = {["channel"] = {["id"] = "channel", ["desc"] = "渠道"}, ["cost"] = {["id"] = "cost", ["desc"] = "消耗"}, ["grade"] = {["id"] = "grade", ["desc"] = "等级"}, ["name"] = {["id"] = "name", ["desc"] = "玩家名字"}, ["pid"] = {["id"] = "pid", ["desc"] = "玩家id"}, ["ride_id"] = {["id"] = "ride_id", ["desc"] = "坐骑ID"}, ["show_id"] = {["id"] = "show_id", ["desc"] = "显示id"}},
        subtype = "buy_time_ride",
    },

    ["random_skill"] = {
        explain = "随机技能",
        log_format = {["channel"] = {["id"] = "channel", ["desc"] = "渠道"}, ["goldcoin"] = {["id"] = "goldcoin", ["desc"] = "金币"}, ["grade"] = {["id"] = "grade", ["desc"] = "等级"}, ["name"] = {["id"] = "name", ["desc"] = "玩家名字"}, ["pid"] = {["id"] = "pid", ["desc"] = "玩家id"}, ["show_id"] = {["id"] = "show_id", ["desc"] = "显示id"}},
        subtype = "random_skill",
    },

    ["reset_skill"] = {
        explain = "遗忘技能",
        log_format = {["channel"] = {["id"] = "channel", ["desc"] = "渠道"}, ["cost"] = {["id"] = "cost", ["desc"] = "消耗"}, ["flag"] = {["id"] = "flag", ["desc"] = "是否全部"}, ["grade"] = {["id"] = "grade", ["desc"] = "等级"}, ["name"] = {["id"] = "name", ["desc"] = "玩家名字"}, ["pid"] = {["id"] = "pid", ["desc"] = "玩家id"}, ["show_id"] = {["id"] = "show_id", ["desc"] = "显示id"}, ["skid"] = {["id"] = "skid", ["desc"] = "技能ID"}},
        subtype = "reset_skill",
    },

    ["ride_break"] = {
        explain = "坐骑突破",
        log_format = {["channel"] = {["id"] = "channel", ["desc"] = "渠道"}, ["cost"] = {["id"] = "cost", ["desc"] = "消耗"}, ["grade"] = {["id"] = "grade", ["desc"] = "等级"}, ["name"] = {["id"] = "name", ["desc"] = "玩家名字"}, ["pid"] = {["id"] = "pid", ["desc"] = "玩家id"}, ["ridelv"] = {["id"] = "ridelv", ["desc"] = "坐骑等级"}, ["show_id"] = {["id"] = "show_id", ["desc"] = "显示id"}},
        subtype = "ride_break",
    },

    ["reset_ride"] = {
        explain = "重置坐骑",
        log_format = {["channel"] = {["id"] = "channel", ["desc"] = "渠道"}, ["grade"] = {["id"] = "grade", ["desc"] = "等级"}, ["name"] = {["id"] = "name", ["desc"] = "玩家名字"}, ["newexp"] = {["id"] = "newexp", ["desc"] = "新经验"}, ["newlv"] = {["id"] = "newlv", ["desc"] = "新等级"}, ["oldexp"] = {["id"] = "oldexp", ["desc"] = "原经验"}, ["oldlv"] = {["id"] = "oldlv", ["desc"] = "原等级"}, ["pid"] = {["id"] = "pid", ["desc"] = "玩家id"}, ["show_id"] = {["id"] = "show_id", ["desc"] = "显示id"}},
        subtype = "reset_ride",
    },

    ["exp"] = {
        explain = "坐骑经验",
        log_format = {["addexp"] = {["id"] = "addexp", ["desc"] = "增加经验"}, ["channel"] = {["id"] = "channel", ["desc"] = "渠道"}, ["grade"] = {["id"] = "grade", ["desc"] = "等级"}, ["name"] = {["id"] = "name", ["desc"] = "玩家名字"}, ["newexp"] = {["id"] = "newexp", ["desc"] = "新经验"}, ["newlv"] = {["id"] = "newlv", ["desc"] = "新等级"}, ["oldexp"] = {["id"] = "oldexp", ["desc"] = "原经验"}, ["oldlv"] = {["id"] = "oldlv", ["desc"] = "原等级"}, ["pid"] = {["id"] = "pid", ["desc"] = "玩家id"}, ["reason"] = {["id"] = "reason", ["desc"] = "原因"}, ["show_id"] = {["id"] = "show_id", ["desc"] = "显示id"}},
        subtype = "exp",
    },

    ["add_ride"] = {
        explain = "增加坐骑",
        log_format = {["channel"] = {["id"] = "channel", ["desc"] = "渠道"}, ["grade"] = {["id"] = "grade", ["desc"] = "等级"}, ["name"] = {["id"] = "name", ["desc"] = "玩家名字"}, ["pid"] = {["id"] = "pid", ["desc"] = "玩家id"}, ["ride_id"] = {["id"] = "ride_id", ["desc"] = "坐骑ID"}, ["show_id"] = {["id"] = "show_id", ["desc"] = "显示id"}},
        subtype = "add_ride",
    },

    ["wield_wenshi"] = {
        explain = "纹饰装载",
        log_format = {["channel"] = {["id"] = "channel", ["desc"] = "渠道"}, ["grade"] = {["id"] = "grade", ["desc"] = "等级"}, ["item"] = {["id"] = "item", ["desc"] = "纹饰"}, ["name"] = {["id"] = "name", ["desc"] = "玩家名字"}, ["pid"] = {["id"] = "pid", ["desc"] = "玩家id"}, ["ride_id"] = {["id"] = "ride_id", ["desc"] = "坐骑ID"}, ["show_id"] = {["id"] = "show_id", ["desc"] = "显示id"}},
        subtype = "wield_wenshi",
    },

    ["unwield_wenshi"] = {
        explain = "纹饰卸载",
        log_format = {["channel"] = {["id"] = "channel", ["desc"] = "渠道"}, ["flag"] = {["id"] = "flag", ["desc"] = "是否丢失"}, ["grade"] = {["id"] = "grade", ["desc"] = "等级"}, ["item"] = {["id"] = "item", ["desc"] = "纹饰"}, ["name"] = {["id"] = "name", ["desc"] = "玩家名字"}, ["pid"] = {["id"] = "pid", ["desc"] = "玩家id"}, ["ride_id"] = {["id"] = "ride_id", ["desc"] = "坐骑ID"}, ["show_id"] = {["id"] = "show_id", ["desc"] = "显示id"}},
        subtype = "unwield_wenshi",
    },

    ["control_summon"] = {
        explain = "统御",
        log_format = {["channel"] = {["id"] = "channel", ["desc"] = "渠道"}, ["grade"] = {["id"] = "grade", ["desc"] = "等级"}, ["name"] = {["id"] = "name", ["desc"] = "玩家名字"}, ["pid"] = {["id"] = "pid", ["desc"] = "玩家id"}, ["pos"] = {["id"] = "pos", ["desc"] = "位置"}, ["ride_id"] = {["id"] = "ride_id", ["desc"] = "坐骑ID"}, ["show_id"] = {["id"] = "show_id", ["desc"] = "显示id"}, ["summon"] = {["id"] = "summon", ["desc"] = "宠物"}},
        subtype = "control_summon",
    },

    ["uncontrol_summon"] = {
        explain = "取消统御",
        log_format = {["channel"] = {["id"] = "channel", ["desc"] = "渠道"}, ["grade"] = {["id"] = "grade", ["desc"] = "等级"}, ["name"] = {["id"] = "name", ["desc"] = "玩家名字"}, ["pid"] = {["id"] = "pid", ["desc"] = "玩家id"}, ["pos"] = {["id"] = "pos", ["desc"] = "位置"}, ["ride_id"] = {["id"] = "ride_id", ["desc"] = "坐骑ID"}, ["show_id"] = {["id"] = "show_id", ["desc"] = "显示id"}},
        subtype = "uncontrol_summon",
    },

}
