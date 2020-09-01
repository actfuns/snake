-- ./excel/log/org.xlsx
return {

    ["create_ready_org"] = {
        explain = "创建预备帮派",
        log_format = {["channel"] = {["id"] = "channel", ["desc"] = "渠道"}, ["grade"] = {["id"] = "grade", ["desc"] = "等级"}, ["name"] = {["id"] = "name", ["desc"] = "玩家名字"}, ["org_name"] = {["id"] = "org_name", ["desc"] = "帮派名字"}, ["pid"] = {["id"] = "pid", ["desc"] = "玩家id"}, ["show_id"] = {["id"] = "show_id", ["desc"] = "显示id"}},
        subtype = "create_ready_org",
    },

    ["create_normal_org"] = {
        explain = "创建帮派",
        log_format = {["leader"] = {["id"] = "leader", ["desc"] = "帮主id"}, ["org_id"] = {["id"] = "org_id", ["desc"] = "帮派id"}, ["org_name"] = {["id"] = "org_name", ["desc"] = "帮派名字"}},
        subtype = "create_normal_org",
    },

    ["join_org"] = {
        explain = "加入帮派",
        log_format = {["leader"] = {["id"] = "leader", ["desc"] = "帮主id"}, ["org_id"] = {["id"] = "org_id", ["desc"] = "帮派id"}, ["org_lv"] = {["id"] = "org_lv", ["desc"] = "帮派等级"}, ["org_name"] = {["id"] = "org_name", ["desc"] = "帮派名字"}, ["pid"] = {["id"] = "pid", ["desc"] = "玩家id"}},
        subtype = "join_org",
    },

    ["dismiss_org"] = {
        explain = "帮派自动解散",
        log_format = {["leader"] = {["id"] = "leader", ["desc"] = "帮主id"}, ["org_id"] = {["id"] = "org_id", ["desc"] = "帮派id"}, ["org_lv"] = {["id"] = "org_lv", ["desc"] = "帮派等级"}, ["org_name"] = {["id"] = "org_name", ["desc"] = "帮派名字"}},
        subtype = "dismiss_org",
    },

    ["leave_org"] = {
        explain = "离开帮派",
        log_format = {["leader"] = {["id"] = "leader", ["desc"] = "帮主id"}, ["org_id"] = {["id"] = "org_id", ["desc"] = "帮派id"}, ["org_lv"] = {["id"] = "org_lv", ["desc"] = "帮派等级"}, ["org_name"] = {["id"] = "org_name", ["desc"] = "帮派名字"}, ["pid"] = {["id"] = "pid", ["desc"] = "玩家id"}, ["reason"] = {["id"] = "reason", ["desc"] = "原因"}},
        subtype = "leave_org",
    },

    ["transfer_leader"] = {
        explain = "帮主更换",
        log_format = {["leader"] = {["id"] = "leader", ["desc"] = "帮主id"}, ["new_leader"] = {["id"] = "new_leader", ["desc"] = "新帮主id"}, ["old_leader"] = {["id"] = "old_leader", ["desc"] = "原帮主id"}, ["org_id"] = {["id"] = "org_id", ["desc"] = "帮派id"}, ["org_lv"] = {["id"] = "org_lv", ["desc"] = "帮派等级"}, ["org_name"] = {["id"] = "org_name", ["desc"] = "帮派名字"}, ["reason"] = {["id"] = "reason", ["desc"] = "原因"}},
        subtype = "transfer_leader",
    },

    ["set_position"] = {
        explain = "设置职位",
        log_format = {["leader"] = {["id"] = "leader", ["desc"] = "帮主id"}, ["new_pos"] = {["id"] = "new_pos", ["desc"] = "新职位"}, ["old_pos"] = {["id"] = "old_pos", ["desc"] = "原职位"}, ["org_id"] = {["id"] = "org_id", ["desc"] = "帮派id"}, ["org_lv"] = {["id"] = "org_lv", ["desc"] = "帮派等级"}, ["org_name"] = {["id"] = "org_name", ["desc"] = "帮派名字"}, ["seter"] = {["id"] = "seter", ["desc"] = "设置者id"}, ["targetid"] = {["id"] = "targetid", ["desc"] = "被设置者id"}},
        subtype = "set_position",
    },

    ["xuetu_to_member"] = {
        explain = "学徒转正",
        log_format = {["leader"] = {["id"] = "leader", ["desc"] = "帮主id"}, ["org_id"] = {["id"] = "org_id", ["desc"] = "帮派id"}, ["org_lv"] = {["id"] = "org_lv", ["desc"] = "帮派等级"}, ["org_name"] = {["id"] = "org_name", ["desc"] = "帮派名字"}, ["pid"] = {["id"] = "pid", ["desc"] = "玩家id"}},
        subtype = "xuetu_to_member",
    },

    ["spread_org"] = {
        explain = "宣传预备帮派",
        log_format = {["channel"] = {["id"] = "channel", ["desc"] = "渠道"}, ["grade"] = {["id"] = "grade", ["desc"] = "等级"}, ["name"] = {["id"] = "name", ["desc"] = "玩家名字"}, ["new_energy"] = {["id"] = "new_energy", ["desc"] = "当前活跃"}, ["old_energy"] = {["id"] = "old_energy", ["desc"] = "原有活跃"}, ["org_id"] = {["id"] = "org_id", ["desc"] = "帮派id"}, ["org_name"] = {["id"] = "org_name", ["desc"] = "帮派名字"}, ["pid"] = {["id"] = "pid", ["desc"] = "玩家id"}, ["show_id"] = {["id"] = "show_id", ["desc"] = "显示id"}},
        subtype = "spread_org",
    },

    ["apply_leader"] = {
        explain = "自荐帮主",
        log_format = {["leader"] = {["id"] = "leader", ["desc"] = "帮主id"}, ["name"] = {["id"] = "name", ["desc"] = "玩家名字"}, ["new_silver"] = {["id"] = "new_silver", ["desc"] = "当前银币"}, ["old_silver"] = {["id"] = "old_silver", ["desc"] = "原有银币"}, ["org_id"] = {["id"] = "org_id", ["desc"] = "帮派id"}, ["org_lv"] = {["id"] = "org_lv", ["desc"] = "帮派等级"}, ["org_name"] = {["id"] = "org_name", ["desc"] = "帮派名字"}, ["pid"] = {["id"] = "pid", ["desc"] = "玩家id"}},
        subtype = "apply_leader",
    },

    ["against_apply_leader"] = {
        explain = "反对自荐帮主",
        log_format = {["againstid"] = {["id"] = "againstid", ["desc"] = "反对id"}, ["applyid"] = {["id"] = "applyid", ["desc"] = "自荐人id"}, ["leader"] = {["id"] = "leader", ["desc"] = "帮主id"}, ["org_id"] = {["id"] = "org_id", ["desc"] = "帮派id"}, ["org_lv"] = {["id"] = "org_lv", ["desc"] = "帮派等级"}, ["org_name"] = {["id"] = "org_name", ["desc"] = "帮派名字"}},
        subtype = "against_apply_leader",
    },

    ["upgrade_build"] = {
        explain = "升级建筑",
        log_format = {["buildid"] = {["id"] = "buildid", ["desc"] = "建筑id"}, ["cost_cnt"] = {["id"] = "cost_cnt", ["desc"] = "消耗数量"}, ["cost_item"] = {["id"] = "cost_item", ["desc"] = "消耗物品"}, ["leader"] = {["id"] = "leader", ["desc"] = "帮主id"}, ["name"] = {["id"] = "name", ["desc"] = "玩家名字"}, ["now_cash"] = {["id"] = "now_cash", ["desc"] = "当前资金"}, ["old_cash"] = {["id"] = "old_cash", ["desc"] = "原有资金"}, ["old_level"] = {["id"] = "old_level", ["desc"] = "原有等级"}, ["org_id"] = {["id"] = "org_id", ["desc"] = "帮派id"}, ["org_lv"] = {["id"] = "org_lv", ["desc"] = "帮派等级"}, ["org_name"] = {["id"] = "org_name", ["desc"] = "帮派名字"}, ["pid"] = {["id"] = "pid", ["desc"] = "玩家id"}},
        subtype = "upgrade_build",
    },

    ["quick_build"] = {
        explain = "快速建造",
        log_format = {["buildid"] = {["id"] = "buildid", ["desc"] = "建筑id"}, ["leader"] = {["id"] = "leader", ["desc"] = "帮主id"}, ["left_time"] = {["id"] = "left_time", ["desc"] = "剩余时间"}, ["money_type"] = {["id"] = "money_type", ["desc"] = "货币类型"}, ["money_val"] = {["id"] = "money_val", ["desc"] = "消耗数量"}, ["now_offer"] = {["id"] = "now_offer", ["desc"] = "当前帮贡"}, ["old_offer"] = {["id"] = "old_offer", ["desc"] = "原有帮贡"}, ["org_id"] = {["id"] = "org_id", ["desc"] = "帮派id"}, ["org_lv"] = {["id"] = "org_lv", ["desc"] = "帮派等级"}, ["org_name"] = {["id"] = "org_name", ["desc"] = "帮派名字"}, ["pid"] = {["id"] = "pid", ["desc"] = "玩家id"}, ["quick_sec"] = {["id"] = "quick_sec", ["desc"] = "加速时间"}},
        subtype = "quick_build",
    },

    ["shop_buy"] = {
        explain = "商店购买",
        log_format = {["buy_cnt"] = {["id"] = "buy_cnt", ["desc"] = "购买数量"}, ["buy_id"] = {["id"] = "buy_id", ["desc"] = "购买项id"}, ["channel"] = {["id"] = "channel", ["desc"] = "渠道"}, ["cost_type"] = {["id"] = "cost_type", ["desc"] = "消耗类型"}, ["cost_val"] = {["id"] = "cost_val", ["desc"] = "消耗数值"}, ["grade"] = {["id"] = "grade", ["desc"] = "等级"}, ["item_cnt"] = {["id"] = "item_cnt", ["desc"] = "物品数量"}, ["item_id"] = {["id"] = "item_id", ["desc"] = "物品id"}, ["name"] = {["id"] = "name", ["desc"] = "玩家名字"}, ["org_id"] = {["id"] = "org_id", ["desc"] = "帮派id"}, ["pid"] = {["id"] = "pid", ["desc"] = "玩家id"}, ["show_id"] = {["id"] = "show_id", ["desc"] = "显示id"}},
        subtype = "shop_buy",
    },

    ["org_sign"] = {
        explain = "帮派签到",
        log_format = {["channel"] = {["id"] = "channel", ["desc"] = "渠道"}, ["grade"] = {["id"] = "grade", ["desc"] = "等级"}, ["name"] = {["id"] = "name", ["desc"] = "玩家名字"}, ["now_silver"] = {["id"] = "now_silver", ["desc"] = "当前银币"}, ["old_silver"] = {["id"] = "old_silver", ["desc"] = "原有银币"}, ["org_id"] = {["id"] = "org_id", ["desc"] = "帮派id"}, ["pid"] = {["id"] = "pid", ["desc"] = "玩家id"}, ["show_id"] = {["id"] = "show_id", ["desc"] = "显示id"}},
        subtype = "org_sign",
    },

    ["receive_bonus"] = {
        explain = "领取帮派奖励",
        log_format = {["channel"] = {["id"] = "channel", ["desc"] = "渠道"}, ["grade"] = {["id"] = "grade", ["desc"] = "等级"}, ["name"] = {["id"] = "name", ["desc"] = "玩家名字"}, ["now_gold"] = {["id"] = "now_gold", ["desc"] = "当前金币"}, ["now_goldcoin"] = {["id"] = "now_goldcoin", ["desc"] = "当前元宝"}, ["now_silver"] = {["id"] = "now_silver", ["desc"] = "当前银币"}, ["old_gold"] = {["id"] = "old_gold", ["desc"] = "原有金币"}, ["old_goldcoin"] = {["id"] = "old_goldcoin", ["desc"] = "原有元宝"}, ["old_silver"] = {["id"] = "old_silver", ["desc"] = "原有银币"}, ["org_id"] = {["id"] = "org_id", ["desc"] = "帮派id"}, ["pid"] = {["id"] = "pid", ["desc"] = "玩家id"}, ["show_id"] = {["id"] = "show_id", ["desc"] = "显示id"}},
        subtype = "receive_bonus",
    },

    ["receive_pos_bonus"] = {
        explain = "领取管理奖励",
        log_format = {["channel"] = {["id"] = "channel", ["desc"] = "渠道"}, ["grade"] = {["id"] = "grade", ["desc"] = "等级"}, ["name"] = {["id"] = "name", ["desc"] = "玩家名字"}, ["now_goldcoin"] = {["id"] = "now_goldcoin", ["desc"] = "当前元宝"}, ["old_goldcoin"] = {["id"] = "old_goldcoin", ["desc"] = "原有元宝"}, ["org_id"] = {["id"] = "org_id", ["desc"] = "帮派id"}, ["pid"] = {["id"] = "pid", ["desc"] = "玩家id"}, ["show_id"] = {["id"] = "show_id", ["desc"] = "显示id"}},
        subtype = "receive_pos_bonus",
    },

    ["receive_achieve"] = {
        explain = "领取成就奖励",
        log_format = {["achid"] = {["id"] = "achid", ["desc"] = "成就id"}, ["channel"] = {["id"] = "channel", ["desc"] = "渠道"}, ["grade"] = {["id"] = "grade", ["desc"] = "等级"}, ["name"] = {["id"] = "name", ["desc"] = "玩家名字"}, ["org_id"] = {["id"] = "org_id", ["desc"] = "帮派id"}, ["pid"] = {["id"] = "pid", ["desc"] = "玩家id"}, ["reward"] = {["id"] = "reward", ["desc"] = "奖励"}, ["show_id"] = {["id"] = "show_id", ["desc"] = "显示id"}},
        subtype = "receive_achieve",
    },

    ["org_response"] = {
        explain = "帮派响应",
        log_format = {["channel"] = {["id"] = "channel", ["desc"] = "渠道"}, ["flag"] = {["id"] = "flag", ["desc"] = "申请OR取消"}, ["grade"] = {["id"] = "grade", ["desc"] = "等级"}, ["name"] = {["id"] = "name", ["desc"] = "玩家名字"}, ["org_id"] = {["id"] = "org_id", ["desc"] = "帮派id"}, ["pid"] = {["id"] = "pid", ["desc"] = "玩家id"}, ["show_id"] = {["id"] = "show_id", ["desc"] = "显示id"}},
        subtype = "org_response",
    },

    ["org_mail"] = {
        explain = "帮派邮件",
        log_format = {["channel"] = {["id"] = "channel", ["desc"] = "渠道"}, ["grade"] = {["id"] = "grade", ["desc"] = "等级"}, ["name"] = {["id"] = "name", ["desc"] = "玩家名字"}, ["org_id"] = {["id"] = "org_id", ["desc"] = "帮派id"}, ["pid"] = {["id"] = "pid", ["desc"] = "玩家id"}, ["show_id"] = {["id"] = "show_id", ["desc"] = "显示id"}},
        subtype = "org_mail",
    },

    ["ready_org_save"] = {
        explain = "预备帮派存库提示",
        log_format = {["org_id"] = {["id"] = "org_id", ["desc"] = "帮派id"}, ["reason"] = {["id"] = "reason", ["desc"] = "原因"}},
        subtype = "ready_org_save",
    },

    ["new_day_log"] = {
        explain = "帮派刷天",
        log_format = {["add_boom"] = {["id"] = "add_boom", ["desc"] = "增加繁华度"}, ["leader"] = {["id"] = "leader", ["desc"] = "帮主id"}, ["now_boom"] = {["id"] = "now_boom", ["desc"] = "当前繁华度"}, ["now_cash"] = {["id"] = "now_cash", ["desc"] = "当前资金"}, ["org_id"] = {["id"] = "org_id", ["desc"] = "帮派id"}, ["org_lv"] = {["id"] = "org_lv", ["desc"] = "帮派等级"}, ["org_name"] = {["id"] = "org_name", ["desc"] = "帮派名字"}, ["sub_boom"] = {["id"] = "sub_boom", ["desc"] = "扣除繁华度"}, ["sub_cash"] = {["id"] = "sub_cash", ["desc"] = "减少资金"}},
        subtype = "new_day_log",
    },

}
