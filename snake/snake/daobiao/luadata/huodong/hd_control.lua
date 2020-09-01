-- ./excel/huodong/hdconfig.xlsx
return {

    ["collect"] = {
        desc = "集字活动",
        hd_type = "collect",
        key_list = {{["name"] = "通用版本", ["key"] = "collect_key_1"}},
        limit_day = 0,
        limit_type = 1,
        max_day = 5,
        min_day = 0,
        name = "集字活动",
    },

    ["caishen"] = {
        desc = "财神送礼",
        hd_type = "caishen",
        key_list = {{["name"] = "老服版本", ["key"] = "caishen_reward_1"}, {["name"] = "新服版本", ["key"] = "caishen_reward_2"}},
        limit_day = 0,
        limit_type = 1,
        max_day = 5,
        min_day = 0,
        name = "财神送礼",
    },

    ["dayexpense"] = {
        desc = "每日累消",
        hd_type = "dayexpense",
        key_list = {{["name"] = "老服版本", ["key"] = "reward_old"}, {["name"] = "新服版本", ["key"] = "reward_new"}},
        limit_day = 0,
        limit_type = 3,
        max_day = 10,
        min_day = 0,
        name = "每日累消(5点刷天)",
    },

    ["everydaycharge"] = {
        desc = "每日单充",
        hd_type = "everydaycharge",
        key_list = {{["name"] = "老服版本", ["key"] = "reward_old"}, {["name"] = "新服版本", ["key"] = "reward_new"}},
        limit_day = 0,
        limit_type = 3,
        max_day = 10,
        min_day = 0,
        name = "每日单充(5点刷天)",
    },

    ["sevenlogin"] = {
        desc = "七星葫芦",
        hd_type = "sevenlogin",
        key_list = {{["name"] = "通用版本", ["key"] = "default"}},
        limit_day = 7,
        limit_type = 2,
        max_day = 10,
        min_day = 0,
        name = "七星葫芦(固定7天)",
    },

    ["superrebate"] = {
        desc = "超级返利",
        hd_type = "superrebate",
        key_list = {{["name"] = "通用版本", ["key"] = "default"}},
        limit_day = 0,
        limit_type = 3,
        max_day = 10,
        min_day = 0,
        name = "超级返利(5点刷天)",
    },

    ["totalcharge"] = {
        desc = "每日累充",
        hd_type = "totalcharge",
        key_list = {{["name"] = "新服", ["key"] = "new"}, {["name"] = "老服", ["key"] = "old"}, {["name"] = "新第三套", ["key"] = "third"}},
        limit_day = 0,
        limit_type = 3,
        max_day = 10,
        min_day = 0,
        name = "每日累充(5点刷天)",
    },

    ["qifu"] = {
        desc = "河神祈福",
        hd_type = "qifu",
        key_list = {{["name"] = "通用版本", ["key"] = "default"}},
        limit_day = 0,
        limit_type = 3,
        max_day = 10,
        min_day = 0,
        name = "河神祈福(5点刷天)",
    },

    ["jubaopen"] = {
        desc = "聚宝盆",
        hd_type = "jubaopen",
        key_list = {{["name"] = "通用版本", ["key"] = "default"}},
        limit_day = 0,
        limit_type = 1,
        max_day = 10,
        min_day = 0,
        name = "聚宝盆",
    },

    ["activepoint"] = {
        desc = "活跃礼包",
        hd_type = "activepoint",
        key_list = {{["name"] = "通用版本", ["key"] = "reward"}},
        limit_day = 0,
        limit_type = 1,
        max_day = 5,
        min_day = 0,
        name = "活跃礼包",
    },

    ["continuouscharge"] = {
        desc = "连环充值",
        hd_type = "continuouscharge",
        key_list = {{["name"] = "新服", ["key"] = "new"}, {["name"] = "老服", ["key"] = "old"}},
        limit_day = 7,
        limit_type = 2,
        max_day = 7,
        min_day = 0,
        name = "连环充值(固定7天)",
    },

    ["continuousexpense"] = {
        desc = "连环消费",
        hd_type = "continuousexpense",
        key_list = {{["name"] = "新服", ["key"] = "new"}, {["name"] = "老服", ["key"] = "old"}},
        limit_day = 7,
        limit_type = 2,
        max_day = 7,
        min_day = 0,
        name = "连环消费(固定7天)",
    },

    ["drawcard"] = {
        desc = "疯狂翻牌",
        hd_type = "drawcard",
        key_list = {{["name"] = "通用版本", ["key"] = "reward"}},
        limit_day = 0,
        limit_type = 1,
        max_day = 7,
        min_day = 0,
        name = "疯狂翻牌",
    },

    ["everydayrank"] = {
        desc = "每日冲榜",
        hd_type = "everydayrank",
        key_list = {{["name"] = "通用版本", ["key"] = "default"}},
        limit_day = 0,
        limit_type = 3,
        max_day = 7,
        min_day = 0,
        name = "每日冲榜",
    },

    ["goldcoinparty"] = {
        desc = "元宝狂欢",
        hd_type = "goldcoinparty",
        key_list = {{["name"] = "通用版本", ["key"] = "default"}},
        limit_day = 0,
        limit_type = 3,
        max_day = 10,
        min_day = 0,
        name = "元宝狂欢",
    },

    ["joyexpense"] = {
        desc = "欢乐返利",
        hd_type = "joyexpense",
        key_list = {{["name"] = "老服版本", ["key"] = "reward_old"}, {["name"] = "新服版本", ["key"] = "reward_new"}},
        limit_day = 0,
        limit_type = 1,
        max_day = 7,
        min_day = 0,
        name = "欢乐返利",
    },

    ["iteminvest"] = {
        desc = "道具投资",
        hd_type = "iteminvest",
        key_list = {{["name"] = "新服", ["key"] = "new"}, {["name"] = "老服", ["key"] = "old"}},
        limit_day = 4,
        limit_type = 2,
        max_day = 4,
        min_day = 0,
        name = "道具投资(固定4天)",
    },

    ["zongzigame"] = {
        desc = "粽子大赛",
        hd_type = "zongzigame",
        key_list = {{["name"] = "通用版本", ["key"] = "default"}},
        limit_day = 0,
        limit_type = 1,
        max_day = 4,
        min_day = 0,
        name = "粽子大赛",
    },

    ["duanwuqifu"] = {
        desc = "端午祈福",
        hd_type = "duanwuqifu",
        key_list = {{["name"] = "通用版本", ["key"] = "default"}},
        limit_day = 0,
        limit_type = 1,
        max_day = 4,
        min_day = 0,
        name = "端午祈福",
    },

    ["worldcup"] = {
        desc = "世界杯",
        hd_type = "worldcup",
        key_list = {{["name"] = "通用版本", ["key"] = "default"}},
        limit_day = 0,
        limit_type = 1,
        max_day = 40,
        min_day = 0,
        name = "世界杯",
    },

}
