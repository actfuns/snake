-- ./excel/log/fabao.xlsx
return {

    ["add_fabao"] = {
        explain = "增加法宝",
        log_format = {["exp"] = {["id"] = "exp", ["desc"] = "经验"}, ["fabao"] = {["id"] = "fabao", ["desc"] = "法宝编号"}, ["level"] = {["id"] = "level", ["desc"] = "等级"}, ["pid"] = {["id"] = "pid", ["desc"] = "玩家id"}, ["reason"] = {["id"] = "reason", ["desc"] = "理由"}},
        subtype = "add_fabao",
    },

    ["remove_fabao"] = {
        explain = "删除法宝",
        log_format = {["exp"] = {["id"] = "exp", ["desc"] = "经验"}, ["fabao"] = {["id"] = "fabao", ["desc"] = "法宝编号"}, ["level"] = {["id"] = "level", ["desc"] = "等级"}, ["pid"] = {["id"] = "pid", ["desc"] = "玩家id"}, ["reason"] = {["id"] = "reason", ["desc"] = "理由"}},
        subtype = "remove_fabao",
    },

    ["wield_fabao"] = {
        explain = "装载法宝",
        log_format = {["exp"] = {["id"] = "exp", ["desc"] = "经验"}, ["fabao"] = {["id"] = "fabao", ["desc"] = "法宝编号"}, ["level"] = {["id"] = "level", ["desc"] = "等级"}, ["pid"] = {["id"] = "pid", ["desc"] = "玩家id"}, ["pos"] = {["id"] = "pos", ["desc"] = "位置"}},
        subtype = "wield_fabao",
    },

    ["unwield_fabao"] = {
        explain = "卸载法宝",
        log_format = {["exp"] = {["id"] = "exp", ["desc"] = "经验"}, ["fabao"] = {["id"] = "fabao", ["desc"] = "法宝编号"}, ["level"] = {["id"] = "level", ["desc"] = "等级"}, ["pid"] = {["id"] = "pid", ["desc"] = "玩家id"}, ["pos"] = {["id"] = "pos", ["desc"] = "位置"}},
        subtype = "unwield_fabao",
    },

    ["combine_fabao"] = {
        explain = "合成法宝",
        log_format = {["channel"] = {["id"] = "channel", ["desc"] = "渠道"}, ["cost"] = {["id"] = "cost", ["desc"] = "消耗"}, ["fabaoid"] = {["id"] = "fabaoid", ["desc"] = "法宝ID"}, ["grade"] = {["id"] = "grade", ["desc"] = "等级"}, ["name"] = {["id"] = "name", ["desc"] = "玩家名字"}, ["pid"] = {["id"] = "pid", ["desc"] = "玩家id"}, ["show_id"] = {["id"] = "show_id", ["desc"] = "显示id"}},
        subtype = "combine_fabao",
    },

    ["decombine_fabao"] = {
        explain = "分解法宝",
        log_format = {["channel"] = {["id"] = "channel", ["desc"] = "渠道"}, ["fabaoid"] = {["id"] = "fabaoid", ["desc"] = "法宝ID"}, ["grade"] = {["id"] = "grade", ["desc"] = "等级"}, ["name"] = {["id"] = "name", ["desc"] = "玩家名字"}, ["pid"] = {["id"] = "pid", ["desc"] = "玩家id"}, ["reward"] = {["id"] = "reward", ["desc"] = "获得物品"}, ["show_id"] = {["id"] = "show_id", ["desc"] = "显示id"}},
        subtype = "decombine_fabao",
    },

    ["upgrade_fabao"] = {
        explain = "升级法宝",
        log_format = {["channel"] = {["id"] = "channel", ["desc"] = "渠道"}, ["cost"] = {["id"] = "cost", ["desc"] = "消耗"}, ["fabaoid"] = {["id"] = "fabaoid", ["desc"] = "法宝ID"}, ["grade"] = {["id"] = "grade", ["desc"] = "等级"}, ["name"] = {["id"] = "name", ["desc"] = "玩家名字"}, ["now_exp"] = {["id"] = "now_exp", ["desc"] = "现经验"}, ["now_level"] = {["id"] = "now_level", ["desc"] = "现等级"}, ["pid"] = {["id"] = "pid", ["desc"] = "玩家id"}, ["pre_exp"] = {["id"] = "pre_exp", ["desc"] = "前经验"}, ["pre_level"] = {["id"] = "pre_level", ["desc"] = "前等级"}, ["show_id"] = {["id"] = "show_id", ["desc"] = "显示id"}},
        subtype = "upgrade_fabao",
    },

    ["xianling_fabao"] = {
        explain = "仙灵法宝",
        log_format = {["channel"] = {["id"] = "channel", ["desc"] = "渠道"}, ["cost"] = {["id"] = "cost", ["desc"] = "消耗"}, ["fabaoid"] = {["id"] = "fabaoid", ["desc"] = "法宝ID"}, ["grade"] = {["id"] = "grade", ["desc"] = "等级"}, ["name"] = {["id"] = "name", ["desc"] = "玩家名字"}, ["pid"] = {["id"] = "pid", ["desc"] = "玩家id"}, ["show_id"] = {["id"] = "show_id", ["desc"] = "显示id"}},
        subtype = "xianling_fabao",
    },

    ["juexing_fabao"] = {
        explain = "觉醒法宝",
        log_format = {["channel"] = {["id"] = "channel", ["desc"] = "渠道"}, ["cost"] = {["id"] = "cost", ["desc"] = "消耗"}, ["fabaoid"] = {["id"] = "fabaoid", ["desc"] = "法宝ID"}, ["grade"] = {["id"] = "grade", ["desc"] = "等级"}, ["name"] = {["id"] = "name", ["desc"] = "玩家名字"}, ["pid"] = {["id"] = "pid", ["desc"] = "玩家id"}, ["show_id"] = {["id"] = "show_id", ["desc"] = "显示id"}},
        subtype = "juexing_fabao",
    },

    ["jx_upgrade_fabao"] = {
        explain = "升级觉醒法宝",
        log_format = {["channel"] = {["id"] = "channel", ["desc"] = "渠道"}, ["cost"] = {["id"] = "cost", ["desc"] = "消耗"}, ["fabaoid"] = {["id"] = "fabaoid", ["desc"] = "法宝ID"}, ["grade"] = {["id"] = "grade", ["desc"] = "等级"}, ["name"] = {["id"] = "name", ["desc"] = "玩家名字"}, ["now_exp"] = {["id"] = "now_exp", ["desc"] = "现经验"}, ["now_level"] = {["id"] = "now_level", ["desc"] = "现等级"}, ["pid"] = {["id"] = "pid", ["desc"] = "玩家id"}, ["pre_exp"] = {["id"] = "pre_exp", ["desc"] = "前经验"}, ["pre_level"] = {["id"] = "pre_level", ["desc"] = "前等级"}, ["show_id"] = {["id"] = "show_id", ["desc"] = "显示id"}},
        subtype = "jx_upgrade_fabao",
    },

    ["jx_hun_fabao"] = {
        explain = "法宝魂",
        log_format = {["channel"] = {["id"] = "channel", ["desc"] = "渠道"}, ["cost"] = {["id"] = "cost", ["desc"] = "消耗"}, ["fabaoid"] = {["id"] = "fabaoid", ["desc"] = "法宝ID"}, ["grade"] = {["id"] = "grade", ["desc"] = "等级"}, ["name"] = {["id"] = "name", ["desc"] = "玩家名字"}, ["pid"] = {["id"] = "pid", ["desc"] = "玩家id"}, ["show_id"] = {["id"] = "show_id", ["desc"] = "显示id"}},
        subtype = "jx_hun_fabao",
    },

}
