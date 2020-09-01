-- ./excel/log/summon.xlsx
return {

    ["wash_summon"] = {
        explain = "洗宠",
        log_format = {["channel"] = {["id"] = "channel", ["desc"] = "渠道"}, ["grade"] = {["id"] = "grade", ["desc"] = "等级"}, ["name"] = {["id"] = "name", ["desc"] = "玩家名字"}, ["pid"] = {["id"] = "pid", ["desc"] = "玩家id"}, ["show_id"] = {["id"] = "show_id", ["desc"] = "显示id"}, ["sid"] = {["id"] = "sid", ["desc"] = "宠物id"}, ["slevel"] = {["id"] = "slevel", ["desc"] = "宠物等级"}, ["sname"] = {["id"] = "sname", ["desc"] = "宠物名字"}, ["traceno"] = {["id"] = "traceno", ["desc"] = "宠物traceno"}},
        subtype = "wash_summon",
    },

    ["stick_skill"] = {
        explain = "打书",
        log_format = {["channel"] = {["id"] = "channel", ["desc"] = "渠道"}, ["cost"] = {["id"] = "cost", ["desc"] = "道具消耗"}, ["grade"] = {["id"] = "grade", ["desc"] = "等级"}, ["learn_sk"] = {["id"] = "learn_sk", ["desc"] = "学习技能"}, ["lose_sk"] = {["id"] = "lose_sk", ["desc"] = "丢失技能"}, ["name"] = {["id"] = "name", ["desc"] = "玩家名字"}, ["pid"] = {["id"] = "pid", ["desc"] = "玩家id"}, ["show_id"] = {["id"] = "show_id", ["desc"] = "显示id"}, ["sid"] = {["id"] = "sid", ["desc"] = "宠物id"}, ["slevel"] = {["id"] = "slevel", ["desc"] = "宠物等级"}, ["sname"] = {["id"] = "sname", ["desc"] = "宠物名字"}, ["traceno"] = {["id"] = "traceno", ["desc"] = "宠物traceno"}},
        subtype = "stick_skill",
    },

    ["skill_level_up"] = {
        explain = "技能升级",
        log_format = {["channel"] = {["id"] = "channel", ["desc"] = "渠道"}, ["cost_cnt"] = {["id"] = "cost_cnt", ["desc"] = "消耗数量"}, ["cost_item"] = {["id"] = "cost_item", ["desc"] = "消耗物品"}, ["grade"] = {["id"] = "grade", ["desc"] = "等级"}, ["name"] = {["id"] = "name", ["desc"] = "玩家名字"}, ["now_lv"] = {["id"] = "now_lv", ["desc"] = "当前等级"}, ["pid"] = {["id"] = "pid", ["desc"] = "玩家id"}, ["show_id"] = {["id"] = "show_id", ["desc"] = "显示id"}, ["sid"] = {["id"] = "sid", ["desc"] = "宠物id"}, ["skid"] = {["id"] = "skid", ["desc"] = "技能id"}, ["slevel"] = {["id"] = "slevel", ["desc"] = "宠物等级"}, ["sname"] = {["id"] = "sname", ["desc"] = "宠物名字"}, ["success"] = {["id"] = "success", ["desc"] = "是否成功"}, ["traceno"] = {["id"] = "traceno", ["desc"] = "宠物traceno"}},
        subtype = "skill_level_up",
    },

    ["change_name"] = {
        explain = "修改名称",
        log_format = {["channel"] = {["id"] = "channel", ["desc"] = "渠道"}, ["grade"] = {["id"] = "grade", ["desc"] = "等级"}, ["name"] = {["id"] = "name", ["desc"] = "玩家名字"}, ["new_name"] = {["id"] = "new_name", ["desc"] = "新名字"}, ["pid"] = {["id"] = "pid", ["desc"] = "玩家id"}, ["show_id"] = {["id"] = "show_id", ["desc"] = "显示id"}, ["sid"] = {["id"] = "sid", ["desc"] = "宠物id"}, ["slevel"] = {["id"] = "slevel", ["desc"] = "宠物等级"}, ["sname"] = {["id"] = "sname", ["desc"] = "宠物名字"}, ["traceno"] = {["id"] = "traceno", ["desc"] = "宠物traceno"}},
        subtype = "change_name",
    },

    ["set_fight"] = {
        explain = "设置战斗",
        log_format = {["channel"] = {["id"] = "channel", ["desc"] = "渠道"}, ["fight"] = {["id"] = "fight", ["desc"] = "是否战斗"}, ["grade"] = {["id"] = "grade", ["desc"] = "等级"}, ["name"] = {["id"] = "name", ["desc"] = "玩家名字"}, ["pid"] = {["id"] = "pid", ["desc"] = "玩家id"}, ["show_id"] = {["id"] = "show_id", ["desc"] = "显示id"}, ["sid"] = {["id"] = "sid", ["desc"] = "宠物id"}, ["slevel"] = {["id"] = "slevel", ["desc"] = "宠物等级"}, ["sname"] = {["id"] = "sname", ["desc"] = "宠物名字"}, ["traceno"] = {["id"] = "traceno", ["desc"] = "宠物traceno"}},
        subtype = "set_fight",
    },

    ["release_summon"] = {
        explain = "放生宠物",
        log_format = {["channel"] = {["id"] = "channel", ["desc"] = "渠道"}, ["grade"] = {["id"] = "grade", ["desc"] = "等级"}, ["name"] = {["id"] = "name", ["desc"] = "玩家名字"}, ["pid"] = {["id"] = "pid", ["desc"] = "玩家id"}, ["show_id"] = {["id"] = "show_id", ["desc"] = "显示id"}, ["sid"] = {["id"] = "sid", ["desc"] = "宠物id"}, ["slevel"] = {["id"] = "slevel", ["desc"] = "宠物等级"}, ["sname"] = {["id"] = "sname", ["desc"] = "宠物名字"}, ["traceno"] = {["id"] = "traceno", ["desc"] = "宠物traceno"}},
        subtype = "release_summon",
    },

    ["assign_point"] = {
        explain = "潜力分配",
        log_format = {["assign_point"] = {["id"] = "assign_point", ["desc"] = "分配点数"}, ["channel"] = {["id"] = "channel", ["desc"] = "渠道"}, ["grade"] = {["id"] = "grade", ["desc"] = "等级"}, ["name"] = {["id"] = "name", ["desc"] = "玩家名字"}, ["now_point"] = {["id"] = "now_point", ["desc"] = "当前点数"}, ["old_point"] = {["id"] = "old_point", ["desc"] = "原有点数"}, ["pid"] = {["id"] = "pid", ["desc"] = "玩家id"}, ["show_id"] = {["id"] = "show_id", ["desc"] = "显示id"}, ["sid"] = {["id"] = "sid", ["desc"] = "宠物id"}, ["slevel"] = {["id"] = "slevel", ["desc"] = "宠物等级"}, ["sname"] = {["id"] = "sname", ["desc"] = "宠物名字"}, ["sub_point"] = {["id"] = "sub_point", ["desc"] = "减少点数"}, ["traceno"] = {["id"] = "traceno", ["desc"] = "宠物traceno"}},
        subtype = "assign_point",
    },

    ["set_assign_scheme"] = {
        explain = "设置分配方案",
        log_format = {["channel"] = {["id"] = "channel", ["desc"] = "渠道"}, ["grade"] = {["id"] = "grade", ["desc"] = "等级"}, ["name"] = {["id"] = "name", ["desc"] = "玩家名字"}, ["pid"] = {["id"] = "pid", ["desc"] = "玩家id"}, ["show_id"] = {["id"] = "show_id", ["desc"] = "显示id"}, ["sid"] = {["id"] = "sid", ["desc"] = "宠物id"}, ["slevel"] = {["id"] = "slevel", ["desc"] = "宠物等级"}, ["sname"] = {["id"] = "sname", ["desc"] = "宠物名字"}, ["traceno"] = {["id"] = "traceno", ["desc"] = "宠物traceno"}},
        subtype = "set_assign_scheme",
    },

    ["open_assign_scheme"] = {
        explain = "开启自动分配",
        log_format = {["channel"] = {["id"] = "channel", ["desc"] = "渠道"}, ["grade"] = {["id"] = "grade", ["desc"] = "等级"}, ["name"] = {["id"] = "name", ["desc"] = "玩家名字"}, ["open"] = {["id"] = "open", ["desc"] = "是否开启"}, ["pid"] = {["id"] = "pid", ["desc"] = "玩家id"}, ["show_id"] = {["id"] = "show_id", ["desc"] = "显示id"}, ["sid"] = {["id"] = "sid", ["desc"] = "宠物id"}, ["slevel"] = {["id"] = "slevel", ["desc"] = "宠物等级"}, ["sname"] = {["id"] = "sname", ["desc"] = "宠物名字"}, ["traceno"] = {["id"] = "traceno", ["desc"] = "宠物traceno"}},
        subtype = "open_assign_scheme",
    },

    ["combine_summon"] = {
        explain = "合成宠物",
        log_format = {["book_cnt"] = {["id"] = "book_cnt", ["desc"] = "经验书数量"}, ["book_id"] = {["id"] = "book_id", ["desc"] = "经验书id"}, ["channel"] = {["id"] = "channel", ["desc"] = "渠道"}, ["grade"] = {["id"] = "grade", ["desc"] = "等级"}, ["name"] = {["id"] = "name", ["desc"] = "玩家名字"}, ["pid"] = {["id"] = "pid", ["desc"] = "玩家id"}, ["show_id"] = {["id"] = "show_id", ["desc"] = "显示id"}, ["sid"] = {["id"] = "sid", ["desc"] = "宠物id"}, ["slevel"] = {["id"] = "slevel", ["desc"] = "宠物等级"}, ["sname"] = {["id"] = "sname", ["desc"] = "宠物名字"}, ["store_cnt"] = {["id"] = "store_cnt", ["desc"] = "技能石数量"}, ["store_id"] = {["id"] = "store_id", ["desc"] = "技能石id"}, ["summon1"] = {["id"] = "summon1", ["desc"] = "宠物1"}, ["summon2"] = {["id"] = "summon2", ["desc"] = "宠物2"}, ["traceno"] = {["id"] = "traceno", ["desc"] = "宠物traceno"}},
        subtype = "combine_summon",
    },

    ["use_exp_book"] = {
        explain = "使用经验书",
        log_format = {["channel"] = {["id"] = "channel", ["desc"] = "渠道"}, ["cost_cnt"] = {["id"] = "cost_cnt", ["desc"] = "使用数量"}, ["cost_item"] = {["id"] = "cost_item", ["desc"] = "使用物品"}, ["grade"] = {["id"] = "grade", ["desc"] = "等级"}, ["name"] = {["id"] = "name", ["desc"] = "玩家名字"}, ["old_exp"] = {["id"] = "old_exp", ["desc"] = "原有经验"}, ["old_level"] = {["id"] = "old_level", ["desc"] = "原有等级"}, ["pid"] = {["id"] = "pid", ["desc"] = "玩家id"}, ["show_id"] = {["id"] = "show_id", ["desc"] = "显示id"}, ["sid"] = {["id"] = "sid", ["desc"] = "宠物id"}, ["slevel"] = {["id"] = "slevel", ["desc"] = "宠物等级"}, ["sname"] = {["id"] = "sname", ["desc"] = "宠物名字"}, ["traceno"] = {["id"] = "traceno", ["desc"] = "宠物traceno"}},
        subtype = "use_exp_book",
    },

    ["use_aptitude_pellet"] = {
        explain = "使用资质丹",
        log_format = {["add_val"] = {["id"] = "add_val", ["desc"] = "增加值"}, ["attr"] = {["id"] = "attr", ["desc"] = "属性名"}, ["channel"] = {["id"] = "channel", ["desc"] = "渠道"}, ["cost"] = {["id"] = "cost", ["desc"] = "使用道具"}, ["grade"] = {["id"] = "grade", ["desc"] = "等级"}, ["name"] = {["id"] = "name", ["desc"] = "玩家名字"}, ["now_val"] = {["id"] = "now_val", ["desc"] = "当前值"}, ["old_val"] = {["id"] = "old_val", ["desc"] = "原有值"}, ["pid"] = {["id"] = "pid", ["desc"] = "玩家id"}, ["show_id"] = {["id"] = "show_id", ["desc"] = "显示id"}, ["sid"] = {["id"] = "sid", ["desc"] = "宠物id"}, ["slevel"] = {["id"] = "slevel", ["desc"] = "宠物等级"}, ["sname"] = {["id"] = "sname", ["desc"] = "宠物名字"}, ["traceno"] = {["id"] = "traceno", ["desc"] = "宠物traceno"}},
        subtype = "use_aptitude_pellet",
    },

    ["wash_attr_point"] = {
        explain = "洗潜力点",
        log_format = {["attr"] = {["id"] = "attr", ["desc"] = "属性名"}, ["channel"] = {["id"] = "channel", ["desc"] = "渠道"}, ["cost_cnt"] = {["id"] = "cost_cnt", ["desc"] = "使用数量"}, ["cost_item"] = {["id"] = "cost_item", ["desc"] = "使用物品"}, ["grade"] = {["id"] = "grade", ["desc"] = "等级"}, ["name"] = {["id"] = "name", ["desc"] = "玩家名字"}, ["now_val"] = {["id"] = "now_val", ["desc"] = "当前值"}, ["old_val"] = {["id"] = "old_val", ["desc"] = "原有值"}, ["pid"] = {["id"] = "pid", ["desc"] = "玩家id"}, ["show_id"] = {["id"] = "show_id", ["desc"] = "显示id"}, ["sid"] = {["id"] = "sid", ["desc"] = "宠物id"}, ["slevel"] = {["id"] = "slevel", ["desc"] = "宠物等级"}, ["sname"] = {["id"] = "sname", ["desc"] = "宠物名字"}, ["traceno"] = {["id"] = "traceno", ["desc"] = "宠物traceno"}, ["wash_val"] = {["id"] = "wash_val", ["desc"] = "增加值"}},
        subtype = "wash_attr_point",
    },

    ["wash_all_point"] = {
        explain = "洗全部潜力点",
        log_format = {["channel"] = {["id"] = "channel", ["desc"] = "渠道"}, ["cost_cnt"] = {["id"] = "cost_cnt", ["desc"] = "使用数量"}, ["cost_item"] = {["id"] = "cost_item", ["desc"] = "使用物品"}, ["free"] = {["id"] = "free", ["desc"] = "是否免费"}, ["grade"] = {["id"] = "grade", ["desc"] = "等级"}, ["name"] = {["id"] = "name", ["desc"] = "玩家名字"}, ["pid"] = {["id"] = "pid", ["desc"] = "玩家id"}, ["show_id"] = {["id"] = "show_id", ["desc"] = "显示id"}, ["sid"] = {["id"] = "sid", ["desc"] = "宠物id"}, ["slevel"] = {["id"] = "slevel", ["desc"] = "宠物等级"}, ["sname"] = {["id"] = "sname", ["desc"] = "宠物名字"}, ["traceno"] = {["id"] = "traceno", ["desc"] = "宠物traceno"}, ["wash_attr"] = {["id"] = "wash_attr", ["desc"] = "洗点属性"}},
        subtype = "wash_all_point",
    },

    ["use_life_book"] = {
        explain = "使用寿命丹",
        log_format = {["channel"] = {["id"] = "channel", ["desc"] = "渠道"}, ["cost_cnt"] = {["id"] = "cost_cnt", ["desc"] = "使用数量"}, ["cost_item"] = {["id"] = "cost_item", ["desc"] = "使用物品"}, ["grade"] = {["id"] = "grade", ["desc"] = "等级"}, ["name"] = {["id"] = "name", ["desc"] = "玩家名字"}, ["now_life"] = {["id"] = "now_life", ["desc"] = "当前寿命"}, ["old_life"] = {["id"] = "old_life", ["desc"] = "原有寿命"}, ["pid"] = {["id"] = "pid", ["desc"] = "玩家id"}, ["show_id"] = {["id"] = "show_id", ["desc"] = "显示id"}, ["sid"] = {["id"] = "sid", ["desc"] = "宠物id"}, ["slevel"] = {["id"] = "slevel", ["desc"] = "宠物等级"}, ["sname"] = {["id"] = "sname", ["desc"] = "宠物名字"}, ["traceno"] = {["id"] = "traceno", ["desc"] = "宠物traceno"}},
        subtype = "use_life_book",
    },

    ["exp"] = {
        explain = "获得经验",
        log_format = {["channel"] = {["id"] = "channel", ["desc"] = "渠道"}, ["exp_add"] = {["id"] = "exp_add", ["desc"] = "增加经验"}, ["exp_now"] = {["id"] = "exp_now", ["desc"] = "当前经验"}, ["exp_old"] = {["id"] = "exp_old", ["desc"] = "原经验"}, ["grade"] = {["id"] = "grade", ["desc"] = "等级"}, ["grade_old"] = {["id"] = "grade_old", ["desc"] = "原等级"}, ["name"] = {["id"] = "name", ["desc"] = "玩家名字"}, ["pid"] = {["id"] = "pid", ["desc"] = "玩家id"}, ["reason"] = {["id"] = "reason", ["desc"] = "原因"}, ["reward_exp"] = {["id"] = "reward_exp", ["desc"] = "传入值"}, ["show_id"] = {["id"] = "show_id", ["desc"] = "显示id"}, ["sid"] = {["id"] = "sid", ["desc"] = "宠物id"}, ["slevel"] = {["id"] = "slevel", ["desc"] = "宠物等级"}, ["sname"] = {["id"] = "sname", ["desc"] = "宠物名字"}, ["traceno"] = {["id"] = "traceno", ["desc"] = "宠物traceno"}},
        subtype = "exp",
    },

    ["extend_size"] = {
        explain = "扩充宠物格子",
        log_format = {["channel"] = {["id"] = "channel", ["desc"] = "渠道"}, ["cost"] = {["id"] = "cost", ["desc"] = "道具花费"}, ["count"] = {["id"] = "count", ["desc"] = "扩充数量"}, ["grade"] = {["id"] = "grade", ["desc"] = "等级"}, ["name"] = {["id"] = "name", ["desc"] = "玩家名字"}, ["pid"] = {["id"] = "pid", ["desc"] = "玩家id"}, ["show_id"] = {["id"] = "show_id", ["desc"] = "显示id"}},
        subtype = "extend_size",
    },

    ["extend_ck_size"] = {
        explain = "扩充仓库格子",
        log_format = {["channel"] = {["id"] = "channel", ["desc"] = "渠道"}, ["count"] = {["id"] = "count", ["desc"] = "扩充数量"}, ["goldcoin"] = {["id"] = "goldcoin", ["desc"] = "元宝"}, ["grade"] = {["id"] = "grade", ["desc"] = "等级"}, ["name"] = {["id"] = "name", ["desc"] = "玩家名字"}, ["pid"] = {["id"] = "pid", ["desc"] = "玩家id"}, ["show_id"] = {["id"] = "show_id", ["desc"] = "显示id"}},
        subtype = "extend_ck_size",
    },

    ["ss_exchange"] = {
        explain = "神兽兑换",
        log_format = {["channel"] = {["id"] = "channel", ["desc"] = "渠道"}, ["cost_item"] = {["id"] = "cost_item", ["desc"] = "消耗物品"}, ["grade"] = {["id"] = "grade", ["desc"] = "等级"}, ["name"] = {["id"] = "name", ["desc"] = "玩家名字"}, ["pid"] = {["id"] = "pid", ["desc"] = "玩家id"}, ["show_id"] = {["id"] = "show_id", ["desc"] = "显示id"}, ["sid"] = {["id"] = "sid", ["desc"] = "兑换神兽"}, ["sid1"] = {["id"] = "sid1", ["desc"] = "消耗神兽1"}, ["sid2"] = {["id"] = "sid2", ["desc"] = "消耗神兽2"}},
        subtype = "ss_exchange",
    },

    ["equip_summon"] = {
        explain = "宠物装备",
        log_format = {["channel"] = {["id"] = "channel", ["desc"] = "渠道"}, ["equip"] = {["id"] = "equip", ["desc"] = "装备id"}, ["grade"] = {["id"] = "grade", ["desc"] = "等级"}, ["name"] = {["id"] = "name", ["desc"] = "玩家名字"}, ["pid"] = {["id"] = "pid", ["desc"] = "玩家id"}, ["show_id"] = {["id"] = "show_id", ["desc"] = "显示id"}, ["sid"] = {["id"] = "sid", ["desc"] = "宠物id"}, ["slevel"] = {["id"] = "slevel", ["desc"] = "宠物等级"}, ["sname"] = {["id"] = "sname", ["desc"] = "宠物名字"}, ["traceno"] = {["id"] = "traceno", ["desc"] = "宠物traceno"}},
        subtype = "equip_summon",
    },

    ["add_ck_summon"] = {
        explain = "宠物装备",
        log_format = {["channel"] = {["id"] = "channel", ["desc"] = "渠道"}, ["grade"] = {["id"] = "grade", ["desc"] = "等级"}, ["name"] = {["id"] = "name", ["desc"] = "玩家名字"}, ["pid"] = {["id"] = "pid", ["desc"] = "玩家id"}, ["show_id"] = {["id"] = "show_id", ["desc"] = "显示id"}, ["sid"] = {["id"] = "sid", ["desc"] = "宠物id"}, ["slevel"] = {["id"] = "slevel", ["desc"] = "宠物等级"}, ["sname"] = {["id"] = "sname", ["desc"] = "宠物名字"}, ["traceno"] = {["id"] = "traceno", ["desc"] = "宠物traceno"}},
        subtype = "add_ck_summon",
    },

    ["change_ck_summon"] = {
        explain = "转换仓库宠物",
        log_format = {["channel"] = {["id"] = "channel", ["desc"] = "渠道"}, ["grade"] = {["id"] = "grade", ["desc"] = "等级"}, ["name"] = {["id"] = "name", ["desc"] = "玩家名字"}, ["pid"] = {["id"] = "pid", ["desc"] = "玩家id"}, ["show_id"] = {["id"] = "show_id", ["desc"] = "显示id"}, ["sid"] = {["id"] = "sid", ["desc"] = "宠物id"}, ["slevel"] = {["id"] = "slevel", ["desc"] = "宠物等级"}, ["sname"] = {["id"] = "sname", ["desc"] = "宠物名字"}, ["traceno"] = {["id"] = "traceno", ["desc"] = "宠物traceno"}},
        subtype = "change_ck_summon",
    },

    ["summon_advance"] = {
        explain = "神兽进阶",
        log_format = {["channel"] = {["id"] = "channel", ["desc"] = "渠道"}, ["grade"] = {["id"] = "grade", ["desc"] = "等级"}, ["name"] = {["id"] = "name", ["desc"] = "玩家名字"}, ["now_adv_lv"] = {["id"] = "now_adv_lv", ["desc"] = "现进阶等级"}, ["old_adv_lv"] = {["id"] = "old_adv_lv", ["desc"] = "原进阶等级"}, ["pid"] = {["id"] = "pid", ["desc"] = "玩家id"}, ["show_id"] = {["id"] = "show_id", ["desc"] = "显示id"}, ["sid"] = {["id"] = "sid", ["desc"] = "宠物id"}, ["slevel"] = {["id"] = "slevel", ["desc"] = "宠物等级"}, ["sname"] = {["id"] = "sname", ["desc"] = "宠物名字"}, ["traceno"] = {["id"] = "traceno", ["desc"] = "宠物traceno"}},
        subtype = "summon_advance",
    },

    ["add_summon"] = {
        explain = "增加宠物",
        log_format = {["channel"] = {["id"] = "channel", ["desc"] = "渠道"}, ["grade"] = {["id"] = "grade", ["desc"] = "等级"}, ["name"] = {["id"] = "name", ["desc"] = "玩家名字"}, ["pid"] = {["id"] = "pid", ["desc"] = "玩家id"}, ["reason"] = {["id"] = "reason", ["desc"] = "原因"}, ["show_id"] = {["id"] = "show_id", ["desc"] = "显示id"}, ["sid"] = {["id"] = "sid", ["desc"] = "宠物id"}, ["slevel"] = {["id"] = "slevel", ["desc"] = "宠物等级"}, ["sname"] = {["id"] = "sname", ["desc"] = "宠物名字"}, ["traceno"] = {["id"] = "traceno", ["desc"] = "宠物traceno"}},
        subtype = "add_summon",
    },

    ["del_summon"] = {
        explain = "删除宠",
        log_format = {["channel"] = {["id"] = "channel", ["desc"] = "渠道"}, ["grade"] = {["id"] = "grade", ["desc"] = "等级"}, ["name"] = {["id"] = "name", ["desc"] = "玩家名字"}, ["pid"] = {["id"] = "pid", ["desc"] = "玩家id"}, ["reason"] = {["id"] = "reason", ["desc"] = "原因"}, ["show_id"] = {["id"] = "show_id", ["desc"] = "显示id"}, ["sid"] = {["id"] = "sid", ["desc"] = "宠物id"}, ["slevel"] = {["id"] = "slevel", ["desc"] = "宠物等级"}, ["sname"] = {["id"] = "sname", ["desc"] = "宠物名字"}, ["traceno"] = {["id"] = "traceno", ["desc"] = "宠物traceno"}},
        subtype = "del_summon",
    },

    ["use_grow_pellet"] = {
        explain = "使用成长丹",
        log_format = {["channel"] = {["id"] = "channel", ["desc"] = "渠道"}, ["grade"] = {["id"] = "grade", ["desc"] = "等级"}, ["name"] = {["id"] = "name", ["desc"] = "玩家名字"}, ["now_grow"] = {["id"] = "now_grow", ["desc"] = "当前成长"}, ["old_grow"] = {["id"] = "old_grow", ["desc"] = "原成长"}, ["pid"] = {["id"] = "pid", ["desc"] = "玩家id"}, ["show_id"] = {["id"] = "show_id", ["desc"] = "显示id"}, ["sid"] = {["id"] = "sid", ["desc"] = "宠物id"}, ["slevel"] = {["id"] = "slevel", ["desc"] = "宠物等级"}, ["sname"] = {["id"] = "sname", ["desc"] = "宠物名字"}, ["traceno"] = {["id"] = "traceno", ["desc"] = "宠物traceno"}},
        subtype = "use_grow_pellet",
    },

    ["exchange_summon"] = {
        explain = "兑换宠物",
        log_format = {["channel"] = {["id"] = "channel", ["desc"] = "渠道"}, ["cnt"] = {["id"] = "cnt", ["desc"] = "消耗数量"}, ["cost"] = {["id"] = "cost", ["desc"] = "消耗物品"}, ["grade"] = {["id"] = "grade", ["desc"] = "等级"}, ["name"] = {["id"] = "name", ["desc"] = "玩家名字"}, ["pid"] = {["id"] = "pid", ["desc"] = "玩家id"}, ["show_id"] = {["id"] = "show_id", ["desc"] = "显示id"}, ["sid"] = {["id"] = "sid", ["desc"] = "宠物id"}, ["slevel"] = {["id"] = "slevel", ["desc"] = "宠物等级"}, ["sname"] = {["id"] = "sname", ["desc"] = "宠物名字"}, ["traceno"] = {["id"] = "traceno", ["desc"] = "宠物traceno"}},
        subtype = "exchange_summon",
    },

}
