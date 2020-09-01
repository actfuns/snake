-- ./excel/log/jjc.xlsx
return {

    ["new_season"] = {
        explain = "新赛季开始",
        log_format = {["month"] = {["id"] = "month", ["desc"] = "赛季月份"}},
        subtype = "new_season",
    },

    ["season_end"] = {
        explain = "赛季结束信息",
        log_format = {["month"] = {["id"] = "month", ["desc"] = "赛季月份"}},
        subtype = "season_end",
    },

    ["formation"] = {
        explain = "设置阵法",
        log_format = {["channel"] = {["id"] = "channel", ["desc"] = "渠道"}, ["formation"] = {["id"] = "formation", ["desc"] = "阵法id"}, ["grade"] = {["id"] = "grade", ["desc"] = "等级"}, ["name"] = {["id"] = "name", ["desc"] = "玩家名字"}, ["pid"] = {["id"] = "pid", ["desc"] = "玩家id"}, ["show_id"] = {["id"] = "show_id", ["desc"] = "显示id"}},
        subtype = "formation",
    },

    ["summon"] = {
        explain = "设置出战宠物",
        log_format = {["channel"] = {["id"] = "channel", ["desc"] = "渠道"}, ["grade"] = {["id"] = "grade", ["desc"] = "等级"}, ["name"] = {["id"] = "name", ["desc"] = "玩家名字"}, ["pid"] = {["id"] = "pid", ["desc"] = "玩家id"}, ["show_id"] = {["id"] = "show_id", ["desc"] = "显示id"}, ["summonid"] = {["id"] = "summonid", ["desc"] = "宠物id"}},
        subtype = "summon",
    },

    ["partner"] = {
        explain = "设置出战伙伴",
        log_format = {["channel"] = {["id"] = "channel", ["desc"] = "渠道"}, ["grade"] = {["id"] = "grade", ["desc"] = "等级"}, ["name"] = {["id"] = "name", ["desc"] = "玩家名字"}, ["partner"] = {["id"] = "partner", ["desc"] = "伙伴信息"}, ["pid"] = {["id"] = "pid", ["desc"] = "玩家id"}, ["show_id"] = {["id"] = "show_id", ["desc"] = "显示id"}},
        subtype = "partner",
    },

    ["fight"] = {
        explain = "挑战信息",
        log_format = {["channel"] = {["id"] = "channel", ["desc"] = "渠道"}, ["grade"] = {["id"] = "grade", ["desc"] = "等级"}, ["name"] = {["id"] = "name", ["desc"] = "玩家名字"}, ["pid"] = {["id"] = "pid", ["desc"] = "玩家id"}, ["show_id"] = {["id"] = "show_id", ["desc"] = "显示id"}, ["target_id"] = {["id"] = "target_id", ["desc"] = "挑战目标id"}, ["target_type"] = {["id"] = "target_type", ["desc"] = "挑战目标类型"}},
        subtype = "fight",
    },

    ["reward"] = {
        explain = "奖励信息",
        log_format = {["channel"] = {["id"] = "channel", ["desc"] = "渠道"}, ["grade"] = {["id"] = "grade", ["desc"] = "等级"}, ["items"] = {["id"] = "items", ["desc"] = "奖励道具"}, ["name"] = {["id"] = "name", ["desc"] = "玩家名字"}, ["pid"] = {["id"] = "pid", ["desc"] = "玩家id"}, ["point"] = {["id"] = "point", ["desc"] = "奖励分数"}, ["show_id"] = {["id"] = "show_id", ["desc"] = "显示id"}},
        subtype = "reward",
    },

    ["rank"] = {
        explain = "排行变化",
        log_format = {["channel"] = {["id"] = "channel", ["desc"] = "渠道"}, ["defeatrank"] = {["id"] = "defeatrank", ["desc"] = "挑战目标排行"}, ["grade"] = {["id"] = "grade", ["desc"] = "等级"}, ["name"] = {["id"] = "name", ["desc"] = "玩家名字"}, ["pid"] = {["id"] = "pid", ["desc"] = "玩家id"}, ["rank"] = {["id"] = "rank", ["desc"] = "玩家排行"}, ["show_id"] = {["id"] = "show_id", ["desc"] = "显示id"}, ["target_id"] = {["id"] = "target_id", ["desc"] = "挑战目标id"}, ["target_type"] = {["id"] = "target_type", ["desc"] = "挑战目标类型"}, ["win"] = {["id"] = "win", ["desc"] = "是否挑战成功"}},
        subtype = "rank",
    },

    ["fight_times"] = {
        explain = "挑战次数",
        log_format = {["channel"] = {["id"] = "channel", ["desc"] = "渠道"}, ["gold"] = {["id"] = "gold", ["desc"] = "消费金币"}, ["grade"] = {["id"] = "grade", ["desc"] = "等级"}, ["hasbuy"] = {["id"] = "hasbuy", ["desc"] = "已购买挑战次数"}, ["name"] = {["id"] = "name", ["desc"] = "玩家名字"}, ["pid"] = {["id"] = "pid", ["desc"] = "玩家id"}, ["show_id"] = {["id"] = "show_id", ["desc"] = "显示id"}},
        subtype = "fight_times",
    },

    ["cd"] = {
        explain = "挑战冷却时间",
        log_format = {["channel"] = {["id"] = "channel", ["desc"] = "渠道"}, ["gold"] = {["id"] = "gold", ["desc"] = "消费金币"}, ["grade"] = {["id"] = "grade", ["desc"] = "等级"}, ["name"] = {["id"] = "name", ["desc"] = "玩家名字"}, ["pid"] = {["id"] = "pid", ["desc"] = "玩家id"}, ["show_id"] = {["id"] = "show_id", ["desc"] = "显示id"}, ["time"] = {["id"] = "time", ["desc"] = "冷却时间"}},
        subtype = "cd",
    },

    ["challenge_info"] = {
        explain = "连续挑战信息",
        log_format = {["channel"] = {["id"] = "channel", ["desc"] = "渠道"}, ["grade"] = {["id"] = "grade", ["desc"] = "等级"}, ["level"] = {["id"] = "level", ["desc"] = "连续挑战难度"}, ["name"] = {["id"] = "name", ["desc"] = "玩家名字"}, ["pid"] = {["id"] = "pid", ["desc"] = "玩家id"}, ["show_id"] = {["id"] = "show_id", ["desc"] = "显示id"}, ["times"] = {["id"] = "times", ["desc"] = "剩余重置次数"}},
        subtype = "challenge_info",
    },

    ["challenge_reset"] = {
        explain = "重置连续挑战",
        log_format = {["channel"] = {["id"] = "channel", ["desc"] = "渠道"}, ["grade"] = {["id"] = "grade", ["desc"] = "等级"}, ["name"] = {["id"] = "name", ["desc"] = "玩家名字"}, ["pid"] = {["id"] = "pid", ["desc"] = "玩家id"}, ["show_id"] = {["id"] = "show_id", ["desc"] = "显示id"}, ["times"] = {["id"] = "times", ["desc"] = "剩余重置次数"}},
        subtype = "challenge_reset",
    },

}
