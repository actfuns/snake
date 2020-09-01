-- ./excel/log/playerskill.xlsx
return {

    ["learn_skill"] = {
        explain = "学习技能",
        log_format = {["add_level"] = {["id"] = "add_level", ["desc"] = "增加等级"}, ["channel"] = {["id"] = "channel", ["desc"] = "渠道"}, ["goldcoin"] = {["id"] = "goldcoin", ["desc"] = "快捷元宝"}, ["grade"] = {["id"] = "grade", ["desc"] = "等级"}, ["level_now"] = {["id"] = "level_now", ["desc"] = "当前等级"}, ["level_old"] = {["id"] = "level_old", ["desc"] = "原有等级"}, ["name"] = {["id"] = "name", ["desc"] = "玩家名字"}, ["pid"] = {["id"] = "pid", ["desc"] = "玩家id"}, ["point_cost"] = {["id"] = "point_cost", ["desc"] = "技能点消耗"}, ["show_id"] = {["id"] = "show_id", ["desc"] = "显示id"}, ["silver_cost"] = {["id"] = "silver_cost", ["desc"] = "消耗银币"}, ["skid"] = {["id"] = "skid", ["desc"] = "技能id"}, ["sktype"] = {["id"] = "sktype", ["desc"] = "技能类型"}},
        subtype = "learn_skill",
    },

    ["fast_learn_skill"] = {
        explain = "快速学习技能",
        log_format = {["add_level"] = {["id"] = "add_level", ["desc"] = "增加等级"}, ["channel"] = {["id"] = "channel", ["desc"] = "渠道"}, ["goldcoin"] = {["id"] = "goldcoin", ["desc"] = "快捷元宝"}, ["grade"] = {["id"] = "grade", ["desc"] = "等级"}, ["level_now"] = {["id"] = "level_now", ["desc"] = "当前等级"}, ["level_old"] = {["id"] = "level_old", ["desc"] = "原有等级"}, ["name"] = {["id"] = "name", ["desc"] = "玩家名字"}, ["pid"] = {["id"] = "pid", ["desc"] = "玩家id"}, ["point_cost"] = {["id"] = "point_cost", ["desc"] = "技能点消耗"}, ["show_id"] = {["id"] = "show_id", ["desc"] = "显示id"}, ["silver_cost"] = {["id"] = "silver_cost", ["desc"] = "消耗银币"}, ["skid"] = {["id"] = "skid", ["desc"] = "技能id"}, ["sktype"] = {["id"] = "sktype", ["desc"] = "技能类型"}},
        subtype = "fast_learn_skill",
    },

    ["reset_active_skill"] = {
        explain = "重置门派技能",
        log_format = {["add_point"] = {["id"] = "add_point", ["desc"] = "获取技能点"}, ["channel"] = {["id"] = "channel", ["desc"] = "渠道"}, ["gold_cost"] = {["id"] = "gold_cost", ["desc"] = "消耗金币"}, ["grade"] = {["id"] = "grade", ["desc"] = "等级"}, ["item_cost"] = {["id"] = "item_cost", ["desc"] = "消耗物品"}, ["level_old"] = {["id"] = "level_old", ["desc"] = "原有等级"}, ["name"] = {["id"] = "name", ["desc"] = "玩家名字"}, ["pid"] = {["id"] = "pid", ["desc"] = "玩家id"}, ["show_id"] = {["id"] = "show_id", ["desc"] = "显示id"}, ["skid"] = {["id"] = "skid", ["desc"] = "技能id"}},
        subtype = "reset_active_skill",
    },

    ["learn_cultivate_skill"] = {
        explain = "学习修炼技能",
        log_format = {["channel"] = {["id"] = "channel", ["desc"] = "渠道"}, ["exp_now"] = {["id"] = "exp_now", ["desc"] = "当前经验"}, ["exp_old"] = {["id"] = "exp_old", ["desc"] = "原有经验"}, ["grade"] = {["id"] = "grade", ["desc"] = "等级"}, ["item_cost"] = {["id"] = "item_cost", ["desc"] = "物品消耗"}, ["level_now"] = {["id"] = "level_now", ["desc"] = "当前等级"}, ["level_old"] = {["id"] = "level_old", ["desc"] = "原有等级"}, ["name"] = {["id"] = "name", ["desc"] = "玩家名字"}, ["pid"] = {["id"] = "pid", ["desc"] = "玩家id"}, ["show_id"] = {["id"] = "show_id", ["desc"] = "显示id"}, ["silver_cost"] = {["id"] = "silver_cost", ["desc"] = "消耗银币"}, ["skid"] = {["id"] = "skid", ["desc"] = "技能id"}},
        subtype = "learn_cultivate_skill",
    },

    ["set_cultivate_skill"] = {
        explain = "设置当前修炼技能",
        log_format = {["channel"] = {["id"] = "channel", ["desc"] = "渠道"}, ["grade"] = {["id"] = "grade", ["desc"] = "等级"}, ["name"] = {["id"] = "name", ["desc"] = "玩家名字"}, ["pid"] = {["id"] = "pid", ["desc"] = "玩家id"}, ["show_id"] = {["id"] = "show_id", ["desc"] = "显示id"}, ["skid"] = {["id"] = "skid", ["desc"] = "技能id"}},
        subtype = "set_cultivate_skill",
    },

    ["fuzhuan_skill_add"] = {
        explain = "学习符篆技能",
        log_format = {["add_level"] = {["id"] = "add_level", ["desc"] = "增加等级"}, ["channel"] = {["id"] = "channel", ["desc"] = "渠道"}, ["cur_level"] = {["id"] = "cur_level", ["desc"] = "当前等级"}, ["grade"] = {["id"] = "grade", ["desc"] = "等级"}, ["name"] = {["id"] = "name", ["desc"] = "玩家名字"}, ["pid"] = {["id"] = "pid", ["desc"] = "玩家id"}, ["show_id"] = {["id"] = "show_id", ["desc"] = "显示id"}, ["skill"] = {["id"] = "skill", ["desc"] = "剧情技能"}, ["storypoint"] = {["id"] = "storypoint", ["desc"] = "剧情点"}},
        subtype = "fuzhuan_skill_add",
    },

    ["fuzhuan_skill_reset"] = {
        explain = "重置符篆技能",
        log_format = {["channel"] = {["id"] = "channel", ["desc"] = "渠道"}, ["cur_level"] = {["id"] = "cur_level", ["desc"] = "当前等级"}, ["grade"] = {["id"] = "grade", ["desc"] = "等级"}, ["name"] = {["id"] = "name", ["desc"] = "玩家名字"}, ["pid"] = {["id"] = "pid", ["desc"] = "玩家id"}, ["show_id"] = {["id"] = "show_id", ["desc"] = "显示id"}, ["skill"] = {["id"] = "skill", ["desc"] = "剧情技能"}, ["storypoint"] = {["id"] = "storypoint", ["desc"] = "剧情点"}, ["sub_level"] = {["id"] = "sub_level", ["desc"] = "减少等级"}},
        subtype = "fuzhuan_skill_reset",
    },

}
