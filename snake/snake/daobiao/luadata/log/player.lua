-- ./excel/log/player.xlsx
return {

    ["login"] = {
        explain = "登录日志",
        log_format = {["account"] = {["id"] = "account", ["desc"] = "账号"}, ["channel"] = {["id"] = "channel", ["desc"] = "渠道"}, ["device"] = {["id"] = "device", ["desc"] = "设备号"}, ["fd"] = {["id"] = "fd", ["desc"] = "玩家handle"}, ["grade"] = {["id"] = "grade", ["desc"] = "等级"}, ["ip"] = {["id"] = "ip", ["desc"] = "网络协议"}, ["mac"] = {["id"] = "mac", ["desc"] = "物理地址"}, ["name"] = {["id"] = "name", ["desc"] = "玩家名字"}, ["pid"] = {["id"] = "pid", ["desc"] = "玩家id"}, ["platform"] = {["id"] = "platform", ["desc"] = "平台"}, ["reenter"] = {["id"] = "reenter", ["desc"] = "顶号"}, ["show_id"] = {["id"] = "show_id", ["desc"] = "显示id"}},
        subtype = "login",
    },

    ["logout"] = {
        explain = "登出日志",
        log_format = {["account"] = {["id"] = "account", ["desc"] = "账号"}, ["channel"] = {["id"] = "channel", ["desc"] = "渠道"}, ["duration"] = {["id"] = "duration", ["desc"] = "在线时长"}, ["grade"] = {["id"] = "grade", ["desc"] = "等级"}, ["name"] = {["id"] = "name", ["desc"] = "玩家名字"}, ["pid"] = {["id"] = "pid", ["desc"] = "玩家id"}, ["show_id"] = {["id"] = "show_id", ["desc"] = "显示id"}},
        subtype = "logout",
    },

    ["exp"] = {
        explain = "经验日志",
        log_format = {["channel"] = {["id"] = "channel", ["desc"] = "渠道"}, ["exp_add"] = {["id"] = "exp_add", ["desc"] = "新增经验"}, ["exp_now"] = {["id"] = "exp_now", ["desc"] = "现经验"}, ["exp_old"] = {["id"] = "exp_old", ["desc"] = "原经验"}, ["grade"] = {["id"] = "grade", ["desc"] = "等级"}, ["grade_now"] = {["id"] = "grade_now", ["desc"] = "现等级"}, ["grade_old"] = {["id"] = "grade_old", ["desc"] = "原等级"}, ["name"] = {["id"] = "name", ["desc"] = "玩家名字"}, ["nowchubei"] = {["id"] = "nowchubei", ["desc"] = "当前储备经验"}, ["pid"] = {["id"] = "pid", ["desc"] = "玩家id"}, ["reason"] = {["id"] = "reason", ["desc"] = "原因"}, ["show_id"] = {["id"] = "show_id", ["desc"] = "显示id"}, ["subchubei"] = {["id"] = "subchubei", ["desc"] = "消耗储备经验"}},
        subtype = "exp",
    },

    ["chubei_exp"] = {
        explain = "储备经验",
        log_format = {["channel"] = {["id"] = "channel", ["desc"] = "渠道"}, ["chubei_add"] = {["id"] = "chubei_add", ["desc"] = "增加储备"}, ["chubei_now"] = {["id"] = "chubei_now", ["desc"] = "现储备"}, ["chubei_old"] = {["id"] = "chubei_old", ["desc"] = "原储备"}, ["grade"] = {["id"] = "grade", ["desc"] = "等级"}, ["name"] = {["id"] = "name", ["desc"] = "玩家名字"}, ["pid"] = {["id"] = "pid", ["desc"] = "玩家id"}, ["reason"] = {["id"] = "reason", ["desc"] = "原因"}, ["show_id"] = {["id"] = "show_id", ["desc"] = "显示id"}},
        subtype = "chubei_exp",
    },

    ["rename"] = {
        explain = "改名日志",
        log_format = {["channel"] = {["id"] = "channel", ["desc"] = "渠道"}, ["goldcoin"] = {["id"] = "goldcoin", ["desc"] = "消耗元宝"}, ["grade"] = {["id"] = "grade", ["desc"] = "等级"}, ["name"] = {["id"] = "name", ["desc"] = "玩家名字"}, ["new_name"] = {["id"] = "new_name", ["desc"] = "新名字"}, ["old_name"] = {["id"] = "old_name", ["desc"] = "原名字"}, ["pid"] = {["id"] = "pid", ["desc"] = "玩家id"}, ["show_id"] = {["id"] = "show_id", ["desc"] = "显示id"}},
        subtype = "rename",
    },

    ["wash_point"] = {
        explain = "洗点日志",
        log_format = {["channel"] = {["id"] = "channel", ["desc"] = "渠道"}, ["grade"] = {["id"] = "grade", ["desc"] = "等级"}, ["name"] = {["id"] = "name", ["desc"] = "玩家名字"}, ["pid"] = {["id"] = "pid", ["desc"] = "玩家id"}, ["point_all"] = {["id"] = "point_all", ["desc"] = "可洗点数"}, ["point_now"] = {["id"] = "point_now", ["desc"] = "现可分配点数"}, ["point_old"] = {["id"] = "point_old", ["desc"] = "原可分配点数"}, ["point_wash"] = {["id"] = "point_wash", ["desc"] = "洗点点数"}, ["prop"] = {["id"] = "prop", ["desc"] = "属性"}, ["show_id"] = {["id"] = "show_id", ["desc"] = "显示id"}},
        subtype = "wash_point",
    },

    ["upvote"] = {
        explain = "点赞日志",
        log_format = {["channel"] = {["id"] = "channel", ["desc"] = "渠道"}, ["grade"] = {["id"] = "grade", ["desc"] = "等级"}, ["name"] = {["id"] = "name", ["desc"] = "玩家名字"}, ["pid"] = {["id"] = "pid", ["desc"] = "玩家id"}, ["show_id"] = {["id"] = "show_id", ["desc"] = "显示id"}, ["upvote_amount"] = {["id"] = "upvote_amount", ["desc"] = "点赞数量"}, ["upvote_player"] = {["id"] = "upvote_player", ["desc"] = "点赞玩家"}},
        subtype = "upvote",
    },

    ["double_point"] = {
        explain = "双倍点数",
        log_format = {["channel"] = {["id"] = "channel", ["desc"] = "渠道"}, ["double_point"] = {["id"] = "double_point", ["desc"] = "双倍点数"}, ["double_point_add"] = {["id"] = "double_point_add", ["desc"] = "新增双倍点数"}, ["grade"] = {["id"] = "grade", ["desc"] = "等级"}, ["name"] = {["id"] = "name", ["desc"] = "玩家名字"}, ["pid"] = {["id"] = "pid", ["desc"] = "玩家id"}, ["show_id"] = {["id"] = "show_id", ["desc"] = "显示id"}},
        subtype = "double_point",
    },

    ["double_point_limit"] = {
        explain = "双倍点数上限",
        log_format = {["channel"] = {["id"] = "channel", ["desc"] = "渠道"}, ["double_point_limit"] = {["id"] = "double_point_limit", ["desc"] = "双倍点数上限"}, ["double_point_limit_add"] = {["id"] = "double_point_limit_add", ["desc"] = "新增双倍点数上限"}, ["grade"] = {["id"] = "grade", ["desc"] = "等级"}, ["name"] = {["id"] = "name", ["desc"] = "玩家名字"}, ["pid"] = {["id"] = "pid", ["desc"] = "玩家id"}, ["show_id"] = {["id"] = "show_id", ["desc"] = "显示id"}},
        subtype = "double_point_limit",
    },

    ["add_state"] = {
        explain = "增加状态",
        log_format = {["args"] = {["id"] = "args", ["desc"] = "参数"}, ["channel"] = {["id"] = "channel", ["desc"] = "渠道"}, ["grade"] = {["id"] = "grade", ["desc"] = "等级"}, ["name"] = {["id"] = "name", ["desc"] = "玩家名字"}, ["pid"] = {["id"] = "pid", ["desc"] = "玩家id"}, ["show_id"] = {["id"] = "show_id", ["desc"] = "显示id"}, ["state"] = {["id"] = "state", ["desc"] = "状态"}},
        subtype = "add_state",
    },

    ["del_state"] = {
        explain = "删除状态",
        log_format = {["channel"] = {["id"] = "channel", ["desc"] = "渠道"}, ["grade"] = {["id"] = "grade", ["desc"] = "等级"}, ["name"] = {["id"] = "name", ["desc"] = "玩家名字"}, ["pid"] = {["id"] = "pid", ["desc"] = "玩家id"}, ["show_id"] = {["id"] = "show_id", ["desc"] = "显示id"}, ["state"] = {["id"] = "state", ["desc"] = "状态"}},
        subtype = "del_state",
    },

    ["change_plan"] = {
        explain = "更换加点方案",
        log_format = {["channel"] = {["id"] = "channel", ["desc"] = "渠道"}, ["grade"] = {["id"] = "grade", ["desc"] = "等级"}, ["name"] = {["id"] = "name", ["desc"] = "玩家名字"}, ["new_plan"] = {["id"] = "new_plan", ["desc"] = "新方案"}, ["old_plan"] = {["id"] = "old_plan", ["desc"] = "旧方案"}, ["pid"] = {["id"] = "pid", ["desc"] = "玩家id"}, ["show_id"] = {["id"] = "show_id", ["desc"] = "显示id"}},
        subtype = "change_plan",
    },

    ["add_point"] = {
        explain = "加点日志",
        log_format = {["channel"] = {["id"] = "channel", ["desc"] = "渠道"}, ["grade"] = {["id"] = "grade", ["desc"] = "等级"}, ["name"] = {["id"] = "name", ["desc"] = "玩家名字"}, ["new_data"] = {["id"] = "new_data", ["desc"] = "加点后数据"}, ["old_data"] = {["id"] = "old_data", ["desc"] = "加点前数据"}, ["pid"] = {["id"] = "pid", ["desc"] = "玩家id"}, ["plan"] = {["id"] = "plan", ["desc"] = "方案"}, ["show_id"] = {["id"] = "show_id", ["desc"] = "显示id"}},
        subtype = "add_point",
    },

    ["reward_gradegift"] = {
        explain = "领取升级礼包",
        log_format = {["channel"] = {["id"] = "channel", ["desc"] = "渠道"}, ["grade"] = {["id"] = "grade", ["desc"] = "礼包等级"}, ["name"] = {["id"] = "name", ["desc"] = "玩家名字"}, ["pid"] = {["id"] = "pid", ["desc"] = "玩家id"}, ["show_id"] = {["id"] = "show_id", ["desc"] = "显示id"}},
        subtype = "reward_gradegift",
    },

    ["reward_preopengift"] = {
        explain = "领取功能预告礼包",
        log_format = {["channel"] = {["id"] = "channel", ["desc"] = "渠道"}, ["grade"] = {["id"] = "grade", ["desc"] = "等级"}, ["name"] = {["id"] = "name", ["desc"] = "玩家名字"}, ["pid"] = {["id"] = "pid", ["desc"] = "玩家id"}, ["show_id"] = {["id"] = "show_id", ["desc"] = "显示id"}, ["sys_id"] = {["id"] = "sys_id", ["desc"] = "功能预告id"}},
        subtype = "reward_preopengift",
    },

    ["newrole"] = {
        explain = "创建玩家",
        log_format = {["account"] = {["id"] = "account", ["desc"] = "账号"}, ["channel"] = {["id"] = "channel", ["desc"] = "渠道"}, ["create_time"] = {["id"] = "create_time", ["desc"] = "创角时间"}, ["name"] = {["id"] = "name", ["desc"] = "玩家名字"}, ["pid"] = {["id"] = "pid", ["desc"] = "玩家id"}, ["school"] = {["id"] = "school", ["desc"] = "门派"}, ["shape"] = {["id"] = "shape", ["desc"] = "造型"}},
        subtype = "newrole",
    },

    ["day_newrole"] = {
        explain = "每天创建玩家数目",
        log_format = {["cnt"] = {["id"] = "cnt", ["desc"] = "新建玩家数目"}, ["day"] = {["id"] = "day", ["desc"] = "时间日期"}},
        subtype = "day_newrole",
    },

    ["newday"] = {
        explain = "记录在线时长",
        log_format = {["account"] = {["id"] = "account", ["desc"] = "账号"}, ["channel"] = {["id"] = "channel", ["desc"] = "渠道"}, ["duration"] = {["id"] = "duration", ["desc"] = "在线时长"}, ["grade"] = {["id"] = "grade", ["desc"] = "等级"}, ["name"] = {["id"] = "name", ["desc"] = "玩家名字"}, ["pid"] = {["id"] = "pid", ["desc"] = "玩家id"}, ["show_id"] = {["id"] = "show_id", ["desc"] = "显示id"}},
        subtype = "newday",
    },

    ["upgrade"] = {
        explain = "升级日志",
        log_format = {["channel"] = {["id"] = "channel", ["desc"] = "渠道"}, ["grade"] = {["id"] = "grade", ["desc"] = "等级"}, ["grade_from"] = {["id"] = "grade_from", ["desc"] = "升级前等级"}, ["name"] = {["id"] = "name", ["desc"] = "玩家名字"}, ["pid"] = {["id"] = "pid", ["desc"] = "玩家id"}, ["school"] = {["id"] = "school", ["desc"] = "门派"}, ["show_id"] = {["id"] = "show_id", ["desc"] = "显示id"}},
        subtype = "upgrade",
    },

    ["delconnection"] = {
        explain = "断开连接",
        log_format = {["pid"] = {["id"] = "pid", ["desc"] = "玩家"}, ["reason"] = {["id"] = "reason", ["desc"] = "断线原因"}},
        subtype = "delconnection",
    },

    ["redeem_code"] = {
        explain = "兑换码",
        log_format = {["code"] = {["id"] = "code", ["desc"] = "兑换码"}, ["gift_id"] = {["id"] = "gift_id", ["desc"] = "礼包Id"}, ["name"] = {["id"] = "name", ["desc"] = "玩家名字"}, ["pid"] = {["id"] = "pid", ["desc"] = "玩家id"}, ["show_id"] = {["id"] = "show_id", ["desc"] = "显示id"}, ["status"] = {["id"] = "status", ["desc"] = "状态"}},
        subtype = "redeem_code",
    },

    ["merger_reward"] = {
        explain = "合服补偿",
        log_format = {["items"] = {["id"] = "items", ["desc"] = "奖励"}, ["pid"] = {["id"] = "pid", ["desc"] = "玩家id"}, ["times"] = {["id"] = "times", ["desc"] = "合服次数"}},
        subtype = "merger_reward",
    },

    ["score"] = {
        explain = "评分变化",
        log_format = {["grade"] = {["id"] = "grade", ["desc"] = "等级"}, ["name"] = {["id"] = "name", ["desc"] = "玩家名字"}, ["pid"] = {["id"] = "pid", ["desc"] = "玩家id"}, ["score"] = {["id"] = "score", ["desc"] = "评分"}, ["sys"] = {["id"] = "sys", ["desc"] = "系统标记"}},
        subtype = "score",
    },

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

}
