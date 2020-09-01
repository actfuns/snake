-- ./excel/log/money.xlsx
return {

    ["add_gold"] = {
        explain = "获得金币",
        log_format = {["channel"] = {["id"] = "channel", ["desc"] = "渠道"}, ["gold_add"] = {["id"] = "gold_add", ["desc"] = "增加金币"}, ["gold_now"] = {["id"] = "gold_now", ["desc"] = "当前金币"}, ["gold_old"] = {["id"] = "gold_old", ["desc"] = "原有金币"}, ["gold_over_now"] = {["id"] = "gold_over_now", ["desc"] = "新溢出金币"}, ["gold_over_old"] = {["id"] = "gold_over_old", ["desc"] = "原溢出金币"}, ["gold_owe_now"] = {["id"] = "gold_owe_now", ["desc"] = "新欠款金币"}, ["gold_owe_old"] = {["id"] = "gold_owe_old", ["desc"] = "原欠款金币"}, ["grade"] = {["id"] = "grade", ["desc"] = "等级"}, ["name"] = {["id"] = "name", ["desc"] = "玩家名字"}, ["pid"] = {["id"] = "pid", ["desc"] = "玩家id"}, ["reason"] = {["id"] = "reason", ["desc"] = "原因"}, ["show_id"] = {["id"] = "show_id", ["desc"] = "显示id"}},
        subtype = "add_gold",
    },

    ["sub_gold"] = {
        explain = "消耗金币",
        log_format = {["channel"] = {["id"] = "channel", ["desc"] = "渠道"}, ["gold_now"] = {["id"] = "gold_now", ["desc"] = "当前金币"}, ["gold_old"] = {["id"] = "gold_old", ["desc"] = "原有金币"}, ["gold_over_now"] = {["id"] = "gold_over_now", ["desc"] = "新溢出金币"}, ["gold_over_old"] = {["id"] = "gold_over_old", ["desc"] = "原溢出金币"}, ["gold_owe_now"] = {["id"] = "gold_owe_now", ["desc"] = "新欠款金币"}, ["gold_owe_old"] = {["id"] = "gold_owe_old", ["desc"] = "原欠款金币"}, ["gold_sub"] = {["id"] = "gold_sub", ["desc"] = "增加金币"}, ["grade"] = {["id"] = "grade", ["desc"] = "等级"}, ["name"] = {["id"] = "name", ["desc"] = "玩家名字"}, ["pid"] = {["id"] = "pid", ["desc"] = "玩家id"}, ["reason"] = {["id"] = "reason", ["desc"] = "原因"}, ["show_id"] = {["id"] = "show_id", ["desc"] = "显示id"}, ["subreason"] = {["id"] = "subreason", ["desc"] = "子原因"}},
        subtype = "sub_gold",
    },

    ["add_silver"] = {
        explain = "获得银币",
        log_format = {["channel"] = {["id"] = "channel", ["desc"] = "渠道"}, ["grade"] = {["id"] = "grade", ["desc"] = "等级"}, ["name"] = {["id"] = "name", ["desc"] = "玩家名字"}, ["pid"] = {["id"] = "pid", ["desc"] = "玩家id"}, ["reason"] = {["id"] = "reason", ["desc"] = "原因"}, ["show_id"] = {["id"] = "show_id", ["desc"] = "显示id"}, ["silver_add"] = {["id"] = "silver_add", ["desc"] = "增加银币"}, ["silver_now"] = {["id"] = "silver_now", ["desc"] = "当前银币"}, ["silver_old"] = {["id"] = "silver_old", ["desc"] = "原有银币"}, ["silver_over_now"] = {["id"] = "silver_over_now", ["desc"] = "新溢出银币"}, ["silver_over_old"] = {["id"] = "silver_over_old", ["desc"] = "原溢出银币"}, ["silver_owe_now"] = {["id"] = "silver_owe_now", ["desc"] = "新欠款银币"}, ["silver_owe_old"] = {["id"] = "silver_owe_old", ["desc"] = "原欠款银币"}},
        subtype = "add_silver",
    },

    ["sub_silver"] = {
        explain = "消耗银币",
        log_format = {["channel"] = {["id"] = "channel", ["desc"] = "渠道"}, ["grade"] = {["id"] = "grade", ["desc"] = "等级"}, ["name"] = {["id"] = "name", ["desc"] = "玩家名字"}, ["pid"] = {["id"] = "pid", ["desc"] = "玩家id"}, ["reason"] = {["id"] = "reason", ["desc"] = "原因"}, ["show_id"] = {["id"] = "show_id", ["desc"] = "显示id"}, ["silver_now"] = {["id"] = "silver_now", ["desc"] = "当前银币"}, ["silver_old"] = {["id"] = "silver_old", ["desc"] = "原有银币"}, ["silver_over_now"] = {["id"] = "silver_over_now", ["desc"] = "新溢出银币"}, ["silver_over_old"] = {["id"] = "silver_over_old", ["desc"] = "原溢出银币"}, ["silver_owe_now"] = {["id"] = "silver_owe_now", ["desc"] = "新欠款银币"}, ["silver_owe_old"] = {["id"] = "silver_owe_old", ["desc"] = "原欠款银币"}, ["silver_sub"] = {["id"] = "silver_sub", ["desc"] = "增加银币"}, ["subreason"] = {["id"] = "subreason", ["desc"] = "子原因"}},
        subtype = "sub_silver",
    },

    ["add_goldcoin"] = {
        explain = "元宝变动",
        log_format = {["channel"] = {["id"] = "channel", ["desc"] = "渠道"}, ["goldcoin_add"] = {["id"] = "goldcoin_add", ["desc"] = "增加元宝"}, ["goldcoin_now"] = {["id"] = "goldcoin_now", ["desc"] = "当前元宝"}, ["goldcoin_old"] = {["id"] = "goldcoin_old", ["desc"] = "原元宝"}, ["goldcoin_owe_now"] = {["id"] = "goldcoin_owe_now", ["desc"] = "当前元宝欠账"}, ["goldcoin_owe_old"] = {["id"] = "goldcoin_owe_old", ["desc"] = "旧元宝欠账"}, ["grade"] = {["id"] = "grade", ["desc"] = "等级"}, ["name"] = {["id"] = "name", ["desc"] = "玩家名字"}, ["pid"] = {["id"] = "pid", ["desc"] = "玩家id"}, ["reason"] = {["id"] = "reason", ["desc"] = "原因"}, ["show_id"] = {["id"] = "show_id", ["desc"] = "显示id"}, ["truegoldcoin_owe_now"] = {["id"] = "truegoldcoin_owe_now", ["desc"] = "当前绑定元宝欠账"}, ["truegoldcoin_owe_old"] = {["id"] = "truegoldcoin_owe_old", ["desc"] = "旧绑定元宝欠账"}},
        subtype = "add_goldcoin",
    },

    ["add_rplgoldcoin"] = {
        explain = "代元宝变动",
        log_format = {["channel"] = {["id"] = "channel", ["desc"] = "渠道"}, ["goldcoin_owe_now"] = {["id"] = "goldcoin_owe_now", ["desc"] = "当前元宝欠账"}, ["goldcoin_owe_old"] = {["id"] = "goldcoin_owe_old", ["desc"] = "旧元宝欠账"}, ["grade"] = {["id"] = "grade", ["desc"] = "等级"}, ["name"] = {["id"] = "name", ["desc"] = "玩家名字"}, ["pid"] = {["id"] = "pid", ["desc"] = "玩家id"}, ["reason"] = {["id"] = "reason", ["desc"] = "原因"}, ["rplgoldcoin_add"] = {["id"] = "rplgoldcoin_add", ["desc"] = "增加代元宝"}, ["rplgoldcoin_now"] = {["id"] = "rplgoldcoin_now", ["desc"] = "当前代元宝"}, ["rplgoldcoin_old"] = {["id"] = "rplgoldcoin_old", ["desc"] = "原代元宝"}, ["show_id"] = {["id"] = "show_id", ["desc"] = "显示id"}},
        subtype = "add_rplgoldcoin",
    },

    ["sub_goldcoin"] = {
        explain = "消耗（代）元宝",
        log_format = {["channel"] = {["id"] = "channel", ["desc"] = "渠道"}, ["goldcoin_now"] = {["id"] = "goldcoin_now", ["desc"] = "当前元宝"}, ["goldcoin_old"] = {["id"] = "goldcoin_old", ["desc"] = "原元宝"}, ["goldcoin_owe_now"] = {["id"] = "goldcoin_owe_now", ["desc"] = "当前元宝欠账"}, ["goldcoin_owe_old"] = {["id"] = "goldcoin_owe_old", ["desc"] = "旧元宝欠账"}, ["goldcoin_sub"] = {["id"] = "goldcoin_sub", ["desc"] = "消耗元宝"}, ["grade"] = {["id"] = "grade", ["desc"] = "等级"}, ["name"] = {["id"] = "name", ["desc"] = "玩家名字"}, ["pid"] = {["id"] = "pid", ["desc"] = "玩家id"}, ["reason"] = {["id"] = "reason", ["desc"] = "原因"}, ["rplgoldcoin_now"] = {["id"] = "rplgoldcoin_now", ["desc"] = "当前代元宝"}, ["rplgoldcoin_old"] = {["id"] = "rplgoldcoin_old", ["desc"] = "原代元宝"}, ["rplgoldcoin_sub"] = {["id"] = "rplgoldcoin_sub", ["desc"] = "增加代元宝"}, ["show_id"] = {["id"] = "show_id", ["desc"] = "显示id"}, ["subreason"] = {["id"] = "subreason", ["desc"] = "子原因"}, ["truegoldcoin_owe_now"] = {["id"] = "truegoldcoin_owe_now", ["desc"] = "当前绑定元宝欠账"}, ["truegoldcoin_owe_old"] = {["id"] = "truegoldcoin_owe_old", ["desc"] = "旧绑定元宝欠账"}},
        subtype = "sub_goldcoin",
    },

    ["frozen_money"] = {
        explain = "冻结货币",
        log_format = {["channel"] = {["id"] = "channel", ["desc"] = "渠道"}, ["frozen_add"] = {["id"] = "frozen_add", ["desc"] = "冻结金额"}, ["frozen_now"] = {["id"] = "frozen_now", ["desc"] = "冻结货币总额"}, ["grade"] = {["id"] = "grade", ["desc"] = "等级"}, ["name"] = {["id"] = "name", ["desc"] = "玩家名字"}, ["pid"] = {["id"] = "pid", ["desc"] = "玩家id"}, ["reason"] = {["id"] = "reason", ["desc"] = "原因"}, ["session"] = {["id"] = "session", ["desc"] = "会话"}, ["show_id"] = {["id"] = "show_id", ["desc"] = "显示id"}, ["type"] = {["id"] = "type", ["desc"] = "货币类型"}},
        subtype = "frozen_money",
    },

    ["unfrozen_money"] = {
        explain = "解冻货币",
        log_format = {["channel"] = {["id"] = "channel", ["desc"] = "渠道"}, ["frozen_now"] = {["id"] = "frozen_now", ["desc"] = "冻结货币总额"}, ["frozen_sub"] = {["id"] = "frozen_sub", ["desc"] = "解冻金额"}, ["grade"] = {["id"] = "grade", ["desc"] = "等级"}, ["name"] = {["id"] = "name", ["desc"] = "玩家名字"}, ["pid"] = {["id"] = "pid", ["desc"] = "玩家id"}, ["reason"] = {["id"] = "reason", ["desc"] = "原因"}, ["session"] = {["id"] = "session", ["desc"] = "会话"}, ["show_id"] = {["id"] = "show_id", ["desc"] = "显示id"}, ["type"] = {["id"] = "type", ["desc"] = "货币类型"}},
        subtype = "unfrozen_money",
    },

    ["add_orgoffer"] = {
        explain = "获得帮贡",
        log_format = {["channel"] = {["id"] = "channel", ["desc"] = "渠道"}, ["freeze_orgoffer_now"] = {["id"] = "freeze_orgoffer_now", ["desc"] = "现冻结帮贡"}, ["freeze_orgoffer_sub"] = {["id"] = "freeze_orgoffer_sub", ["desc"] = "消耗冻结帮贡"}, ["grade"] = {["id"] = "grade", ["desc"] = "等级"}, ["name"] = {["id"] = "name", ["desc"] = "玩家名字"}, ["org_id"] = {["id"] = "org_id", ["desc"] = "帮派ID"}, ["orgoffer_add"] = {["id"] = "orgoffer_add", ["desc"] = "加帮贡"}, ["orgoffer_now"] = {["id"] = "orgoffer_now", ["desc"] = "现帮贡"}, ["orgoffer_old"] = {["id"] = "orgoffer_old", ["desc"] = "原帮贡"}, ["pid"] = {["id"] = "pid", ["desc"] = "玩家id"}, ["reason"] = {["id"] = "reason", ["desc"] = "原因"}, ["show_id"] = {["id"] = "show_id", ["desc"] = "显示id"}},
        subtype = "add_orgoffer",
    },

    ["sub_orgoffer"] = {
        explain = "消耗帮贡",
        log_format = {["channel"] = {["id"] = "channel", ["desc"] = "渠道"}, ["grade"] = {["id"] = "grade", ["desc"] = "等级"}, ["name"] = {["id"] = "name", ["desc"] = "玩家名字"}, ["org_id"] = {["id"] = "org_id", ["desc"] = "帮派ID"}, ["orgoffer_now"] = {["id"] = "orgoffer_now", ["desc"] = "现帮贡"}, ["orgoffer_old"] = {["id"] = "orgoffer_old", ["desc"] = "原帮贡"}, ["orgoffer_sub"] = {["id"] = "orgoffer_sub", ["desc"] = "减帮贡"}, ["pid"] = {["id"] = "pid", ["desc"] = "玩家id"}, ["reason"] = {["id"] = "reason", ["desc"] = "原因"}, ["show_id"] = {["id"] = "show_id", ["desc"] = "显示id"}},
        subtype = "sub_orgoffer",
    },

    ["vigor"] = {
        explain = "精气",
        log_format = {["channel"] = {["id"] = "channel", ["desc"] = "渠道"}, ["grade"] = {["id"] = "grade", ["desc"] = "等级"}, ["name"] = {["id"] = "name", ["desc"] = "玩家名字"}, ["pid"] = {["id"] = "pid", ["desc"] = "玩家id"}, ["reason"] = {["id"] = "reason", ["desc"] = "原因"}, ["show_id"] = {["id"] = "show_id", ["desc"] = "显示id"}, ["vigor_add"] = {["id"] = "vigor_add", ["desc"] = "增加精气"}, ["vigor_now"] = {["id"] = "vigor_now", ["desc"] = "当前精气"}, ["vigor_old"] = {["id"] = "vigor_old", ["desc"] = "原有精气"}},
        subtype = "vigor",
    },

    ["add_wuxun"] = {
        explain = "获得武勋",
        log_format = {["channel"] = {["id"] = "channel", ["desc"] = "渠道"}, ["grade"] = {["id"] = "grade", ["desc"] = "等级"}, ["name"] = {["id"] = "name", ["desc"] = "玩家名字"}, ["pid"] = {["id"] = "pid", ["desc"] = "玩家id"}, ["reason"] = {["id"] = "reason", ["desc"] = "原因"}, ["show_id"] = {["id"] = "show_id", ["desc"] = "显示id"}, ["wuxun_add"] = {["id"] = "wuxun_add", ["desc"] = "增加武勋"}, ["wuxun_now"] = {["id"] = "wuxun_now", ["desc"] = "当前武勋"}, ["wuxun_old"] = {["id"] = "wuxun_old", ["desc"] = "原有武勋"}},
        subtype = "add_wuxun",
    },

    ["sub_wuxun"] = {
        explain = "消耗武勋",
        log_format = {["channel"] = {["id"] = "channel", ["desc"] = "渠道"}, ["grade"] = {["id"] = "grade", ["desc"] = "等级"}, ["name"] = {["id"] = "name", ["desc"] = "玩家名字"}, ["pid"] = {["id"] = "pid", ["desc"] = "玩家id"}, ["reason"] = {["id"] = "reason", ["desc"] = "原因"}, ["show_id"] = {["id"] = "show_id", ["desc"] = "显示id"}, ["wuxun_now"] = {["id"] = "wuxun_now", ["desc"] = "当前武勋"}, ["wuxun_old"] = {["id"] = "wuxun_old", ["desc"] = "原有武勋"}, ["wuxun_sub"] = {["id"] = "wuxun_sub", ["desc"] = "增加武勋"}},
        subtype = "sub_wuxun",
    },

    ["add_jjcpoint"] = {
        explain = "获得武勋",
        log_format = {["channel"] = {["id"] = "channel", ["desc"] = "渠道"}, ["grade"] = {["id"] = "grade", ["desc"] = "等级"}, ["jjcpoint_add"] = {["id"] = "jjcpoint_add", ["desc"] = "增加武勋"}, ["jjcpoint_now"] = {["id"] = "jjcpoint_now", ["desc"] = "当前武勋"}, ["jjcpoint_old"] = {["id"] = "jjcpoint_old", ["desc"] = "原有武勋"}, ["name"] = {["id"] = "name", ["desc"] = "玩家名字"}, ["pid"] = {["id"] = "pid", ["desc"] = "玩家id"}, ["reason"] = {["id"] = "reason", ["desc"] = "原因"}, ["show_id"] = {["id"] = "show_id", ["desc"] = "显示id"}},
        subtype = "add_jjcpoint",
    },

    ["sub_jjcpoint"] = {
        explain = "消耗武勋",
        log_format = {["channel"] = {["id"] = "channel", ["desc"] = "渠道"}, ["grade"] = {["id"] = "grade", ["desc"] = "等级"}, ["jjcpoint_now"] = {["id"] = "jjcpoint_now", ["desc"] = "当前武勋"}, ["jjcpoint_old"] = {["id"] = "jjcpoint_old", ["desc"] = "原有武勋"}, ["jjcpoint_sub"] = {["id"] = "jjcpoint_sub", ["desc"] = "增加武勋"}, ["name"] = {["id"] = "name", ["desc"] = "玩家名字"}, ["pid"] = {["id"] = "pid", ["desc"] = "玩家id"}, ["reason"] = {["id"] = "reason", ["desc"] = "原因"}, ["show_id"] = {["id"] = "show_id", ["desc"] = "显示id"}},
        subtype = "sub_jjcpoint",
    },

    ["add_leaderpoint"] = {
        explain = "获得功勋",
        log_format = {["channel"] = {["id"] = "channel", ["desc"] = "渠道"}, ["grade"] = {["id"] = "grade", ["desc"] = "等级"}, ["leaderpoint_add"] = {["id"] = "leaderpoint_add", ["desc"] = "增加功勋"}, ["leaderpoint_now"] = {["id"] = "leaderpoint_now", ["desc"] = "当前功勋"}, ["leaderpoint_old"] = {["id"] = "leaderpoint_old", ["desc"] = "原有功勋"}, ["name"] = {["id"] = "name", ["desc"] = "玩家名字"}, ["pid"] = {["id"] = "pid", ["desc"] = "玩家id"}, ["reason"] = {["id"] = "reason", ["desc"] = "原因"}, ["show_id"] = {["id"] = "show_id", ["desc"] = "显示id"}},
        subtype = "add_leaderpoint",
    },

    ["sub_leaderpoint"] = {
        explain = "消耗功勋",
        log_format = {["channel"] = {["id"] = "channel", ["desc"] = "渠道"}, ["grade"] = {["id"] = "grade", ["desc"] = "等级"}, ["leaderpoint_now"] = {["id"] = "leaderpoint_now", ["desc"] = "当前功勋"}, ["leaderpoint_old"] = {["id"] = "leaderpoint_old", ["desc"] = "原有功勋"}, ["leaderpoint_sub"] = {["id"] = "leaderpoint_sub", ["desc"] = "增加功勋"}, ["name"] = {["id"] = "name", ["desc"] = "玩家名字"}, ["pid"] = {["id"] = "pid", ["desc"] = "玩家id"}, ["reason"] = {["id"] = "reason", ["desc"] = "原因"}, ["show_id"] = {["id"] = "show_id", ["desc"] = "显示id"}},
        subtype = "sub_leaderpoint",
    },

    ["add_xiayipoint"] = {
        explain = "获得狭义值",
        log_format = {["channel"] = {["id"] = "channel", ["desc"] = "渠道"}, ["grade"] = {["id"] = "grade", ["desc"] = "等级"}, ["name"] = {["id"] = "name", ["desc"] = "玩家名字"}, ["pid"] = {["id"] = "pid", ["desc"] = "玩家id"}, ["reason"] = {["id"] = "reason", ["desc"] = "原因"}, ["show_id"] = {["id"] = "show_id", ["desc"] = "显示id"}, ["xiayipoint_add"] = {["id"] = "xiayipoint_add", ["desc"] = "增加狭义值"}, ["xiayipoint_now"] = {["id"] = "xiayipoint_now", ["desc"] = "当前狭义值"}, ["xiayipoint_old"] = {["id"] = "xiayipoint_old", ["desc"] = "原有狭义值"}},
        subtype = "add_xiayipoint",
    },

    ["sub_xiayipoint"] = {
        explain = "消耗狭义值",
        log_format = {["channel"] = {["id"] = "channel", ["desc"] = "渠道"}, ["grade"] = {["id"] = "grade", ["desc"] = "等级"}, ["name"] = {["id"] = "name", ["desc"] = "玩家名字"}, ["pid"] = {["id"] = "pid", ["desc"] = "玩家id"}, ["reason"] = {["id"] = "reason", ["desc"] = "原因"}, ["show_id"] = {["id"] = "show_id", ["desc"] = "显示id"}, ["xiayipoint_now"] = {["id"] = "xiayipoint_now", ["desc"] = "当前狭义值"}, ["xiayipoint_old"] = {["id"] = "xiayipoint_old", ["desc"] = "原有狭义值"}, ["xiayipoint_sub"] = {["id"] = "xiayipoint_sub", ["desc"] = "增加狭义值"}},
        subtype = "sub_xiayipoint",
    },

    ["add_summonpoint"] = {
        explain = "获得宠物合成积分",
        log_format = {["channel"] = {["id"] = "channel", ["desc"] = "渠道"}, ["grade"] = {["id"] = "grade", ["desc"] = "等级"}, ["name"] = {["id"] = "name", ["desc"] = "玩家名字"}, ["pid"] = {["id"] = "pid", ["desc"] = "玩家id"}, ["reason"] = {["id"] = "reason", ["desc"] = "原因"}, ["show_id"] = {["id"] = "show_id", ["desc"] = "显示id"}, ["summonpoint_add"] = {["id"] = "summonpoint_add", ["desc"] = "增加合成积分"}, ["summonpoint_now"] = {["id"] = "summonpoint_now", ["desc"] = "当前合成积分"}, ["summonpoint_old"] = {["id"] = "summonpoint_old", ["desc"] = "原有合成积分"}},
        subtype = "add_summonpoint",
    },

    ["sub_summonpoint"] = {
        explain = "消耗宠物合成积分",
        log_format = {["channel"] = {["id"] = "channel", ["desc"] = "渠道"}, ["grade"] = {["id"] = "grade", ["desc"] = "等级"}, ["name"] = {["id"] = "name", ["desc"] = "玩家名字"}, ["pid"] = {["id"] = "pid", ["desc"] = "玩家id"}, ["reason"] = {["id"] = "reason", ["desc"] = "原因"}, ["show_id"] = {["id"] = "show_id", ["desc"] = "显示id"}, ["summonpoint_now"] = {["id"] = "summonpoint_now", ["desc"] = "当前合成积分"}, ["summonpoint_old"] = {["id"] = "summonpoint_old", ["desc"] = "原有合成积分"}, ["summonpoint_sub"] = {["id"] = "summonpoint_sub", ["desc"] = "增加合成积分"}},
        subtype = "sub_summonpoint",
    },

    ["add_storypoint"] = {
        explain = "获得剧情点",
        log_format = {["channel"] = {["id"] = "channel", ["desc"] = "渠道"}, ["grade"] = {["id"] = "grade", ["desc"] = "等级"}, ["name"] = {["id"] = "name", ["desc"] = "玩家名字"}, ["pid"] = {["id"] = "pid", ["desc"] = "玩家id"}, ["reason"] = {["id"] = "reason", ["desc"] = "理由"}, ["show_id"] = {["id"] = "show_id", ["desc"] = "显示id"}, ["storypoint_add"] = {["id"] = "storypoint_add", ["desc"] = "获得剧情点"}, ["storypoint_cur"] = {["id"] = "storypoint_cur", ["desc"] = "当前剧情点"}},
        subtype = "add_storypoint",
    },

    ["sub_storypoint"] = {
        explain = "消耗剧情点",
        log_format = {["channel"] = {["id"] = "channel", ["desc"] = "渠道"}, ["grade"] = {["id"] = "grade", ["desc"] = "等级"}, ["name"] = {["id"] = "name", ["desc"] = "玩家名字"}, ["pid"] = {["id"] = "pid", ["desc"] = "玩家id"}, ["reason"] = {["id"] = "reason", ["desc"] = "理由"}, ["show_id"] = {["id"] = "show_id", ["desc"] = "显示id"}, ["storypoint_cur"] = {["id"] = "storypoint_cur", ["desc"] = "当前剧情点"}, ["storypoint_sub"] = {["id"] = "storypoint_sub", ["desc"] = "消耗剧情点"}},
        subtype = "sub_storypoint",
    },

    ["add_chumopoint"] = {
        explain = "获得除魔值",
        log_format = {["channel"] = {["id"] = "channel", ["desc"] = "渠道"}, ["chumopoint_add"] = {["id"] = "chumopoint_add", ["desc"] = "增加除魔值"}, ["chumopoint_now"] = {["id"] = "chumopoint_now", ["desc"] = "当前除魔值"}, ["chumopoint_old"] = {["id"] = "chumopoint_old", ["desc"] = "原有除魔值"}, ["grade"] = {["id"] = "grade", ["desc"] = "等级"}, ["name"] = {["id"] = "name", ["desc"] = "玩家名字"}, ["pid"] = {["id"] = "pid", ["desc"] = "玩家id"}, ["reason"] = {["id"] = "reason", ["desc"] = "原因"}, ["show_id"] = {["id"] = "show_id", ["desc"] = "显示id"}},
        subtype = "add_chumopoint",
    },

    ["sub_chumopoint"] = {
        explain = "消耗除魔值",
        log_format = {["channel"] = {["id"] = "channel", ["desc"] = "渠道"}, ["chumopoint_now"] = {["id"] = "chumopoint_now", ["desc"] = "当前除魔值"}, ["chumopoint_old"] = {["id"] = "chumopoint_old", ["desc"] = "原有除魔值"}, ["chumopoint_sub"] = {["id"] = "chumopoint_sub", ["desc"] = "消耗除魔值"}, ["grade"] = {["id"] = "grade", ["desc"] = "等级"}, ["name"] = {["id"] = "name", ["desc"] = "玩家名字"}, ["pid"] = {["id"] = "pid", ["desc"] = "玩家id"}, ["reason"] = {["id"] = "reason", ["desc"] = "原因"}, ["show_id"] = {["id"] = "show_id", ["desc"] = "显示id"}},
        subtype = "sub_chumopoint",
    },

}
