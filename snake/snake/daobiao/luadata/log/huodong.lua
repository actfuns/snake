-- ./excel/log/huodong.xlsx
return {

    ["dance"] = {
        explain = "跳舞活动",
        log_format = {["flag"] = {["id"] = "flag", ["desc"] = "操作对象"}, ["op"] = {["id"] = "op", ["desc"] = "操作"}, ["pid"] = {["id"] = "pid", ["desc"] = "玩家id"}, ["value"] = {["id"] = "value", ["desc"] = "数据"}},
        subtype = "dance",
    },

    ["signin_sign"] = {
        explain = "签到",
        log_format = {["pid"] = {["id"] = "pid", ["desc"] = "玩家id"}, ["show_id"] = {["id"] = "show_id", ["desc"] = "显示id"}},
        subtype = "signin_sign",
    },

    ["signin_replenish"] = {
        explain = "签到补签",
        log_format = {["after"] = {["id"] = "after", ["desc"] = "补签后可补签次数"}, ["before"] = {["id"] = "before", ["desc"] = "补签前可补签次数"}, ["pid"] = {["id"] = "pid", ["desc"] = "玩家id"}, ["show_id"] = {["id"] = "show_id", ["desc"] = "显示id"}},
        subtype = "signin_replenish",
    },

    ["signin_addreplenish"] = {
        explain = "获得补签次数",
        log_format = {["after"] = {["id"] = "after", ["desc"] = "获得后可补签次数"}, ["before"] = {["id"] = "before", ["desc"] = "获得前可补签次数"}, ["pid"] = {["id"] = "pid", ["desc"] = "玩家id"}, ["show_id"] = {["id"] = "show_id", ["desc"] = "显示id"}},
        subtype = "signin_addreplenish",
    },

    ["signin_fortune"] = {
        explain = "签到运势",
        log_format = {["fortune"] = {["id"] = "fortune", ["desc"] = "运势"}, ["pid"] = {["id"] = "pid", ["desc"] = "玩家id"}, ["show_id"] = {["id"] = "show_id", ["desc"] = "显示id"}},
        subtype = "signin_fortune",
    },

    ["signin_lottery"] = {
        explain = "签到抽奖",
        log_format = {["after"] = {["id"] = "after", ["desc"] = "抽奖后抽奖次数"}, ["before"] = {["id"] = "before", ["desc"] = "抽奖前抽奖次数"}, ["pid"] = {["id"] = "pid", ["desc"] = "玩家id"}, ["show_id"] = {["id"] = "show_id", ["desc"] = "显示id"}},
        subtype = "signin_lottery",
    },

    ["signin_addlottery"] = {
        explain = "获得签到次数",
        log_format = {["after"] = {["id"] = "after", ["desc"] = "获得后抽奖次数"}, ["before"] = {["id"] = "before", ["desc"] = "获得前抽奖次数"}, ["pid"] = {["id"] = "pid", ["desc"] = "玩家id"}, ["show_id"] = {["id"] = "show_id", ["desc"] = "显示id"}, ["total_sign"] = {["id"] = "total_sign", ["desc"] = "总签到次数"}},
        subtype = "signin_addlottery",
    },

    ["mengzhu"] = {
        explain = "帮派秘境",
        log_format = {["info"] = {["id"] = "info", ["desc"] = "详细信息"}, ["pid"] = {["id"] = "pid", ["desc"] = "玩家id"}},
        subtype = "mengzhu",
    },

    ["schoolpass_reward"] = {
        explain = "门派试练任务奖励",
        log_format = {["pid"] = {["id"] = "pid", ["desc"] = "玩家id"}, ["reward"] = {["id"] = "reward", ["desc"] = "奖励项"}, ["rewardcnt"] = {["id"] = "rewardcnt", ["desc"] = "奖励次数"}, ["show_id"] = {["id"] = "show_id", ["desc"] = "显示id"}, ["task"] = {["id"] = "task", ["desc"] = "任务id"}},
        subtype = "schoolpass_reward",
    },

    ["schoolpass_result"] = {
        explain = "门派试练成绩",
        log_format = {["noteamresult"] = {["id"] = "noteamresult", ["desc"] = "无效队伍成绩"}, ["pid"] = {["id"] = "pid", ["desc"] = "玩家id"}, ["resultcancel"] = {["id"] = "resultcancel", ["desc"] = "无效个人成绩"}, ["teammember"] = {["id"] = "teammember", ["desc"] = "队伍成员"}},
        subtype = "schoolpass_result",
    },

    ["fumo_start"] = {
        explain = "附魔副本开启",
        log_format = {["teammember"] = {["id"] = "teammember", ["desc"] = "队伍成员"}},
        subtype = "fumo_start",
    },

    ["fumo_step_reward"] = {
        explain = "附魔副本关卡奖励",
        log_format = {["step"] = {["id"] = "step", ["desc"] = "关卡"}, ["teammember"] = {["id"] = "teammember", ["desc"] = "队伍成员"}},
        subtype = "fumo_step_reward",
    },

    ["fumo_done"] = {
        explain = "伏魔副本完毕",
        log_format = {["doneinfo"] = {["id"] = "doneinfo", ["desc"] = "完成信息"}},
        subtype = "fumo_done",
    },

    ["biwu_start"] = {
        explain = "比武开启",
        log_format = {["state"] = {["id"] = "state", ["desc"] = "状态"}},
        subtype = "biwu_start",
    },

    ["biwu_end"] = {
        explain = "比武结束",
        log_format = {["state"] = {["id"] = "state", ["desc"] = "状态"}},
        subtype = "biwu_end",
    },

    ["biwu_battle"] = {
        explain = "比武对战",
        log_format = {["battle1"] = {["id"] = "battle1", ["desc"] = "队伍成员"}, ["battle2"] = {["id"] = "battle2", ["desc"] = "队伍成员"}},
        subtype = "biwu_battle",
    },

    ["biwu_warend"] = {
        explain = "比武战斗结束",
        log_format = {["player"] = {["id"] = "player", ["desc"] = "战士信息"}, ["winside"] = {["id"] = "winside", ["desc"] = "胜利方"}},
        subtype = "biwu_warend",
    },

    ["biwu_sort"] = {
        explain = "比武结束排名",
        log_format = {["sort"] = {["id"] = "sort", ["desc"] = "排名信息"}},
        subtype = "biwu_sort",
    },

    ["fenyao_ownerreward"] = {
        explain = "封妖主人奖励",
        log_format = {["money"] = {["id"] = "money", ["desc"] = "货币类型"}, ["owner"] = {["id"] = "owner", ["desc"] = "主人"}, ["pid"] = {["id"] = "pid", ["desc"] = "玩家"}, ["value"] = {["id"] = "value", ["desc"] = "数据"}},
        subtype = "fenyao_ownerreward",
    },

    ["fenyao_player"] = {
        explain = "玩家触发封妖",
        log_format = {["flag"] = {["id"] = "flag", ["desc"] = "类型"}, ["mapid"] = {["id"] = "mapid", ["desc"] = "地图id"}, ["pid"] = {["id"] = "pid", ["desc"] = "玩家"}},
        subtype = "fenyao_player",
    },

    ["fenyao_refresh"] = {
        explain = "刷封妖",
        log_format = {["amount"] = {["id"] = "amount", ["desc"] = "数量"}, ["pid"] = {["id"] = "pid", ["desc"] = "玩家"}, ["trigger"] = {["id"] = "trigger", ["desc"] = "触发类型"}},
        subtype = "fenyao_refresh",
    },

    ["devil_refresh"] = {
        explain = "刷天魔",
        log_format = {["refresh"] = {["id"] = "refresh", ["desc"] = "刷新信息"}},
        subtype = "devil_refresh",
    },

    ["campfire_answer"] = {
        explain = "篝火答题",
        log_format = {["channel"] = {["id"] = "channel", ["desc"] = "渠道"}, ["correct"] = {["id"] = "correct", ["desc"] = "是否回答正确"}, ["grade"] = {["id"] = "grade", ["desc"] = "等级"}, ["name"] = {["id"] = "name", ["desc"] = "玩家名字"}, ["pid"] = {["id"] = "pid", ["desc"] = "玩家id"}, ["ques_id"] = {["id"] = "ques_id", ["desc"] = "题目id"}, ["reward"] = {["id"] = "reward", ["desc"] = "奖励信息"}, ["rewardid"] = {["id"] = "rewardid", ["desc"] = "奖励表id"}, ["round"] = {["id"] = "round", ["desc"] = "题目轮次"}, ["show_id"] = {["id"] = "show_id", ["desc"] = "显示id"}},
        subtype = "campfire_answer",
    },

    ["campfire_reward_fire_exp"] = {
        explain = "获得篝火经验",
        log_format = {["adds"] = {["id"] = "adds", ["desc"] = "加成百分比"}, ["channel"] = {["id"] = "channel", ["desc"] = "渠道"}, ["exp"] = {["id"] = "exp", ["desc"] = "经验值"}, ["grade"] = {["id"] = "grade", ["desc"] = "等级"}, ["name"] = {["id"] = "name", ["desc"] = "玩家名字"}, ["pid"] = {["id"] = "pid", ["desc"] = "玩家id"}, ["show_id"] = {["id"] = "show_id", ["desc"] = "显示id"}},
        subtype = "campfire_reward_fire_exp",
    },

    ["campfire_drink_purchase"] = {
        explain = "篝火饮酒支付",
        log_format = {["channel"] = {["id"] = "channel", ["desc"] = "渠道"}, ["drink_amount"] = {["id"] = "drink_amount", ["desc"] = "饮酒数"}, ["grade"] = {["id"] = "grade", ["desc"] = "等级"}, ["item"] = {["id"] = "item", ["desc"] = "物品sid"}, ["name"] = {["id"] = "name", ["desc"] = "玩家名字"}, ["pid"] = {["id"] = "pid", ["desc"] = "玩家id"}, ["show_id"] = {["id"] = "show_id", ["desc"] = "显示id"}, ["sub_goldcoin"] = {["id"] = "sub_goldcoin", ["desc"] = "扣元宝数"}, ["sub_item_amount"] = {["id"] = "sub_item_amount", ["desc"] = "扣物品数"}},
        subtype = "campfire_drink_purchase",
    },

    ["campfire_drink_reward"] = {
        explain = "篝火饮酒奖励",
        log_format = {["channel"] = {["id"] = "channel", ["desc"] = "渠道"}, ["drink_amount"] = {["id"] = "drink_amount", ["desc"] = "饮酒数"}, ["drink_org_cnt"] = {["id"] = "drink_org_cnt", ["desc"] = "帮派饮酒总量"}, ["drink_person_cnt"] = {["id"] = "drink_person_cnt", ["desc"] = "个人饮酒总量"}, ["grade"] = {["id"] = "grade", ["desc"] = "等级"}, ["name"] = {["id"] = "name", ["desc"] = "玩家名字"}, ["orgid"] = {["id"] = "orgid", ["desc"] = "帮派id"}, ["pid"] = {["id"] = "pid", ["desc"] = "玩家id"}, ["reward_orgoffer"] = {["id"] = "reward_orgoffer", ["desc"] = "奖励帮贡"}, ["show_id"] = {["id"] = "show_id", ["desc"] = "显示id"}},
        subtype = "campfire_drink_reward",
    },

    ["campfire_tie_purchase"] = {
        explain = "篝火情意结支付",
        log_format = {["channel"] = {["id"] = "channel", ["desc"] = "渠道"}, ["grade"] = {["id"] = "grade", ["desc"] = "等级"}, ["item"] = {["id"] = "item", ["desc"] = "物品sid"}, ["name"] = {["id"] = "name", ["desc"] = "玩家名字"}, ["pid"] = {["id"] = "pid", ["desc"] = "玩家id"}, ["show_id"] = {["id"] = "show_id", ["desc"] = "显示id"}, ["sub_goldcoin"] = {["id"] = "sub_goldcoin", ["desc"] = "扣元宝数"}, ["sub_item_amount"] = {["id"] = "sub_item_amount", ["desc"] = "扣物品数"}},
        subtype = "campfire_tie_purchase",
    },

    ["liumai_battle"] = {
        explain = "六脉对战",
        log_format = {["battle1"] = {["id"] = "battle1", ["desc"] = "队伍成员"}, ["battle2"] = {["id"] = "battle2", ["desc"] = "队伍成员"}},
        subtype = "liumai_battle",
    },

    ["liumai_warend"] = {
        explain = "六脉战斗结束",
        log_format = {["failleader"] = {["id"] = "failleader", ["desc"] = "失败队长"}, ["gamestate"] = {["id"] = "gamestate", ["desc"] = "玩法进度"}, ["player"] = {["id"] = "player", ["desc"] = "战士信息"}, ["playerinfo"] = {["id"] = "playerinfo", ["desc"] = "战士信息"}, ["ttstate"] = {["id"] = "ttstate", ["desc"] = "淘汰进度"}, ["winleader"] = {["id"] = "winleader", ["desc"] = "胜利队长"}, ["winside"] = {["id"] = "winside", ["desc"] = "胜利方"}},
        subtype = "liumai_warend",
    },

    ["charge"] = {
        explain = "充值礼包",
        log_format = {["info"] = {["id"] = "info", ["desc"] = "详细信息"}, ["pid"] = {["id"] = "pid", ["desc"] = "玩家id"}},
        subtype = "charge",
    },

    ["welfare"] = {
        explain = "运营活动礼包",
        log_format = {["info"] = {["id"] = "info", ["desc"] = "详细信息"}, ["pid"] = {["id"] = "pid", ["desc"] = "玩家id"}},
        subtype = "welfare",
    },

    ["caishen"] = {
        explain = "财神送礼",
        log_format = {["info"] = {["id"] = "info", ["desc"] = "详细信息"}, ["pid"] = {["id"] = "pid", ["desc"] = "玩家id"}},
        subtype = "caishen",
    },

    ["lingxi_reward_friend_degree"] = {
        explain = "灵犀奖好友度",
        log_format = {["add_degree"] = {["id"] = "add_degree", ["desc"] = "增加好友度"}, ["new_degree1"] = {["id"] = "new_degree1", ["desc"] = "玩家1新好友度"}, ["new_degree2"] = {["id"] = "new_degree2", ["desc"] = "玩家2新好友度"}, ["old_degree1"] = {["id"] = "old_degree1", ["desc"] = "玩家1旧好友度"}, ["old_degree2"] = {["id"] = "old_degree2", ["desc"] = "玩家2旧好友度"}, ["pid1"] = {["id"] = "pid1", ["desc"] = "玩家1id"}, ["pid2"] = {["id"] = "pid2", ["desc"] = "玩家2id"}, ["rewardid"] = {["id"] = "rewardid", ["desc"] = "奖励表id"}},
        subtype = "lingxi_reward_friend_degree",
    },

    ["orgwar"] = {
        explain = "帮战日志",
        log_format = {["info"] = {["id"] = "info", ["desc"] = "日志信息"}},
        subtype = "orgwar",
    },

    ["return_goldcoin"] = {
        explain = "封测返利",
        log_format = {["name"] = {["id"] = "name", ["desc"] = "玩家名"}, ["pid"] = {["id"] = "pid", ["desc"] = "玩家id"}, ["type"] = {["id"] = "type", ["desc"] = "领取类型"}},
        subtype = "return_goldcoin",
    },

    ["sevenlogin_state"] = {
        explain = "7天登录",
        log_format = {["state"] = {["id"] = "state", ["desc"] = "状态"}, ["version"] = {["id"] = "version", ["desc"] = "版本"}},
        subtype = "sevenlogin_state",
    },

    ["sevenlogin_reward"] = {
        explain = "7天登录奖励",
        log_format = {["day"] = {["id"] = "day", ["desc"] = "登录天数"}, ["op"] = {["id"] = "op", ["desc"] = "操作"}, ["pid"] = {["id"] = "pid", ["desc"] = "玩家id"}, ["reward"] = {["id"] = "reward", ["desc"] = "奖励"}, ["version"] = {["id"] = "version", ["desc"] = "版本"}},
        subtype = "sevenlogin_reward",
    },

    ["everydaycharge_state"] = {
        explain = "每日充值",
        log_format = {["endtime"] = {["id"] = "endtime", ["desc"] = "结束时间"}, ["hdid"] = {["id"] = "hdid", ["desc"] = "活动ID"}, ["hdkey"] = {["id"] = "hdkey", ["desc"] = "活动版本"}, ["starttime"] = {["id"] = "starttime", ["desc"] = "开始时间"}},
        subtype = "everydaycharge_state",
    },

    ["everydaycharge_reward"] = {
        explain = "每日充值奖励",
        log_format = {["day"] = {["id"] = "day", ["desc"] = "登录天数"}, ["flag"] = {["id"] = "flag", ["desc"] = "充值类型"}, ["hdid"] = {["id"] = "hdid", ["desc"] = "活动ID"}, ["hdkey"] = {["id"] = "hdkey", ["desc"] = "活动版本"}, ["op"] = {["id"] = "op", ["desc"] = "操作"}, ["pid"] = {["id"] = "pid", ["desc"] = "玩家id"}, ["reward"] = {["id"] = "reward", ["desc"] = "奖励"}, ["rewardcnt"] = {["id"] = "rewardcnt", ["desc"] = "奖励次数"}, ["rewardedcnt"] = {["id"] = "rewardedcnt", ["desc"] = "领取次数"}},
        subtype = "everydaycharge_reward",
    },

    ["onlinegift_reward"] = {
        explain = "在线豪礼奖励",
        log_format = {["key"] = {["id"] = "key", ["desc"] = "奖励key"}, ["pid"] = {["id"] = "pid", ["desc"] = "玩家id"}, ["reward"] = {["id"] = "reward", ["desc"] = "奖励"}},
        subtype = "onlinegift_reward",
    },

    ["superrebate_state"] = {
        explain = "超级返利",
        log_format = {["state"] = {["id"] = "state", ["desc"] = "状态"}, ["version"] = {["id"] = "version", ["desc"] = "版本"}},
        subtype = "superrebate_state",
    },

    ["superrebate_reward"] = {
        explain = "超级返利奖励",
        log_format = {["pid"] = {["id"] = "pid", ["desc"] = "玩家id"}, ["reward"] = {["id"] = "reward", ["desc"] = "奖励"}, ["version"] = {["id"] = "version", ["desc"] = "版本"}},
        subtype = "superrebate_reward",
    },

    ["superrebate_lottery"] = {
        explain = "超级返利抽奖",
        log_format = {["lotterycnt"] = {["id"] = "lotterycnt", ["desc"] = "剩余抽奖次数"}, ["pid"] = {["id"] = "pid", ["desc"] = "玩家id"}, ["rebate"] = {["id"] = "rebate", ["desc"] = "返利类型"}, ["version"] = {["id"] = "version", ["desc"] = "版本"}},
        subtype = "superrebate_lottery",
    },

    ["totalcharge_state"] = {
        explain = "每日累充状态",
        log_format = {["mode"] = {["id"] = "mode", ["desc"] = "模式"}, ["state"] = {["id"] = "state", ["desc"] = "状态"}, ["version"] = {["id"] = "version", ["desc"] = "版本"}},
        subtype = "totalcharge_state",
    },

    ["totalcharge_reward"] = {
        explain = "每日累充奖励",
        log_format = {["level"] = {["id"] = "level", ["desc"] = "级别"}, ["mode"] = {["id"] = "mode", ["desc"] = "模式"}, ["pid"] = {["id"] = "pid", ["desc"] = "玩家id"}, ["version"] = {["id"] = "version", ["desc"] = "版本"}},
        subtype = "totalcharge_reward",
    },

    ["totalcharge_rewarded"] = {
        explain = "每日累充领取奖励",
        log_format = {["level"] = {["id"] = "level", ["desc"] = "级别"}, ["mode"] = {["id"] = "mode", ["desc"] = "模式"}, ["pid"] = {["id"] = "pid", ["desc"] = "玩家id"}, ["reward"] = {["id"] = "reward", ["desc"] = "奖励"}, ["version"] = {["id"] = "version", ["desc"] = "版本"}},
        subtype = "totalcharge_rewarded",
    },

    ["fightgiftbag_reward"] = {
        explain = "战力礼包奖励",
        log_format = {["pid"] = {["id"] = "pid", ["desc"] = "玩家id"}, ["rank"] = {["id"] = "rank", ["desc"] = "排名"}, ["score"] = {["id"] = "score", ["desc"] = "战力"}},
        subtype = "fightgiftbag_reward",
    },

    ["fightgiftbag_rewarded"] = {
        explain = "战力礼包领取奖励",
        log_format = {["pid"] = {["id"] = "pid", ["desc"] = "玩家id"}, ["reward"] = {["id"] = "reward", ["desc"] = "奖励"}, ["score"] = {["id"] = "score", ["desc"] = "战力"}},
        subtype = "fightgiftbag_rewarded",
    },

    ["dayexpense_reward"] = {
        explain = "每日累消奖励",
        log_format = {["expense"] = {["id"] = "expense", ["desc"] = "消费级别"}, ["hd_id"] = {["id"] = "hd_id", ["desc"] = "活动id"}, ["pid"] = {["id"] = "pid", ["desc"] = "玩家id"}, ["reward_group_key"] = {["id"] = "reward_group_key", ["desc"] = "领取奖励组"}},
        subtype = "dayexpense_reward",
    },

    ["dayexpense_rewarded"] = {
        explain = "每日累消领取奖励",
        log_format = {["expense"] = {["id"] = "expense", ["desc"] = "消费级别"}, ["hd_id"] = {["id"] = "hd_id", ["desc"] = "活动id"}, ["pid"] = {["id"] = "pid", ["desc"] = "玩家id"}, ["reward"] = {["id"] = "reward", ["desc"] = "奖励列表"}, ["reward_group_key"] = {["id"] = "reward_group_key", ["desc"] = "领取奖励组"}},
        subtype = "dayexpense_rewarded",
    },

    ["dayexpense_state"] = {
        explain = "每日累消活动状态",
        log_format = {["hd_id"] = {["id"] = "hd_id", ["desc"] = "活动id"}, ["reward_group_key"] = {["id"] = "reward_group_key", ["desc"] = "领取奖励组"}, ["state"] = {["id"] = "state", ["desc"] = "开启状态"}},
        subtype = "dayexpense_state",
    },

    ["threebiwu_battle"] = {
        explain = "三人比武对战",
        log_format = {["battle1"] = {["id"] = "battle1", ["desc"] = "队伍成员"}, ["battle2"] = {["id"] = "battle2", ["desc"] = "队伍成员"}},
        subtype = "threebiwu_battle",
    },

    ["threebiwu_warend"] = {
        explain = "三人比武战斗结束",
        log_format = {["player"] = {["id"] = "player", ["desc"] = "战士信息"}, ["winside"] = {["id"] = "winside", ["desc"] = "胜利方"}},
        subtype = "threebiwu_warend",
    },

    ["threebiwu_sort"] = {
        explain = "三人比武结束排名",
        log_format = {["sort"] = {["id"] = "sort", ["desc"] = "排名信息"}},
        subtype = "threebiwu_sort",
    },

    ["auction"] = {
        explain = "拍卖",
        log_format = {["info"] = {["id"] = "info", ["desc"] = "拍卖信息"}},
        subtype = "auction",
    },

    ["qifu_lottery"] = {
        explain = "祈福",
        log_format = {["flag"] = {["id"] = "flag", ["desc"] = "祈福类型"}, ["pid"] = {["id"] = "pid", ["desc"] = "玩家id"}},
        subtype = "qifu_lottery",
    },

    ["qifu_degree"] = {
        explain = "祈福进度奖励",
        log_format = {["degree"] = {["id"] = "degree", ["desc"] = "进度奖励"}, ["pid"] = {["id"] = "pid", ["desc"] = "玩家id"}},
        subtype = "qifu_degree",
    },

    ["activepointgift_state"] = {
        explain = "活跃礼包状态",
        log_format = {["info"] = {["id"] = "info", ["desc"] = "活动详细信息"}},
        subtype = "activepointgift_state",
    },

    ["activepointgift_reward"] = {
        explain = "活跃礼包奖励",
        log_format = {["info"] = {["id"] = "info", ["desc"] = "详细信息"}, ["pid"] = {["id"] = "pid", ["desc"] = "玩家id"}},
        subtype = "activepointgift_reward",
    },

    ["activepointgift_rewarded"] = {
        explain = "活跃礼包领取奖励",
        log_format = {["info"] = {["id"] = "info", ["desc"] = "详细信息"}, ["pid"] = {["id"] = "pid", ["desc"] = "玩家id"}},
        subtype = "activepointgift_rewarded",
    },

    ["jubaopen_state"] = {
        explain = "聚宝盆",
        log_format = {["state"] = {["id"] = "state", ["desc"] = "状态"}, ["version"] = {["id"] = "version", ["desc"] = "版本"}},
        subtype = "jubaopen_state",
    },

    ["jubaopen_reward"] = {
        explain = "聚宝盆奖励",
        log_format = {["cost"] = {["id"] = "cost", ["desc"] = "消耗元宝"}, ["op"] = {["id"] = "op", ["desc"] = "操作"}, ["pid"] = {["id"] = "pid", ["desc"] = "玩家id"}, ["reward"] = {["id"] = "reward", ["desc"] = "奖励"}, ["times"] = {["id"] = "times", ["desc"] = "聚宝次数"}, ["version"] = {["id"] = "version", ["desc"] = "版本"}},
        subtype = "jubaopen_reward",
    },

    ["drawcard_state"] = {
        explain = "疯狂翻牌状态",
        log_format = {["info"] = {["id"] = "info", ["desc"] = "详细信息"}},
        subtype = "drawcard_state",
    },

    ["drawcard_rewarded"] = {
        explain = "疯狂翻牌领取奖励",
        log_format = {["info"] = {["id"] = "info", ["desc"] = "详细信息"}, ["pid"] = {["id"] = "pid", ["desc"] = "玩家"}},
        subtype = "drawcard_rewarded",
    },

    ["continuouscharge_state"] = {
        explain = "连环充值",
        log_format = {["mode"] = {["id"] = "mode", ["desc"] = "模式"}, ["state"] = {["id"] = "state", ["desc"] = "状态"}, ["version"] = {["id"] = "version", ["desc"] = "版本"}},
        subtype = "continuouscharge_state",
    },

    ["continuouscharge_reward"] = {
        explain = "连环充值奖励",
        log_format = {["day"] = {["id"] = "day", ["desc"] = "第几天"}, ["mode"] = {["id"] = "mode", ["desc"] = "模式"}, ["pid"] = {["id"] = "pid", ["desc"] = "玩家id"}, ["reward"] = {["id"] = "reward", ["desc"] = "奖励"}, ["version"] = {["id"] = "version", ["desc"] = "版本"}},
        subtype = "continuouscharge_reward",
    },

    ["continuouscharge_totalreward"] = {
        explain = "连环充值累计奖励",
        log_format = {["day"] = {["id"] = "day", ["desc"] = "累计天数"}, ["mode"] = {["id"] = "mode", ["desc"] = "模式"}, ["pid"] = {["id"] = "pid", ["desc"] = "玩家id"}, ["reward"] = {["id"] = "reward", ["desc"] = "奖励"}, ["version"] = {["id"] = "version", ["desc"] = "版本"}},
        subtype = "continuouscharge_totalreward",
    },

    ["continuousexpense_state"] = {
        explain = "连环消费",
        log_format = {["mode"] = {["id"] = "mode", ["desc"] = "模式"}, ["state"] = {["id"] = "state", ["desc"] = "状态"}, ["version"] = {["id"] = "version", ["desc"] = "版本"}},
        subtype = "continuousexpense_state",
    },

    ["continuousexpense_reward"] = {
        explain = "连环消费奖励",
        log_format = {["day"] = {["id"] = "day", ["desc"] = "第几天"}, ["mode"] = {["id"] = "mode", ["desc"] = "模式"}, ["pid"] = {["id"] = "pid", ["desc"] = "玩家id"}, ["reward"] = {["id"] = "reward", ["desc"] = "奖励"}, ["version"] = {["id"] = "version", ["desc"] = "版本"}},
        subtype = "continuousexpense_reward",
    },

    ["continuousexpense_totalreward"] = {
        explain = "连环消费累计奖励",
        log_format = {["day"] = {["id"] = "day", ["desc"] = "累计天数"}, ["mode"] = {["id"] = "mode", ["desc"] = "模式"}, ["pid"] = {["id"] = "pid", ["desc"] = "玩家id"}, ["reward"] = {["id"] = "reward", ["desc"] = "奖励"}, ["version"] = {["id"] = "version", ["desc"] = "版本"}},
        subtype = "continuousexpense_totalreward",
    },

    ["nianshou_monster"] = {
        explain = "年兽刷怪",
        log_format = {["cnt"] = {["id"] = "cnt", ["desc"] = "数量"}, ["flag"] = {["id"] = "flag", ["desc"] = "类型"}, ["pid"] = {["id"] = "pid", ["desc"] = "玩家id"}},
        subtype = "nianshou_monster",
    },

    ["fuyuanbox_reward"] = {
        explain = "福缘宝箱",
        log_format = {["pid"] = {["id"] = "pid", ["desc"] = "玩家id"}, ["reward"] = {["id"] = "reward", ["desc"] = "奖励"}, ["times"] = {["id"] = "times", ["desc"] = "次数"}},
        subtype = "fuyuanbox_reward",
    },

    ["limittimediscount_state"] = {
        explain = "商城限时打折",
        log_format = {["state"] = {["id"] = "state", ["desc"] = "状态"}},
        subtype = "limittimediscount_state",
    },

    ["festivalgift_rewarded"] = {
        explain = "节日礼物领取状态",
        log_format = {["info"] = {["id"] = "info", ["desc"] = "详细信息"}, ["pid"] = {["id"] = "pid", ["desc"] = "玩家"}},
        subtype = "festivalgift_rewarded",
    },

    ["goldcoinparty_lottery"] = {
        explain = "元宝狂欢",
        log_format = {["flag"] = {["id"] = "flag", ["desc"] = "抽奖模式"}, ["lottery"] = {["id"] = "lottery", ["desc"] = "抽奖类型"}, ["pid"] = {["id"] = "pid", ["desc"] = "玩家id"}},
        subtype = "goldcoinparty_lottery",
    },

    ["goldcoinparty_degree"] = {
        explain = "元宝狂欢进度奖励",
        log_format = {["degree"] = {["id"] = "degree", ["desc"] = "进度奖励"}, ["pid"] = {["id"] = "pid", ["desc"] = "玩家id"}},
        subtype = "goldcoinparty_degree",
    },

    ["mysticalbox_getbox"] = {
        explain = "神秘宝箱领取宝箱",
        log_format = {["info"] = {["id"] = "info", ["desc"] = "详细信息"}, ["pid"] = {["id"] = "pid", ["desc"] = "玩家id"}},
        subtype = "mysticalbox_getbox",
    },

    ["mysticalbox_rewarded"] = {
        explain = "神秘宝箱获得宝箱奖励",
        log_format = {["info"] = {["id"] = "info", ["desc"] = "详细信息"}, ["pid"] = {["id"] = "pid", ["desc"] = "玩家id"}},
        subtype = "mysticalbox_rewarded",
    },

    ["luanshimoying_boss"] = {
        explain = "乱世魔影boss",
        log_format = {["boss_type"] = {["id"] = "boss_type", ["desc"] = "BOSS类型"}, ["npc_id"] = {["id"] = "npc_id", ["desc"] = "BOSS"}, ["scene"] = {["id"] = "scene", ["desc"] = "场景"}, ["star"] = {["id"] = "star", ["desc"] = "星级"}},
        subtype = "luanshimoying_boss",
    },

    ["luanshimoying_box"] = {
        explain = "乱世魔影宝箱",
        log_format = {["num"] = {["id"] = "num", ["desc"] = "宝箱数量"}, ["scene"] = {["id"] = "scene", ["desc"] = "场景"}, ["star"] = {["id"] = "star", ["desc"] = "BOSS星级"}},
        subtype = "luanshimoying_box",
    },

    ["joyexpense_reward"] = {
        explain = "欢乐返利奖励",
        log_format = {["info"] = {["id"] = "info", ["desc"] = "详细信息"}, ["pid"] = {["id"] = "pid", ["desc"] = "玩家id"}},
        subtype = "joyexpense_reward",
    },

    ["joyexpense_rewarded"] = {
        explain = "欢乐返利领取奖励",
        log_format = {["info"] = {["id"] = "info", ["desc"] = "详细信息"}, ["pid"] = {["id"] = "pid", ["desc"] = "玩家id"}},
        subtype = "joyexpense_rewarded",
    },

    ["joyexpense_state"] = {
        explain = "欢乐返利活动状态",
        log_format = {["info"] = {["id"] = "info", ["desc"] = "详细信息"}},
        subtype = "joyexpense_state",
    },

    ["iteminvest"] = {
        explain = "道具投资",
        log_format = {["invest_id"] = {["id"] = "invest_id", ["desc"] = "投资编号"}, ["invest_item"] = {["id"] = "invest_item", ["desc"] = "投资道具"}, ["invest_money"] = {["id"] = "invest_money", ["desc"] = "投资金额"}, ["pid"] = {["id"] = "pid", ["desc"] = "玩家id"}},
        subtype = "iteminvest",
    },

    ["iteminvest_reward"] = {
        explain = "道具投资奖励",
        log_format = {["day"] = {["id"] = "day", ["desc"] = "第几天奖励"}, ["invest_id"] = {["id"] = "invest_id", ["desc"] = "投资编号"}, ["invest_item"] = {["id"] = "invest_item", ["desc"] = "投资道具"}, ["item_num"] = {["id"] = "item_num", ["desc"] = "道具数量"}, ["pid"] = {["id"] = "pid", ["desc"] = "玩家id"}},
        subtype = "iteminvest_reward",
    },

    ["iteminvest_state"] = {
        explain = "道具投资状态",
        log_format = {["mode"] = {["id"] = "mode", ["desc"] = "模式"}, ["state"] = {["id"] = "state", ["desc"] = "状态"}, ["version"] = {["id"] = "version", ["desc"] = "版本"}},
        subtype = "iteminvest_state",
    },

    ["singlewar"] = {
        explain = "蜀山论道",
        log_format = {["info"] = {["id"] = "info", ["desc"] = "日志信息"}},
        subtype = "singlewar",
    },

    ["treasureconvoy_state"] = {
        explain = "秘宝护送状态",
        log_format = {["state"] = {["id"] = "state", ["desc"] = "状态"}},
        subtype = "treasureconvoy_state",
    },

    ["treasureconvoy_rob"] = {
        explain = "秘宝护送打劫",
        log_format = {["loser"] = {["id"] = "loser", ["desc"] = "输家"}, ["war"] = {["id"] = "war", ["desc"] = "战斗"}, ["winner"] = {["id"] = "winner", ["desc"] = "赢家"}, ["winside"] = {["id"] = "winside", ["desc"] = "赢方"}},
        subtype = "treasureconvoy_rob",
    },

    ["treasureconvoy_robbed_cashpledge"] = {
        explain = "秘宝护送被劫押金",
        log_format = {["cash_loss"] = {["id"] = "cash_loss", ["desc"] = "被劫押金"}, ["cash_type"] = {["id"] = "cash_type", ["desc"] = "押金类型"}, ["leave_cashpledge"] = {["id"] = "leave_cashpledge", ["desc"] = "剩余押金"}, ["pid"] = {["id"] = "pid", ["desc"] = "护送者"}, ["rob"] = {["id"] = "rob", ["desc"] = "抢劫者"}},
        subtype = "treasureconvoy_robbed_cashpledge",
    },

    ["discount_sale_buy"] = {
        explain = "购买优惠甩卖",
        log_format = {["day"] = {["id"] = "day", ["desc"] = "天数"}, ["goldcoin"] = {["id"] = "goldcoin", ["desc"] = "消耗元宝"}, ["items"] = {["id"] = "items", ["desc"] = "物品"}, ["pid"] = {["id"] = "pid", ["desc"] = "护送者"}, ["start_time"] = {["id"] = "start_time", ["desc"] = "开始时间"}},
        subtype = "discount_sale_buy",
    },

    ["worldcup_state"] = {
        explain = "世界杯",
        log_format = {["state"] = {["id"] = "state", ["desc"] = "状态"}, ["version"] = {["id"] = "version", ["desc"] = "版本"}},
        subtype = "worldcup_state",
    },

    ["zongzigame"] = {
        explain = "粽子大赛",
        log_format = {["info"] = {["id"] = "info", ["desc"] = "日志信息"}},
        subtype = "zongzigame",
    },

    ["duanwuqifu"] = {
        explain = "端午祈福",
        log_format = {["info"] = {["id"] = "info", ["desc"] = "日志信息"}},
        subtype = "duanwuqifu",
    },

    ["retrieveexp"] = {
        explain = "经验找回",
        log_format = {["info"] = {["id"] = "info", ["desc"] = "找回信息"}, ["pid"] = {["id"] = "pid", ["desc"] = "玩家id"}, ["totalexp"] = {["id"] = "totalexp", ["desc"] = "找回经验"}, ["type"] = {["id"] = "type", ["desc"] = "类型"}},
        subtype = "retrieveexp",
    },

}
